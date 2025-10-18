# RewardSystem.gd - Simple singleton for digging rewards
extends Node

# Simple reward table
var rewards = {
	"common": {
		"chance": 0.60,
		"items": [
			{"name": "Stone", "color": Color.GRAY, "value": 1},
			{"name": "Dirt", "color": Color.SADDLE_BROWN, "value": 1},
			{"name": "Clay", "color": Color.ORANGE_RED, "value": 2}
		]
	},
	"uncommon": {
		"chance": 0.25,
		"items": [
			{"name": "Coal", "color": Color.DIM_GRAY, "value": 5},
			{"name": "Iron Ore", "color": Color.STEEL_BLUE, "value": 10},
			{"name": "Copper Ore", "color": Color.ORANGE, "value": 8}
		]
	},
	"rare": {
		"chance": 0.12,
		"items": [
			{"name": "Gold Ore", "color": Color.GOLD, "value": 25},
			{"name": "Silver Ore", "color": Color.SILVER, "value": 20},
			{"name": "Fossil", "color": Color.ANTIQUE_WHITE, "value": 30}
		]
	},
	"epic": {
		"chance": 0.025,
		"items": [
			{"name": "Ruby", "color": Color.RED, "value": 50},
			{"name": "Sapphire", "color": Color.BLUE, "value": 50},
			{"name": "Emerald", "color": Color.GREEN, "value": 50}
		]
	},
	"legendary": {
		"chance": 0.005,
		"items": [
			{"name": "Diamond", "color": Color.CYAN, "value": 100},
			{"name": "Ancient Artifact", "color": Color.PURPLE, "value": 150}
		]
	}
}

# Roll for a random reward
func roll() -> Dictionary:
	var rand = randf()
	var total = 0.0
	
	for rarity in ["legendary", "epic", "rare", "uncommon", "common"]:
		total += rewards[rarity]["chance"]
		if rand <= total:
			var items = rewards[rarity]["items"]
			var item = items[randi() % items.size()]
			return {
				"name": item["name"],
				"color": item["color"],
				"value": item["value"],
				"rarity": rarity
			}
	
	return {}

# Create an Item from reward data
func create_item(reward: Dictionary) -> Item:
	if reward.is_empty():
		return null
	
	var item = Item.create_misc(reward["name"], "", reward["value"])
	item.is_stackable = true
	item.max_stack = 99
	return item
