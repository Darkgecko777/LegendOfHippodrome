class_name CombatResolver
extends RefCounted

## Full Declare → Reveal → Resolve combat engine.
## Produces a structured, filterable log and a final result.

# Input
var gladiator: GladiatorTemplate
var monster: MonsterTemplate
var intervention_level: int = 0
var knowledge_revealed: bool = false
var max_exchanges: int = 40          # safety only; fight is to the death

# Output
var log_events: Array[Dictionary] = []
var winner: StringName = &""         # &"gladiator", &"monster"
var final_gladiator_health: int = 0
var final_monster_health: int = 0
var gold_reward: int = 0
var fame_reward: int = 0

# Internal runtime state
var _g_stance: StringName = &"aggressive"
var _m_stance: StringName = &"aggressive"
var _g_kit: Dictionary = {}
var _m_kit: Dictionary = {}
var _g_cooldowns: Dictionary = {}    # ability id -> remaining exchanges
var _m_cooldowns: Dictionary = {}
var _g_stamina: float = 0.0
var _m_stamina: float = 0.0
var _g_health: int = 0
var _m_health: int = 0
var _exchange: int = 0
var _g_poor_results: int = 0
var _m_poor_results: int = 0
var _g_stamina_triggered: bool = false
var _m_stamina_triggered: bool = false

# Stance passives (from locked design)
const STANCE_MODS := {
	&"aggressive": {
		"stamina_recovery": 0.60,
		"damage": 1.20,
		"crit": 8.0,
		"accuracy": -5.0,
		"dodge": -8.0,
		"resistance": -10.0,
		"initiative": 0,
		"read_mod": -15.0,
	},
	&"defensive": {
		"stamina_recovery": 1.40,
		"damage": 0.85,
		"crit": -4.0,
		"accuracy": 0.0,
		"dodge": 0.0,
		"resistance": 15.0,
		"initiative": -5,
		"read_mod": 0.0,
	},
	&"evasive": {
		"stamina_recovery": 1.00,
		"damage": 0.90,
		"crit": 0.0,
		"accuracy": 8.0,
		"dodge": 12.0,
		"resistance": -5.0,
		"initiative": 5,
		"read_mod": 15.0,
	},
}


func resolve() -> void:
	log_events.clear()
	_setup()
	_emit(&"fight_start", &"narrative", "%s vs %s" % [gladiator.get_display_name(), monster.get_display_name()], {})

	while _g_health > 0 and _m_health > 0 and _exchange < max_exchanges:
		_exchange += 1
		_run_exchange()

	_finish()


func _setup() -> void:
	_g_health = gladiator.base_max_health
	_m_health = monster.max_health
	_g_stamina = float(gladiator.base_max_stamina)
	_m_stamina = float(monster.max_stamina)
	_g_stance = &"aggressive"
	_m_stance = monster.preferred_stance if monster.preferred_stance != &"" else &"aggressive"

	var weapon_id: StringName = &"gladius"
	if gladiator.assigned_weapon != null:
		weapon_id = gladiator.assigned_weapon.id
	_g_kit = AbilityLibrary.get_kit_for_weapon(weapon_id)
	_m_kit = AbilityLibrary.get_kit_for_monster(monster.id)

	_g_cooldowns.clear()
	_m_cooldowns.clear()
	_g_poor_results = 0
	_m_poor_results = 0
	_g_stamina_triggered = false
	_m_stamina_triggered = false


