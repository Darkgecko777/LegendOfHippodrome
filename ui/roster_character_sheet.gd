class_name RosterCharacterSheet
extends Control

## Roster Character Sheet
## Populates from GladiatorTemplate instances produced by the generator.

@onready var roster_list: VBoxContainer = %RosterList
@onready var empty_state: Control = %EmptyState
@onready var sheet_content: Control = %SheetContent

# Identity
@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var species_label: Label = %SpeciesLabel
@onready var combat_personality_label: Label = %CombatPersonality
@onready var noncombat_personality_label: Label = %NoncombatPersonality
@onready var alive_badge: Label = %AliveBadge

# Vitals
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_value_label: Label = %HealthValue
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var stamina_value_label: Label = %StaminaValue

# Primary Attributes
@onready var vitality_value: Label = %VitalityValue
@onready var endurance_value: Label = %EnduranceValue
@onready var strength_value: Label = %StrengthValue
@onready var agility_value: Label = %AgilityValue
@onready var precision_value: Label = %PrecisionValue
@onready var resilience_value: Label = %ResilienceValue
@onready var charisma_value: Label = %CharismaValue

# Derived (some unique names still reflect older labels; values are remapped)
@onready var max_health_value: Label = %MaxHealthValue
@onready var max_stamina_value: Label = %MaxStaminaValue
@onready var stamina_regen_value: Label = %StaminaRegenValue
@onready var base_damage_value: Label = %BaseDamageValue
@onready var attack_speed_value: Label = %AttackSpeedValue
@onready var ability_power_value: Label = %InitiativeValue  # remapped slot
@onready var dodge_chance_value: Label = %DodgeChanceValue
@onready var crit_chance_value: Label = %CritChanceValue
@onready var crit_multiplier_value: Label = %CritMultiplierValue
@onready var accuracy_value: Label = %AccuracyValue

# Defense
@onready var primary_dr_value: Label = %PrimaryDRValue
@onready var crit_defense_value: Label = %SecondaryCritDefValue
@onready var status_res_value: Label = %StatusResValue
@onready var intimidation_res_value: Label = %IntimidationResValue

# Meta
@onready var cunning_value: Label = %CunningValue
@onready var injury_recovery_value: Label = %CunningRateValue  # remapped slot
@onready var fatigue_resistance_value: Label = %StanceAffinityValue  # remapped slot
@onready var crowd_hype_value: Label = %CrowdInfluenceValue
@onready var essence_potency_value: Label = %EssencePotencyValue

# Abilities
@onready var ability_list: HBoxContainer = %AbilityList

var current_template: GladiatorTemplate = null
var roster: Array[GladiatorTemplate] = []


func _ready() -> void:
	_relabel_static_ui()
	_show_empty_state()


func _relabel_static_ui() -> void:
	# Keep unique_name paths stable; only change visible text on name labels.
	_set_label_text_by_path(
		"MainHBox/SheetPanel/SheetMargin/SheetRoot/SheetContent/ContentVBox/StatsGrid/DerivedBlock/DerivedVBox/InitiativeRow/InitiativeName",
		"Ability Power"
	)
	_set_label_text_by_path(
		"MainHBox/SheetPanel/SheetMargin/SheetRoot/SheetContent/ContentVBox/StatsGrid/DefenseBlock/DefenseVBox/SecondaryCritDefRow/SecondaryCritDefName",
		"Crit Defense Factor"
	)
	_set_label_text_by_path(
		"MainHBox/SheetPanel/SheetMargin/SheetRoot/SheetContent/ContentVBox/StatsGrid/MetaBlock/MetaVBox/MetaTitle",
		"CUNNING · CROWD · META"
	)
	_set_label_text_by_path(
		"MainHBox/SheetPanel/SheetMargin/SheetRoot/SheetContent/ContentVBox/StatsGrid/MetaBlock/MetaVBox/CunningRateRow/CunningRateName",
		"Injury Recovery"
	)
	_set_label_text_by_path(
		"MainHBox/SheetPanel/SheetMargin/SheetRoot/SheetContent/ContentVBox/StatsGrid/MetaBlock/MetaVBox/StanceAffinityRow/StanceAffinityName",
		"Fatigue Resistance"
	)
	_set_label_text_by_path(
		"MainHBox/SheetPanel/SheetMargin/SheetRoot/SheetContent/ContentVBox/StatsGrid/MetaBlock/MetaVBox/CrowdInfluenceRow/CrowdInfluenceName",
		"Crowd Hype Inc."
	)


func _set_label_text_by_path(path: String, text: String) -> void:
	var node := get_node_or_null(path)
	if node is Label:
		(node as Label).text = text


func set_roster(new_roster: Array[GladiatorTemplate]) -> void:
	roster = new_roster
	_rebuild_roster_list()
	if roster.size() > 0:
		select_character(roster[0])
	else:
		_show_empty_state()


func select_character(template: GladiatorTemplate) -> void:
	if template == null:
		_show_empty_state()
		return
	current_template = template
	_populate_sheet(template)
	_show_sheet()


