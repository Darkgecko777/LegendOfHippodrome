class_name Ability
extends Resource

## Stance-linked combat ability. Used by both gladiators (via weapons) and monsters.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""

@export var stance: StringName = &"aggressive"          # aggressive / defensive / evasive
@export var stamina_cost: int = 10
@export var cooldown_exchanges: int = 0                # 0 = usable every exchange

@export var commitment: StringName = &"standard"       # low / standard / high
@export var is_telegraphed: bool = false               # forces high-priority Cunning trigger

@export var damage_multiplier: float = 1.0
@export var accuracy_modifier: float = 0.0             # flat %
@export var crit_modifier: float = 0.0                 # flat %

@export var additional_effects: Array[StringName] = []
@export var tags: Array[StringName] = []


static func create(
		p_id: StringName,
		p_name: String,
		p_stance: StringName,
		p_stamina: int = 10,
		p_cooldown: int = 0,
		p_commitment: StringName = &"standard",
		p_telegraphed: bool = false,
		p_dmg_mult: float = 1.0,
		p_acc: float = 0.0,
		p_crit: float = 0.0,
		p_tags: Array[StringName] = []
	) -> Ability:
	var a := Ability.new()
	a.id = p_id
	a.display_name = p_name
	a.stance = p_stance
	a.stamina_cost = p_stamina
	a.cooldown_exchanges = p_cooldown
	a.commitment = p_commitment
	a.is_telegraphed = p_telegraphed
	a.damage_multiplier = p_dmg_mult
	a.accuracy_modifier = p_acc
	a.crit_modifier = p_crit
	a.tags = p_tags
	return a
