class_name FightLog
extends RefCounted
## The full structured output of one FightSimulator.simulate() call.

var events: Array[FightEvent] = []
var winner: String = ""  ## "player", "opponent", or "draw"


func add(event: FightEvent) -> void:
	events.append(event)
