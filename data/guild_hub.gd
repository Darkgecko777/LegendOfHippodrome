extends Control

## Guild Hub controller — Option A layout + Calendar registration + Combat log.

const MAX_ROSTER_SIZE := 5
const COMBAT_LOG_PATH := "res://last_combat_log.txt"

@onready var generator: Node = $GladiatorGenerator
@onready var roster_sheet: RosterCharacterSheet = %RosterCharacterSheet

@onready var gold_label: Label = %GoldLabel
@onready var renown_label: Label = %RenownLabel
@onready var week_label: Label = %WeekLabel
@onready var advance_week_button: Button = %AdvanceWeekButton
@onready var fight_button: Button = %FightButton

@onready var purchase_button: Button = %PurchaseButton
@onready var market_status: Label = %MarketStatusLabel
@onready var gladiator_list: ItemList = %GladiatorList
@onready var weapon_list: ItemList = %WeaponList
@onready var training_list: ItemList = %TrainingList
@onready var refresh_button: Button = %RefreshMarketButton

@onready var assignment_rows: VBoxContainer = %AssignmentRows
@onready var assignments_status: Label = %AssignmentsStatusLabel

@onready var owned_weapons_list: ItemList = %OwnedWeaponsList
@onready var owned_training_list: ItemList = %OwnedTrainingList

@onready var calendar_tab: MarginContainer = $MainVBox/ContentMargin/TabContainer/Calendar

var combat_tab: MarginContainer
var combat_log_label: RichTextLabel
var filter_narrative: CheckBox
var filter_result: CheckBox
var filter_decision: CheckBox
var filter_resource: CheckBox
var filter_debug: CheckBox
var last_log_events: Array[Dictionary] = []

var guild_state: GuildState
var market_state: MarketState

enum Category { NONE, GLADIATOR, WEAPON, TRAINING }
var selected_category: Category = Category.NONE
var selected_index: int = -1

var row_gladiators: Array[GladiatorTemplate] = []
var row_weapon_options: Array[OptionButton] = []
var row_activity_options: Array[OptionButton] = []
var _updating_dropdowns := false

var calendar_offers_list: ItemList
var calendar_detail_label: Label
var calendar_gladiator_option: OptionButton
var calendar_intervention_option: OptionButton
var calendar_register_button: Button
var calendar_status_label: Label
var selected_offer_index: int = -1


func _ready() -> void:
	_ensure_guild_state()
	_ensure_market_state()
	_build_calendar_ui()
	_build_combat_tab()
	if advance_week_button:
		advance_week_button.pressed.connect(_on_advance_week_pressed)
	if fight_button:
		fight_button.pressed.connect(_on_fight_pressed)
	if purchase_button:
		purchase_button.pressed.connect(_on_purchase_pressed)
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	if gladiator_list:
		gladiator_list.item_selected.connect(_on_gladiator_selected)
	if weapon_list:
		weapon_list.item_selected.connect(_on_weapon_selected)
	if training_list:
		training_list.item_selected.connect(_on_training_selected)
	_refresh_all()


func _ensure_guild_state() -> void:
	if guild_state == null:
		guild_state = GuildState.new()
		guild_state.gold = 600
		guild_state.renown = 20
		guild_state.current_week = 1
		guild_state.refresh_match_offers(3)


func _ensure_market_state() -> void:
	if market_state == null:
		market_state = MarketState.new()
		market_state.refresh_weekly(generator)


func _refresh_all() -> void:
	_refresh_market_ui()
	_rebuild_assignment_rows()
	_refresh_guild_ownership_ui()
	_refresh_calendar_ui()
	_update_currency_display()
	_update_market_status()
	_update_fight_button()


func _update_currency_display() -> void:
	if gold_label and guild_state:
		gold_label.text = "Gold: %d" % guild_state.gold
	if renown_label and guild_state:
		renown_label.text = "Renown: %d  (Tier %d)" % [guild_state.renown, guild_state.get_guild_tier()]
	if week_label and guild_state:
		week_label.text = "Week %d" % guild_state.current_week


func _update_fight_button() -> void:
	if fight_button == null or guild_state == null:
		return
	fight_button.disabled = not guild_state.has_registered_match()
	if guild_state.has_registered_match():
		var m: MonsterTemplate = guild_state.registered_match.get("monster")
		fight_button.text = "Fight: %s" % (m.get_display_name() if m else "Fight")
	else:
		fight_button.text = "Fight"


