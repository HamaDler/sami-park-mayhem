extends SceneTree
var game: Node3D
var audio: Node
var capture: AudioEffectCapture
var checks: int=0
var failures: Array[String]=[]
var events: Array[String]=[]
const OUT: String="C:/Users/7amad/Documents/Codex/2026-10-11/c-users-7amad-desktop-godot-erbil/outputs"
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    checks+=1
    if value:print("PASS ",message)
    else:failures.append(message);push_error("FAIL "+message)
func delay(seconds: float) -> void:await create_timer(seconds,true).timeout
func run() -> void:
    audio=root.get_node_or_null("GameAudio")
    check(audio!=null,"Persistent audio autoload starts with the project")
    if not audio:quit(1);return
    game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    game.survival.process_mode=Node.PROCESS_MODE_DISABLED
    var initial_volumes: Dictionary=audio.volumes.duplicate()
    audio.sound_played.connect(func(event: String):events.append(event))
    await delay(.4)
    check(audio.music.playing and audio.music.stream.loop,"Background music starts and loops")
    check(audio.voices.size()==24 and audio.ui_voices.size()==6,"Sound voice pools are bounded")
    check(AudioServer.get_bus_index("Music")>0 and AudioServer.get_bus_index("SFX")>0 and AudioServer.get_bus_index("UI")>0,"Music/effects/UI have separate buses")
    check(AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"Master output has a limiter")
    var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
    check(manifest["pistol_shot.wav"].sha256!=manifest["rifle_shot.wav"].sha256 and manifest["rifle_shot.wav"].sha256!=manifest["sniper_shot.wav"].sha256,"Three gun types use different downloaded recordings")
    capture=AudioEffectCapture.new();capture.buffer_length=2;AudioServer.add_bus_effect(0,capture)
    audio.set_volume("Music",0,false)
    var guns: Node3D=game.player.weapons
    guns.grant_weapon(2,0);guns.grant_weapon(3,0)
    var peaks: Dictionary={}
    for slot in range(1,4):
        guns.select_weapon(slot);guns.cooldown=0;capture.clear_buffer();guns.shoot()
        await delay(.38)
        var frames:=capture.get_buffer(capture.get_frames_available());var peak: float=0
        for sample in frames:peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
        peaks[str(slot)]=peak
        check(events.has(["pistol","rifle","sniper"][slot-1]),"Firing slot %d dispatches its own sound" % slot)
        check(peak>.001 and peak<.92,"Slot %d produces non-silent unclipped mixer output" % slot)
    print("AUDIO MIX PEAKS ",JSON.stringify(peaks))
    guns.rounds[guns.selected_slot]=0;guns.reserve[guns.selected_slot]=10;guns.reload_time=0;guns.reload()
    check(events.has("reload_sniper"),"Reload uses the equipped gun's handling sound")
    var cart: CharacterBody3D=game.get_node("GolfCart")
    game.enter_vehicle(cart.get_node("VehicleAccess"),true);await delay(.35)
    var motor: Node3D=cart.get_node("VehicleAudio")
    check(motor.engine.playing and motor.engine.volume_linear>.001,"Entering the cart starts its spatial engine loop")
    var idle_pitch: float=motor.engine.pitch_scale
    cart.set_physics_process(false);cart.speed=40;cart.throttle_amount=1;cart.on_path=true;motor._physics_process(.5)
    check(motor.engine.pitch_scale>idle_pitch and motor.wind.playing,"Speed/throttle increase engine pitch and driving wind")
    cart.handbrake_down=true;cart.drifting=true;cart.slip_angle=.6;motor._physics_process(.5)
    check(motor.skid.playing and motor.skid.volume_linear>.001,"Braking and drifting activate tire squeal")
    cart.rolling=true;motor._physics_process(1)
    check(motor.skid.volume_linear<.001,"Airborne/rolling cart silences tire contact sounds")
    cart.rolling=false;cart.handbrake_down=false;cart.drifting=false;cart.speed=0
    var music_position: float=audio.music.get_playback_position()
    game.hud.set_paused(true);await delay(.2)
    check(motor.engine.stream_paused,"Pause suspends world/vehicle sounds")
    check(audio.music.playing and audio.music.get_playback_position()>music_position,"Music continues while paused")
    var before: int=events.size();audio.play_weapon(1)
    check(events.size()==before,"Paused gameplay cannot trigger gun sounds")
    audio.play_sfx("ui_click")
    check(events.back()=="ui_click" and audio.ui_voices.any(func(v: AudioStreamPlayer):return v.playing),"UI sounds remain active in menus")
    audio.hover_time=0;game.hud.pause_overlay.tabs[2].mouse_entered.emit()
    check(events.back()=="ui_hover","Actual menu button hover dispatches its cue")
    game.hud.pause_overlay.tabs[2].pressed.emit()
    check(events.back()=="ui_click" and game.hud.pause_overlay.current_tab==2,"Actual menu button click dispatches audio and opens its tab")
    game.hud.pause_overlay.show_tab(2)
    var options: Control=game.hud.pause_overlay.views[2]
    check(options.sliders.size()==4,"Pause audio tab exposes four volume controls")
    options.sliders.Music.value=22
    check(is_equal_approx(float(audio.volumes.Music),.22),"Music slider changes only the music bus")
    audio.set_volume("SFX",0,false)
    check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Zero volume fully mutes the effects bus")
    audio.save_preferences();audio.set_volume("Music",.9,false);audio.load_preferences()
    check(is_equal_approx(float(audio.volumes.Music),.22),"Volume settings persist through reload")
    options.sliders.Music.value=65;options.sliders.SFX.value=85
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUT+"/audio-options.png")
    game.hud.set_paused(false);await delay(.1)
    check(not motor.engine.stream_paused,"Resuming restores vehicle playback")
    cart.set_control_enabled(false);motor._physics_process(2)
    check(not motor.engine.playing,"Leaving a parked cart fades its engine out")
    var music_id: int=audio.music.get_instance_id();music_position=audio.music.get_playback_position()
    game.hud.survival_overlay.restart();await delay(.4);game=current_scene
    check(audio.music.get_instance_id()==music_id and audio.music.get_playback_position()>music_position,"Run restart preserves continuous music instead of stacking/restarting it")
    check(root.get_node("GameAudio")==audio and audio.voices.size()==24,"Restart keeps one audio manager and the same voice limit")
    for bus: String in initial_volumes:audio.set_volume(bus,float(initial_volumes[bus]),false)
    audio.save_preferences()
    AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1);capture=null
    audio.stop_all();game.queue_free();await delay(.2)
    print("AUDIO VALIDATION: ",checks," checks; ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
