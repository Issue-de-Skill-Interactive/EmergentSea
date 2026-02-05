extends Node

func _enter_tree():
	load_user_config()

func rebind_action(action_name: String, new_keycode: int):
	# On supprime les anciens bindings pour cette action
	InputMap.action_erase_events(action_name)

	# On crée un nouvel InputEventKey
	var ev :InputEventKey= InputEventKey.new()
	ev.keycode = new_keycode

	# On l’ajoute à l’action
	InputMap.action_add_event(action_name, ev)

func save_user_config(path := "user://input.cfg"):
	var config := ConfigFile.new()

	for action in InputMap.get_actions():
		var events := InputMap.action_get_events(action)
		var serialized := []

		for ev in events:
			if ev is InputEventKey:
				serialized.append({
					"type": "key",
					"keycode": ev.keycode
				})
			elif ev is InputEventMouseButton:
				serialized.append({
					"type": "mouse",
					"button": ev.button_index
				})
			# Tu peux ajouter d'autres types si tu veux (manette, etc.)

		config.set_value("input", action, serialized)

	config.save(path)

func load_user_config(path := "user://input.cfg"):
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return

	# On itère seulement sur les actions présentes dans le fichier de config.
	for action in config.get_section_keys("input"):
		# On vérifie si l'action existe dans le projet avant d'essayer de la modifier
		if InputMap.has_action(action):
			InputMap.action_erase_events(action) # On nettoie seulement cette action
			
			var serialized = config.get_value("input", action, [])
			
			for data in serialized:
				match data["type"]:
					"key":
						var ev := InputEventKey.new()
						ev.keycode = data["keycode"]
						InputMap.action_add_event(action, ev)
					"mouse":
						var ev := InputEventMouseButton.new()
						ev.button_index = data["button"]
						InputMap.action_add_event(action, ev)
