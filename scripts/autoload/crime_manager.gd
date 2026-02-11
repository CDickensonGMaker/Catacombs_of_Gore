## crime_manager.gd - Manages player bounties and crime system
## Tracks bounties per region, handles crime reporting, and coordinates with guards
extends Node

## Signals
signal bounty_changed(region_id: String, new_amount: int)
signal player_arrested(region_id: String)
signal player_jailed(region_id: String)
signal player_released(region_id: String)
signal crime_reported(crime_type: CrimeType, region_id: String)

## Crime types
enum CrimeType {
	ASSAULT,      # Attacking an NPC
	THEFT,        # Stealing from a chest/container
	MURDER,       # Killing an NPC
	TRESPASSING,  # Breaking into a locked area
	PICKPOCKET    # Pickpocketing an NPC
}

## Base bounty values per crime type
const BOUNTY_VALUES: Dictionary = {
	CrimeType.ASSAULT: 100,
	CrimeType.THEFT: 50,
	CrimeType.MURDER: 1000,
	CrimeType.TRESPASSING: 25,
	CrimeType.PICKPOCKET: 40
}

## Crime names for display
const CRIME_NAMES: Dictionary = {
	CrimeType.ASSAULT: "Assault",
	CrimeType.THEFT: "Theft",
	CrimeType.MURDER: "Murder",
	CrimeType.TRESPASSING: "Trespassing",
	CrimeType.PICKPOCKET: "Pickpocketing"
}

## Bounty tracking per region
## Format: { "region_id": bounty_amount }
var bounties: Dictionary = {}

## Last known crimes per region (for guard dialogue)
## Format: { "region_id": CrimeType }
var last_crimes: Dictionary = {}

## Jailed weapons storage (items confiscated when jailed)
## Format: { "region_id": [{item_id, quality, data, durability, max_durability}] }
var confiscated_items: Dictionary = {}

## Whether player is currently jailed
var is_jailed: bool = false

## Current jail region (while jailed)
var jail_region: String = ""

## Time remaining in jail (in game hours)
var jail_time_remaining: float = 0.0

## Bounty to time conversion rate (gold per game hour)
const BOUNTY_PER_HOUR: int = 100


func _ready() -> void:
	print("[CrimeManager] Initialized")


func _process(delta: float) -> void:
	if is_jailed and jail_time_remaining > 0.0:
		# Convert real delta to game hours
		var hours_passed: float = (delta * GameManager.time_scale) / 3600.0
		jail_time_remaining -= hours_passed

		if jail_time_remaining <= 0.0:
			_release_from_jail()


## Report a crime
## crime_type: The type of crime committed
## region_id: The region where the crime occurred
## witnesses: Array of witness nodes (NPCs who saw the crime)
## Returns: true if crime was successfully reported (had witnesses)
func report_crime(crime_type: CrimeType, region_id: String, witnesses: Array = []) -> bool:
	# No witnesses = no crime reported
	if witnesses.is_empty():
		print("[CrimeManager] Crime committed but no witnesses")
		return false

	# Get bounty value for this crime
	var bounty_value: int = BOUNTY_VALUES.get(crime_type, 50)

	# Add to existing bounty
	var current_bounty: int = bounties.get(region_id, 0)
	bounties[region_id] = current_bounty + bounty_value
	last_crimes[region_id] = crime_type

	print("[CrimeManager] Crime reported: %s in %s (+%d bounty, total: %d)" % [
		CRIME_NAMES.get(crime_type, "Unknown"),
		region_id,
		bounty_value,
		bounties[region_id]
	])

	# Emit signal for UI updates
	bounty_changed.emit(region_id, bounties[region_id])
	crime_reported.emit(crime_type, region_id)

	# Alert nearby guards
	_alert_guards(region_id)

	return true


## Get current bounty in a region
func get_bounty(region_id: String) -> int:
	return bounties.get(region_id, 0)


## Get total bounty across all regions
func get_total_bounty() -> int:
	var total := 0
	for region_id in bounties.keys():
		total += bounties[region_id]
	return total


## Check if player has any bounty in the current region
func has_bounty_in_region(region_id: String) -> bool:
	return get_bounty(region_id) > 0


## Check if player has any bounty anywhere
func has_any_bounty() -> bool:
	return get_total_bounty() > 0


## Get the name of the last crime committed in a region
func get_last_crime_name(region_id: String) -> String:
	if not last_crimes.has(region_id):
		return "crimes"
	return CRIME_NAMES.get(last_crimes[region_id], "crimes")


## Pay bounty with gold to clear it
## Returns: true if payment successful
func pay_bounty(region_id: String) -> bool:
	var bounty: int = get_bounty(region_id)
	if bounty <= 0:
		return true  # No bounty to pay

	if not InventoryManager.remove_gold(bounty):
		push_warning("[CrimeManager] Not enough gold to pay bounty")
		return false

	bounties[region_id] = 0
	last_crimes.erase(region_id)

	print("[CrimeManager] Bounty paid: %d gold in %s" % [bounty, region_id])
	bounty_changed.emit(region_id, 0)

	return true


