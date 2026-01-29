extends Node2D

# Liste des navires créés
@export var navires := {}

# Liste des joueurs
@export var joueurs := {
	1: { "nom": "Joueur 1", "couleur": Color.BLUE },
	2: { "nom": "Joueur 2", "couleur": Color.RED }
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _enter_tree():
	add_to_group("shared_entities")
