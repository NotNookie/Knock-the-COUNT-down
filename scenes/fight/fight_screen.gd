extends Control
## Playback layer over the FightLog FightSession already computed, plus the
## juice (impact flash, shake, floating damage) and commentary that make
## watching it not feel like reading a spreadsheet.

const EVENT_INTERVAL := 0.7

@onready var player_sprite: TextureRect = $Arena/PlayerSprite
@onready var opponent_sprite: TextureRect = $Arena/OpponentSprite
@onready var player_hp_bar: ProgressBar = $Margin/VBox/HpRow/PlayerHpBox/PlayerHpBar
@onready var player_hp_label: Label = $Margin/VBox/HpRow/PlayerHpBox/PlayerHpLabel
@onready var player_name_label: Label = $Margin/VBox/HpRow/PlayerHpBox/InfoRow/PlayerNameLabel
@onready var player_stat_bar: ProgressBar = $Margin/VBox/HpRow/PlayerHpBox/InfoRow/PlayerStatBar
@onready var opponent_hp_bar: ProgressBar = $Margin/VBox/HpRow/OpponentHpBox/OpponentHpBar
@onready var opponent_hp_label: Label = $Margin/VBox/HpRow/OpponentHpBox/OpponentHpLabel
@onready var opponent_name_label: Label = $Margin/VBox/HpRow/OpponentHpBox/InfoRow/OpponentNameLabel
@onready var opponent_stat_bar: ProgressBar = $Margin/VBox/HpRow/OpponentHpBox/InfoRow/OpponentStatBar
@onready var log_scroll: ScrollContainer = $CombatLogPanel/LogMargin/LogLayout/LogScroll
@onready var log_vbox: VBoxContainer = $CombatLogPanel/LogMargin/LogLayout/LogScroll/LogVBox
@onready var outcome_label: Label = $Margin/VBox/OutcomeLabel
@onready var continue_button: Button = $Margin/VBox/ContinueButton
@onready var event_timer: Timer = $EventTimer
@onready var punch_sound: AudioStreamPlayer = $PunchSound

var _events: Array[FightEvent] = []
var _event_index: int = 0
var _opponent_name: String = "Opponent"
var _root_start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_root_start_position = position
	# Centered pivots so the dodge's weave-tilt rotates around the sprite's
	# middle instead of its top-left corner.
	player_sprite.pivot_offset = player_sprite.size / 2.0
	opponent_sprite.pivot_offset = opponent_sprite.size / 2.0
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	event_timer.timeout.connect(_on_event_timer_timeout)
	event_timer.wait_time = EVENT_INTERVAL

	player_name_label.text = "%s  Lv. %d" % [GameState.player_name, GameState.level]
	_set_stat_bar(player_stat_bar, FightSession.player_stat_levels)

	var opponent: Opponent = ContentDB.opponents.get(FightSession.opponent_id)
	if opponent != null:
		_opponent_name = opponent.display_name
		if opponent.portrait != null:
			opponent_sprite.texture = opponent.portrait
		var opponent_level: int = GameState.level if opponent.tier == "mob" else opponent.level
		opponent_name_label.text = "%s  Lv. %d" % [_opponent_name, opponent_level]
	_set_stat_bar(opponent_stat_bar, FightSession.opponent_stat_levels)

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


## Fills in the compact hoverable "power level" bar -- its height is a quick
## at-a-glance read, the tooltip has the actual Power/Speed/Vitality numbers.
func _set_stat_bar(bar: ProgressBar, stat_levels: Dictionary) -> void:
	var power: int = stat_levels.get("power", 1)
	var speed: int = stat_levels.get("speed", 1)
	var vitality: int = stat_levels.get("vitality", 1)
	bar.value = float(power + speed + vitality)
	bar.tooltip_text = "Power: %d\nSpeed: %d\nVitality: %d" % [power, speed, vitality]


