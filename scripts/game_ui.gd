class_name GameUI
extends RefCounted
const INK = Color("10151e")
const PANEL = Color("1b283a")
const LIME = Color("bef249")
const WHITE = Color("f2f4f7")
const MUTED = Color("9eaabb")
const RED = Color("ff5b4e")
const PAPER = Color("f4ecd8")
const COMIC_YELLOW = Color("ffd23f")
const ComicBox=preload("res://scripts/comic_box.gd")
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
# Comic panel style: fill, thick ink border, hard offset shadow (scripts/comic_box.gd).
static func style(color: Color, margin: float=12, shadow:=Vector2(4,4), halftone: bool=false) -> StyleBox:
    var box:=ComicBox.new()
    box.fill=color;box.shadow=shadow;box.halftone=halftone
    box.ink=Color(OUTLINE_COLOR.r,OUTLINE_COLOR.g,OUTLINE_COLOR.b,1)
    box.content_margin_left=margin
    box.content_margin_right=margin
    box.content_margin_top=8
    box.content_margin_bottom=8
    return box
# Clipped comic plate drawn on any canvas: hard ink shadow, fill, halftone dots, ink border and
# (on dark fills) a thin paper inner rule so the panel reads against the night.
static func draw_plate(canvas: CanvasItem, rect: Rect2, fill: Color, cut: float=12.0, halftone: bool=true, shadow:=Vector2(6,6)) -> void:
    var shape:=func(offset: Vector2, inset: float) -> PackedVector2Array:
        var a: Vector2=rect.position+offset+Vector2(inset,inset);var b: Vector2=rect.end+offset-Vector2(inset,inset)
        var c: float=maxf(cut-inset*.4,0)
        return PackedVector2Array([a,Vector2(b.x-c,a.y),Vector2(b.x,a.y+c),b,Vector2(a.x+c,b.y),Vector2(a.x,b.y-c)])
    var ink:=Color(OUTLINE_COLOR.r,OUTLINE_COLOR.g,OUTLINE_COLOR.b,fill.a)
    if shadow!=Vector2.ZERO:canvas.draw_colored_polygon(shape.call(shadow,0.0),Color(ink.r,ink.g,ink.b,ink.a*.8))
    canvas.draw_colored_polygon(shape.call(Vector2.ZERO,0.0),fill)
    var dark: bool=fill.get_luminance()<.5
    if halftone:
        var dots:=ComicBox.new();dots.fill=Color(0,0,0,0);dots.border=0;dots.shadow=Vector2.ZERO;dots.halftone=true
        dots.halftone_color=Color(1,1,1,.06*fill.a) if dark else Color(0,0,0,.08*fill.a)
        canvas.draw_style_box(dots,rect)
    var outline: PackedVector2Array=shape.call(Vector2.ZERO,1.5);outline.append(outline[0])
    canvas.draw_polyline(outline,ink,3,true)
    if dark:
        var rule: PackedVector2Array=shape.call(Vector2.ZERO,6.0);rule.append(rule[0])
        canvas.draw_polyline(rule,Color(PAPER.r,PAPER.g,PAPER.b,.22*fill.a),1.5,true)
