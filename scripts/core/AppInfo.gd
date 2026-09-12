# res://scripts/core/AppInfo.gd
class_name AppInfo
extends RefCounted

## Application & Build Metadata for Defend Dinosaur.
## Houses external build information, version numbers, release notes references,
## and environment metadata decoupled from game balance configs.

const VERSION: String = "v0.0"
const APP_NAME: String = "Defend Dinosaur"
const BUILD_STAGE: String = "Prototype"
const ENGINE_TARGET: String = "Godot 4.7"
const RELEASE_DATE: String = "2026-09-11"

## Returns the active application version string.
## Priority order for build-time stamping:
## 1. External version.json file if present on disk (CI/CD build pipeline injection)
## 2. ProjectSettings "application/config/version" if configured
## 3. Internal default VERSION constant ("v0.0")
static func get_version() -> String:
	if FileAccess.file_exists("res://version.json"):
		var file = FileAccess.open("res://version.json", FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK and json.data is Dictionary and json.data.has("version"):
				var v = str(json.data["version"]).strip_edges()
				if v != "":
					return v

	if ProjectSettings.has_setting("application/config/version"):
		var v = ProjectSettings.get_setting("application/config/version")
		if v is String and v.strip_edges() != "":
			return v.strip_edges()

	return VERSION

## Returns formatted full display title, e.g. "Defend Dinosaur v0.0".
static func get_app_title() -> String:
	return "%s %s" % [APP_NAME, get_version()]

## Returns a comprehensive metadata dictionary for about dialogues or build stamping.
static func get_metadata() -> Dictionary:
	return {
		"app_name": APP_NAME,
		"version": get_version(),
		"stage": BUILD_STAGE,
		"engine": ENGINE_TARGET,
		"release_date": RELEASE_DATE,
	}
