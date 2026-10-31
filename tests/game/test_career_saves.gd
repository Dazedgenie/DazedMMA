extends GutTest
## CareerSaves (game/career_saves.gd, docs/03 §10.1, D301; docs/04 §11): career slots that a crash can't wipe out.

const TEST_DIR := "user://test_career_saves/"


func before_each() -> void:
	_clear()


func after_all() -> void:
	_clear()


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file))


func _career(career_seed: int = 1) -> Career:
	var p: Dictionary = FighterLibrary.load_dir().profile("wrestler")
	p.age = 16
	return Career.create(p, career_seed, { "coach": "Sam", "nickname": "The Hammer" })


func test_a_saved_career_loads_back_from_its_slot() -> void:
	var c: Career = _career()
	c.run_week()
	assert_true(CareerSaves.save(c, 0, TEST_DIR))
	var back: Career = CareerSaves.load_slot(0, TEST_DIR)
	assert_not_null(back)
	assert_eq(back.fighter_name(), "Wrestler")
	assert_eq(back.week, 1)
	assert_false(CareerSaves.used_backup)


func test_an_empty_slot_loads_nothing() -> void:
	assert_null(CareerSaves.load_slot(1, TEST_DIR))
	assert_eq(CareerSaves.info(1, TEST_DIR), {})
	assert_eq(CareerSaves.latest(TEST_DIR), -1, "nothing to continue")
	assert_eq(CareerSaves.free_slot(TEST_DIR), 0)


func test_no_temporary_file_is_left_behind() -> void:
	CareerSaves.save(_career(), 0, TEST_DIR)
	assert_false(FileAccess.file_exists(TEST_DIR.path_join(CareerSaves.TEMP_FILE % 0)))
	assert_true(FileAccess.file_exists(CareerSaves.main_path(0, TEST_DIR)))


func test_saving_again_keeps_the_last_save_as_the_backup() -> void:
	var c: Career = _career()
	CareerSaves.save(c, 0, TEST_DIR)
	c.run_week()
	CareerSaves.save(c, 0, TEST_DIR)
	assert_eq(int(CareerSaves._read(CareerSaves.main_path(0, TEST_DIR)).calendar.week), 1)
	assert_eq(int(CareerSaves._read(CareerSaves.backup_path(0, TEST_DIR)).calendar.week), 0, "the save before is the backup")


func test_a_damaged_save_falls_back_to_the_backup() -> void:
	var c: Career = _career()
	CareerSaves.save(c, 0, TEST_DIR)
	c.run_week()
	CareerSaves.save(c, 0, TEST_DIR)
	var file: FileAccess = FileAccess.open(CareerSaves.main_path(0, TEST_DIR), FileAccess.WRITE)
	file.store_string("{ \"schema\": \"career\", \"vers")  # Cut off half way, as a crash might leave it.
	file.close()
	var back: Career = CareerSaves.load_slot(0, TEST_DIR)
	assert_not_null(back, "the backup still loads")
	assert_eq(back.week, 0, "a week back, not lost")
	assert_true(CareerSaves.used_backup)
	assert_true(CareerSaves.info(0, TEST_DIR).backup, "the load screen can say it came from the backup")


func test_continue_picks_the_slot_saved_last() -> void:
	CareerSaves.save(_career(1), 2, TEST_DIR)
	OS.delay_msec(10)
	CareerSaves.save(_career(2), 0, TEST_DIR)
	assert_eq(CareerSaves.latest(TEST_DIR), 0)
	OS.delay_msec(10)
	CareerSaves.save(_career(1), 2, TEST_DIR)
	assert_eq(CareerSaves.latest(TEST_DIR), 2)
	assert_eq(CareerSaves.free_slot(TEST_DIR), 1)


func test_deleting_a_slot_removes_its_save_and_its_backup() -> void:
	var c: Career = _career()
	CareerSaves.save(c, 0, TEST_DIR)
	CareerSaves.save(c, 0, TEST_DIR)
	CareerSaves.delete(0, TEST_DIR)
	assert_eq(CareerSaves.info(0, TEST_DIR), {})
	assert_false(FileAccess.file_exists(CareerSaves.main_path(0, TEST_DIR)))
	assert_false(FileAccess.file_exists(CareerSaves.backup_path(0, TEST_DIR)))
	assert_eq(CareerSaves.free_slot(TEST_DIR), 0)


func test_the_load_screen_reads_a_slot_without_loading_the_career() -> void:
	CareerSaves.save(_career(), 0, TEST_DIR)
	var slot: Dictionary = CareerSaves.info(0, TEST_DIR)
	assert_eq(slot.name, "Wrestler")
	assert_eq(slot.nickname, "The Hammer")
	assert_eq(slot.age, 16.0)
	assert_eq(slot.date, "Mon 4 Jan 2027")
	assert_eq(slot.amateur_record, "0-0-0")
	assert_ne(slot.saved_at, "")
	assert_false(slot.backup)
