extends Control

## Guild Hub controller — Option A layout.
## Assignments tab: each gladiator row has Weapon + Activity dropdowns.
## Dropdowns auto-assign and stay in sync so the same item cannot be chosen twice.

const MAX_ROSTER_SIZE := 5

@onready var generator: Node = $GladiatorGenerator
@onready var roster_sheet: RosterCharacterSheet = %RosterCharacterSheet

# Global chrome
@onready var gold_label: Label = %GoldLabel
@onready var renown_label: Label = %RenownLabel
@onready var week_label: Label = %WeekLabel
@onready var advance_week_button: Button = %AdvanceWeekButton
@onready var fight_button: Button = %FightButton

# Market
@onready var purchase_button: Button = %PurchaseButton
@onready var market_status: Label = %MarketStatusLabel
@onready var gladiator_list: ItemList = %GladiatorList
@onready var weapon_list: ItemList = %WeaponList
@onready var training_list: ItemList = %TrainingList
@onready var refresh_button: Button = %RefreshMarketButton

# Assignments
@onready var assignment_rows: VBoxContainer = %AssignmentRows
@onready var assignments_status: Label = %AssignmentsStatusLabel

# Guild ownership
@onready var owned_weapons_list: ItemList = %OwnedWeaponsList
@onready var owned_training_list: ItemList = %OwnedTrainingList

var guild_state: GuildState
var market_state: MarketState

# Market selection
enum Category { NONE, GLADIATOR, WEAPON, TRAINING }
var selected_category: Category = Category.NONE
var selected_index: int = -1

# Assignment row tracking (parallel arrays)
var row_gladiators: Array[GladiatorTemplate] = []
var row_weapon_options: Array[OptionButton] = []
var row_activity_options: Array[OptionButton] = []
var _updating_dropdowns := false  # prevent re-entrant signals


func _ready() -> void:
	_ensure_guild_state()
	_ensure_market_state()

	if advance_week_button:
		advance_week_button.pressed.connect(_on_advance_week_pressed)
	if fight_button:
		fight_button.disabled = true

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


func _ensure_market_state() -> void:
	if market_state == null:
		market_state = MarketState.new()
		market_state.refresh_weekly(generator)


func _refresh_all() -> void:
	_refresh_market_ui()
	_rebuild_assignment_rows()
	_refresh_guild_ownership_ui()
	_update_currency_display()
	_update_market_status()


# ─────────────────────────────────────────────
# Global chrome
# ─────────────────────────────────────────────

func _update_currency_display() -> void:
	if gold_label and guild_state:
		gold_label.text = "Gold: %d" % guild_state.gold
	if renown_label and guild_state:
		renown_label.text = "Renown: %d" % guild_state.renown
	if week_label and guild_state:
		week_label.text = "Week %d" % guild_state.current_week


func _on_advance_week_pressed() -> void:
	request_advance_week()


func request_advance_week() -> void:
	if roster_sheet == null or guild_state == null:
		return
	var roster: Array = roster_sheet.roster

	var has_observer := false
	for g in roster:
		if g is GladiatorTemplate and g.assigned_training == null:
			has_observer = true
			break
	var has_unused := guild_state.get_available_training(roster).size() > 0
	if has_observer and has_unused:
		print("Advance Week warning: observers present and unused training available.")

	var summary: Array[String] = WeekResolver.resolve_week(roster, guild_state)
	for line in summary:
		print(line)

	# Clear activities after resolution (weapons stay)
	for g in roster:
		if g is GladiatorTemplate:
			g.assigned_training = null

	_refresh_all()
	if market_status:
		market_status.text = "Week advanced to %d. See console for full summary." % guild_state.current_week


# ─────────────────────────────────────────────
# Market (unchanged logic)
# ─────────────────────────────────────────────

func _refresh_market_ui() -> void:
	_populate_gladiator_list()
	_populate_weapon_list()
	_populate_training_list()


func _populate_gladiator_list() -> void:
	if gladiator_list == null or market_state == null:
		return
	gladiator_list.clear()
	for offer in market_state.gladiator_offers:
		var t: GladiatorTemplate = offer["template"]
		var price: int = offer["price"]
		var desc := _build_fog_descriptors(t)
		var line := "%s  |  Prefers %s  |  %s  |  %d gold" % [
			t.display_name, str(t.preferred_weapon).capitalize(), desc, price
		]
		gladiator_list.add_item(line)


