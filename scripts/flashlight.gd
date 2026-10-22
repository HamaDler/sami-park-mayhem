extends Node3D
# Hand-held flashlight. It sits just right of and below the eyes, aims at the crosshair a few
# metres ahead, and trails fast camera turns slightly like a light held in a hand.
# It is put away while driving (the cart has headlights instead).
const BODY_LAYER: int=1<<10
const VIEWMODEL_LAYER: int=1<<11
const ALL_LAYERS: int=0xFFFFF
const HAND_OFFSET:=Vector3(.17,-.15,-.10)
const AIM_DISTANCE: float=12.0
var camera: Camera3D
var beam: SpotLight3D
var spill: SpotLight3D
var on: bool=true
var stowed: bool=false
func initialize(view: Camera3D) -> void:
    camera=view
    top_level=true
    beam=SpotLight3D.new();beam.name="Beam"
    beam.light_color=Color(1.0,.9,.64);beam.light_energy=1.45;beam.light_indirect_energy=0
    beam.spot_range=42;beam.spot_angle=17;beam.spot_angle_attenuation=.4;beam.spot_attenuation=.9
    beam.shadow_enabled=true;beam.shadow_bias=.04;beam.shadow_normal_bias=1.2
    # Your own body and weapon never block the beam or show up blown out in it.
    beam.light_cull_mask=ALL_LAYERS&~VIEWMODEL_LAYER
    beam.shadow_caster_mask=ALL_LAYERS&~(BODY_LAYER|VIEWMODEL_LAYER)
    add_child(beam)
    spill=SpotLight3D.new();spill.name="Spill"
    spill.light_color=beam.light_color;spill.light_energy=.22;spill.light_indirect_energy=0
    spill.spot_range=16;spill.spot_angle=40;spill.spot_angle_attenuation=1.6
    spill.light_cull_mask=beam.light_cull_mask
    add_child(spill)
    _apply()
func toggle() -> bool:
    on=not on;_apply()
    GameUI.play_ui("ui_click")
    return on
func set_on(value: bool) -> void:on=value;_apply()
func set_stowed(value: bool) -> void:stowed=value;_apply()
func is_lit() -> bool:return on and not stowed
func _apply() -> void:
    if beam:beam.visible=is_lit();spill.visible=is_lit()
    if is_lit():snap()
func snap() -> void:
    if camera and is_inside_tree() and camera.is_inside_tree():global_transform=_hand_transform()
func _hand_transform() -> Transform3D:
    var aim:=Vector3(-HAND_OFFSET.x,-HAND_OFFSET.y,-AIM_DISTANCE-HAND_OFFSET.z).normalized()
    return camera.global_transform*Transform3D(Basis.looking_at(aim),HAND_OFFSET)
func _process(delta: float) -> void:
    if camera==null or not is_lit():return
    var hand:=_hand_transform()
    var from: Quaternion=global_basis.orthonormalized().get_rotation_quaternion()
    var to: Quaternion=hand.basis.orthonormalized().get_rotation_quaternion()
    global_transform=Transform3D(Basis(from.slerp(to,1-exp(-delta*16))),hand.origin)
