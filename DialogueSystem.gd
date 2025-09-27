# DialogueSystem.gd
extends Resource
class_name DialogueSystem

static func get_dialogue_data() -> Dictionary:
	return {
		# Steve - helpful neighbor with starter items
		"steve_neighbour": {
			"stages": [
				{
					"message": "Look who we have here...",
				},
				{
					"message": "You look like you could use some help getting started.",
				},
				{
					"message": "Here, take these. You'll need them more than I do.",
					"function": "give_potion"
				},
				{
					"message": "Those should help you survive out here. Good luck!",
				},
				{
					"message": "How are those supplies working out for you?",
					"repeatable": true
				}
			]
		},
		
		# Standard trader
		"merchant_trader": {
			"stages": [
				{
					"message": "Welcome, traveler! Care to see my wares?",
					"actions": [{"type": "enable_trading"}]
				},
				{
					"message": "Back for more goods?",
					"actions": [{"type": "enable_trading"}],
					"repeatable": true
				}
			]
		},
		
		# Guide with tips and eventual map reward
		"helpful_guide": {
			"stages": [
				{
					"message": "Ah, another soul brave enough to venture here!",
					"actions": []
				},
				{
					"message": "Watch out for the rocky terrain - it's harder to dig through.",
					"actions": []
				},
				{
					"message": "I've seen red creatures lurking in some structures. Be careful!",
					"actions": []
				},
				{
					"message": "You seem experienced now. Here's a map I found.",
					"actions": [{
						"type": "give_items",
						"items": [
							{"name": "Map Fragment", "type": "CONSUMABLE", "quantity": 1},
							{"name": "Health Potion", "type": "CONSUMABLE", "quantity": 2}
						]
					}]
				},
				{
					"message": "May your path be clear, adventurer.",
					"actions": [],
					"repeatable": true
				}
			]
		},
		
		# Scholar with research reward
		"ancient_scholar": {
			"stages": [
				{
					"message": "Fascinating! Another explorer in these ruins.",
					"actions": []
				},
				{
					"message": "These structures are ancient... built by those who came before.",
					"actions": []
				},
				{
					"message": "I'm documenting the architecture here. Each structure tells a story.",
					"actions": []
				},
				{
					"message": "Your exploration has helped my research! Take this ancient artifact.",
					"actions": [{
						"type": "give_items",
						"items": [
							{"name": "Ancient Artifact", "type": "CONSUMABLE", "quantity": 1},
							{"name": "Scholarly Notes", "type": "CONSUMABLE", "quantity": 1}
						]
					}]
				},
				{
					"message": "Knowledge shared is knowledge doubled. Farewell!",
					"actions": [],
					"repeatable": true
				}
			]
		},
		
		# Hermit with healing blessing
		"wise_hermit": {
			"stages": [
				{
					"message": "...Oh. A visitor. How... unexpected.",
					"actions": []
				},
				{
					"message": "I came here seeking solitude. Found it, mostly.",
					"actions": []
				},
				{
					"message": "In silence, one learns to listen to the earth itself.",
					"actions": []
				},
				{
					"message": "Your presence has been... peaceful. Accept this blessing.",
					"actions": [{
						"type": "give_items",
						"items": [
							{"name": "Hermit's Blessing", "type": "CONSUMABLE", "quantity": 1}
						]
					}, {
						"type": "restore_health",
						"amount": 50
					}]
				},
				{
					"message": "Go well, wanderer. May you find what you seek.",
					"actions": [],
					"repeatable": true
				}
			]
		}
	}

# Convert string to Item.ItemType enum
static func string_to_item_type(type_string: String) -> Item.ItemType:
	match type_string.to_upper():
		"CONSUMABLE":
			return Item.ItemType.CONSUMABLE
		"WEAPON":
			return Item.ItemType.WEAPON
		"ARMOR":
			return Item.ItemType.ARMOR
		"ACCESSORY":
			return Item.ItemType.ACCESSORY
		"MISC":
			return Item.ItemType.MISC
		_:
			return Item.ItemType.MISC  # Default to MISC for unknown types