# Large HUD/menu panel: comic box with halftone shading in the corner.
static func panel_style(color: Color, margin: float=12) -> StyleBox:
    var box:=style(color,margin,Vector2(6,6),true)
    box.inner_rule=true
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
    var focus:=style(Color(0,0,0,0),12,Vector2.ZERO)
    focus.ink=WHITE;focus.border=3
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
# Physical signboard: a dark plank on two posts, painted lettering on both faces (a bold
# title and a smaller detail line). The paint is lit by the scene like everything else, so
# signs only read when a lamp, the flashlight or the headlights reach them. The board faces
# the parent's -Z; it fades out beyond fade_distance.
const SIGN_TITLE_SIZE:=34
const SIGN_DETAIL_SIZE:=26
const SIGN_PIXEL:=.0075
static func world_sign(parent: Node3D, title: String, detail: String, point: Vector3, color: Color, fade_distance: float=45.0) -> Node3D:
    var sign:=Node3D.new();sign.name="Signboard";sign.position=point;parent.add_child(sign)
    var wood:=ParkGeometry.material(Color("2c2622"));var post_color:=ParkGeometry.material(Color("1d2124"))
    var board:=ParkGeometry.box(sign,Vector3.ZERO,Vector3(1,1,.06),wood)
    sign.set_meta("board",board);sign.set_meta("color",color)
    for side in [-1.0,1.0]:
        var post:=ParkGeometry.box(sign,Vector3.ZERO,Vector3(.06,1,.06),post_color)
        sign.set_meta("post_left" if side<0 else "post_right",post)
    for face in ["front","back"]:
        var heading:=Label3D.new();style_sign(heading,10);heading.font_size=SIGN_TITLE_SIZE;heading.pixel_size=SIGN_PIXEL
        var line:=Label3D.new();line.font=body_bold();line.outline_size=8;line.outline_modulate=OUTLINE_COLOR
        line.font_size=SIGN_DETAIL_SIZE;line.pixel_size=SIGN_PIXEL
        for paint: Label3D in [heading,line]:
            # Blended paint (drawn after the ink pass, which would otherwise trace and thin the letters).
            # No outline on the dark board: one surface per label keeps it cheap.
            paint.shaded=true;paint.double_sided=false;paint.outline_size=0
            paint.visibility_range_end=fade_distance;paint.visibility_range_end_margin=8
            paint.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
            # Front lettering reads from -Z, back lettering from +Z.
            paint.rotation.y=PI if face=="front" else 0.0
            sign.add_child(paint)
        sign.set_meta(face+"_title",heading);sign.set_meta(face+"_detail",line)
    set_sign(sign,title,detail)
    return sign
static func set_sign(sign: Node3D, title: String, detail: String="") -> void:
    var color: Color=sign.get_meta("color")
    var title_width: float=text_width(display(),title,SIGN_TITLE_SIZE)*SIGN_PIXEL
    var detail_width: float=text_width(body_bold(),detail,SIGN_DETAIL_SIZE)*SIGN_PIXEL if detail!="" else 0.0
    var width: float=maxf(title_width,detail_width)+.34
    var height: float=.66 if detail!="" else .44
    var board: MeshInstance3D=sign.get_meta("board")
    (board.mesh as BoxMesh).size=Vector3(width,height,.06)
    for side in [-1,1]:
        var post: MeshInstance3D=sign.get_meta("post_left" if side<0 else "post_right")
        var post_height: float=sign.position.y-height*.5+.05
        (post.mesh as BoxMesh).size=Vector3(.06,post_height,.06)
        post.position=Vector3(side*(width*.5-.12),-height*.5-post_height*.5+.05,0)
    for face in ["front","back"]:
        var z: float=-.036 if face=="front" else .036
        var heading: Label3D=sign.get_meta(face+"_title");var line: Label3D=sign.get_meta(face+"_detail")
        heading.text=title;heading.modulate=color;heading.position=Vector3(0,.1 if detail!="" else 0.0,z)
        line.text=detail;line.visible=detail!="";line.modulate=color.lerp(WHITE,.5);line.position=Vector3(0,-.16,z)
# Floating labels (zombie types, pickups, beacons) only show up close, fading in.
static func close_up(label: Label3D, distance: float) -> Label3D:
    label.visibility_range_end=distance;label.visibility_range_end_margin=distance*.25
    label.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    return label
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
    # Keycaps read as little printed keys: paper face, ink border, ink shadow.
    var box:=style(PAPER,0,Vector2(2,3))
    box.border=2
    panel.add_theme_stylebox_override("panel",box)
    panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(panel)
    var node:=label(panel,text,Vector2(0,1),SIZE_LABEL,INK,true)
    node.add_theme_color_override("font_shadow_color",Color(0,0,0,0))
    node.size=panel.size
    node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
