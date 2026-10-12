extends Control
@export var fill: Color = Color(.06,.08,.12,.94)
@export var accent: Color = Color(0,0,0,0)
@export var cut: float = 14.0
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _draw() -> void:
    draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x-cut,0),Vector2(size.x,cut),size,Vector2(cut,size.y),Vector2(0,size.y-cut)]),fill)
    if accent.a>0:
        draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(5,0),Vector2(5,size.y),Vector2.ZERO+Vector2(0,size.y-cut)]),accent)
