extends Control
var survival: Node3D
var station: Node3D
var rows: Dictionary={}
var balance: Label
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var shade:=ColorRect.new();shade.color=Color(.015,.025,.035,.64);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
    var panel:=Panel.new();add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.offset_left=-320;panel.offset_top=-237;panel.offset_right=320;panel.offset_bottom=237
    panel.add_theme_stylebox_override("panel",GameUI.style(GameUI.INK))
    GameUI.label(panel,"CART WORKSHOP",Vector2(22,12),36,GameUI.LIME,true)
    balance=GameUI.label(panel,"",Vector2(23,57),20,GameUI.WHITE,true)
    GameUI.label(panel,"COMBAT CONTINUES WHILE YOU SHOP",Vector2(23,87),17,GameUI.RED,true)
    var index:=0
    for kind: String in ["bumper","armor","handling"]:
        var y:=123+index*91
        var title:=GameUI.label(panel,"",Vector2(23,y),23,GameUI.WHITE,true)
        var description:=GameUI.label(panel,"",Vector2(23,y+31),16,GameUI.MUTED)
        var button:=GameUI.button(panel,"",Vector2(447,y),Vector2(170,55),func():
            if survival.upgrades.purchase(kind,station):refresh())
        rows[kind]={"title":title,"description":description,"button":button};index+=1
    GameUI.button(panel,"F / ESC  —  BACK",Vector2(23,410),Vector2(594,44),close)
    hide()
func open(session: Node3D, location: Node3D) -> void:
    if not session.upgrades.service_available(location):session.announce("PARK AN UPRIGHT CART WITHIN 16 METRES");return
    survival=session;station=location
    survival.game.player.movement_locked=true;survival.game.player.weapons.set_enabled(false)
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;show();refresh();GameUI.play_ui("ui_open")
func refresh() -> void:
    balance.text="%d IQD  /  %s" % [survival.dinars,station.display_name]
    for kind: String in rows:
        var level: int=survival.upgrades.levels[kind]
        var data: Dictionary=survival.upgrades.settings[kind]
        rows[kind].title.text="%s  %d / 3" % [data.name,level]
        rows[kind].description.text=data.description
        rows[kind].button.text="MAXED" if level>=3 else "%d IQD  >" % survival.upgrades.cost(kind)
        rows[kind].button.disabled=level>=3 or survival.dinars<survival.upgrades.cost(kind)
func close() -> void:
    if not visible:return
    hide();GameUI.play_ui("ui_close")
    if not is_instance_valid(survival):return
    survival.game.player.movement_locked=false
    survival.game.player.weapons.set_enabled(not survival.over and survival.game.player.active)
    survival.game.hud._restore_mouse()
func _input(event: InputEvent) -> void:
    if not visible:return
    if event is InputEventKey and event.echo:return
    if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("map_toggle"):
        close();get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
    if not visible or not survival:return
    if not survival.upgrades.service_available(station):close()
    else:refresh()
