class_name MonsterTemplate
extends Resource

## Static arena opponent. No training, no lessons, no weekly progression.
## Shares combat secondaries with GladiatorTemplate for consistent math.

# Identification
@export var id: StringName = &""
@export var display_name: String = ""
@export var tier: int = 1
@export var flavour: String = ""
@export var is_alive: bool = true

# Visuals (optional for now)
@export var visual_key: String = "placeholder_monster"
@export var portrait: Texture2D
@export var sprite_texture: Texture2D

#region Primary Attributes
@export var vitality: int = 12
@export var endurance: int = 12
@export var strength: int = 12
@export var agility: int = 12
@export var precision: int = 12
@export var resilience: int = 12
@export var charisma: int = 10
## Fixed value — monsters do not have Base/Current split.
@export var cunning: float = 5.0
#endregion

#region Combat Secondaries (baked at creation)
@export var max_health: int = 160
@export var current_health: int = 160
@export var max_stamina: int = 80
@export var current_stamina: int = 80
@export var stamina_regen: float = 2.5
@export var fatigue_resistance: float = 5.0
@export var base_damage: int = 20
@export var ability_power: int = 20
@export var attack_speed: float = 1.05
@export var dodge_chance: float = 6.0
@export var accuracy: float = 85.0
@export var crit_chance: float = 7.0
@export var crit_multiplier: float = 1.75
@export var crit_defense_factor: float = 1.4
@export var status_resistance: float = 24.0
@export var crowd_hype_increment: float = 8.0
@export var intimidation_resistance: float = 15.0
@export var primary_damage_reduction: float = 0.0
#endregion

#region Combat Identity
## e.g. [&"heavy_hide", &"aerial"]
@export var vulnerability_tags: Array[StringName] = []
## Engine stance the monster prefers (aggressive / defensive / evasive)
@export var preferred_stance: StringName = &"aggressive"
## Simple behaviour flag used by the decision loop
@export var ai_bias: StringName = &"aggressive"
#endregion

# Runtime
var stance_timer: float = 0.0

signal health_changed(new_health: int)
signal stamina_changed(new_stamina: int)
signal stance_changed(new_stance: String)
signal character_defeated


# ─────────────────────────────────────────────
# Vulnerability tag constants
# ─────────────────────────────────────────────
const TAG_HEAVY_HIDE := &"heavy_hide"
const TAG_REACH_ADVANTAGE := &"reach_advantage"
const TAG_WEAK_POINTS := &"weak_points"
const TAG_SWARM := &"swarm"
const TAG_AERIAL := &"aerial"
const TAG_POISON_STATUS := &"poison_status"


func get_display_name() -> String:
	if display_name != "":
		return display_name
	return str(id) if id != &"" else "Unknown Beast"


func reset_for_battle() -> void:
	current_health = max_health
	current_stamina = max_stamina
	is_alive = true
	stance_timer = 0.0


func create_runtime_data() -> MonsterTemplate:
	var runtime := duplicate(true) as MonsterTemplate
	runtime.reset_for_battle()
	return runtime


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health)
	if current_health <= 0:
		is_alive = false
		character_defeated.emit()


## Bake combat secondaries from the current primaries using the shared formulas.
func bake_secondaries() -> void:
	max_health = (vitality * 12) + 40
	current_health = max_health
	max_stamina = (endurance * 6) + 20
	current_stamina = max_stamina
	stamina_regen = endurance * 0.25
	fatigue_resistance = endurance * 0.5
	base_damage = int((strength * 1.5) + 5)
	ability_power = strength * 2
	attack_speed = 0.8 + (agility * 0.025)
	dodge_chance = agility * 0.6
	accuracy = 75.0 + (precision * 1.0)
	crit_chance = precision * 0.7
	crit_multiplier = 1.5 + (precision * 0.025)
	crit_defense_factor = 1.0 + (resilience * 0.04)
	status_resistance = resilience * 2.4
	crowd_hype_increment = charisma * 0.8
	intimidation_resistance = charisma * 1.5
	# primary_damage_reduction stays whatever was set (usually 0)


