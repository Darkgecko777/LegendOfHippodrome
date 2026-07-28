extends Control

## Guild Hub controller — Option A layout.
## Global chrome (gold/renown + Advance Week + Fight) is always visible.
## Tabs: Roster | Market | Assignments | Guild | Calendar

const MAX_ROSTER_SIZE := 5
const GLADIATOR_CARD_SCENE := preload("res://ui/GladiatorCard.tscn")

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
@onready var card_container: VBoxContainer = %CardContainer
@onready var assign_weapon_list: ItemList = %AssignWeaponList
@onready var assign_training_list: ItemList = %AssignTrainingList
@onready var prediction_label: Label = %PredictionLabel
@onready var assign_button: Button = %AssignButton
@onready var unassign_weapon_button: Button = %UnassignWeaponButton
@onready var unassign_training_button: Button = %UnassignTrainingButton
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

# Assignments selection
var selected_gladiator: CharacterTemplate = null
var selected_assign_weapon_idx: int = -1
var selected_assign_training_idx: int = -1
var card_instances: Array[GladiatorCard] = []


func _ready() -> void:
	_ensure_guild_state()
	_ensure_market_state()

	# Global
	if advance_week_button:
		advance_week_button.pressed.connect(_on_advance_week_pressed)
	if fight_button:
		fight_button.disabled = true  # not wired yet

	# Market
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

	# Assignments
	if assign_weapon_list:
		assign_weapon_list.item_selected.connect(_on_assign_weapon_selected)
	if assign_training_list:
		assign_training_list.item_selected.connect(_on_assign_training_selected)
	if assign_button:
		assign_button.pressed.connect(_on_assign_pressed)
	if unassign_weapon_button:
		unassign_weapon_button.pressed.connect(_on_unassign_weapon_pressed)
	if unassign_training_button:
		unassign_training_button.pressed.connect(_on_unassign_training_pressed)

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
	_refresh_assignments_ui()
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

	# Soft unused-training safeguard
	var has_observer := false
	for g in roster:
		if g is CharacterTemplate and g.assigned_training == null:
			has_observer = true
			break
	var has_unused := guild_state.get_available_training(roster).size() > 0
	if has_observer and has_unused:
		print("Advance Week warning: observers present and unused training available.")
		# Full confirmation dialog can be added later; for now we proceed.

	var summary: Array[String] = WeekResolver.resolve_week(roster, guild_state)
	for line in summary:
		print(line)

	# Clear assignments after resolution so next week starts clean
	for g in roster:
		if g is CharacterTemplate:
			g.assigned_training = null
			# Weapons stay equipped until unassigned

	_refresh_all()
	if market_status:
		market_status.text = "Week advanced to %d. See console for full summary." % guild_state.current_week


# ─────────────────────────────────────────────
# Market
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
		var t: CharacterTemplate = offer["template"]
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


func _build_fog_descriptors(t: CharacterTemplate) -> String:
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
	_refresh_assignments_ui()
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
	var template: CharacterTemplate = offer["template"]
	if not guild_state.spend_gold(price):
		if market_status: market_status.text = "Not enough gold."
		return
	var new_roster: Array[CharacterTemplate] = []
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
# Assignments
# ─────────────────────────────────────────────

func _refresh_assignments_ui() -> void:
	_rebuild_cards()
	_populate_assign_lists()
	_update_prediction()
	_update_assign_buttons()


func _rebuild_cards() -> void:
	if card_container == null or roster_sheet == null:
		return
	for c in card_instances:
		if is_instance_valid(c):
			c.queue_free()
	card_instances.clear()
	for g in roster_sheet.roster:
		if not g is CharacterTemplate:
			continue
		var card: GladiatorCard = GLADIATOR_CARD_SCENE.instantiate()
		card_container.add_child(card)
		card.setup(g)
		card.gladiator_selected.connect(_on_card_selected)
		card_instances.append(card)


func _on_card_selected(t: CharacterTemplate) -> void:
	selected_gladiator = t
	for c in card_instances:
		c.clear_selection_visual()
	# Re-highlight the selected one (simple approach)
	for c in card_instances:
		if c.template == t:
			c.modulate = Color(1.15, 1.1, 0.95)
	selected_assign_weapon_idx = -1
	selected_assign_training_idx = -1
	if assign_weapon_list: assign_weapon_list.deselect_all()
	if assign_training_list: assign_training_list.deselect_all()
	_populate_assign_lists()
	_update_prediction()
	_update_assign_buttons()
	if assignments_status:
		assignments_status.text = "Selected: %s" % t.get_display_name()


