extends Control
signal resume_requested
signal recover_requested
signal map_requested
signal density_requested(value: float)
signal quit_requested
var frame: Control
var views: Array[Control] = []
var tabs: Array[Button] = []
var resume_button: Button
var recover_button: Button
var description_label: Label
var header_context: Label
var density_label: Label
var high_button: Button
var low_button: Button
var current_tab: int = 0
func _ready() -> void:
    theme=GameUI.theme()
    var shade:=ColorRect.new()
    shade.color=Color(.01,.02,.04,.60)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    frame=Control.new();frame.size=Vector2(760,578);add_child(frame)
    var header:=_plate(frame,Vector2.ZERO,Vector2(760,66),GameUI.LIME)
    GameUI.label(header,"PAUSED",Vector2(24,7),44,GameUI.INK,true)
    header_context=GameUI.label(header,"SAMI PARK  /  FREE DRIVE",Vector2(432,26),19,GameUI.INK,true)
    _plate(frame,Vector2(0,70),Vector2(760,448),Color(.05,.07,.11,.96))
    for index in 4:
        var index_copy:=index
        var button:=GameUI.button(frame,["DRIVE","OPTIONS","AUDIO","CONTROLS"][index],Vector2(18,90+index*58),Vector2(168,48),func():show_tab(index_copy))
        tabs.append(button)
        var view: Control=load("res://scenes/audio_options.tscn").instantiate() if index==2 else Control.new()
        view.position=Vector2(216,92);view.size=Vector2(514,392);frame.add_child(view);views.append(view)
    GameUI.label(views[0],"BACK TO THE PARK",Vector2.ZERO,29,GameUI.WHITE,true)
    description_label=GameUI.label(views[0],"DRIVE / EXPLORE SAMI PARK",Vector2(0,39),15,GameUI.MUTED)
    resume_button=GameUI.button(views[0],"CONTINUE DRIVING   >",Vector2(0,86),Vector2(500,58),func():resume_requested.emit())
    resume_button.add_theme_stylebox_override("normal",GameUI.style(GameUI.LIME))
    resume_button.add_theme_color_override("font_color",GameUI.INK)
    resume_button.add_theme_color_override("font_focus_color",GameUI.INK)
    GameUI.button(views[0],"WORLD MAP",Vector2(0,158),Vector2(500,50),func():map_requested.emit())
    recover_button=GameUI.button(views[0],"RESET CART",Vector2(0,222),Vector2(500,50),func():recover_requested.emit())
    GameUI.button(views[0],"QUIT GAME",Vector2(0,286),Vector2(500,50),func():quit_requested.emit())
    GameUI.label(views[1],"DISPLAY / CAMERA",Vector2.ZERO,29,GameUI.WHITE,true)
    _row(views[1],"VEGETATION DETAIL",62,GameUI.PANEL)
    density_label=GameUI.label(views[1],"HIGH",Vector2(370,74),20,GameUI.LIME,true)
    high_button=GameUI.button(views[1],"HIGH",Vector2(264,128),Vector2(110,43),func():density_requested.emit(1.0))
    low_button=GameUI.button(views[1],"LOW",Vector2(386,128),Vector2(110,43),func():density_requested.emit(.45))
    _row(views[1],"CAMERA",198,GameUI.PANEL)
    GameUI.label(views[1],"FIRST PERSON",Vector2(330,210),20,GameUI.LIME,true)
    GameUI.label(views[1],"MOUSE LOOKS AROUND ON FOOT AND IN THE CART",Vector2(12,258),19,GameUI.MUTED)
    GameUI.label(views[1],"Lower detail reduces trees and close grass.",Vector2(12,318),17,GameUI.MUTED)
    GameUI.label(views[3],"KEYBOARD / MOUSE",Vector2.ZERO,29,GameUI.WHITE,true)
    var control_names: Array[String]=["MOVE / DRIVE","LOOK / STEER","ENTER / EXIT VEHICLE","JUMP / HANDBRAKE","WEAPON SLOTS","AIM / FIRE","RELOAD / RECOVER","WORLD MAP","FLASHLIGHT / LIGHTS"]
    var bindings: Array[String]=["WASD / ARROWS","MOUSE / A + D","F","SPACE   |   SHIFT RUN","1 PISTOL / 2 RIFLE / 3 SNIPER","RIGHT / LEFT MOUSE","R","M","T"]
    for index in control_names.size():
        var y:=58+index*40
        _row(views[3],control_names[index],y,GameUI.PANEL if index%2==0 else Color("141c28"),36)
        GameUI.label(views[3],bindings[index],Vector2(228,y+7),15,GameUI.LIME,true)
    GameUI.keycap(frame,"ESC",Vector2(18,536),46)
    GameUI.label(frame,"BACK TO GAME",Vector2(76,538),17,GameUI.WHITE,true)
    GameUI.label(frame,"Cart: Daniel Zhabotinsky / CC BY 4.0",Vector2(216,534),13,GameUI.MUTED)
    GameUI.label(frame,"Character/nature/weapons: Quaternius / CC0  |  Map: OSM / ODbL",Vector2(216,554),13,GameUI.MUTED)
    resized.connect(_layout)
    _layout();show_tab(0)
func _plate(parent: Node, point: Vector2, dimensions: Vector2, color: Color) -> Control:
    var panel:=Control.new();panel.set_script(load("res://scripts/game_plate.gd"));panel.position=point;panel.size=dimensions;panel.fill=color;parent.add_child(panel);return panel
func _row(parent: Node, text: String, y: float, color: Color, height: float=43) -> void:
    _plate(parent,Vector2(0,y),Vector2(500,height),color)
    GameUI.label(parent,text,Vector2(12,y+8),17,GameUI.WHITE,true)
func _layout() -> void:
    if frame:frame.position=(size-Vector2(760,578))*.5
func show_tab(index: int) -> void:
    current_tab=index
    for i in views.size():
        views[i].visible=i==index
        tabs[i].add_theme_stylebox_override("normal",GameUI.style(GameUI.LIME if i==index else GameUI.PANEL))
        tabs[i].add_theme_color_override("font_color",GameUI.INK if i==index else GameUI.WHITE)
        tabs[i].add_theme_color_override("font_focus_color",GameUI.INK if i==index else GameUI.WHITE)
func open(detail: float) -> void:
    set_detail(detail)
    show_tab(0)
    show()
    resume_button.grab_focus()
func set_detail(detail: float) -> void:
    density_label.text="HIGH" if detail>.6 else "LOW"
    for button in [high_button,low_button]:
        var selected: bool=(button==high_button)==(detail>.6)
        button.add_theme_stylebox_override("normal",GameUI.style(GameUI.LIME if selected else GameUI.PANEL))
        button.add_theme_color_override("font_color",GameUI.INK if selected else GameUI.WHITE)
        button.add_theme_color_override("font_focus_color",GameUI.INK if selected else GameUI.WHITE)

func set_context(driving: bool) -> void:
    header_context.text="SAMI PARK  /  SURVIVAL"
    resume_button.text="CONTINUE DRIVING   >" if driving else "CONTINUE WALKING   >"
    recover_button.text="RESTART RUN"
    tabs[0].text="DRIVE" if driving else "ON FOOT"
    description_label.text="SURVIVE / EARN DINARS / FIND STRONGER WEAPONS"
