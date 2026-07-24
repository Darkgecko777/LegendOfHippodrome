class_name MarketState
extends Resource

## Holds the current week's market offers and handles refresh + purchase helpers.
## Price for gladiators is generated here (100 ± 15%); gear prices are fixed.

const GLADIATOR_BASE_PRICE := 100
const GLADIATOR_PRICE_VARIANCE := 0.15
const MAX_GLADIATOR_OFFERS := 5

var gladiator_offers: Array[Dictionary] = []   # { "template": CharacterTemplate, "price": int }
var weapon_offers: Array[WeaponData] = []
var training_offers: Array[TrainingEquipment] = []


func _init() -> void:
	_ensure_tier1_gear()


## Call at the start of each week (or on first open).
func refresh_weekly(generator: Node) -> void:
	_refresh_gladiators(generator)
	_ensure_tier1_gear()


func _refresh_gladiators(generator: Node) -> void:
	gladiator_offers.clear()
	if generator == null or not generator.has_method("generate_gladiator"):
		push_error("MarketState: Invalid generator.")
		return
	for i in MAX_GLADIATOR_OFFERS:
		var template: CharacterTemplate = generator.generate_gladiator()
		if template == null:
			continue
		var price := _roll_gladiator_price()
		gladiator_offers.append({
			"template": template,
			"price": price
		})


func _roll_gladiator_price() -> int:
	var variance := GLADIATOR_BASE_PRICE * GLADIATOR_PRICE_VARIANCE
	var min_p := int(GLADIATOR_BASE_PRICE - variance)
	var max_p := int(GLADIATOR_BASE_PRICE + variance)
	# Round to nearest 5 for cleaner numbers
	var raw := randi_range(min_p, max_p)
	return int(round(float(raw) / 5.0) * 5)


func _ensure_tier1_gear() -> void:
	weapon_offers.clear()
	weapon_offers.append(WeaponData.create(&"gladius", "Gladius", 1, 75, "Classic short sword, balanced and reliable."))
	weapon_offers.append(WeaponData.create(&"spear", "Spear", 1, 75, "Reach weapon, strong against beasts."))
	weapon_offers.append(WeaponData.create(&"trident", "Trident", 1, 75, "Iconic and slightly specialised."))
	weapon_offers.append(WeaponData.create(&"net", "Net", 1, 75, "Control and showmanship option."))

	training_offers.clear()
	training_offers.append(TrainingEquipment.create(
		&"wooden_dummy", "Wooden Dummy", &"weapon",
		[&"weapon_skill"], 1, 250,
		"Trains the chosen weapon skill.", 0.0, 0.0))
	training_offers.append(TrainingEquipment.create(
		&"weighted_vest", "Weighted Vest", &"endurance",
		[&"max_stamina", &"stamina_regen", &"fatigue_resistance"], 1, 250,
		"Endurance conditioning.", 0.0, 0.0))
	training_offers.append(TrainingEquipment.create(
		&"heavy_sandbag", "Heavy Sandbag", &"strength",
		[&"base_damage", &"ability_power"], 1, 250,
		"Strength and power work.", 0.0, 0.0))
	training_offers.append(TrainingEquipment.create(
		&"balance_beam", "Balance Beam", &"agility",
		[&"attack_speed", &"dodge_chance"], 1, 250,
		"Footwork and speed.", 0.0, 0.0))
	training_offers.append(TrainingEquipment.create(
		&"precision_target", "Precision Target", &"precision",
		[&"accuracy", &"crit_chance", &"crit_multiplier"], 1, 250,
		"Aim and timing.", 0.0, 0.0))
	training_offers.append(TrainingEquipment.create(
		&"iron_hide_drills", "Iron Hide Drills", &"resilience",
		[&"crit_defense_factor", &"status_resistance"], 1, 250,
		"Toughness and pain tolerance.", 0.0, 0.0))
	training_offers.append(TrainingEquipment.create(
		&"vitality_circuit", "Vitality Circuit", &"vitality",
		[&"max_health", &"injury_recovery_chance"], 1, 250,
		"Conditioning and recovery.", 0.0, 0.0))
	training_offers.append(TrainingEquipment.create(
		&"strategy_table", "Strategy Table", &"cunning",
		[], 1, 250,
		"Mental training — the core progression pillar.", 0.8, 1.2))
	training_offers.append(TrainingEquipment.create(
		&"arena_presence", "Arena Presence Training", &"charisma",
		[&"crowd_hype_increment", &"intimidation_resistance"], 1, 250,
		"Presence and crowd command.", 0.0, 0.0))
	# Medic
	training_offers.append(TrainingEquipment.create(
		&"medic", "Medic", &"recovery",
		[], 1, 200,
		"Increases injury recovery chance for the assigned gladiator this week.",
		0.0, 0.0, true, 1.75))


## Remove a gladiator offer by index after purchase.
func remove_gladiator_offer(index: int) -> void:
	if index >= 0 and index < gladiator_offers.size():
		gladiator_offers.remove_at(index)
