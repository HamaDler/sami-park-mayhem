extends Node
var survival: Node3D
var settings: Dictionary
var levels: Dictionary={"bumper":0,"armor":0,"handling":0}
var base_driving: Resource
var base_health: float
var ram_damage: float=1
var ram_wear: float=1
var damage_received: float=1
func initialize(session: Node3D) -> void:
    survival=session
    settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicle_upgrades.json"))
    var cart: CharacterBody3D=survival.game.get_node("GolfCart")
    base_driving=cart.settings.duplicate();cart.settings=cart.settings.duplicate()
    base_health=cart.max_health
func cost(kind: String) -> int:
    if not levels.has(kind) or int(levels[kind])>=3:return 0
    return int(settings[kind].costs[int(levels[kind])])
func service_available(station: Node3D) -> bool:
    if survival.over or survival.game.is_driving() or get_tree().paused or not is_instance_valid(station):return false
    var cart: CharacterBody3D=survival.game.get_node("GolfCart")
    return cart.health>0 and not cart.rolling and absf(cart.speed)<.5 and cart.velocity.length()<1 and cart.global_position.distance_to(station.global_position)<=float(settings.service_distance) and survival.game.player.global_position.distance_to(station.to_global(Vector3(3.8,0,4.8)))<4
func purchase(kind: String, station: Node3D) -> bool:
    if not levels.has(kind) or int(levels[kind])>=3:return false
    if not service_available(station):survival.announce("PARK AN UPRIGHT CART NEAR THE WORKSHOP");return false
    if not survival.spend(cost(kind)):return false
    grant(kind);survival.announce("%s  /  LEVEL %d" % [settings[kind].name,levels[kind]])
    return true
func grant(kind: String) -> bool:
    if not levels.has(kind) or int(levels[kind])>=3:return false
    levels[kind]=int(levels[kind])+1
    var cart: CharacterBody3D=survival.game.get_node("GolfCart")
    var ratio: float=cart.health/cart.max_health
    cart.max_health=base_health*float(settings.armor.health[int(levels.armor)])
    # An upgrade preserves damage percentage; it cannot resurrect or repair the cart.
    cart.health=cart.max_health*ratio
    damage_received=float(settings.armor.damage_received[int(levels.armor)])
    ram_damage=float(settings.bumper.ram_damage[int(levels.bumper)])
    ram_wear=float(settings.bumper.ram_wear[int(levels.bumper)])
    var level: int=levels.handling
    cart.settings.road_traction=base_driving.road_traction*float(settings.handling.grip[level])
    cart.settings.grass_traction=base_driving.grass_traction*float(settings.handling.grip[level])
    cart.settings.brake_deceleration=base_driving.brake_deceleration*float(settings.handling.brakes[level])
    cart.settings.rollover_lateral_acceleration=base_driving.rollover_lateral_acceleration*float(settings.handling.stability[level])
    _visuals(cart)
    return true
func grant_random() -> String:
    var available: Array[String]=[]
    for kind: String in levels:
        if int(levels[kind])<3:available.append(kind)
    if available.is_empty():return ""
    var kind: String=available[survival.enemies.random.randi_range(0,available.size()-1)]
    grant(kind)
    return str(settings[kind].name)
func _visuals(cart: CharacterBody3D) -> void:
    var old: Node=cart.visual.get_node_or_null("UpgradeParts")
    if old:cart.visual.remove_child(old);old.queue_free()
    var parts:=Node3D.new();parts.name="UpgradeParts";cart.visual.add_child(parts)
    var dark:=ParkGeometry.material(Color("26333b"),.5)
    var steel:=ParkGeometry.material(Color("9fabb1"),.4)
    if int(levels.bumper)>0:
        ParkGeometry.box(parts,Vector3(0,.42,-1.49),Vector3(1.55,.15+.05*int(levels.bumper),.17),steel)
        for x in [-.55,.55]:ParkGeometry.box(parts,Vector3(x,.63,-1.49),Vector3(.12,.5,.13),dark)
    if int(levels.armor)>0:
        for x in [-.71,.71]:ParkGeometry.box(parts,Vector3(x,.6,0),Vector3(.09,.38,1.7),dark)
        ParkGeometry.box(parts,Vector3(0,.36,1.36),Vector3(1.3,.25,.1),steel)
    if int(levels.handling)>0:
        for x in [-.7,.7]:ParkGeometry.box(parts,Vector3(x,.22,0),Vector3(.07,.08,1.3),ParkGeometry.material(Color("c5ed55")))
