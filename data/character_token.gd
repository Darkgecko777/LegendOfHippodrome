class_name CharacterToken
extends Node2D

signal health_changed(new_health: int)

@export var data: GladiatorTemplate
@export var is_player_controlled: bool = false

var sprite: Sprite2D
var attack_sound_player: AudioStreamPlayer

var abilities: Array[Ability] = []
var current_stance: String = "Neutral"


func _ready() -> void:
	sprite = get_node_or_null("Base/Sprite2D")

	if sprite and data and data.sprite_texture:
		sprite.texture = data.sprite_texture

	if data:
		data.reset_for_battle()
		if not data.health_changed.is_connected(_on_health_changed):
			data.health_changed.connect(_on_health_changed)

	setup_sound_player()
	initialize_abilities()


func _process(delta: float) -> void:
	if not data or not data.is_alive:
		return

	# Stance timer logic (Cunning will drive re-evaluation later)
	if data.stance_timer > 0.0:
		data.stance_timer -= delta
		if data.stance_timer <= 0.0:
			pass  # AI stance re-evaluation placeholder

	for ability in abilities:
		ability.current_cooldown = max(0.0, ability.current_cooldown - delta)

	if can_auto_attack():
		perform_auto_attack()


func setup_sound_player() -> void:
	attack_sound_player = AudioStreamPlayer.new()
	attack_sound_player.name = "AttackSound"
	add_child(attack_sound_player)


func initialize_abilities() -> void:
	abilities.clear()
	if data and data.abilities.size() > 0:
		for ab in data.abilities:
			var new_ability = ab.duplicate()
			abilities.append(new_ability)
	else:
		var basic = Ability.new()
		basic.display_name = "Basic Attack"
		var effect = AbilityEffect.new()
		basic.effect = effect
		abilities.append(basic)


func can_auto_attack() -> bool:
	for ability in abilities:
		if ability.is_ready():
			return true
	return false


func perform_auto_attack() -> void:
	var target = find_target()
	if not target or not target.data or not target.data.is_alive:
		return

	for ability in abilities:
		if ability.is_ready():
			ability.use(self, target)
			return


func find_target() -> CharacterToken:
	var parent = get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is CharacterToken and child != self:
			return child
	return null


func animate_attack() -> void:
	if not sprite:
		return
	var original_rot = sprite.rotation_degrees
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", 30.0 if is_player_controlled else -30.0, 0.08)
	tween.tween_property(sprite, "rotation_degrees", original_rot, 0.15)


func take_damage(amount: int) -> void:
	if data:
		data.take_damage(amount)
		if not data.is_alive:
			print(data.get_display_name() + " has been defeated!")


func _on_health_changed(new_health: int) -> void:
	health_changed.emit(new_health)
