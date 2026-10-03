extends "res://game/hybrid_region.gd"
const Wetland = preload("res://game/deep_wetland_terrain.gd")
const Field = preload("res://game/deep_wetland_field_terrain.gd")
const RunTerrain = preload("res://game/wetland_boss_trial_terrain.gd")
const Layout = preload("res://game/wetland_run_layout.gd")
const WetlandDecor = preload("res://game/wetland_environment.gd")
const GuardianVisual = preload("res://game/wetland_guardian_visual.gd")
var root_visuals: Dictionary = {}
var place_encounter_trial := true
func _init() -> void:
	super._init()
	terrain=RunTerrain.new()
	start_point=Wetland.ENTRY
	region_id=RunProfile.WETLAND_REGION
	boss_scene=preload("res://game/wetland_boss.tscn")
	boss_name="석면 수호자"
	first_clear_notice="깊은 사원 습지 정복"
	scene_title="Loop Conquest — 깊은 사원 습지"
	scene_hud_title="깊은 사원 습지"
	profile_save_prefix="user://loop_conquest_profile"
	growth_save_prefix="user://loop_conquest_1d_unlocks"
	landmark_points={"입구":Wetland.ENTRY,"얼굴 유적":Wetland.FACE_BANK,"사원뜰":Wetland.TEMPLE_COURT,"안쪽 성소":Vector2(5020,1060)}
	temple_environment_enabled=false
	temple_sanctuary_enabled=false
	temple_opening_enabled=false
	ground_color=Color("4c6858")
	overview_camera_size=65.0
func _ready() -> void:
	preload("res://game/field_preview_session.gd").configure(self)
	var access:=RunProfile.new()
	access.save_prefix=profile_save_prefix
	access.load_state()
	if not access.load_error and not access.region_available(region_id):
		set_process(false)
		set_physics_process(false)
		get_tree().call_deferred("change_scene_to_file","res://game/travel_camp.tscn")
		return
	super._ready()
	minimap.title_text="습지 지도"
	minimap.legend_override="참배길 · 얼굴 유적 · 안쪽 성소"
func region_layout(): return Layout
func _create_region_section() -> Node:
	var section=preload("res://game/wetland_section.gd").new()
	section.layout=Layout
	section.field_area=Rect2()
	section.boss_area=RunTerrain.DUEL
	section.boss_point=Vector2(5020,1060)
	section.boss_spawn_points=[Vector2(5020,1060),Vector2(5210,1380),Vector2(4780,820)]
	section.retry_point=Vector2(4500,1670)
	section.destination_point=Vector2(4600,1720)
	return section
func _build_terrain(render_bounds := Rect2()) -> void:
	super._build_terrain(render_bounds)
	WetlandDecor.build(self)
	WetlandDecor.build_field(self)
func _dry_routes() -> Array: return [Wetland.WAYPOINTS,Wetland.SIDE_ROUTE,Field.INNER_ROUTE,Field.RETURN_ROUTE]
func _inner_ruins() -> Array: return Field.INNER_RUINS.filter(func(area): return not area.intersects(RunTerrain.DUEL.grow(30)))
func _far_bank_groves() -> Array: return [Vector2(330,450),Vector2(420,1110),Vector2(390,1900),Vector2(1140,300),Vector2(1770,350),Vector2(3650,400),Vector2(4130,300)]
func _top(st: SurfaceTool,area: Rect2,elevation: Callable,color: Color) -> void:
	var tint:=Color("294e50") if color==Color("39858b") else color
	var points: Array=[]
	for p in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]: points.append(Vector3(p.x,elevation.call(p),p.y))
	_quad(st,points,tint)
func _build_boss_figure(visual: Node3D) -> void:
	visual.get_node("Body").hide()
	GuardianVisual.build(self,visual)
func _animate_boss_figure() -> void:
	if not is_instance_valid(boss) or not actors.has(boss): return
	var figure: Node3D=actors[boss].get_node("BossFigure")
	figure.rotation.y=atan2(player.position.x-boss.position.x,player.position.y-boss.position.y)
	figure.rotation.x=-0.08 if boss.pattern_active else 0.08 if boss.recovery_time>0 else 0.0
	var core: MeshInstance3D=figure.get_node("FaceCore")
	core.material_override.albedo_color=Color.WHITE if boss.hit_flash>0 else Color("b5ad78") if boss.phase==2 else Color("8f9d7c")
func _process(delta: float) -> void:
	super._process(delta)
	GuardianVisual.update_roots(self,boss,root_visuals)

func _roll_role() -> TrainingEnemy.Role:
	if not place_encounter_trial:return super._roll_role()
	if boss_spawned or run_time<45.0:return TrainingEnemy.Role.FRAGMENT
	var weights=preload("res://game/wetland_encounter_composition.gd").weights(player.position,run_time,_encounter_phase())
	var roll:=rng.randf()*100.0
	for role in 5:
		roll-=weights[role]
		if roll<0.0:return role as TrainingEnemy.Role
	return TrainingEnemy.Role.FRAGMENT
