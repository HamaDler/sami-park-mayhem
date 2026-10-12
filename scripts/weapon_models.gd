class_name WeaponModels
extends RefCounted
const SCENES: Array[PackedScene]=[
    preload("res://scenes/weapons/pistol.tscn"),
    preload("res://scenes/weapons/rifle.tscn"),
    preload("res://scenes/weapons/sniper.tscn")
]
static func build(slot: int) -> Node3D:
    return SCENES[slot-1].instantiate() as Node3D