func _populate_weapon_list() -> void:
	if weapon_list == null or market_state == null:
		return
	weapon_list.clear()
	for w in market_state.weapon_offers:
		weapon_list.add_item("%s  (Tier %d)  —  %d gold" % [w.display_name, w.tier, w.cost])


func _populate_training_list() -> void:
	if training_list == null or market_state == null:
		return
	training_list.clear()
	for t in market_state.training_offers:
		training_list.add_item("%s  (Tier %d)  —  %d gold" % [t.display_name, t.tier, t.cost])


func _build_fog_descriptors(t: GladiatorTemplate) -> String:
	var stats := [
		{"name": "vitality", "value": t.base_vitality},
		{"name": "endurance", "value": t.base_endurance},
		{"name": "strength", "value": t.base_strength},
		{"name": "agility", "value": t.base_agility},
		{"name": "precision", "value": t.base_precision},
		{"name": "resilience", "value": t.base_resilience},
		{"name": "charisma", "value": t.base_charisma},
		{"name": "cunning", "value": int(t.current_cunning)},
	]
	stats.sort_custom(func(a, b): return a["value"] > b["value"])
	var high1: String = _pick_descriptor(stats[0]["name"], true)
	var high2: String = _pick_descriptor(stats[1]["name"], true)
	var low1: String = _pick_descriptor(stats[stats.size() - 1]["name"], false)
	var low2: String = _pick_descriptor(stats[stats.size() - 2]["name"], false)
	return "%s, %s, %s, %s" % [high1, high2, low1, low2]


func _pick_descriptor(stat_name: String, is_high: bool) -> String:
	var pools := {
		"vitality": {"high": ["Hardy", "Iron-framed", "Tireless", "Sturdy"], "low": ["Fragile", "Brittle", "Sickly", "Delicate"]},
		"endurance": {"high": ["Robust", "Relentless", "Stamina-iron", "Unflagging"], "low": ["Winded", "Soft", "Easily spent", "Fading"]},
		"strength": {"high": ["Powerful", "Crushing", "Bull-like", "Mighty"], "low": ["Weak", "Feeble", "Soft-armed", "Slight"]},
		"agility": {"high": ["Fleet", "Whip-quick", "Cat-footed", "Lithe"], "low": ["Clumsy", "Lead-footed", "Stiff", "Awkward"]},
		"precision": {"high": ["Keen-eyed", "Deadly-accurate", "Steady", "Sharp"], "low": ["Wild", "Erratic", "Unsteady", "Blunt"]},
		"resilience": {"high": ["Unyielding", "Thick-skinned", "Steadfast", "Iron-willed"], "low": ["Brittle", "Soft", "Quailing", "Fragile"]},
		"charisma": {"high": ["Commanding", "Magnetic", "Crowd-favourite", "Imposing"], "low": ["Bland", "Forgettable", "Unremarkable", "Meek"]},
		"cunning": {"high": ["Sharp", "Calculating", "Wily", "Shrewd"], "low": ["Dull", "Predictable", "Simple", "Slow-witted"]},
	}
	var key := "high" if is_high else "low"
	var options: Array = pools.get(stat_name, {}).get(key, ["Unknown"])
	return options[randi() % options.size()]


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
	if purchase_button == null or guild_state == null:
		return
	var can_buy := false
	if selected_category == Category.GLADIATOR and selected_index >= 0 and selected_index < market_state.gladiator_offers.size():
		can_buy = guild_state.gold >= market_state.gladiator_offers[selected_index]["price"]
	elif selected_category == Category.WEAPON and selected_index >= 0 and selected_index < market_state.weapon_offers.size():
		can_buy = guild_state.gold >= market_state.weapon_offers[selected_index].cost
	elif selected_category == Category.TRAINING and selected_index >= 0 and selected_index < market_state.training_offers.size():
		can_buy = guild_state.gold >= market_state.training_offers[selected_index].cost
	purchase_button.disabled = not can_buy