func _on_event_timer_timeout() -> void:
	if _event_index >= _events.size():
		event_timer.stop()
		_show_outcome()
		return
	var event: FightEvent = _events[_event_index]
	_event_index += 1
	_apply_event(event)


const ATTACK_RESULTS := ["hit", "miss", "avoided_mist"]
const DAMAGE_RESULTS := ["hit", "dot"]


func _apply_event(event: FightEvent) -> void:
	if event.result in ATTACK_RESULTS:
		_animate_lunge(event.actor)
	if event.result == "hit":
		var defender_id: String = _other_actor(event.actor)
		_animate_knockback(defender_id)
		_flash_hit(defender_id)
		_shake_screen(event.damage)
		_play_punch_sound()
	elif event.result == "miss":
		_animate_dodge(_other_actor(event.actor))
	elif event.result == "avoided_mist":
		_animate_mist_dodge(_other_actor(event.actor))
	if event.result in DAMAGE_RESULTS:
		var damaged_id: String = event.actor if event.result == "dot" else _other_actor(event.actor)
		_spawn_damage_popup(damaged_id, event.damage)

	if event.actor == "player":
		player_hp_bar.value = event.actor_hp
		opponent_hp_bar.value = event.target_hp
	else:
		opponent_hp_bar.value = event.actor_hp
		player_hp_bar.value = event.target_hp
	_update_hp_labels()
	_append_log_line(_describe_event(event))


