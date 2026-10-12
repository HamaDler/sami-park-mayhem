extends CanvasLayer
var cart: CharacterBody3D
var park: Node3D
var root: Control
var speed_label: Label
var status_label: Label
var trip_label: Label
var toast_label: Label
var toast_plate: Control
var pause_overlay: Control
var map: Control
var full_map: Control
var gauge: Control
var area_label: Label
var driving_hints: Control
var map_was_paused: bool = false
var toast_time: float = 0
var elapsed: float = 0
var tutorial_time: float = 0
var area_time: float = 0
var landmarks: Array = []
func _ready() -> void:
    root=Control.new();root.name="DrivingHUD"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.theme=GameUI.theme();add_child(root)
    GameUI.label(root,"SAMI PARK",Vector2(32,22),33,GameUI.WHITE,true)
    var tag:=_plate(root,Vector2(32,66),Vector2(110,23),GameUI.LIME)
    GameUI.label(tag,"FREE DRIVE",Vector2(11,0),16,GameUI.INK,true)
    area_label=GameUI.label(root,"ENGLISH DOOR",Vector2(155,65),17,GameUI.WHITE,true)
    driving_hints=Control.new();driving_hints.position=Vector2(32,105);root.add_child(driving_hints)
    GameUI.keycap(driving_hints,"WASD",Vector2.ZERO,62)
    GameUI.label(driving_hints,"DRIVE",Vector2(74,3),16)
    GameUI.keycap(driving_hints,"SPACE",Vector2(147,0),67)
    GameUI.label(driving_hints,"BRAKE / DRIFT",Vector2(226,3),16)
    gauge=load("res://scenes/speedometer.tscn").instantiate();root.add_child(gauge)
    gauge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    gauge.offset_left=-308;gauge.offset_top=-290;gauge.offset_right=-18;gauge.offset_bottom=-30
    speed_label=gauge.speed_label
    status_label=GameUI.label(gauge,"",Vector2(89,247),18,GameUI.WHITE,true)
    status_label.size=Vector2(183,26);status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    map=Control.new();map.name="Minimap";map.set_script(load("res://scripts/minimap.gd"));root.add_child(map)
    map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    map.offset_left=28;map.offset_top=-302;map.offset_right=282;map.offset_bottom=-42
    trip_label=GameUI.label(root,"0.00 KM",Vector2.ZERO,15,GameUI.MUTED,true)
    trip_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    trip_label.offset_left=32;trip_label.offset_top=-34;trip_label.offset_right=210;trip_label.offset_bottom=-12
    var footer:=Control.new();root.add_child(footer)
    footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    footer.offset_left=-201;footer.offset_top=-52;footer.offset_right=230;footer.offset_bottom=-24
    for entry in [["M","MAP",0,32],["ESC","MENU",122,42],["R","RESET",266,32]]:
        GameUI.keycap(footer,entry[0],Vector2(entry[2],0),entry[3])
        GameUI.label(footer,entry[1],Vector2(entry[2]+entry[3]+11,3),16,GameUI.WHITE,true)
    var credit:=GameUI.label(root,"\u00a9 OpenStreetMap contributors",Vector2.ZERO,11,GameUI.MUTED)
    credit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    credit.offset_left=-110;credit.offset_top=-21;credit.offset_right=180;credit.offset_bottom=-3
    toast_plate=_plate(root,Vector2.ZERO,Vector2(500,51),Color(.04,.06,.09,.90))
    toast_plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    toast_plate.offset_left=-250;toast_plate.offset_top=70;toast_plate.offset_right=250;toast_plate.offset_bottom=121
    toast_plate.accent=GameUI.LIME
    toast_label=GameUI.label(toast_plate,"",Vector2(15,7),24,GameUI.WHITE,true)
    toast_label.size=Vector2(470,36);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    pause_overlay=load("res://scenes/game_menu.tscn").instantiate();root.add_child(pause_overlay)
    pause_overlay.resume_requested.connect(func():set_paused(false))
    pause_overlay.recover_requested.connect(func():cart.recover();set_paused(false))
    pause_overlay.map_requested.connect(open_map)
    pause_overlay.density_requested.connect(_set_density)
    pause_overlay.quit_requested.connect(func():get_tree().quit())
    pause_overlay.hide()
    full_map=load("res://scenes/full_map.tscn").instantiate();root.add_child(full_map)
    full_map.close_requested.connect(close_map);full_map.spawn_requested.connect(_map_spawn)
