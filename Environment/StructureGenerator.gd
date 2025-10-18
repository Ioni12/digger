extends RefCounted
class_name StructureGenerator

# Simple structure templates - 1 = dig, 0 = don't dig
var structures = {
	"hut": [
		[1,1,1],
		[1,0,1],
		[1,0,1]
	],
	
	"house": [
		[1,1,1,1],
		[1,0,0,1],
		[1,0,0,1],
		[1,1,0,1]  # entrance at bottom
	],
	
	"tunnel": [
		[1],
		[1],
		[1],
		[1],
		[1]
	],
	
	"room": [
		[1,1,1,1,1],
		[1,0,0,0,1],
		[1,0,0,0,1],
		[1,0,0,0,1],
		[1,1,1,1,1]
	],
	
	"test_structure": {
		"pattern": [
			[1,1,1],
			[1,0,1],
			[1,1,1]
		],
		"background": "res://icon.svg"
	},
	
	"cave": {
		"pattern": [
			[3, 3, 3, 3, 3, 3, 3, 3],
			[3, 1, 1, 1, 1, 1, 3, 3],
			[3, 1, 1, 1, 1, 1, 1, 3],
			[3, 1, 1, 3, 3, 1, 1, 3],
			[3, 1, 1, 1, 1, 1, 1, 3],
			[3, 1, 1, 1, 1, 1, 1, 3],
			[3, 1, 1, 1, 1, 1, 1, 3],
			[3, 3, 3, 3, 3, 3, 3, 3],
		],
		"background": "res://backrounds/Background Complete.png"
	}
}

# Get a structure pattern
func get_structure(name: String):
	if structures.has(name):
		var structure = structures[name]
		# If it's a dictionary with pattern and background, return the whole thing
		if structure is Dictionary and structure.has("pattern"):
			return structure
		# Otherwise it's just an array pattern
		else:
			return {"pattern": structure, "background": null}
	return {"pattern": [], "background": null}

# Get list of available structures
func get_structure_names() -> Array:
	return structures.keys()