func _populate_assign_lists() -> void:
	if assign_weapon_list == null or assign_training_list == null or guild_state == null or roster_sheet == null:
		return
	var roster: Array = roster_sheet.roster
	assign_weapon_list.clear()
	for w in guild_state.get_available_weapons(roster):
		assign_weapon_list.add_item(w.display_name)
	assign_training_list.clear()
	for t in guild_state.get_available_training(roster):
		assign_training_list.add_item(t.display_name)
	for m in guild_state.get_available_medics(roster):
		assign_training_list.add_item(m.display_name + " (Medic)")


func _on_assign_weapon_selected(index: int) -> void:
	selected_assign_weapon_idx = index
	selected_assign_training_idx = -1
	if assign_training_list: assign_training_list.deselect_all()
	_update_prediction()
	_update_assign_buttons()


func _on_assign_training_selected(index: int) -> void:
	selected_assign_training_idx = index
	selected_assign_weapon_idx = -1
	if assign_weapon_list: assign_weapon_list.deselect_all()
	_update_prediction()
	_update_assign_buttons()


func _update_prediction() -> void:
	if prediction_label == null:
		return
	if selected_gladiator == null:
		prediction_label.text = "Select a gladiator, then a weapon or training item."
		return
	if selected_assign_weapon_idx >= 0:
		var avail := guild_state.get_available_weapons(roster_sheet.roster)
		if selected_assign_weapon_idx < avail.size():
			var w: WeaponData = avail[selected_assign_weapon_idx]
			prediction_label.text = "Will equip: %s\n(Unarmed → Armed)" % w.display_name
			return
	if selected_assign_training_idx >= 0:
		var train := guild_state.get_available_training(roster_sheet.roster)
		var meds := guild_state.get_available_medics(roster_sheet.roster)
		var all: Array = []
		all.append_array(train)
		all.append_array(meds)
		if selected_assign_training_idx < all.size():
			var item: TrainingEquipment = all[selected_assign_training_idx]
			if item.is_medic:
				prediction_label.text = "Medic\nRecovery chance × %.2f this week" % item.recovery_multiplier
			elif item.linked_primary == &"cunning":
				prediction_label.text = "%s\nCurrent Cunning +%.1f–%.1f" % [item.display_name, item.cunning_gain_min, item.cunning_gain_max]
			elif item.linked_primary == &"weapon":
				prediction_label.text = "%s\nWeapon skill +0.08" % item.display_name
			else:
				var secs := ", ".join(item.possible_secondaries)
				prediction_label.text = "%s\nOne of: %s" % [item.display_name, secs]
			return
	prediction_label.text = "Select a weapon or training item to see predicted effect."


func _update_assign_buttons() -> void:
	if assign_button:
		assign_button.disabled = selected_gladiator == null or (selected_assign_weapon_idx < 0 and selected_assign_training_idx < 0)
	if unassign_weapon_button:
		unassign_weapon_button.disabled = selected_gladiator == null or selected_gladiator.assigned_weapon == null
	if unassign_training_button:
		unassign_training_button.disabled = selected_gladiator == null or selected_gladiator.assigned_training == null


func _on_assign_pressed() -> void:
	if selected_gladiator == null:
		return
	var roster: Array = roster_sheet.roster
	if selected_assign_weapon_idx >= 0:
		var avail := guild_state.get_available_weapons(roster)
		if selected_assign_weapon_idx < avail.size():
			selected_gladiator.assigned_weapon = avail[selected_assign_weapon_idx]
	elif selected_assign_training_idx >= 0:
		var train := guild_state.get_available_training(roster)
		var meds := guild_state.get_available_medics(roster)
		var all: Array = []
		all.append_array(train)
		all.append_array(meds)
		if selected_assign_training_idx < all.size():
			selected_gladiator.assigned_training = all[selected_assign_training_idx]
	_refresh_assignments_ui()
	if assignments_status and selected_gladiator:
		assignments_status.text = "%s updated — %s / %s" % [
			selected_gladiator.get_display_name(),
			selected_gladiator.get_weapon_display(),
			selected_gladiator.get_activity_display()
		]


func _on_unassign_weapon_pressed() -> void:
	if selected_gladiator:
		selected_gladiator.assigned_weapon = null
		_refresh_assignments_ui()


func _on_unassign_training_pressed() -> void:
	if selected_gladiator:
		selected_gladiator.assigned_training = null
		_refresh_assignments_ui()


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
