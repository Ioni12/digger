# InventoryGUI.gd - Inventory interface with item grid
extends Control
class_name InventoryGUI

# === UI REFERENCES ===
@onready var inventory_tabs: TabContainer = $InventoryTabs
@onready var items_tab: Control = $InventoryTabs/ItemsTab
@onready var equipment_tab: Control = $InventoryTabs/EquipmentTab
@onready var stats_tab: Control = $InventoryTabs/StatsTab

# Items tab components
@onready var item_grid: GridContainer = $InventoryTabs/ItemsTab/ItemsGrid

# Equipment tab components
@onready var weapon_slot: Button = $InventoryTabs/EquipmentTab/WeaponSlot
@onready var armor_slot: Button = $InventoryTabs/EquipmentTab/ArmorSlot
@onready var accessory_slot: Button = $InventoryTabs/EquipmentTab/AccessorySlot

# UI elements
@onready var gold_display: Label = $GoldDisplay
@onready var tooltip: Panel = $ItemTooltip
@onready var tooltip_label: Label = $ItemTooltip/Label
@onready var close_button: Button = $CloseButton

@onready var context_menu: Panel = $ItemContextMenu
@onready var context_menu_container: VBoxContainer = $ItemContextMenu/MarginContainer/VBoxContainer
@onready var use_button: Button = $ItemContextMenu/MarginContainer/VBoxContainer/UseButton
@onready var equip_button: Button = $ItemContextMenu/MarginContainer/VBoxContainer/EquipButton
@onready var drop_button: Button = $ItemContextMenu/MarginContainer/VBoxContainer/DropButton
@onready var examine_button: Button = $ItemContextMenu/MarginContainer/VBoxContainer/ExamineButton
@onready var cancel_button: Button = $ItemContextMenu/MarginContainer/VBoxContainer/CancelButton

var selected_item: Item
var selected_slot_index: int

# === PROPERTIES ===
var player_inventory: PlayerInventory
var player: Player
var stats_container: VBoxContainer

# Grid settings
const GRID_SIZE = 6  # 6x6 grid = 36 slots
const SLOT_SIZE = Vector2(64, 64)
var item_slots: Array[Button] = []

# === SIGNALS ===
signal inventory_closed()

# === SETUP ===
func _ready():
	print("=== InventoryGUI _ready() started ===")
	visible = false
	close_button.pressed.connect(close_inventory)
	
	# Setup grid
	setup_item_grid()
	
	# Create stats container dynamically
	stats_container = VBoxContainer.new()
	stats_tab.add_child(stats_container)
	
	# Setup equipment slots
	weapon_slot.pressed.connect(func(): unequip_slot(Item.EquipmentSlot.WEAPON))
	armor_slot.pressed.connect(func(): unequip_slot(Item.EquipmentSlot.ARMOR))
	accessory_slot.pressed.connect(func(): unequip_slot(Item.EquipmentSlot.ACCESSORY))
	
	# Setup tooltip
	if tooltip_label == null:
		tooltip_label = Label.new()
		tooltip.add_child(tooltip_label)
	tooltip.visible = false
	
	setup_context_menu()

func setup_item_grid():
	# Configure grid container
	item_grid.columns = GRID_SIZE
	
	# Create item slots
	for i in range(GRID_SIZE * GRID_SIZE):
		var slot_button = create_item_slot(i)
		item_grid.add_child(slot_button)
		item_slots.append(slot_button)

func create_item_slot(slot_index: int) -> Button:
	var slot = Button.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.flat = false
	
	# Style the slot
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.4, 0.4, 0.4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.6, 0.6, 0.6)
	
	slot.add_theme_stylebox_override("normal", style_normal)
	slot.add_theme_stylebox_override("hover", style_hover)
	slot.add_theme_stylebox_override("pressed", style_hover)
	
	# Connect signals
	slot.pressed.connect(func(): _on_slot_clicked(slot_index))
	slot.mouse_entered.connect(func(): _on_slot_hover_enter(slot_index))
	slot.mouse_exited.connect(func(): _on_slot_hover_exit())
	
	return slot

func setup(inventory: PlayerInventory, player_ref: Player):
	player_inventory = inventory
	player = player_ref
	
	player_inventory.inventory_changed.connect(refresh_display)
	player_inventory.item_equipped.connect(func(item): refresh_display())
	player_inventory.item_unequipped.connect(func(item): refresh_display())
	
	refresh_display()

