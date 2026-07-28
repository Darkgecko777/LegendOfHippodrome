class_name GladiatorCard
extends PanelContainer

## Compact reusable card showing name, fame, weapon and activity.
## Unarmed / Observation are rendered in red.

signal gladiator_selected(template: GladiatorTemplate)

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var fame_label: Label = %FameLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var activity_label: Label = %ActivityLabel

var template: GladiatorTemplate

const COLOR_NORMAL := Color(0.9, 0.85, 0.75)
const COLOR_WARNING := Color(0.95, 0.35, 0.3)


func setup(t: GladiatorTemplate) -> void:
	template = t
	_refresh()


func _refresh() -> void:
	if template == null:
		return
	if name_label:
		name_label.text = template.get_display_name()
	if fame_label:
		fame_label.text = "Fame: %d" % template.fame
	if weapon_label:
		var w_text := template.get_weapon_display()
		weapon_label.text = "Weapon: %s" % w_text
		weapon_label.add_theme_color_override("font_color", COLOR_WARNING if w_text == "Unarmed" else COLOR_NORMAL)
	if activity_label:
		var a_text := template.get_activity_display()
		activity_label.text = "Activity: %s" % a_text
		activity_label.add_theme_color_override("font_color", COLOR_WARNING if a_text == "Observation" else COLOR_NORMAL)
	if portrait and template.portrait:
		portrait.texture = template.portrait


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if template:
			gladiator_selected.emit(template)
		# Simple visual selection feedback
		modulate = Color(1.15, 1.1, 0.95)


func clear_selection_visual() -> void:
	modulate = Color.WHITE