func _show_empty_state() -> void:
	empty_state.visible = true
	sheet_content.visible = false
	current_template = null


func _show_sheet() -> void:
	empty_state.visible = false
	sheet_content.visible = true


func _rebuild_roster_list() -> void:
	for child in roster_list.get_children():
		child.queue_free()

	for template in roster:
		roster_list.add_child(_create_roster_card(template))

	var empty_slots := maxi(0, 5 - roster.size())
	for i in empty_slots:
		roster_list.add_child(_create_empty_slot_card())


func _create_roster_card(template: GladiatorTemplate) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	var label := template.display_name if template.display_name != "" else "Unnamed"
	if template.character_id != "":
		label += "  [%s]" % template.character_id
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(select_character.bind(template))
	if template == current_template:
		btn.modulate = Color(1.15, 1.05, 0.85)
	return btn


func _create_empty_slot_card() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.text = "+ Empty Slot"
	btn.disabled = true
	btn.modulate = Color(0.6, 0.55, 0.5)
	return btn


func _populate_sheet(t: GladiatorTemplate) -> void:
	name_label.text = t.display_name if t.display_name != "" else "Unnamed Gladiator"
	var species_line := t.species_or_class if t.species_or_class != "" else "Unknown"
	if t.character_id != "":
		species_line += "  ·  %s" % t.character_id
	species_label.text = species_line
	combat_personality_label.text = "Combat: %s" % (t.combat_personality if t.combat_personality != "" else "—")
	noncombat_personality_label.text = "Non-Combat: %s" % (t.noncombat_personality if t.noncombat_personality != "" else "—")
	alive_badge.text = "Alive" if t.is_alive else "Fallen"
	alive_badge.modulate = Color(0.4, 0.85, 0.45) if t.is_alive else Color(0.85, 0.35, 0.3)

	if t.portrait:
		portrait.texture = t.portrait
	elif t.sprite_texture:
		portrait.texture = t.sprite_texture
	else:
		portrait.texture = null

	var max_hp := maxi(t.base_max_health, 1)
	var cur_hp := clampi(t.current_health, 0, max_hp)
	health_bar.max_value = max_hp
	health_bar.value = cur_hp
	health_value_label.text = "%d / %d" % [cur_hp, max_hp]

	var max_sta := maxi(t.base_max_stamina, 1)
	var cur_sta := clampi(t.current_stamina, 0, max_sta)
	stamina_bar.max_value = max_sta
	stamina_bar.value = cur_sta
	stamina_value_label.text = "%d / %d" % [cur_sta, max_sta]

	_set_stat(vitality_value, t.base_vitality)
	_set_stat(endurance_value, t.base_endurance)
	_set_stat(strength_value, t.base_strength)
	_set_stat(agility_value, t.base_agility)
	_set_stat(precision_value, t.base_precision)
	_set_stat(resilience_value, t.base_resilience)
	_set_stat(charisma_value, t.base_charisma)

	_set_stat(max_health_value, t.base_max_health)
	_set_stat(max_stamina_value, t.base_max_stamina)
	_set_stat(stamina_regen_value, t.base_stamina_regen, "%.1f /s")
	_set_stat(base_damage_value, t.base_damage)
	_set_stat(attack_speed_value, t.base_attack_speed, "%.2f×")
	_set_stat(ability_power_value, t.base_ability_power)
	_set_stat(dodge_chance_value, t.base_dodge_chance, "%.1f%%")
	_set_stat(crit_chance_value, t.base_crit_chance, "%.1f%%")
	_set_stat(crit_multiplier_value, t.base_crit_multiplier, "%.2f×")
	_set_stat(accuracy_value, t.base_accuracy, "%.0f%%")

	_set_stat(primary_dr_value, t.base_primary_damage_reduction, "%.0f%%")
	_set_stat(crit_defense_value, t.base_crit_defense_factor, "÷%.2f")
	_set_stat(status_res_value, t.base_status_resistance, "%.0f%%")
	_set_stat(intimidation_res_value, t.base_intimidation_resistance, "%.0f%%")

	_set_stat(cunning_value, t.base_cunning, "%.1f")
	_set_stat(injury_recovery_value, t.base_injury_recovery_chance, "%.1f%%/wk")
	_set_stat(fatigue_resistance_value, t.base_fatigue_resistance, "%.1f%%")
	_set_stat(crowd_hype_value, t.base_crowd_hype_increment, "%.1f")
	_set_stat(essence_potency_value, t.base_essence_potency, "%.0f")

	for child in ability_list.get_children():
		child.queue_free()
	if t.abilities.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No abilities assigned yet"
		placeholder.modulate = Color(0.7, 0.65, 0.55)
		ability_list.add_child(placeholder)
	else:
		for ability in t.abilities:
			var card := Label.new()
			card.text = ability.display_name if "display_name" in ability else str(ability)
			ability_list.add_child(card)


func _set_stat(label: Label, value: Variant, format: String = "%s") -> void:
	if label == null:
		return
	if value == null:
		label.text = "—"
	else:
		label.text = format % value
