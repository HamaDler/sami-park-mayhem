extends Node3D
func _ready() -> void:
    _setup_inputs()
    $GolfCart.initialize($SamiPark)
    $ChaseCamera.initialize($GolfCart)
    $HUD.initialize($GolfCart,$SamiPark)
    $GolfCart.recovered.connect(func(_reason):$ChaseCamera.snap())
    get_window().focus_exited.connect(func():$HUD.set_paused(true))
func _setup_inputs() -> void:
    var bindings: Dictionary = {
        "accelerate":[KEY_W,KEY_UP],"reverse":[KEY_S,KEY_DOWN],
        "left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],
        "brake":[KEY_SPACE],"recover":[KEY_R],"pause":[KEY_ESCAPE],"map_toggle":[KEY_M]
    }
    for action in bindings:
        if not InputMap.has_action(action):InputMap.add_action(action)
        for key in bindings[action]:
            var event:=InputEventKey.new()
            event.physical_keycode=key
            InputMap.action_add_event(action,event)
