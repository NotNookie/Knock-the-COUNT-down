extends Node
## Plays a click sound whenever any Button is pressed, anywhere in the game.
## Hooks new buttons automatically via node_added instead of requiring each
## scene to wire it up individually.

const CLICK_SOUND := preload("res://assets/ui/kenney/sounds/click-a.ogg")

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_child(player)
	player.stream = CLICK_SOUND
	player.volume_db = -8.0
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(_play_click)


func _play_click() -> void:
	player.stop()
	player.play()
