extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
    checks+=1
    if condition:print("PASS: ",message)
    else:failures+=1;push_error("FAIL: "+message)
func frames(count: int = 3) -> void:
    for i in count:await process_frame
func run() -> void:
    var game=load("res://scenes/main.tscn").instantiate()
    root.add_child(game);current_scene=game
    for connection in root.focus_exited.get_connections():root.focus_exited.disconnect(connection.callable)
    await frames()
    var crowd=game.get_node("Crowd")
    var park=game.get_node("SamiPark")
    var hud=game.get_node("HUD")
    hud.set_paused(false)
    check(crowd.initialized and crowd.people.size()==1000,"Park initializes all 1000 visitors")
    check(crowd.variants.size()==12,"Twelve civilian outfits are available from both packs")
    var genders: Dictionary={"men":0,"women":0}
    var animations: Dictionary={}
    var ids: Dictionary={}
    var initial: Array[Vector2]=[]
    var safe:=true
    var walkers:=0
    for p in crowd.people:
        var state: Dictionary=crowd.get_person_state(p.id)
        genders[state.gender]+=1;ids[p.id]=true
        animations[state.animation]=true
        if state.animation=="Walk":walkers+=1
        initial.append(p.position)
        if not park._map_land_rejection(p.position).is_empty() or park.path_distance(p.position)>.5:safe=false
    check(genders.men==500 and genders.women==500,"Population contains an even randomized mix of men and women")
    check(ids.size()==1000,"Each visitor has a unique persistent mission ID")
    check(walkers>750,"Most visitors begin walking")
    check(animations.size()>=3,"Visitors use varied walking and non-combat idle animations")
    check(safe,"Visitors spawn on safe park paths outside water and buildings")
    check(crowd.visible_count>0 and crowd.visible_count<1000,"Only nearby visitors are submitted for rendering")
    check(crowd.find_children("*","Skeleton3D",true,false).is_empty(),"Crowd animation does not create 1000 live skeletons")
    var arrival_count: Dictionary={"value":0}
    crowd.person_arrived.connect(func(_person_id: int,_junction: int):arrival_count.value+=1)
    var start:=Time.get_ticks_usec()
    for step in 200:
        crowd.animation_clock+=.05
        crowd._simulate(.05,Vector2(4000,4000))
    var cost:=Time.get_ticks_usec()-start
    var moved:=0
    safe=true
    for p in crowd.people:
        if p.position.distance_to(initial[p.id])>1:moved+=1
        if not park._map_land_rejection(p.position).is_empty() or park.path_distance(p.position)>.5:safe=false
    check(moved>700,"Most visitors make progress along paths over ten seconds")
    check(arrival_count.value>0,"Visitors traverse connected path junctions and emit arrival events")
    check(safe,"Walking remains on safe paths after route changes")
    var person=crowd.people[0]
    crowd.set_person_paused(0,true)
    var held: Vector2=person.position
    crowd._simulate(1,Vector2(4000,4000))
    check(person.position==held and crowd.get_person_state(0).state=="idle","Mission hooks can hold an individual visitor")
    person.mission_data["test_objective"]="meet_player"
    check(crowd.get_person_state(0).mission_data.test_objective=="meet_player","Mission metadata persists independently of rendering")
    crowd.set_person_paused(0,false)
    person.wait=0
    crowd._simulate(1,Vector2(4000,4000))
    check(person.position.distance_to(held)>.1,"Released visitors resume their route")
    var nearest: int=crowd.nearest_person(person.position,.1)
    check(nearest>=0,"Future interactions can find a nearby visitor by ID")
    var before: Vector2=person.position
    crowd._simulate(.05,person.position)
    check(person.position.is_equal_approx(before),"Visitors stop when the active actor is in their clearance area")
    crowd.refresh()
    check(crowd.batches.size()<200,"Visible visitors share a bounded set of spatial render batches")
    var clock_before: float=crowd.animation_clock
    hud.open_map()
    await frames(8)
    check(crowd.animation_clock==clock_before,"Crowd movement and animation clock pause while browsing the map")
    hud.close_map()
    await frames(4)
    check(crowd.animation_clock>clock_before,"Crowd resumes after closing the map")
    game.teleport_active(Vector2(445,-76.47),0)
    check(crowd.last_actor_position.distance_to(Vector2(445,-76.47))<.1,"Map travel immediately refreshes the visible crowd")
    print("CROWD_PROFILE: ",cost/200.0," us per simulation tick for 1000 people")
    print("CROWD_RESULT: ",checks," checks, ",failures," failures")
    quit(failures)
