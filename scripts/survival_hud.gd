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
var sound_words: Control
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE;process_mode=Node.PROCESS_MODE_ALWAYS
    sound_words=Control.new();sound_words.name="ComicSoundWords";sound_words.set_script(load("res://scripts/comic_sfx.gd"));add_child(sound_words)
    workshop=Control.new();workshop.set_script(load("res://scripts/workshop_menu.gd"));add_child(workshop)
    ending=Control.new();ending.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(ending)
    var shade:=ColorRect.new();shade.color=Color(.015,.02,.025,.92);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ending.add_child(shade)
    var frame:=Control.new();frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER);frame.position=Vector2(-300,-190);frame.size=Vector2(600,410);ending.add_child(frame)
    GameUI.shout_label(frame,"YOU DIDN'T MAKE IT!",Vector2(8,-18),72,GameUI.RED)
    summary=GameUI.label(frame,"",Vector2(12,86),22,GameUI.WHITE,true);summary.size=Vector2(580,170)
    summary.add_theme_constant_override("line_spacing",6)
    GameUI.button(frame,"TRY AGAIN   >",Vector2(12,270),Vector2(278,58),restart)
    GameUI.button(frame,"QUIT",Vector2(310,270),Vector2(278,58),GameUI.quit_game)
    GameUI.label(frame,"A new run starts back at English Door.",Vector2(12,350),GameUI.SIZE_BODY,GameUI.MUTED)
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
    sound_words.bind(session)
func _on_hit_feedback(kind: String, points: int, label: String) -> void:
    hit_kind=kind;hit_time=.28
    GameUI.play_ui({"body":"hitmarker","head":"hitmarker_head"}.get(kind,"kill_confirm"))
    if points>0:
        popups.append({"text":"+%d" % points,"callout":label+"!" if label!="" else "","color":Color("ffd268") if kind=="headkill" else GameUI.WHITE,"time":1.1})
        if popups.size()>6:popups.pop_front()
func show_banner(title: String, subtitle: String, color: Color) -> void:
    banner_title=title;banner_subtitle=subtitle;banner_color=color;banner_time=BANNER_SECONDS
func restart() -> void:
    get_tree().paused=false;get_tree().reload_current_scene()
func show_game_over() -> void:
    workshop.close()
    var s:=survival
    var g:=GameUI.grouped
    summary.text="WAVE %d    /    %s KILLS\nSCORE %s\nBEST SCORE %s    /    BEST WAVE %d\nLIFETIME KILLS %s" % [s.wave.number,g.call(s.kills),g.call(s.score),g.call(s.records.best_score),s.records.best_wave,g.call(s.records.lifetime_kills)]
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
# bold: display face (Lilita One), otherwise body (Nunito Sans). outline: ink outline over the 3D scene.
func _text(point: Vector2, text: String, pixels: int=19, color: Color=GameUI.WHITE, bold: bool=false, outline: int=0) -> void:
    GameUI.draw_text(self,GameUI.display() if bold else GameUI.body_bold(),point,text,pixels,color,outline)
func _caption(point: Vector2, text: String, pixels: int, color: Color) -> void:
    GameUI.draw_text(self,GameUI.caption(),point,text,pixels,color)
