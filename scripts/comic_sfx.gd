extends Control
# Comic sound-effect lettering: "BLAM!" beside the gun when it fires, "THWAP!" on hits,
# a "SPLAT!" burst where a zombie dies, "THWACK!" for melee, "CRUNCH!" for roadkills and a red
# "CHOMP!" from the side a zombie bites you. Impact words are pinned to the world; gunfire and
# bite words are pinned to the screen. Bangers lettering, ink outline, pop-in, then a fade.
const WORDS:={
    "pistol":["BLAM!","BANG!"],"rifle":["RAT-TAT!","BRAKKA!","TAKKA!"],"sniper":["KA-BLAM!","BOOM!"],
    "hit":["THWAP!","WHAP!","THUD!"],"headhit":["KRAK!","CLONK!"],
    "kill":["SPLAT!","SPLORCH!","SQUELCH!"],"headkill":["POP!","SPLAT!","KRAK!"],
    "melee":["THWACK!","WHAM!"],"meleekill":["KA-POW!","WHAM!"],
    "roadkill":["CRUNCH!","THUNK!","SPLAT!"],"hurt":["CHOMP!","GNASH!","GRAAH!"]}
# Per kind: fill colour, letter size, seconds on screen, star burst behind, tilt range (degrees).
const STYLES:={
    "pistol":[Color("ffd23f"),30,.3,false,10.0],"rifle":[Color("ffd23f"),28,.36,false,8.0],"sniper":[Color("ff9b3d"),40,.45,false,8.0],
    "hit":[Color("f4ecd8"),26,.42,false,14.0],"headhit":[Color("ffd23f"),30,.46,false,14.0],
    "kill":[Color("ff4f3d"),50,.8,true,12.0],"headkill":[Color("ff4f3d"),56,.85,true,12.0],
    "melee":[Color("ffd23f"),40,.55,false,16.0],"meleekill":[Color("ff4f3d"),54,.85,true,14.0],
    "roadkill":[Color("ff4f3d"),56,.85,true,10.0],"hurt":[Color("ff3b30"),44,.6,false,12.0]}
const MAX_WORDS: int=14
# Minimum seconds between words of the same family, so automatic fire does not flood the screen.
const THROTTLE:={"gun":.22,"rifle":.45,"hit":.2,"hurt":.35}
@export var show_gunfire: bool=true
var survival: Node3D
var words: Array[Dictionary]=[]
var clock: float=0
# Only redraw while words are on screen (plus one frame to clear the last one).
var drawn: bool=false
var last_said: Dictionary={}
var random:=RandomNumberGenerator.new()
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    random.randomize()
func bind(session: Node3D) -> void:
    survival=session
    session.zombie_struck.connect(_on_struck)
    session.player_hit_from.connect(_on_bitten)
    var weapons: Node=session.game.player.weapons
    if not weapons.fired.is_connected(_on_fired):weapons.fired.connect(_on_fired)
func camera() -> Camera3D:
    return survival.game.camera_rig.camera if survival else null
func _ready_to_say(family: String) -> bool:
    if clock-float(last_said.get(family,-10.0))<float(THROTTLE.get(family,0.0)):return false
    last_said[family]=clock;return true
func say(kind: String, anchor: Variant, offset:=Vector2.ZERO) -> void:
    var style: Array=STYLES[kind]
    var group: Array=WORDS[kind]
    var tilt: float=float(style[4])
    words.append({"text":group[random.randi_range(0,group.size()-1)],"kind":kind,"anchor":anchor,"offset":offset,
        "age":0.0,"life":float(style[2]),"tilt":deg_to_rad(random.randf_range(-tilt,tilt)),"seed":random.randi()})
    if words.size()>MAX_WORDS:words.pop_front()
func _on_fired(slot: int, _hit: Dictionary) -> void:
    if not show_gunfire or not is_visible_in_tree():return
    var kind: String=["pistol","rifle","sniper"][clampi(slot,1,3)-1]
    if not _ready_to_say("rifle" if kind=="rifle" else "gun"):return
    var view: Camera3D=camera();var game: Node3D=survival.game
    var muzzle: Vector3
    if game.camera_rig.first_person and game.camera_rig.viewmodel.visible:muzzle=game.camera_rig.viewmodel.muzzle_position()
    else:muzzle=game.player.avatar.get_weapon().get_node("Muzzle").global_position
    if view==null or view.is_position_behind(muzzle):return
    # Screen-pinned, up and to the right of the muzzle so the crosshair stays clear.
    say(kind,view.unproject_position(muzzle),Vector2(random.randf_range(40,80),random.randf_range(-70,-40)))
