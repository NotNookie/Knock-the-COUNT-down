extends Control
## Arena entry: two paths. "Ladder" fights whichever ladder opponent you
## haven't beaten yet (Blood Knight -> Nightstalker -> Dracula, label updates to
## show who's next). "Duel" picks a random mob-tier opponent immediately --
## no selection list, since the whole point is a quick filler fight.

## Internal opponent ids -- unchanged even though "mummy"/"invisible_man" now
## display as "Blood Knight"/"Nightstalker" (vampire-themed reskin, see their
## .tres files). Renaming the ids themselves would mean touching save-shaped
## data like GameState.ladder_progress's keys, which isn't worth the risk.
const LADDER_ORDER := ["mummy", "invisible_man", "dracula"]

@onready var gold_label: Label = $GoldBadge/HBox/GoldLabel
@onready var ladder_button: Button = $ActionsBox/LadderButton
@onready var duel_button: Button = $ActionsBox/DuelButton
@onready var host_portrait: TextureRect = $HostPortrait


func _ready() -> void:
	ladder_button.pressed.connect(_on_ladder_button_pressed)
	duel_button.pressed.connect(_on_duel_button_pressed)
	GameState.currency_changed.connect(_on_currency_changed)
	_refresh()
	_start_breathing_animation()


## Same idle scale-pulse as the Hub's character sprite -- keeps the host from
## sitting dead-still while the player reads the speech bubble.
func _start_breathing_animation() -> void:
	const SCALE_AMOUNT := 0.015
	const BOB_DURATION := 1.4
	host_portrait.pivot_offset = host_portrait.size / 2.0
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(host_portrait, "scale", Vector2.ONE * (1.0 + SCALE_AMOUNT), BOB_DURATION)
	tween.tween_property(host_portrait, "scale", Vector2.ONE, BOB_DURATION)


func _on_currency_changed(_new_amount: int) -> void:
	_refresh()


func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameState.currency
	var next_id: String = _next_ladder_opponent_id()
	var opponent: Opponent = ContentDB.opponents.get(next_id)
	ladder_button.text = "Fight %s" % (opponent.display_name if opponent != null else next_id)
	duel_button.disabled = _mob_opponent_ids().is_empty()


## Fixed ladder order; once everyone's beaten, keeps offering the last (Dracula)
## as a repeatable fight rather than dead-ending the button.
func _next_ladder_opponent_id() -> String:
	for opponent_id: String in LADDER_ORDER:
		if not GameState.ladder_progress.get(opponent_id, false):
			return opponent_id
	return LADDER_ORDER[-1]


func _mob_opponent_ids() -> Array:
	return ContentDB.opponents.values() \
		.filter(func(o: Opponent) -> bool: return o.tier == "mob") \
		.map(func(o: Opponent) -> String: return o.id)


func _on_ladder_button_pressed() -> void:
	_start_fight(_next_ladder_opponent_id())


func _on_duel_button_pressed() -> void:
	var mob_ids: Array = _mob_opponent_ids()
	if mob_ids.is_empty():
		return
	_start_fight(mob_ids[randi() % mob_ids.size()])


func _start_fight(opponent_id: String) -> void:
	FightSession.start_fight(opponent_id)
	FightSession.run_simulation()
	SceneTransition.change_scene("res://scenes/fight/fight_screen.tscn")


func _on_back_pressed() -> void:
	SceneTransition.change_scene("res://scenes/hub/hub.tscn")
