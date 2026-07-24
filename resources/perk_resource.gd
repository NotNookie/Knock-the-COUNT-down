class_name Perk
extends Resource
## A permanent passive upgrade unlocked by beating a ladder opponent.

enum EffectType {
	TECHNIQUE_DAMAGE_BONUS,   ## bonus damage for techniques matching affects_tag
	DODGE_CHANCE_RAMP,        ## dodge chance increases each round the fight continues
	COUNTER_CHANCE_BONUS,     ## Counter technique trigger chance increase
	STAMINA_REGEN_BONUS,      ## extra stamina recovered between rounds
	DAMAGE_VS_STAGGERED,      ## bonus damage vs. a staggered/low-HP opponent
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var style_tag: String = ""
@export var effect_type: EffectType = EffectType.TECHNIQUE_DAMAGE_BONUS
@export var effect_value: float = 0.0
## Used by effects that only apply to techniques carrying a specific tag
## (e.g. Galvanized only boosts techniques tagged "power_based").
@export var affects_tag: String = ""
