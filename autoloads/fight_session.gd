extends Node
## Transient state for the fight currently being set up/played. Not
## meta-progression (that's GameState) -- cleared each time a new fight starts.

var opponent_id: String = ""
var log: FightLog = null
var player_max_hp: float = 0.0
var opponent_max_hp: float = 0.0


func start_fight(new_opponent_id: String) -> void:
	opponent_id = new_opponent_id
	log = null
	player_max_hp = 0.0
	opponent_max_hp = 0.0


## Runs the simulation immediately and stores the result for fight_screen to play back.
func run_simulation() -> void:
	var opponent: Opponent = ContentDB.opponents.get(opponent_id)
	if opponent == null:
		return
	var player_state: FighterState = GameState.build_player_fighter_state()
	var opponent_state: FighterState = FighterState.from_opponent(opponent)
	player_max_hp = player_state.max_hp
	opponent_max_hp = opponent_state.max_hp
	log = FightSimulator.simulate(player_state, opponent_state)
