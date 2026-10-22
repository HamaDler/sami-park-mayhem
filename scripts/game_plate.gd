extends Control
@export var fill: Color = Color(.06,.08,.12,.94)
@export var accent: Color = Color(0,0,0,0)
@export var cut: float = 14.0
# Comic finish: ink outline and a hard offset shadow; halftone dots on big panels.
@export var ink_width: float = 3.0
@export var shadow := Vector2(5,5)
@export var halftone: bool = false
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _draw() -> void:
    GameUI.draw_plate(self,Rect2(Vector2.ZERO,size),fill,cut,halftone,shadow)
    if accent.a>0:
        draw_colored_polygon(PackedVector2Array([Vector2(3,3),Vector2(9,3),Vector2(9,size.y-3),Vector2(3,size.y-cut)]),accent)
