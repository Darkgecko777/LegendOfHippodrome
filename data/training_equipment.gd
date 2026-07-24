class_name TrainingEquipment
extends Resource

## Training item that improves secondaries / Cunning / weapon skill, or a Medic.
## At Tier 1 a random secondary from the linked list is improved.

@export var id: StringName = &""
@export var display_name: String = ""
@export var tier: int = 1
@export var cost: int = 250
@export var linked_primary: StringName = &""          # or "cunning" / "weapon" / "recovery"
@export var possible_secondaries: Array[StringName] = []
@export var weapon_skill_gain: float = 0.0           # used by Wooden Dummy
@export var cunning_gain_min: float = 0.0
@export var cunning_gain_max: float = 0.0
@export var is_medic: bool = false
@export var recovery_multiplier: float = 1.0         # used by Medic
@export var description: String = ""


static func create(
		p_id: StringName,
		p_name: String,
		p_linked: StringName,
		p_secondaries: Array[StringName],
		p_tier: int = 1,
		p_cost: int = 250,
		p_desc: String = "",
		p_cunning_min: float = 0.0,
		p_cunning_max: float = 0.0,
		p_is_medic: bool = false,
		p_recovery_mult: float = 1.0
) -> TrainingEquipment:
	var t := TrainingEquipment.new()
	t.id = p_id
	t.display_name = p_name
	t.linked_primary = p_linked
	t.possible_secondaries = p_secondaries
	t.tier = p_tier
	t.cost = p_cost
	t.description = p_desc
	t.cunning_gain_min = p_cunning_min
	t.cunning_gain_max = p_cunning_max
	t.is_medic = p_is_medic
	t.recovery_multiplier = p_recovery_mult
	return t
