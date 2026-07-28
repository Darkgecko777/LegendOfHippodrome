class_name GuildState
extends Resource

## Persistent container for core guild values, ownership, and fight registration.

@export var gold: int = 600
@export var renown: int = 20
@export var current_week: int = 1

var owned_weapons: Array[WeaponData] = []
var owned_training: Array[TrainingEquipment] = []
var owned_medics: Array[TrainingEquipment] = []

## Available fight offers for the current cycle (array of Dictionaries).
## Each entry: { "monster": MonsterTemplate, "threat": int, "base_gold": int, "base_fame": int }
var available_offers: Array[Dictionary] = []

## Currently registered fight, or empty if none.
## Keys: monster, gladiator, intervention_level, threat, base_gold, base_fame
var registered_match: Dictionary = {}


func add_gold(amount: int) -> void:
	gold += max(amount, 0)


func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	return true


func add_renown(amount: int) -> void:
	renown += max(amount, 0)


func apply_renown_decay(amount: int) -> void:
	renown = max(renown - max(amount, 0), 0)


func advance_week() -> void:
	current_week += 1


func add_weapon(w: WeaponData) -> void:
	if w != null:
		owned_weapons.append(w)


func add_training(t: TrainingEquipment) -> void:
	if t == null:
		return
	if t.is_medic:
		owned_medics.append(t)
	else:
		owned_training.append(t)


## Returns weapons that are not currently assigned to any gladiator in the given roster.
func get_available_weapons(roster: Array) -> Array[WeaponData]:
	var assigned_ids: Dictionary = {}
	for g in roster:
		if g is GladiatorTemplate and g.assigned_weapon != null:
			assigned_ids[g.assigned_weapon] = true
	var result: Array[WeaponData] = []
	for w in owned_weapons:
		if not assigned_ids.has(w):
			result.append(w)
	return result


## Returns training items (non-medic) not currently assigned.
func get_available_training(roster: Array) -> Array[TrainingEquipment]:
	var assigned_ids: Dictionary = {}
	for g in roster:
		if g is GladiatorTemplate and g.assigned_training != null and not g.assigned_training.is_medic:
			assigned_ids[g.assigned_training] = true
	var result: Array[TrainingEquipment] = []
	for t in owned_training:
		if not assigned_ids.has(t):
			result.append(t)
	return result


## Returns medics not currently assigned.
func get_available_medics(roster: Array) -> Array[TrainingEquipment]:
	var assigned_ids: Dictionary = {}
	for g in roster:
		if g is GladiatorTemplate and g.assigned_training != null and g.assigned_training.is_medic:
			assigned_ids[g.assigned_training] = true
	var result: Array[TrainingEquipment] = []
	for m in owned_medics:
		if not assigned_ids.has(m):
			result.append(m)
	return result


## Simple tier from renown. Tune later.
func get_guild_tier() -> int:
	if renown >= 80:
		return 3
	if renown >= 40:
		return 2
	return 1


## Whether the guild knows the precise vulnerability tags for this monster archetype.
func knows_vulnerabilities(monster: MonsterTemplate) -> bool:
	if monster == null:
		return false
	# Simple thresholds for the prototype
	match monster.id:
		&"dire_boar":
			return renown >= 15
		&"giant_spider":
			return renown >= 25
		&"armoured_minotaur":
			return renown >= 45
		&"harpy":
			return renown >= 55
		_:
			return renown >= 30


func has_registered_match() -> bool:
	return not registered_match.is_empty()


func clear_registered_match() -> void:
	registered_match = {}


## Generate a fresh set of available offers based on current guild tier.
func refresh_match_offers(count: int = 3) -> void:
	available_offers.clear()
	var tier := get_guild_tier()
	for i in count:
		var m: MonsterTemplate = MonsterTemplate.get_random_for_tier(tier)
		var threat := _calc_threat(m)
		var base_gold := 40 + (threat * 3) + (m.tier * 25)
		var base_fame := 4 + int(threat / 8.0) + (m.tier * 3)
		available_offers.append({
			"monster": m,
			"threat": threat,
			"base_gold": base_gold,
			"base_fame": base_fame,
		})


func _calc_threat(m: MonsterTemplate) -> int:
	# Simple aggregate for prototype rewards
	var score := m.vitality + m.strength + m.endurance + int(m.cunning * 2.0)
	score += m.tier * 12
	return score