func _on_purchase_pressed() -> void:
	if selected_category == Category.NONE or selected_index < 0:
		return
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
	if index < 0 or index >= market_state.gladiator_offers.size() or roster_sheet == null:
		return
	var current := roster_sheet.roster
	if current.size() >= MAX_ROSTER_SIZE:
		if market_status: market_status.text = "Roster is full (%d/%d)." % [current.size(), MAX_ROSTER_SIZE]
		return
	var offer: Dictionary = market_state.gladiator_offers[index]
	var price: int = offer["price"]
	var template: GladiatorTemplate = offer["template"]
	if not guild_state.spend_gold(price):
		if market_status: market_status.text = "Not enough gold."
		return
	var new_roster: Array[GladiatorTemplate] = []
	new_roster.assign(current)
	new_roster.append(template)
	roster_sheet.set_roster(new_roster)
	market_state.remove_gladiator_offer(index)
	_populate_gladiator_list()
	if market_status:
		market_status.text = "Recruited %s for %d gold — Roster %d/%d" % [template.display_name, price, new_roster.size(), MAX_ROSTER_SIZE]


func _purchase_weapon(index: int) -> void:
	if index < 0 or index >= market_state.weapon_offers.size():
		return
	var w: WeaponData = market_state.weapon_offers[index]
	if not guild_state.spend_gold(w.cost):
		if market_status: market_status.text = "Not enough gold."
		return
	var owned := WeaponData.create(w.id, w.display_name, w.tier, w.cost, w.description)
	guild_state.add_weapon(owned)
	if market_status:
		market_status.text = "Purchased %s for %d gold. Owned weapons: %d" % [w.display_name, w.cost, guild_state.owned_weapons.size()]


func _purchase_training(index: int) -> void:
	if index < 0 or index >= market_state.training_offers.size():
		return
	var t: TrainingEquipment = market_state.training_offers[index]
	if not guild_state.spend_gold(t.cost):
		if market_status: market_status.text = "Not enough gold."
		return
	var owned := TrainingEquipment.create(
		t.id, t.display_name, t.linked_primary, t.possible_secondaries,
		t.tier, t.cost, t.description,
		t.cunning_gain_min, t.cunning_gain_max, t.is_medic, t.recovery_multiplier
	)
	guild_state.add_training(owned)
	var count := guild_state.owned_medics.size() if t.is_medic else guild_state.owned_training.size()
	var pool := "medics" if t.is_medic else "training items"
	if market_status:
		market_status.text = "Purchased %s for %d gold. Owned %s: %d" % [t.display_name, t.cost, pool, count]


func _on_refresh_pressed() -> void:
	market_state.refresh_weekly(generator)
	selected_category = Category.NONE
	selected_index = -1
	_refresh_market_ui()
	_update_purchase_button()
	if market_status: market_status.text = "Market refreshed."


func _update_market_status() -> void:
	if market_status == null or roster_sheet == null or guild_state == null:
		return
	var count := roster_sheet.roster.size()
	var offers := market_state.gladiator_offers.size() if market_state else 0
	var owned_w := guild_state.owned_weapons.size()
	var owned_t := guild_state.owned_training.size() + guild_state.owned_medics.size()
	market_status.text = "Roster: %d/%d  |  Offers: %d  |  Owned: %dW / %dT  |  Week %d" % [
		count, MAX_ROSTER_SIZE, offers, owned_w, owned_t, guild_state.current_week
	]


# ─────────────────────────────────────────────
# Assignments — per-gladiator dropdown rows
# ─────────────────────────────────────────────

