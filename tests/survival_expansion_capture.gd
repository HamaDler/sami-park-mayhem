extends SceneTree
var game: Node3D
const OUTPUT="C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/"
func _initialize() -> void:call_deferred("run")
func save_view(filename: String) -> void:
    for i in 10:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUTPUT+filename)
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var s: Node3D=game.survival;s.set_physics_process(false);s.enemies.set_physics_process(false)
    var center:=Vector2(195.8739,-39.85362)
    var forward:=Vector2(.949736,.313053);var side:=Vector2(-forward.y,forward.x)
    game.player.teleport_to(center-forward*4,atan2(-forward.x,-forward.y));game.camera_rig.foot_yaw=game.player.rotation.y;game.camera_rig.snap()
    s.wave.begin_next()
    var index:=0
    for kind: String in ["walker","runner","armored","screamer"]:
        var zombie: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();s.enemies.add_child(zombie)
        var model: int=s.enemies.types[kind].model;zombie.build(s.enemies,s.enemies.models[model],model);s.enemies.pool.append(zombie)
        zombie.activate(center+forward*5+side*(index-1.5)*2,index+1,s.enemies.type_stats(1,kind));zombie.rotation.y=game.player.rotation.y+PI
        zombie.set_physics_process(false);zombie.animator.advance(.15);index+=1
    var camera:=Camera3D.new();game.add_child(camera);camera.global_position=Vector3(center.x-forward.x*5,3,center.y-forward.y*5)
    camera.look_at(Vector3(center.x+forward.x*5,1.05,center.y+forward.y*5));camera.current=true
    await save_view("zombie-archetypes.png")
    for zombie in s.enemies.pool:zombie.deactivate()
    s.missions.start_mission(0)
    var p: Vector2=s.missions.position_2d
    game.player.teleport_to(p+Vector2(5,0),0)
    camera.global_position=Vector3(p.x+23,14,p.y+25);camera.look_at(Vector3(p.x,0,p.y));s.missions.tick(12)
    await save_view("supply-cache-world.png")
    game.hud.open_map();await save_view("supply-cache-map.png");game.hud.close_map()
    GameUI.audio_manager().stop_all();game.queue_free();await process_frame;await process_frame;quit()
