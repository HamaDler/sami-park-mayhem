extends Node3D
var active_vehicle: Node3D
var survival: Node3D
@onready var player: CharacterBody3D=$WalkPlayer
@onready var park: Node3D=$SamiPark
@onready var camera_rig: Node3D=$ChaseCamera
@onready var hud: CanvasLayer=$HUD
func _ready() -> void:
    _setup_inputs()
    $GolfCart.initialize(park)
    player.initialize(park,camera_rig)
    hud.initialize($GolfCart,park)
    player.recovered.connect(hud.show_toast)
    camera_rig.initialize($GolfCart)
    var spawn: Dictionary=park.layout.spawn
    var start:=Vector2(spawn.position[0],spawn.position[1])
    player.teleport_to(start+Vector2(0,3.4),float(spawn.yaw));player.set_active(true)
    camera_rig.follow_actor(player,true);hud.set_context(player,false)
    $Crowd.process_mode=Node.PROCESS_MODE_DISABLED
    survival=$Survival;survival.initialize(self)
    hud.initialize_survival(survival)
    var audio: Node=GameUI.audio_manager()
    if audio:audio.bind_game(self)
    get_tree().auto_accept_quit=false
    if not get_window().close_requested.is_connected(GameUI.quit_game):get_window().close_requested.connect(GameUI.quit_game)
    get_window().focus_exited.connect(func():hud.set_paused(true))
func get_active_actor() -> CharacterBody3D:
    if is_instance_valid(active_vehicle):return active_vehicle.vehicle
    return player if is_instance_valid(player) else get_node_or_null("GolfCart")
func is_driving() -> bool:return is_instance_valid(active_vehicle)
func _setup_inputs() -> void:
    var bindings: Dictionary={"accelerate":[KEY_W,KEY_UP],"reverse":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"brake":[KEY_SPACE],"jump":[KEY_SPACE],"recover":[KEY_R],"pause":[KEY_ESCAPE],"map_toggle":[KEY_M],"interact":[KEY_F],"sprint":[KEY_SHIFT],"weapon_1":[KEY_1],"weapon_2":[KEY_2],"weapon_3":[KEY_3]}
    for action: String in bindings:
        if not InputMap.has_action(action):InputMap.add_action(action)
        for key in bindings[action]:
            var event:=InputEventKey.new();event.physical_keycode=key
            if not InputMap.action_has_event(action,event):InputMap.action_add_event(action,event)
    for action in ["fire","aim"]:
        if not InputMap.has_action(action):InputMap.add_action(action)
        var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT if action=="fire" else MOUSE_BUTTON_RIGHT
        if not InputMap.action_has_event(action,event):InputMap.action_add_event(action,event)
func _unhandled_input(event: InputEvent) -> void:
    if player.movement_locked:return
    if get_tree().paused or (survival and survival.over) or (event is InputEventKey and event.echo):return
    if event.is_action_pressed("interact"):
        if is_driving():exit_vehicle()
        else:
            var action: Dictionary=survival.nearest_action() if survival else {}
            var access:=nearest_vehicle()
            if not action.is_empty() and (access==null or player.global_position.distance_to(action.station.to_global(action.position))<player.global_position.distance_to(access.vehicle.global_position)):survival.use_action(action)
            elif access:enter_vehicle(access)
            else:hud.show_toast("MOVE CLOSER TO A VEHICLE")
        get_viewport().set_input_as_handled()
func nearest_vehicle() -> Node3D:
    var best: Node3D=null
    var distance: float=player.settings.interaction_distance
    for access: Node3D in get_tree().get_nodes_in_group("vehicles"):
        if not access.available():continue
        var candidate: float=player.global_position.distance_to(access.vehicle.global_position)
        if candidate>minf(distance,access.interaction_distance):continue
        var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,access.vehicle.global_position+Vector3.UP,3,[player.get_rid(),access.vehicle.get_rid()])
        if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
        distance=candidate;best=access
    return best
