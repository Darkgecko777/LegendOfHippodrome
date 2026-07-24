class_name CharacterTemplate
extends Resource

# Identification
@export var character_id: String = ""
@export var display_name: String = ""
@export var species_or_class: String = "Human"
@export var is_alive: bool = true
@export var is_monster: bool = false

# Visuals
@export var visual_key: String = "placeholder_gladiator"
@export var portrait: Texture2D
@export var sprite_texture: Texture2D

#region Primary Attributes (rarely changed after generation)
@export var base_vitality: int = 10
@export var base_endurance: int = 10
@export var base_strength: int = 10
@export var base_agility: int = 10
@export var base_precision: int = 10
@export var base_resilience: int = 10
@export var base_charisma: int = 10
#endregion

#region Cunning (main long-term progression)
## How intelligently the combat AI applies decisions. Starting range 2–10, no hard ceiling.
@export var base_cunning: float = 5.0
#endregion

#region Vitality Secondaries (baked at generation)
@export var base_max_health: int = 160
@export var current_health: int = 160
## % chance per week to recover from injury (Vitality / 2), cumulative.
@export var base_injury_recovery_chance: float = 5.0
#endregion

#region Endurance Secondaries (baked at generation)
@export var base_max_stamina: int = 80
@export var current_stamina: int = 80
@export var base_stamina_regen: float = 2.5
## Soft reduction in stamina costs under rapid-attack pressure (Endurance × 0.5%).
@export var base_fatigue_resistance: float = 5.0
#endregion

#region Strength Secondaries (baked at generation)
@export var base_damage: int = 20
@export var base_ability_power: int = 20
#endregion

#region Agility Secondaries (baked at generation)
## Multiplier applied to ability base speeds.
@export var base_attack_speed: float = 1.05
@export var base_dodge_chance: float = 6.0
#endregion

#region Precision Secondaries (baked at generation)
@export var base_accuracy: float = 85.0
@export var base_crit_chance: float = 7.0
@export var base_crit_multiplier: float = 1.75
#endregion

#region Resilience Secondaries (baked at generation)
## Divisor applied to bonus crit damage: bonus / crit_defense_factor.
## Formula: 1.0 + (Resilience × 0.04)
@export var base_crit_defense_factor: float = 1.4
@export var base_status_resistance: float = 24.0
#endregion

#region Charisma Secondaries (baked at generation)
## Value added to crowd hype on each notable moment (capped by crowd size).
@export var base_crowd_hype_increment: float = 8.0
@export var base_intimidation_resistance: float = 15.0
#endregion

#region Defense & Meta
## Gear-only. Starts at 0; set by equipment later.
@export var base_primary_damage_reduction: float = 0.0
## Vitality + Precision + Charisma (further modified by play conditions).
@export var base_essence_potency: float = 30.0
#endregion

#region Personality (string enums for now)
@export var combat_personality: String = "Balanced"
@export var noncombat_personality: String = "Stoic"
#endregion

#region Weapon Preference & Skills
## Exactly one preferred weapon type assigned at generation.
@export var preferred_weapon: StringName = &"gladius"
## Skill multiplier per weapon type. Starts with a modest value in the preferred weapon.
@export var weapon_skills: Dictionary = {}
#endregion

# Combat Abilities
@export var abilities: Array[Ability] = []

# Runtime-only helpers (not required to be exported)
var stance_timer: float = 0.0

# Signals
signal health_changed(new_health: int)
signal stamina_changed(new_stamina: int)
signal stance_changed(new_stance: String)
signal character_defeated


func get_display_name() -> String:
	if display_name != "":
		return display_name
	return character_id if character_id != "" else "Unnamed"


## Reset combat-volatile values before a fight. Does not touch roster-persistent data.
func reset_for_battle() -> void:
	current_health = base_max_health
	current_stamina = base_max_stamina
	is_alive = true
	stance_timer = 0.0


## Returns a duplicate suitable for combat so the roster copy stays clean.
func create_runtime_data() -> CharacterTemplate:
	var runtime := duplicate(true) as CharacterTemplate
	runtime.reset_for_battle()
	return runtime


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	if current_health <= 0:
		is_alive = false
		character_defeated.emit()
