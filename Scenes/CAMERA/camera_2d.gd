###===================================================================###
##							Script de Caméra						   ##
# Ce script permet de controller la caméra du joueur					#
# Parmi les fonctions proposées, il y a :								#
#  - la possibilité de déplacer la caméra dans la direction voulue		#
#  - il est possible de zoomer et dézoomer								#
#  - on peut déplacer la caméra à un point voulu						#
##																	   ##
###===================================================================###


extends Camera2D

@export var speed := 3600.0
@export var min_zoom := 0.1
@export var max_zoom := 3.0
@export var zoom_step := 0.15



var target_zoom := Vector2.ONE
var follow_target: Node2D
var follow_once := true

func _enter_tree():
	add_to_group("camera_controller")

func _ready():
	make_current()

func _input(event):
	# Zoom molette
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= Vector2(zoom_step, zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += Vector2(zoom_step, zoom_step)
		target_zoom = target_zoom.clamp(
			Vector2(min_zoom, min_zoom),
			Vector2(max_zoom, max_zoom)
		)

func set_target(target: Node2D):
	follow_target = target
	global_position = target.global_position  # caméra centrée au démarrage

func _process(delta):
	# Zoom fluide
	zoom = zoom.lerp(target_zoom, 0.2)
	
	# Si on doit suivre le navire au tout début
	if follow_once and follow_target:
		global_position = follow_target.global_position
		follow_once = false  # ensuite on arrête de suivre
		return

	# Déplacement libre
	var move := Vector2.ZERO
	if Input.is_action_pressed("ui_up"): move.y -= speed * delta
	if Input.is_action_pressed("ui_down"): move.y += speed * delta
	if Input.is_action_pressed("ui_left"): move.x -= speed * delta
	if Input.is_action_pressed("ui_right"): move.x += speed * delta

	global_position += move
