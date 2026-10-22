class_name GameUI
extends RefCounted
const INK = Color("10151e")
const PANEL = Color("1b283a")
const LIME = Color("bef249")
const WHITE = Color("f2f4f7")
const MUTED = Color("9eaabb")
const RED = Color("ff5b4e")
# Typography: three families, each with one job.
#  display (Lilita One): headings, buttons, HUD labels and numbers, weapon names, prompts.
#  body (Nunito Sans):   descriptions, settings help, credits, map place names.
#  shout (Bangers):      rare dramatic moments only: wave banners, HEADSHOT!, game over, titles.
const FONT_DIR:="res://assets/ui/fonts/"
# Type scale, in pixels at the 1440x900 base resolution.
const SIZE_SHOUT:=80
const SIZE_CALLOUT:=30
const SIZE_TITLE:=40
const SIZE_HEADING:=26
const SIZE_SUBHEADING:=20
const SIZE_LABEL:=15
const SIZE_BODY:=16
const SIZE_SMALL:=13
const SIZE_MICRO:=11
# Ink outline for text drawn straight over the 3D scene (matches the comic ink lines).
const OUTLINE:=6
const OUTLINE_COLOR:=Color(.02,.025,.05,.92)
static var fonts: Dictionary={}
static func display() -> Font:return _font("display")
# Slightly spaced-out display face for small uppercase captions ("SCORE", "KILLS").
static func caption() -> Font:return _font("caption")
static func body(weight: int=560) -> Font:return _font("body:%d" % weight)
static func body_bold() -> Font:return body(780)
static func shout() -> Font:return _font("shout")
# Earlier names, kept so every caller reads the same roles.
static func bold() -> Font:return display()
static func regular() -> Font:return body()
static func _font(key: String) -> Font:
    if fonts.has(key):return fonts[key]
    var font: Font
    if key=="display":font=load(FONT_DIR+"LilitaOne-Regular.ttf")
    elif key=="caption":
        var spaced:=FontVariation.new();spaced.base_font=display();spaced.spacing_glyph=1;font=spaced
    elif key=="shout":
        var loud:=FontVariation.new();loud.base_font=load(FONT_DIR+"Bangers-Regular.ttf");loud.spacing_glyph=2;font=loud
    else:
        var weighted:=FontVariation.new();weighted.base_font=load(FONT_DIR+"NunitoSans-Variable.ttf")
        weighted.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):int(key.get_slice(":",1))}
        font=weighted
    fonts[key]=font
    return font
# Text drawn with a CanvasItem: optional ink outline under the fill.
static func draw_text(canvas: CanvasItem, font: Font, point: Vector2, text: String, font_size: int, color: Color, outline: int=0) -> void:
    if outline>0:
        var ink:=OUTLINE_COLOR;ink.a*=color.a
        canvas.draw_string_outline(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,outline,ink)
    canvas.draw_string(font,point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
# 12450 -> "12,450"
static func grouped(value: int) -> String:
    var digits:=str(absi(value));var out:=""
    while digits.length()>3:out=","+digits.right(3)+out;digits=digits.left(digits.length()-3)
    return ("-" if value<0 else "")+digits+out
static func text_width(font: Font, text: String, font_size: int) -> float:
    return font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
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
    result.default_font=body()
    result.default_font_size=SIZE_BODY
    result.set_font("font","Button",display())
    result.set_font_size("font_size","Button",SIZE_SUBHEADING)
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
# heavy: display face (Lilita One); otherwise body text (Nunito Sans).
# outline: ink outline width, for labels that sit straight on the 3D scene.
static func label(parent: Node, text: String, point: Vector2, font_size: int, color: Color=WHITE, heavy: bool=false, outline: int=0) -> Label:
    var node:=Label.new()
    node.text=text
    node.position=point
    node.add_theme_font_override("font",display() if heavy else body())
    node.add_theme_font_size_override("font_size",font_size)
    node.add_theme_color_override("font_color",color)
    if outline>0:
        node.add_theme_constant_override("outline_size",outline)
        node.add_theme_color_override("font_outline_color",OUTLINE_COLOR)
    node.add_theme_color_override("font_shadow_color",Color(0,0,0,.65))
    node.add_theme_constant_override("shadow_offset_y",2 if outline>0 else 1)
    node.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(node)
    return node
# Bangers label for the rare dramatic line (game over, titles), always ink-outlined.
static func shout_label(parent: Node, text: String, point: Vector2, font_size: int, color: Color=WHITE) -> Label:
    var node:=label(parent,text,point,font_size,color,true,maxi(4,font_size/8))
    node.add_theme_font_override("font",shout())
    node.add_theme_constant_override("shadow_offset_x",3);node.add_theme_constant_override("shadow_offset_y",4)
    node.add_theme_color_override("font_shadow_color",Color(0,0,0,.55))
    return node
# World signs and markers: display face with a thick ink outline so they read at night.
static func style_sign(sign: Label3D, outline: int=14) -> Label3D:
    sign.font=display();sign.outline_size=outline;sign.outline_modulate=OUTLINE_COLOR
    return sign
# Station sign: a bold title with a smaller body-font detail line under it. Fades out with
# distance so far-off signs do not clutter the night (the map and HUD mark stations).
static func world_sign(parent: Node3D, title: String, detail: String, point: Vector3, color: Color, fade_distance: float=40.0) -> Label3D:
    var heading:=Label3D.new();heading.text=title;heading.position=point
    style_sign(heading,12);heading.font_size=34;heading.pixel_size=.008;heading.modulate=color
    heading.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    var line:=Label3D.new();line.name="Detail";line.text=detail;line.position=Vector3(0,-.3,0)
    line.font=body_bold();line.outline_size=10;line.outline_modulate=OUTLINE_COLOR
    line.font_size=26;line.pixel_size=.008;line.modulate=color.lerp(WHITE,.45)
    line.billboard=BaseMaterial3D.BILLBOARD_ENABLED;line.visible=detail!=""
    heading.add_child(line)
    for sign: Label3D in [heading,line]:
        sign.visibility_range_end=fade_distance;sign.visibility_range_end_margin=8
        sign.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    parent.add_child(heading)
    return heading
static func set_sign(sign: Label3D, title: String, detail: String="") -> void:
    sign.text=title
    var line: Label3D=sign.get_node_or_null("Detail")
    if line:line.text=detail;line.visible=detail!=""
static func button(parent: Node, text: String, point: Vector2, dimensions: Vector2, action: Callable) -> Button:
    var node:=Button.new()
    node.theme=theme()
    node.text=text
    node.position=point
    node.size=dimensions
    node.pressed.connect(action)
    node.pressed.connect(func():play_ui("ui_click"))
    node.mouse_entered.connect(func():
        if not node.disabled:play_ui("ui_hover"))
    node.focus_entered.connect(func():
        if not node.disabled:play_ui("ui_hover"))
    node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    parent.add_child(node)
    return node
static func audio_manager() -> Node:
    var tree:=Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null("GameAudio") if tree else null
static func play_ui(event: String) -> void:
    var audio:=audio_manager()
    if audio:audio.play_sfx(event)
static func quit_game() -> void:
    var audio:=audio_manager()
    if audio:audio.request_quit()
    else:(Engine.get_main_loop() as SceneTree).quit()
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
    var node:=label(panel,text,Vector2(0,1),SIZE_LABEL,WHITE,true)
    node.size=panel.size
    node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
