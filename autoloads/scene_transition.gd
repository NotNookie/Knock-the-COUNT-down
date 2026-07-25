extends CanvasLayer
## Fade-to-black scene transition. Lives on a CanvasLayer so it renders on
## top of whatever scene is currently loaded, and persists across scene
## swaps since it's an autoload rather than a child of any particular scene.

const FADE_DURATION := 0.25

@onready var fade_rect: ColorRect = $FadeRect


func _ready() -> void:
	fade_rect.visible = false
	fade_rect.modulate.a = 0.0


## Fades to black, swaps to the given scene, then fades back in. Callers
## don't need to await this -- it's fine to fire-and-forget.
func change_scene(scene_path: String) -> void:
	fade_rect.visible = true
	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await fade_out.finished

	get_tree().change_scene_to_file(scene_path)

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, FADE_DURATION)
	await fade_in.finished
	fade_rect.visible = false
