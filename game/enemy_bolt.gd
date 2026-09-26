class_name EnemyBolt
extends Node2D

const MAXIMUM_DISTANCE := 760.0

var direction := Vector2.RIGHT
var speed := 240.0
var damage := 12.0
var distance_traveled := 0.0
var maximum_distance := MAXIMUM_DISTANCE
var visual_origin := Vector2.ZERO


func setup(new_direction: Vector2, new_speed: float, new_damage: float) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage
	z_index = 5


func _ready() -> void:
	add_to_group("enemy_bolts")


func _physics_process(delta: float) -> void:
	var travel := minf(speed * delta, maximum_distance - distance_traveled)
	if travel <= 0.0:
		queue_free()
		return
	var destination := global_position + direction * travel
	var ray := PhysicsRayQueryParameters2D.create(global_position, destination, 5)
	ray.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position = hit.position
		if hit.collider is SandboxPlayer:
			hit.collider.receive_hit(damage, global_position)
		queue_free()
		return
	global_position = destination
	distance_traveled += travel
	queue_redraw()


func _draw() -> void:
	draw_line(-direction * 15.0, Vector2.ZERO, Color(1.0, 0.52, 0.17, 0.5), 8.0)
	draw_line(-direction * 10.0, Vector2.ZERO, Color("fff0a6"), 3.0)
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.57, 0.15, 0.28))
	draw_circle(Vector2.ZERO, 4.0, Color("ffe18c"))
