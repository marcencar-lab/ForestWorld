extends Control

## Start screen: single player, host a game, or join one by address.

var _name: LineEdit
var _addr: LineEdit
var _status: Label


func _ready() -> void:
	Session.load_settings()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.10, 0.08)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "FOREST WORLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.86, 0.92, 0.78))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Survive the forest. Watch out for the bear."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.65, 0.72, 0.62))
	box.add_child(sub)

	box.add_child(_spacer(10))
	box.add_child(_caption("Your name"))
	_name = LineEdit.new()
	_name.text = Session.player_name
	_name.max_length = 20
	box.add_child(_name)

	box.add_child(_spacer(6))
	box.add_child(_button("Single player", _on_single))
	box.add_child(_button("Host a game", _on_host))

	box.add_child(_spacer(6))
	box.add_child(_caption("Join a friend (their address, e.g. 203.0.113.5 or 203.0.113.5:%d)" % Session.DEFAULT_PORT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_addr = LineEdit.new()
	_addr.text = Session.address if Session.port == Session.DEFAULT_PORT else "%s:%d" % [Session.address, Session.port]
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_addr)
	var join := _button("Join", _on_join)
	join.custom_minimum_size = Vector2(110, 0)
	row.add_child(join)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
	box.add_child(_status)

	box.add_child(_spacer(8))
	box.add_child(_button("Quit", func() -> void: get_tree().quit()))

	if Session.menu_message != "":
		_status.text = Session.menu_message
		Session.menu_message = ""


func _caption(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.75, 0.80, 0.72))
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	return b


func _take_name() -> void:
	var n := _name.text.strip_edges()
	Session.player_name = n if n != "" else "Survivor"


func _start(mode: String) -> void:
	_take_name()
	Session.mode = mode
	Session.save_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_single() -> void:
	_start("single")


func _on_host() -> void:
	Session.port = Session.DEFAULT_PORT
	_start("host")


func _on_join() -> void:
	var t := _addr.text.strip_edges()
	if t == "":
		_status.text = "Type your friend's address first."
		return
	var host := t
	var port := Session.DEFAULT_PORT
	var colon := t.rfind(":")
	if colon > 0 and t.count(":") == 1:
		host = t.substr(0, colon)
		port = int(t.substr(colon + 1))
	Session.address = host
	Session.port = port if port > 0 else Session.DEFAULT_PORT
	_start("client")
