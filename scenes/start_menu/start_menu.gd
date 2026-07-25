extends Control
## Title screen: asks the player's name (stored on GameState, shown throughout
## fight commentary/HP labels) before dropping them into the Hub.

const DEFAULT_NAME := "Boxer"
const MAX_NAME_LENGTH := 16

@onready var name_edit: LineEdit = $Panel/VBox/NameEdit
@onready var start_button: Button = $Panel/VBox/StartButton


func _ready() -> void:
	name_edit.text = GameState.player_name
	name_edit.max_length = MAX_NAME_LENGTH
	name_edit.text_submitted.connect(_on_start_pressed)
	start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed(_text: String = "") -> void:
	var chosen_name: String = name_edit.text.strip_edges()
	GameState.player_name = chosen_name if not chosen_name.is_empty() else DEFAULT_NAME
	SceneTransition.change_scene("res://scenes/hub/hub.tscn")
