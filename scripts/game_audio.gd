extends Node
# Persistent across run restarts: one music stream, bounded overlapping effects.
signal sound_played(event: String)
const DIRECTORY: String="res://assets/audio/"
const PREFERENCES: String="user://audio_settings.cfg"
var settings: Dictionary
var volumes: Dictionary={}
var streams: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
var ui_voices: Array[AudioStreamPlayer]=[]
var voices_3d: Array[AudioStreamPlayer3D]=[]
var music: AudioStreamPlayer
var game: Node3D
var save_delay: float=0
var hover_time: float=0
var foot_distance: float=0
var previous_distance: float=0
var previous_floor: bool=true
var step_index: int=0
var random:=RandomNumberGenerator.new()
var playback_enabled: bool=true
var quitting: bool=false
func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    playback_enabled=DisplayServer.get_name()!="headless"
    settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_settings.json"))
    random.randomize();_setup_buses();load_preferences()
    for event: String in settings.events:
        var path: String=DIRECTORY+str(settings.events[event].file)
        if not streams.has(path):streams[path]=load(path)
    for index in int(settings.voice_limit):voices.append(_voice("SFX",Node.PROCESS_MODE_PAUSABLE))
    for index in 6:ui_voices.append(_voice("UI",Node.PROCESS_MODE_ALWAYS))
    for index in int(settings.spatial.voice_limit):
        var spatial:=AudioStreamPlayer3D.new();spatial.bus="SFX";spatial.process_mode=Node.PROCESS_MODE_PAUSABLE
        spatial.unit_size=float(settings.spatial.unit_size);spatial.max_distance=float(settings.spatial.max_distance)
        spatial.attenuation_filter_cutoff_hz=6000;add_child(spatial);voices_3d.append(spatial)
    music=_voice("Music",Node.PROCESS_MODE_ALWAYS)
    music.name="ContinuousMusic";music.stream=load(DIRECTORY+str(settings.music.file))
    if music.stream is AudioStreamOggVorbis:music.stream.loop=true
    music.volume_db=-55
    if playback_enabled:music.play()
func _voice(bus: String, mode: ProcessMode) -> AudioStreamPlayer:
    var player:=AudioStreamPlayer.new();player.bus=bus;player.process_mode=mode;add_child(player);return player
func _setup_buses() -> void:
    for bus: String in ["Music","SFX","UI"]:
        if AudioServer.get_bus_index(bus)>=0:continue
        AudioServer.add_bus();var index:=AudioServer.bus_count-1
        AudioServer.set_bus_name(index,bus);AudioServer.set_bus_send(index,"Master")
    var found:=false
    for index in AudioServer.get_bus_effect_count(0):
        if AudioServer.get_bus_effect(0,index) is AudioEffectHardLimiter:found=true
    if not found:
        var limiter:=AudioEffectHardLimiter.new();limiter.ceiling_db=-1;AudioServer.add_bus_effect(0,limiter)
func load_preferences() -> void:
    var file:=ConfigFile.new();file.load(PREFERENCES)
    for bus: String in settings.defaults:
        var value: Variant=file.get_value("volume",bus,settings.defaults[bus])
        if not value is float and not value is int:value=settings.defaults[bus]
        set_volume(bus,float(value),false)
func set_volume(bus: String, amount: float, persist: bool=true) -> void:
    var index:=AudioServer.get_bus_index(bus)
    if index<0:return
    volumes[bus]=clampf(amount,0,1)
    AudioServer.set_bus_mute(index,float(volumes[bus])<.001)
    AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,float(volumes[bus]))))
    if persist:save_delay=.35
func save_preferences() -> void:
    var file:=ConfigFile.new()
    for bus: String in volumes:file.set_value("volume",bus,volumes[bus])
    file.save(PREFERENCES)
func get_stream(filename: String, loop: bool=false) -> AudioStream:
    var path:=DIRECTORY+filename
    if not streams.has(path):streams[path]=load(path)
    var stream: AudioStream=streams[path]
    if loop and stream is AudioStreamWAV:
        stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0
        stream.loop_end=int(round(stream.get_length()*stream.mix_rate))
    return stream