func _run_exchange() -> void:
	_emit(&"exchange_start", &"narrative", "— Exchange %d —" % _exchange, {"exchange": _exchange})

	# 1. Declare
	var g_ability: Ability = _choose_ability(true)
	var m_ability: Ability = _choose_ability(false)

	_emit(&"declaration", &"narrative", "%s declares %s (%s)" % [gladiator.get_display_name(), g_ability.display_name, _g_stance.capitalize()], {"actor": "gladiator"})
	_emit(&"declaration", &"narrative", "%s declares %s (%s)" % [monster.get_display_name(), m_ability.display_name, _m_stance.capitalize()], {"actor": "monster"})

	# 2. Initiative
	var g_init: float = _calc_initiative(true, g_ability)
	var m_init: float = _calc_initiative(false, m_ability)
	var gladiator_first: bool = g_init >= m_init

	_emit(&"initiative", &"decision", "Initiative: %s %.0f vs %s %.0f → %s reveals first" % [
		gladiator.get_display_name(), g_init,
		monster.get_display_name(), m_init,
		gladiator.get_display_name() if gladiator_first else monster.get_display_name()
	], {})

	# 3. Reveal + possible reaction
	if gladiator_first:
		_emit(&"reveal_order", &"decision", "%s is revealed first." % gladiator.get_display_name(), {})
		_try_reaction(false, m_ability, g_ability)
	else:
		_emit(&"reveal_order", &"decision", "%s is revealed first." % monster.get_display_name(), {})
		_try_reaction(true, g_ability, m_ability)

	# Re-fetch abilities in case a reaction changed them
	var g_refetched = _g_kit.get(_g_stance, g_ability)
	var m_refetched = _m_kit.get(_m_stance, m_ability)
	if g_refetched is Ability:
		g_ability = g_refetched
	if m_refetched is Ability:
		m_ability = m_refetched

	# 4. Resolve in initiative order
	if gladiator_first:
		_resolve_action(true, g_ability)
		if _m_health > 0:
			_resolve_action(false, m_ability)
	else:
		_resolve_action(false, m_ability)
		if _g_health > 0:
			_resolve_action(true, g_ability)

	# 5. Stamina recovery
	_apply_stamina_recovery(true)
	_apply_stamina_recovery(false)

	# 6. Tick cooldowns
	_tick_cooldowns(true)
	_tick_cooldowns(false)


func _choose_ability(is_gladiator: bool) -> Ability:
	var kit: Dictionary = _g_kit if is_gladiator else _m_kit
	var stance: StringName = _g_stance if is_gladiator else _m_stance
	var cds: Dictionary = _g_cooldowns if is_gladiator else _m_cooldowns
	var stamina: float = _g_stamina if is_gladiator else _m_stamina

	var ability: Ability = kit.get(stance) as Ability
	if ability == null:
		var vals: Array = kit.values()
		if vals.size() > 0:
			ability = vals[0] as Ability
	if ability == null:
		# Absolute fallback so the fight never crashes
		ability = Ability.create(&"basic", "Basic Attack", &"aggressive", 10, 0, &"standard", false, 1.0)

	if cds.get(ability.id, 0) > 0 or stamina < ability.stamina_cost:
		for s in [&"defensive", &"evasive", &"aggressive"]:
			var alt: Ability = kit.get(s) as Ability
			if alt != null and cds.get(alt.id, 0) <= 0 and stamina >= alt.stamina_cost:
				if is_gladiator:
					_g_stance = s
				else:
					_m_stance = s
				return alt
	return ability


func _calc_initiative(is_gladiator: bool, ability: Ability) -> float:
	var agi: float
	var prec: float
	var stance: StringName
	if is_gladiator:
		agi = float(gladiator.base_agility)
		prec = float(gladiator.base_precision)
		stance = _g_stance
	else:
		agi = float(monster.agility)
		prec = float(monster.precision)
		stance = _m_stance

	var value: float = (agi * 2.0) + (prec * 0.5) + randf_range(0.0, 15.0)
	var stance_init = STANCE_MODS[stance]["initiative"]
	value += float(stance_init)

	match ability.commitment:
		&"low":
			value += randf_range(0.0, 8.0)
		&"high":
			value -= randf_range(12.0, 25.0)
		_:
			pass
	return value


func _try_reaction(is_gladiator: bool, _own_ability: Ability, opponent_ability: Ability) -> void:
	var trigger: StringName = _find_trigger(is_gladiator, opponent_ability)
	if trigger == &"":
		return

	var cunning: float = gladiator.current_cunning if is_gladiator else monster.cunning
	var success_chance: float = clampf(cunning * 6.0, 15.0, 85.0)
	var opp_stance: StringName = _m_stance if is_gladiator else _g_stance
	success_chance += float(STANCE_MODS[opp_stance]["read_mod"])
	success_chance = clampf(success_chance, 5.0, 95.0)

	var roll: float = randf() * 100.0
	var success: bool = roll < success_chance

	var actor_name: String = gladiator.get_display_name() if is_gladiator else monster.get_display_name()
	_emit(&"cunning_check", &"decision", "%s Cunning check (%.0f%%) on trigger '%s': %s" % [
		actor_name, success_chance, trigger, "SUCCESS" if success else "FAIL"
	], {"success": success, "trigger": trigger})

	if success:
		var new_stance: StringName = _pick_counter_stance(opp_stance)
		var kit: Dictionary = _g_kit if is_gladiator else _m_kit
		var new_ability: Ability = kit.get(new_stance) as Ability
		if new_ability != null:
			if is_gladiator:
				_g_stance = new_stance
			else:
				_m_stance = new_stance
			_emit(&"thought_bubble", &"narrative", "%s (Green): \"I see it — switch to %s.\"" % [actor_name, new_ability.display_name], {"colour": "green"})
			_emit(&"reaction", &"decision", "%s reacts → %s (%s)" % [actor_name, new_ability.display_name, new_stance.capitalize()], {})
			_emit(&"stance_change", &"decision", "%s stance is now %s" % [actor_name, new_stance.capitalize()], {})
	else:
		_emit(&"thought_bubble", &"narrative", "%s (White): \"Stay the course.\"" % actor_name, {"colour": "white"})


