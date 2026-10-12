extends SceneTree
var game: Node3D
func _initialize() -> void:call_deferred("capture")
func frames(count: int) -> void:
    for i in count:await process_frame
func save(name: String) -> void:
    await frames(8);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/"+name+".png")
func capture() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var park: Node3D=game.get_node("SamiPark")
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var hud: Node=game.get_node("HUD")
    var track: Node3D=park.running_track
    hud.set_paused(false)
    var dir: Vector2=(track.centerline[9]-track.centerline[8]).normalized()
    var normal:=Vector2(-dir.y,dir.x)
    var point: Vector2=(track.centerline[8]+track.centerline[9])*.5+normal
    cart.teleport_to(point,atan2(-dir.x,-dir.y))
    game.get_node("ChaseCamera").snap();park.nature.refresh()
    hud.toast_time=0;hud.tutorial_time=30;hud._process(0)
    await create_timer(1).timeout
    await save("running-track-drive")
    hud.open_map()
    hud.full_map.canvas.center_world=Vector2(-273,-574)
    hud.full_map.canvas.zoom=2.6;hud.full_map.select_point(point)
    await save("running-track-map")
    hud.close_map();hud.hide()
    game.get_node("WorldEnvironment").environment.fog_enabled=false
    var camera:=Camera3D.new();game.add_child(camera)
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=650;camera.far=2000
    camera.position=Vector3(-273,1000,-574);camera.rotation_degrees=Vector3(-90,0,0);camera.current=true
    park.nature.refresh();await create_timer(.5).timeout
    await save("running-track-overhead")
    print("TRACK_CAPTURE_COMPLETE")
    quit()