func _rebuild_assignment_rows() -> void:
	if assignment_rows == null or roster_sheet == null or guild_state == null:
		return

	# Clear old rows
	for child in assignment_rows.get_children():
		child.queue_free()
	row_gladiators.clear()
	row_weapon_options.clear()
	row_activity_options.clear()

	var roster: Array = roster_sheet.roster
	if roster.is_empty():
		if assignments_status:
			assignments_status.text = "No gladiators in roster. Recruit some from the Market."
		return

	for g in roster:
		if not g is GladiatorTemplate:
			continue
		var t: GladiatorTemplate = g

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		assignment_rows.add_child(row)

		# Name
		var name_lbl := Label.new()
		name_lbl.text = t.get_display_name()
		name_lbl.custom_minimum_size = Vector2(140, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# Fame (compact)
		var fame_lbl := Label.new()
		fame_lbl.text = "Fame %d" % t.fame
		fame_lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(fame_lbl)

		# Weapon dropdown
		var wpn_opt := OptionButton.new()
		wpn_opt.custom_minimum_size = Vector2(160, 0)
		wpn_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(wpn_opt)
		wpn_opt.item_selected.connect(_on_weapon_dropdown_selected.bind(t, wpn_opt))

		# Activity dropdown
		var act_opt := OptionButton.new()
		act_opt.custom_minimum_size = Vector2(200, 0)
		act_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(act_opt)
		act_opt.item_selected.connect(_on_activity_dropdown_selected.bind(t, act_opt))

		row_gladiators.append(t)
		row_weapon_options.append(wpn_opt)
		row_activity_options.append(act_opt)

	_refresh_all_dropdowns()
	if assignments_status:
		assignments_status.text = "%d gladiators — choose weapon & activity for each." % row_gladiators.size()


func _refresh_all_dropdowns() -> void:
	_updating_dropdowns = true
	var roster: Array = roster_sheet.roster if roster_sheet else []

	for i in row_gladiators.size():
		var t: GladiatorTemplate = row_gladiators[i]
		var wpn_opt: OptionButton = row_weapon_options[i]
		var act_opt: OptionButton = row_activity_options[i]

		# --- Weapons ---
		wpn_opt.clear()
		wpn_opt.add_item("Unarmed")
		wpn_opt.set_item_metadata(0, null)
		var selected_wpn_idx := 0
		var avail_w := guild_state.get_available_weapons(roster)
		# Always include the one currently assigned to this gladiator
		if t.assigned_weapon != null and not avail_w.has(t.assigned_weapon):
			avail_w.append(t.assigned_weapon)
		for w in avail_w:
			var idx := wpn_opt.item_count
			wpn_opt.add_item(w.display_name)
			wpn_opt.set_item_metadata(idx, w)
			if t.assigned_weapon == w:
				selected_wpn_idx = idx
		wpn_opt.select(selected_wpn_idx)

		# --- Activities ---
		act_opt.clear()
		act_opt.add_item("Observation")
		act_opt.set_item_metadata(0, null)
		var selected_act_idx := 0
		var avail_t := guild_state.get_available_training(roster)
		var avail_m := guild_state.get_available_medics(roster)
		if t.assigned_training != null:
			if t.assigned_training.is_medic:
				if not avail_m.has(t.assigned_training):
					avail_m.append(t.assigned_training)
			else:
				if not avail_t.has(t.assigned_training):
					avail_t.append(t.assigned_training)
		for item in avail_t:
			var idx2 := act_opt.item_count
			act_opt.add_item(item.display_name)
			act_opt.set_item_metadata(idx2, item)
			if t.assigned_training == item:
				selected_act_idx = idx2
		for item in avail_m:
			var idx3 := act_opt.item_count
			act_opt.add_item(item.display_name + " (Medic)")
			act_opt.set_item_metadata(idx3, item)
			if t.assigned_training == item:
				selected_act_idx = idx3
		act_opt.select(selected_act_idx)

	_updating_dropdowns = false


func _on_weapon_dropdown_selected(index: int, t: GladiatorTemplate, opt: OptionButton) -> void:
	if _updating_dropdowns:
		return
	var meta = opt.get_item_metadata(index)
	t.assigned_weapon = meta as WeaponData  # null if Unarmed
	_refresh_all_dropdowns()
	if assignments_status:
		assignments_status.text = "%s → %s" % [t.get_display_name(), t.get_weapon_display()]


func _on_activity_dropdown_selected(index: int, t: GladiatorTemplate, opt: OptionButton) -> void:
	if _updating_dropdowns:
		return
	var meta = opt.get_item_metadata(index)
	t.assigned_training = meta as TrainingEquipment  # null if Observation
	_refresh_all_dropdowns()
	if assignments_status:
		assignments_status.text = "%s → %s" % [t.get_display_name(), t.get_activity_display()]


# ─────────────────────────────────────────────
# Guild ownership view
# ─────────────────────────────────────────────

func _refresh_guild_ownership_ui() -> void:
	if owned_weapons_list == null or owned_training_list == null or guild_state == null:
		return
	owned_weapons_list.clear()
	for w in guild_state.owned_weapons:
		owned_weapons_list.add_item(w.display_name)
	owned_training_list.clear()
	for t in guild_state.owned_training:
		owned_training_list.add_item(t.display_name)
	for m in guild_state.owned_medics:
		owned_training_list.add_item(m.display_name + " (Medic)")
