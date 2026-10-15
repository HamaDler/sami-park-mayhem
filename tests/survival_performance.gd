extends SceneTree
var game: Node3D
var reports: Array=[]
const OUT: String="C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs"
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
    for i in count:await physics_frame
func run() -> void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames(5)
    var s: Node3D=game.survival;s.enemies.set_physics_process(false)
    s.config.player.max_health=1000000;s.health=1000000
    game.hud.elapsed=-10000
    game.player.teleport_to(Vector2(195.8739,-39.85362),-1.889);game.camera_rig.foot_yaw=-1.889;game.camera_rig.snap()
    s.wave.begin_next();s.wave.total=1000;s.wave.active_limit=80
    s.missions.start_mission(1)
    for count in [0,40,80]:
        var attempts: int=0
        while s.enemies.living().size()<count and attempts<600:
            s.enemies.spawn_one();attempts+=1;await frames(1)
        for zombie in s.enemies.living():zombie.alerted=true
        var settle:=Time.get_ticks_msec()
        while Time.get_ticks_msec()-settle<2000:await process_frame
        var timings: Array[float]=[];var start:=Time.get_ticks_usec();var last:=start
        while Time.get_ticks_usec()-start<8000000:
            await process_frame
            var now:=Time.get_ticks_usec();timings.append(float(now-last)/1000);last=now
        timings.sort()
        var sum: float=0
        for value in timings:sum+=value
        var report: Dictionary={"requested_zombies":count,"living_zombies":s.enemies.living().size(),"average_fps":1000/(sum/timings.size()),"p95_frame_ms":timings[int(timings.size()*.95)],"memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"vegetation_density":game.park.vegetation_density,"frames":timings.size()}
        var kinds: Dictionary={}
        for zombie in s.enemies.living():kinds[zombie.archetype]=int(kinds.get(zombie.archetype,0))+1
        report.archetypes=kinds;report.supply_mission_active=s.missions.active
        reports.append(report);print("BENCHMARK ",JSON.stringify(report))
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(OUT+"/survival-performance-%d.png" % count)
    var file:=FileAccess.open(OUT+"/survival-performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(reports,"  "));file.close()
    game.queue_free();await process_frame;await process_frame;quit()
