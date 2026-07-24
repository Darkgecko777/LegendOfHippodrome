extends Control

## Guild Hub controller.
## Market tab: 5 gladiator offers + weapons + training equipment.
## Purchase gladiators into the existing roster. Gear purchases are stubbed for now.

const MAX_ROSTER_SIZE := 5

@onready var generator: Node = $GladiatorGenerator
@onready var roster_sheet: RosterCharacterSheet = $MarginContainer/TabContainer/Roster/RosterCharacterSheet

# Market UI
@onready var gold_label: Label = %GoldLabel
@onready var renown_label: Label = %RenownLabel
@onready var purchase_button: Button = %PurchaseButton
@onready var market_status: Label = %MarketStatusLabel
@onready var gladiator_list: ItemList = %GladiatorList
@onready var weapon_list: ItemList = %WeaponList
@onready var training_list: ItemList = %TrainingList
@onready var refresh_button: Button = %RefreshMarketButton

var guild_state: GuildState
var market_state: MarketState

# Selection tracking
enum Category { NONE, GLADIATOR, WEAPON, TRAINING }
var selected_category: Category = Category.NONE
var selected_index: int = -1


func _ready() -> void:
	_ensure_guild_state()
	_ensure_market_state()

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

	_refresh_market_ui()
	_update_currency_display()
	_update_purchase_button()


func _ensure_guild_state() -> void:
	# Simple in-memory for now; later this will be loaded/saved by a GameManager.
	if guild_state == null:
		guild_state = GuildState.new()
		guild_state.gold = 600
		guild_state.renown = 20


func _ensure_market_state() -> void:
	if market_state == null:
		market_state = MarketState.new()
		market_state.refresh_weekly(generator)


func _refresh_market_ui() -> void:
	_populate_gladiator_list()
	_populate_weapon_list()
	_populate_training_list()
	_update_market_status()


func _populate_gladiator_list() -> void:
	if gladiator_list == null or market_state == null:
		return
	gladiator_list.clear()
	for offer in market_state.gladiator_offers:
		var t: CharacterTemplate = offer["template"]
		var price: int = offer["price"]
		var desc := _build_fog_descriptors(t)
		var line := "%s  |  Prefers %s  |  %s  |  %d gold" % [
			t.display_name,
			str(t.preferred_weapon).capitalize(),
			desc,
			price
		]
		gladiator_list.add_item(line)


func _populate_weapon_list() -> void:
	if weapon_list == null or market_state == null:
		return
	weapon_list.clear()
	for w in market_state.weapon_offers:
		var line := "%s  (Tier %d)  —  %d gold" % [w.display_name, w.tier, w.cost]
		weapon_list.add_item(line)


func _populate_training_list() -> void:
	if training_list == null or market_state == null:
		return
	training_list.clear()
	for t in market_state.training_offers:
		var line := "%s  (Tier %d)  —  %d gold" % [t.display_name, t.tier, t.cost]
		training_list.add_item(line)