func _draw() -> void:
    if not survival:return
    var s:=survival
    var p:=Vector2(size.x-355,25)
    draw_style_box(GameUI.panel_style(Color(.04,.05,.08,.94)),Rect2(p,Vector2(325,172)))
    draw_rect(Rect2(p+Vector2(3,3),Vector2(319,5)),GameUI.RED)
    _caption(p+Vector2(17,36),"WAVE",18,GameUI.MUTED)
    _text(p+Vector2(88,44),"%02d" % maxi(1,s.wave.number),42,GameUI.WHITE,true)
    var status: String="%d LEFT" % s.wave.remaining() if s.wave.running else "NEXT IN %dS" % ceili(s.wave.preparation)
    _text(p+Vector2(308-GameUI.text_width(GameUI.display(),status,18),36),status,18,GameUI.LIME,true)
    draw_line(p+Vector2(17,58),p+Vector2(308,58),Color("354039"),1)
    _caption(p+Vector2(17,84),"SCORE",GameUI.SIZE_SMALL,GameUI.MUTED);_caption(p+Vector2(178,84),"KILLS",GameUI.SIZE_SMALL,GameUI.MUTED)
    _text(p+Vector2(17,114),_grouped(s.score),28,GameUI.WHITE,true);_text(p+Vector2(178,114),_grouped(s.kills),28,GameUI.WHITE,true)
    _text(p+Vector2(17,153),"%s IQD" % _grouped(s.dinars),24,Color("ffd268"),true)
    _draw_vitals(s)
    var y: float=225
    if s.missions.active:
        var mission: Node3D=s.missions
        var origin:=Vector2(30,156)
        draw_style_box(GameUI.panel_style(Color(.04,.05,.08,.94)),Rect2(origin,Vector2(350,128)))
        draw_rect(Rect2(origin+Vector2(3,3),Vector2(344,5)),Color("64e2f0"))
        _text(origin+Vector2(13,26),"SUPPLIES  /  "+mission.location_name,GameUI.SIZE_SUBHEADING,Color("64e2f0"),true)
        _text(origin+Vector2(13,51),mission.status,GameUI.SIZE_BODY,GameUI.WHITE)
        var distance: float=s.game.get_active_actor().global_position.distance_to(Vector3(mission.position_2d.x,0,mission.position_2d.y))
        _text(origin+Vector2(13,76),"%dM   /   %dS LEFT" % [roundi(distance),ceili(mission.remaining)],GameUI.SIZE_LABEL,GameUI.MUTED,true)
        draw_rect(Rect2(origin+Vector2(13,91),Vector2(324,8)),Color("354039"))
        draw_rect(Rect2(origin+Vector2(13,91),Vector2(324*clampf(mission.progress/float(mission.settings.hold_seconds),0,1),8)),Color("64e2f0"))
        _text(origin+Vector2(13,119),"SECURE  %d / %dS" % [floori(mission.progress),ceili(mission.settings.hold_seconds)],GameUI.SIZE_LABEL,GameUI.WHITE,true)
        if not get_tree().paused:
            var camera: Camera3D=s.game.camera_rig.camera
            var world_point:=Vector3(mission.position_2d.x,3,mission.position_2d.y)
            var marker:=camera.unproject_position(world_point)
            if camera.is_position_behind(world_point):marker=size*.5-(marker-size*.5)
            marker=marker.clamp(Vector2(35,310),size-Vector2(45,190))
            draw_arc(marker,10,0,TAU,4,Color("64e2f0"),3,true)
            var caption: String="SUPPLIES  %dM" % roundi(distance)
            var width:=GameUI.text_width(GameUI.display(),caption,GameUI.SIZE_LABEL)
            var label_point:=marker+Vector2(15,5)
            if label_point.x+width>size.x-20:label_point.x=marker.x-width-15
            _text(label_point,caption,GameUI.SIZE_LABEL,Color("64e2f0"),true,GameUI.OUTLINE)
    if s.rewards.infinite_ammo>0:_text(Vector2(size.x-338,y),"INFINITE AMMO  %dS" % ceili(s.rewards.infinite_ammo),GameUI.SIZE_SUBHEADING,GameUI.LIME,true,GameUI.OUTLINE);y+=30
    if s.rewards.double_dinars>0:_text(Vector2(size.x-338,y),"DOUBLE DINARS  %dS" % ceili(s.rewards.double_dinars),GameUI.SIZE_SUBHEADING,Color("ffd268"),true,GameUI.OUTLINE)
    if s.game.is_driving():
        var cart: CharacterBody3D=s.game.active_vehicle.vehicle
        _text(Vector2(size.x-287,size.y-323),"CART  %d%%" % ceili(cart.health/cart.max_health*100),GameUI.SIZE_SUBHEADING,GameUI.RED if cart.health<cart.max_health*.25 else GameUI.WHITE,true,GameUI.OUTLINE)
        _text(Vector2(size.x-287,size.y-300),"BUMPER %d  /  ARMOR %d  /  GRIP %d" % [s.upgrades.levels.bumper,s.upgrades.levels.armor,s.upgrades.levels.handling],GameUI.SIZE_SMALL,GameUI.LIME,true,4)
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
            _text(marker+Vector2(12,5),"%dM" % roundi(world_point.distance_to(s.game.get_active_actor().global_position)),GameUI.SIZE_LABEL,GameUI.WHITE,true,GameUI.OUTLINE)