## Lunges the attacker toward the other fighter and back -- reads as a punch.
## Only fires for actual attack attempts (hit/miss/avoided_mist), not
## passive ticks like curse damage or Night Walker regen. Travels the actual
## on-screen distance so the attacker's edge reaches the defender -- a real
## hit, not a token twitch -- with a fast snap out and a slower recoil back.
func _animate_lunge(actor_id: String) -> void:
	const CONTACT_GAP := 4.0
	const LUNGE_OUT_DURATION := 0.08
	const LUNGE_BACK_DURATION := 0.18
	var attacker: TextureRect = player_sprite if actor_id == "player" else opponent_sprite
	var defender: TextureRect = opponent_sprite if actor_id == "player" else player_sprite
	var direction: float = 1.0 if actor_id == "player" else -1.0

	var attacker_center: float = attacker.position.x + attacker.size.x / 2.0
	var defender_center: float = defender.position.x + defender.size.x / 2.0
	var gap: float = absf(defender_center - attacker_center) - attacker.size.x / 2.0 - defender.size.x / 2.0
	var travel: float = maxf(gap - CONTACT_GAP, 0.0)

	var start_x: float = attacker.position.x
	var tween := create_tween()
	tween.tween_property(attacker, "position:x", start_x + direction * travel, LUNGE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker, "position:x", start_x, LUNGE_BACK_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _other_actor(actor_id: String) -> String:
	return "opponent" if actor_id == "player" else "player"


func _sprite_for(actor_id: String) -> TextureRect:
	return player_sprite if actor_id == "player" else opponent_sprite


## Snaps the defender away from the attacker on an actual hit, timed to land
## right as the attacker's lunge reaches them (see LUNGE_OUT_DURATION above).
func _animate_knockback(target_id: String) -> void:
	const KNOCKBACK_DISTANCE := 18.0
	const IMPACT_DELAY := 0.08
	const KNOCKBACK_OUT_DURATION := 0.06
	const KNOCKBACK_BACK_DURATION := 0.2
	var sprite: TextureRect = _sprite_for(target_id)
	var direction: float = -1.0 if target_id == "player" else 1.0
	var start_x: float = sprite.position.x
	var tween := create_tween()
	tween.tween_interval(IMPACT_DELAY)
	tween.tween_property(sprite, "position:x", start_x + direction * KNOCKBACK_DISTANCE, KNOCKBACK_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:x", start_x, KNOCKBACK_BACK_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## A step-back-and-weave for the defender on a "miss" -- sells the dodge
## instead of the defender just standing there while the attacker whiffs.
## Steps away from the attacker, dips into a duck, and tilts like they're
## leaning out of the punch's path. Also flashes a cool cyan tint -- a color
## cue that reads even if the (much smaller, easy to miss next to the
## attacker's big lunge) movement itself doesn't catch the eye.
func _animate_dodge(target_id: String) -> void:
	const IMPACT_DELAY := 0.08
	const STEP_DISTANCE := 28.0
	const DUCK_DISTANCE := 16.0
	const TILT_ANGLE := 0.35
	const DODGE_OUT_DURATION := 0.14
	const DODGE_BACK_DURATION := 0.28
	const FLASH_DURATION := 0.1
	var sprite: TextureRect = _sprite_for(target_id)
	var away_direction: float = -1.0 if target_id == "player" else 1.0
	var tilt_direction: float = 1.0 if target_id == "player" else -1.0
	var start_position: Vector2 = sprite.position
	var start_rotation: float = sprite.rotation
	var dodge_position: Vector2 = start_position + Vector2(away_direction * STEP_DISTANCE, DUCK_DISTANCE)
	var dodge_rotation: float = start_rotation + tilt_direction * TILT_ANGLE

	# Three independent tweens started together instead of one tween juggling
	# parallel groups -- each is internally a plain sequential tween, the same
	# proven-working pattern as _animate_knockback/_flash_hit, just three of
	# them running at once.
	var position_tween := create_tween()
	position_tween.tween_interval(IMPACT_DELAY)
	position_tween.tween_property(sprite, "position", dodge_position, DODGE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	position_tween.tween_property(sprite, "position", start_position, DODGE_BACK_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var rotation_tween := create_tween()
	rotation_tween.tween_interval(IMPACT_DELAY)
	rotation_tween.tween_property(sprite, "rotation", dodge_rotation, DODGE_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rotation_tween.tween_property(sprite, "rotation", start_rotation, DODGE_BACK_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var color_tween := create_tween()
	color_tween.tween_interval(IMPACT_DELAY)
	color_tween.tween_property(sprite, "modulate", Color(0.4, 0.9, 1.0), FLASH_DURATION)
	color_tween.tween_property(sprite, "modulate", Color(1, 1, 1), DODGE_BACK_DURATION)


## Mist Form's dodge is thematically a vanish, not a sidestep -- the defender
## briefly fades to near-transparent (dissolving into mist) instead of
## physically moving, then reappears.
func _animate_mist_dodge(target_id: String) -> void:
	const IMPACT_DELAY := 0.08
	const FADE_OUT_DURATION := 0.12
	const FADE_IN_DURATION := 0.22
	const MIST_ALPHA := 0.15
	var sprite: TextureRect = _sprite_for(target_id)
	var tween := create_tween()
	tween.tween_interval(IMPACT_DELAY)
	tween.tween_property(sprite, "modulate:a", MIST_ALPHA, FADE_OUT_DURATION)
	tween.tween_property(sprite, "modulate:a", 1.0, FADE_IN_DURATION)


## Flashes the hit sprite white-hot then back to normal, synced to land with
## the knockback's impact moment.
func _flash_hit(target_id: String) -> void:
	const IMPACT_DELAY := 0.08
	const FLASH_DURATION := 0.06
	const FADE_DURATION := 0.18
	var sprite: TextureRect = _sprite_for(target_id)
	var tween := create_tween()
	tween.tween_interval(IMPACT_DELAY)
	tween.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0), FLASH_DURATION)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), FADE_DURATION)


## Shakes the whole screen on impact, scaled a little by damage dealt so a
## big hit reads as bigger than a graze.
func _shake_screen(damage: float) -> void:
	const IMPACT_DELAY := 0.08
	const SHAKE_DURATION := 0.05
	var strength: float = clampf(damage / 4.0, 2.0, 10.0)
	var tween := create_tween()
	tween.tween_interval(IMPACT_DELAY)
	for _i in range(4):
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(self, "position", _root_start_position + offset, SHAKE_DURATION)
	tween.tween_property(self, "position", _root_start_position, SHAKE_DURATION)


## A few different impact sounds picked at random, on top of the pitch
## variation below, so a flurry of hits doesn't sound identical.
const PUNCH_SOUNDS := [
	preload("res://assets/audio/sfx/punch_impact.mp3"),
	preload("res://assets/audio/sfx/punch_impact_2.mp3"),
	preload("res://assets/audio/sfx/punch_impact_3.mp3"),
]


## Punch impact sound, timed to land with the knockback/flash/shake (see
## IMPACT_DELAY in those functions). Slight pitch variation per hit so
## repeated punches in the same exchange don't sound like a stuck record.
func _play_punch_sound() -> void:
	const IMPACT_DELAY := 0.08
	const PITCH_MIN := 0.9
	const PITCH_MAX := 1.1
	var tween := create_tween()
	tween.tween_interval(IMPACT_DELAY)
	tween.tween_callback(func() -> void:
		punch_sound.stream = PUNCH_SOUNDS[randi() % PUNCH_SOUNDS.size()]
		punch_sound.pitch_scale = randf_range(PITCH_MIN, PITCH_MAX)
		punch_sound.play()
	)


## A damage number that pops up from the hit fighter and fades out. Parented
## to the sprite's own parent (Arena) so its position -- taken directly from
## sprite.position -- stays in the same local coordinate space instead of
## drifting if Arena itself is offset from FightScreen's origin.
func _spawn_damage_popup(target_id: String, amount: float) -> void:
	const IMPACT_DELAY := 0.08
	const RISE_DISTANCE := 24.0
	const POPUP_DURATION := 0.6
	var sprite: TextureRect = _sprite_for(target_id)
	var layer: Node = sprite.get_parent()

	var popup := Label.new()
	popup.text = "-%d" % int(amount)
	popup.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	popup.position = sprite.position + Vector2(sprite.size.x / 2.0 - 12.0, -8.0)
	popup.z_index = 10
	layer.add_child(popup)

	# Two independent tweens instead of set_parallel()+chain() -- see the
	# comment in _animate_dodge for why.
	var rise_tween := create_tween()
	rise_tween.tween_interval(IMPACT_DELAY)
	rise_tween.tween_property(popup, "position:y", popup.position.y - RISE_DISTANCE, POPUP_DURATION)

	var fade_tween := create_tween()
	fade_tween.tween_interval(IMPACT_DELAY + POPUP_DURATION * 0.4)
	fade_tween.tween_property(popup, "modulate:a", 0.0, POPUP_DURATION * 0.6)
	fade_tween.tween_callback(popup.queue_free)


## Rounds up rather than truncating so a fighter with a sliver of real HP
## (e.g. 0.4, still alive per FighterState.is_alive()) never displays as a
## misleading "0" while they can still act.
func _update_hp_labels() -> void:
	player_hp_label.text = "%d/%d" % [ceili(player_hp_bar.value), ceili(player_hp_bar.max_value)]
	opponent_hp_label.text = "%d/%d" % [ceili(opponent_hp_bar.value), ceili(opponent_hp_bar.max_value)]


## Appends one line to the scrolling combat log and snaps it to the bottom,
## chat-style, instead of overwriting a single "latest line" label.
const LOG_LINE_FONT_SIZE := 13

func _append_log_line(text: String) -> void:
	var line := Label.new()
	line.text = text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", LOG_LINE_FONT_SIZE)
	log_vbox.add_child(line)
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


## Commentary lines -- multiple phrasings per result, picked at random, so the
## broadcast doesn't read the same way twice. Each array's templates all share
## the exact same argument order so formatting stays simple and correct.
## This is the "monster boxing treated completely seriously by the
## commentators" bit from the original pitch, finally wired in.
## Args: round, actor, technique, target, damage.
const HIT_LINES := [
	"Round %d: %s connect with a %s on %s -- %d damage!",
	"Round %d: %s lands a %s on %s! %d damage, and the arena erupts!",
	"Round %d: OH! %s drops a %s on %s for %d!",
	"Round %d: %s's %s finds a home on %s. %d damage.",
]
## Args: round, actor, technique.
const MISS_LINES := [
	"Round %d: %s throw a %s and hit nothing but air.",
	"Round %d: %s's %s sails wide. The judges are unimpressed.",
	"Round %d: %s telegraphs a %s a mile away. Easy dodge.",
]
## Args: round, actor, technique.
const AVOIDED_MIST_LINES := [
	"Round %d: %s's %s passes clean through mist. Where did they go?!",
	"Round %d: The crowd gasps as %s's %s meets nothing but fog.",
]
## Args: round, target, damage.
const DOT_LINES := [
	"Round %d: the curse tightens its grip -- %s takes %d damage!",
	"Round %d: %s writhes as the curse deals %d more.",
]
## Args: round, actor, damage.
const REGEN_LINES := [
	"Round %d: %s's wounds knit shut in the dark -- +%d HP.",
	"Round %d: something ancient stirs in %s, healing %d HP.",
]


func _describe_event(event: FightEvent) -> String:
	var actor_name: String = GameState.player_name if event.actor == "player" else _opponent_name
	var target_name: String = _opponent_name if event.actor == "player" else GameState.player_name
	var technique: Technique = ContentDB.techniques.get(event.technique_id)
	var technique_name: String = technique.display_name if technique != null else event.technique_id
	match event.result:
		"hit":
			var line: String = HIT_LINES[randi() % HIT_LINES.size()]
			return line % [event.round, actor_name, technique_name, target_name, int(event.damage)]
		"miss":
			var line: String = MISS_LINES[randi() % MISS_LINES.size()]
			return line % [event.round, actor_name, technique_name]
		"avoided_mist":
			var line: String = AVOIDED_MIST_LINES[randi() % AVOIDED_MIST_LINES.size()]
			return line % [event.round, actor_name, technique_name]
		"dot":
			var line: String = DOT_LINES[randi() % DOT_LINES.size()]
			return line % [event.round, target_name, int(event.damage)]
		"regen":
			var line: String = REGEN_LINES[randi() % REGEN_LINES.size()]
			return line % [event.round, actor_name, int(event.damage)]
		_:
			return ""


## Special congratulatory copy the first time Dracula falls -- otherwise a
## Dracula win still gets the grand banner (repeatable fight, S&S2/Pigeon
## Ascent-style boss kills are always a moment), just without "first ever" framing.
const DRACULA_FIRST_WIN_LINE := "You have knocked the Count down... for the COUNT.\nThe championship -- and the pun -- are yours."
const DRACULA_REPEAT_WIN_LINE := "The Count falls once more. The crowd never gets tired of this."


func _show_outcome() -> void:
	match FightSession.log.winner:
		"player":
			var is_dracula: bool = FightSession.opponent_id == "dracula"
			var dracula_already_beaten: bool = GameState.ladder_progress.get("dracula", false)
			var gold_before: int = GameState.currency
			var level_before: int = GameState.level
			GameState.award_victory(FightSession.opponent_id)
			var gold_gained: int = GameState.currency - gold_before

			if is_dracula:
				outcome_label.text = "*** YOU BEAT COUNT DRACULA! ***\n"
				outcome_label.text += DRACULA_REPEAT_WIN_LINE if dracula_already_beaten else DRACULA_FIRST_WIN_LINE
				outcome_label.text += "\n+%d Gold" % gold_gained
			else:
				outcome_label.text = "VICTORY! +%d Gold" % gold_gained
			if GameState.level > level_before:
				outcome_label.text += "\nLEVEL UP! You're now Level %d!" % GameState.level
		"opponent":
			outcome_label.text = "DEFEAT..."
		_:
			outcome_label.text = "DRAW"
	continue_button.visible = true


func _on_continue_pressed() -> void:
	SceneTransition.change_scene("res://scenes/hub/hub.tscn")
