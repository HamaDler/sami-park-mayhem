extends SceneTree
# Renders the first-person arms: each weapon at the hip and aimed, reload stages, the melee
# shove, the sniper bolt, a weapon rising after a switch, and an outside view of the arm pose.
# Run in the actual renderer (no --headless). Images go to $CAPTURE_DIR or user://arms_captures.
var game: Node3D
var folder: String
var player: CharacterBody3D
var rig: Node3D
var view: Node3D
func _initialize() -> void:call_deferred("capture")
func frames(count: int) -> void:
    for i in count:await process_frame
func shot(name: String) -> void:
    await frames(6);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder.path_join(name+".png"))
    print("CAPTURED ",name)
func equip(slot: int) -> void:
    player.weapons.select_weapon(slot);player.weapons.raise_time=0;await frames(12)
func freeze(value: bool) -> void:
    player.weapons.set_physics_process(not value);player.set_physics_process(not value)
func capture() -> void:
    folder=OS.get_environment("CAPTURE_DIR")
    if folder=="":folder=ProjectSettings.globalize_path("user://arms_captures")
    DirAccess.make_dir_recursive_absolute(folder)
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    game.survival.process_mode=Node.PROCESS_MODE_DISABLED
    player=game.player;rig=game.camera_rig;view=rig.viewmodel
    rig.set_process_unhandled_input(false)
    game.hud.visible=false
    player.weapons.grant_weapon(2,0);player.weapons.grant_weapon(3,0)
    await create_timer(1.0).timeout
    rig.foot_yaw=player.rotation.y+PI*.5;rig.pitch=-.05
    for slot in range(1,4):
        await equip(slot)
        await shot("%d-slot%d-hip" % [slot*10,slot])
        Input.action_press("aim");await create_timer(.4).timeout
        await shot("%d-slot%d-aim" % [slot*10+1,slot])
        Input.action_release("aim");await create_timer(.35).timeout
    await equip(2)
    freeze(true)
    player.weapons.reload_time=1.0
    for stage in [.1,.3,.5,.66,.85]:
        player.avatar.reload_progress=stage
        await shot("40-reload-%02d" % int(stage*100))
    player.weapons.reload_time=0;player.avatar.reload_progress=0
    for stage in [.3,.45]:
        player.melee_time=float(player.settings.melee.duration)*(1-stage)
        await shot("50-melee-%02d" % int(stage*100))
    player.melee_time=0
    player.weapons.raise_time=player.weapons.RAISE_SECONDS*.5
    await shot("60-switch-rising")
    player.weapons.raise_time=0
    freeze(false)
    await equip(3)
    for stage in [.3,.5]:
        for i in 8:
            view.bolt_time=view.BOLT_START+view.BOLT_SECONDS*stage;view.bolt_ejected=true;await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(folder.path_join("70-bolt-%02d.png" % int(stage*100)))
        print("CAPTURED bolt ",stage)
    view.bolt_time=-1
    await equip(2)
    # Automatic fire: brass casings fly out to the right.
    player.weapons.infinite_ammo=true;player.weapons.spread_enabled=false
    Input.action_press("fire");await create_timer(.45).timeout
    await shot("75-rifle-casings")
    Input.action_release("fire");await create_timer(.3).timeout
    var flying: int=0
    for casing in view.casings:flying+=1 if casing.visible else 0
    print("CASINGS_VISIBLE ",flying)
    # Outside view of the arms to check the pose.
    var outside:=Camera3D.new();game.add_child(outside);outside.fov=45;outside.near=.02
    var basis: Basis=rig.camera.global_basis
    outside.global_position=rig.camera.global_position+basis.x*.85+basis.y*.1-basis.z*.25
    outside.look_at(rig.camera.global_position-basis.z*.3-basis.y*.15);outside.current=true
    await shot("80-outside-rifle")
    rig.camera.current=true;await equip(1)
    outside.current=true;await shot("81-outside-pistol")
    rig.camera.current=true
    print("ARMS_CAPTURE_COMPLETE")
    quit()