# === INPUT HANDLING ===
func _input(event):
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		if context_menu.visible:
			hide_context_menu()
		else:
			close_inventory()
		get_viewport().set_input_as_handled()
	
	# Close context menu on any click outside it
	if event is InputEventMouseButton and event.pressed:
		if context_menu.visible:
			# Convert global mouse position to context menu's local coordinates
			var local_mouse_pos = context_menu.global_position - event.global_position
			var context_rect = Rect2(Vector2.ZERO, context_menu.size)
			
			# Alternative approach: check if mouse is outside the menu bounds
			var menu_rect = Rect2(context_menu.global_position, context_menu.size)
			if not menu_rect.has_point(event.global_position):
				hide_context_menu()

# === DISPLAY UPDATES ===
func refresh_display():
	if not player_inventory:
		return
		
	update_gold_display()
	update_item_grid()
	update_equipment_display()
	update_stats_display()

func update_gold_display():
	gold_display.text = "Gold: %d" % player_inventory.gold

func update_item_grid():
	print("=== DEBUG: update_item_grid() called ===")
	print("Total inventory items: ", player_inventory.items.size())
	
	# Clear all slots first
	for slot in item_slots:
		clear_slot(slot)
	
	# Fill slots with items
	var slot_index = 0
	for i in range(player_inventory.items.size()):
		var item = player_inventory.items[i]
		print("Item ", i, ": ", item.name, " | Quantity: ", item.quantity, " | Type: ", item.item_type)
		
		if item.quantity > 0 and slot_index < item_slots.size():
			print("  -> Adding to slot ", slot_index)
			setup_slot_with_item(item_slots[slot_index], item)
			slot_index += 1
		else:
			print("  -> Skipped (quantity: ", item.quantity, " | slot_index: ", slot_index, ")")
	
	print("Total slots filled: ", slot_index)
	print("=== DEBUG: update_item_grid() complete ===")

func clear_slot(slot: Button):
	slot.text = ""
	slot.icon = null
	slot.modulate = Color.WHITE
	
	# Reset to empty style
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.4, 0.4, 0.4)
	slot.add_theme_stylebox_override("normal", style_normal)

func setup_slot_with_item(slot: Button, item: Item):
	# Set item name (or short name) - with fallback for empty names
	var display_name = item.name
	
	# DEBUG: Add this to see what's happening
	print("DEBUG: Setting up slot with item name: '", item.name, "' type: ", item.item_type)
	
	# Fallback for empty names
	if display_name == null or display_name == "":
		match item.item_type:
			Item.ItemType.CONSUMABLE:
				display_name = "Potion"
			Item.ItemType.MISC:
				display_name = "Item"
			Item.ItemType.WEAPON:
				display_name = "Weapon"
			Item.ItemType.ARMOR:
				display_name = "Armor"
			_:
				display_name = "Unknown"
	
	if len(display_name) > 8:
		display_name = display_name.substr(0, 6) + ".."
	
	slot.text = display_name
	
	# Show quantity if > 1
	if item.quantity > 1:
		slot.text = "%s\nx%d" % [display_name, item.quantity]
	
	# Color coding by item type/rarity
	if item.is_equipped:
		slot.modulate = Color.GREEN
		# Equipped item border
		var style_equipped = StyleBoxFlat.new()
		style_equipped.bg_color = Color(0.1, 0.4, 0.1, 0.9)
		style_equipped.border_width_left = 3
		style_equipped.border_width_right = 3
		style_equipped.border_width_top = 3
		style_equipped.border_width_bottom = 3
		style_equipped.border_color = Color.GREEN
		slot.add_theme_stylebox_override("normal", style_equipped)
	elif item.can_be_equipped():
		slot.modulate = Color.CYAN
	elif item.can_be_consumed():
		slot.modulate = Color.YELLOW
	else:
		slot.modulate = Color.WHITE