func play_sfx(event: String, extra_db: float=0) -> void:
    if not settings.events.has(event):return
    var definition: Dictionary=settings.events[event]
    var ui: bool=definition.get("bus","SFX")=="UI"
    if not ui and get_tree().paused:return
    if event=="ui_hover":
        if hover_time>0:return
        hover_time=.06
    var pool: Array[AudioStreamPlayer]=ui_voices if ui else voices
    var voice: AudioStreamPlayer=pool[0]
    for candidate in pool:
        if not candidate.playing:voice=candidate;break
    if voice.playing:
        pool.pop_front();pool.append(voice);voice.stop()
    voice.stream=get_stream(str(definition.file))
    voice.volume_db=float(definition.db)+extra_db
    var variation: float=definition.get("pitch_variation",0.0)
    voice.pitch_scale=float(definition.get("pitch",1.0))+random.randf_range(-variation,variation)
    if playback_enabled:voice.play()
    sound_played.emit(event)
func play_weapon(slot: int) -> void:play_sfx(["pistol","rifle","sniper"][clampi(slot,1,3)-1])
# Positional effects (zombies). Separate bounded pool; far voices are stolen first.
func play_at(event: String, point: Vector3, extra_db: float=0) -> void:
    if not settings.events.has(event) or get_tree().paused or voices_3d.is_empty():return
    var listener: Vector3=_listener_position()
    var distance: float=listener.distance_to(point)
    if distance>float(settings.spatial.max_distance):return
    var voice: AudioStreamPlayer3D=null;var farthest: float=-1
    for candidate in voices_3d:
        if not candidate.playing:voice=candidate;break
        var d: float=candidate.global_position.distance_to(listener)
        if d>farthest:farthest=d;voice=candidate
    if voice.playing and farthest<distance:return
    var definition: Dictionary=settings.events[event]
    voice.stop();voice.stream=get_stream(str(definition.file));voice.global_position=point
    voice.volume_db=float(definition.db)+extra_db
    var variation: float=definition.get("pitch_variation",0.0)
    voice.pitch_scale=float(definition.get("pitch",1.0))+random.randf_range(-variation,variation)
    if playback_enabled:voice.play()
    sound_played.emit(event)
func _listener_position() -> Vector3:
    var camera: Camera3D=get_viewport().get_camera_3d()
    return camera.global_position if camera else Vector3.ZERO
func bind_game(scene: Node3D) -> void:
    game=scene;foot_distance=0;previous_distance=game.player.distance_m;previous_floor=true
    for voice in voices:voice.stop()
    for voice in voices_3d:voice.stop()
    game.survival.wave.started.connect(func(_number: int):play_sfx("wave_start"))
    game.survival.wave.completed.connect(func(_number: int):play_sfx("wave_clear"))
    game.survival.player_damaged.connect(func(_amount: float):play_sfx("player_hit"))
    game.survival.run_ended.connect(func():play_sfx("ui_error"))
func _process(delta: float) -> void:
    hover_time=maxf(0,hover_time-delta)
    if save_delay>0:
        save_delay=maxf(0,save_delay-delta)
        if save_delay==0:save_preferences()
    var target: float=settings.music.volume_db
    if get_tree().paused:target+=float(settings.music.paused_duck_db)
    music.volume_db=lerpf(music.volume_db,target,1-exp(-delta*3))
func _physics_process(_delta: float) -> void:
    if get_tree().paused or not is_instance_valid(game):return
    var player: CharacterBody3D=game.player
    var travelled: float=maxf(0,player.distance_m-previous_distance);previous_distance=player.distance_m
    if not player.active or game.survival.over:foot_distance=0;previous_floor=true;return
    var grounded:=player.is_on_floor()
    if grounded and not previous_floor:play_sfx("step_path_0",-3)
    previous_floor=grounded
    if not grounded:return
    foot_distance+=minf(travelled,.8)
    if foot_distance<1.6:return
    foot_distance=0;step_index=(step_index+1)%3
    play_sfx(("step_path_" if game.park.is_on_path(player.global_position) else "step_grass_")+str(step_index))
func _exit_tree() -> void:
    save_preferences()
    stop_all()
func stop_all() -> void:
    for voice in voices:voice.stop();voice.stream=null
    for voice in ui_voices:voice.stop();voice.stream=null
    for voice in voices_3d:voice.stop();voice.stream=null
    if music:music.stop();music.stream=null
    streams.clear()
func request_quit() -> void:
    if quitting:return
    quitting=true;save_preferences();stop_all();get_tree().paused=true
    if is_instance_valid(game):game.queue_free()
    await get_tree().create_timer(.15,true).timeout
    get_tree().quit()
