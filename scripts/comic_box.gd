extends StyleBox
# Comic panel: flat fill, thick ink border and a hard offset shadow, like a printed comic box.
# Optional halftone dots fade in from one corner. Used by every panel and button through
# GameUI.style(), so draw_style_box() and Control themes get the same look.
var fill: Color=Color(.06,.08,.12,.94)
var ink: Color=Color(.02,.025,.05,1)
var border: float=3.0
var shadow:=Vector2(5,5)
var halftone: bool=false
var halftone_color: Color=Color(1,1,1,.07)
var skew: float=0.0
# Thin paper line inside the ink border (big panels), so dark panels read against the night.
var inner_rule: bool=false
func _draw(to_canvas_item: RID, rect: Rect2) -> void:
    var server:=RenderingServer
    if shadow!=Vector2.ZERO and ink.a>0:
        var dark:=ink;dark.a*=.85
        server.canvas_item_add_polygon(to_canvas_item,_shape(Rect2(rect.position+shadow,rect.size)),PackedColorArray([dark]))
    if fill.a>0:server.canvas_item_add_polygon(to_canvas_item,_shape(rect),PackedColorArray([fill]))
    if halftone:_halftone(to_canvas_item,rect)
    if border>0 and ink.a>0:
        var outline:=_shape(rect.grow(-border*.5));outline.append(outline[0])
        server.canvas_item_add_polyline(to_canvas_item,outline,PackedColorArray([ink]),border,true)
    if inner_rule:
        var rule:=_shape(rect.grow(-border-4));rule.append(rule[0])
        server.canvas_item_add_polyline(to_canvas_item,rule,PackedColorArray([Color(.96,.93,.85,.22*fill.a)]),1.5,true)
func _shape(rect: Rect2) -> PackedVector2Array:
    var lean: float=rect.size.y*skew
    return PackedVector2Array([rect.position+Vector2(lean,0),rect.position+Vector2(rect.size.x,0),rect.end-Vector2(lean,0),rect.position+Vector2(0,rect.size.y)])
# Dots grow towards the bottom-right corner, the classic printed-shading look. The pattern is
# rendered once into a texture and drawn as one image (hundreds of separate circles a frame were
# expensive), anchored to the panel's bottom-right corner and cropped to fit.
const HALFTONE_SIZE:=Vector2i(240,150)
static var halftone_image: ImageTexture
static func halftone_texture() -> ImageTexture:
    if halftone_image:return halftone_image
    var image:=Image.create(HALFTONE_SIZE.x,HALFTONE_SIZE.y,false,Image.FORMAT_LA8)
    var step: float=9.0
    var corner:=Vector2(HALFTONE_SIZE)
    var reach: float=minf(HALFTONE_SIZE.x,HALFTONE_SIZE.y)*.95
    for y in HALFTONE_SIZE.y:
        var row: int=int(floor(y/(step*.86)))
        var cy: float=(row+.5)*step*.86
        var shift: float=step*.5 if row%2==1 else 0.0
        for x in HALFTONE_SIZE.x:
            var cx: float=floor((x-shift)/step)*step+step*.5+shift
            var t: float=1.0-clampf(Vector2(cx,cy).distance_to(corner)/reach,0,1)
            var radius: float=t*step*.4
            var d: float=Vector2(x+.5,y+.5).distance_to(Vector2(cx,cy))
            image.set_pixel(x,y,Color(1,1,1,clampf(radius-d+.5,0,1)))
    halftone_image=ImageTexture.create_from_image(image)
    return halftone_image
func _halftone(item: RID, rect: Rect2) -> void:
    var inner:=rect.grow(-border-1)
    var size:=Vector2(minf(inner.size.x,HALFTONE_SIZE.x),minf(inner.size.y,HALFTONE_SIZE.y))
    var source:=Rect2(Vector2(HALFTONE_SIZE)-size,size)
    RenderingServer.canvas_item_add_texture_rect_region(item,Rect2(inner.end-size,size),halftone_texture().get_rid(),source,halftone_color)
