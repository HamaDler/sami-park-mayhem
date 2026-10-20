extends SceneTree
var game: Node3D
const OUT: String="C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs"
func _initialize() -> void:call_deferred("run")
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var s: Node3D=game.survival;s.enemies.set_physics_process(false);s.set_physics_process(false)
    var p:=Vector2(195.8739,-39.85362);var forward:=Vector2(.949736,.313053);var side:=Vector2(-forward.y,forward.x)
    game.player.teleport_to(p,atan2(-forward.x,-forward.y));game.camera_rig.foot_yaw=game.player.rotation.y;game.camera_rig.snap()
    game.hud.tutorial_time=0;game.hud.show_toast("SURVIVE SAMI PARK")
    s.wave.begin_next()
    for i in s.enemies.models.size():
        var zombie: CharacterBody3D=load("res://scenes/zombie.tscn").instantiate();s.enemies.add_child(zombie);zombie.build(s.enemies,s.enemies.models[i],i);s.enemies.pool.append(zombie)
        zombie.activate(p+forward*6+side*(i-1.5)*1.8,i+1,{"health":100,"damage":25,"speed":1.8});zombie.rotation.y=game.player.rotation.y+PI
        zombie.set_physics_process(false);zombie.animator.advance(.15)
        s.wave.register_spawn()
    for i in 40:await process_frame
    DirAccess.make_dir_recursive_absolute(OUT)
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"/survival-gameplay.png")
    game.hud.open_map();await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUT+"/survival-map.png")
    game.hud.close_map();s.score=1250;s.kills=12;s.config.player.death_slowmo_seconds=0;s.damage_player(1000)
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUT+"/survival-game-over.png")
    paused=false;game.queue_free();await process_frame;await process_frame;quit()
