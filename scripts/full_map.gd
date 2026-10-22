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
var rendering_suspended: bool = false
var previous_disable_3d: bool = false
var navigation_only: bool=false
const SURVIVAL_LEGEND="Gold boxes: weapons, ammo,\nrepairs and the workshop.\n\nCyan: supply mission."
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP
    theme=GameUI.theme()
    var background:=ColorRect.new();background.color=GameUI.INK;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
    var ribbon:=Control.new();ribbon.set_script(load("res://scripts/game_plate.gd"));ribbon.position=Vector2(28,24);ribbon.size=Vector2(334,61);ribbon.fill=GameUI.LIME;add_child(ribbon)
    GameUI.label(ribbon,"WORLD MAP",Vector2(18,7),GameUI.SIZE_TITLE,GameUI.INK,true)
    GameUI.label(self,"SAMI PARK  /  ERBIL",Vector2(386,42),GameUI.SIZE_SUBHEADING,GameUI.WHITE,true).add_theme_font_override("font",GameUI.caption())
    canvas=Control.new();canvas.set_script(load("res://scripts/map_canvas.gd"));canvas.name="MapCanvas";add_child(canvas);canvas.point_selected.connect(select_point)
    side_panel=PanelContainer.new();side_panel.add_theme_stylebox_override("panel",GameUI.style(Color("172232"),20));add_child(side_panel)
    side_body=Control.new();side_panel.add_child(side_body)
    GameUI.label(side_body,"SET WAYPOINT",Vector2.ZERO,GameUI.SIZE_HEADING,GameUI.WHITE,true)
    GameUI.label(side_body,"CLICK A LOCATION",Vector2(0,40),GameUI.SIZE_LABEL,GameUI.LIME,true)
    destination_label=GameUI.label(side_body,"No waypoint selected.",Vector2(0,80),GameUI.SIZE_BODY,GameUI.WHITE)
    destination_label.size=Vector2(258,114)
    destination_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    spawn_button=GameUI.button(side_body,"SPAWN HERE  >",Vector2(0,217),Vector2(258,54),spawn_selected)
    spawn_button.add_theme_stylebox_override("normal",GameUI.style(GameUI.LIME))
    spawn_button.add_theme_color_override("font_color",GameUI.INK)
    spawn_button.add_theme_color_override("font_focus_color",GameUI.INK)
    spawn_button.disabled=true
    GameUI.label(side_body,"Enter to confirm.\nDouble-click to spawn there.",Vector2(0,284),GameUI.SIZE_BODY-1,GameUI.MUTED)
    zoom_controls=Control.new();side_body.add_child(zoom_controls)
    zoom_label=GameUI.label(zoom_controls,"ZOOM  1.0x",Vector2(0,0),GameUI.SIZE_SUBHEADING-2,GameUI.WHITE,true)
    GameUI.button(zoom_controls,"-",Vector2(0,36),Vector2(125,40),func():canvas.zoom_at(1.0/1.4,canvas.size*.5))
    GameUI.button(zoom_controls,"+",Vector2(133,36),Vector2(125,40),func():canvas.zoom_at(1.4,canvas.size*.5))
    GameUI.button(zoom_controls,"FIT PARK",Vector2(0,87),Vector2(258,42),func():canvas.fit_park())
    GameUI.button(zoom_controls,"LOCATE PLAYER",Vector2(0,140),Vector2(258,42),func():canvas.find_cart())
    close_button=GameUI.button(self,"ESC  BACK",Vector2.ZERO,Vector2(170,46),func():close_requested.emit())
    var credits:=GameUI.label(self,"\u00a9 OpenStreetMap contributors / ODbL 1.0",Vector2.ZERO,GameUI.SIZE_SMALL-1,GameUI.MUTED)
    credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);credits.offset_left=28;credits.offset_top=-34;credits.offset_right=540;credits.offset_bottom=-8
    var guide:=GameUI.label(self,"SCROLL  ZOOM     /     RIGHT DRAG  PAN     /     M  CLOSE",Vector2.ZERO,GameUI.SIZE_SMALL,GameUI.WHITE,true)
    guide.add_theme_font_override("font",GameUI.caption());guide.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    guide.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);guide.offset_left=-540;guide.offset_top=-34;guide.offset_right=-28;guide.offset_bottom=-8
    resized.connect(_layout);side_body.resized.connect(_layout_side)
    visibility_changed.connect(_sync_world_rendering)
    _layout();hide()

func _sync_world_rendering() -> void:
    if is_visible_in_tree():
        if not rendering_suspended:
            previous_disable_3d=get_viewport().disable_3d
            rendering_suspended=true
            get_viewport().disable_3d=true
    elif rendering_suspended:
        get_viewport().disable_3d=previous_disable_3d
        rendering_suspended=false

func _exit_tree() -> void:
    if rendering_suspended:
        get_viewport().disable_3d=previous_disable_3d
        rendering_suspended=false
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
    destination_label.text=SURVIVAL_LEGEND+"\n\nClick the map to set a waypoint." if navigation_only else "No waypoint selected.";destination_label.modulate=GameUI.MUTED
    spawn_button.disabled=true;canvas.panning=false;canvas.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    show();canvas.queue_redraw()
func select_point(point: Vector2, quick_spawn: bool=false) -> void:
    if navigation_only:
        selection={"valid":true,"position":point,"yaw":cart.rotation.y};canvas.selected=selection
        destination_label.text="Waypoint set.\nE %d m  /  N %d m\n\n" % [point.x,-point.y]+SURVIVAL_LEGEND
        canvas.queue_redraw();return
    selection=park.resolve_map_spawn(point,cart.rotation.y,cart.get_rid(),cart.is_in_group("walk_player"))
    canvas.selected=selection;canvas.requested_point=point;spawn_button.disabled=not selection.valid
    destination_label.modulate=GameUI.LIME if selection.valid else GameUI.RED
    if selection.valid:
        var location: Vector2=selection.position
        destination_label.text="Waypoint ready.\nE %d m  /  N %d m" % [location.x,-location.y]
        if point.distance_to(location)>.5:destination_label.text+="\nMoved slightly to clear the scenery."
    else:destination_label.text=selection.reason
    canvas.queue_redraw()
    if quick_spawn:spawn_selected()
func spawn_selected() -> void:
    if navigation_only:return
    if selection.get("valid",false):spawn_requested.emit(selection.position,selection.yaw)
func _process(_delta: float) -> void:
    if visible:zoom_label.text="ZOOM  %.1fx" % canvas.zoom
func _input(event: InputEvent) -> void:
    if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ENTER:
        spawn_selected();get_viewport().set_input_as_handled()
func configure_navigation_only() -> void:
    spawn_button.hide()
    destination_label.size.y=190
    var labels: Array[Node]=side_body.find_children("*","Label",false,false)
    for label: Label in labels:
        if label.text.contains("QUICK SPAWN"):label.text="SURVIVAL / NO FAST TRAVEL"
    destination_label.text=SURVIVAL_LEGEND
