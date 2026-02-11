## test_bandit_hideout_generation.gd - Test dungeon generation viability
## Run this scene to validate that bandit hideout dungeons generate correctly 25 times each
extends Node3D

const TEST_COUNT := 25

var current_test := 0
var current_level := 1
var passed_tests := 0
var failed_tests := 0
var results: Array[Dictionary] = []

var generator: DungeonGenerator


func _ready() -> void:
	print("=" * 60)
	print("BANDIT HIDEOUT DUNGEON GENERATION TEST")
	print("Testing %d generations for each level" % TEST_COUNT)
	print("=" * 60)

	# Start testing level 1
	_run_next_test()


func _run_next_test() -> void:
	current_test += 1

	# Switch levels after TEST_COUNT tests
	if current_test > TEST_COUNT and current_level == 1:
		current_level = 2
		current_test = 1

	# All tests complete
	if current_test > TEST_COUNT and current_level == 2:
		_report_results()
		return

	print("\n[Test L%d #%d] Running..." % [current_level, current_test])

	# Clean up previous generator
	if generator:
		generator.queue_free()
		await get_tree().process_frame

	# Create new generator
	generator = DungeonGenerator.new()
	add_child(generator)

	# Configure based on level
	if current_level == 1:
		_setup_level_1()
	else:
		_setup_level_2()

	# Connect signal
	generator.generation_complete.connect(_on_generation_complete)

	# Generate with random seed
	var test_seed := randi()
	generator.generate(test_seed)


func _setup_level_1() -> void:
	generator.zone_id = "bandit_hideout_level_1_test"
	generator.grid_size = 15.0
	generator.max_rooms = 7
	generator.min_rooms = 5
	generator.total_enemies_min = 6
	generator.total_enemies_max = 12
	generator.total_chests_min = 2
	generator.total_chests_max = 4
	generator.has_boss = false
	generator.min_rooms_with_enemies = 3

	# Create room templates
	_create_l1_entrance_template()
	_create_l1_corridor_template()
	_create_l1_storage_template()
	_create_l1_barracks_template()
	_create_l1_exit_template()


func _setup_level_2() -> void:
	generator.zone_id = "bandit_hideout_level_2_test"
	generator.grid_size = 15.0
	generator.max_rooms = 6
	generator.min_rooms = 4
	generator.total_enemies_min = 5
	generator.total_enemies_max = 10
	generator.total_chests_min = 2
	generator.total_chests_max = 4
	generator.has_boss = true
	generator.min_rooms_with_enemies = 2

	# Create room templates
	_create_l2_entrance_template()
	_create_l2_corridor_template()
	_create_l2_guardroom_template()
	_create_l2_treasure_vault_template()
	_create_l2_boss_template()


# Level 1 Templates
func _create_l1_entrance_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l1_entrance"
	template.room_type = "entrance"
	template.width = 10
	template.depth = 10
	template.height = 4
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 5), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(5, 0, 0), Vector3.RIGHT, 4.0),
		RoomTemplate.make_door(Vector3(-5, 0, 0), Vector3.LEFT, 4.0),
	]
	template.floor_color = Color(0.12, 0.1, 0.08)
	template.wall_color = Color(0.18, 0.14, 0.11)
	generator.add_template(template)


func _create_l1_corridor_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l1_corridor"
	template.room_type = "corridor"
	template.width = 5
	template.depth = 12
	template.height = 3
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 6), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, -6), Vector3.BACK, 4.0),
	]
	template.floor_color = Color(0.1, 0.08, 0.06)
	template.wall_color = Color(0.16, 0.12, 0.1)
	generator.add_template(template)


func _create_l1_storage_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l1_storage"
	template.room_type = "treasure"
	template.width = 8
	template.depth = 8
	template.height = 3
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 4), Vector3.FORWARD, 4.0),
	]
	template.chest_count = 2
	template.floor_color = Color(0.11, 0.09, 0.07)
	template.wall_color = Color(0.17, 0.13, 0.1)
	generator.add_template(template)


