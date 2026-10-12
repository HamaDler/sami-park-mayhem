extends SceneTree
var game: Node3D
var hud: Node
var park: Node3D
var cart: CharacterBody3D
var failures: int = 0
var checks: int = 0
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:
        failures+=1
        push_error("FAIL: "+message)
func ui_frames(count: int = 3) -> void:
    for i in count:await process_frame
func key(code: Key, echo: bool = false) -> void:
    var event:=InputEventKey.new()
    event.physical_keycode=code
    event.pressed=true
    event.echo=echo
    Input.parse_input_event(event)
    await ui_frames()
    event.pressed=false
    event.echo=false
    Input.parse_input_event(event)
    await ui_frames()
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    hud=game.get_node("HUD")
    park=game.get_node("SamiPark")
    cart=game.get_node("GolfCart")
    await ui_frames(5)
    hud.set_paused(false)
    await key(KEY_M)
    check(hud.full_map.visible and paused and not hud.pause_overlay.visible,"M opens the full map and pauses driving")
    var map: Control= hud.full_map
    var canvas: Control=map.canvas
    check(canvas.paths.size()==park.layout.paths.size() and canvas.lakes.size()==park.water_polygons.size(),"Full map uses the actual game paths and lakes")
    check(canvas.labels.size()>=7 and canvas.trees.size()==park.tree_count,"Stylized map includes entrances, landmarks, and park planting")
    check(Rect2(Vector2.ZERO,map.size).encloses(map.side_panel.get_rect()),"Map sidebar stays within the viewport")
    check(root.disable_3d,"Full map suspends hidden 3D rendering")
    check(canvas.tree_mesh != null and canvas.tree_mesh.get_surface_count()==1,"All map trees share a single mesh")
    await ui_frames()
    var terrain_draws: Dictionary={"count":0}
    canvas.terrain.draw.connect(func():terrain_draws.count+=1)
    var position_before:=cart.position
    Input.action_press("accelerate")
    await create_timer(0.05,true).timeout
    check(cart.position.is_equal_approx(position_before),"Cart stays stationary while browsing the map")
    Input.action_release("accelerate")
    var anchor:=Vector2(320,260)
    var anchor_world: Vector2=canvas.map_to_world(anchor)
    var wheel:=InputEventMouseButton.new()
    wheel.button_index=MOUSE_BUTTON_WHEEL_UP
    wheel.pressed=true
    wheel.position=anchor
    canvas._gui_input(wheel)
    check(canvas.zoom>1 and canvas.map_to_world(anchor).distance_to(anchor_world)<0.001,"Wheel zoom keeps the point under the cursor fixed")
    var click:=InputEventMouseButton.new()
    click.button_index=MOUSE_BUTTON_RIGHT
    click.pressed=true
    canvas._gui_input(click)
    await ui_frames()
    var draws_before: int=terrain_draws.count
    var center_before: Vector2=canvas.center_world
    var drag:=InputEventMouseMotion.new()
    drag.relative=Vector2(80,-40)
    canvas._gui_input(drag)
    check(canvas.center_world.distance_to(center_before)>20,"Dragging pans the map across real world coordinates")
    await ui_frames()
    check(terrain_draws.count==draws_before,"Panning reuses scenery without rebuilding its drawing commands")
    check(canvas.terrain.position.is_equal_approx(canvas.size*.5-canvas.center_world*canvas.fit_scale*canvas.zoom),"Cached scenery follows the map transform")
    canvas.zoom_at(1.2,anchor)
    await ui_frames()
    check(terrain_draws.count>draws_before,"Zoom refreshes scenery line widths")
    click.pressed=false
    canvas._gui_input(click)
    check(not canvas.panning,"Releasing the mouse ends panning")
    canvas.zoom_at(100,anchor)
    check(canvas.zoom==10,"Zoom in has a usable maximum")
    canvas.zoom_at(0.00001,anchor)
    check(canvas.zoom==0.8,"Zoom out has a usable minimum")
    canvas.find_cart()
    check(canvas.world_to_map(Vector2(cart.position.x,cart.position.z)).distance_to(canvas.size*0.5)<0.01,"Find my cart centers the player marker")
    canvas.fit_park()
    check(canvas.zoom==1 and canvas.center_world.is_equal_approx(canvas.bounds.get_center()),"Fit whole park restores the complete park view")
    var destination:=Vector2(445,-76.47)
    click.button_index=MOUSE_BUTTON_LEFT
    click.pressed=true
    click.position=canvas.world_to_map(destination)
    canvas._gui_input(click)
    check(map.selection.valid and not map.spawn_button.disabled,"Clicking clear land selects an available destination")
    var selected: Vector2=map.selection.position
    var trip_before: float=cart.distance_m
    cart.speed=22
    cart.drift_blend=1
    cart.slip_angle=0.5
    cart.drifting=true
    map.spawn_button.pressed.emit()
    await ui_frames(5)
    check(not paused and not map.visible,"Spawn here closes the map and resumes the game")
    check(not root.disable_3d,"Spawning restores 3D rendering")
    check(Vector2(cart.position.x,cart.position.z).distance_to(selected)<0.01,"Cart appears at the selected map coordinates")
    check(cart.speed==0 and cart.velocity.x==0 and not cart.drifting and cart.slip_angle==0,"Map spawning clears speed and drift momentum")
    check(absf(cart.distance_m-trip_before)<0.01,"Teleport distance is not counted as distance driven")
    check(cart.safe_transform.origin.distance_to(cart.position)<0.3,"Map destination becomes the new recovery point")
    var rig=game.get_node("ChaseCamera")
    check(rig.global_position.distance_to(cart.global_position)<2,"Camera snaps to the new map destination")
    cart.position.x+=10
    cart.recover()
    check(Vector2(cart.position.x,cart.position.z).distance_to(selected)<0.01,"Recovery returns to the map destination")
    await key(KEY_M)
    var lake_point:=Vector2.ZERO
    for point in park.water_polygons[0]:lake_point+=point
    lake_point/=park.water_polygons[0].size()
    map.select_point(lake_point)
    check(not map.selection.valid and map.spawn_button.disabled,"Water cannot be selected as a spawn destination")
    position_before=cart.position
    map.spawn_selected()
    check(map.visible and cart.position.is_equal_approx(position_before),"Invalid selection cannot teleport the cart")
    map.select_point(Vector2(2500,2500))
    check(not map.selection.valid and map.selection.reason.contains("inside the park"),"Places outside the park are rejected")
    var building_tested:=false
    for poly in park.building_polygons:
        var midpoint:=Vector2.ZERO
        for point in poly:midpoint+=point
        midpoint/=poly.size()
        if park._inside_water_polygon(midpoint,poly) and park._inside_water_polygon(midpoint,park.boundary) and not park.is_water(midpoint):
            map.select_point(midpoint)
            building_tested=not map.selection.valid and map.selection.reason.contains("building")
            break
    check(building_tested,"Building interiors are rejected")
    var trunk:=Vector3(park.tree_positions[0].x,0,park.tree_positions[0].y)
    var tree_point:=Vector2(trunk.x,trunk.z)
    map.select_point(tree_point)
    check(map.selection.valid and map.selection.position.distance_to(tree_point)>=1.9,"A selected tree position shifts to nearby clear land")
    var obstacle:=ParkGeometry.collider(game,Vector3(destination.x,1,destination.y),Vector3(5,2,5))
    await ui_frames(5)
    map.select_point(destination)
    check(map.selection.valid and map.selection.position.distance_to(destination)>3,"Spawn placement clears colliding scenery")
    obstacle.queue_free()
    await key(KEY_ESCAPE)
    check(not map.visible and not paused,"Esc closes the map and restores driving")
    check(not root.disable_3d,"Esc restores 3D rendering")
    hud.set_paused(true)
    await key(KEY_M)
    await key(KEY_M)
    check(paused and hud.pause_overlay.visible and not map.visible,"Opening and closing the map from pause restores the pause menu")
    hud.set_paused(false)
    await key(KEY_M)
    await key(KEY_M,true)
    check(map.visible,"Holding M does not repeatedly toggle the map")
    await key(KEY_M)
    check(not map.visible and not paused,"M toggles the map closed")
    await key(KEY_M)
    map.select_point(Vector2(-693.162,-38.357))
    var enter_destination: Vector2=map.selection.position
    map.close_button.grab_focus()
    await key(KEY_ENTER)
    check(not map.visible and not paused and Vector2(cart.position.x,cart.position.z).distance_to(enter_destination)<0.1,"Enter spawns at the selected destination even with another button focused")
    await key(KEY_M)
    canvas.fit_park()
    click.position=canvas.world_to_map(destination)
    click.double_click=true
    canvas._gui_input(click)
    await ui_frames()
    check(not map.visible and Vector2(cart.position.x,cart.position.z).distance_to(destination)<0.1,"Double-click selects and spawns directly")
    root.disable_3d=true
    await key(KEY_M)
    await key(KEY_M)
    check(root.disable_3d,"Closing the map preserves a previously disabled 3D viewport")
    root.disable_3d=false
    print("MAP_RESULT: ",checks," checks, ",failures," failures")
    quit(failures)