func update_equipment_display():
	# Update weapon slot
	var weapon = player_inventory.get_equipped_in_slot(Item.EquipmentSlot.WEAPON)
	if weapon:
		weapon_slot.text = weapon.name
		weapon_slot.modulate = Color.GREEN
	else:
		weapon_slot.text = "No Weapon"
		weapon_slot.modulate = Color.WHITE
	
	# Update armor slot
	var armor = player_inventory.get_equipped_in_slot(Item.EquipmentSlot.ARMOR)
	if armor:
		armor_slot.text = armor.name
		armor_slot.modulate = Color.GREEN
	else:
		armor_slot.text = "No Armor"
		armor_slot.modulate = Color.WHITE
	
	# Update accessory slot
	var accessory = player_inventory.get_equipped_in_slot(Item.EquipmentSlot.ACCESSORY)
	if accessory:
		accessory_slot.text = accessory.name
		accessory_slot.modulate = Color.GREEN
	else:
		accessory_slot.text = "No Accessory"
		accessory_slot.modulate = Color.WHITE

func update_stats_display():
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()
	
	if not player:
		return
	
	# Create stat labels
	var stats_data = [
		["Level", str(player.level)],
		["Health", "%d / %d" % [player.current_hp, player.max_hp]],
		["Stamina", "%d / %d" % [player.stamina, player.max_stamina]],
		["", ""],
		["Attack", str(player.current_attack)],
		["Defense", str(player.current_defense)],
		["Speed", str(player.current_speed)]
	]
	
	for stat in stats_data:
		var label = Label.new()
		if stat[0] == "":
			label.text = ""
		else:
			label.text = "%s: %s" % [stat[0], stat[1]]
		stats_container.add_child(label)

# === EVENT HANDLERS ===
func _on_slot_clicked(slot_index: int):
	var item = get_item_at_slot(slot_index)
	if not item:
		hide_context_menu()
		return
	
	# Store the selected item
	selected_item = item
	selected_slot_index = slot_index
	
	# Show context menu at mouse position
	show_item_context_menu()
	
	# Show context menu at mouse position
	show_item_context_menu()

func _on_slot_hover_enter(slot_index: int):
	var item = get_item_at_slot(slot_index)
	if not item:
		return
	
	# Show tooltip
	var tooltip_text = item.name
	if item.quantity > 1:
		tooltip_text += "\nQuantity: %d" % item.quantity
	
	if item.can_be_equipped():
		tooltip_text += "\nType: Equipment"
		if item.is_equipped:
			tooltip_text += " (Equipped)"
	elif item.can_be_consumed():
		tooltip_text += "\nType: Consumable"
	
	# Add item stats/description if available
	# tooltip_text += "\n" + item.description
	
	tooltip_label.text = tooltip_text
	tooltip.visible = true
	
	# Position tooltip near mouse
	var mouse_pos = get_global_mouse_position()
	tooltip.position = mouse_pos + Vector2(10, 10)

func _on_slot_hover_exit():
	tooltip.visible = false

func get_item_at_slot(slot_index: int) -> Item:
	var current_slot = 0
	for item in player_inventory.items:
		if item.quantity > 0:
			if current_slot == slot_index:
				return item
			current_slot += 1
	return null

func unequip_slot(slot: Item.EquipmentSlot):
	var equipped_item = player_inventory.get_equipped_in_slot(slot)
	if equipped_item:
		player_inventory.unequip_item(equipped_item.name)

# === INTERFACE METHODS ===
func open_inventory():
	visible = true
	refresh_display()

func close_inventory():
	visible = false
	inventory_closed.emit()

func toggle_inventory():
	if visible:
		close_inventory()
	else:
		open_inventory()

func show_item_context_menu():
	if not selected_item:
		return
	
	# Position the menu at mouse position
	var mouse_pos = get_global_mouse_position()
	context_menu.global_position = mouse_pos
	
	# Ensure menu stays on screen
	var screen_size = get_viewport().size
	var menu_size = context_menu.size
	if context_menu.global_position.x + menu_size.x > screen_size.x:
		context_menu.global_position.x = screen_size.x - menu_size.x
	if context_menu.global_position.y + menu_size.y > screen_size.y:
		context_menu.global_position.y = screen_size.y - menu_size.y
	
	# Show/hide buttons based on item type
	use_button.visible = selected_item.can_be_consumed()
	
	if selected_item.can_be_equipped():
		equip_button.visible = true
		equip_button.text = "Unequip" if selected_item.is_equipped else "Equip"
	else:
		equip_button.visible = false
	
	# Always show drop and examine
	drop_button.visible = true
	examine_button.visible = true
	cancel_button.visible = true
	
	context_menu.visible = true

