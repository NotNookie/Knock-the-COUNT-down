extends Control
## Dumb playback layer over the FightLog FightSession already computed --
## no fight logic lives here, just presentation on a timer.

const EVENT_INTERVAL := 0.4

@onready var player_sprite: TextureRect = $Margin/VBox/Arena/PlayerSprite
@onready var opponent_sprite: TextureRect = $Margin/VBox/Arena/OpponentSprite
@onready var player_hp_bar: ProgressBar = $Margin/VBox/HpRow/PlayerHpBox/PlayerHpBar
@onready var player_hp_label: Label = $Margin/VBox/HpRow/PlayerHpBox/PlayerHpLabel
@onready var opponent_hp_bar: ProgressBar = $Margin/VBox/HpRow/OpponentHpBox/OpponentHpBar
@onready var opponent_hp_label: Label = $Margin/VBox/HpRow/OpponentHpBox/OpponentHpLabel
@onready var log_label: Label = $Margin/VBox/LogLabel
@onready var outcome_label: Label = $Margin/VBox/OutcomeLabel
@onready var continue_button: Button = $Margin/VBox/ContinueButton
@onready var event_timer: Timer = $EventTimer

var _events: Array[FightEvent] = []
var _event_index: int = 0
var _opponent_name: String = "Opponent"


func _ready() -> void:
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	event_timer.timeout.connect(_on_event_timer_timeout)
	event_timer.wait_time = EVENT_INTERVAL

	var opponent: Opponent = ContentDB.opponents.get(FightSession.opponent_id)
	if opponent != null:
		_opponent_name = opponent.display_name
		if opponent.portrait != null:
			opponent_sprite.texture = opponent.portrait

	var log: FightLog = FightSession.log
	if log == null:
		outcome_label.text = "No fight in progress."
		continue_button.visible = true
		return

	_events = log.events
	player_hp_bar.max_value = FightSession.player_max_hp
	player_hp_bar.value = FightSession.player_max_hp
	opponent_hp_bar.max_value = FightSession.opponent_max_hp
	opponent_hp_bar.value = FightSession.opponent_max_hp
	_update_hp_labels()

	event_timer.start()


func _on_event_timer_timeout() -> void:
	if _event_index >= _events.size():
		event_timer.stop()
		_show_outcome()
		return
	var event: FightEvent = _events[_event_index]
	_event_index += 1
	_apply_event(event)


func _apply_event(event: FightEvent) -> void:
	if event.actor == "player":
		player_hp_bar.value = event.actor_hp
		opponent_hp_bar.value = event.target_hp
	else:
		opponent_hp_bar.value = event.actor_hp
		player_hp_bar.value = event.target_hp
	_update_hp_labels()
	log_label.text = _describe_event(event)


func _update_hp_labels() -> void:
	player_hp_label.text = "%d/%d" % [int(player_hp_bar.value), int(player_hp_bar.max_value)]
	opponent_hp_label.text = "%d/%d" % [int(opponent_hp_bar.value), int(opponent_hp_bar.max_value)]


func _describe_event(event: FightEvent) -> String:
	var actor_name: String = "You" if event.actor == "player" else _opponent_name
	var target_name: String = _opponent_name if event.actor == "player" else "You"
	var technique: Technique = ContentDB.techniques.get(event.technique_id)
	var technique_name: String = technique.display_name if technique != null else event.technique_id
	match event.result:
		"hit":
			return "Round %d: %s land a %s for %d damage!" % [event.round, actor_name, technique_name, int(event.damage)]
		"miss":
			return "Round %d: %s throw a %s and miss." % [event.round, actor_name, technique_name]
		"avoided_mist":
			return "Round %d: %s vanish into mist, dodging the %s entirely." % [event.round, actor_name, technique_name]
		"dot":
			return "Round %d: %s takes %d curse damage." % [event.round, target_name, int(event.damage)]
		"regen":
			return "Round %d: %s regenerates %d HP." % [event.round, actor_name, int(event.damage)]
		_:
			return ""


func _show_outcome() -> void:
	match FightSession.log.winner:
		"player":
			outcome_label.text = "VICTORY!"
			GameState.award_victory(FightSession.opponent_id)
		"opponent":
			outcome_label.text = "DEFEAT..."
		_:
			outcome_label.text = "DRAW"
	continue_button.visible = true


func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")
