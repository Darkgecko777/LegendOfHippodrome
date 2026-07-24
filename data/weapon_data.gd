class_name WeaponData
extends Resource

## Simple data definition for a purchasable weapon.

@export var id: StringName = &""
@export var display_name: String = ""
@export var tier: int = 1
@export var cost: int = 75
@export var description: String = ""


static func create(p_id: StringName, p_name: String, p_tier: int = 1, p_cost: int = 75, p_desc: String = "") -> WeaponData:
	var w := WeaponData.new()
	w.id = p_id
	w.display_name = p_name
	w.tier = p_tier
	w.cost = p_cost
	w.description = p_desc
	return w
