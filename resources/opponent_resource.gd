class_name Opponent
extends Resource
## A ladder or filler-fight opponent definition.

@export var id: String = ""
@export var display_name: String = ""
## "mob" (weak, trait-free filler), "miniboss" (ladder fight with unique traits),
## or "boss" (Dracula -- the one and only final boss).
@export var tier: String = "mob"
## Miniboss/boss only: their fixed narrative difficulty level, just for
## display in the fight screen. Mobs display the player's current level
## instead, since FighterState.from_opponent scales them to match it.
@export var level: int = 1
## Keys: "power", "speed", "vitality". Used as-is for miniboss/boss (hand-tuned
## encounters). Ignored for "mob" tier -- see total_stat_points instead.
@export var base_stats: Dictionary = {}
## Mob tier only: total points randomly split across power/speed/vitality
## fresh each fight, so the same mob plays a little differently each duel.
@export var total_stat_points: int = 0
## Trait ids resolved by fight_simulator.gd, e.g. "ancient_resilience", "curse_of_decay".
@export var traits: Array[String] = []
@export var technique_pool: Array[Technique] = []
@export var portrait: Texture2D
