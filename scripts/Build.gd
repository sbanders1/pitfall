extends Node
# Autoload singleton "Build" — owns run state (souls) and the Necromancy skill tree.
# This is the heart of the prototype: every node here is a TRANSFORMATIVE choice,
# not a +1. Other systems just ask `Build.has("some_id")` and change behaviour.

signal souls_changed(amount)
signal skill_unlocked(id)

var souls: int = 0
var unlocked := {}  # id -> true

func _ready() -> void:
	# Start with the root node already learned so testing jumps straight to driving.
	unlocked["raise_dead"] = true

# Each skill: id, name, cost (souls), req (prerequisite ids), pos (tree layout), desc.
const SKILLS := [
	{
		"id": "raise_dead",
		"name": "Raise Dead",
		"cost": 3,
		"req": [],
		"pos": Vector2(0, -120),
		"desc": "The first sin. Press SPACE to tear nearby corpses out of the dirt as skeletal minions that hunt your enemies. Everything below grows from this.",
	},
	{
		"id": "legion",
		"name": "Legion",
		"cost": 5,
		"req": ["raise_dead"],
		"pos": Vector2(-260, 40),
		"desc": "You no longer raise one — you raise a CROWD. Every corpse bursts into THREE skeletons, your raise radius widens, and your horde cap more than doubles (10 -> 24). Death is a numbers game now.",
	},
	{
		"id": "miasma_wake",
		"name": "Miasma Wake",
		"cost": 5,
		"req": ["raise_dead"],
		"pos": Vector2(0, 40),
		"desc": "Your minions exhale rot as they move, trailing lingering poison clouds. The arena itself becomes a weapon — drive enemies through the murk you've sown.",
	},
	{
		"id": "bone_riders",
		"name": "Bone Riders",
		"cost": 6,
		"req": ["raise_dead"],
		"pos": Vector2(260, 40),
		"desc": "Your skeletons mount spectral steeds. They keep pace with your engine, charge at lethal speed, and ram like you do. A cavalry of the dead at your bumper.",
	},
	{
		"id": "plague_burst",
		"name": "Plague Burst",
		"cost": 6,
		"req": ["miasma_wake"],
		"pos": Vector2(-130, 220),
		"desc": "A slain minion is not a loss — it's a delivery. Every fallen skeleton erupts into a thick plague cloud, seeding fresh miasma exactly where the fighting is worst.",
	},
	{
		"id": "dark_momentum",
		"name": "Dark Momentum",
		"cost": 7,
		"req": ["bone_riders"],
		"pos": Vector2(280, 220),
		"desc": "Every minion in your legion feeds your engine. The bigger the horde at your back, the faster you fly. Raise an army and outrun the world.",
	},
	{
		"id": "necrotic_bloom",
		"name": "Necrotic Bloom",
		"cost": 9,
		"req": ["plague_burst", "dark_momentum"],
		"pos": Vector2(80, 380),
		"desc": "The capstone. Pools of miasma bloom spores that claw their way up as NEW minions, with no corpse required. The dead make more dead, forever. The pit becomes yours.",
	},
]

func skill(id: String) -> Dictionary:
	for s in SKILLS:
		if s["id"] == id:
			return s
	return {}

func has(id: String) -> bool:
	return unlocked.has(id)

func reqs_met(s: Dictionary) -> bool:
	for r in s["req"]:
		if not has(r):
			return false
	return true

func can_unlock(id: String) -> bool:
	if has(id):
		return false
	var s := skill(id)
	if s.is_empty():
		return false
	return reqs_met(s) and souls >= int(s["cost"])

func try_unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	var s := skill(id)
	souls -= int(s["cost"])
	unlocked[id] = true
	emit_signal("souls_changed", souls)
	emit_signal("skill_unlocked", id)
	return true

func add_souls(n: int) -> void:
	souls += n
	emit_signal("souls_changed", souls)

func reset() -> void:
	souls = 0
	unlocked.clear()
	emit_signal("souls_changed", souls)
