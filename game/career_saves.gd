class_name CareerSaves
extends RefCounted
## The career save slots (docs/03 §10.1, D301; docs/04 §11, A11): one Career a slot, as a JSON file in the
## player's user://saves/ folder (on Windows %APPDATA%\Godot\app_userdata\Chin Check\saves; in the browser build,
## the browser's storage for the page, so clearing the site's data clears them).
##
## A save can't be lost to a crash half way through writing it (R8): it's written to a temporary file first and read
## back, and only then does it take the slot's place. The save it replaces is kept as the slot's backup, and loading
## falls back to the backup when the main file is missing or damaged.

const DIR := "user://saves/"
## How many careers can be saved side by side.
const SLOTS: int = 3
const MAIN_FILE := "slot_%d.json"
const BACKUP_FILE := "slot_%d.backup.json"
const TEMP_FILE := "slot_%d.tmp"

## Whether the last load_slot() had to use the backup.
static var used_backup: bool = false


## Saves the career into a slot (0 … SLOTS − 1). Returns true when it's safely on disk.
static func save(career: Career, slot: int, dir: String = DIR) -> bool:
	assert(slot >= 0 and slot < SLOTS, "career slots are 0 to %d" % (SLOTS - 1))
	DirAccess.make_dir_recursive_absolute(dir)
	var data: Dictionary = career.to_dict()
	data.saved_at = Time.get_datetime_string_from_system(true)
	data.saved_unix = Time.get_unix_time_from_system()
	data.game = { "name": String(ProjectSettings.get_setting("application/config/name")), "godot": Engine.get_version_info().string }
	var temp: String = dir.path_join(TEMP_FILE % slot)
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	# Full precision, so a fraction of a stat point comes back exactly as it went.
	file.store_string(JSON.stringify(data, "\t", true, true))
	file.close()
	if _read(temp).is_empty():
		DirAccess.remove_absolute(temp)
		return false
	var main: String = main_path(slot, dir)
	var backup: String = backup_path(slot, dir)
	if FileAccess.file_exists(main):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(main, backup) != OK:
			return false
	return DirAccess.rename_absolute(temp, main) == OK


## The career in a slot, or null when the slot is empty or neither its save nor its backup can be read.
static func load_slot(slot: int, dir: String = DIR, library: TrainingLibrary = null) -> Career:
	used_backup = false
	for path: String in [main_path(slot, dir), backup_path(slot, dir)]:
		var data: Dictionary = _read(path)
		if data.is_empty():
			continue
		var career: Career = Career.from_dict(data, library)
		if career != null:
			used_backup = path == backup_path(slot, dir)
			return career
	return null


## What the load screen shows for a slot: the career's summary plus `saved_at`, `saved_unix` and `backup` (true when
## only the backup could be read). {} for an empty slot.
static func info(slot: int, dir: String = DIR) -> Dictionary:
	for path: String in [main_path(slot, dir), backup_path(slot, dir)]:
		var data: Dictionary = _read(path)
		if data.is_empty() or Career.migrate(data).is_empty():
			continue
		var out: Dictionary = data.get("summary", {}).duplicate(true)
		out.saved_at = String(data.get("saved_at", ""))
		out.saved_unix = float(data.get("saved_unix", 0.0))
		out.backup = path == backup_path(slot, dir)
		return out
	return {}


## The slot saved most recently (what *Continue* loads), or −1 when every slot is empty.
static func latest(dir: String = DIR) -> int:
	var best: int = -1
	var best_time: float = -1.0
	for slot in SLOTS:
		var slot_info: Dictionary = info(slot, dir)
		if not slot_info.is_empty() and float(slot_info.saved_unix) > best_time:
			best = slot
			best_time = float(slot_info.saved_unix)
	return best


## The first empty slot, or −1 when they're all in use.
static func free_slot(dir: String = DIR) -> int:
	for slot in SLOTS:
		if info(slot, dir).is_empty():
			return slot
	return -1


## Deletes a slot's save and its backup.
static func delete(slot: int, dir: String = DIR) -> void:
	for path: String in [main_path(slot, dir), backup_path(slot, dir), dir.path_join(TEMP_FILE % slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


static func main_path(slot: int, dir: String = DIR) -> String:
	return dir.path_join(MAIN_FILE % slot)


static func backup_path(slot: int, dir: String = DIR) -> String:
	return dir.path_join(BACKUP_FILE % slot)


## A JSON file's contents, or {} when it's missing or isn't a JSON object.
static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()  # An instance's parse() reports a damaged file quietly; JSON.parse_string() prints an error.
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