func _create_l1_barracks_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l1_barracks"
	template.room_type = "guard"
	template.width = 12
	template.depth = 10
	template.height = 4
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 5), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, -5), Vector3.BACK, 4.0),
		RoomTemplate.make_door(Vector3(6, 0, 0), Vector3.RIGHT, 4.0),
	]
	template.min_enemies = 2
	template.max_enemies = 4
	template.floor_color = Color(0.13, 0.1, 0.08)
	template.wall_color = Color(0.19, 0.15, 0.12)
	generator.add_template(template)


func _create_l1_exit_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l1_exit"
	template.room_type = "special"
	template.width = 8
	template.depth = 8
	template.height = 4
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, -4), Vector3.BACK, 4.0),
	]
	template.min_enemies = 1
	template.max_enemies = 2
	template.floor_color = Color(0.14, 0.11, 0.09)
	template.wall_color = Color(0.2, 0.16, 0.13)
	generator.add_template(template)


# Level 2 Templates
func _create_l2_entrance_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l2_entrance"
	template.room_type = "entrance"
	template.width = 10
	template.depth = 10
	template.height = 4
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 5), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(5, 0, 0), Vector3.RIGHT, 4.0),
	]
	template.floor_color = Color(0.14, 0.11, 0.09)
	template.wall_color = Color(0.2, 0.16, 0.13)
	generator.add_template(template)


func _create_l2_corridor_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l2_corridor"
	template.room_type = "corridor"
	template.width = 5
	template.depth = 12
	template.height = 4
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 6), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, -6), Vector3.BACK, 4.0),
	]
	template.floor_color = Color(0.12, 0.09, 0.07)
	template.wall_color = Color(0.18, 0.14, 0.11)
	generator.add_template(template)


func _create_l2_guardroom_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l2_guardroom"
	template.room_type = "guard"
	template.width = 10
	template.depth = 10
	template.height = 4
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 5), Vector3.FORWARD, 4.0),
		RoomTemplate.make_door(Vector3(0, 0, -5), Vector3.BACK, 4.0),
		RoomTemplate.make_door(Vector3(5, 0, 0), Vector3.RIGHT, 4.0),
	]
	template.min_enemies = 2
	template.max_enemies = 3
	template.floor_color = Color(0.15, 0.12, 0.09)
	template.wall_color = Color(0.21, 0.17, 0.13)
	generator.add_template(template)


func _create_l2_treasure_vault_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l2_vault"
	template.room_type = "treasure"
	template.width = 8
	template.depth = 8
	template.height = 3
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, 4), Vector3.FORWARD, 4.0),
	]
	template.chest_count = 3
	template.min_enemies = 1
	template.max_enemies = 2
	template.floor_color = Color(0.16, 0.13, 0.1)
	template.wall_color = Color(0.22, 0.18, 0.14)
	generator.add_template(template)


func _create_l2_boss_template() -> void:
	var template := RoomTemplate.new()
	template.room_id = "l2_boss"
	template.room_type = "boss"
	template.width = 14
	template.depth = 14
	template.height = 5
	template.is_boss_room = true
	template.doors = [
		RoomTemplate.make_door(Vector3(0, 0, -7), Vector3.BACK, 5.0),
	]
	template.min_enemies = 2
	template.max_enemies = 3
	template.chest_count = 2
	template.floor_color = Color(0.18, 0.14, 0.11)
	template.wall_color = Color(0.24, 0.19, 0.15)
	generator.add_template(template)


