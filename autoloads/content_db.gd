extends Node
## Loads and indexes all data-driven content Resources by id.
## Adding new content later means dropping a new .tres in data/ -- no code change.

const TECHNIQUES_DIR := "res://data/techniques/"
const PERKS_DIR := "res://data/perks/"
const STYLES_DIR := "res://data/styles/"
const OPPONENTS_DIR := "res://data/opponents/"

var techniques: Dictionary = {}  # id -> Technique
var perks: Dictionary = {}  # id -> Perk
var styles: Dictionary = {}  # id -> FighterStyle
var opponents: Dictionary = {}  # id -> Opponent


func _ready() -> void:
	_load_all(STYLES_DIR, styles)
	_load_all(TECHNIQUES_DIR, techniques)
	_load_all(PERKS_DIR, perks)
	_load_all(OPPONENTS_DIR, opponents)


func _load_all(dir_path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("ContentDB: could not open %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource: Resource = load(dir_path + file_name)
			if resource != null and "id" in resource:
				into[resource.id] = resource
		file_name = dir.get_next()
	dir.list_dir_end()


## Techniques usable by a given style: its own unlocks plus all universal ones.
func techniques_for_style(style: FighterStyle) -> Array[Technique]:
	var result: Array[Technique] = []
	for technique: Technique in techniques.values():
		if technique.required_style == null or technique.required_style == style:
			result.append(technique)
	return result


func universal_techniques() -> Array[Technique]:
	var result: Array[Technique] = []
	for technique: Technique in techniques.values():
		if technique.required_style == null:
			result.append(technique)
	return result


func perks_for_style(style: FighterStyle) -> Array[Perk]:
	var result: Array[Perk] = []
	for perk: Perk in perks.values():
		if perk.style_tag == "" or perk.style_tag == style.id:
			result.append(perk)
	return result
