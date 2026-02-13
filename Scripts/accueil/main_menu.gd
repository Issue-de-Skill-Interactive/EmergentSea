extends Control

const SOLO_SCENE_PATH := "res://Scenes/in_game/Main.tscn"
const SAVE_PATH := "user://controls.cfg"

# Actions rebindables
var rebind_actions: Array[StringName] = [
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right",
	&"fish"
]

# UI state
var waiting_action: StringName = &""

# Screens
var screen_main: Control
var screen_options: Control
var screen_controls: Control

# Controls screen refs
var hint_label: Label
var actions_box: VBoxContainer


# =========================================================
# Lifecycle
# =========================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_binds()
	_build_ui()
	_show_main()


# =========================================================
# UI BUILD
# =========================================================

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.043, 0.063, 0.125)
	add_child(bg)

	screen_main = _make_main_screen()
	screen_options = _make_options_screen()
	screen_controls = _make_controls_screen()

	add_child(screen_main)
	add_child(screen_options)
	add_child(screen_controls)


func _make_panel(title_text: String) -> Dictionary:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)

	v.add_child(title)
	panel.add_child(v)
	center.add_child(panel)

	return { "root": center, "vbox": v }


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	return b


# =========================================================
# SCREENS
# =========================================================

func _make_main_screen() -> Control:
	var d := _make_panel("EmergentSea")
	var v: VBoxContainer = d["vbox"]

	var btn_solo := _make_button("Solo")
	var btn_multi := _make_button("Multijoueur")
	var btn_options := _make_button("Options")
	var btn_quit := _make_button("Quitter")

	btn_solo.pressed.connect(_on_solo_pressed)
	btn_options.pressed.connect(_show_options)
	btn_quit.pressed.connect(func(): get_tree().quit())

	btn_multi.pressed.connect(func():
		btn_multi.text = "Multijoueur (bientôt)"
		btn_multi.disabled = true
	)

	v.add_child(btn_solo)
	v.add_child(btn_multi)
	v.add_child(btn_options)
	v.add_child(btn_quit)

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(d["root"])
	return wrapper


func _make_options_screen() -> Control:
	var d := _make_panel("Options")
	var v: VBoxContainer = d["vbox"]

	var btn_controls := _make_button("Contrôles")
	var btn_back := _make_button("Retour")

	btn_controls.pressed.connect(_show_controls)
	btn_back.pressed.connect(_show_main)

	v.add_child(btn_controls)
	v.add_child(btn_back)

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.visible = false
	wrapper.add_child(d["root"])
	return wrapper


func _make_controls_screen() -> Control:
	var d := _make_panel("Contrôles")
	var v: VBoxContainer = d["vbox"]

	hint_label = Label.new()
	hint_label.text = "Clique sur “Changer”, puis appuie sur une touche. (Échap = annuler)"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint_label)

	actions_box = VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 10)
	v.add_child(actions_box)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)

	var btn_reset := _make_button("Reset")
	var btn_back := _make_button("Retour")

	btn_reset.pressed.connect(_on_reset_pressed)
	btn_back.pressed.connect(_show_options)

	h.add_child(btn_reset)
	h.add_child(btn_back)

	_rebuild_actions_ui()

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.visible = false
	wrapper.add_child(d["root"])
	return wrapper


# =========================================================
# NAVIGATION
# =========================================================

func _set_visible_screen(active: Control) -> void:
	screen_main.visible = active == screen_main
	screen_options.visible = active == screen_options
	screen_controls.visible = active == screen_controls


func _show_main() -> void:
	waiting_action = &""
	_set_visible_screen(screen_main)


func _show_options() -> void:
	waiting_action = &""
	_set_visible_screen(screen_options)


func _show_controls() -> void:
	waiting_action = &""
	_rebuild_actions_ui()
	_set_visible_screen(screen_controls)


# =========================================================
# ACTIONS
# =========================================================

