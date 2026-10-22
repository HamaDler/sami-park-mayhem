extends Control
var vehicle: CharacterBody3D
var speed_label: Label
var gear_label: Label
var rpm: float = 1100
var virtual_gear: int = 1
var redline: bool = false
var thresholds: Array[float] = [0,32,66,105,148,205]
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var italic:=FontVariation.new()
    italic.base_font=GameUI.bold()
    italic.variation_transform=Transform2D(Vector2(1,0),Vector2(-.13,1),Vector2.ZERO)
    speed_label=GameUI.label(self,"0",Vector2(111,130),74,GameUI.WHITE,true)
    speed_label.add_theme_font_override("font",italic)
    speed_label.size=Vector2(151,91)
    speed_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    gear_label=GameUI.label(self,"N",Vector2(131,102),30,GameUI.WHITE,true)
    gear_label.size=Vector2(82,42)
    gear_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    GameUI.label(self,"KPH",Vector2(153,216),GameUI.SIZE_SMALL+1,GameUI.MUTED,true).add_theme_font_override("font",GameUI.caption())
    GameUI.label(self,"RPM x1000",Vector2(66,222),GameUI.SIZE_MICRO,GameUI.MUTED)
func initialize(cart: CharacterBody3D) -> void:vehicle=cart
func _process(delta: float) -> void:
    if vehicle==null:return
    var kmh:=absf(vehicle.speed)*3.6
    speed_label.text=str(roundi(kmh))
    if vehicle.speed<-.3:gear_label.text="R"
    elif kmh<.8 and absf(vehicle.throttle_amount)<.1:gear_label.text="N"
    else:
        while virtual_gear<5 and kmh>thresholds[virtual_gear]+2:virtual_gear+=1
        while virtual_gear>1 and kmh<thresholds[virtual_gear-1]-3:virtual_gear-=1
        gear_label.text=str(virtual_gear)
    var ratio:=clampf((kmh-thresholds[virtual_gear-1])/(thresholds[virtual_gear]-thresholds[virtual_gear-1]),0,1)
    var desired:=1100.0 if kmh<.8 else lerpf(1800,7300,ratio)+absf(vehicle.throttle_amount)*450
    if gear_label.text=="R":desired=lerpf(1100,4400,clampf(kmh/15,0,1))
    rpm=lerpf(rpm,clampf(desired,900,7900),1-exp(-delta*12))
    redline=rpm>=7000
    queue_redraw()
func point_on_dial(value: float, radius: float) -> Vector2:
    return Vector2(139,130)+Vector2(cos(deg_to_rad(135+value/8*225)),sin(deg_to_rad(135+value/8*225)))*radius
func _draw() -> void:
    var center:=Vector2(139,130)
    draw_circle(center,112,Color(.02,.025,.035,.25))
    draw_arc(center,111,deg_to_rad(135),deg_to_rad(360),80,Color(1,1,1,.46),1.3,true)
    draw_arc(center,106,deg_to_rad(135),deg_to_rad(360),80,Color(1,1,1,.16),5,true)
    draw_arc(center,106,deg_to_rad(135+7.0/8*225),TAU,24,GameUI.RED,5,true)
    for tick in 41:
        var value:=tick/5.0
        var major:=tick%5==0
        var color:=GameUI.RED if value>=7 else Color(.94,.96,.99,.85 if major else .42)
        draw_line(point_on_dial(value,major_radius(major)),point_on_dial(value,109),color,2 if major else 1,true)
    for number in 9:
        var point:=point_on_dial(number,85)
        var color:=GameUI.RED if number>=7 else GameUI.WHITE
        draw_string(GameUI.display(),point+Vector2(-4,5),str(number),HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
    var tip:=point_on_dial(rpm/1000,101)
    var direction: Vector2=(tip-center).normalized()
    var normal:=Vector2(-direction.y,direction.x)
    draw_colored_polygon(PackedVector2Array([center-direction*15+normal*2.5,tip,center-direction*15-normal*2.5]),GameUI.RED if redline else GameUI.WHITE)
    draw_circle(center,4,GameUI.WHITE)
func major_radius(major: bool) -> float:return 97 if major else 103
