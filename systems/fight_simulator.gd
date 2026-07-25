class_name FightSimulator
extends RefCounted
## Pure fight-resolution logic -- no scene tree dependency. fight_screen.tscn
## is just a dumb playback layer over the FightLog this produces.

const MAX_ROUNDS := 5
const EXCHANGES_PER_ROUND := 4

const BASE_HIT_CHANCE := 0.85
const DODGE_PER_SPEED := 0.01  ## each point of Speed above the opponent's nudges dodge chance
const DAMAGE_PER_POWER := 0.08  ## +8% technique damage per Power level
const DAMAGE_REDUCTION_PER_VITALITY := 0.02  ## -2% incoming damage per Vitality level (capped)
const MAX_DAMAGE_REDUCTION := 0.6
const STAGGER_DAMAGE_THRESHOLD := 0.18  ## a hit dealing >=18% of target's max HP staggers them

const CURSE_OF_DECAY_START_ROUND := 3
const CURSE_OF_DECAY_DAMAGE := 4.0
const NIGHT_WALKER_REGEN_FRACTION := 0.08
const BLOOD_FRENZY_HP_THRESHOLD := 0.3
const BLOOD_FRENZY_DAMAGE_MULTIPLIER := 1.3
const SUCKER_PUNCH_CHANCE := 0.15
const SUCKER_PUNCH_DAMAGE := 10.0


static func simulate(player: FighterState, opponent: FighterState) -> FightLog:
	var log := FightLog.new()
	var flags := {
		"player": _fresh_flags(),
		"opponent": _fresh_flags(),
	}

	for round_num in range(1, MAX_ROUNDS + 1):
		_on_round_start(player, opponent, flags, round_num, log)
		if not player.is_alive() or not opponent.is_alive():
			break
		for _exchange in range(EXCHANGES_PER_ROUND):
			for actor_id in _turn_order(player, opponent):
				var actor: FighterState = player if actor_id == "player" else opponent
				var target: FighterState = opponent if actor_id == "player" else player
				var target_id: String = "opponent" if actor_id == "player" else "player"
				if not actor.is_alive() or not target.is_alive():
					break
				_take_turn(actor, target, actor_id, target_id, flags, round_num, log)
				if not target.is_alive():
					break
			if not player.is_alive() or not opponent.is_alive():
				break
		if not player.is_alive() or not opponent.is_alive():
			break

	log.winner = _decide_winner(player, opponent)
	return log


static func _on_round_start(player: FighterState, opponent: FighterState, flags: Dictionary, round_num: int, log: FightLog) -> void:
	flags["player"]["mist_form_used"] = false
	flags["opponent"]["mist_form_used"] = false

	for pair in [["player", player, opponent], ["opponent", opponent, player]]:
		var id: String = pair[0]
		var fighter: FighterState = pair[1]
		var foe: FighterState = pair[2]
		var fighter_flags: Dictionary = flags[id]

		# Night Walker: regenerate a chunk of max HP at the start of each round.
		if fighter.has_trait("night_walker") and fighter.is_alive():
			var pre_regen_hp: float = fighter.current_hp
			fighter.current_hp = minf(fighter.max_hp, fighter.current_hp + fighter.max_hp * NIGHT_WALKER_REGEN_FRACTION)
			if fighter.current_hp > pre_regen_hp:
				log.add(_make_event(round_num, id, "night_walker", "regen", fighter.current_hp - pre_regen_hp, fighter, foe, "Night Walker regenerates."))

		# Curse of Decay: a stacking DoT on the opponent once the fight runs long.
		if fighter.has_trait("curse_of_decay") and round_num >= CURSE_OF_DECAY_START_ROUND and foe.is_alive():
			var stacks: int = fighter_flags.get("curse_stacks", 0) + 1
			fighter_flags["curse_stacks"] = stacks
			var dot: float = CURSE_OF_DECAY_DAMAGE * stacks
			foe.current_hp = maxf(0.0, foe.current_hp - dot)
			log.add(_make_event(round_num, id, "curse_of_decay", "dot", dot, fighter, foe, "The curse deepens."))

		# Blood Frenzy: becomes significantly more aggressive/damaging when low.
		if fighter.has_trait("blood_frenzy"):
			fighter_flags["blood_frenzy"] = fighter.current_hp <= fighter.max_hp * BLOOD_FRENZY_HP_THRESHOLD


static func _turn_order(player: FighterState, opponent: FighterState) -> Array[String]:
	var player_speed: int = player.stat_levels.get("speed", 1)
	var opponent_speed: int = opponent.stat_levels.get("speed", 1)
	if player_speed >= opponent_speed:
		return ["player", "opponent"]
	return ["opponent", "player"]


