extends Chunk

var block_mats = [ null,
		preload("res://chunking/blocks_server/dirt.tres"),
		preload("res://chunking/blocks_server/grass.tres"),
		preload("res://chunking/blocks_server/stone.tres"),
		preload("res://chunking/blocks_server/log1.tres"),
		preload("res://chunking/blocks_server/leaves1.tres"),
		preload("res://chunking/blocks_server/wood1.tres"),
		preload("res://chunking/blocks_server/log2.tres"),
		preload("res://chunking/blocks_server/leaves2.tres"),
		preload("res://chunking/blocks_server/wood2.tres"),
		preload("res://chunking/blocks_server/glass.tres")
	]

var block_ids = []
var block_array := []
var scenario
var material
var collide
var rendered := false
var shape


func _ready():
	scenario = get_world_3d().scenario
	for mat in block_mats:
		if mat == null:
			block_ids.append(null)
		else:
			block_ids.append(mat.get_rid())
	
	var xform = Transform3D(Basis(), position)
	collide = PhysicsServer3D.body_create()
	
	PhysicsServer3D.body_set_space(collide, get_world_3d().space)
	PhysicsServer3D.body_set_state(collide, PhysicsServer3D.BODY_STATE_TRANSFORM, xform)
	PhysicsServer3D.body_set_collision_layer(collide, 0)
	
	shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, (Vector3.ONE / 2))


func place_block(local_pos: Vector3, type, regen = true):
	var pos = local_pos.floor()
	blocks.set_block(pos, type)
	if regen:
		update()
		finalize()
	else:
		_destroy_block(pos.x, pos.y, pos.z)
		_create_block(pos.x, pos.y, pos.z, type)
#		_add_collider(pos.x, pos.y, pos.z)


func break_block(local_pos: Vector3, regen = true):
	var pos = local_pos.floor()
	blocks.set_block(pos, WorldGen.AIR)
	if regen:
		update()
		finalize()
	else:
		_destroy_block(pos.x, pos.y, pos.z)


func update():
	if !rendered:
		_render()
	else:
		PhysicsServer3D.body_clear_shapes(collide)
		for x in Globals.chunk_size.x:
			for z in Globals.chunk_size.z:
				@warning_ignore("narrowing_conversion")
				var height = blocks.get_height(x, z)
				for y in height:
					if blocks.types[x][z][y] == WorldGen.AIR:
						_destroy_block(x, y, z)
					elif (blocks.flags[x][z][y] & ChunkData.ALL_SIDES != ChunkData.ALL_SIDES):
						if block_array[x][z][y] == null:
							_create_block(x, y, z, blocks.types[x][z][y])
#						_add_collider(x, y, z)


func _render():
	rendered = true
	block_array = []
# warning-ignore:narrowing_conversion
	@warning_ignore("narrowing_conversion")
	block_array.resize(Globals.chunk_size.x)
	for x in Globals.chunk_size.x:
		block_array[x] = []
		block_array[x].resize(Globals.chunk_size.z)
		for z in Globals.chunk_size.z:
			block_array[x][z] = []
			block_array[x][z].resize(Globals.chunk_size.y)
			@warning_ignore("narrowing_conversion")
			var height = blocks.get_height(x, z)
			for y in height:
				if blocks.types[x][z][y] != WorldGen.AIR and (blocks.flags[x][z][y] & ChunkData.ALL_SIDES != ChunkData.ALL_SIDES):
					_create_block(x, y, z, blocks.types[x][z][y])
#					_add_collider(x, y, z)


func _create_block(x, y, z, type):
	var xform = Transform3D(Basis(), position + Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5))
	var visual = RenderingServer.instance_create2(block_ids[type], scenario)
	RenderingServer.instance_set_transform(visual, xform)
	block_array[x][z][y] = visual


func _add_collider(x, y, z):
	PhysicsServer3D.body_add_shape(collide, shape, Transform3D(Basis(), Vector3(x, y, z)))


func _destroy_block(x, y, z):
	if block_array[x][z][y] != null:
		RenderingServer.free_rid(block_array[x][z][y][0])
		PhysicsServer3D.free_rid(block_array[x][z][y][1])
		block_array[x][z][y] = null


func finalize():
	blocks.depool()