func setup_context_menu():
	print("=== DEBUG: Setting up context menu ===")
	
	# Debug: Check if all button references exist
	print("use_button: ", use_button)
	print("equip_button: ", equip_button)
	print("drop_button: ", drop_button)
	print("examine_button: ", examine_button)
	print("cancel_button: ", cancel_button)
	print("context_menu: ", context_menu)
	print("context_menu_container: ", context_menu_container)
	
	if not use_button:
		print("ERROR: use_button is null!")
		return
	if not equip_button:
		print("ERROR: equip_button is null!")
		return
	if not drop_button:
		print("ERROR: drop_button is null!")
		return
	if not examine_button:
		print("ERROR: examine_button is null!")
		return
	if not cancel_button:
		print("ERROR: cancel_button is null!")
		return
	
	context_menu.visible = false
	
	# Style the context menu
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_bg.border_width_left = 2
	style_bg.border_width_right = 2
	style_bg.border_width_top = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color(0.5, 0.5, 0.5)
	context_menu.add_theme_stylebox_override("panel", style_bg)
	
	# Connect button signals with debug output
	print("Connecting button signals...")
	
	if use_button.pressed.is_connected(_on_use_item_pressed):
		print("use_button already connected")
	else:
		use_button.pressed.connect(_on_use_item_pressed)
		print("Connected use_button")
	
	if equip_button.pressed.is_connected(_on_equip_item_pressed):
		print("equip_button already connected")
	else:
		equip_button.pressed.connect(_on_equip_item_pressed)
		print("Connected equip_button")
	
	if drop_button.pressed.is_connected(_on_drop_item_pressed):
		print("drop_button already connected")
	else:
		drop_button.pressed.connect(_on_drop_item_pressed)
		print("Connected drop_button")
	
	if examine_button.pressed.is_connected(_on_examine_item_pressed):
		print("examine_button already connected")
	else:
		examine_button.pressed.connect(_on_examine_item_pressed)
		print("Connected examine_button")
	
	if cancel_button.pressed.is_connected(_on_cancel_context_menu):
		print("cancel_button already connected")
	else:
		cancel_button.pressed.connect(_on_cancel_context_menu)
		print("Connected cancel_button")
	
	print("=== Context menu setup complete ===")

func _on_use_item_pressed():
	if selected_item and selected_item.can_be_consumed():
		player_inventory.use_item(selected_item.name)
		print("Used item: ", selected_item.name)
	hide_context_menu()

func _on_equip_item_pressed():
	if selected_item and selected_item.can_be_equipped():
		if selected_item.is_equipped:
			player_inventory.unequip_item(selected_item.name)
			print("Unequipped item: ", selected_item.name)
		else:
			player_inventory.equip_item(selected_item.name)
			print("Equipped item: ", selected_item.name)
	hide_context_menu()

func _on_drop_item_pressed():
	if selected_item:
		# You'll need to implement drop_item in your PlayerInventory
		# player_inventory.drop_item(selected_item.name)
		print("Dropped item: ", selected_item.name)
		# For now, just remove one quantity
		selected_item.quantity -= 1
		if selected_item.quantity <= 0:
			player_inventory.remove_item(selected_item.name)
		refresh_display()
	hide_context_menu()

func _on_examine_item_pressed():
	if selected_item:
		# Show detailed item information
		print("Examining item: ", selected_item.name)
		# You could show a detailed tooltip or info panel here
		show_item_examination(selected_item)
	hide_context_menu()

func _on_cancel_context_menu():
	hide_context_menu()

func hide_context_menu():
	context_menu.visible = false
	selected_item = null
	selected_slot_index = -1

func _on_focus_changed(control):
	# Hide context menu when clicking elsewhere
	if context_menu.visible and control != context_menu:
		hide_context_menu()

func show_item_examination(item: Item):
	# Update tooltip with detailed info
	var examine_text = "=== %s ===" % item.name.to_upper()
	examine_text += "\nType: %s" % Item.ItemType.keys()[item.item_type]
	examine_text += "\nQuantity: %d" % item.quantity
	
	if item.can_be_equipped():
		examine_text += "\nEquipment Slot: %s" % Item.EquipmentSlot.keys()[item.equipment_slot]
		examine_text += "\nEquipped: %s" % ("Yes" if item.is_equipped else "No")
	
	if item.can_be_consumed():
		examine_text += "\nConsumable: Yes"
	
	# Show in tooltip for now, or create a dedicated examination panel
	tooltip_label.text = examine_text
	tooltip.visible = true
	tooltip.global_position = get_global_mouse_position() + Vector2(20, 20)
