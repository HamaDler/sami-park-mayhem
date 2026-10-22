extends Control
var sliders: Dictionary={}
var credits: AcceptDialog
func _ready() -> void:
    GameUI.label(self,"AUDIO",Vector2.ZERO,GameUI.SIZE_HEADING,GameUI.WHITE,true)
    GameUI.label(self,"Music, combat, engine and interface volume. Changes save automatically.",Vector2(0,38),GameUI.SIZE_BODY,GameUI.MUTED)
    var audio: Node=GameUI.audio_manager()
    var buses: Array[String]=["Master","Music","SFX","UI"]
    for index in buses.size():
        var bus: String=buses[index];var y: float=65+index*66
        var panel:=Panel.new();panel.position=Vector2(0,y);panel.size=Vector2(500,54)
        panel.add_theme_stylebox_override("panel",GameUI.style(GameUI.PANEL));add_child(panel)
        GameUI.label(panel,["MASTER","MUSIC","EFFECTS","INTERFACE"][index],Vector2(12,16),GameUI.SIZE_LABEL+1,GameUI.WHITE,true)
        var percentage:=GameUI.label(panel,"",Vector2(446,16),GameUI.SIZE_LABEL+1,GameUI.LIME,true)
        var slider:=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=1
        slider.position=Vector2(160,14);slider.size=Vector2(278,28);slider.modulate=GameUI.LIME;panel.add_child(slider)
        slider.value=roundi(float(audio.volumes[bus])*100) if audio else 80
        percentage.text=str(int(slider.value))+"%";sliders[bus]=slider
        slider.value_changed.connect(func(value: float):
            percentage.text=str(int(value))+"%"
            if audio:audio.set_volume(bus,value/100))
        slider.mouse_entered.connect(func():GameUI.play_ui("ui_hover"))
        slider.focus_entered.connect(func():GameUI.play_ui("ui_hover"))
    credits=AcceptDialog.new();credits.title="AUDIO CREDITS";credits.dialog_text="EmptyCity — yd (CC0)\nFirearms — Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney (CC0)\nUI / footsteps / impacts — Kenney (CC0)\nEngine loops — domasx2 (CC0)\nWind — Luke.RUSTLTD (CC0)\n\nTire squeal — audible-edge (Tom Haigh), loop edit by qubodup\nCreative Commons Attribution 3.0\nhttps://opengameart.org/content/car-tire-squeal-skid-loop\nhttps://creativecommons.org/licenses/by/3.0/\nEdited: resampled, mono, normalized, loop crossfade.\n\nAll sources and licenses: assets/audio/CREDITS.md"
    add_child(credits)
    GameUI.button(self,"AUDIO CREDITS",Vector2(0,338),Vector2(500,42),func():credits.popup_centered(Vector2i(730,410)))
