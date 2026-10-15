extends SceneTree
var game: Node3D
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:failures.append(message);push_error("FAIL: "+message)
func frames(count: int) -> void:
    for i in count:await physics_frame
func fence_hit(a: Vector3, b: Vector3, fence: Node3D) -> bool:
    var ray:=PhysicsRayQueryParameters3D.create(a,b,1)
    for i in 12:
        var hit:=game.get_world_3d().direct_space_state.intersect_ray(ray)
        if hit.is_empty():return false
        if fence.is_ancestor_of(hit.collider):return true
        var exclusions:=ray.exclude
        exclusions.append(hit.rid);ray.exclude=exclusions
    return false
func run() -> void:
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    game.survival.process_mode=Node.PROCESS_MODE_DISABLED
    var park: Node3D=game.park
    var fence: Node3D=park.perimeter_fence
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var player: CharacterBody3D=game.player
    cart.set_physics_process(false);player.set_physics_process(false)
    await frames(4)
    check(fence.outline.size()==park.boundary.size(),"Fence follows every mapped boundary vertex and closes the loop")
    check(fence.length_m>5000 and fence.sections.size()>200,"Entire park perimeter has permanent solid fence sections")
    var sealed:=true
    var samples:=0
    var sides: Array=[]
    for i in fence.outline.size():
        var a: Vector2=fence.outline[i];var b: Vector2=fence.outline[(i+1)%fence.outline.size()]
        var normal:=Vector2(-(b-a).y,(b-a).x).normalized()
        var count:=maxi(2,ceili(a.distance_to(b)/3))
        for j in range(count+1):
            var p:=a.lerp(b,float(j)/count)
            for y in [1.0,3.8]:
                var from:=Vector3(p.x+normal.x*2,y,p.y+normal.y*2)
                var to:=Vector3(p.x-normal.x*2,y,p.y-normal.y*2)
                sealed=sealed and fence_hit(from,to,fence)
                samples+=1
        if a.distance_to(b)>80:
            var middle: Vector2=(a+b)*.5
            var inward:=normal if park._inside_water_polygon(middle+normal*6,park.boundary) else -normal
            sides.append({"middle":middle,"inward":inward})
    check(sealed,"All %d perimeter rays, including corners and panel joints, hit solid fence" % samples)
    var max_length:=true
    for body: StaticBody3D in fence.sections:
        max_length=max_length and body.get_child(0).shape.size.x<25 and body.collision_layer==1
    check(max_length,"Fence sections use the shared world collision layer and navigation-sized obstacles")
    var start: Vector2=Vector2(park.layout.spawn.position[0],park.layout.spawn.position[1])
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=BoxShape3D.new();query.shape.size=Vector3(3,2,4)
    query.transform=Transform3D(Basis.IDENTITY,Vector3(start.x,1.2,start.y));query.collision_mask=1
    check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"English Door spawn remains clear of fence and scenery")
    var recoveries: Array[String]=[]
    cart.recovered.connect(func(reason: String):
        if reason!="Moved to your map destination":recoveries.append(reason))
    player.recovered.connect(func(reason: String):recoveries.append(reason))
    var safe_cart:=true;var safe_jump:=true;var collisions:=0
    # Sweep the real cart and walking capsule toward long perimeter edges around the park.
    for side: Dictionary in sides:
        var inward: Vector2=side.inward
        var p: Vector2=side.middle+inward*7
        if not park._map_land_rejection(p).is_empty():continue
        var heading:=Vector3(-inward.x,0,-inward.y)
        cart.teleport_to(p,atan2(inward.x,inward.y))
        cart.set_control_enabled(true)
        cart.speed=200.0/3.6;cart.travel_yaw=cart.rotation.y
        player.teleport_to(start+Vector2(3,3),0)
        Input.action_press("accelerate")
        await frames(1)
        var hit_fence:=false
        for tick in 16:
            cart._physics_process(1.0/60)
            for contact in cart.get_slide_collision_count():
                hit_fence=hit_fence or fence.is_ancestor_of(cart.get_slide_collision(contact).get_collider())
            safe_cart=safe_cart and park._inside_water_polygon(Vector2(cart.position.x,cart.position.z),park.boundary)
            await physics_frame
        if hit_fence:collisions+=1
        if not hit_fence:print("CART APPROACH: ",side.middle," ended at ",cart.position," world_wall=",cart.is_on_wall()," speed=",cart.speed)
        # Existing entrance pillars/buildings can stop an approach before the fence.
        safe_cart=safe_cart and (hit_fence or cart.is_on_wall())
        Input.action_release("accelerate");cart.set_control_enabled(false)
        cart.teleport_to(start,0)
        player.teleport_to(side.middle+inward*2,0)
        player.velocity=heading*7+Vector3.UP*float(player.settings.jump_velocity)
        var jumped_into_fence:=false
        for tick in 48:
            player.velocity.x=heading.x*7;player.velocity.z=heading.z*7
            player.velocity.y-=float(player.settings.gravity)/60
            player.move_and_slide()
            for contact in player.get_slide_collision_count():
                jumped_into_fence=jumped_into_fence or fence.is_ancestor_of(player.get_slide_collision(contact).get_collider())
            safe_jump=safe_jump and park._inside_water_polygon(Vector2(player.position.x,player.position.z),park.boundary)
            await physics_frame
        safe_jump=safe_jump and jumped_into_fence
    check(safe_cart and collisions>=4,"Actual cart at 200 km/h stays inside against %d perimeter edges" % collisions)
    check(safe_jump,"Running and jumping into the fence cannot leave the park")
    check(recoveries.is_empty(),"Boundary impacts and jump attempts do not trigger environmental respawn")
    var rollover_site: Dictionary=sides[0]
    var middle: Vector2=rollover_site.middle;var inward: Vector2=rollover_site.inward
    var rolling: RigidBody3D=load("res://scenes/rollover_body.tscn").instantiate()
    game.add_child(rolling)
    rolling.global_position=Vector3(middle.x+inward.x*8,.3,middle.y+inward.y*8)
    rolling.linear_velocity=Vector3(-inward.x*200/3.6,2,-inward.y*200/3.6)
    rolling.angular_velocity=Vector3(1,0,5)
    var stayed_inside:=true
    for i in 75:
        await physics_frame
        stayed_inside=stayed_inside and park._inside_water_polygon(Vector2(rolling.position.x,rolling.position.z),park.boundary)
    check(stayed_inside,"Physics rollover body at 200 km/h is contained by the fence")
    rolling.queue_free()
    var navigation: Node=game.survival.enemies.navigation
    var blocked:=0
    for side: Dictionary in sides:
        if not navigation.walkable(side.middle):blocked+=1
    check(blocked==sides.size(),"Survival navigation respects the new perimeter fence")
    cart.teleport_to(start,0);player.teleport_to(start+Vector2(0,3.4),0)
    if DisplayServer.get_name()!="headless":
        var camera:=Camera3D.new();game.add_child(camera)
        camera.global_position=Vector3(start.x+20,13,start.y+21)
        camera.look_at(Vector3(start.x-5,1.8,start.y-2));camera.current=true
        await frames(12);await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs/perimeter-fence.png")
    var audio: Node=GameUI.audio_manager()
    if audio:audio.stop_all()
    game.queue_free();await frames(5)
    print("PERIMETER RESULT: ",checks," checks; ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
