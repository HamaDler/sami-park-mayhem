extends Control
var survival: Node3D:set=_set_survival
# Feel layer: hitmarker, floating score popups, wave banners, damage direction arcs,
# smoothed health with delayed chip damage, and a stamina bar.
var hit_kind: String=""
var hit_time: float=0
var popups: Array[Dictionary]=[]
var banner_title: String=""
var banner_subtitle: String=""
var banner_color: Color=Color.WHITE
var banner_time: float=0
var damage_marks: Array[Dictionary]=[]
var shown_health: float=100
var chip_health: float=100
var chip_delay: float=0
var vignette: GradientTexture2D
var pulse: float=0
const BANNER_SECONDS: float=3.2
var ending: Control
var summary: Label
var workshop: Control
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE;process_mode=Node.PROCESS_MODE_ALWAYS
    workshop=Control.new();workshop.set_script(load("res://scripts/workshop_menu.gd"));add_child(workshop)
    ending=Control.new();ending.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(ending)
    var shade:=ColorRect.new();shade.color=Color(.015,.02,.025,.92);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ending.add_child(shade)
    var frame:=Control.new();frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER);frame.position=Vector2(-300,-190);frame.size=Vector2(600,410);ending.add_child(frame)
    GameUI.label(frame,"YOU DIDN'T MAKE IT",Vector2(10,0),47,GameUI.RED,true)
    summary=GameUI.label(frame,"",Vector2(12,82),25,GameUI.WHITE,true);summary.size=Vector2(580,170)
    GameUI.button(frame,"TRY AGAIN   >",Vector2(12,270),Vector2(278,58),restart)
    GameUI.button(frame,"QUIT",Vector2(310,270),Vector2(278,58),GameUI.quit_game)
    GameUI.label(frame,"ENGLISH DOOR  /  A NEW RUN",Vector2(12,353),17,GameUI.MUTED,true)
    ending.hide()
    vignette=GradientTexture2D.new();vignette.fill=GradientTexture2D.FILL_RADIAL;vignette.fill_from=Vector2(.5,.5);vignette.fill_to=Vector2(1.05,.5)
    vignette.width=128;vignette.height=128
    var ramp:=Gradient.new();ramp.offsets=PackedFloat32Array([0,.55,1]);ramp.colors=PackedColorArray([Color(.6,0,0,0),Color(.6,0,0,0),Color(.55,0,0,.85)])
    vignette.gradient=ramp
func _set_survival(session: Node3D) -> void:
    survival=session
    if session==null:return
    shown_health=float(session.health);chip_health=shown_health
    session.hit_feedback.connect(_on_hit_feedback)
    session.player_hit_from.connect(func(source: Vector3):damage_marks.append({"source":source,"time":1.3}))
func _on_hit_feedback(kind: String, points: int, label: String) -> void:
    hit_kind=kind;hit_time=.28
    GameUI.play_ui({"body":"hitmarker","head":"hitmarker_head"}.get(kind,"kill_confirm"))
    if points>0:
        var text: String="+%d" % points
        if label!="":text+="  "+label
        popups.append({"text":text,"color":Color("ffd268") if kind=="headkill" else GameUI.WHITE,"time":1.1})
        if popups.size()>6:popups.pop_front()
func show_banner(title: String, subtitle: String, color: Color) -> void:
    banner_title=title;banner_subtitle=subtitle;banner_color=color;banner_time=BANNER_SECONDS
func restart() -> void:
    get_tree().paused=false;get_tree().reload_current_scene()
func show_game_over() -> void:
    workshop.close()
    var s:=survival
    summary.text="WAVE %d    /    %d KILLS\nSCORE %d\nBEST SCORE %d    /    BEST WAVE %d\nLIFETIME KILLS %d" % [s.wave.number,s.kills,s.score,s.records.best_score,s.records.best_wave,s.records.lifetime_kills]
    ending.show();ending.get_child(1).get_child(2).grab_focus()
func _process(delta: float) -> void:
    if survival and not get_tree().paused:
        hit_time=maxf(0,hit_time-delta);banner_time=maxf(0,banner_time-delta);pulse+=delta
        for item in popups:item.time=float(item.time)-delta
        popups=popups.filter(func(item: Dictionary):return float(item.time)>0)
        for item in damage_marks:item.time=float(item.time)-delta
        damage_marks=damage_marks.filter(func(item: Dictionary):return float(item.time)>0)
        var health: float=float(survival.health)
        shown_health=lerpf(shown_health,health,1-exp(-delta*14))
        if health<chip_health:
            chip_delay-=delta
            if chip_delay<=0:chip_health=move_toward(chip_health,health,delta*60)
        else:chip_health=health;chip_delay=.45
    queue_redraw()
func _text(point: Vector2, text: String, pixels: int=19, color: Color=GameUI.WHITE, bold: bool=false) -> void:
    draw_string(GameUI.bold() if bold else GameUI.regular(),point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)
