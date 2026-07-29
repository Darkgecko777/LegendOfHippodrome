# Reference snippet only — see guild_hub.gd for integration.
# After resolver.resolve(), call:
#
# func _write_combat_log_file(resolver: CombatResolver) -> void:
#   var lines: PackedStringArray = []
#   lines.append("=== COMBAT LOG ===")
#   ...
#   var file := FileAccess.open("res://last_combat_log.txt", FileAccess.WRITE)
#   if file:
#       file.store_string("\n".join(lines))
#       file.close()
