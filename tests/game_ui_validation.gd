extends SceneTree
var game: Node3D
var hud: Node
var cart: CharacterBody3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:failures.append(message);push_error("FAIL: "+message)
func frames(count: int=4) -> void:
    for i in count:await process_frame
func inside(parent: Control, child: Control) -> bool:
    return parent.get_global_rect().grow(1).encloses(child.get_global_rect())
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    hud=game.get_node("HUD");cart=game.get_node("GolfCart")
    await frames()
    hud.set_paused(true)
    check(paused and hud.pause_overlay.resume_button.has_focus(),"Pause gives keyboard focus to Continue Driving")
    cart.speed=0;cart.throttle_amount=0;hud.gauge._process(1)
    check(hud.gauge.speed_label.text=="0" and hud.gauge.gear_label.text=="N","Stopped cart displays 0 KPH and neutral")
    cart.speed=-3;hud.gauge._process(1)
    check(hud.gauge.speed_label.text=="11" and hud.gauge.gear_label.text=="R","Reverse displays positive actual speed and R")
    cart.speed=103.0/3.6;cart.throttle_amount=.75;hud.gauge._process(1)
    check(hud.gauge.speed_label.text=="103" and hud.gauge.gear_label.text=="3","Forward telemetry updates speed and virtual gear")
    cart.speed=200.0/3.6;cart.throttle_amount=1;hud.gauge._process(1)
    check(hud.gauge.speed_label.text=="200" and hud.gauge.gear_label.text=="5" and hud.gauge.redline,"200 KPH fits the readout and enters the tachometer redline")
    cart.speed=0;cart.throttle_amount=0
    hud.pause_overlay.tabs[2].pressed.emit()
    check(hud.pause_overlay.views[2].visible and not hud.pause_overlay.views[0].visible,"Controls tab opens its bindings screen")
    hud.pause_overlay.tabs[1].pressed.emit();hud.pause_overlay.low_button.pressed.emit()
    check(game.get_node("SamiPark").vegetation_density<.6 and hud.pause_overlay.density_label.text=="LOW","Low-detail button changes real scenery detail")
    hud.pause_overlay.high_button.pressed.emit()
    check(game.get_node("SamiPark").vegetation_density>.6 and hud.pause_overlay.density_label.text=="HIGH","High-detail button restores scenery detail")
    hud.pause_overlay.resume_button.pressed.emit()
    check(not paused and not hud.pause_overlay.visible,"Continue Driving resumes gameplay")
    hud.tutorial_time=0;hud.elapsed=-100;hud._process(20)
    check(hud.driving_hints.modulate.a==0,"Opening driving hints fade out during gameplay")
    hud.show_toast("Recovered to path");hud.set_paused(true)
    var remaining: float=hud.toast_time
    hud._process(1)
    check(hud.toast_time==remaining and hud.toast_plate.visible,"Recovery notification remains available during pause")
    hud.set_paused(false);hud._process(4)
    check(not hud.toast_plate.visible,"Recovery notification clears after resuming")
    hud.set_paused(true)
    for resolution: Vector2i in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(3440,1440)]:
        root.size=resolution;await frames()
        check(inside(hud.root,hud.gauge) and inside(hud.root,hud.map),"HUD instruments fit at "+str(resolution))
        check(inside(hud.pause_overlay,hud.pause_overlay.frame),"Pause menu fits at "+str(resolution))
        hud.open_map();await frames()
        check(inside(hud.full_map,hud.full_map.canvas) and inside(hud.full_map,hud.full_map.side_panel) and not hud.full_map.canvas.get_global_rect().intersects(hud.full_map.side_panel.get_global_rect()),"Map and sidebar fit without overlap at "+str(resolution))
        var buttons_fit:=true
        for child in hud.full_map.zoom_controls.get_children():
            if child is Button:buttons_fit=buttons_fit and inside(hud.full_map.side_panel,child)
        check(buttons_fit and inside(hud.full_map.side_panel,hud.full_map.spawn_button),"Map actions remain inside their panel at "+str(resolution))
        hud.close_map()
    print("UI_RESULT: ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
