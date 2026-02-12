class_name UI_stats_navire
extends Node

var navire : Navires
var stats_panel : Panel
var vie_label: Label
var energie_label: Label
var equipage_label: Label
var nourriture_label: Label
var stats_timer := 0.0
var stats_visible := false

# =========================
# UI STATS - DEUX PANNEAUX
# =========================
# Panneau pour navire allié (à droite)
@export var stats_panel_ally: Panel
var vie_label_ally: Label
var energie_label_ally: Label
var equipage_label_ally: Label
var nourriture_label_ally: Label

# Panneau pour navire ennemi (à gauche)
var stats_panel_enemy: Panel
var vie_label_enemy: Label
var energie_label_enemy: Label
var equipage_label_enemy: Label
var nourriture_label_enemy: Label


const stats_duration: float = 2.5

#Couleurs Player
const color_bg_player : Color = Color(0, 0.2, 0.4, 0.8)  # Bleu pour le joueur
const color_txt_player : Color = Color(0.5, 0.8, 1)

#Couleurs Enemy
const color_bg_enemy : Color = Color(0.4, 0, 0, 0.8)  # Rouge pour l'ennemi
const color_txt_enemy : Color = Color(1, 0.5, 0.5)

var ui_layer: CanvasLayer


func _init(ship : Navires) -> void:
	self.navire = ship
	navire.add_child(self)
	navire.sig_show_stats.connect(handler)
	
	#build_ui()
	##### SOLUTION TEMPORAIRE PARCE QUE SINON CA MARCHE PAS
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		push_error("ERREUR : ui_layer est null, impossible de créer l'UI des stats!")
		return
	# Créer le panneau allié (à droite)
	_create_ally_stats_panel()
	
	# Créer le panneau ennemi (à gauche)
	_create_enemy_stats_panel()

func _process(delta):
	if isVisible():
		stats_timer -= delta
		update()
		if stats_timer <= 0:
			hide()

func isVisible() -> bool:
	return stats_visible

func build_ui():
	await get_tree().process_frame
	ui_layer = get_tree().get_first_node_in_group("ui_layer")
	if not ui_layer:
		push_error("ERREUR : ui_layer est null, impossible de créer l'UI des stats!")
		return
	stats_panel = Panel.new()
	stats_panel.visible = false

	stats_panel.anchor_left = 1
	stats_panel.anchor_top = 0
	stats_panel.anchor_right = 1
	stats_panel.anchor_bottom = 0
	stats_panel.offset_left = -180
	stats_panel.offset_top = 20
	stats_panel.offset_right = -20
	stats_panel.offset_bottom = 110

	var style := StyleBoxFlat.new()
	if navire.is_player_ship:
		style.bg_color = color_bg_player
	else:
		style.bg_color = color_bg_enemy
	
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	stats_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_child(vbox)

	# Titre (JOUEUR ou ENNEMI)
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if navire.is_player_ship:
		title_label.text = "🚢 JOUEUR"
		title_label.add_theme_color_override("font_color", color_txt_player)
	else:
		title_label.text = "☠️ ENNEMI"
		title_label.add_theme_color_override("font_color", color_txt_enemy)
	vbox.add_child(title_label)

	vie_label = Label.new()
	energie_label = Label.new()
	nourriture_label = Label.new()
	equipage_label = Label.new()
	nourriture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label)
	vbox.add_child(energie_label)
	vbox.add_child(equipage_label)
	vbox.add_child(nourriture_label)
	
	
	ui_layer.add_child(stats_panel)
	print(">>> UI Stats créée pour navire ", "JOUEUR" if navire.is_player_ship else "ENNEMI")





func handler():
	if isVisible():
		hide()
	else:
		show()

func show():
	if not stats_panel:
		push_warning("ATTENTION : Pas de stats_panel pour afficher les stats!")
		return
		
	stats_visible = true
	stats_timer = stats_duration
	stats_panel.visible = true
	update()

func hide():
	if not stats_panel:
		return
		
	stats_visible = false
	stats_panel.visible = false

func update():
	if not stats_panel or not vie_label or not energie_label or not equipage_label:
		return
		
	vie_label.text = "❤️ %d / %d" % [navire.vie, navire.maxvie]
	energie_label.text = "⚡ %d / %d" % [navire.energie, navire.maxenergie]
	equipage_label.text = "👥 %d" % navire.nrbequipage
	nourriture_label.text = "🐟 %d" % navire.nourriture




