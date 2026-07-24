extends Node

## Orchestrates gladiator creation using GladiatorGeneratorRules.
## Produces a fully baked CharacterTemplate ready for the roster.

@export var rules: GladiatorGeneratorRules

const WEAPON_TYPES: Array[StringName] = [&"gladius", &"spear", &"trident", &"net"]


func _ready() -> void:
	if rules == null:
		# Fallback so the node still works if the export was left empty.
		rules = GladiatorGeneratorRules.new()


func generate_gladiator() -> CharacterTemplate:
	if rules == null:
		push_error("GladiatorGenerator: No rules assigned.")
		return null

	var t := CharacterTemplate.new()

	# Identity
	t.character_id = rules.create_character_id()
	t.display_name = rules.create_name()
	t.species_or_class = rules.default_species
	t.is_alive = true
	t.is_monster = false
	t.visual_key = rules.default_visual_key
	t.fame = 0

	# Primaries (8–20)
	t.base_vitality = rules.create_primary_stat()
	t.base_endurance = rules.create_primary_stat()
	t.base_strength = rules.create_primary_stat()
	t.base_agility = rules.create_primary_stat()
	t.base_precision = rules.create_primary_stat()
	t.base_resilience = rules.create_primary_stat()
	t.base_charisma = rules.create_primary_stat()

	# Cunning (flat 2–10) — Base is fixed, Current starts equal to Base
	t.base_cunning = rules.create_cunning()
	t.current_cunning = t.base_cunning

	# Personalities
	t.combat_personality = rules.create_combat_personality()
	t.noncombat_personality = rules.create_noncombat_personality()

	# Preferred weapon (exactly one) + modest starting skill
	t.preferred_weapon = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	t.weapon_skills = {
		t.preferred_weapon: 1.1
	}

	# Assignments start empty
	t.assigned_weapon = null
	t.assigned_training = null

	# Bake secondaries from primaries
	_bake_secondaries(t)

	# Runtime starting values
	t.current_health = t.base_max_health
	t.current_stamina = t.base_max_stamina
	t.abilities = []

	return t


func _bake_secondaries(t: CharacterTemplate) -> void:
	# Vitality
	t.base_max_health = rules.calc_max_health(t.base_vitality)
	t.base_injury_recovery_chance = rules.calc_injury_recovery_chance(t.base_vitality)

	# Endurance
	t.base_max_stamina = rules.calc_max_stamina(t.base_endurance)
	t.base_stamina_regen = rules.calc_stamina_regen(t.base_endurance)
	t.base_fatigue_resistance = rules.calc_fatigue_resistance(t.base_endurance)

	# Strength
	t.base_damage = rules.calc_base_damage(t.base_strength)
	t.base_ability_power = rules.calc_ability_power(t.base_strength)

	# Agility
	t.base_attack_speed = rules.calc_attack_speed(t.base_agility)
	t.base_dodge_chance = rules.calc_dodge_chance(t.base_agility)

	# Precision
	t.base_accuracy = rules.calc_accuracy(t.base_precision)
	t.base_crit_chance = rules.calc_crit_chance(t.base_precision)
	t.base_crit_multiplier = rules.calc_crit_multiplier(t.base_precision)

	# Resilience
	t.base_crit_defense_factor = rules.calc_crit_defense_factor(t.base_resilience)
	t.base_status_resistance = rules.calc_status_resistance(t.base_resilience)

	# Charisma
	t.base_crowd_hype_increment = rules.calc_crowd_hype_increment(t.base_charisma)
	t.base_intimidation_resistance = rules.calc_intimidation_resistance(t.base_charisma)

	# Meta
	t.base_primary_damage_reduction = 0.0
	t.base_essence_potency = rules.calc_essence_potency(
		t.base_vitality, t.base_precision, t.base_charisma
	)