func _on_advance_week_pressed() -> void:
	request_advance_week()


func request_advance_week() -> void:
	if roster_sheet == null or guild_state == null:
		return
	var roster: Array = roster_sheet.roster
	var summary: Array[String] = WeekResolver.resolve_week(roster, guild_state)
	for line in summary:
		print(line)
	for g in roster:
		if g is GladiatorTemplate:
			g.assigned_training = null
	guild_state.refresh_match_offers(3)
	_refresh_all()


func _on_fight_pressed() -> void:
	if not guild_state.has_registered_match():
		return
	var rm := guild_state.registered_match
	var monster: MonsterTemplate = rm.get("monster")
	var glad: GladiatorTemplate = rm.get("gladiator")
	var inter: int = rm.get("intervention_level", 0)
	if monster == null or glad == null:
		return

	var resolver := CombatResolver.new()
	resolver.gladiator = glad
	resolver.monster = monster
	resolver.intervention_level = inter
	resolver.knowledge_revealed = guild_state.knows_vulnerabilities(monster)
	resolver.resolve()

	last_log_events = resolver.log_events
	_refresh_combat_log()
	_write_combat_log_file(resolver)

	var tabs: TabContainer = $MainVBox/ContentMargin/TabContainer
	if tabs and combat_tab:
		for i in tabs.get_child_count():
			if tabs.get_child(i) == combat_tab:
				tabs.current_tab = i
				break

	print("Combat finished. Winner: %s | Log: %s" % [resolver.winner, COMBAT_LOG_PATH])