# ─────────────────────────────────────────────
# Prototype factories (the four locked archetypes)
# ─────────────────────────────────────────────

static func create_dire_boar() -> MonsterTemplate:
	var m := MonsterTemplate.new()
	m.id = &"dire_boar"
	m.display_name = "Dire Boar"
	m.tier = 1
	m.flavour = "A heavy charging beast with thick hide."
	m.vitality = randi_range(16, 22)
	m.endurance = randi_range(14, 18)
	m.strength = randi_range(18, 24)
	m.agility = randi_range(8, 12)
	m.precision = randi_range(8, 11)
	m.resilience = randi_range(14, 18)
	m.charisma = randi_range(6, 10)
	m.cunning = randf_range(3.0, 6.0)
	m.vulnerability_tags = [TAG_HEAVY_HIDE, TAG_REACH_ADVANTAGE]
	m.preferred_stance = &"aggressive"
	m.ai_bias = &"aggressive"
	m.bake_secondaries()
	return m


static func create_giant_spider() -> MonsterTemplate:
	var m := MonsterTemplate.new()
	m.id = &"giant_spider"
	m.display_name = "Giant Spider"
	m.tier = 1
	m.flavour = "Mobile and venomous. Prefers hit-and-run."
	m.vitality = randi_range(12, 16)
	m.endurance = randi_range(13, 17)
	m.strength = randi_range(11, 15)
	m.agility = randi_range(18, 24)
	m.precision = randi_range(14, 18)
	m.resilience = randi_range(9, 13)
	m.charisma = randi_range(5, 9)
	m.cunning = randf_range(5.0, 9.0)
	m.vulnerability_tags = [TAG_SWARM, TAG_POISON_STATUS]
	m.preferred_stance = &"evasive"
	m.ai_bias = &"cunning"
	m.bake_secondaries()
	return m


static func create_armoured_minotaur() -> MonsterTemplate:
	var m := MonsterTemplate.new()
	m.id = &"armoured_minotaur"
	m.display_name = "Armoured Minotaur"
	m.tier = 2
	m.flavour = "A living wall of muscle and plate."
	m.vitality = randi_range(22, 28)
	m.endurance = randi_range(16, 20)
	m.strength = randi_range(22, 28)
	m.agility = randi_range(7, 11)
	m.precision = randi_range(9, 13)
	m.resilience = randi_range(18, 24)
	m.charisma = randi_range(8, 12)
	m.cunning = randf_range(4.0, 7.0)
	m.vulnerability_tags = [TAG_HEAVY_HIDE, TAG_WEAK_POINTS]
	m.preferred_stance = &"defensive"
	m.ai_bias = &"defensive"
	m.bake_secondaries()
	return m


static func create_harpy() -> MonsterTemplate:
	var m := MonsterTemplate.new()
	m.id = &"harpy"
	m.display_name = "Harpy"
	m.tier = 2
	m.flavour = "Aerial skirmisher that stays out of reach."
	m.vitality = randi_range(11, 15)
	m.endurance = randi_range(14, 18)
	m.strength = randi_range(10, 14)
	m.agility = randi_range(20, 26)
	m.precision = randi_range(15, 19)
	m.resilience = randi_range(8, 12)
	m.charisma = randi_range(14, 18)
	m.cunning = randf_range(8.0, 12.0)
	m.vulnerability_tags = [TAG_AERIAL, TAG_REACH_ADVANTAGE]
	m.preferred_stance = &"evasive"
	m.ai_bias = &"cunning"
	m.bake_secondaries()
	return m


## Simple tier-based random pick for calendar generation.
static func get_random_for_tier(max_tier: int) -> MonsterTemplate:
	var pool: Array[Callable] = []
	if max_tier >= 1:
		pool.append(create_dire_boar)
		pool.append(create_giant_spider)
	if max_tier >= 2:
		pool.append(create_armoured_minotaur)
		pool.append(create_harpy)
	# Later tiers can be added here
	if pool.is_empty():
		return create_dire_boar()
	var choice: Callable = pool[randi() % pool.size()]
	return choice.call()
