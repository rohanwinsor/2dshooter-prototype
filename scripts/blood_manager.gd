extends Node

const BLOOD_DECAL_SCENE: PackedScene = preload("res://effects/blood_decal.tscn")

@export var max_decals: int = 150
@export var spray_count: int = 4
@export var spray_spread_degrees: float = 22.5
@export var ray_length: float = 180.0
@export var floor_ray_length: float = 220.0

var _rng := RandomNumberGenerator.new()
var _decal_parent: Node2D
var _decals: Array[Node] = []

func _ready() -> void:
	_rng.randomize()
	get_tree().connect("current_scene_changed", Callable(self, "_on_scene_changed"))
	_assign_decal_parent()

func spawn_splatter(origin: Vector2, incoming_direction: Vector2, excludes: Array = []) -> void:
	var parent := _ensure_decal_parent()
	if parent == null:
		return
	var space_state := parent.get_world_2d().direct_space_state
	var direction := incoming_direction
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	direction = direction.normalized()

	var ray_params := PhysicsRayQueryParameters2D.create(origin, origin)
	ray_params.collision_mask = 0xFFFFFFFF
	ray_params.exclude = excludes

	for i in range(spray_count):
		var spread := deg_to_rad(_rng.randf_range(-spray_spread_degrees, spray_spread_degrees))
		var cast_dir := direction.rotated(spread)
		ray_params.from = origin
		ray_params.to = origin + cast_dir * ray_length
		var hit := space_state.intersect_ray(ray_params)
		if hit:
			var collider: Object = hit.get("collider")
			if _is_surface_bloodable(collider, hit.get("position")):
				_spawn_decal(hit.get("position"), hit.get("normal"))
				continue
		var floor_hit := _cast_floor(space_state, origin, excludes)
		if floor_hit and _is_surface_bloodable(floor_hit.get("collider"), floor_hit.get("position")):
			_spawn_decal(floor_hit.get("position"), floor_hit.get("normal"))

func clear_splatter() -> void:
	for decal in _decals:
		if is_instance_valid(decal):
			decal.queue_free()
	_decals.clear()

func _on_scene_changed(_new_scene: Node) -> void:
	_assign_decal_parent()

func _assign_decal_parent() -> void:
	_decal_parent = null
	var scene := get_tree().current_scene
	if scene == null:
		return
	_decal_parent = scene.get_node_or_null("BloodLayer")
	if _decal_parent == null:
		_decal_parent = Node2D.new()
		_decal_parent.name = "BloodLayer"
		scene.add_child(_decal_parent)

func _ensure_decal_parent() -> Node2D:
	if _decal_parent == null or not is_instance_valid(_decal_parent):
		_assign_decal_parent()
	return _decal_parent

func _is_surface_bloodable(collider: Object, world_position: Vector2) -> bool:
	if collider == null:
		return false
	if collider is TileMap:
		var tilemap := collider as TileMap
		var local := tilemap.to_local(world_position)
		var map_coords := tilemap.local_to_map(local)
		var layer_count := tilemap.get_layers_count()
		for layer in range(layer_count):
			var data: TileData = tilemap.get_cell_tile_data(layer, map_coords)
			if data == null:
				continue
			var custom: Variant = data.get_custom_data("bloodable")
			if typeof(custom) == TYPE_BOOL:
				return custom
			if typeof(custom) in [TYPE_INT, TYPE_FLOAT]:
				return custom != 0
			if typeof(custom) == TYPE_STRING:
				return custom != "false"
		# If tile had data but none flagged, treat as false
		return false
	return true

func _spawn_decal(position: Vector2, normal: Vector2) -> void:
	var parent := _ensure_decal_parent()
	if parent == null:
		return
	var decal := BLOOD_DECAL_SCENE.instantiate()
	parent.add_child(decal)
	if decal is BloodDecal:
		(decal as BloodDecal).setup(position, normal, _rng)
	elif decal is Node2D:
		var node2d := decal as Node2D
		node2d.global_position = position
	var sprite := decal.get_node_or_null("Sprite2D")
	if sprite is Sprite2D:
		(sprite as Sprite2D).modulate.a = 0.88
	_decals.append(decal)
	if _decals.size() > max_decals:
		var oldest: Node = _decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _cast_floor(space_state: PhysicsDirectSpaceState2D, origin: Vector2, excludes: Array) -> Dictionary:
	var params := PhysicsRayQueryParameters2D.create(origin, origin + Vector2.DOWN * floor_ray_length)
	params.collision_mask = 0xFFFFFFFF
	params.exclude = excludes
	return space_state.intersect_ray(params)
