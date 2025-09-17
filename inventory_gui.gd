# InventoryGUI.gd - Simple inventory interface
extends Control
class_name InventoryGUI

# === UI REFERENCES (matching your project structure) ===
@onready var inventory_tabs: TabContainer = $InventoryTabs
@onready var items_tab: Control = $InventoryTabs/ItemsTab
@onready var equipment_tab: Control = $InventoryTabs/EquipmentTab
@onready var stats_tab: Control = $StatsTab

# Items tab components
@onready var item_grid: GridContainer = $InventoryTabs/ItemsTab/ItemGrid
@onready var items_list: ItemList = $InventoryTabs/ItemsTab/ItemsList

# Equipment tab components (these are Button nodes in your structure)
@onready var weapon_slot: Button = $InventoryTabs/EquipmentTab/WeaponSlot
@onready var armor_slot: Button = $InventoryTabs/EquipmentTab/ArmorSlot
@onready var accessory_slot: Button = $InventoryTabs/EquipmentTab/AccessorySlot

# UI elements
@onready var gold_display: Label = $GoldDisplay
@onready var tooltip: Panel = $ItemTooltip
@onready var close_button: Button = $CloseButton

# === PROPERTIES ===
var player_inventory: PlayerInventory
var player: Player
var stats_container: VBoxContainer

# === SIGNALS ===
signal inventory_closed()

# === SETUP ===
func _ready():
	visible = false
	close_button.pressed.connect(close_inventory)
	
	# Create stats container dynamically
	stats_container = VBoxContainer.new()
	stats_tab.add_child(stats_container)
	
	# Setup equipment slots
	weapon_slot.pressed.connect(func(): unequip_slot(Item.EquipmentSlot.WEAPON))
	armor_slot.pressed.connect(func(): unequip_slot(Item.EquipmentSlot.ARMOR))
	accessory_slot.pressed.connect(func(): unequip_slot(Item.EquipmentSlot.ACCESSORY))
	
	# Setup items list
	items_list.item_activated.connect(_on_item_activated)
	
	tooltip.visible = false

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
	update_items_list()
	update_equipment_display()
	update_stats_display()

func update_gold_display():
	gold_display.text = "Gold: %d" % player_inventory.gold

func update_items_list():
	items_list.clear()
	
	for item in player_inventory.items:
		if item.quantity > 0:
			var display_text = item.name
			if item.quantity > 1:
				display_text += " x%d" % item.quantity
			if item.is_equipped:
				display_text += " (Equipped)"
			
			items_list.add_item(display_text)

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
func _on_item_activated(index: int):
	if index >= player_inventory.items.size():
		return
		
	var item = player_inventory.items[index]
	
	# Simple item interaction
	if item.can_be_consumed():
		player_inventory.use_item(item.name)
	elif item.can_be_equipped():
		if item.is_equipped:
			player_inventory.unequip_item(item.name)
		else:
			player_inventory.equip_item(item.name)

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
