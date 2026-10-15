extends Control
var player: CharacterBody3D
var game: Node3D
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
    if player==null or game==null or not player.active:return
    var weapons: Node3D=player.weapons
    var center:=size*.5
    if not get_tree().paused:
        if weapons.aiming and weapons.selected_slot==3:
            var radius:=minf(size.x,size.y)*.34
            var outside:=size.length()
            for i in 96:
                var a:=Vector2.from_angle(TAU*i/96.0)
                var b:=Vector2.from_angle(TAU*(i+1)/96.0)
                draw_colored_polygon(PackedVector2Array([center+a*radius,center+a*outside,center+b*outside,center+b*radius]),Color(0,0,0,.97))
            draw_arc(center,radius,0,TAU,96,Color(0,0,0,.9),5,true)
            draw_line(center-Vector2(radius,0),center+Vector2(radius,0),Color(0,0,0,.9),1.5,true)
            draw_line(center-Vector2(0,radius),center+Vector2(0,radius),Color(0,0,0,.9),1.5,true)
            for i in range(-3,4):
                if i!=0:draw_line(center+Vector2(i*25,-4),center+Vector2(i*25,4),Color(0,0,0,.9),1,true)
        else:
            var gap:=4 if weapons.aiming else 8
            for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
                draw_line(center+direction*gap,center+direction*(gap+7),Color(0,0,0,.7),3,true)
                draw_line(center+direction*gap,center+direction*(gap+7),GameUI.WHITE,1.5,true)
    var point:=Vector2(size.x-360,size.y-174)
    var dimensions:=Vector2(332,134)
    draw_colored_polygon(PackedVector2Array([point,point+Vector2(320,0),point+Vector2(332,12),point+dimensions,point+Vector2(12,134),point+Vector2(0,122)]),Color(.025,.04,.065,.9))
    draw_line(point,point+Vector2(320,0),GameUI.LIME,3,true)
    var title: String=str(weapons.current().name)
    if weapons.survival_enabled:title+="  /  T"+str(int(weapons.tiers[weapons.selected_slot])+1)
    draw_string(GameUI.bold(),point+Vector2(15,32),title,HORIZONTAL_ALIGNMENT_LEFT,-1,23,GameUI.WHITE)
    var ammo:=str(weapons.rounds[weapons.selected_slot])
    if weapons.infinite_ammo:ammo="∞"
    draw_string(GameUI.bold(),point+Vector2(17,87),ammo,HORIZONTAL_ALIGNMENT_LEFT,-1,51,GameUI.WHITE)
    draw_string(GameUI.regular(),point+Vector2(85,82),"/ "+str(int(weapons.reserve[weapons.selected_slot]) if weapons.survival_enabled else int(weapons.current().magazine)),HORIZONTAL_ALIGNMENT_LEFT,-1,24,GameUI.MUTED)
    draw_string(GameUI.regular(),point+Vector2(177,63),"R  RELOAD",HORIZONTAL_ALIGNMENT_LEFT,-1,16,GameUI.MUTED)
    draw_string(GameUI.regular(),point+Vector2(177,84),"RMB AIM / LMB FIRE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,GameUI.MUTED)
    for slot in range(1,4):
        var x:=point.x+14+(slot-1)*103
        var selected: bool=weapons.selected_slot==slot
        draw_rect(Rect2(Vector2(x,point.y+102),Vector2(98,22)),GameUI.LIME if selected else GameUI.PANEL)
        var caption: String=["PISTOL","RIFLE","SNIPER"][slot-1] if weapons.unlocked[slot] else "LOCKED"
        draw_string(GameUI.bold(),Vector2(x+7,point.y+118),str(slot)+" "+caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,GameUI.INK if selected else (GameUI.WHITE if weapons.unlocked[slot] else GameUI.MUTED))
    if weapons.reload_time>0:
        var ratio: float=1-weapons.reload_time/float(weapons.current().reload_seconds)
        draw_rect(Rect2(point+Vector2(15,93),Vector2(302*ratio,3)),GameUI.LIME)
