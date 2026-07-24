class_name GuildState
extends Resource

## Persistent container for core guild values and ownership of all equipment.
## Created by the game if none exists on first run / new game.

@export var gold: int = 600
@export var renown: int = 20
@export var current_week: int = 1

var owned_weapons: Array[WeaponData] = []
var owned_training: Array[TrainingEquipment] = []
var owned_medics: Array[TrainingEquipment] = []


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
		if g is CharacterTemplate and g.assigned_weapon != null:
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
		if g is CharacterTemplate and g.assigned_training != null and not g.assigned_training.is_medic:
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
		if g is CharacterTemplate and g.assigned_training != null and g.assigned_training.is_medic:
			assigned_ids[g.assigned_training] = true
	var result: Array[TrainingEquipment] = []
	for m in owned_medics:
		if not assigned_ids.has(m):
			result.append(m)
	return result
