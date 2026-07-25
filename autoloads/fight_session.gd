extends Node
## Transient state for the fight currently being set up/played. Not
## meta-progression (that's GameState) -- cleared each time a new fight starts.

var opponent_id: String = ""
var log: FightLog = null
var player_max_hp: float = 0.0
var opponent_max_hp: float = 0.0
## Stashed for fight_screen's hoverable stat display -- the FighterState
## instances themselves are discarded once the simulation finishes.
var player_stat_levels: Dictionary = {}
var opponent_stat_levels: Dictionary = {}


func start_fight(new_opponent_id: String) -> void:
	opponent_id = new_opponent_id
	log = null
	player_max_hp = 0.0
	opponent_max_hp = 0.0
	player_stat_levels = {}
	opponent_stat_levels = {}


## Runs the simulation immediately and stores the result for fight_screen to play back.
func run_simulation() -> void:
	var opponent: Opponent = ContentDB.opponents.get(opponent_id)
	if opponent == null:
		return
	var player_state: FighterState = GameState.build_player_fighter_state()
	var opponent_state: FighterState = FighterState.from_opponent(opponent, GameState.level)
	player_max_hp = player_state.max_hp
	opponent_max_hp = opponent_state.max_hp
	player_stat_levels = player_state.stat_levels.duplicate()
	opponent_stat_levels = opponent_state.stat_levels.duplicate()
	log = FightSimulator.simulate(player_state, opponent_state)
