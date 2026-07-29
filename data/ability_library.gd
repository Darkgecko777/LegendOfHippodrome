class_name AbilityLibrary
extends RefCounted

## Hard-coded first kits. One ability per stance for the prototype weapons and monsters.
## Later these can be moved to .tres resources created in the editor.

static func get_gladius_kit() -> Dictionary:
	# stance -> Ability
	return {
		&"aggressive": Ability.create(&"wolf_advance", "Wolf's Advance", &"aggressive", 14, 0, &"standard", false, 1.20, 0.0, 6.0, [&"thrust"]),
		&"defensive":  Ability.create(&"iron_wall", "Iron Wall", &"defensive", 10, 0, &"low", false, 0.75, 0.0, 0.0, [&"guard"]),
		&"evasive":    Ability.create(&"viper_coil", "Viper's Coil", &"evasive", 12, 0, &"low", false, 0.90, 10.0, 0.0, [&"counter", &"thrust"]),
	}


static func get_spear_kit() -> Dictionary:
	return {
		&"aggressive": Ability.create(&"boar_thrust", "Boar's Thrust", &"aggressive", 18, 1, &"high", true, 1.35, -5.0, 4.0, [&"thrust", &"reach"]),
		&"defensive":  Ability.create(&"hedge_of_points", "Hedge of Points", &"defensive", 11, 0, &"standard", false, 0.80, 5.0, 0.0, [&"guard", &"reach"]),
		&"evasive":    Ability.create(&"serpent_withdraw", "Serpent's Withdraw", &"evasive", 13, 0, &"low", false, 0.85, 8.0, 0.0, [&"counter", &"reach"]),
	}


static func get_dire_boar_kit() -> Dictionary:
	return {
		&"aggressive": Ability.create(&"thunder_charge", "Thunder Charge", &"aggressive", 22, 2, &"high", true, 1.45, -8.0, 0.0, [&"charge"]),
		&"defensive":  Ability.create(&"braced_hide", "Braced Hide", &"defensive", 8, 0, &"low", false, 0.70, 0.0, 0.0, [&"guard"]),
		&"evasive":    Ability.create(&"side_lunge", "Side Lunge", &"evasive", 14, 0, &"standard", false, 1.00, 6.0, 0.0, [&"counter"]),
	}


static func get_giant_spider_kit() -> Dictionary:
	return {
		&"aggressive": Ability.create(&"venom_lunge", "Venom Lunge", &"aggressive", 15, 1, &"standard", false, 1.10, 0.0, 0.0, [&"thrust"]),
		&"defensive":  Ability.create(&"leg_guard", "Leg Guard", &"defensive", 9, 0, &"low", false, 0.65, 0.0, 0.0, [&"guard"]),
		&"evasive":    Ability.create(&"skitter", "Skitter", &"evasive", 11, 0, &"low", false, 0.80, 12.0, 0.0, [&"counter"]),
	}


static func get_armoured_minotaur_kit() -> Dictionary:
	return {
		&"aggressive": Ability.create(&"crushing_blow", "Crushing Blow", &"aggressive", 20, 2, &"high", true, 1.50, -10.0, 0.0, [&"crush"]),
		&"defensive":  Ability.create(&"plate_wall", "Plate Wall", &"defensive", 7, 0, &"low", false, 0.60, 0.0, 0.0, [&"guard"]),
		&"evasive":    Ability.create(&"shoulder_check", "Shoulder Check", &"evasive", 13, 0, &"standard", false, 0.95, 0.0, 0.0, [&"counter"]),
	}


static func get_harpy_kit() -> Dictionary:
	return {
		&"aggressive": Ability.create(&"talon_flurry", "Talon Flurry", &"aggressive", 16, 1, &"standard", false, 1.15, 5.0, 0.0, [&"sweep"]),
		&"defensive":  Ability.create(&"wing_guard", "Wing Guard", &"defensive", 10, 0, &"low", false, 0.70, 0.0, 0.0, [&"guard"]),
		&"evasive":    Ability.create(&"dive_and_wheel", "Dive and Wheel", &"evasive", 14, 1, &"high", true, 1.05, 8.0, 0.0, [&"dive", &"counter"]),
	}


static func get_kit_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"spear", &"trident":
			return get_spear_kit()
		_:
			return get_gladius_kit()  # default / gladius / short sword


static func get_kit_for_monster(monster_id: StringName) -> Dictionary:
	match monster_id:
		&"dire_boar":
			return get_dire_boar_kit()
		&"giant_spider":
			return get_giant_spider_kit()
		&"armoured_minotaur":
			return get_armoured_minotaur_kit()
		&"harpy":
			return get_harpy_kit()
		_:
			return get_dire_boar_kit()
