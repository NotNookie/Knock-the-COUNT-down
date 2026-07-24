extends Node
## Single source of truth for meta-progression: level/XP, stats, gold,
## purchased styles, the per-technique skill tree, equipped techniques,
## unlocked perks, and ladder progress. Progression is fight-driven: win a
## fight, earn XP (levels up -> stat points) and gold (spend at the Trainer
## on styles and the techniques inside them), fight again. No clock.

signal xp_changed(xp: int, required: int)
signal leveled_up(new_level: int)
signal stat_trained(stat: String, new_level: int)
signal stat_points_changed(available: int)
signal currency_changed(new_amount: int)
signal style_unlocked(style: FighterStyle)
signal active_style_changed(style: FighterStyle)
signal technique_unlocked(technique_id: String)
signal perk_unlocked(perk_id: String)
signal perk_equip_changed(perk_id: String, equipped: bool)
signal opponent_defeated(opponent_id: String)

## XP/gold awarded per victory, by opponent tier -- mobs give little (so
## grinding them alone isn't the efficient path), the boss gives a lot.
const XP_PER_TIER := {"mob": 10, "miniboss": 25, "boss": 100}
const GOLD_PER_TIER := {"mob": 5, "miniboss": 15, "boss": 50}
## XP required to reach the next level scales with the level being entered
## (e.g. level 1->2 needs BASE*2), matching the old training-cost curve.
const LEVEL_UP_BASE_XP := 20
const STAT_POINTS_PER_LEVEL := 4
## Flat gold price to purchase a style at the Trainer. Individual techniques
## inside that style's tree then cost their own gold on top of this -- see
## Technique.unlock_cost.
const STYLE_COST := 30
const MAX_EQUIPPED_TECHNIQUES := 4
const MAX_EQUIPPED_PERKS := 2

var level: int = 1
## XP accumulated toward the next level; resets (carrying overflow) on level-up.
var xp: int = 0
var currency: int = 0

## Keys: "power", "speed", "vitality". Everyone starts at 1.
var stat_levels: Dictionary = {"power": 1, "speed": 1, "vitality": 1}
var available_stat_points: int = 0

## Styles purchased with gold -- more than one can be owned over a run.
var unlocked_styles: Array[FighterStyle] = []
## Whichever purchased style currently drives the fight AI's behavior weights.
var active_style: FighterStyle = null

## Techniques unlocked in the skill tree (each cost its own gold, gated on
## its style being purchased first). Jab/Cross start unlocked for free.
var unlocked_technique_ids: Array[String] = ["jab", "cross"]
var equipped_technique_ids: Array[String] = ["jab", "cross"]

## Blood in the Water has no style_tag, so unlike the other 4 perks it isn't
## gated behind a style purchase -- it's just always unlocked from the start.
var unlocked_perk_ids: Array[String] = ["blood_in_the_water"]
var equipped_perk_ids: Array[String] = []
var ladder_progress: Dictionary = {"mummy": false, "invisible_man": false, "dracula": false}


func can_afford(amount: int) -> bool:
	return currency >= amount


func spend_stat_point(stat: String) -> bool:
	if available_stat_points <= 0:
		return false
	available_stat_points -= 1
	stat_levels[stat] = stat_levels.get(stat, 1) + 1
	stat_points_changed.emit(available_stat_points)
	stat_trained.emit(stat, stat_levels[stat])
	return true


## Unlocking a style also unlocks that style's tagged perk for free (e.g.
## buying Franken unlocks Galvanized) -- see _unlock_perks_for_style. The
## style's techniques are NOT unlocked automatically -- each still costs its
## own gold via unlock_technique(), once the style itself is owned.
func unlock_style(style: FighterStyle) -> bool:
	if unlocked_styles.has(style) or not can_afford(STYLE_COST):
		return false
	currency -= STYLE_COST
	unlocked_styles.append(style)
	currency_changed.emit(currency)
	style_unlocked.emit(style)
	_unlock_perks_for_style(style)
	if active_style == null:
		set_active_style(style)
	return true