## Calculate jail time for current bounty (in game hours)
func calculate_jail_time(region_id: String) -> float:
	var bounty: int = get_bounty(region_id)
	@warning_ignore("integer_division")
	return float(bounty) / float(BOUNTY_PER_HOUR)


## Serve jail time to clear bounty
## This initiates the jailing process - player is teleported to jail
func serve_time(region_id: String) -> void:
	var bounty: int = get_bounty(region_id)
	if bounty <= 0:
		return

	is_jailed = true
	jail_region = region_id
	jail_time_remaining = calculate_jail_time(region_id)

	# Confiscate equipped weapons
	_confiscate_weapons(region_id)

	print("[CrimeManager] Player jailed in %s for %.1f hours" % [region_id, jail_time_remaining])
	player_jailed.emit(region_id)


## Clear bounty (for pardons, escapes, or completing jail time)
func clear_bounty(region_id: String) -> void:
	if bounties.has(region_id):
		bounties[region_id] = 0
		last_crimes.erase(region_id)
		bounty_changed.emit(region_id, 0)
		print("[CrimeManager] Bounty cleared in %s" % region_id)


## Clear all bounties (for pardons or special events)
func clear_all_bounties() -> void:
	for region_id in bounties.keys():
		clear_bounty(region_id)


## Alert guards in the region about the crime
func _alert_guards(region_id: String) -> void:
	var guards := get_tree().get_nodes_in_group("guards")
	for guard in guards:
		if guard.has_method("on_crime_reported"):
			guard.on_crime_reported(region_id)


## Confiscate player's equipped weapons when jailed
func _confiscate_weapons(region_id: String) -> void:
	var confiscated: Array = []

	# Get main hand weapon
	if not InventoryManager.equipment.main_hand.is_empty():
		var weapon: Dictionary = InventoryManager.equipment.main_hand.duplicate()
		confiscated.append(weapon)
		InventoryManager.equipment.main_hand = {}
		print("[CrimeManager] Confiscated main hand: %s" % weapon.get("item_id", "unknown"))

	# Get off hand (shield/secondary)
	if not InventoryManager.equipment.off_hand.is_empty():
		var off_hand: Dictionary = InventoryManager.equipment.off_hand.duplicate()
		confiscated.append(off_hand)
		InventoryManager.equipment.off_hand = {}
		print("[CrimeManager] Confiscated off hand: %s" % off_hand.get("item_id", "unknown"))

	confiscated_items[region_id] = confiscated


## Return confiscated items to player on release
func _return_confiscated_items(region_id: String) -> void:
	if not confiscated_items.has(region_id):
		return

	var items: Array = confiscated_items[region_id]
	for item in items:
		var item_id: String = item.get("item_id", "")
		var quality: Enums.ItemQuality = item.get("quality", Enums.ItemQuality.AVERAGE)

		if not item_id.is_empty():
			InventoryManager.add_item(item_id, 1, quality)
			print("[CrimeManager] Returned confiscated item: %s" % item_id)

	confiscated_items.erase(region_id)


## Release player from jail after serving time
func _release_from_jail() -> void:
	if not is_jailed:
		return

	var region: String = jail_region

	# Clear bounty
	clear_bounty(region)

	# Return confiscated items
	_return_confiscated_items(region)

	# Reset jail state
	is_jailed = false
	jail_region = ""
	jail_time_remaining = 0.0

	print("[CrimeManager] Player released from jail in %s" % region)
	player_released.emit(region)


## Called when player escapes from jail (bounty not cleared, adds to it)
func on_jail_escape(region_id: String) -> void:
	# Add escape bounty (treated as trespassing)
	var escape_bounty: int = 200  # Escaping jail is serious
	var current_bounty: int = bounties.get(region_id, 0)
	bounties[region_id] = current_bounty + escape_bounty

	print("[CrimeManager] Jail escape! Additional bounty: %d" % escape_bounty)
	bounty_changed.emit(region_id, bounties[region_id])

	# Return items (player managed to grab them)
	_return_confiscated_items(region_id)

	# Reset jail state
	is_jailed = false
	jail_region = ""
	jail_time_remaining = 0.0


## Skip jail time (for testing or time-skip mechanics)
func skip_jail_time() -> void:
	if is_jailed:
		jail_time_remaining = 0.0
		_release_from_jail()


## Serialize for saving
func to_dict() -> Dictionary:
	return {
		"bounties": bounties.duplicate(),
		"last_crimes": last_crimes.duplicate(),
		"confiscated_items": confiscated_items.duplicate(true),
		"is_jailed": is_jailed,
		"jail_region": jail_region,
		"jail_time_remaining": jail_time_remaining
	}


## Deserialize from save
func from_dict(data: Dictionary) -> void:
	bounties = data.get("bounties", {}).duplicate()
	last_crimes = data.get("last_crimes", {}).duplicate()
	confiscated_items = data.get("confiscated_items", {}).duplicate(true)
	is_jailed = data.get("is_jailed", false)
	jail_region = data.get("jail_region", "")
	jail_time_remaining = data.get("jail_time_remaining", 0.0)


## Reset for new game
func reset_for_new_game() -> void:
	bounties.clear()
	last_crimes.clear()
	confiscated_items.clear()
	is_jailed = false
	jail_region = ""
	jail_time_remaining = 0.0