func _build_fog_descriptors(t: CharacterTemplate) -> String:
	## Rank all 7 primaries + Cunning, take two highest and two lowest, map to flavour.
	var stats := [
		{"name": "vitality", "value": t.base_vitality},
		{"name": "endurance", "value": t.base_endurance},
		{"name": "strength", "value": t.base_strength},
		{"name": "agility", "value": t.base_agility},
		{"name": "precision", "value": t.base_precision},
		{"name": "resilience", "value": t.base_resilience},
		{"name": "charisma", "value": t.base_charisma},
		{"name": "cunning", "value": int(t.base_cunning)},
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
	if weapon_list:
		weapon_list.deselect_all()
	if training_list:
		training_list.deselect_all()
	_update_purchase_button()


func _on_weapon_selected(index: int) -> void:
	selected_category = Category.WEAPON
	selected_index = index
	if gladiator_list:
		gladiator_list.deselect_all()
	if training_list:
		training_list.deselect_all()
	_update_purchase_button()


func _on_training_selected(index: int) -> void:
	selected_category = Category.TRAINING
	selected_index = index
	if gladiator_list:
		gladiator_list.deselect_all()
	if weapon_list:
		weapon_list.deselect_all()
	_update_purchase_button()


func _update_purchase_button() -> void:
	if purchase_button == null or guild_state == null:
		return
	var can_buy := false
	if selected_category == Category.GLADIATOR and selected_index >= 0 and selected_index < market_state.gladiator_offers.size():
		var price: int = market_state.gladiator_offers[selected_index]["price"]
		can_buy = guild_state.gold >= price
	elif selected_category == Category.WEAPON and selected_index >= 0 and selected_index < market_state.weapon_offers.size():
		var w: WeaponData = market_state.weapon_offers[selected_index]
		can_buy = guild_state.gold >= w.cost
	elif selected_category == Category.TRAINING and selected_index >= 0 and selected_index < market_state.training_offers.size():
		var t: TrainingEquipment = market_state.training_offers[selected_index]
		can_buy = guild_state.gold >= t.cost
	purchase_button.disabled = not can_buy


func _on_purchase_pressed() -> void:
	if selected_category == Category.NONE or selected_index < 0:
		return

	match selected_category:
		Category.GLADIATOR:
			_purchase_gladiator(selected_index)
		Category.WEAPON:
			_purchase_weapon(selected_index)
		Category.TRAINING:
			_purchase_training(selected_index)

	selected_category = Category.NONE
	selected_index = -1
	_update_purchase_button()
	_update_currency_display()
	_update_market_status()


func _purchase_gladiator(index: int) -> void:
	if index < 0 or index >= market_state.gladiator_offers.size():
		return
	if roster_sheet == null:
		return

	var current := roster_sheet.roster
	if current.size() >= MAX_ROSTER_SIZE:
		if market_status:
			market_status.text = "Roster is full (%d/%d). Release someone first." % [current.size(), MAX_ROSTER_SIZE]
		return

	var offer: Dictionary = market_state.gladiator_offers[index]
	var price: int = offer["price"]
	var template: CharacterTemplate = offer["template"]

	if not guild_state.spend_gold(price):
		if market_status:
			market_status.text = "Not enough gold."
		return

	var new_roster: Array[CharacterTemplate] = []
	new_roster.assign(current)
	new_roster.append(template)
	roster_sheet.set_roster(new_roster)

	market_state.remove_gladiator_offer(index)
	_populate_gladiator_list()

	if market_status:
		market_status.text = "Recruited %s for %d gold — Roster %d/%d" % [
			template.display_name, price, new_roster.size(), MAX_ROSTER_SIZE
		]
	print("Purchased gladiator: %s [%s] for %d gold" % [template.display_name, template.character_id, price])


func _purchase_weapon(index: int) -> void:
	if index < 0 or index >= market_state.weapon_offers.size():
		return
	var w: WeaponData = market_state.weapon_offers[index]
	if not guild_state.spend_gold(w.cost):
		if market_status:
			market_status.text = "Not enough gold."
		return
	# Stub: inventory system comes later. Just deduct gold and report.
	if market_status:
		market_status.text = "Purchased %s for %d gold (inventory stub)." % [w.display_name, w.cost]
	print("Purchased weapon: %s for %d gold" % [w.display_name, w.cost])


func _purchase_training(index: int) -> void:
	if index < 0 or index >= market_state.training_offers.size():
		return
	var t: TrainingEquipment = market_state.training_offers[index]
	if not guild_state.spend_gold(t.cost):
		if market_status:
			market_status.text = "Not enough gold."
		return
	# Stub: inventory system comes later.
	if market_status:
		market_status.text = "Purchased %s for %d gold (inventory stub)." % [t.display_name, t.cost]
	print("Purchased training: %s for %d gold" % [t.display_name, t.cost])


func _on_refresh_pressed() -> void:
	market_state.refresh_weekly(generator)
	selected_category = Category.NONE
	selected_index = -1
	_refresh_market_ui()
	_update_purchase_button()
	if market_status:
		market_status.text = "Market refreshed for a new week."


func _update_currency_display() -> void:
	if gold_label and guild_state:
		gold_label.text = "Gold: %d" % guild_state.gold
	if renown_label and guild_state:
		renown_label.text = "Renown: %d" % guild_state.renown


func _update_market_status() -> void:
	if market_status == null or roster_sheet == null:
		return
	var count := roster_sheet.roster.size()
	var offers := market_state.gladiator_offers.size() if market_state else 0
	market_status.text = "Roster: %d/%d  |  Gladiator offers this week: %d" % [count, MAX_ROSTER_SIZE, offers]