func enter_vehicle(access: Node3D, initial: bool=false) -> bool:
    if not initial and is_driving():return false
    if not initial and (not access.available() or player.global_position.distance_to(access.vehicle.global_position)>access.interaction_distance):return false
    var body: CharacterBody3D=access.vehicle
    if not body.has_meta("interaction_signals_bound"):
        body.set_meta("interaction_signals_bound",true)
        body.recovered.connect(func(reason: String):
            if get_active_actor()==body:camera_rig.snap();hud.show_toast(reason))
        body.rollover_started.connect(func():
            if get_active_actor()==body:hud.show_toast("CART ROLLING   /   R TO RESET"))
    player.set_active(false)
    active_vehicle=access;access.set_occupied(player)
    camera_rig.follow_actor(access.vehicle,false)
    hud.set_context(access.vehicle,true)
    park.nature.refresh()
    if not initial:hud.show_toast("ENTERED "+access.display_name)
    return true
func _exit_position(access: Node3D, force: bool=false) -> Dictionary:
    var capsule:=CapsuleShape3D.new();capsule.radius=.30;capsule.height=1.72
    var candidates: Array[Vector3]=access.exit_candidates()
    if access.vehicle.rolling or force:
        for radius in [3.2,5.0,8.0]:
            for i in 12:candidates.append(access.vehicle.global_position+Vector3(cos(i*TAU/12)*radius,0,sin(i*TAU/12)*radius))
    for candidate: Vector3 in candidates:
        var point:=Vector2(candidate.x,candidate.z)
        if not park._map_land_rejection(point).is_empty():continue
        var ray:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*2,candidate-Vector3.UP*1.5,1)
        var ground:=get_world_3d().direct_space_state.intersect_ray(ray)
        if ground.is_empty() or ground.normal.y<.65:continue
        var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=3;query.exclude=[player.get_rid()]
        query.collision_mask=11
        query.transform=Transform3D(Basis.IDENTITY,ground.position+Vector3.UP*.90)
        if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
        return {"position":point,"height":ground.position.y}
    return {}
func exit_vehicle(force: bool=false) -> bool:
    if not is_driving():return false
    if not force and active_vehicle.vehicle.rolling and active_vehicle.vehicle.speed>3:hud.show_toast("WAIT FOR THE CART TO STOP ROLLING");return false
    var exit:=_exit_position(active_vehicle,force)
    if exit.is_empty() and force and survival:
        var p: Vector2=survival.safe_point(Vector2(active_vehicle.vehicle.global_position.x,active_vehicle.vehicle.global_position.z),player)
        exit={"position":p,"height":.05}
    if exit.is_empty():hud.show_toast("EXIT BLOCKED - MOVE TO A CLEAR AREA");return false
    var yaw: float=active_vehicle.vehicle.rotation.y
    active_vehicle.set_occupied(null);active_vehicle=null
    player.teleport_to(exit.position,yaw);player.global_position.y=float(exit.height)+.08
    player.set_active(true)
    camera_rig.follow_actor(player,true)
    hud.set_context(player,false)
    park.nature.refresh()
    hud.show_toast("ON FOOT   /   F TO ENTER NEAR A VEHICLE")
    return true
func teleport_active(point: Vector2, yaw: float) -> void:
    if survival:return
    get_active_actor().teleport_to(point,yaw)
    if not is_driving():camera_rig.foot_yaw=yaw
    camera_rig.snap();park.nature.refresh();$Crowd.refresh()
func recover_active() -> void:
    if survival:
        get_tree().paused=false;get_tree().reload_current_scene()
    else:get_active_actor().recover()
func interaction_text() -> String:
    if survival:
        if survival.over:return ""
        if not survival.action.is_empty():return "REPAIRING  /  %d%% — STAY STILL" % roundi(survival.action_progress/float(survival.config.economy.repair_seconds)*100)
        if survival.can_recover():return "HOLD R  /  RIGHT CART   %d%%" % roundi(survival.recovery_time/float(survival.config.economy.recovery_seconds)*100)
        var action: Dictionary=survival.nearest_action()
        var vehicle:=nearest_vehicle() if not is_driving() else null
        if not action.is_empty() and (vehicle==null or player.global_position.distance_to(action.station.to_global(action.position))<player.global_position.distance_to(vehicle.vehicle.global_position)):return action.station.prompt(str(action.kind))
    if is_driving():return "F  /  EXIT "+active_vehicle.display_name
    var access:=nearest_vehicle()
    return "F  /  ENTER "+access.display_name if access else ""
