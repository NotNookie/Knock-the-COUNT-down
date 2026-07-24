class_name FighterState
extends RefCounted
## Live, in-fight battle state for one combatant. Built fresh from GameState
## and content Resources at fight start; discarded once the fight ends.

var display_name: String = ""
var style: FighterStyle
## Keys: "power", "speed", "vitality".
var stat_levels: Dictionary = {"power": 0, "speed": 0, "vitality": 0}
var equipped_techniques: Array[Technique] = []
var perks: Array[Perk] = []
## Trait ids, e.g. an opponent's "mist_form" or "blood_frenzy".
var traits: Array[String] = []

var max_hp: float = 0.0
var current_hp: float = 0.0
var max_stamina: float = 0.0
var current_stamina: float = 0.0


func _init(p_display_name: String = "", p_style: FighterStyle = null) -> void:
	display_name = p_display_name
	style = p_style


## Derives max HP/Stamina from the Vitality stat and refills both to full.
## Formula is a placeholder for the Day 3 balance pass.
func recompute_pools() -> void:
	var vitality: float = stat_levels.get("vitality", 0)
	max_hp = 100.0 + vitality * 10.0
	max_stamina = 50.0 + vitality * 5.0
	current_hp = max_hp
	current_stamina = max_stamina


func has_trait(trait_id: String) -> bool:
	return traits.has(trait_id)


func is_alive() -> bool:
	return current_hp > 0.0


## Builds a live FighterState for an Opponent resource -- the boss/filler-fight
## equivalent of GameState.build_player_fighter_state(). Mob-tier opponents get
## their total_stat_points randomly redistributed each fight instead of using
## a fixed base_stats spread, so the same mob plays a little differently each duel.
static func from_opponent(opponent: Opponent) -> FighterState:
	var state := FighterState.new(opponent.display_name, null)
	if opponent.tier == "mob" and opponent.total_stat_points > 0:
		state.stat_levels = _random_stat_split(opponent.total_stat_points)
	else:
		state.stat_levels = {
			"power": opponent.base_stats.get("power", 1),
			"speed": opponent.base_stats.get("speed", 1),
			"vitality": opponent.base_stats.get("vitality", 1),
		}
	state.traits = opponent.traits.duplicate()
	state.equipped_techniques = opponent.technique_pool.duplicate()
	state.recompute_pools()
	return state


## Randomly distributes `total_points` one point at a time across the 3 stats.
static func _random_stat_split(total_points: int) -> Dictionary:
	var stats := {"power": 0, "speed": 0, "vitality": 0}
	var keys: Array = stats.keys()
	for _i in range(total_points):
		var key: String = keys[randi() % keys.size()]
		stats[key] += 1
	return stats
