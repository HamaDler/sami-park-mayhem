extends Node3D
var survival: Node3D
var display_name: String
var actions: Array[Dictionary]=[]
var roll_time: float=0
var reward_time: float=0
var reward: Dictionary={}
var preview: Node3D
var lid: Node3D
var rolling: bool=false
var banner: Label3D
var spin_time: float=0
func initialize(session: Node3D, location: String) -> void:
    survival=session;display_name=location
    var wood:=ParkGeometry.material(Color("3a2927"));var metal:=ParkGeometry.material(Color("20292d"));var gold:=ParkGeometry.material(Color("ccab53"))
    ParkGeometry.box(self,Vector3(0,.56,0),Vector3(2.2,1.1,1.0),wood,true)
    for x in [-.8,.8]:ParkGeometry.box(self,Vector3(x,.57,0),Vector3(.10,1.17,1.06),metal)
    lid=Node3D.new();lid.position=Vector3(0,1.11,.5);add_child(lid)
    ParkGeometry.box(lid,Vector3(0,.05,-.5),Vector3(2.26,.12,1.06),wood)
    for x in [-.65,.65]:
        var mark:=Label3D.new();mark.text="?";GameUI.style_sign(mark,18);mark.font_size=96;mark.pixel_size=.008;mark.position=Vector3(x,.65,-.514);add_child(mark)
    banner=GameUI.world_sign(self,"MYSTERY BOX","%d IQD" % int(survival.config.economy.box_price),Vector3(0,3.0,0),Color("ffd268"))
    actions.append({"kind":"box","position":Vector3.ZERO,"station":self})
    var ammo:=Node3D.new();ammo.position=Vector3(3.8,0,0);add_child(ammo)
    ParkGeometry.box(ammo,Vector3(0,.55,0),Vector3(1,1.1,.9),metal,true)
    ParkGeometry.box(ammo,Vector3(0,1.15,0),Vector3(1.1,.12,1),gold)
    GameUI.world_sign(ammo,"AMMO","%d IQD" % int(survival.config.economy.ammo_price),Vector3(0,2.0,0),Color("85d2f4"))
    actions.append({"kind":"ammo","position":ammo.position,"station":self})
    var repair:=Node3D.new();repair.position=Vector3(0,0,4.8);add_child(repair)
    ParkGeometry.box(repair,Vector3(0,.6,0),Vector3(1.2,1.2,.7),metal,true)
    GameUI.world_sign(repair,"CART REPAIR","%d IQD" % int(survival.config.economy.repair_price),Vector3(0,2.0,0),Color("9deb91"))
    actions.append({"kind":"repair","position":repair.position,"station":self})
    var workshop:=Node3D.new();workshop.position=Vector3(3.8,0,4.8);add_child(workshop)
    ParkGeometry.box(workshop,Vector3(0,.6,0),Vector3(1.5,1.2,.7),metal,true)
    ParkGeometry.box(workshop,Vector3(0,1.25,0),Vector3(1.6,.12,.9),gold)
    GameUI.world_sign(workshop,"CART WORKSHOP","Bumper · Armor · Handling",Vector3(0,3.0,0),Color("c5ed55"))
    actions.append({"kind":"upgrade","position":workshop.position,"station":self})
func prompt(kind: String) -> String:
    if kind=="upgrade":return "F  /  CART WORKSHOP"
    if kind=="ammo":return "F  /  REFILL AMMO   %d IQD" % int(survival.config.economy.ammo_price)
    if kind=="repair":return "F  /  REPAIR CART   %d IQD   [%ds]" % [int(survival.config.economy.repair_price),ceili(survival.config.economy.repair_seconds)]
    if rolling:return "MYSTERY BOX OPENING…"
    if not reward.is_empty():return "F  /  CLAIM "+survival.weapon_title(int(reward.slot),int(reward.tier))
    return "F  /  MYSTERY BOX   %d IQD" % int(survival.config.economy.box_price)
func use(kind: String) -> void:
    if kind=="upgrade":survival.game.hud.survival_overlay.workshop.open(survival,self);return
    if kind=="box" and rolling:return
    var economy: Dictionary=survival.config.economy
    if kind=="ammo":
        if survival.game.player.weapons.ammo_full():survival.announce("AMMO ALREADY FULL");return
        if survival.spend(int(economy.ammo_price)):survival.game.player.weapons.refill_selected();survival.announce("AMMUNITION REFILLED")
    elif kind=="repair":survival.begin_repair(self)
    elif not reward.is_empty():
        survival.game.player.weapons.grant_weapon(int(reward.slot),int(reward.tier))
        survival.announce("CLAIMED "+survival.weapon_title(int(reward.slot),int(reward.tier)))
        clear_reward()
    elif not rolling and survival.spend(int(economy.box_price)):
        reward=survival.roll_weapon();rolling=true;roll_time=float(economy.box_reveal_seconds);spin_time=0
        _preview(survival.enemies.random.randi_range(1,3));GameUI.set_sign(banner,"ROLLING…")
func _preview(slot: int) -> void:
    if preview:preview.queue_free()
    preview=load(["res://scenes/weapons/pistol.tscn","res://scenes/weapons/rifle.tscn","res://scenes/weapons/sniper.tscn"][slot-1]).instantiate()
    preview.position=Vector3(0,1.95,0);preview.scale=Vector3.ONE*2.1;add_child(preview)
func clear_reward() -> void:
    if preview:preview.queue_free();preview=null
    reward.clear();reward_time=0;GameUI.set_sign(banner,"MYSTERY BOX","%d IQD" % int(survival.config.economy.box_price))
func _physics_process(delta: float) -> void:
    if not survival or survival.over:return
    lid.rotation.x=lerpf(lid.rotation.x,-1.2 if rolling or not reward.is_empty() else 0.0,1-exp(-delta*8))
    if preview:preview.rotation.y+=delta*1.3
    if rolling:
        roll_time-=delta;spin_time+=delta
        if spin_time>.18:spin_time=0;_preview(survival.enemies.random.randi_range(1,3))
        if roll_time<=0:
            GameUI.play_ui("ui_confirm")
            rolling=false;reward_time=float(survival.config.economy.reward_seconds);_preview(int(reward.slot))
            GameUI.set_sign(banner,survival.weapon_title(int(reward.slot),int(reward.tier)),"F to claim");survival.announce("MYSTERY BOX READY — F TO CLAIM")
    elif not reward.is_empty():
        reward_time-=delta
        if reward_time<=0:clear_reward()
