extends Resource
class_name ChunkData

# Flags
const TOP = 1 << 0
const BOTTOM = 1 << 1
const LEFT = 1 << 2
const RIGHT = 1 << 3
const FRONT = 1 << 4
const BACK = 1 << 5
const ALL_SIDES = TOP | BOTTOM | LEFT | RIGHT | FRONT | BACK

# Generated Data
var types := []
var flags := []
var heights := []
var stumps := {}

# Chunk info
var chunk_id: Vector2
var chunk_pos: Vector3
var chunk_size: Vector3


func generate(id: Vector2, pos: Vector3):
	chunk_size = Globals.chunk_size
	chunk_id = id
	chunk_pos = pos
	var chunk_data = WorldGen.start_new_chunk(id)
	
	_generate_types(pos, chunk_data)
	_generate_trees(pos, chunk_data)
	_generate_faces(pos, chunk_data)


func update():
	var chunk_data = WorldGen.start_new_chunk(chunk_id)
	_generate_faces(chunk_pos, chunk_data)


func depool():
	var i := 0
	var j := 0
	while i < chunk_size.x:
		j = 0
		while j < chunk_size.z:
			types[i][j] = Array(types[i][j])
			j += 1
		i += 1
	
	# We have to rebuild this anyways if the types array changes.
	flags = []


func check_visible(pos: Vector3, direction: int) -> bool:
	return !bool(flags[pos.x][pos.z][pos.y] & direction)


func _set_visible_safe(i: int, j: int, k: int):
	if i > 0:
		flags[i - 1][j][k] |= RIGHT
	if i < chunk_size.x - 1:
		flags[i + 1][j][k] |= LEFT
	if j > 0:
		flags[i][j - 1][k] |= BACK
	if j < chunk_size.z - 1:
		flags[i][j + 1][k] |= FRONT
	if k > 0:
		flags[i][j][k - 1] |= TOP
	if k < chunk_size.y - 1:
		flags[i][j][k + 1] |= BOTTOM


func get_height(x: int, z: int):
	return heights[x][z]


func get_block(pos: Vector3):
	pos = pos.floor()
	return types[pos.x][pos.z][pos.y]


func set_block(pos: Vector3, t: int):
	pos = pos.floor()
	types[pos.x][pos.z][pos.y] = t
	heights[pos.x][pos.z] = max(pos.y + 1, heights[pos.x][pos.z])
	_generate_faces(pos, null)


func _generate_types(pos: Vector3, data):
	var pool_array = PoolByteArray()
	for y in chunk_size.y:
		pool_array.append(0)
	
	types.resize(int(chunk_size.x))
	heights.resize(int(chunk_size.x))
	for i in range(0, chunk_size.x):
		types[i] = []
		types[i].resize(int(chunk_size.z))
		heights[i] = []
		heights[i].resize(int(chunk_size.z))
		for j in range(0, chunk_size.z):
			types[i][j] = pool_array
	
	# Set all blocks within the chunk.
	var block
	for i in chunk_size.x:
		for j in chunk_size.z:
			# Work top to bottom in the y direction.
			var height = WorldGen.get_height(i + pos.x, j + pos.z) + 1
			heights[i][j] = height
			for k in height:
				block = WorldGen.get_block_type(i + pos.x, k + pos.y, j + pos.z, data)
				types[i][j][k] = block
				if block == WorldGen.STUMP:
					types[i][j][k] = WorldGen.AIR
					stumps[Vector2(i, j)] = k


func _generate_trees(pos: Vector3, data):
	for v in stumps.keys():
		_generate_tree(v.x, v.y, stumps[v], pos, data)


