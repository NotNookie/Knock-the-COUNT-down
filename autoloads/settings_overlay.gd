extends CanvasLayer
## Small always-on-top volume control, available from every scene since this
## is an autoload rather than something each scene has to wire up itself.

@onready var toggle_button: Button = $Root/ToggleButton
@onready var popup: PanelContainer = $Root/VolumePopup
@onready var volume_slider: HSlider = $Root/VolumePopup/VBox/VolumeSlider

var _master_bus: int = AudioServer.get_bus_index("Master")


func _ready() -> void:
	popup.visible = false
	toggle_button.pressed.connect(_on_toggle_pressed)
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(_master_bus))
	volume_slider.value_changed.connect(_on_volume_changed)


func _on_toggle_pressed() -> void:
	popup.visible = not popup.visible


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(value))
