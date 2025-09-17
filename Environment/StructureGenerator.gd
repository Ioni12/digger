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
	]
}

# Get a structure pattern
func get_structure(name: String) -> Array:
	if structures.has(name):
		return structures[name]
	return []

# Get list of available structures
func get_structure_names() -> Array:
	return structures.keys()
