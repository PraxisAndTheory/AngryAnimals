extends Node2D


const ANIMAL = preload("res://scenes/animal/animal.tscn")

@onready var animal_start = $AnimalStart


# Called when the node enters the scene tree for the first time.
func _ready():
	SignalManager.on_animal_died.connect(add_animal)
	add_animal()


func add_animal() -> void:
	var new_animal = ANIMAL.instantiate()
	new_animal.position = animal_start.position
	add_child(new_animal)
