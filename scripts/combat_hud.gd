extends Control
var player: CharacterBody3D
var game: Node3D
var crosshair_gap: float=8
var crosshair_alpha: float=1
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
            # Gap tracks the real bullet cone so the crosshair blooms with sustained fire and movement.
            var camera: Camera3D=game.camera_rig.camera
            var pixels_per_degree: float=size.y/maxf(camera.fov,1.0)
            var target_gap: float=clampf(3+weapons.spread_degrees()*pixels_per_degree,3,90)
            crosshair_gap=lerpf(crosshair_gap,target_gap,.35)
            var lowered: bool=player.get("sprinting") or player.is_busy() or weapons.raise_time>0
            crosshair_alpha=lerpf(crosshair_alpha,0.0 if lowered else 1.0,.3)
            for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
                draw_line(center+direction*crosshair_gap,center+direction*(crosshair_gap+7),Color(0,0,0,.7*crosshair_alpha),3,true)
                draw_line(center+direction*crosshair_gap,center+direction*(crosshair_gap+7),Color(1,1,1,crosshair_alpha),1.5,true)
            draw_circle(center,1.2,Color(1,1,1,.8*crosshair_alpha))
            var magazine: int=int(weapons.current().magazine);var loaded: int=int(weapons.rounds[weapons.selected_slot])
            var warning: String=""
            if weapons.reload_time>0:warning="RELOADING"
            elif not weapons.infinite_ammo and loaded==0:warning="NO AMMO" if int(weapons.reserve[weapons.selected_slot])==0 and weapons.survival_enabled else "RELOAD"
            elif not weapons.infinite_ammo and loaded<=ceili(magazine*.25):warning="R  RELOAD"
            if warning!="":
                var width: float=GameUI.text_width(GameUI.display(),warning,18)
                var tone: Color=GameUI.RED if warning=="NO AMMO" else (GameUI.LIME if warning=="RELOADING" else Color("ffd268"))
                tone.a=.65+.35*sin(Time.get_ticks_msec()*.008) if warning!="RELOADING" else .9
                GameUI.draw_text(self,GameUI.display(),center+Vector2(-width*.5,60),warning,18,tone,GameUI.OUTLINE)
    var point:=Vector2(size.x-360,size.y-174)
    var dimensions:=Vector2(332,134)
    draw_colored_polygon(PackedVector2Array([point,point+Vector2(320,0),point+Vector2(332,12),point+dimensions,point+Vector2(12,134),point+Vector2(0,122)]),Color(.025,.04,.065,.9))
    draw_line(point,point+Vector2(320,0),GameUI.LIME,3,true)
    var title: String=str(weapons.current().name)
    if weapons.survival_enabled:title+="  /  T"+str(int(weapons.tiers[weapons.selected_slot])+1)
    GameUI.draw_text(self,GameUI.display(),point+Vector2(15,32),title,GameUI.SIZE_SUBHEADING,GameUI.WHITE)
    var ammo:=str(weapons.rounds[weapons.selected_slot])
    if weapons.infinite_ammo:ammo="∞"
    var ammo_width: float=GameUI.text_width(GameUI.display(),ammo,46)
    GameUI.draw_text(self,GameUI.display(),point+Vector2(17,86),ammo,46,GameUI.RED if not weapons.infinite_ammo and int(weapons.rounds[weapons.selected_slot])==0 else GameUI.WHITE)
    GameUI.draw_text(self,GameUI.display(),point+Vector2(25+ammo_width,84),"/ "+str(int(weapons.reserve[weapons.selected_slot]) if weapons.survival_enabled else int(weapons.current().magazine)),GameUI.SIZE_SUBHEADING,GameUI.MUTED)
    GameUI.draw_text(self,GameUI.caption(),point+Vector2(184,63),"R RELOAD  /  V MELEE",GameUI.SIZE_SMALL-1,GameUI.MUTED)
    GameUI.draw_text(self,GameUI.caption(),point+Vector2(184,83),"C ROLL  /  RMB AIM",GameUI.SIZE_SMALL-1,GameUI.MUTED)
    for slot in range(1,4):
        var x:=point.x+14+(slot-1)*103
        var selected: bool=weapons.selected_slot==slot
        draw_rect(Rect2(Vector2(x,point.y+102),Vector2(98,22)),GameUI.LIME if selected else GameUI.PANEL)
        var caption: String=["PISTOL","RIFLE","SNIPER"][slot-1] if weapons.unlocked[slot] else "LOCKED"
        GameUI.draw_text(self,GameUI.display(),Vector2(x+7,point.y+118),str(slot)+"  "+caption,GameUI.SIZE_SMALL,GameUI.INK if selected else (GameUI.WHITE if weapons.unlocked[slot] else GameUI.MUTED))
    if weapons.reload_time>0:
        var ratio: float=1-weapons.reload_time/float(weapons.current().reload_seconds)
        draw_rect(Rect2(point+Vector2(15,93),Vector2(302*ratio,3)),GameUI.LIME)