func _on_generation_complete(_dungeon: DungeonGenerator) -> void:
	# Validate results
	var room_count: int = generator.rooms.size()
	var min_required: int = generator.min_rooms
	var is_valid: bool = room_count >= min_required

	# Check connectivity
	var entrance = generator.get_entrance_room()
	var all_connected: bool = true
	if entrance:
		all_connected = _check_all_rooms_reachable(entrance)
	else:
		all_connected = false

	# Check boss room for level 2
	var boss_ok: bool = true
	if current_level == 2 and generator.has_boss:
		var boss_room = generator.get_boss_room()
		boss_ok = boss_room != null

	var success: bool = is_valid and all_connected and boss_ok

	var result := {
		"level": current_level,
		"test": current_test,
		"seed": generator.actual_seed,
		"rooms": room_count,
		"min_required": min_required,
		"connected": all_connected,
		"boss_placed": boss_ok if current_level == 2 else true,
		"success": success
	}
	results.append(result)

	if success:
		passed_tests += 1
		print("[Test L%d #%d] PASSED - %d rooms, seed: %d" % [current_level, current_test, room_count, generator.actual_seed])
	else:
		failed_tests += 1
		var reasons: Array[String] = []
		if not is_valid:
			reasons.append("only %d/%d rooms" % [room_count, min_required])
		if not all_connected:
			reasons.append("rooms not connected")
		if not boss_ok:
			reasons.append("no boss room")
		print("[Test L%d #%d] FAILED - %s (seed: %d)" % [current_level, current_test, ", ".join(reasons), generator.actual_seed])

	# Run next test after a frame delay
	await get_tree().process_frame
	_run_next_test()


func _check_all_rooms_reachable(start: DungeonRoom) -> bool:
	var visited: Array[DungeonRoom] = []
	var queue: Array[DungeonRoom] = [start]

	while not queue.is_empty():
		var current: DungeonRoom = queue.pop_front()
		if current in visited:
			continue
		visited.append(current)

		for dir: Vector3 in current.connected_rooms:
			var neighbor: DungeonRoom = current.connected_rooms[dir]
			if neighbor and neighbor not in visited:
				queue.append(neighbor)

	return visited.size() == generator.rooms.size()


func _report_results() -> void:
	print("\n" + "=" * 60)
	print("TEST RESULTS SUMMARY")
	print("=" * 60)

	# Level 1 results
	var l1_passed := 0
	var l1_failed := 0
	var l1_avg_rooms := 0.0

	for r in results:
		if r.level == 1:
			if r.success:
				l1_passed += 1
			else:
				l1_failed += 1
			l1_avg_rooms += r.rooms

	l1_avg_rooms /= TEST_COUNT

	print("\nLevel 1 (Storage Level):")
	print("  Passed: %d/%d (%.1f%%)" % [l1_passed, TEST_COUNT, 100.0 * l1_passed / TEST_COUNT])
	print("  Failed: %d" % l1_failed)
	print("  Average rooms: %.1f" % l1_avg_rooms)

	# Level 2 results
	var l2_passed := 0
	var l2_failed := 0
	var l2_avg_rooms := 0.0
	var l2_boss_placed := 0

	for r in results:
		if r.level == 2:
			if r.success:
				l2_passed += 1
			else:
				l2_failed += 1
			l2_avg_rooms += r.rooms
			if r.boss_placed:
				l2_boss_placed += 1

	l2_avg_rooms /= TEST_COUNT

	print("\nLevel 2 (Boss Lair):")
	print("  Passed: %d/%d (%.1f%%)" % [l2_passed, TEST_COUNT, 100.0 * l2_passed / TEST_COUNT])
	print("  Failed: %d" % l2_failed)
	print("  Average rooms: %.1f" % l2_avg_rooms)
	print("  Boss room placed: %d/%d" % [l2_boss_placed, TEST_COUNT])

	# Overall
	print("\nOVERALL:")
	print("  Total passed: %d/%d (%.1f%%)" % [passed_tests, TEST_COUNT * 2, 100.0 * passed_tests / (TEST_COUNT * 2)])
	print("  Total failed: %d" % failed_tests)

	if failed_tests > 0:
		print("\nFailed test seeds (for debugging):")
		for r in results:
			if not r.success:
				print("  L%d seed %d - rooms: %d, connected: %s, boss: %s" % [
					r.level, r.seed, r.rooms, r.connected, r.boss_placed
				])

	print("\n" + "=" * 60)

	if failed_tests == 0:
		print("ALL TESTS PASSED! Dungeons are viable.")
	else:
		print("SOME TESTS FAILED. Review failed seeds above.")

	print("=" * 60)

	# Exit after reporting
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
