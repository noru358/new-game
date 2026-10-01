extends RefCounted
## Opt-in temple-only comparison. The scene owner calls update(arena, delta)
## instead of the two legacy threshold/sanctuary alpha updates. Nothing mounts
## this candidate automatically; restore() also makes a live comparison reversible.

const Terrain = preload("res://game/hybrid_terrain.gd")
const Sanctuary = preload("res://game/temple_sanctuary_environment.gd")
const CLEAR_HOLD := 0.35
const RESTORE_SECONDS := 0.18
const HOLD_MARGIN := 10.0
# Existing horizontal stone-course tops, with a small gap above their caps.
# These opaque courses retain the obstacle's footing while the upper member clears.
const BASE_HEIGHTS := {
	"RuinedSanctuaryThreshold": 52.5,
	"SteppedSanctuary": 55.3,
	"BrokenRearGallery": 25.3,
	"CourtMasonryRemnant": 65.0,
}
const CUT_SHADER := """shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
uniform float cut_height = 1000.0;
varying float stone_height;
void vertex() { stone_height = VERTEX.y; }
void fragment() {
	if (stone_height > cut_height) { discard; }
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

var members: Array[Dictionary] = []
var transition_count := 0
var _installed := false


func install(arena: Node3D) -> void:
	if _installed: return
	_installed = true
	var shader := Shader.new()
	shader.code = CUT_SHADER
	for group_root in [arena.temple_environment_root, arena.temple_sanctuary_root]:
		if not is_instance_valid(group_root): continue
		for mesh in group_root.get_children():
			if not mesh is MeshInstance3D or not BASE_HEIGHTS.has(String(mesh.name)): continue
			var original: Material = mesh.get_meta("solid_material", mesh.material_override)
			var material := ShaderMaterial.new()
			material.shader = shader
			var height: float = mesh.get_aabb().end.y + 0.01
			material.set_shader_parameter("cut_height", height)
			members.append({"mesh": mesh, "original": original, "material": material,
				"shadow": GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
				"triangles": mesh.mesh.generate_triangle_mesh(),
				"base": float(BASE_HEIGHTS[String(mesh.name)]) * Terrain.SCALE,
				"full": height, "height": height, "cut": false,
				"clear_time": 0.0, "transitions": 0})


func update(arena: Node3D, delta: float) -> void:
	if not _installed: install(arena)
	var inactive: bool = not is_instance_valid(arena.player) or arena.overview or (arena.temple_section != null and arena.temple_section.in_garden)
	var targets: Array[Vector3] = []
	if not inactive:
		for actor in arena.actors:
			if not is_instance_valid(actor): continue
			if actor != arena.player and (not actor is TrainingEnemy or actor.health <= 0): continue
			if actor == arena.player and actor.health <= 0: continue
			var visual = arena.actors[actor]
			if not is_instance_valid(visual) or not visual.is_visible_in_tree(): continue
			if actor.position.distance_to(arena.player.position) > 1500: continue
			# Preserve face and torso. Feet behind the retained low wall remain
			# grounded in its depth, rather than erasing the wall's entire footprint.
			for lift in [55.0, 120.0 if actor is GateBoss else 85.0]:
				targets.append(arena.terrain.world_point(actor.position, lift))
		Sanctuary._add_boss_warning_targets(arena, targets)
	var visible_targets: Array[Vector3] = []
	for target in targets:
		if arena.get_viewport().get_visible_rect().has_point(arena.camera.unproject_position(target)):
			visible_targets.append(target)
	for member in members:
		if not is_instance_valid(member.mesh): continue
		if inactive or not member.mesh.is_visible_in_tree():
			_reset_member(member)
			continue
		var obscures := _obscures(member, arena, visible_targets, HOLD_MARGIN if member.cut else 0.0)
		if obscures:
			member.clear_time = 0.0
			_set_cut(member, true)
		else:
			member.clear_time += maxf(0.0, delta)
			if member.clear_time >= CLEAR_HOLD: _set_cut(member, false)
		# Entry clears immediately, including a direction reversal mid-restore.
		# Only the safe return animates, after the clear interval has elapsed.
		member.height = member.base if member.cut else move_toward(float(member.height), float(member.full), (float(member.full) - float(member.base)) * maxf(0.0, delta) / RESTORE_SECONDS)
		member.material.set_shader_parameter("cut_height", member.height)
		member.mesh.material_override = member.material
		member.mesh.cast_shadow = member.shadow


func _obscures(member: Dictionary, arena: Node3D, targets: Array[Vector3], margin: float) -> bool:
	var toward: Vector3 = arena.camera.global_basis.z * 40.0
	var side: Vector3 = arena.camera.global_basis.x * margin * Terrain.SCALE
	var offsets: Array[Vector3] = [Vector3.ZERO]
	if margin > 0.0: offsets.append_array([side, -side, Vector3.UP * margin * Terrain.SCALE])
	for target in targets:
		for offset in offsets:
			var origin: Vector3 = member.mesh.to_local(target + offset)
			var end: Vector3 = member.mesh.to_local(target + offset + toward)
			var hit: Dictionary = member.triangles.intersect_segment(origin, end)
			if not hit.is_empty() and hit.position.y > float(member.base): return true
	return false


func _set_cut(member: Dictionary, cut: bool) -> void:
	if member.cut == cut: return
	member.cut = cut
	member.transitions += 1
	transition_count += 1


func _reset_member(member: Dictionary) -> void:
	_set_cut(member, false)
	member.clear_time = 0.0
	member.height = member.full
	member.material.set_shader_parameter("cut_height", member.full)
	member.mesh.material_override = member.original
	member.mesh.cast_shadow = member.shadow


func restore() -> void:
	for member in members:
		if is_instance_valid(member.mesh): _reset_member(member)
	members.clear()
	_installed = false