func _draw_vitals(s: Node3D) -> void:
    var maximum: float=float(s.config.player.max_health)
    var bottom:=Vector2(size.x*.5-145,size.y-137)
    draw_style_box(GameUI.style(Color(.04,.05,.08,.92),0,Vector2(3,4)),Rect2(bottom,Vector2(290,33)))
    var inner:=Vector2(282,25)
    draw_rect(Rect2(bottom+Vector2(4,4),Vector2(inner.x*clampf(chip_health/maximum,0,1),inner.y)),Color(.95,.85,.75,.75))
    draw_rect(Rect2(bottom+Vector2(4,4),Vector2(inner.x*clampf(shown_health/maximum,0,1),inner.y)),GameUI.RED if s.health<35 else Color("76ba79"))
    _text(bottom+Vector2(13,23),"HEALTH  %d" % ceili(s.health),17,GameUI.WHITE,true,4)
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
    var y: float=0
    for i in popups.size():
        var item: Dictionary=popups[popups.size()-1-i]
        var t: float=float(item.time)/1.1
        var color: Color=item.color;color.a=clampf(t*2.5,0,1)
        var rise: float=(1-t)*22
        var pop: float=1.0+maxf(0,(t-.85)/.15)*.35
        var point:=origin+Vector2(0,-y-rise)
        var points_size: int=int(22*pop)
        _text(point,str(item.text),points_size,color,true,GameUI.OUTLINE)
        var callout: String=item.get("callout","")
        if callout!="":
            # The one dramatic word gets the comic face, tilted like a sound effect.
            var shout_size: int=int(GameUI.SIZE_CALLOUT*pop)
            var x: float=GameUI.text_width(GameUI.display(),str(item.text),points_size)+12
            draw_set_transform(point+Vector2(x,2),deg_to_rad(-6),Vector2.ONE)
            GameUI.draw_text(self,GameUI.shout(),Vector2.ZERO,callout,shout_size,color,8)
            draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
        y+=34 if callout!="" else 26
func _draw_banner() -> void:
    if banner_time<=0 or get_tree().paused:return
    var elapsed: float=BANNER_SECONDS-banner_time
    var slide: float=1-pow(1-clampf(elapsed/.35,0,1),3)
    var alpha: float=clampf(banner_time/.6,0,1)*clampf(elapsed/.15,0,1)
    # A quick punch-in when the banner lands.
    var punch: float=1.0+(1.0-clampf(elapsed/.25,0,1))*.25
    var title_size: int=GameUI.SIZE_SHOUT
    var width: float=GameUI.text_width(GameUI.shout(),banner_title,title_size)
    var y: float=size.y*.24
    draw_rect(Rect2(Vector2(0,y-74),Vector2(size.x,118)),Color(.02,.03,.04,.72*alpha))
    var accent: Color=banner_color;accent.a=alpha
    draw_rect(Rect2(Vector2(size.x*.5-200*slide,y-74),Vector2(400*slide,4)),accent)
    var center:=Vector2(size.x*.5-(1-slide)*80,y-title_size*.34)
    draw_set_transform(center,deg_to_rad(-2.5),Vector2.ONE*punch)
    # Offset colour shadow under the ink-outlined title, like a printed comic banner.
    GameUI.draw_text(self,GameUI.shout(),Vector2(-width*.5+4,title_size*.34+5),banner_title,title_size,Color(accent.r,accent.g,accent.b,alpha*.9))
    GameUI.draw_text(self,GameUI.shout(),Vector2(-width*.5,title_size*.34),banner_title,title_size,Color(1,1,1,alpha),10)
    draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
    var sub_size: int=GameUI.SIZE_SUBHEADING
    var sub_width: float=GameUI.text_width(GameUI.caption(),banner_subtitle,sub_size)
    GameUI.draw_text(self,GameUI.caption(),Vector2(size.x*.5-sub_width*.5+(1-slide)*80,y+32),banner_subtitle,sub_size,accent,4)
func _grouped(value: int) -> String:return GameUI.grouped(value)
