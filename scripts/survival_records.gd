extends RefCounted
# Only records survive a run. Never deserialize executable resources from user://.
const PATH: String="user://survival_records.json"
var best_score: int=0
var best_wave: int=0
var lifetime_kills: int=0
func load_records() -> void:
    if not FileAccess.file_exists(PATH):return
    var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not parsed is Dictionary:return
    best_score=maxi(0,int(parsed.get("best_score",0)))
    best_wave=maxi(0,int(parsed.get("best_wave",0)))
    lifetime_kills=maxi(0,int(parsed.get("lifetime_kills",0)))
func save_records(score: int, completed_wave: int) -> void:
    best_score=maxi(best_score,score);best_wave=maxi(best_wave,completed_wave)
    var file:=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
    if file==null:return
    file.store_string(JSON.stringify({"version":1,"best_score":best_score,"best_wave":best_wave,"lifetime_kills":lifetime_kills}))
    file.close()
    DirAccess.rename_absolute(PATH+".tmp",PATH)
