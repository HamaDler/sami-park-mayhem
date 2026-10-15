extends Control
var survival: Node3D
var ending: Control
var summary: Label
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE;process_mode=Node.PROCESS_MODE_ALWAYS
    ending=Control.new();ending.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(ending)
    var shade:=ColorRect.new();shade.color=Color(.015,.02,.025,.92);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ending.add_child(shade)
    var frame:=Control.new();frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER);frame.position=Vector2(-300,-190);frame.size=Vector2(600,410);ending.add_child(frame)
    GameUI.label(frame,"YOU DIDN'T MAKE IT",Vector2(10,0),47,GameUI.RED,true)
    summary=GameUI.label(frame,"",Vector2(12,82),25,GameUI.WHITE,true);summary.size=Vector2(580,170)
    GameUI.button(frame,"TRY AGAIN   >",Vector2(12,270),Vector2(278,58),restart)
    GameUI.button(frame,"QUIT",Vector2(310,270),Vector2(278,58),GameUI.quit_game)
    GameUI.label(frame,"ENGLISH DOOR  /  A NEW RUN",Vector2(12,353),17,GameUI.MUTED,true)
    ending.hide()
func restart() -> void:
    get_tree().paused=false;get_tree().reload_current_scene()
func show_game_over() -> void:
    var s:=survival
    summary.text="WAVE %d    /    %d KILLS\nSCORE %d\nBEST SCORE %d    /    BEST WAVE %d\nLIFETIME KILLS %d" % [s.wave.number,s.kills,s.score,s.records.best_score,s.records.best_wave,s.records.lifetime_kills]
    ending.show();ending.get_child(1).get_child(2).grab_focus()
func _process(_delta: float) -> void:queue_redraw()
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
    var bottom:=Vector2(size.x*.5-145,size.y-137)
    draw_rect(Rect2(bottom,Vector2(290,33)),Color(.02,.03,.04,.85))
    draw_rect(Rect2(bottom+Vector2(4,4),Vector2(282*clampf(s.health/float(s.config.player.max_health),0,1),25)),GameUI.RED if s.health<35 else Color("76ba79"))
    _text(bottom+Vector2(13,24),"HEALTH  %d" % ceili(s.health),19,GameUI.WHITE,true)
    var y: float=225
    if s.rewards.infinite_ammo>0:_text(Vector2(size.x-338,y),"INFINITE AMMO  %ds" % ceili(s.rewards.infinite_ammo),23,GameUI.LIME,true);y+=32
    if s.rewards.double_dinars>0:_text(Vector2(size.x-338,y),"DOUBLE DINARS  %ds" % ceili(s.rewards.double_dinars),23,Color("ffd268"),true)
    if s.game.is_driving():
        var cart: CharacterBody3D=s.game.active_vehicle.vehicle
        _text(Vector2(size.x-287,size.y-323),"CART  %d%%" % ceili(cart.health/cart.max_health*100),23,GameUI.RED if cart.health<cart.max_health*.25 else GameUI.WHITE,true)
    if s.damage_flash>0:
        var c:=Color(.8,.03,.02,s.damage_flash*.8)
        draw_rect(Rect2(Vector2.ZERO,Vector2(size.x,12)),c);draw_rect(Rect2(Vector2.ZERO,Vector2(12,size.y)),c)
        draw_rect(Rect2(Vector2(size.x-12,0),Vector2(12,size.y)),c);draw_rect(Rect2(Vector2(0,size.y-12),Vector2(size.x,12)),c)
    if s.hit_flash>0 and not get_tree().paused:
        var center:=size*.5;var color:=Color("ffd268") if s.last_hit_headshot else GameUI.WHITE
        for d in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:draw_line(center+d*10,center+d*16,color,2,true)
    if not get_tree().paused and s.wave.running and s.wave.spawned>=s.wave.total and s.wave.remaining()<=5:
        var camera: Camera3D=s.game.camera_rig.camera
        for zombie in s.enemies.living():
            var world_point: Vector3=zombie.global_position+Vector3.UP*2.3
            var marker:=camera.unproject_position(world_point)
            if camera.is_position_behind(world_point):marker=size*.5-(marker-size*.5)
            marker=marker.clamp(Vector2(30,170),size-Vector2(35,180))
            draw_arc(marker,8,0,TAU,12,GameUI.RED,2,true)
            _text(marker+Vector2(12,5),"%dm" % roundi(world_point.distance_to(s.game.get_active_actor().global_position)),16,GameUI.WHITE,true)
