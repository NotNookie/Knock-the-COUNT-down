class_name Technique
extends Resource
## A single equippable boxing technique.

enum StatType { POWER, SPEED, VITALITY, UNIVERSAL }

@export var id: String = ""
@export var display_name: String = ""
@export var stat_type: StatType = StatType.UNIVERSAL
@export var required_style: FighterStyle
@export var base_damage: float = 0.0
@export var stamina_cost: float = 0.0
## Gold cost to unlock this technique in the Trainer's skill tree. Universal
## starters (Jab/Cross) are 0 -- everyone has them from the start for free.
@export var unlock_cost: int = 0
## Free-form tags consumed by fight_simulator.gd and opponent traits,
## e.g. "power_based" is checked by the Blood Knight's Ancient Resilience trait.
@export var tags: PackedStringArray = []
