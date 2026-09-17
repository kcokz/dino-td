# res://scripts/autoload/WindowMode.gd
extends Node

## Fullscreen or windowed, remembered between runs.
##
## The game shipped locked to fullscreen by project setting, which is right for playing
## and wrong for everything else: you cannot put it beside a reference, and you cannot
## screenshot it to point at something. F11 toggles, the pause menu has a picker, and
## the choice is saved next to the language preference rather than in a file of its own.

signal changed(fullscreen: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable while the game is paused
	set_fullscreen(_saved_preference(), false)

func _shortcut_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == _toggle_key():
		toggle()
		get_viewport().set_input_as_handled()

func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func toggle() -> void:
	set_fullscreen(not is_fullscreen())

## `remember` is false only while restoring at startup, so reading the preference back
## does not immediately write it again.
func set_fullscreen(on: bool, remember: bool = true) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if not on:
		# A freshly windowed window can land half off-screen or at the size the project
		# declares, which on a large display is a postage stamp. Centre it and give it a
		# usable size the first time.
		var screen := DisplayServer.screen_get_size()
		var want := Vector2i(int(screen.x * 0.7), int(screen.y * 0.7))
		DisplayServer.window_set_size(want)
		DisplayServer.window_set_position((screen - want) / 2)
	if remember:
		var i18n := get_node_or_null("/root/I18n")
		if i18n and i18n.has_method("save_setting"):
			i18n.save_setting("display", "fullscreen", on)
	changed.emit(on)

func _saved_preference() -> bool:
	var fallback: bool = true
	var cfg := get_node_or_null("/root/Config")
	if cfg and "WINDOW" in cfg:
		fallback = bool(cfg.WINDOW.get("default_fullscreen", true))
	var i18n := get_node_or_null("/root/I18n")
	if i18n and i18n.has_method("load_setting"):
		return bool(i18n.load_setting("display", "fullscreen", fallback))
	return fallback

func _toggle_key() -> int:
	var cfg := get_node_or_null("/root/Config")
	if cfg and "WINDOW" in cfg:
		return int(cfg.WINDOW.get("toggle_key", KEY_F11))
	return KEY_F11