static func _take_turn(actor: FighterState, target: FighterState, actor_id: String, target_id: String, flags: Dictionary, round_num: int, log: FightLog) -> void:
	var technique: Technique = _choose_technique(actor, target, actor_id, flags)
	if technique == null:
		return
	actor.current_stamina = maxf(0.0, actor.current_stamina - technique.stamina_cost)

	var actor_flags: Dictionary = flags[actor_id]
	var target_flags: Dictionary = flags[target_id]
	# This turn (whatever it does) consumes the "just dodged" counter window --
	# it only stays open for the actor's very next action.
	actor_flags["just_dodged"] = false

	# Mist Form: automatically avoids the first power-tagged hit each round.
	if target.has_trait("mist_form") and not target_flags.get("mist_form_used", false) and technique.tags.has("power_based"):
		target_flags["mist_form_used"] = true
		target_flags["just_dodged"] = true
		log.add(_make_event(round_num, actor_id, technique.id, "avoided_mist", 0.0, actor, target, "Mist Form lets them slip through the hit entirely."))
		return

	var hit_chance: float = BASE_HIT_CHANCE + (actor.stat_levels.get("speed", 1) - target.stat_levels.get("speed", 1)) * DODGE_PER_SPEED
	if _has_perk(target, "feral_instinct"):
		hit_chance -= 0.05 * float(round_num - 1)
	hit_chance = clampf(hit_chance, 0.1, 0.98)

	if randf() > hit_chance:
		target_flags["just_dodged"] = true
		log.add(_make_event(round_num, actor_id, technique.id, "miss", 0.0, actor, target, ""))
		return

	var damage: float
	var bypass_reduction := false
	# Sucker Punch: the Nightstalker periodically bypasses defense entirely.
	if actor.has_trait("sucker_punch") and randf() < SUCKER_PUNCH_CHANCE:
		damage = SUCKER_PUNCH_DAMAGE
		bypass_reduction = true
	else:
		damage = technique.base_damage * (1.0 + actor.stat_levels.get("power", 1) * DAMAGE_PER_POWER)
		if _has_perk(actor, "galvanized") and technique.tags.has("power_based"):
			damage *= 1.0 + _perk_value(actor, "galvanized")
		# Blood in the Water: bonus vs a staggered/low-HP target -- suppressed by
		# Off the Radar, since the player can't actually read that opening.
		if _has_perk(actor, "blood_in_the_water") and not target.has_trait("off_the_radar"):
			if target_flags.get("staggered", false) or target.current_hp <= target.max_hp * 0.25:
				damage *= 1.0 + _perk_value(actor, "blood_in_the_water")
		if actor_flags.get("blood_frenzy", false):
			damage *= BLOOD_FRENZY_DAMAGE_MULTIPLIER

	if not bypass_reduction:
		var reduction: float = clampf(target.stat_levels.get("vitality", 1) * DAMAGE_REDUCTION_PER_VITALITY, 0.0, MAX_DAMAGE_REDUCTION)
		damage *= (1.0 - reduction)

	target.current_hp = maxf(0.0, target.current_hp - damage)

	# Stagger: a big hit staggers the target unless they're immune to it.
	var can_stagger: bool = not (target.has_trait("ancient_resilience") and not technique.tags.has("power_based"))
	target_flags["staggered"] = can_stagger and damage >= target.max_hp * STAGGER_DAMAGE_THRESHOLD

	log.add(_make_event(round_num, actor_id, technique.id, "hit", damage, actor, target, ""))


static func _choose_technique(actor: FighterState, target: FighterState, actor_id: String, flags: Dictionary) -> Technique:
	var pool: Array[Technique] = actor.equipped_techniques
	if pool.is_empty():
		return null

	# "counter"-tagged techniques (e.g. Counter) are only usable the turn right
	# after this fighter successfully dodged -- see "just_dodged" in _take_turn.
	var can_counter: bool = flags[actor_id].get("just_dodged", false)
	var available: Array = pool.filter(func(t: Technique) -> bool: return can_counter or not t.tags.has("counter"))
	if available.is_empty():
		available = pool

	var usable: Array = available.filter(func(t: Technique) -> bool: return actor.current_stamina >= t.stamina_cost)
	if usable.is_empty():
		var cheapest: Technique = available[0]
		for t: Technique in available:
			if t.stamina_cost < cheapest.stamina_cost:
				cheapest = t
		usable = [cheapest]

	# The dodge window is fleeting -- capitalize on it immediately rather than
	# leaving Counter to compete with other techniques on damage/aggression.
	if can_counter:
		var counters: Array = usable.filter(func(t: Technique) -> bool: return t.tags.has("counter"))
		if not counters.is_empty():
			return counters[0]

	var target_flags: Dictionary = flags["opponent"] if actor_id == "player" else flags["player"]
	if target_flags.get("staggered", false):
		var finishers: Array = usable.filter(func(t: Technique) -> bool: return t.tags.has("finisher"))
		if not finishers.is_empty():
			return finishers[0]

	var behavior: Dictionary = actor.style.behavior_weights if actor.style != null else {}
	var aggression: float = behavior.get("aggression", 0.5)
	usable.sort_custom(func(a: Technique, b: Technique) -> bool: return a.base_damage > b.base_damage)
	if randf() < aggression:
		return usable[0]
	return usable[-1]


static func _decide_winner(player: FighterState, opponent: FighterState) -> String:
	if not player.is_alive() and not opponent.is_alive():
		return "draw"
	if not player.is_alive():
		return "opponent"
	if not opponent.is_alive():
		return "player"
	var player_pct: float = player.current_hp / player.max_hp
	var opponent_pct: float = opponent.current_hp / opponent.max_hp
	return "player" if player_pct >= opponent_pct else "opponent"


static func _has_perk(fighter: FighterState, perk_id: String) -> bool:
	for perk: Perk in fighter.perks:
		if perk.id == perk_id:
			return true
	return false


static func _perk_value(fighter: FighterState, perk_id: String) -> float:
	for perk: Perk in fighter.perks:
		if perk.id == perk_id:
			return perk.effect_value
	return 0.0


static func _fresh_flags() -> Dictionary:
	return {
		"staggered": false,
		"mist_form_used": false,
		"curse_stacks": 0,
		"blood_frenzy": false,
		"just_dodged": false,
	}


static func _make_event(round_num: int, actor_id: String, technique_id: String, result: String, damage: float, actor: FighterState, target: FighterState, note: String) -> FightEvent:
	var event := FightEvent.new()
	event.round = round_num
	event.actor = actor_id
	event.technique_id = technique_id
	event.result = result
	event.damage = damage
	event.actor_hp = actor.current_hp
	event.target_hp = target.current_hp
	event.note = note
	return event
