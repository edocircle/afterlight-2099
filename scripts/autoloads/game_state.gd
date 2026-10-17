extends Node

signal energy_updated(target: String, value: float, max_value: float)
signal skill_leveled(discipline: String, new_val: float)
signal toast_requested(text: String)
signal modal_requested(kind: String)
signal identity_updated
signal glove_modifier_changed(new_val: float)

var protag_energy: float = 114.0
var max_protag_energy: float = 114.0
var minion_energy: float = 137.0
var max_minion_energy: float = 137.0

# Operative Identity
var operative_callsign: String = "Pete"
var operative_chassis: String = "male" # "male" / "female"

# Base Skills
var skills := {
	"mealPrep": 37.2,
	"toolCraft": 23.6,
	"woodWork": 25.9,
	"skinning": 11.2,
	"cooking": 22.3,
	"tailoring": 1.1,
	"pottery": 6.7,
	"construction": 0.0,
	"engraving": 0.0,
}

# Sub-progress tracking towards next +0.1 increment: discipline -> crafts completed
var skill_craft_counts: Dictionary = {}

# GP Cyberware Stats
var glove_modifier: float = 30.0 # +30 Cyber-Glove (or -15 Training Glove)
var gp_boost_pct: float = 400.0 # +400% Nanite Fabricator Apron
var archive_bonus: float = 0.2 # +0.2 Neural Archive Cortex bonus per increment

var minion_skills := {
	"scavenging": 55.2,
	"lumber": 29.6,
	"hunting": 20.7,
	"fishing": 4.6,
	"communication": 58.8,
}

var minion_gather_target: String = "" # item id; empty = random scrap

const SKILLS_PATH := "res://data/skills.json"
const LOADOUT_PATH := "res://data/loadout.json"
const POINTS_PER_LEVEL := 10.0

var skills_def: Dictionary = {} # display names per skill key
var loadout: Dictionary = {} # equipment / cyberware / minion chassis slot display data
var _initial: Dictionary = {}


func _ready() -> void:
	skills_def = _load_json(SKILLS_PATH)
	loadout = _load_json(LOADOUT_PATH)
	_initial = {
		"skills": skills.duplicate(),
		"minion_skills": minion_skills.duplicate(),
		"protag_energy": protag_energy,
		"minion_energy": minion_energy,
	}


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Invalid JSON in %s" % path)
	return {}


func set_identity(callsign: String, chassis: String) -> void:
	operative_callsign = callsign
	operative_chassis = chassis
	identity_updated.emit()


func get_avatar_glyph() -> String:
	return "👩‍🚀" if operative_chassis == "female" else "🧑‍🚀"


func cycle_glove_modifier() -> float:
	## Cycles between +30 (Cyber-Glove), 0 (Unequipped), and -15 (Training Glove for Fail-to-Learn XP)
	if glove_modifier == 30.0:
		glove_modifier = 0.0
	elif glove_modifier == 0.0:
		glove_modifier = -15.0
	else:
		glove_modifier = 30.0
	glove_modifier_changed.emit(glove_modifier)
	return glove_modifier


func reset_run() -> void:
	skills = _initial["skills"].duplicate()
	minion_skills = _initial["minion_skills"].duplicate()
	protag_energy = _initial["protag_energy"]
	minion_energy = _initial["minion_energy"]
	minion_gather_target = ""
	skill_craft_counts.clear()
	_emit_energy("player")
	_emit_energy("minion")


func get_level(points: float) -> int:
	## Discipline level = floor(skill points / 10). Skill points stay the source of truth.
	return int(floor(points / POINTS_PER_LEVEL))


func get_level_progress(points: float) -> float:
	return fposmod(points, POINTS_PER_LEVEL) / POINTS_PER_LEVEL


func get_total_level() -> int:
	var total := 0
	for k in skills:
		total += get_level(float(skills[k]))
	return total


func get_effective_skill(discipline: String) -> float:
	return float(skills.get(discipline, 0.0)) + glove_modifier


## --- Scaling Progression Curve & Success Formulas ---

func get_crafts_required_for_increment(base_skill: float) -> int:
	## Crafts Required for +0.1 Skill = max(1, floor(1 + (Base Skill / 15)^1.8))
	var ratio := base_skill / 15.0
	return maxi(1, int(floor(1.0 + pow(ratio, 1.8))))


func get_recipe_success_chance(discipline: String, level_req: float) -> float:
	## Success Chance = clamp(50% + (Effective Skill - Recipe Req) * 2%, 0%, 100%)
	var eff := get_effective_skill(discipline)
	var chance := 0.50 + (eff - level_req) * 0.02
	return clampf(chance, 0.0, 1.0)


func apply_craft_skill_xp(discipline: String, recipe_level_req: float) -> Dictionary:
	## Applies craft iteration XP taking into account Diminishing Returns,
	## Scaling Progression Curve, and Neural Archive Cortex (+0.2 Book) bonus.
	if not skills.has(discipline):
		return {"gained": 0.0, "diminished": false, "count": 0, "req_crafts": 1}

	var base: float = float(skills[discipline])

	# Diminishing Returns Rule:
	# Crafting a recipe whose minimum level requirement is more than 20 levels below base skill grants 0.0 XP.
	if (base - recipe_level_req) > 20.0:
		return {"gained": 0.0, "diminished": true, "count": 0, "req_crafts": 1}

	var req_crafts := get_crafts_required_for_increment(base)
	var count: int = int(skill_craft_counts.get(discipline, 0)) + 1
	var gained := 0.0

	if count >= req_crafts:
		count = 0
		# Neural Archive Cortex adds its bonus directly to each milestone increment (+0.2):
		var increment := snappedf(0.1 + archive_bonus, 0.1)
		skills[discipline] = snappedf(skills[discipline] + increment, 0.1)
		gained = increment
		skill_leveled.emit(discipline, skills[discipline])

	skill_craft_counts[discipline] = count
	return {
		"gained": gained,
		"diminished": false,
		"count": count,
		"req_crafts": req_crafts
	}


## --- Energy & Minion Methods ---

func consume_energy(target: String, amount: float) -> bool:
	if target == "player":
		if protag_energy < amount:
			return false
		protag_energy -= amount
	else:
		if minion_energy < amount:
			return false
		minion_energy -= amount
	_emit_energy(target)
	return true


func replenish_energy(target: String, amount: float) -> void:
	if target == "player":
		protag_energy = minf(max_protag_energy, protag_energy + amount)
	else:
		minion_energy = minf(max_minion_energy, minion_energy + amount)
	_emit_energy(target)


func add_skill_xp(discipline: String) -> void:
	apply_craft_skill_xp(discipline, 0.0)


func add_minion_skill_xp(skill: String) -> void:
	if minion_skills.has(skill):
		minion_skills[skill] = snappedf(minion_skills[skill] + 0.1, 0.1)
		skill_leveled.emit(skill, minion_skills[skill])


func _emit_energy(target: String) -> void:
	if target == "player":
		energy_updated.emit(target, protag_energy, max_protag_energy)
	else:
		energy_updated.emit(target, minion_energy, max_minion_energy)
