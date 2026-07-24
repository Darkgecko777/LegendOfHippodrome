class_name TrainingEquipment
extends Resource

## Training item that improves secondaries / Cunning / weapon skill.
## At Tier 1 a random secondary from the linked list is improved.

@export var id: StringName = &""
@export var display_name: String = ""
@export var tier: int = 1
@export var cost: int = 250
@export var linked_primary: StringName = &""          # or "cunning" / "weapon"
@export var possible_secondaries: Array[StringName] = []
@export var weapon_skill_gain: float = 0.0           # used by Wooden Dummy
@export var description: String = ""


static func create(
		p_id: StringName,
		p_name: String,
		p_linked: StringName,
		p_secondaries: Array[StringName],
		p_tier: int = 1,
		p_cost: int = 250,
		p_desc: String = ""
) -> TrainingEquipment:
	var t := TrainingEquipment.new()
	t.id = p_id
	t.display_name = p_name
	t.linked_primary = p_linked
	t.possible_secondaries = p_secondaries
	t.tier = p_tier
	t.cost = p_cost
	t.description = p_desc
	return t
