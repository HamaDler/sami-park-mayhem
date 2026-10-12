class_name GameUI
extends RefCounted
const INK = Color("10151e")
const PANEL = Color("1b283a")
const LIME = Color("bef249")
const WHITE = Color("f2f4f7")
const MUTED = Color("9eaabb")
const RED = Color("ff5b4e")
static func bold() -> Font:return load("res://assets/ui/fonts/Rajdhani-Bold.ttf")
static func regular() -> Font:return load("res://assets/ui/fonts/Rajdhani-SemiBold.ttf")
static func style(color: Color, margin: float=12) -> StyleBoxFlat:
    var box:=StyleBoxFlat.new()
    box.bg_color=color
    box.content_margin_left=margin
    box.content_margin_right=margin
    box.content_margin_top=8
    box.content_margin_bottom=8
    return box
static func theme() -> Theme:
    var result:=Theme.new()
    result.default_font=regular()
    result.default_font_size=19
    result.set_font("font","Button",bold())
    result.set_font_size("font_size","Button",23)
    result.set_color("font_color","Button",WHITE)
    result.set_color("font_hover_color","Button",INK)
    result.set_color("font_pressed_color","Button",INK)
    result.set_color("font_focus_color","Button",WHITE)
    result.set_color("font_disabled_color","Button",Color("667284"))
    result.set_stylebox("normal","Button",style(PANEL))
    result.set_stylebox("hover","Button",style(LIME))
    result.set_stylebox("pressed","Button",style(Color("a3d333")))
    result.set_stylebox("disabled","Button",style(Color("172130")))
    var focus:=style(Color(0,0,0,0))
    focus.set_border_width_all(2)
    focus.border_color=WHITE
    result.set_stylebox("focus","Button",focus)
    return result
static func label(parent: Node, text: String, point: Vector2, font_size: int, color: Color=WHITE, heavy: bool=false) -> Label:
    var node:=Label.new()
    node.text=text
    node.position=point
    node.add_theme_font_override("font",bold() if heavy else regular())
    node.add_theme_font_size_override("font_size",font_size)
    node.add_theme_color_override("font_color",color)
    node.add_theme_color_override("font_shadow_color",Color(0,0,0,.65))
    node.add_theme_constant_override("shadow_offset_y",1)
    node.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(node)
    return node
static func button(parent: Node, text: String, point: Vector2, dimensions: Vector2, action: Callable) -> Button:
    var node:=Button.new()
    node.theme=theme()
    node.text=text
    node.position=point
    node.size=dimensions
    node.pressed.connect(action)
    node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    parent.add_child(node)
    return node
static func keycap(parent: Node, text: String, point: Vector2, width: float=32) -> void:
    var panel:=Panel.new()
    panel.position=point
    panel.size=Vector2(width,26)
    var box:=style(Color(.07,.09,.13,.82),0)
    box.set_border_width_all(1)
    box.border_color=Color(.8,.87,.91,.55)
    panel.add_theme_stylebox_override("panel",box)
    panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(panel)
    var node:=label(panel,text,Vector2.ZERO,17,WHITE,true)
    node.size=panel.size
    node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