func _create_ally_stats_panel():
	"""Crée le panneau de stats pour les navires alliés (à droite)"""
	stats_panel_ally = Panel.new()
	stats_panel_ally.visible = false

	stats_panel_ally.anchor_left = 1
	stats_panel_ally.anchor_top = 0
	stats_panel_ally.anchor_right = 1
	stats_panel_ally.anchor_bottom = 0
	stats_panel_ally.offset_left = -180
	stats_panel_ally.offset_top = 20
	stats_panel_ally.offset_right = -20
	stats_panel_ally.offset_bottom = 110

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0.2, 0.4, 0.9)  # Bleu pour allié
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	stats_panel_ally.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel_ally.add_child(vbox)

	# Titre
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owner_name = navire.player_owner.player_name if navire.player_owner else "???"
	title_label.text = "🚢 " + owner_name
	title_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	vbox.add_child(title_label)

	# Labels de stats
	vie_label_ally = Label.new()
	energie_label_ally = Label.new()
	nourriture_label_ally = Label.new()
	equipage_label_ally = Label.new()
	
	vie_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipage_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nourriture_label_ally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label_ally)
	vbox.add_child(energie_label_ally)
	vbox.add_child(equipage_label_ally)
	vbox.add_child(nourriture_label_ally)

	ui_layer.add_child(stats_panel_ally)


func _create_enemy_stats_panel():
	"""Crée le panneau de stats pour les navires ennemis (à gauche)"""
	stats_panel_enemy = Panel.new()
	stats_panel_enemy.visible = false

	stats_panel_enemy.anchor_left = 0
	stats_panel_enemy.anchor_top = 0
	stats_panel_enemy.anchor_right = 0
	stats_panel_enemy.anchor_bottom = 0
	stats_panel_enemy.offset_left = 20
	stats_panel_enemy.offset_top = 20
	stats_panel_enemy.offset_right = 180
	stats_panel_enemy.offset_bottom = 110

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0, 0, 0.9)  # Rouge pour ennemi
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	stats_panel_enemy.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel_enemy.add_child(vbox)

	# Titre
	var title_label := Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var owner_name = navire.player_owner.player_name if navire.player_owner else "???"
	title_label.text = "☠️ " + owner_name
	title_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(title_label)

	# Labels de stats
	vie_label_enemy = Label.new()
	energie_label_enemy = Label.new()
	nourriture_label_enemy = Label.new()
	equipage_label_enemy = Label.new()
	
	vie_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energie_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipage_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nourriture_label_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(vie_label_enemy)
	vbox.add_child(energie_label_enemy)
	vbox.add_child(equipage_label_enemy)
	vbox.add_child(nourriture_label_enemy)

	ui_layer.add_child(stats_panel_enemy)


func show_stats():
	"""Affiche les stats du navire dans le bon panneau"""
	stats_visible = true
	stats_timer = stats_duration
	
	# Déterminer si ce navire est allié ou ennemi
	var is_ally = (navire.player_owner and navire.player_owner.is_human)
	
	if is_ally:
		# Afficher dans le panneau allié (droite)
		if stats_panel_ally:
			stats_panel_ally.visible = true
			update_stats()
	else:
		# Afficher dans le panneau ennemi (gauche)
		if stats_panel_enemy:
			stats_panel_enemy.visible = true
			update_stats()


func hide_all_stats():
	"""Masque tous les panneaux de stats de ce navire"""
	stats_visible = false
	
	if stats_panel_ally:
		stats_panel_ally.visible = false
	
	if stats_panel_enemy:
		stats_panel_enemy.visible = false


func update_stats():
	"""Met à jour l'affichage des stats"""
	var is_ally = (navire.player_owner and navire.player_owner.is_human)
	
	if is_ally:
		if vie_label_ally and energie_label_ally and equipage_label_ally:
			vie_label_ally.text = "❤️ %d / %d" % [navire.vie, navire.maxvie]
			energie_label_ally.text = "⚡ %d / %d" % [navire.energie, navire.maxenergie]
			equipage_label_ally.text = "👥 %d" % navire.nrbequipage
			nourriture_label_ally.text = "🐟 %d" % navire.nourriture
	else:
		if vie_label_enemy and energie_label_enemy and equipage_label_enemy:
			vie_label_enemy.text = "❤️ %d / %d" % [navire.vie, navire.maxvie]
			energie_label_enemy.text = "⚡ %d / %d" % [navire.energie, navire.maxenergie]
			equipage_label_enemy.text = "👥 %d" % navire.nrbequipage
			nourriture_label_enemy.text = "🐟 %d" % navire.nourriture
