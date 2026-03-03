## game_border_frame.gd - Decorative border frame that overlays the game screen
## Hides automatically when menus (Tab, Escape) are open
## Edit the scene file at res://scenes/ui/game_border_frame.tscn to adjust visually
class_name GameBorderFrame
extends CanvasLayer

const BORDER_SCENE_PATH := "res://scenes/ui/game_border_frame.tscn"

var border_instance: CanvasLayer = null
var is_visible_state: bool = true


func _ready() -> void:
	_setup_border()


func _setup_border() -> void:
	# Load the editable scene
	if ResourceLoader.exists(BORDER_SCENE_PATH):
		var scene: PackedScene = load(BORDER_SCENE_PATH)
		border_instance = scene.instantiate()
		get_tree().root.add_child(border_instance)
	else:
		push_warning("[GameBorderFrame] Scene not found: %s" % BORDER_SCENE_PATH)


func _process(_delta: float) -> void:
	if not border_instance:
		return

	# Check if any menu is open
	var menu_open := _is_any_menu_open()

	# Update visibility if state changed
	if menu_open and is_visible_state:
		_hide_border()
	elif not menu_open and not is_visible_state:
		_show_border()


func _is_any_menu_open() -> bool:
	# Check GameManager state
	if GameManager and GameManager.is_in_menu:
		return true

	# Check dialogue systems
	if DialogueManager and DialogueManager.is_dialogue_active:
		return true
	if ConversationSystem and ConversationSystem.is_active:
		return true

	# Check for visible menus via HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		# Check game menu (Tab)
		if hud.game_menu and hud.game_menu.visible:
			return true
		# Check pause menu (Escape)
		if hud.pause_menu and hud.pause_menu.visible:
			return true

	return false


func _hide_border() -> void:
	is_visible_state = false
	if border_instance:
		border_instance.visible = false


func _show_border() -> void:
	is_visible_state = true
	if border_instance:
		border_instance.visible = true


func _exit_tree() -> void:
	if border_instance and is_instance_valid(border_instance):
		border_instance.queue_free()


## Manual toggle (for settings menu option later)
func set_border_visible(show: bool) -> void:
	if show:
		_show_border()
	else:
		_hide_border()