func _find_trigger(is_gladiator: bool, opponent_ability: Ability) -> StringName:
	if opponent_ability.is_telegraphed:
		return &"telegraphed_ability"

	var stamina: float = _g_stamina if is_gladiator else _m_stamina
	var max_stam: float = float(gladiator.base_max_stamina) if is_gladiator else float(monster.max_stamina)
	var already: bool = _g_stamina_triggered if is_gladiator else _m_stamina_triggered
	if not already and stamina < max_stam * 0.35:
		if is_gladiator:
			_g_stamina_triggered = true
		else:
			_m_stamina_triggered = true
		return &"stamina_critical"

	var poor: int = _g_poor_results if is_gladiator else _m_poor_results
	if poor >= 2:
		return &"stance_failing"

	return &""


func _pick_counter_stance(opponent_stance: StringName) -> StringName:
	match opponent_stance:
		&"aggressive":
			return &"evasive"
		&"defensive":
			return &"aggressive"
		&"evasive":
			return &"defensive"
		_:
			return &"defensive"


func _resolve_action(is_gladiator: bool, ability: Ability) -> void:
	var actor_name: String = gladiator.get_display_name() if is_gladiator else monster.get_display_name()
	var target_name: String = monster.get_display_name() if is_gladiator else gladiator.get_display_name()
	var stance: StringName = _g_stance if is_gladiator else _m_stance
	var mods: Dictionary = STANCE_MODS[stance]

	# Stamina cost
	if is_gladiator:
		_g_stamina = maxf(0.0, _g_stamina - float(ability.stamina_cost))
	else:
		_m_stamina = maxf(0.0, _m_stamina - float(ability.stamina_cost))
	_emit(&"stamina_spent", &"resource", "%s spends %d stamina (now %.0f)" % [actor_name, ability.stamina_cost, _g_stamina if is_gladiator else _m_stamina], {})

	# Cooldown
	if ability.cooldown_exchanges > 0:
		var cds: Dictionary = _g_cooldowns if is_gladiator else _m_cooldowns
		cds[ability.id] = ability.cooldown_exchanges
		_emit(&"cooldown_started", &"resource", "%s — %s on cooldown for %d exchanges" % [actor_name, ability.display_name, ability.cooldown_exchanges], {})

	# Accuracy
	var base_acc: float
	var base_dodge: float
	if is_gladiator:
		base_acc = gladiator.base_accuracy + ability.accuracy_modifier + float(mods["accuracy"])
		base_dodge = monster.dodge_chance + float(STANCE_MODS[_m_stance]["dodge"])
	else:
		base_acc = monster.accuracy + ability.accuracy_modifier + float(mods["accuracy"])
		base_dodge = gladiator.base_dodge_chance + float(STANCE_MODS[_g_stance]["dodge"])

	var hit_chance: float = clampf(base_acc - base_dodge, 5.0, 95.0)
	var roll: float = randf() * 100.0
	_emit(&"accuracy_roll", &"debug", "%s accuracy %.0f vs dodge %.0f → %.0f%% (roll %.0f)" % [actor_name, base_acc, base_dodge, hit_chance, roll], {})

	if roll > hit_chance:
		_emit(&"miss", &"result", "%s misses with %s." % [actor_name, ability.display_name], {})
		_emit(&"dodge", &"result", "%s avoids the attack." % target_name, {})
		if is_gladiator:
			_g_poor_results += 1
		else:
			_m_poor_results += 1
		return

	# Hit
	var is_crit: bool = false
	var crit_chance: float
	if is_gladiator:
		crit_chance = gladiator.base_crit_chance + ability.crit_modifier + float(mods["crit"])
	else:
		crit_chance = monster.crit_chance + ability.crit_modifier + float(mods["crit"])
	if randf() * 100.0 < crit_chance:
		is_crit = true

	var base_dmg: float
	if is_gladiator:
		base_dmg = float(gladiator.base_damage)
	else:
		base_dmg = float(monster.base_damage)

	var dmg: float = base_dmg * ability.damage_multiplier * float(mods["damage"])
	if is_crit:
		var crit_mult: float = gladiator.base_crit_multiplier if is_gladiator else monster.crit_multiplier
		dmg *= crit_mult

	# Resistance
	var resistance: float
	if is_gladiator:
		resistance = float(STANCE_MODS[_m_stance]["resistance"])
	else:
		resistance = float(STANCE_MODS[_g_stance]["resistance"])
	dmg *= (1.0 - resistance / 100.0)
	dmg = maxf(1.0, dmg)

	var final_dmg: int = int(round(dmg))
	if is_gladiator:
		_m_health = max(0, _m_health - final_dmg)
	else:
		_g_health = max(0, _g_health - final_dmg)

	if is_crit:
		_emit(&"critical_hit", &"result", "%s lands a CRITICAL %s on %s for %d damage!" % [actor_name, ability.display_name, target_name, final_dmg], {})
	else:
		_emit(&"hit", &"result", "%s hits %s with %s for %d damage." % [actor_name, target_name, ability.display_name, final_dmg], {})

	_emit(&"damage", &"result", "%s health is now %d" % [target_name, _m_health if is_gladiator else _g_health], {})

	if is_gladiator:
		_g_poor_results = 0
	else:
		_m_poor_results = 0

	if (is_gladiator and _m_health <= 0) or (not is_gladiator and _g_health <= 0):
		_emit(&"death", &"result", "%s has fallen!" % target_name, {})


