extends Control
## Town view: background + character in the middle + interactable building
## hotspots. Arena launches a fight. Trainer spends gold on styles and the
## skill tree of techniques inside them. Stats/Perks popups still exist
## (unreachable for now -- no hotspot wired to them) but aren't deleted.

const STAT_IDS := ["power", "speed", "vitality"]
const STAT_DISPLAY_NAMES := {"power": "Power", "speed": "Speed", "vitality": "Vitality"}
const STYLE_IDS := ["franken", "werewolf", "ghost", "hunter"]
const PERK_IDS := ["galvanized", "feral_instinct", "unfinished_business", "silver_reserves", "blood_in_the_water"]

@onready var character_sprite: TextureRect = $CharacterSprite
@onready var gold_label: Label = $GoldLabel

@onready var stats_popup: Control = $StatsPopup
@onready var trainer_popup: Control = $TrainerPopup
@onready var perks_popup: Control = $PerksPopup
@onready var popups: Array[Control] = [stats_popup, trainer_popup, perks_popup]

@onready var level_label: Label = $StatsPopup/Panel/VBox/LevelLabel
@onready var stat_points_label: Label = $StatsPopup/Panel/VBox/StatPointsLabel
@onready var stat_rows: Dictionary = {
	"power": $StatsPopup/Panel/VBox/StatsBox/PowerRow,
	"speed": $StatsPopup/Panel/VBox/StatsBox/SpeedRow,
	"vitality": $StatsPopup/Panel/VBox/StatsBox/VitalityRow,
}

@onready var trainer_currency_label: Label = $TrainerPopup/Panel/VBox/CurrencyLabel
@onready var style_rows: Dictionary = {
	"franken": $TrainerPopup/Panel/VBox/StylesBox/FrankenRow,
	"werewolf": $TrainerPopup/Panel/VBox/StylesBox/WerewolfRow,
	"ghost": $TrainerPopup/Panel/VBox/StylesBox/GhostRow,
	"hunter": $TrainerPopup/Panel/VBox/StylesBox/HunterRow,
}
@onready var tree_row: HBoxContainer = $TrainerPopup/Panel/VBox/TreeScroll/TreeRow

@onready var perk_rows: Dictionary = {
	"galvanized": $PerksPopup/Panel/VBox/PerksBox/GalvanizedRow,
	"feral_instinct": $PerksPopup/Panel/VBox/PerksBox/FeralInstinctRow,
	"unfinished_business": $PerksPopup/Panel/VBox/PerksBox/UnfinishedBusinessRow,
	"silver_reserves": $PerksPopup/Panel/VBox/PerksBox/SilverReservesRow,
	"blood_in_the_water": $PerksPopup/Panel/VBox/PerksBox/BloodInTheWaterRow,
}


func _ready() -> void:
	GameState.xp_changed.connect(_on_state_changed)
	GameState.leveled_up.connect(_on_state_changed)
	GameState.stat_trained.connect(_on_state_changed)
	GameState.stat_points_changed.connect(_on_state_changed)
	GameState.currency_changed.connect(_on_state_changed)
	GameState.style_unlocked.connect(_on_state_changed)
	GameState.active_style_changed.connect(_on_state_changed)
	GameState.technique_unlocked.connect(_on_state_changed)
	GameState.perk_unlocked.connect(_on_state_changed)
	GameState.perk_equip_changed.connect(_on_state_changed)

	for stat_id: String in STAT_IDS:
		var row: HBoxContainer = stat_rows[stat_id]
		var button: Button = row.get_node("SpendButton")
		button.pressed.connect(_on_spend_stat_pressed.bind(stat_id))
	for style_id: String in STYLE_IDS:
		var row: HBoxContainer = style_rows[style_id]
		var button: Button = row.get_node("StyleButton")
		button.pressed.connect(_on_style_button_pressed.bind(style_id))
	for perk_id: String in PERK_IDS:
		var row: HBoxContainer = perk_rows[perk_id]
		var button: Button = row.get_node("PerkButton")
		button.pressed.connect(_on_perk_button_pressed.bind(perk_id))

	for popup: Control in popups:
		popup.visible = false
		var close_button: Button = popup.get_node("Panel/VBox/CloseButton")
		close_button.pressed.connect(_close_all_popups)

	_refresh()
	_start_breathing_animation()


## A small looping scale pulse on the character sprite -- reads as idle
## breathing without moving him from his fixed position (unlike animating
## position, which reads as floating/flying).
func _start_breathing_animation() -> void:
	const SCALE_AMOUNT := 0.06
	const BOB_DURATION := 1.0
	character_sprite.pivot_offset = character_sprite.size / 2.0
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character_sprite, "scale", Vector2.ONE * (1.0 + SCALE_AMOUNT), BOB_DURATION)
	tween.tween_property(character_sprite, "scale", Vector2.ONE, BOB_DURATION)


func _on_arena_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/fight_prep/fight_prep.tscn")


