class_name FightEvent
extends RefCounted
## One resolved action within a fight -- what fight_screen.tscn plays back.

var round: int = 0
var actor: String = ""  ## "player" or "opponent"
var technique_id: String = ""
var result: String = ""  ## "hit", "miss", "avoided_mist", "dot"
var damage: float = 0.0
var actor_hp: float = 0.0
var target_hp: float = 0.0
var note: String = ""  ## optional flavor text for commentary
