extends Node3D
var survival: Node3D
var pickups: Array[Dictionary]=[]
var infinite_ammo: float=0
var double_dinars: float=0
var random:=RandomNumberGenerator.new()
func initialize(session: Node3D) -> void:survival=session;random.randomize()
func maybe_drop(point: Vector3) -> void:
    if random.randf()>float(survival.config.powerups.drop_chance):return
    spawn_pickup(point,random.randi_range(0,2))
func spawn_pickup(point: Vector3, kind: int) -> void:
    if pickups.size()>=12:
        pickups[0].node.queue_free();pickups.pop_front()
    var node:=Node3D.new();add_child(node);node.global_position=Vector3(point.x,.1,point.z)
    var color: Color=[Color("84ef8a"),Color("ffd268"),Color("7dcdf8")][kind]
    var material:=ParkGeometry.material(color);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    var item:=ParkGeometry.box(node,Vector3(0,1,0),Vector3(.6,.6,.6),material);item.rotation.z=PI*.25
    var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.6;torus.outer_radius=.68;ring.mesh=torus;ring.material_override=material;ring.position.y=.12;node.add_child(ring)
    var label:=Label3D.new();label.text=["INFINITE AMMO","DOUBLE DINARS","MAX AMMO"][kind];GameUI.style_sign(label,12);GameUI.close_up(label,18);label.font_size=38;label.pixel_size=.009;label.position.y=1.8;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=false;node.add_child(label)
    pickups.append({"node":node,"kind":kind,"life":float(survival.config.powerups.pickup_lifetime),"phase":0.0})
func collect(kind: int) -> void:
    GameUI.play_ui("pickup")
    if kind==0:
        infinite_ammo=float(survival.config.powerups.infinite_ammo_seconds)
        survival.game.player.weapons.reload_time=0
    elif kind==1:double_dinars=float(survival.config.powerups.double_dinars_seconds)
    else:survival.game.player.weapons.refill_all()
    survival.game.player.weapons.infinite_ammo=infinite_ammo>0
    survival.announce(["INFINITE AMMO — %ds" % ceili(infinite_ammo),"DOUBLE DINARS — %ds" % ceili(double_dinars),"MAX AMMO"][kind])
func _physics_process(delta: float) -> void:
    if not survival or survival.over:return
    infinite_ammo=maxf(0,infinite_ammo-delta);double_dinars=maxf(0,double_dinars-delta)
    survival.game.player.weapons.infinite_ammo=infinite_ammo>0
    var actor_point: Vector3=survival.game.get_active_actor().global_position
    for index in range(pickups.size()-1,-1,-1):
        var item: Dictionary=pickups[index];item.life-=delta;item.phase+=delta
        item.node.rotation.y+=delta*1.4;item.node.get_child(0).position.y=1+sin(float(item.phase)*3)*.12
        item.node.visible=float(item.life)>5 or fmod(float(item.life),.35)>.1
        var close: bool=Vector2(actor_point.x,actor_point.z).distance_to(Vector2(item.node.global_position.x,item.node.global_position.z))<(3.0 if survival.game.is_driving() else 1.65)
        if close:collect(int(item.kind))
        if close or float(item.life)<=0:item.node.queue_free();pickups.remove_at(index)
