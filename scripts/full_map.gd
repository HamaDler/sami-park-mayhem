extends Control
signal close_requested
signal spawn_requested(point: Vector2, yaw: float)
var cart: CharacterBody3D
var park: Node3D
var canvas: Control
var destination_label: Label
var spawn_button: Button
var zoom_label: Label
var side_panel: PanelContainer
var close_button: Button
var side_body: Control
var zoom_controls: Control
var selection: Dictionary = {}
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    theme=GameUI.theme()
    var background:=ColorRect.new();background.color=GameUI.INK;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
    var ribbon:=Control.new();ribbon.set_script(load("res://scripts/game_plate.gd"));ribbon.position=Vector2(28,24);ribbon.size=Vector2(334,61);ribbon.fill=GameUI.LIME;add_child(ribbon)
    GameUI.label(ribbon,"WORLD MAP",Vector2(18,3),42,GameUI.INK,true)
    GameUI.label(self,"SAMI PARK  /  ERBIL",Vector2(386,42),23,GameUI.WHITE,true)
    canvas=Control.new();canvas.set_script(load("res://scripts/map_canvas.gd"));canvas.name="MapCanvas";add_child(canvas);canvas.point_selected.connect(select_point)
    side_panel=PanelContainer.new();side_panel.add_theme_stylebox_override("panel",GameUI.style(Color("172232"),20));add_child(side_panel)
    side_body=Control.new();side_panel.add_child(side_body)
    GameUI.label(side_body,"SET WAYPOINT",Vector2.ZERO,30,GameUI.WHITE,true)
    GameUI.label(side_body,"CLICK A LOCATION",Vector2(0,42),16,GameUI.LIME,true)
    destination_label=GameUI.label(side_body,"NO WAYPOINT SELECTED",Vector2(0,83),20,GameUI.WHITE,true)
    destination_label.size=Vector2(258,114)
    destination_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    spawn_button=GameUI.button(side_body,"SPAWN HERE  >",Vector2(0,217),Vector2(258,54),spawn_selected)
    spawn_button.add_theme_stylebox_override("normal",GameUI.style(GameUI.LIME))
    spawn_button.add_theme_color_override("font_color",GameUI.INK)
    spawn_button.add_theme_color_override("font_focus_color",GameUI.INK)
    spawn_button.disabled=true
    GameUI.label(side_body,"ENTER  CONFIRM\nDOUBLE CLICK  QUICK SPAWN",Vector2(0,286),15,GameUI.MUTED)
    zoom_controls=Control.new();side_body.add_child(zoom_controls)
    zoom_label=GameUI.label(zoom_controls,"ZOOM  1.0x",Vector2(0,0),20,GameUI.WHITE,true)
    GameUI.button(zoom_controls,"-",Vector2(0,36),Vector2(125,40),func():canvas.zoom_at(1.0/1.4,canvas.size*.5))
    GameUI.button(zoom_controls,"+",Vector2(133,36),Vector2(125,40),func():canvas.zoom_at(1.4,canvas.size*.5))
    GameUI.button(zoom_controls,"FIT PARK",Vector2(0,87),Vector2(258,42),func():canvas.fit_park())
    GameUI.button(zoom_controls,"LOCATE PLAYER",Vector2(0,140),Vector2(258,42),func():canvas.find_cart())
    close_button=GameUI.button(self,"ESC  BACK",Vector2.ZERO,Vector2(170,46),func():close_requested.emit())
    var credits:=GameUI.label(self,"\u00a9 OpenStreetMap contributors / ODbL 1.0",Vector2.ZERO,12,GameUI.MUTED)
    credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);credits.offset_left=28;credits.offset_top=-34;credits.offset_right=540;credits.offset_bottom=-8
    var guide:=GameUI.label(self,"SCROLL  ZOOM     /     RIGHT DRAG  PAN     /     M  CLOSE",Vector2.ZERO,14,GameUI.WHITE,true)
    guide.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);guide.offset_left=-540;guide.offset_top=-34;guide.offset_right=-28;guide.offset_bottom=-8
    resized.connect(_layout);side_body.resized.connect(_layout_side)
    _layout();hide()
func _layout() -> void:
    if not is_instance_valid(canvas):return
    canvas.position=Vector2(28,110)
    canvas.size=Vector2(maxf(300,size.x-382),maxf(300,size.y-164))
    side_panel.position=Vector2(size.x-326,110)
    side_panel.size=Vector2(298,maxf(300,size.y-164))
    close_button.position=Vector2(size.x-198,32)
    _layout_side()
func _layout_side() -> void:
    if is_instance_valid(zoom_controls):zoom_controls.position=Vector2(0,maxf(350,side_body.size.y-188))
func initialize(vehicle: CharacterBody3D, world: Node3D) -> void:
    cart=vehicle;park=world;canvas.initialize(vehicle,world)
func open() -> void:
    selection.clear();canvas.selected.clear()
    destination_label.text="NO WAYPOINT SELECTED";destination_label.modulate=GameUI.MUTED
    spawn_button.disabled=true;canvas.panning=false;canvas.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    show();canvas.queue_redraw()
func select_point(point: Vector2, quick_spawn: bool=false) -> void:
    selection=park.resolve_map_spawn(point,cart.rotation.y,cart.get_rid(),cart.is_in_group("walk_player"))
    canvas.selected=selection;canvas.requested_point=point;spawn_button.disabled=not selection.valid
    destination_label.modulate=GameUI.LIME if selection.valid else GameUI.RED
    if selection.valid:
        var location: Vector2=selection.position
        destination_label.text="WAYPOINT READY\nE %d m  /  N %d m" % [location.x,-location.y]
        if point.distance_to(location)>.5:destination_label.text+="\nSCENERY CLEARANCE ADJUSTED"
    else:destination_label.text=selection.reason.to_upper()
    canvas.queue_redraw()
    if quick_spawn:spawn_selected()
func spawn_selected() -> void:
    if selection.get("valid",false):spawn_requested.emit(selection.position,selection.yaw)
func _process(_delta: float) -> void:
    if visible:zoom_label.text="ZOOM  %.1fx" % canvas.zoom
func _input(event: InputEvent) -> void:
    if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ENTER:
        spawn_selected();get_viewport().set_input_as_handled()
