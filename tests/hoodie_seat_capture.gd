extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
    var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var cart: CharacterBody3D=game.get_node("GolfCart")
    game.get_node("HUD").hide()
    var camera:=Camera3D.new();game.add_child(camera);camera.fov=42
    camera.global_position=cart.to_global(Vector3(-2.6,1.8,-3.5))
    camera.look_at(cart.to_global(Vector3(-.20,1.08,0)));camera.current=true
    await create_timer(.5).timeout
    var driver: Node3D=cart.get_node("Visual/SeatedDriver")
    for name in ["Body","Head","UpperLeg.L","LowerLeg.L","Foot.L","Wrist.L","Wrist.R"]:print("SEAT_BONE ",name," ",cart.to_local(driver.bone_world(name).origin))
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/hoodie-seat.png")
    quit()
