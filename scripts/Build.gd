extends Node
# Autoload singleton "Build" — owns run state (souls) and the Necromancy skill tree.
# This is the heart of the prototype: every node here is a TRANSFORMATIVE choice,
# not a +1. Other systems just ask `Build.has("some_id")` and change behaviour.

signal souls_changed(amount)
signal skill_unlocked(id)
signal xp_changed(xp, needed)
signal level_changed(level)
signal points_changed(points)

# Souls are an EXPENDABLE resource — fuel you burn out in the pit (raising the dead).
# They are NOT how you progress. Progression is the tree, paid for with SKILL POINTS,
# which you earn by LEVELLING UP. XP accrues over time from the descent plus every kill.
var souls: int = 0
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var unlocked := {}  # id -> true

func _ready() -> void:
	# Start with the root node already learned so testing jumps straight to driving.
	unlocked["raise_dead"] = true

# Each skill: id, name, cost (SKILL POINTS), req (prerequisite ids), pos (tree layout), desc.
# Costs scale by tier — tier-2 powers cost 1, tier-3 cost 2, the capstone costs 3.
const SKILLS := [
	{
		"id": "raise_dead",
		"name": "Raise Dead",
		"cost": 0,
		"req": [],
		"pos": Vector2(0, -180),
		"desc": "The first sin (already learned). Press SPACE to raise skeletal minions at your wheels — anywhere, no corpse needed — that hunt down rival racers. Each one costs souls. Everything below grows from this.",
	},
	{
		"id": "legion",
		"name": "Legion",
		"cost": 1,
		"req": ["raise_dead"],
		"pos": Vector2(-320, -40),
		"desc": "You no longer raise one — you raise a CROWD. Every summon claws up THREE skeletons at once instead of one, and your horde cap more than doubles (10 -> 24). Death is a numbers game now.",
	},
	{
		"id": "miasma_wake",
		"name": "Miasma Wake",
		"cost": 1,
		"req": ["raise_dead"],
		"pos": Vector2(-60, -40),
		"desc": "Your minions exhale rot as they move, trailing lingering poison clouds. The arena itself becomes a weapon — drive enemies through the murk you've sown.",
	},
	{
		"id": "bone_riders",
		"name": "Bone Riders",
		"cost": 1,
		"req": ["raise_dead"],
		"pos": Vector2(240, -40),
		"desc": "Your skeletons mount spectral steeds. They keep pace with your engine, charge at lethal speed, and ram like you do. A cavalry of the dead at your bumper.",
	},
	{
		"id": "plague_burst",
		"name": "Plague Burst",
		"cost": 2,
		"req": ["miasma_wake"],
		"pos": Vector2(-120, 100),
		"desc": "A slain minion is not a loss — it's a delivery. Every fallen skeleton erupts into a thick plague cloud, seeding fresh miasma exactly where the fighting is worst.",
	},
	{
		"id": "dark_momentum",
		"name": "Dark Momentum",
		"cost": 2,
		"req": ["bone_riders"],
		"pos": Vector2(260, 100),
		"desc": "Every minion in your legion feeds your engine. The bigger the horde at your back, the faster you fly. Raise an army and outrun the world.",
	},
	{
		"id": "necrotic_bloom",
		"name": "Necrotic Bloom",
		"cost": 3,
		"req": ["plague_burst", "dark_momentum"],
		"pos": Vector2(70, 230),
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
	return reqs_met(s) and skill_points >= int(s["cost"])

func try_unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	var s := skill(id)
	skill_points -= int(s["cost"])
	unlocked[id] = true
	emit_signal("points_changed", skill_points)
	emit_signal("skill_unlocked", id)
	return true

# --- Souls: expendable fuel ---------------------------------------------------

func add_souls(n: int) -> void:
	souls += n
	emit_signal("souls_changed", souls)

func spend_souls(n: int) -> bool:
	if n <= 0 or souls < n:
		return false
	souls -= n
	emit_signal("souls_changed", souls)
	return true

# --- XP & levelling: the progression currency ---------------------------------

func xp_to_next() -> int:
	return 10 + (level - 1) * 6

func add_xp(n: int) -> void:
	if n <= 0:
		return
	xp += n
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		skill_points += 1
		emit_signal("level_changed", level)
		emit_signal("points_changed", skill_points)
	emit_signal("xp_changed", xp, xp_to_next())

func reset() -> void:
	souls = 0
	level = 1
	xp = 0
	skill_points = 0
	unlocked.clear()
	unlocked["raise_dead"] = true
	emit_signal("souls_changed", souls)
	emit_signal("level_changed", level)
	emit_signal("points_changed", skill_points)
	emit_signal("xp_changed", xp, xp_to_next())
