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
		close_inventory()
		get_viewport().set_input_as_handled()

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
	# Clear all slots first
	for slot in item_slots:
		clear_slot(slot)
	
	# Fill slots with items
	var slot_index = 0
	for item in player_inventory.items:
		if item.quantity > 0 and slot_index < item_slots.size():
			setup_slot_with_item(item_slots[slot_index], item)
			slot_index += 1

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
	# Set item name (or short name)
	var display_name = item.name
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
	
	# You could set icons here if you have them
	# slot.icon = load("res://icons/" + item.name.to_lower() + ".png")

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
		return
	
	# Item interaction
	if item.can_be_consumed():
		player_inventory.use_item(item.name)
	elif item.can_be_equipped():
		if item.is_equipped:
			player_inventory.unequip_item(item.name)
		else:
			player_inventory.equip_item(item.name)

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