func _on_struck(point: Vector3, cause: String, headshot: bool, killed: bool) -> void:
    var kind: String
    if cause=="ram":kind="roadkill" if killed else ""
    elif cause=="melee":kind="meleekill" if killed else "melee"
    elif killed:kind="headkill" if headshot else "kill"
    else:
        if not _ready_to_say("hit"):return
        kind="headhit" if headshot else "hit"
    if kind=="":return
    say(kind,point+Vector3.UP*(.35 if killed else .1))
func _on_bitten(source: Vector3) -> void:
    if not _ready_to_say("hurt"):return
    var view: Camera3D=camera()
    if view==null:return
    var offset: Vector3=view.global_basis.inverse()*(source-view.global_position)
    var direction:=Vector2(offset.x,-offset.z).normalized()
    if direction.length_squared()<.01:direction=Vector2.DOWN
    # From the side the bite came from, between the crosshair and the screen edge.
    say("hurt",Vector2.ZERO,Vector2(direction.x*.32,-direction.y*.3))
func _process(delta: float) -> void:
    if get_tree().paused:return
    clock+=delta
    if words.is_empty():
        if drawn:drawn=false;queue_redraw()
        return
    for word in words:word.age=float(word.age)+delta
    words=words.filter(func(word: Dictionary):return float(word.age)<float(word.life))
    drawn=true;queue_redraw()
func _draw() -> void:
    var view: Camera3D=camera()
    if view==null or get_tree().paused:return
    for word in words:
        var point: Vector2;var scale_factor: float=1.0
        if word.anchor is Vector3:
            var world: Vector3=word.anchor
            if view.is_position_behind(world):continue
            point=view.unproject_position(world)
            scale_factor=clampf(9.0/maxf(view.global_position.distance_to(world),.1),.55,1.25)
        elif word.kind=="hurt":
            point=size*.5+Vector2(word.offset.x*size.x,word.offset.y*size.y)
        else:point=word.anchor+word.offset
        _draw_word(word,point,scale_factor)
func _draw_word(word: Dictionary, point: Vector2, scale_factor: float) -> void:
    var style: Array=STYLES[word.kind]
    var t: float=float(word.age)/float(word.life)
    # Pop in with a little overshoot, hold, then fade and drift up.
    var pop: float=1.0+.55*(1.0-clampf(float(word.age)/.1,0,1))
    if float(word.age)>.1:pop=1.0+.08*sin(clampf((float(word.age)-.1)/.12,0,1)*PI)
    var alpha: float=1.0-smoothstep(.62,1.0,t)
    var rise: float=t*18.0
    var letter_size: int=int(float(style[1])*scale_factor)
    var font: Font=GameUI.shout()
    var text: String=word.text
    var width: float=GameUI.text_width(font,text,letter_size)
    draw_set_transform(point-Vector2(0,rise),float(word.tilt),Vector2.ONE*pop)
    if style[3]:_draw_burst(width,letter_size,int(word.seed),alpha)
    var fill: Color=style[0];fill.a=alpha
    var shade:=Color(GameUI.OUTLINE_COLOR.r,GameUI.OUTLINE_COLOR.g,GameUI.OUTLINE_COLOR.b,alpha*.9)
    var origin:=Vector2(-width*.5,letter_size*.35)
    # Offset ink shadow, then the outlined letters.
    draw_string(font,origin+Vector2(3,4),text,HORIZONTAL_ALIGNMENT_LEFT,-1,letter_size,shade)
    GameUI.draw_text(self,font,origin,text,letter_size,fill,maxi(6,letter_size/6))
    draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
# Jagged comic "POW" burst behind kill words.
func _draw_burst(width: float, letter_size: int, burst_seed: int, alpha: float) -> void:
    var jitter:=RandomNumberGenerator.new();jitter.seed=burst_seed
    var outer:=Vector2(width*.62+18,letter_size*.95)
    var points:=PackedVector2Array()
    var spikes: int=14
    for i in spikes*2:
        var angle: float=TAU*i/(spikes*2.0)
        var reach: float=1.0 if i%2==0 else .62
        reach*=jitter.randf_range(.9,1.1)
        points.append(Vector2(cos(angle)*outer.x,sin(angle)*outer.y)*reach)
    var ink:=Color(GameUI.OUTLINE_COLOR.r,GameUI.OUTLINE_COLOR.g,GameUI.OUTLINE_COLOR.b,alpha)
    var shadow:=PackedVector2Array();for p in points:shadow.append(p+Vector2(4,5))
    draw_colored_polygon(shadow,Color(ink.r,ink.g,ink.b,alpha*.8))
    draw_colored_polygon(points,Color(GameUI.COMIC_YELLOW.r,GameUI.COMIC_YELLOW.g,GameUI.COMIC_YELLOW.b,alpha))
    var outline:=points.duplicate();outline.append(points[0])
    draw_polyline(outline,ink,3,true)
