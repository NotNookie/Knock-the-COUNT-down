class_name FighterStyle
extends Resource
## A fighting style: a monster-flavored specialization the boxer trains into.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var monster_flavor: String = ""
@export var primary_stat: Technique.StatType = Technique.StatType.UNIVERSAL
## Weights consumed by fight_simulator.gd's technique-choice AI,
## e.g. {"aggression": 0.8, "patience": 0.2, "stamina_caution": 0.3}.
@export var behavior_weights: Dictionary = {}
