class_name GuildState
extends Resource

## Persistent container for core guild values.
## Created by the game if none exists on first run / new game.

@export var gold: int = 600
@export var renown: int = 20


func add_gold(amount: int) -> void:
	gold += max(amount, 0)


func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	return true


func add_renown(amount: int) -> void:
	renown += max(amount, 0)


func apply_renown_decay(amount: int) -> void:
	renown = max(renown - max(amount, 0), 0)