func _write_combat_log_file(resolver: CombatResolver) -> void:
	var lines: PackedStringArray = []
	lines.append("=== COMBAT LOG ===")
	lines.append("Winner: %s" % resolver.winner)
	lines.append("Gladiator HP: %d | Monster HP: %d" % [resolver.final_gladiator_health, resolver.final_monster_health])
	lines.append("Gold: %d | Fame: %d | Intervention: %d" % [resolver.gold_reward, resolver.fame_reward, resolver.intervention_level])
	lines.append("")
	for ev in resolver.log_events:
		var cat: String = str(ev.get("category", ""))
		var type: String = str(ev.get("type", ""))
		var text: String = str(ev.get("text", ""))
		lines.append("[%s|%s] %s" % [cat, type, text])
	lines.append("")
	lines.append("=== END ===")
	var body: String = "\n".join(lines)
	var file := FileAccess.open(COMBAT_LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(body)
		file.close()
	else:
		push_warning("Could not write combat log to %s" % COMBAT_LOG_PATH)


func _build_combat_tab() -> void:
	var tabs: TabContainer = $MainVBox/ContentMargin/TabContainer
	if tabs == null:
		return
	combat_tab = null
	for child in tabs.get_children():
		if child.name == "Combat":
			combat_tab = child
			break
	if combat_tab == null:
		combat_tab = MarginContainer.new()
		combat_tab.name = "Combat"
		tabs.add_child(combat_tab)
	for child in combat_tab.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_tab.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Combat Log"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 12)
	vbox.add_child(filter_row)
	filter_narrative = CheckBox.new()
	filter_narrative.text = "Narrative"
	filter_narrative.button_pressed = true
	filter_narrative.toggled.connect(_on_filter_toggled)
	filter_row.add_child(filter_narrative)
	filter_result = CheckBox.new()
	filter_result.text = "Results"
	filter_result.button_pressed = true
	filter_result.toggled.connect(_on_filter_toggled)
	filter_row.add_child(filter_result)
	filter_decision = CheckBox.new()
	filter_decision.text = "Decisions"
	filter_decision.button_pressed = true
	filter_decision.toggled.connect(_on_filter_toggled)
	filter_row.add_child(filter_decision)
	filter_resource = CheckBox.new()
	filter_resource.text = "Resources"
	filter_resource.button_pressed = false
	filter_resource.toggled.connect(_on_filter_toggled)
	filter_row.add_child(filter_resource)
	filter_debug = CheckBox.new()
	filter_debug.text = "Debug"
	filter_debug.button_pressed = false
	filter_debug.toggled.connect(_on_filter_toggled)
	filter_row.add_child(filter_debug)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	combat_log_label = RichTextLabel.new()
	combat_log_label.bbcode_enabled = true
	combat_log_label.fit_content = true
	combat_log_label.scroll_following = true
	combat_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_log_label.custom_minimum_size = Vector2(0, 300)
	scroll.add_child(combat_log_label)
	combat_log_label.text = "Register a fight in the Calendar tab, then press the Fight button."


func _on_filter_toggled(_pressed: bool) -> void:
	_refresh_combat_log()


func _refresh_combat_log() -> void:
	if combat_log_label == null:
		return
	if last_log_events.is_empty():
		combat_log_label.text = "No fight resolved yet."
		return
	var show_narrative := filter_narrative.button_pressed if filter_narrative else true
	var show_result := filter_result.button_pressed if filter_result else true
	var show_decision := filter_decision.button_pressed if filter_decision else true
	var show_resource := filter_resource.button_pressed if filter_resource else false
	var show_debug := filter_debug.button_pressed if filter_debug else false
	var lines: PackedStringArray = []
	for ev in last_log_events:
		var cat: StringName = ev.get("category", &"")
		var visible := false
		match cat:
			&"narrative": visible = show_narrative
			&"result": visible = show_result
			&"decision": visible = show_decision
			&"resource": visible = show_resource
			&"debug": visible = show_debug
			_: visible = show_narrative
		if not visible:
			continue
		var text: String = str(ev.get("text", ""))
		var type: StringName = ev.get("type", &"")
		if type == &"thought_bubble":
			var colour: String = str(ev.get("data", {}).get("colour", "white"))
			match colour:
				"green": text = "[color=lime]%s[/color]" % text
				"red": text = "[color=salmon]%s[/color]" % text
				_: text = "[color=lightgray]%s[/color]" % text
		elif type == &"critical_hit" or type == &"death":
			text = "[color=gold]%s[/color]" % text
		elif type == &"exchange_start":
			text = "[color=aqua]%s[/color]" % text
		lines.append(text)
	combat_log_label.text = "\n".join(lines)


func _build_calendar_ui() -> void:
	if calendar_tab == null:
		return
	for child in calendar_tab.get_children():
		child.queue_free()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	calendar_tab.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Calendar — Available Matches"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	var lists_row := HBoxContainer.new()
	lists_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists_row.add_theme_constant_override("separation", 16)
	vbox.add_child(lists_row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists_row.add_child(left)
	var offers_header := Label.new()
	offers_header.text = "Offers this cycle"
	left.add_child(offers_header)
	calendar_offers_list = ItemList.new()
	calendar_offers_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	calendar_offers_list.custom_minimum_size = Vector2(0, 180)
	left.add_child(calendar_offers_list)
	calendar_offers_list.item_selected.connect(_on_offer_selected)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	lists_row.add_child(right)
	var detail_header := Label.new()
	detail_header.text = "Match Detail"
	right.add_child(detail_header)
	calendar_detail_label = Label.new()
	calendar_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calendar_detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	calendar_detail_label.text = "Select an offer to see details and register."
	right.add_child(calendar_detail_label)
	var glad_row := HBoxContainer.new()
	right.add_child(glad_row)
	var glad_lbl := Label.new()
	glad_lbl.text = "Gladiator:"
	glad_lbl.custom_minimum_size = Vector2(90, 0)
	glad_row.add_child(glad_lbl)
	calendar_gladiator_option = OptionButton.new()
	calendar_gladiator_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glad_row.add_child(calendar_gladiator_option)
	var inter_row := HBoxContainer.new()
	right.add_child(inter_row)
	var inter_lbl := Label.new()
	inter_lbl.text = "Intervention:"
	inter_lbl.custom_minimum_size = Vector2(90, 0)
	inter_row.add_child(inter_lbl)
	calendar_intervention_option = OptionButton.new()
	calendar_intervention_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calendar_intervention_option.add_item("None (max risk / max reward)", 0)
	calendar_intervention_option.add_item("Light", 1)
	calendar_intervention_option.add_item("Standard", 2)
	calendar_intervention_option.add_item("Heavy", 3)
	calendar_intervention_option.add_item("Maximum (near-zero death chance)", 4)
	inter_row.add_child(calendar_intervention_option)
	calendar_register_button = Button.new()
	calendar_register_button.text = "Register for this Fight"
	calendar_register_button.pressed.connect(_on_register_pressed)
	right.add_child(calendar_register_button)
	calendar_status_label = Label.new()
	calendar_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(calendar_status_label)


func _refresh_calendar_ui() -> void:
	if calendar_offers_list == null or guild_state == null:
		return
	calendar_offers_list.clear()
	for offer in guild_state.available_offers:
		var m: MonsterTemplate = offer["monster"]
		calendar_offers_list.add_item("Tier %d — %s  |  Threat %d  |  %dg / %df" % [m.tier, m.get_display_name(), offer["threat"], offer["base_gold"], offer["base_fame"]])
	calendar_gladiator_option.clear()
	var roster: Array = roster_sheet.roster if roster_sheet else []
	if roster.is_empty():
		calendar_gladiator_option.add_item("(No gladiators)")
		calendar_gladiator_option.set_item_disabled(0, true)
	else:
		for g in roster:
			if g is GladiatorTemplate:
				var idx := calendar_gladiator_option.item_count
				calendar_gladiator_option.add_item(g.get_display_name())
				calendar_gladiator_option.set_item_metadata(idx, g)
	selected_offer_index = -1
	calendar_detail_label.text = "Select an offer to see details and register."
	if guild_state.has_registered_match():
		var rm := guild_state.registered_match
		var m: MonsterTemplate = rm.get("monster")
		var g: GladiatorTemplate = rm.get("gladiator")
		calendar_status_label.text = "Registered: %s vs %s (Intervention %d)." % [g.get_display_name() if g else "?", m.get_display_name() if m else "?", rm.get("intervention_level", 0)]
	else:
		calendar_status_label.text = "No fight registered."


func _on_offer_selected(index: int) -> void:
	selected_offer_index = index
	if index < 0 or index >= guild_state.available_offers.size():
		return
	offer_detail(index)


func offer_detail(index: int) -> void:
	var offer: Dictionary = guild_state.available_offers[index]
	var m: MonsterTemplate = offer["monster"]
	var known := guild_state.knows_vulnerabilities(m)
	var vuln_text := "Vulnerabilities: fogged." if not known else "Known: " + ", ".join(m.vulnerability_tags.map(func(t): return str(t)))
	calendar_detail_label.text = "%s (Tier %d)\n%s\n\nThreat %d | %dg / %df\n%s\nStance bias: %s" % [m.get_display_name(), m.tier, m.flavour, offer["threat"], offer["base_gold"], offer["base_fame"], vuln_text, str(m.preferred_stance).capitalize()]


func _on_register_pressed() -> void:
	if selected_offer_index < 0 or selected_offer_index >= guild_state.available_offers.size():
		return
	var roster: Array = roster_sheet.roster if roster_sheet else []
	if roster.is_empty():
		return
	var glad: GladiatorTemplate = calendar_gladiator_option.get_item_metadata(calendar_gladiator_option.selected) as GladiatorTemplate
	if glad == null:
		return
	var offer: Dictionary = guild_state.available_offers[selected_offer_index]
	guild_state.registered_match = {
		"monster": offer["monster"], "gladiator": glad,
		"intervention_level": calendar_intervention_option.get_selected_id(),
		"threat": offer["threat"], "base_gold": offer["base_gold"], "base_fame": offer["base_fame"],
	}
	_update_fight_button()
	_refresh_calendar_ui()


func _refresh_market_ui() -> void:
	_populate_gladiator_list()
	_populate_weapon_list()
	_populate_training_list()


func _populate_gladiator_list() -> void:
	if gladiator_list == null or market_state == null: return
	gladiator_list.clear()
	for offer in market_state.gladiator_offers:
		var t: GladiatorTemplate = offer["template"]
		gladiator_list.add_item("%s | %s | %d gold" % [t.display_name, str(t.preferred_weapon).capitalize(), offer["price"]])


func _populate_weapon_list() -> void:
	if weapon_list == null or market_state == null: return
	weapon_list.clear()
	for w in market_state.weapon_offers:
		weapon_list.add_item("%s (T%d) — %d gold" % [w.display_name, w.tier, w.cost])


func _populate_training_list() -> void:
	if training_list == null or market_state == null: return
	training_list.clear()
	for t in market_state.training_offers:
		training_list.add_item("%s (T%d) — %d gold" % [t.display_name, t.tier, t.cost])


func _on_gladiator_selected(index: int) -> void:
	selected_category = Category.GLADIATOR
	selected_index = index
	if weapon_list: weapon_list.deselect_all()
	if training_list: training_list.deselect_all()
	_update_purchase_button()


func _on_weapon_selected(index: int) -> void:
	selected_category = Category.WEAPON
	selected_index = index
	if gladiator_list: gladiator_list.deselect_all()
	if training_list: training_list.deselect_all()
	_update_purchase_button()


func _on_training_selected(index: int) -> void:
	selected_category = Category.TRAINING
	selected_index = index
	if gladiator_list: gladiator_list.deselect_all()
	if weapon_list: weapon_list.deselect_all()
	_update_purchase_button()


func _update_purchase_button() -> void:
	if purchase_button == null or guild_state == null: return
	var can_buy := false
	if selected_category == Category.GLADIATOR and selected_index >= 0 and selected_index < market_state.gladiator_offers.size():
		can_buy = guild_state.gold >= market_state.gladiator_offers[selected_index]["price"]
	elif selected_category == Category.WEAPON and selected_index >= 0 and selected_index < market_state.weapon_offers.size():
		can_buy = guild_state.gold >= market_state.weapon_offers[selected_index].cost
	elif selected_category == Category.TRAINING and selected_index >= 0 and selected_index < market_state.training_offers.size():
		can_buy = guild_state.gold >= market_state.training_offers[selected_index].cost
	purchase_button.disabled = not can_buy


func _on_purchase_pressed() -> void:
	if selected_category == Category.NONE or selected_index < 0: return
	match selected_category:
		Category.GLADIATOR: _purchase_gladiator(selected_index)
		Category.WEAPON: _purchase_weapon(selected_index)
		Category.TRAINING: _purchase_training(selected_index)
	selected_category = Category.NONE
	selected_index = -1
	_update_purchase_button()
	_update_currency_display()
	_update_market_status()
	_rebuild_assignment_rows()
	_refresh_guild_ownership_ui()


func _purchase_gladiator(index: int) -> void:
	if index < 0 or index >= market_state.gladiator_offers.size() or roster_sheet == null: return
	var current := roster_sheet.roster
	if current.size() >= MAX_ROSTER_SIZE: return
	var offer: Dictionary = market_state.gladiator_offers[index]
	if not guild_state.spend_gold(offer["price"]): return
	var new_roster: Array[GladiatorTemplate] = []
	new_roster.assign(current)
	new_roster.append(offer["template"])
	roster_sheet.set_roster(new_roster)
	market_state.remove_gladiator_offer(index)
	_populate_gladiator_list()
	_refresh_calendar_ui()


func _purchase_weapon(index: int) -> void:
	if index < 0 or index >= market_state.weapon_offers.size(): return
	var w: WeaponData = market_state.weapon_offers[index]
	if not guild_state.spend_gold(w.cost): return
	guild_state.add_weapon(WeaponData.create(w.id, w.display_name, w.tier, w.cost, w.description))


func _purchase_training(index: int) -> void:
	if index < 0 or index >= market_state.training_offers.size(): return
	var t: TrainingEquipment = market_state.training_offers[index]
	if not guild_state.spend_gold(t.cost): return
	guild_state.add_training(TrainingEquipment.create(t.id, t.display_name, t.linked_primary, t.possible_secondaries, t.tier, t.cost, t.description, t.cunning_gain_min, t.cunning_gain_max, t.is_medic, t.recovery_multiplier))


func _on_refresh_pressed() -> void:
	market_state.refresh_weekly(generator)
	selected_category = Category.NONE
	selected_index = -1
	_refresh_market_ui()
	_update_purchase_button()


func _update_market_status() -> void:
	if market_status == null or roster_sheet == null or guild_state == null: return
	market_status.text = "Roster: %d/%d | Offers: %d | Week %d" % [roster_sheet.roster.size(), MAX_ROSTER_SIZE, market_state.gladiator_offers.size() if market_state else 0, guild_state.current_week]


func _rebuild_assignment_rows() -> void:
	if assignment_rows == null or roster_sheet == null or guild_state == null: return
	for child in assignment_rows.get_children():
		child.queue_free()
	row_gladiators.clear()
	row_weapon_options.clear()
	row_activity_options.clear()
	var roster: Array = roster_sheet.roster
	if roster.is_empty():
		if assignments_status: assignments_status.text = "No gladiators in roster."
		return
	for g in roster:
		if not g is GladiatorTemplate: continue
		var t: GladiatorTemplate = g
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		assignment_rows.add_child(row)
		var name_lbl := Label.new()
		name_lbl.text = t.get_display_name()
		name_lbl.custom_minimum_size = Vector2(140, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var fame_lbl := Label.new()
		fame_lbl.text = "Fame %d" % t.fame
		fame_lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(fame_lbl)
		var wpn_opt := OptionButton.new()
		wpn_opt.custom_minimum_size = Vector2(160, 0)
		wpn_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(wpn_opt)
		wpn_opt.item_selected.connect(_on_weapon_dropdown_selected.bind(t, wpn_opt))
		var act_opt := OptionButton.new()
		act_opt.custom_minimum_size = Vector2(200, 0)
		act_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(act_opt)
		act_opt.item_selected.connect(_on_activity_dropdown_selected.bind(t, act_opt))
		row_gladiators.append(t)
		row_weapon_options.append(wpn_opt)
		row_activity_options.append(act_opt)
	_refresh_all_dropdowns()


func _refresh_all_dropdowns() -> void:
	_updating_dropdowns = true
	var roster: Array = roster_sheet.roster if roster_sheet else []
	for i in row_gladiators.size():
		var t: GladiatorTemplate = row_gladiators[i]
		var wpn_opt: OptionButton = row_weapon_options[i]
		var act_opt: OptionButton = row_activity_options[i]
		wpn_opt.clear()
		wpn_opt.add_item("Unarmed")
		wpn_opt.set_item_metadata(0, null)
		var selected_wpn_idx := 0
		var avail_w := guild_state.get_available_weapons(roster)
		if t.assigned_weapon != null and not avail_w.has(t.assigned_weapon):
			avail_w.append(t.assigned_weapon)
		for w in avail_w:
			var idx := wpn_opt.item_count
			wpn_opt.add_item(w.display_name)
			wpn_opt.set_item_metadata(idx, w)
			if t.assigned_weapon == w: selected_wpn_idx = idx
		wpn_opt.select(selected_wpn_idx)
		act_opt.clear()
		act_opt.add_item("Observation")
		act_opt.set_item_metadata(0, null)
		var selected_act_idx := 0
		var avail_t := guild_state.get_available_training(roster)
		var avail_m := guild_state.get_available_medics(roster)
		if t.assigned_training != null:
			if t.assigned_training.is_medic and not avail_m.has(t.assigned_training):
				avail_m.append(t.assigned_training)
			elif not t.assigned_training.is_medic and not avail_t.has(t.assigned_training):
				avail_t.append(t.assigned_training)
		for item in avail_t:
			var idx2 := act_opt.item_count
			act_opt.add_item(item.display_name)
			act_opt.set_item_metadata(idx2, item)
			if t.assigned_training == item: selected_act_idx = idx2
		for item in avail_m:
			var idx3 := act_opt.item_count
			act_opt.add_item(item.display_name + " (Medic)")
			act_opt.set_item_metadata(idx3, item)
			if t.assigned_training == item: selected_act_idx = idx3
		act_opt.select(selected_act_idx)
	_updating_dropdowns = false


func _on_weapon_dropdown_selected(index: int, t: GladiatorTemplate, opt: OptionButton) -> void:
	if _updating_dropdowns: return
	t.assigned_weapon = opt.get_item_metadata(index) as WeaponData
	_refresh_all_dropdowns()


func _on_activity_dropdown_selected(index: int, t: GladiatorTemplate, opt: OptionButton) -> void:
	if _updating_dropdowns: return
	t.assigned_training = opt.get_item_metadata(index) as TrainingEquipment
	_refresh_all_dropdowns()


func _refresh_guild_ownership_ui() -> void:
	if owned_weapons_list == null or owned_training_list == null or guild_state == null: return
	owned_weapons_list.clear()
	for w in guild_state.owned_weapons:
		owned_weapons_list.add_item(w.display_name)
	owned_training_list.clear()
	for t in guild_state.owned_training:
		owned_training_list.add_item(t.display_name)
	for m in guild_state.owned_medics:
		owned_training_list.add_item(m.display_name + " (Medic)")
