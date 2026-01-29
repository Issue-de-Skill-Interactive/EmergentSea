extends Node2D

# Liste des navires créés
@export var liste_navires : Dictionary= {}

# Liste des joueurs
@export var liste_joueurs : Dictionary= {
	1: { "nom": "Joueur 1", "couleur": Color.BLUE, "is_player": true },   # Joueur humain
	2: { "nom": "Joueur 2", "couleur": Color.RED, "is_player": false }     # Ennemi (immobile)
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _enter_tree():
	add_to_group("shared_entities")

func getPlayerList() -> Dictionary:
	return liste_joueurs;

# permet de récupérer la liste des navires sur une case précise
func getNavireByPosition(pos:Vector2i) -> Array:
	# liste des navires trouvés
	var found : Array
	if(not liste_navires.is_empty()):
		for ship in liste_navires.values():
			if(ship.getPosition()):
				found.append(ship)
			
	return found