func _draw() -> void:
    if not survival:return
    var s:=survival
    var p:=Vector2(size.x-355,25)
    draw_style_box(GameUI.style(Color(.02,.03,.04,.9)),Rect2(p,Vector2(325,172)))
    draw_line(p,p+Vector2(325,0),GameUI.RED,4,true)
    _text(p+Vector2(17,37),"WAVE",21,GameUI.MUTED,true)
    _text(p+Vector2(94,43),"%02d" % maxi(1,s.wave.number),41,GameUI.WHITE,true)
    var status: String="%d REMAIN" % s.wave.remaining() if s.wave.running else "NEXT IN %ds" % ceili(s.wave.preparation)
    _text(p+Vector2(174,36),status,19,GameUI.LIME,true)
    draw_line(p+Vector2(17,58),p+Vector2(308,58),Color("354039"),1)
    _text(p+Vector2(17,88),"SCORE",14,GameUI.MUTED,true);_text(p+Vector2(178,88),"KILLS",14,GameUI.MUTED,true)
    _text(p+Vector2(17,117),str(s.score),29,GameUI.WHITE,true);_text(p+Vector2(178,117),str(s.kills),29,GameUI.WHITE,true)
    _text(p+Vector2(17,153),"%s IQD" % str(s.dinars),26,Color("ffd268"),true)
    _draw_vitals(s)
    var y: float=225
    if s.missions.active:
        var mission: Node3D=s.missions
        var origin:=Vector2(30,156)
        draw_style_box(GameUI.style(Color(.02,.03,.04,.9)),Rect2(origin,Vector2(350,128)))
        draw_line(origin,origin+Vector2(350,0),Color("64e2f0"),3,true)
        _text(origin+Vector2(13,25),"SUPPLIES / "+mission.location_name,22,Color("64e2f0"),true)
        _text(origin+Vector2(13,51),mission.status,17,GameUI.WHITE,true)
        var distance: float=s.game.get_active_actor().global_position.distance_to(Vector3(mission.position_2d.x,0,mission.position_2d.y))
        _text(origin+Vector2(13,76),"%dm   /   %ds LEFT" % [roundi(distance),ceili(mission.remaining)],19,GameUI.MUTED,true)
        draw_rect(Rect2(origin+Vector2(13,91),Vector2(324,8)),Color("354039"))
        draw_rect(Rect2(origin+Vector2(13,91),Vector2(324*clampf(mission.progress/float(mission.settings.hold_seconds),0,1),8)),Color("64e2f0"))
        _text(origin+Vector2(13,119),"SECURE  %d / %ds" % [floori(mission.progress),ceili(mission.settings.hold_seconds)],17,GameUI.WHITE,true)
        if not get_tree().paused:
            var camera: Camera3D=s.game.camera_rig.camera
            var world_point:=Vector3(mission.position_2d.x,3,mission.position_2d.y)
            var marker:=camera.unproject_position(world_point)
            if camera.is_position_behind(world_point):marker=size*.5-(marker-size*.5)
            marker=marker.clamp(Vector2(35,310),size-Vector2(45,190))
            draw_arc(marker,10,0,TAU,4,Color("64e2f0"),3,true)
            var caption: String="SUPPLIES  %dm" % roundi(distance)
            var width:=GameUI.bold().get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
            var label_point:=marker+Vector2(15,5)
            if label_point.x+width>size.x-20:label_point.x=marker.x-width-15
            _text(label_point,caption,17,Color("64e2f0"),true)
    if s.rewards.infinite_ammo>0:_text(Vector2(size.x-338,y),"INFINITE AMMO  %ds" % ceili(s.rewards.infinite_ammo),23,GameUI.LIME,true);y+=32
    if s.rewards.double_dinars>0:_text(Vector2(size.x-338,y),"DOUBLE DINARS  %ds" % ceili(s.rewards.double_dinars),23,Color("ffd268"),true)
    if s.game.is_driving():
        var cart: CharacterBody3D=s.game.active_vehicle.vehicle
        _text(Vector2(size.x-287,size.y-323),"CART  %d%%" % ceili(cart.health/cart.max_health*100),23,GameUI.RED if cart.health<cart.max_health*.25 else GameUI.WHITE,true)
        _text(Vector2(size.x-287,size.y-299),"BUMPER %d  /  ARMOR %d  /  GRIP %d" % [s.upgrades.levels.bumper,s.upgrades.levels.armor,s.upgrades.levels.handling],16,GameUI.LIME,true)
    _draw_damage(s)
    _draw_hitmarker()
    _draw_popups()
    _draw_banner()
    if not get_tree().paused and s.wave.running and s.wave.spawned>=s.wave.total and s.wave.remaining()<=5:
        var camera: Camera3D=s.game.camera_rig.camera
        for zombie in s.enemies.living():
            var world_point: Vector3=zombie.global_position+Vector3.UP*2.3
            var marker:=camera.unproject_position(world_point)
            if camera.is_position_behind(world_point):marker=size*.5-(marker-size*.5)
            marker=marker.clamp(Vector2(30,170),size-Vector2(35,180))
            draw_arc(marker,8,0,TAU,12,GameUI.RED,2,true)
            _text(marker+Vector2(12,5),"%dm" % roundi(world_point.distance_to(s.game.get_active_actor().global_position)),16,GameUI.WHITE,true)