func _apply_stamina_recovery(is_gladiator: bool) -> void:
	var stance: StringName = _g_stance if is_gladiator else _m_stance
	var base_regen: float
	var max_stam: float
	if is_gladiator:
		base_regen = gladiator.base_stamina_regen
		max_stam = float(gladiator.base_max_stamina)
	else:
		base_regen = monster.stamina_regen
		max_stam = float(monster.max_stamina)

	var recovered: float = base_regen * float(STANCE_MODS[stance]["stamina_recovery"])
	if is_gladiator:
		_g_stamina = minf(max_stam, _g_stamina + recovered)
	else:
		_m_stamina = minf(max_stam, _m_stamina + recovered)

	_emit(&"stamina_recovered", &"resource", "%s recovers %.1f stamina (now %.0f)" % [
		gladiator.get_display_name() if is_gladiator else monster.get_display_name(),
		recovered,
		_g_stamina if is_gladiator else _m_stamina
	], {})


func _tick_cooldowns(is_gladiator: bool) -> void:
	var cds: Dictionary = _g_cooldowns if is_gladiator else _m_cooldowns
	var to_erase: Array = []
	for id in cds.keys():
		cds[id] = int(cds[id]) - 1
		if int(cds[id]) <= 0:
			to_erase.append(id)
			_emit(&"cooldown_ready", &"resource", "%s is ready again." % str(id), {})
	for id in to_erase:
		cds.erase(id)


func _finish() -> void:
	final_gladiator_health = _g_health
	final_monster_health = _m_health

	if _g_health <= 0 and _m_health <= 0:
		winner = &"draw"
	elif _m_health <= 0:
		winner = &"gladiator"
	else:
		winner = &"monster"

	var base_gold: int = 80 + (_exchange * 3)
	var base_fame: int = 8 + int(_exchange / 2)
	var mults: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.1]
	var mult: float = mults[clampi(intervention_level, 0, 4)]
	gold_reward = int(float(base_gold) * mult) if winner == &"gladiator" else 0
	fame_reward = int(float(base_fame) * mult) if winner == &"gladiator" else 0

	var winner_name: String = gladiator.get_display_name() if winner == &"gladiator" else monster.get_display_name()
	_emit(&"fight_end", &"narrative", "Fight over — %s is victorious after %d exchanges." % [winner_name, _exchange], {})
	if winner == &"gladiator":
		_emit(&"fight_end", &"narrative", "Rewards: %d gold, %d fame (Intervention level %d)." % [gold_reward, fame_reward, intervention_level], {})


func _emit(type: StringName, category: StringName, text: String, data: Dictionary) -> void:
	log_events.append({
		"type": type,
		"category": category,
		"exchange": _exchange,
		"text": text,
		"data": data,
	})
