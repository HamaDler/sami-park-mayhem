extends Node3D
var vehicle: CharacterBody3D
var audio: Node
var settings: Dictionary
var engine: AudioStreamPlayer3D
var rolling: AudioStreamPlayer3D
var skid: AudioStreamPlayer3D
var wind: AudioStreamPlayer3D
var impact_cooldown: float=0
func _ready() -> void:
    vehicle=get_parent();audio=get_node_or_null("/root/GameAudio")
    if not audio:set_physics_process(false);return
    settings=audio.settings.vehicle
    engine=_loop("engine_loop.wav");rolling=_loop("rolling_loop.wav")
    skid=_loop("tire_skid_loop.wav");wind=_loop("driving_wind_loop.wav")
func _loop(filename: String) -> AudioStreamPlayer3D:
    var player:=AudioStreamPlayer3D.new();player.stream=audio.get_stream(filename,true)
    player.bus="SFX";player.unit_size=12;player.max_distance=float(settings.audible_distance)
    player.volume_db=-80;player.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(player);return player
func _physics_process(delta: float) -> void:
    impact_cooldown=maxf(0,impact_cooldown-delta)
    var running: bool=vehicle.control_enabled and vehicle.health>0
    var speed:=absf(vehicle.speed)
    var ratio:=clampf(speed/float(vehicle.settings.max_speed),0,1)
    var grounded: bool=vehicle.is_on_floor() and not vehicle.rolling
    var throttle:=absf(vehicle.throttle_amount)
    engine.pitch_scale=lerpf(engine.pitch_scale,lerpf(float(settings.min_engine_pitch),float(settings.max_engine_pitch),ratio)+throttle*.12,1-exp(-delta*5))
    _mix(engine,(.55+throttle*.25+ratio*.2) if running else 0,float(settings.engine_db),delta)
    _mix(rolling,clampf(speed/9,0,1)*(1 if vehicle.on_path else 1.35) if running and grounded else 0,float(settings.rolling_db),delta)
    rolling.pitch_scale=lerpf(.7,1.4,ratio)
    var braking: bool=vehicle.handbrake_down or (running and Input.get_axis("reverse","accelerate")<-.1 and vehicle.speed>1)
    var slip:=clampf(absf(vehicle.slip_angle)/.7,0,1)
    var squeal: float=maxf(slip if vehicle.drifting else 0.0,(.2+ratio*.8) if braking else 0.0)
    if not vehicle.on_path:squeal*=.28
    _mix(skid,squeal if running and grounded and speed>3 else 0,float(settings.skid_db),delta)
    skid.pitch_scale=lerpf(.88,1.14,ratio)
    _mix(wind,smoothstep(6,50,speed) if running else 0,float(settings.wind_db),delta)
    if vehicle.impact_speed>4 and impact_cooldown==0:
        audio.play_sfx("cart_impact",clampf(vehicle.impact_speed/8,-3,4));impact_cooldown=.5
func _mix(player: AudioStreamPlayer3D, amount: float, db: float, delta: float) -> void:
    var target: float=db_to_linear(db)*amount
    player.volume_linear=lerpf(player.volume_linear,target,1-exp(-delta*9))
    if target>.0001 and not player.playing and audio.playback_enabled:player.play()
    if target==0 and player.volume_linear<.0001 and player.playing:player.stop()
func _exit_tree() -> void:
    for player in [engine,rolling,skid,wind]:
        if is_instance_valid(player):player.stop();player.stream=null