func _draw_vitals(s: Node3D) -> void:
    var maximum: float=float(s.config.player.max_health)
    var bottom:=Vector2(size.x*.5-145,size.y-137)
    draw_rect(Rect2(bottom,Vector2(290,33)),Color(.02,.03,.04,.85))
    var inner:=Vector2(282,25)
    draw_rect(Rect2(bottom+Vector2(4,4),Vector2(inner.x*clampf(chip_health/maximum,0,1),inner.y)),Color(.95,.85,.75,.75))
    draw_rect(Rect2(bottom+Vector2(4,4),Vector2(inner.x*clampf(shown_health/maximum,0,1),inner.y)),GameUI.RED if s.health<35 else Color("76ba79"))
    _text(bottom+Vector2(13,24),"HEALTH  %d" % ceili(s.health),19,GameUI.WHITE,true)
    var player: CharacterBody3D=s.game.player
    if player.active and player.get("stamina")!=null:
        var ratio: float=clampf(float(player.stamina)/float(player.settings.stamina.max),0,1)
        if ratio<.999:
            var color:=Color(.8,.3,.25) if player.exhausted else Color("e7c75a")
            draw_rect(Rect2(bottom+Vector2(0,37),Vector2(290,7)),Color(.02,.03,.04,.8))
            draw_rect(Rect2(bottom+Vector2(2,39),Vector2(286*ratio,3)),color)
func _draw_damage(s: Node3D) -> void:
    if get_tree().paused:return
    var low: float=clampf((35-float(s.health))/35,0,1)
    var strength: float=maxf(s.damage_flash*1.6,low*(.45+.25*sin(pulse*6)))
    if strength>.01:draw_texture_rect(vignette,Rect2(Vector2.ZERO,size),false,Color(1,1,1,clampf(strength,0,1)))
    if damage_marks.is_empty() or not s.game.player.active:return
    var camera: Camera3D=s.game.camera_rig.camera;var center:=size*.5
    for mark in damage_marks:
        var offset: Vector3=camera.global_basis.inverse()*(Vector3(mark.source)-s.game.player.global_position)
        var angle: float=atan2(offset.x,-offset.z)-PI*.5
        var alpha: float=clampf(float(mark.time)/.5,0,1)
        draw_arc(center,150,angle-.32,angle+.32,18,Color(.9,.08,.05,.85*alpha),10,true)
func _draw_hitmarker() -> void:
    if hit_time<=0 or get_tree().paused:return
    var center:=size*.5;var t: float=hit_time/.28
    var kill: bool=hit_kind=="kill" or hit_kind=="headkill"
    var color: Color=GameUI.RED if kill else (Color("ffd268") if hit_kind=="head" else GameUI.WHITE)
    color.a=clampf(t*1.6,0,1)
    var inner: float=(9.0 if kill else 7.0)+(1-t)*4;var outer: float=inner+(9.0 if kill else 6.0)
    for d in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
        var n: Vector2=d.normalized()
        draw_line(center+n*inner,center+n*outer,Color(0,0,0,color.a*.6),4.5,true)
        draw_line(center+n*inner,center+n*outer,color,2.5 if kill else 2.0,true)
func _draw_popups() -> void:
    if get_tree().paused:return
    var origin:=size*.5+Vector2(46,-34)
    for i in popups.size():
        var item: Dictionary=popups[popups.size()-1-i]
        var t: float=float(item.time)/1.1
        var color: Color=item.color;color.a=clampf(t*2.5,0,1)
        var rise: float=(1-t)*22
        var pop: float=1.0+maxf(0,(t-.85)/.15)*.35
        _text(origin+Vector2(0,-i*24-rise),str(item.text),int(22*pop),color,true)
func _draw_banner() -> void:
    if banner_time<=0 or get_tree().paused:return
    var elapsed: float=BANNER_SECONDS-banner_time
    var slide: float=1-pow(1-clampf(elapsed/.35,0,1),3)
    var alpha: float=clampf(banner_time/.6,0,1)*clampf(elapsed/.15,0,1)
    var width: float=GameUI.bold().get_string_size(banner_title,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x
    var y: float=size.y*.24
    var x: float=size.x*.5-width*.5-(1-slide)*80
    draw_rect(Rect2(Vector2(0,y-62),Vector2(size.x,96)),Color(.02,.03,.04,.72*alpha))
    var accent: Color=banner_color;accent.a=alpha
    draw_rect(Rect2(Vector2(size.x*.5-180*slide,y-62),Vector2(360*slide,3)),accent)
    _text(Vector2(x,y),banner_title,64,Color(1,1,1,alpha),true)
    var sub_width: float=GameUI.bold().get_string_size(banner_subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
    _text(Vector2(size.x*.5-sub_width*.5+(1-slide)*80,y+26),banner_subtitle,22,accent,true)