func _on_trainer_button_pressed() -> void:
	_open_popup(trainer_popup)


func _open_popup(popup: Control) -> void:
	for p: Control in popups:
		p.visible = (p == popup)


func _close_all_popups() -> void:
	for p: Control in popups:
		p.visible = false


func _on_spend_stat_pressed(stat_id: String) -> void:
	GameState.spend_stat_point(stat_id)


func _on_style_button_pressed(style_id: String) -> void:
	var style: FighterStyle = ContentDB.styles.get(style_id)
	if style == null:
		return
	if GameState.unlocked_styles.has(style):
		GameState.set_active_style(style)
	else:
		GameState.unlock_style(style)


func _on_technique_button_pressed(technique_id: String) -> void:
	if GameState.equipped_technique_ids.has(technique_id):
		GameState.unequip_technique(technique_id)
	elif GameState.unlocked_technique_ids.has(technique_id):
		GameState.equip_technique(technique_id)
	else:
		GameState.unlock_technique(technique_id)


func _on_perk_button_pressed(perk_id: String) -> void:
	if GameState.equipped_perk_ids.has(perk_id):
		GameState.unequip_perk(perk_id)
	else:
		GameState.equip_perk(perk_id)


func _on_state_changed(_a = null, _b = null) -> void:
	_refresh()


func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameState.currency

	level_label.text = "Level %d  (XP: %d/%d)" % [
		GameState.level, GameState.xp, GameState.xp_required_for_next_level()
	]
	stat_points_label.text = "Stat Points: %d" % GameState.available_stat_points

	for stat_id: String in STAT_IDS:
		var row: HBoxContainer = stat_rows[stat_id]
		var stat_level_label: Label = row.get_node("LevelLabel")
		var button: Button = row.get_node("SpendButton")
		stat_level_label.text = "%s: %d" % [STAT_DISPLAY_NAMES[stat_id], GameState.stat_levels.get(stat_id, 1)]
		button.disabled = GameState.available_stat_points <= 0

	trainer_currency_label.text = "Gold: %d" % GameState.currency
	for style_id: String in STYLE_IDS:
		var row: HBoxContainer = style_rows[style_id]
		var button: Button = row.get_node("StyleButton")
		var style: FighterStyle = ContentDB.styles.get(style_id)
		if style == null:
			continue
		var unlocked: bool = GameState.unlocked_styles.has(style)
		var active: bool = GameState.active_style == style
		if active:
			button.text = "%s (Active)" % style.display_name
			button.disabled = true
		elif unlocked:
			button.text = "Set Active: %s" % style.display_name
			button.disabled = false
		else:
			button.text = "Buy %s (%d gold)" % [style.display_name, GameState.STYLE_COST]
			button.disabled = not GameState.can_afford(GameState.STYLE_COST)
	_refresh_technique_tree()

	var perk_slots_full: bool = GameState.equipped_perk_ids.size() >= GameState.MAX_EQUIPPED_PERKS
	for perk_id: String in PERK_IDS:
		var row: HBoxContainer = perk_rows[perk_id]
		var button: Button = row.get_node("PerkButton")
		var perk: Perk = ContentDB.perks.get(perk_id)
		if perk == null:
			continue
		var unlocked: bool = GameState.unlocked_perk_ids.has(perk_id)
		var equipped: bool = GameState.equipped_perk_ids.has(perk_id)
		if not unlocked:
			button.text = "%s (Locked)" % perk.display_name
			button.disabled = true
		elif equipped:
			button.text = "%s (Equipped)" % perk.display_name
			button.disabled = false
		else:
			button.text = "Equip %s" % perk.display_name
			button.disabled = perk_slots_full


## Rebuilds the horizontally-scrollable skill tree for whichever style is
## currently active, plus the universal starters. Built at runtime instead
## of authored per-style in the scene since the visible set changes with
## which style you have active.
func _refresh_technique_tree() -> void:
	for child in tree_row.get_children():
		child.queue_free()

	var techniques: Array = ContentDB.techniques.values().filter(
		func(t: Technique) -> bool:
			return t.required_style == null or t.required_style == GameState.active_style
	)
	var equipped_full: bool = GameState.equipped_technique_ids.size() >= GameState.MAX_EQUIPPED_TECHNIQUES

	for technique: Technique in techniques:
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 0)
		var unlocked: bool = GameState.unlocked_technique_ids.has(technique.id)
		var equipped: bool = GameState.equipped_technique_ids.has(technique.id)
		if equipped:
			button.text = "%s\n(Equipped)" % technique.display_name
		elif unlocked:
			button.text = "Equip\n%s" % technique.display_name
			button.disabled = equipped_full
		else:
			button.text = "Unlock %s\n(%d gold)" % [technique.display_name, technique.unlock_cost]
			button.disabled = not GameState.can_afford(technique.unlock_cost)
		button.pressed.connect(_on_technique_button_pressed.bind(technique.id))
		tree_row.add_child(button)
