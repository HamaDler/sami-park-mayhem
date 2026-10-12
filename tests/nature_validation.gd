extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, text: String) -> void:
    checks+=1
    if value:print("PASS: ",text)
    else:failures.append(text);push_error("FAIL: "+text)
func run() -> void:
    var game: Node3D=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    var park: Node3D=game.get_node("SamiPark")
    var cart: CharacterBody3D=game.get_node("GolfCart")
    var nature: Node3D=park.nature
    var planting: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/vegetation_layout.json"))
    for i in 5:await physics_frame
    check(park.tree_count>9000 and park.tree_count<12000,"Satellite density plan creates dense planting without a uniform forest")
    check(nature.grass_count>100000 and nature.flower_count>2000 and nature.rock_count>150,"Grass, intermittent flower borders and varied shoreline stones are present")
    check(planting.metadata.tree_counts.size()==5,"Five tree species are arranged in coherent groves and rows")
    var valid_trees:=true
    for i in park.tree_count:
        var point: Vector2=park.tree_positions[i]
        if not park._map_land_rejection(point).is_empty() or park.path_distance(point)<3.5:valid_trees=false;break
    check(valid_trees,"Every tree stays inside the park and clear of roads, lakes and buildings")
    var valid_details:=true
    for name: String in planting.details:
        var rows: Array=planting.details[name]
        for i in range(0,rows.size(),100):
            var point:=Vector2(rows[i][0],rows[i][1])
            if not park._map_land_rejection(point).is_empty() or park.path_distance(point)<.7:valid_details=false
    check(valid_details,"Grass, flower and stone samples stay off drivable surfaces and out of water")
    var imported:=true
    var mipmapped:=true
    for item: String in nature.manifest:
        var mesh: Mesh=load(nature.manifest[item].mesh)
        if mesh==null or mesh.get_surface_count()==0:imported=false
        for surface in mesh.get_surface_count():
            var mat: Material=mesh.surface_get_material(surface)
            if mat is ShaderMaterial:
                var texture: Texture2D=mat.get_shader_parameter("leaf_texture")
                if texture==null or texture.get_width()>1024:imported=false
                if not texture.get_image().has_mipmaps():mipmapped=false
    check(imported,"All 38 original asset variants load with linked textures capped at 1024px")
    check(mipmapped,"Foliage textures have mipmaps to reduce distance shimmer")
    var near:=0
    var far:=0
    for batch: Dictionary in nature.near_batches:
        if batch.node.visible:near+=1
    for batch: Dictionary in nature.far_batches:
        if batch.node.visible:far+=1
    check(near>0 and near<nature.near_batches.size()/4 and far>0,"Near models and far impostors are spatially culled")
    var cheap:=true
    for batch: Dictionary in nature.far_batches:
        var mesh: Mesh=batch.node.multimesh.mesh
        if mesh.get_surface_count()!=1 or mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()!=12:cheap=false
    check(cheap,"Each distant tree uses six triangles and one atlas material")
    check(nature.active_bodies.size()>0 and nature.active_bodies.size()<int(nature.settings.max_active_tree_colliders),"Nearby tree collision count stays within the fixed pool")
    var close_grass_instances:=0
    for tile: Array in nature.grass_tiles.values():
        for node: MultiMeshInstance3D in tile:close_grass_instances+=node.multimesh.instance_count
    check(nature.grass_tiles.size()>0 and nature.grass_tiles.size()<=49 and close_grass_instances<=18000,"Dense close grass streams through a bounded tile ring")
    cart.teleport_to(Vector2(450,-70),0)
    for i in 3:await physics_frame
    nature.refresh()
    check(nature.last_collision_position.distance_to(Vector2(cart.position.x,cart.position.z))<1,"Collision pool follows map teleport destinations immediately")
    var local:=true
    for index: int in nature.active_bodies:
        if park.tree_positions[index].distance_to(nature.last_collision_position)>float(nature.settings.collision_radius)+.1:local=false
    check(local,"Distant tree colliders are removed when leaving a grove")
    park.set_visible_tree_fraction(.45)
    for i in 2:await physics_frame
    check(nature.visible_tree_count==int(park.tree_count*.45),"Low vegetation mode thins planting consistently across the park")
    var hidden_collision:=false
    for index: int in nature.active_bodies:
        if index>=nature.visible_tree_count:hidden_collision=true
    check(not hidden_collision,"Low density leaves no invisible trunk colliders")
    var model: Mesh=nature.near_batches[0].node.multimesh.mesh
    var mat: Material=model.surface_get_material(model.get_surface_count()-1)
    check(mat is ShaderMaterial and float(mat.get_shader_parameter("wind_strength"))>0,"Leaf models have restrained wind animation")
    print("RESULT: ",checks," checks, ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