func _on_solo_pressed() -> void:
	get_tree().change_scene_to_file(SOLO_SCENE_PATH)


func _on_reset_pressed() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()


# =========================================================
# REBIND UI
# =========================================================

func _rebuild_actions_ui() -> void:
	if actions_box == null:
		return

	for c in actions_box.get_children():
		c.queue_free()

	for a in rebind_actions:
		if not InputMap.has_action(a):
			continue

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl := Label.new()
		lbl.text = _pretty_action(a)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_lbl := Label.new()
		key_lbl.text = _keys_text(a)
		key_lbl.custom_minimum_size = Vector2(220, 0)

		var btn := _make_button("Changer")
		btn.pressed.connect(func():
			waiting_action = a
			hint_label.text = "Appuie sur une touche pour : %s (Échap = annuler)" % _pretty_action(a)
		)

		row.add_child(lbl)
		row.add_child(key_lbl)
		row.add_child(btn)
		actions_box.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if waiting_action == &"":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey

		if k.keycode == KEY_ESCAPE:
			waiting_action = &""
			hint_label.text = "Clique sur “Changer”, puis appuie sur une touche. (Échap = annuler)"
			return

		_set_action_key(waiting_action, k)
		_save_binds()

		waiting_action = &""
		hint_label.text = "Clique sur “Changer”, puis appuie sur une touche. (Échap = annuler)"
		_rebuild_actions_ui()


func _set_action_key(action_name: StringName, key_event: InputEventKey) -> void:
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey:
			InputMap.action_erase_event(action_name, e)

	var ev := InputEventKey.new()
	ev.keycode = key_event.keycode
	ev.physical_keycode = key_event.physical_keycode
	ev.ctrl_pressed = key_event.ctrl_pressed
	ev.alt_pressed = key_event.alt_pressed
	ev.shift_pressed = key_event.shift_pressed
	ev.meta_pressed = key_event.meta_pressed
	InputMap.action_add_event(action_name, ev)


func _keys_text(action_name: StringName) -> String:
	var keys: Array[String] = []
	for e in InputMap.action_get_events(action_name):
		if e is InputEventKey:
			keys.append(OS.get_keycode_string((e as InputEventKey).keycode))
	return "-" if keys.is_empty() else ", ".join(keys)


func _pretty_action(a: StringName) -> String:
	match String(a):
		"ui_up": return "Monter"
		"ui_down": return "Descendre"
		"ui_left": return "Gauche"
		"ui_right": return "Droite"
		"fish": return "Pêcher"
		_: return String(a)


# =========================================================
# SAVE / LOAD BINDS
# =========================================================

func _save_binds() -> void:
	var cfg := ConfigFile.new()

	for a in rebind_actions:
		if not InputMap.has_action(a):
			continue

		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				var k := e as InputEventKey
				cfg.set_value("binds", String(a), {
					"keycode": int(k.keycode),
					"physical_keycode": int(k.physical_keycode),
					"ctrl": k.ctrl_pressed,
					"alt": k.alt_pressed,
					"shift": k.shift_pressed,
					"meta": k.meta_pressed
				})
				break

	cfg.save(SAVE_PATH)


func _load_binds() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	for a in rebind_actions:
		if not InputMap.has_action(a):
			continue

		var saved: Dictionary = cfg.get_value("binds", String(a), {})
		if saved.is_empty():
			continue

		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				InputMap.action_erase_event(a, e)

		var ev := InputEventKey.new()
		ev.keycode = int(saved.get("keycode", 0))
		ev.physical_keycode = int(saved.get("physical_keycode", 0))
		ev.ctrl_pressed = bool(saved.get("ctrl", false))
		ev.alt_pressed = bool(saved.get("alt", false))
		ev.shift_pressed = bool(saved.get("shift", false))
		ev.meta_pressed = bool(saved.get("meta", false))

		InputMap.action_add_event(a, ev)
