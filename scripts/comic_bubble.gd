extends Control
# Comic speech bubble: rounded paper balloon, thick ink outline, hard ink shadow and a tail
# pointing down towards the player (the messages are the character talking).
@export var fill: Color = GameUI.PAPER
@export var ink_width: float = 3.0
@export var shadow := Vector2(4,5)
@export var tail_height: float = 16.0
var accent: Color = Color(0,0,0,0)
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func balloon_rect() -> Rect2:
    return Rect2(Vector2.ZERO,Vector2(size.x,size.y-tail_height))
func _outline(offset: Vector2) -> PackedVector2Array:
    var body:=balloon_rect();body.position+=offset
    var radius: float=minf(body.size.y*.5,22.0)
    var points:=PackedVector2Array()
    # Rounded rectangle, clockwise from the top-left corner, with the tail on the bottom edge.
    var corners: Array=[[body.position+Vector2(radius,radius),PI],[Vector2(body.end.x-radius,body.position.y+radius),PI*1.5],[body.end-Vector2(radius,radius),0.0],[Vector2(body.position.x+radius,body.end.y-radius),PI*.5]]
    for i in corners.size():
        var center: Vector2=corners[i][0];var start: float=corners[i][1]
        for step in 7:points.append(center+Vector2.from_angle(start+PI*.5*step/6.0)*radius)
        if i==2:
            # Tail: leaves the bottom edge left of centre and points down-left.
            var base_x: float=body.position.x+body.size.x*.32
            points.append(Vector2(base_x+22,body.end.y))
            points.append(Vector2(base_x-6,body.end.y+tail_height))
            points.append(Vector2(base_x,body.end.y))
    return points
func _draw() -> void:
    var ink: Color=GameUI.OUTLINE_COLOR;ink.a=fill.a
    if shadow!=Vector2.ZERO:draw_colored_polygon(_outline(shadow),Color(ink.r,ink.g,ink.b,ink.a*.75))
    var shape:=_outline(Vector2.ZERO)
    draw_colored_polygon(shape,fill)
    if accent.a>0:draw_rect(Rect2(Vector2(14,5),Vector2(size.x-28,4)),Color(accent.r,accent.g,accent.b,accent.a*fill.a))
    shape.append(shape[0])
    draw_polyline(shape,ink,ink_width,true)
