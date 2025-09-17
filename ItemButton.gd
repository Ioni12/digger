# ItemButton.gd - Individual item button in the inventory grid
extends Button
class_name ItemButton

# === PROPERTIES ===
var item: Item
var inventory_gui: InventoryGUI
var context_menu: PopupMenu

# === SETUP ===
func setup(item_data: Item, gui: InventoryGUI):
	item = item_data
	inventory_gui = gui
	
	# Setup button appearance
	_update_button_display()
	
	# Setup context menu
	_create_context_menu()
	
	# Connect signals
	pressed.connect(_on_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _create_context_menu():
	context_menu = PopupMenu.new()
	add_child(context_menu)
	
	# Add context menu options based on item type
	if item.can_be_consumed():
		context_menu.add_item("Use", 0)
		context_menu.add_separator()
	
	if item.can_be_equipped():
		if item.is_equipped:
			context_menu.add_item("Unequip", 1)
		else:
			context_menu.add_item("Equip", 1)
		context_menu.add_separator()
	
	context_menu.add_item("Drop", 2)
	context_menu.add_item("Drop All", 3)
	context_menu.add_separator()
	context_menu.add_item("Info", 4)
	
	context_menu.id_pressed.connect(_on_context_menu_selected)

func _update_button_display():
	if not item:
		return
	
	# Set button text
	var display_text = item.name
	if item.quantity > 1:
		display_text += " (%d)" % item.quantity
	text = display_text
	
	# Set button color based on item type and equipped status
	if item.is_equipped:
		modulate = Color.LIGHT_GREEN
	else:
		match item.item_type:
			Item.ItemType.WEAPON:
				modulate = Color.ORANGE_RED
			Item.ItemType.ARMOR:
				modulate = Color.STEEL_BLUE
			Item.ItemType.ACCESSORY:
				modulate = Color.PURPLE
			Item.ItemType.CONSUMABLE:
				modulate = Color.LIGHT_GREEN
			Item.ItemType.MISC:
				modulate = Color.LIGHT_GRAY
			_:
				modulate = Color.WHITE
	
	# Set minimum size
	custom_minimum_size = Vector2(120, 40)

# === EVENT HANDLERS ===
func _on_button_pressed():
	# Left click - default action
	if item.can_be_consumed():
		inventory_gui.use_item(item)
	elif item.can_be_equipped():
		if item.is_equipped:
			inventory_gui.unequip_item(item)
		else:
			inventory_gui.equip_item(item)

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right click - show context menu
			context_menu.popup_on_parent(Rect2(event.position, Vector2.ZERO))

func _on_mouse_entered():
	# Show tooltip
	var tooltip_position = global_position + Vector2(size.x + 10, 0)
	inventory_gui.show_tooltip(item, tooltip_position)

func _on_mouse_exited():
	# Hide tooltip (with small delay)
	await get_tree().create_timer(0.1).timeout
	if not get_global_rect().has_point(get_global_mouse_position()):
		inventory_gui.hide_tooltip()

func _on_context_menu_selected(id: int):
	match id:
		0:  # Use
			inventory_gui.use_item(item)
		1:  # Equip/Unequip
			if item.is_equipped:
				inventory_gui.unequip_item(item)
			else:
				inventory_gui.equip_item(item)
		2:  # Drop 1
			_show_drop_dialog(1)
		3:  # Drop All
			_show_drop_dialog(item.quantity)
		4:  # Info
			_show_item_info()

func _show_drop_dialog(suggested_amount: int):
	# Create a simple dialog for dropping items
	var dialog = AcceptDialog.new()
	dialog.title = "Drop Item"
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "How many %s do you want to drop?" % item.name
	vbox.add_child(label)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = 1
	spinbox.max_value = item.quantity
	spinbox.value = min(suggested_amount, item.quantity)
	vbox.add_child(spinbox)
	
	dialog.confirmed.connect(func(): inventory_gui.drop_item(item, int(spinbox.value)))
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.tree_exited.connect(func(): dialog.queue_free())

func _show_item_info():
	# Create detailed item info dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Item Information"
	dialog.size = Vector2(400, 300)
	
	var scroll = ScrollContainer.new()
	dialog.add_child(scroll)
	
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = inventory_gui._generate_tooltip_text(item)
	label.fit_content = true
	scroll.add_child(label)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.tree_exited.connect(func(): dialog.queue_free())