func _plate(parent: Node, point: Vector2, dimensions: Vector2, color: Color) -> Control:
    var panel:=Control.new();panel.set_script(load("res://scripts/game_plate.gd"));panel.position=point;panel.size=dimensions;panel.fill=color;parent.add_child(panel);return panel
func initialize(vehicle: CharacterBody3D, world: Node3D) -> void:
    cart=vehicle;park=world
    gauge.initialize(vehicle);map.initialize(vehicle,world);full_map.initialize(vehicle,world)
    landmarks=JSON.parse_string(FileAccess.get_file_as_string("res://data/map_labels.json"))
    cart.recovered.connect(show_toast)
    cart.rollover_started.connect(func():show_toast("CART ROLLING   /   R TO RESET"))
    show_toast("ENGLISH DOOR   /   FREE DRIVE")
func show_toast(message: String) -> void:
    toast_label.text=message.to_upper()
    toast_time=3.5
    toast_plate.show()
func set_paused(value: bool) -> void:
    get_tree().paused=value
    if not value and is_instance_valid(full_map):full_map.hide()
    var show_menu:=value and (not is_instance_valid(full_map) or not full_map.visible)
    pause_overlay.visible=show_menu
    if show_menu:pause_overlay.open(park.vegetation_density)
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    get_tree().current_scene.get_node("ChaseCamera").dragging=false
func open_map() -> void:
    if full_map.visible:return
    map_was_paused=get_tree().paused
    get_tree().paused=true;pause_overlay.hide()
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    get_tree().current_scene.get_node("ChaseCamera").dragging=false
    full_map.open()
func close_map() -> void:
    full_map.hide();get_tree().paused=map_was_paused;pause_overlay.visible=map_was_paused
    if map_was_paused:pause_overlay.open(park.vegetation_density)
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
func _map_spawn(point: Vector2, yaw: float) -> void:
    cart.teleport_to(point,yaw);map_was_paused=false;close_map()
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:return
    if event.is_action_pressed("map_toggle"):
        if full_map.visible:close_map()
        else:open_map()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("pause"):
        if full_map.visible:close_map()
        else:set_paused(not get_tree().paused)
        get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
    if cart==null:return
    status_label.text="DRIFT" if cart.drifting else ("REVERSE" if cart.speed<-.1 else ("" if cart.on_path else "OFF ROAD"))
    if cart.rolling:status_label.text="R  /  RESET CART"
    status_label.modulate=GameUI.RED if cart.rolling else (Color("ffbc55") if cart.drifting else GameUI.LIME)
    trip_label.text="%.2f KM EXPLORED" % (cart.distance_m/1000.0)
    if not get_tree().paused:
        tutorial_time+=delta
        driving_hints.modulate.a=clampf((19-tutorial_time)/2,0,1)
        toast_time=maxf(0,toast_time-delta)
        toast_plate.visible=toast_time>0;toast_label.visible=toast_time>0
        toast_plate.modulate.a=minf(1,toast_time*3)
        area_time+=delta
        if area_time>1:
            area_time=0
            var nearest:=130.0
            area_label.text="ERBIL / KURDISTAN"
            for entry: Dictionary in landmarks:
                var distance:=Vector2(cart.position.x,cart.position.z).distance_to(Vector2(entry.position[0],entry.position[1]))
                if distance<nearest:nearest=distance;area_label.text=str(entry.name).to_upper()
        elapsed+=delta
        if elapsed>12:
            elapsed=0
            if Engine.get_frames_per_second()<40 and park.vegetation_density>.6:
                _toggle_density();show_toast("LOW VEGETATION DETAIL ENABLED")
func _set_density(value: float) -> void:
    park.vegetation_density=value;park.set_visible_tree_fraction(value)
    pause_overlay.set_detail(value)
func _toggle_density() -> void:_set_density(.45 if park.vegetation_density>.6 else 1.0)
