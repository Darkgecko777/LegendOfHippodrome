extends Node

# For editor testing / quick battles
@export var player_definition: GladiatorTemplate
@export var enemy_definition: GladiatorTemplate

# Main roster (persistent)
var guild_roster: Array[GladiatorTemplate] = []


## Create a combat token from a persistent roster entry.
## Uses create_runtime_data() so the roster copy is not mutated by combat.
func create_token_from_template(persistent: GladiatorTemplate, is_player: bool = false) -> CharacterToken:
	if not persistent:
		push_error("CharacterManager: Missing persistent character!")
		return null

	var data := persistent.create_runtime_data()

	var token_scene := preload("res://scenes/Character_Token.tscn")
	var token := token_scene.instantiate() as CharacterToken
	token.data = data
	token.is_player_controlled = is_player

	return token


## Convenience for quick testing
func create_fight_pair() -> Dictionary:
	return {
		"player": create_token_from_template(player_definition, true),
		"enemy": create_token_from_template(enemy_definition, false)
	}


## Add a generated gladiator to the persistent roster.
func add_to_roster(template: GladiatorTemplate) -> void:
	if template:
		guild_roster.append(template)