func _generate_faces(pos: Vector3, data):
	var pool_array = PoolByteArray()
	for y in chunk_size.y:
		pool_array.append(0)
	
	flags = []
	flags.resize(int(chunk_size.x))
	for i in range(0, chunk_size.x):
		flags[i] = []
		flags[i].resize(int(chunk_size.z))
		for j in range(0, chunk_size.z):
			flags[i][j] = pool_array
	
	# Set flags internally.
	for i in range(1, chunk_size.x - 1):
		for j in range(1, chunk_size.z - 1):
			# Work top to bottom in the y direction.
			var height = heights[i][j]
			flags[i][j][0] |= BOTTOM
			for k in range(1, height):
				if WorldGen.types[types[i][j][k]][WorldGen.SOLID]:
					flags[i - 1][j][k] |= RIGHT
					flags[i + 1][j][k] |= LEFT
					flags[i][j - 1][k] |= BACK
					flags[i][j + 1][k] |= FRONT
					flags[i][j][k - 1] |= TOP
					flags[i][j][k + 1] |= BOTTOM
	
	# Set flags on the outer edges.
	for i in chunk_size.x:
		for k in heights[i][0]:
			if WorldGen.types[types[i][0][k]][WorldGen.SOLID]:
				_set_visible_safe(i, 0, k)
			if WorldGen.types[WorldGen.get_block_type(pos.x + i, pos.y + k, pos.z - 1, data)][WorldGen.SOLID]:
				flags[i][0][k] |= FRONT
		for k in heights[i][chunk_size.z - 1]:
			if WorldGen.types[types[i][chunk_size.z - 1][k]][WorldGen.SOLID]:
# warning-ignore:narrowing_conversion
				_set_visible_safe(i, chunk_size.z - 1, k)
			if WorldGen.types[WorldGen.get_block_type(pos.x + i, pos.y + k, pos.z + chunk_size.z, data)][WorldGen.SOLID]:
				flags[i][chunk_size.z - 1][k] |= BACK
	
	for j in chunk_size.z:
		for k in heights[0][j]:
			if WorldGen.types[types[0][j][k]][WorldGen.SOLID]:
				_set_visible_safe(0, j, k)
			if WorldGen.types[WorldGen.get_block_type(pos.x - 1, pos.y + k, pos.z + j, data)][WorldGen.SOLID]:
				flags[0][j][k] |= LEFT
		for k in heights[chunk_size.x - 1][j]:
			if WorldGen.types[types[chunk_size.x - 1][j][k]][WorldGen.SOLID]:
# warning-ignore:narrowing_conversion
				_set_visible_safe(chunk_size.z - 1, j, k)
			if WorldGen.types[WorldGen.get_block_type(pos.x + chunk_size.x, pos.y + k, pos.z + j, data)][WorldGen.SOLID]:
				flags[chunk_size.x - 1][j][k] |= RIGHT


func _generate_tree(i: int, j: int, k: int, pos: Vector3, data):
	# Check if we have room for a tree here.
	var tree := WorldGen.get_tree_dimensions(i + pos.x, j + pos.z, data)
	
	# Abort!
	if i < tree.brim_width or i + tree.brim_width >= chunk_size.x or \
			j < tree.brim_width or j + tree.brim_width >= chunk_size.z:
		return
	for y in range(WorldGen.tree_heights.x, WorldGen.tree_heights.y):
		if types[i][j][k + y + 1] != WorldGen.AIR:
			return
	
	# Kill the grass.
	types[i][j][k - 1] = WorldGen.DIRT
	
	# Make the tree!
	for y in range(tree.trunk_height + tree.brim_height):
		types[i][j][k + y] = tree.trunk_type
	
	var offset := tree.trunk_height
	var height := k + tree.trunk_height + tree.brim_height
	for x in range(-tree.brim_width, tree.brim_width + 1):
		for z in range(-tree.brim_width, tree.brim_width + 1):
			for y in range(tree.brim_height):
				if types[i + x][j + z][k + y + offset] == WorldGen.AIR:
					types[i + x][j + z][k + y + offset] = tree.leaf_type
			heights[i + x][j + z] = max(heights[i + x][j + z], height)

	offset += tree.brim_height
	height += tree.top_height
	for x in range(-tree.top_width, tree.top_width + 1):
		for z in range(-tree.top_width, tree.top_width + 1):
			for y in range(tree.top_height):
				if types[i + x][j + z][k + y + offset] == WorldGen.AIR:
					types[i + x][j + z][k + y + offset] = tree.leaf_type
			heights[i + x][j + z] = max(heights[i + x][j + z], height)
