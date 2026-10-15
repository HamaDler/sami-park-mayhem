extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/survival_settings.json"))
    for path: String in settings.models:
        var model: Node3D=load(path).instantiate();root.add_child(model)
        print("MODEL ",path)
        for animation: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false):print("CLIPS ",animation.get_animation_list())
        for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):print("MESH ",mesh.name," ",mesh.get_aabb()," ",mesh.global_transform)
        model.queue_free()
    await process_frame;quit()