func _unlock_perks_for_style(style: FighterStyle) -> void:
	for perk: Perk in ContentDB.perks.values():
		if perk.style_tag == style.id:
			unlock_perk(perk.id)


func set_active_style(style: FighterStyle) -> bool:
	if not unlocked_styles.has(style):
		return false
	active_style = style
	active_style_changed.emit(style)
	return true


## Unlocks one technique in the skill tree. Requires its style to already be
## purchased (universal techniques have no required_style and are already
## unlocked from the start, so this is only ever called for style techniques).
func unlock_technique(technique_id: String) -> bool:
	if unlocked_technique_ids.has(technique_id):
		return true
	var technique: Technique = ContentDB.techniques.get(technique_id)
	if technique == null:
		return false
	if technique.required_style != null and not unlocked_styles.has(technique.required_style):
		return false
	if not can_afford(technique.unlock_cost):
		return false
	currency -= technique.unlock_cost
	unlocked_technique_ids.append(technique_id)
	currency_changed.emit(currency)
	technique_unlocked.emit(technique_id)
	return true


func equip_technique(technique_id: String) -> bool:
	if equipped_technique_ids.has(technique_id):
		return true
	if not unlocked_technique_ids.has(technique_id):
		return false
	if equipped_technique_ids.size() >= MAX_EQUIPPED_TECHNIQUES:
		return false
	equipped_technique_ids.append(technique_id)
	return true


func unequip_technique(technique_id: String) -> void:
	equipped_technique_ids.erase(technique_id)


func unlock_perk(perk_id: String) -> void:
	if not unlocked_perk_ids.has(perk_id):
		unlocked_perk_ids.append(perk_id)
		perk_unlocked.emit(perk_id)


func equip_perk(perk_id: String) -> bool:
	if not unlocked_perk_ids.has(perk_id) or equipped_perk_ids.has(perk_id):
		return false
	if equipped_perk_ids.size() >= MAX_EQUIPPED_PERKS:
		return false
	equipped_perk_ids.append(perk_id)
	perk_equip_changed.emit(perk_id, true)
	return true


func unequip_perk(perk_id: String) -> void:
	if equipped_perk_ids.has(perk_id):
		equipped_perk_ids.erase(perk_id)
		perk_equip_changed.emit(perk_id, false)


func xp_required_for_next_level() -> int:
	return LEVEL_UP_BASE_XP * (level + 1)


## Called by the fight system on a victory: grants XP (levels up, possibly
## more than once on a big gain, granting stat points each time) and gold
## (spent at the Trainer), both scaled by the opponent's tier, and records
## ladder progress.
func award_victory(opponent_id: String) -> void:
	var opponent: Opponent = ContentDB.opponents.get(opponent_id)
	var tier: String = opponent.tier if opponent != null else "mob"
	xp += XP_PER_TIER.get(tier, 10)
	currency += GOLD_PER_TIER.get(tier, 5)
	currency_changed.emit(currency)

	var required: int = xp_required_for_next_level()
	while xp >= required:
		xp -= required
		level += 1
		available_stat_points += STAT_POINTS_PER_LEVEL
		leveled_up.emit(level)
		stat_points_changed.emit(available_stat_points)
		required = xp_required_for_next_level()
	xp_changed.emit(xp, required)

	if ladder_progress.has(opponent_id):
		ladder_progress[opponent_id] = true
	opponent_defeated.emit(opponent_id)


## Builds a live FighterState for the player from current meta-progression.
func build_player_fighter_state() -> FighterState:
	var state := FighterState.new("Your Boxer", active_style)
	state.stat_levels = stat_levels.duplicate()
	for technique_id: String in equipped_technique_ids:
		if ContentDB.techniques.has(technique_id):
			state.equipped_techniques.append(ContentDB.techniques[technique_id])
	for perk_id: String in equipped_perk_ids:
		if ContentDB.perks.has(perk_id):
			state.perks.append(ContentDB.perks[perk_id])
	state.recompute_pools()
	return state
