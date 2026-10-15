extends Node
signal started(number: int)
signal completed(number: int)
var settings: Dictionary
var number: int=0
var total: int=0
var spawned: int=0
var killed: int=0
var active_limit: int=0
var preparation: float=0
var running: bool=false
func initialize(config: Dictionary) -> void:
    settings=config
    preparation=float(settings.initial_delay)
func tick(delta: float) -> void:
    if running:return
    preparation=maxf(0,preparation-delta)
    if preparation==0:begin_next()
func begin_next() -> void:
    number+=1
    total=int(settings.first_total)+(number-1)*int(settings.total_increment)
    active_limit=mini(int(settings.max_active),int(settings.first_active)+(number-1)*int(settings.active_increment))
    spawned=0;killed=0;running=true;started.emit(number)
func can_spawn(alive: int) -> bool:return running and spawned<total and alive<active_limit
func register_spawn() -> void:spawned+=1
func register_kill() -> void:
    if not running:return
    killed+=1
    if killed>=total and spawned>=total:
        running=false;preparation=float(settings.preparation_seconds);completed.emit(number)
func remaining() -> int:return maxi(0,total-killed)
