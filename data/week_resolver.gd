class_name WeekResolver
extends RefCounted

## Resolves one week of training / recovery / cunning decay for the entire roster.
## Returns a plain-language summary array for the Weekly Summary pop-out.

const SECONDARY_GAINS := {
	&"max_health": 8,
	&"injury_recovery_chance": 1.5,
	&"max_stamina": 4,
	&"stamina_regen": 0.30,
	&"fatigue_resistance": 1.0,
	&"base_damage": 2,
	&"ability_power": 3,
	&"attack_speed": 0.03,
	&"dodge_chance": 1.5,
	&"accuracy": 2.0,
	&"crit_chance": 1.0,
	&"crit_multiplier": 0.05,
	&"crit_defense_factor": 0.06,
	&"status_resistance": 3.0,
	&"crowd_hype_increment": 1.5,
	&"intimidation_resistance": 2.0,
}

const OBSERVATION_SECONDARIES: Array[StringName] = [
	&"max_health", &"max_stamina", &"accuracy", &"dodge_chance", &"crit_chance"
]


static func resolve_week(roster: Array, guild: GuildState) -> Array[String]:
	var lines: Array[String] = []
	lines.append("=== Week %d Summary ===" % guild.current_week)

	for g in roster:
		if not g is GladiatorTemplate:
			continue
		var t: GladiatorTemplate = g
		var parts: Array[String] = []

		# --- Activity resolution ---
		if t.assigned_training == null:
			# Observation
			var sec: StringName = OBSERVATION_SECONDARIES[randi() % OBSERVATION_SECONDARIES.size()]
			_apply_secondary(t, sec, 1.0)
			t.current_cunning += 0.25
			parts.append("Observation: +1 %s, +0.25 Cunning" % str(sec).capitalize())
		elif t.assigned_training.is_medic:
			# Medic — recovery handled below
			parts.append("Medic assigned (recovery boosted)")
		else:
			var item: TrainingEquipment = t.assigned_training
			if item.linked_primary == &"cunning":
				var gain := randf_range(item.cunning_gain_min, item.cunning_gain_max)
				t.current_cunning += gain
				parts.append("%s: +%.2f Cunning" % [item.display_name, gain])
			elif item.linked_primary == &"weapon":
				var wpn: StringName = t.preferred_weapon
				if t.assigned_weapon != null:
					wpn = t.assigned_weapon.id
				var skill: float = t.weapon_skills.get(wpn, 1.0)
				skill += item.weapon_skill_gain if item.weapon_skill_gain > 0.0 else 0.08
				t.weapon_skills[wpn] = skill
				parts.append("%s: +%.2f %s skill" % [item.display_name, 0.08, str(wpn).capitalize()])
			else:
				if item.possible_secondaries.size() > 0:
					var sec2: StringName = item.possible_secondaries[randi() % item.possible_secondaries.size()]
					var mag: float = SECONDARY_GAINS.get(sec2, 1.0)
					_apply_secondary(t, sec2, mag)
					parts.append("%s: +%s %s" % [item.display_name, str(mag), str(sec2).capitalize()])

		# --- Injury recovery ---
		var recovery_chance := t.base_injury_recovery_chance
		if t.assigned_training != null and t.assigned_training.is_medic:
			recovery_chance *= t.assigned_training.recovery_multiplier
		# (Actual injury state not yet tracked in v1 — just report the chance)
		parts.append("Recovery chance this week: %.1f%%" % recovery_chance)

		# --- Cunning decay toward base ---
		var diff := t.current_cunning - t.base_cunning
		if absf(diff) > 0.01:
			var step := diff * 0.08  # ~8% of the gap per week
			t.current_cunning -= step
			parts.append("Cunning drift toward base: %.2f → %.2f" % [t.current_cunning + step, t.current_cunning])

		lines.append("%s — %s" % [t.get_display_name(), "; ".join(parts)])

	guild.advance_week()
	lines.append("Advanced to Week %d." % guild.current_week)
	return lines


static func _apply_secondary(t: GladiatorTemplate, sec: StringName, magnitude: float) -> void:
	match sec:
		&"max_health":
			t.base_max_health += int(magnitude)
			t.current_health = t.base_max_health
		&"injury_recovery_chance":
			t.base_injury_recovery_chance += magnitude
		&"max_stamina":
			t.base_max_stamina += int(magnitude)
			t.current_stamina = t.base_max_stamina
		&"stamina_regen":
			t.base_stamina_regen += magnitude
		&"fatigue_resistance":
			t.base_fatigue_resistance += magnitude
		&"base_damage":
			t.base_damage += int(magnitude)
		&"ability_power":
			t.base_ability_power += int(magnitude)
		&"attack_speed":
			t.base_attack_speed += magnitude
		&"dodge_chance":
			t.base_dodge_chance += magnitude
		&"accuracy":
			t.base_accuracy += magnitude
		&"crit_chance":
			t.base_crit_chance += magnitude
		&"crit_multiplier":
			t.base_crit_multiplier += magnitude
		&"crit_defense_factor":
			t.base_crit_defense_factor += magnitude
		&"status_resistance":
			t.base_status_resistance += magnitude
		&"crowd_hype_increment":
			t.base_crowd_hype_increment += magnitude
		&"intimidation_resistance":
			t.base_intimidation_resistance += magnitude
