extends SceneTree
# Minimal scene: the combat effects node, a camera and a grey backdrop. Used to inspect the
# blood sprites without the park. godot --path . --script res://tests/blood_isolated_capture.gd -- <out>
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
    for i in count:await process_frame
func run() -> void:
    var out: String=OS.get_cmdline_user_args()[0]
    var world:=Node3D.new();root.add_child(world)
    var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.62,.66,.6);world.add_child(env)
    var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,30,0);world.add_child(light)
    var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,20);floor_mesh.mesh=plane;world.add_child(floor_mesh)
    var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.1,20);shape.shape=box;body.position.y=-.05;body.add_child(shape);world.add_child(body)
    var cam:=Camera3D.new();world.add_child(cam);cam.position=Vector3(1.2,1.4,2.2);cam.look_at(Vector3(0,1.1,0));cam.current=true;cam.fov=50
    var effects: Node3D=load("res://scripts/combat_effects.gd").new();world.add_child(effects)
    await frames(3)
    # Bullet travels away from the camera (-Z), so the mist puffs back toward the viewer.
    effects.blood_burst(Vector3(0,1.2,0),Vector3(0,0,-1),false)
    for i in [2,6,12]:
        await frames(i if i==2 else 4)
        await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/iso_body_%d.png" % i)
    await frames(30)
    effects.blood_burst(Vector3(0,1.2,0),Vector3(0,0,-1),true);effects.blood_splat(Vector3(0,0,0),1.4)
    for i in [2,6,12]:
        await frames(i if i==2 else 4)
        await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/iso_head_%d.png" % i)
    await frames(60)
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/iso_splat.png")
    quit()
