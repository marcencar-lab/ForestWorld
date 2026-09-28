class_name ForestHUD
extends CanvasLayer

## On-screen readout: controls on the left, live state on the right, a centred
## toast line for events, and in survival mode the player's vitals, an
## interaction prompt, the bear warning, a hurt flash and the game-over card.

var help_panel: PanelContainer
var help_label: Label
var stats_label: Label
var toast_label: Label
var prompt_label: Label
var warning_label: Label
var vignette: ColorRect
var vitals_panel: PanelContainer
var bag_label: Label
var status_label: Label
var game_over: PanelContainer
var game_over_label: Label
var compass_label: Label
var fade: ColorRect
var inv_label: Label
var hotbar_label: Label
var crosshair: Label
var side_panel: PanelContainer
var side_label: Label
var stats_panel: PanelContainer
var hint_label: Label

## 0 = compact (a small "H  controls" hint), 1 = controls shown, 2 = HUD hidden.
var hud_mode := 0
var _survival := true

var _bars := {}
var _toast_t := 0.0
var _hurt := 0.0
var _warn_t := 0.0

const SURVIVAL_HELP := """FOREST WORLD - SURVIVAL
  Stay alive. The bear hunts anything it
  can hear or smell, and that includes you.

  Mouse            look
  W A S D          move       (Shift = sprint)
  C                crouch / sneak  (quieter)
  Space            jump
  LMB              use held tool / place piece
  E                interact: pick up, open, fuel,
                   cast line / reel in a bite
  R                repair what you're looking at
  1 2 3 ...        choose held item
  Tab              crafting
  B                build mode  (wheel = piece)
  Q                eat (best food first)
  X                drink from your bottle
  Z                use a bandage
  C + E            drink at the lake
  T                toggle day-night cycle
  M                mute / unmute audio
  H                controls / hide HUD
  P                switch to sandbox mode
  Esc              release mouse   (click to recapture)

  Rocks lie on the ground. Hit trees with one
  for branches, craft an axe, fell trees for
  logs, saw logs into planks and build.
  Walls keep the bear out; a roof, lean-to or
  campfire keeps you warm when it rains.
  Search abandoned cabins for supplies and
  weapons. Cook meat and fish on a fire -
  raw food can make you sick."""

const SANDBOX_HELP := """FOREST WORLD - SANDBOX
  Mouse            look
  W A S D          move        (Shift = sprint)
  Space            jump / fly up
  Ctrl             fly down
  F                toggle fly mode
  Tab              camera: player / bear / prey
  R                teleport to the bear
  B                build mode  (free, no costs)
  G                toggle rain
  T                toggle day-night cycle
  V                toggle volumetric fog
  M                mute / unmute audio
  H                controls / hide HUD
  P                back to survival (restarts)
  Esc              release mouse   (click to recapture)"""


func _ready() -> void:
	layer = 10

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.material = _vignette_material()
	vignette.color = Color(0.55, 0.0, 0.0, 0.0)
	add_child(vignette)

	help_panel = PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", _bg(0.35))
	help_panel.offset_left = 16
	help_panel.offset_top = 16
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_panel.visible = false
	add_child(help_panel)

	help_label = Label.new()
	help_label.text = SURVIVAL_HELP
	help_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.90))
	help_label.add_theme_font_size_override("font_size", 13)
	_outline(help_label)
	help_panel.add_child(help_label)

	hint_label = Label.new()
	hint_label.text = "H  controls"
	hint_label.position = Vector2(18, 14)
	hint_label.modulate.a = 0.55
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	hint_label.add_theme_font_size_override("font_size", 13)
	_outline(hint_label)
	add_child(hint_label)

	# Pinned to the top-right corner; grows leftward as the text gets wider.
	var right := PanelContainer.new()
	stats_panel = right
	right.add_theme_stylebox_override("panel", _bg())
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -16
	right.offset_right = -16
	right.offset_top = 16
	right.offset_bottom = 16
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)

	stats_label = Label.new()
	stats_label.text = "..."
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.modulate.a = 0.85
	_outline(stats_label)
	right.add_child(stats_label)

	toast_label = _centred_label(34, 22, Color(1.0, 0.86, 0.55))
	toast_label.modulate.a = 0.0

	warning_label = _centred_label(72, 20, Color(1.0, 0.38, 0.30))
	warning_label.visible = false

	prompt_label = _centred_label(0, 20, Color(0.96, 0.96, 0.92))
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_label.offset_top = -150
	prompt_label.offset_bottom = -150

	crosshair = _centred_label(0, 18, Color(1, 1, 1, 0.8))
	crosshair.text = "+"
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	crosshair.offset_top = -12
	crosshair.offset_bottom = 12

	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", _bg(0.3))
	side_panel.anchor_left = 1.0
	side_panel.anchor_right = 1.0
	side_panel.anchor_top = 0.5
	side_panel.anchor_bottom = 0.5
	side_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	side_panel.offset_left = -16
	side_panel.offset_right = -16
	side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_panel.visible = false
	add_child(side_panel)
	side_label = Label.new()
	side_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
	side_label.add_theme_font_size_override("font_size", 14)
	_outline(side_label)
	side_panel.add_child(side_label)

	compass_label = _centred_label(8, 15, Color(0.95, 0.95, 0.90))
	compass_label.modulate.a = 0.8

	_build_vitals()
	_build_game_over()

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0, 0, 0, 0)
	add_child(fade)


## Dark outline so text stays readable over bright scenery without a panel.
func _outline(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)


func _centred_label(top: float, size: int, col: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = top
	l.offset_bottom = top
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", size)
	add_child(l)
	return l


func _build_vitals() -> void:
	vitals_panel = PanelContainer.new()
	vitals_panel.add_theme_stylebox_override("panel", _bg())
	vitals_panel.anchor_top = 1.0
	vitals_panel.anchor_bottom = 1.0
	vitals_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vitals_panel.offset_left = 16
	vitals_panel.offset_top = -16
	vitals_panel.offset_bottom = -16
	vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vitals_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	vitals_panel.add_child(box)

	_add_bar(box, "health", "HEALTH", Color(0.86, 0.22, 0.20))
	_add_bar(box, "stamina", "STAMINA", Color(0.92, 0.78, 0.26))
	_add_bar(box, "hunger", "FOOD", Color(0.88, 0.52, 0.20))
	_add_bar(box, "thirst", "WATER", Color(0.30, 0.78, 0.86))
	_add_bar(box, "warmth", "WARMTH", Color(0.35, 0.62, 0.95))

	inv_label = Label.new()
	inv_label.add_theme_color_override("font_color", Color(0.93, 0.90, 0.80))
	inv_label.add_theme_font_size_override("font_size", 12)
	_outline(inv_label)
	box.add_child(inv_label)

	hotbar_label = Label.new()
	hotbar_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	hotbar_label.add_theme_font_size_override("font_size", 12)
	_outline(hotbar_label)
	box.add_child(hotbar_label)

	bag_label = Label.new()
	bag_label.add_theme_color_override("font_color", Color(0.90, 0.94, 0.96))
	bag_label.add_theme_font_size_override("font_size", 12)
	_outline(bag_label)
	box.add_child(bag_label)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	status_label.add_theme_font_size_override("font_size", 12)
	_outline(status_label)
	box.add_child(status_label)


func _add_bar(parent: Control, key: String, title: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(58, 0)
	l.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	l.add_theme_font_size_override("font_size", 10)
	_outline(l)
	row.add_child(l)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 7)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)
	_bars[key] = [bar, fg, col]


func _build_game_over() -> void:
	game_over = PanelContainer.new()
	var sb := _bg()
	sb.bg_color = Color(0.04, 0.03, 0.03, 0.75)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	game_over.add_theme_stylebox_override("panel", sb)
	game_over.set_anchors_preset(Control.PRESET_CENTER)
	game_over.grow_horizontal = Control.GROW_DIRECTION_BOTH
	game_over.grow_vertical = Control.GROW_DIRECTION_BOTH
	game_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over.visible = false
	add_child(game_over)

	game_over_label = Label.new()
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.86))
	game_over_label.add_theme_font_size_override("font_size", 20)
	game_over.add_child(game_over_label)


## Dark red edges that are clear in the middle.
func _vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.25, 0.75, length(d) * 1.35);
	COLOR = vec4(COLOR.rgb, COLOR.a * edge);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _bg(alpha := 0.14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, alpha)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# --- API ----------------------------------------------------------------------

func set_mode(survival: bool) -> void:
	_survival = survival
	help_label.text = SURVIVAL_HELP if survival else SANDBOX_HELP
	_apply_hud_mode()
	if not survival:
		prompt_label.text = ""
		warning_label.visible = false


## H cycles: compact -> controls -> HUD hidden -> compact.
func toggle_help() -> void:
	hud_mode = (hud_mode + 1) % 3
	_apply_hud_mode()


func _apply_hud_mode() -> void:
	help_panel.visible = hud_mode == 1
	hint_label.visible = hud_mode == 0
	stats_panel.visible = hud_mode != 2
	vitals_panel.visible = hud_mode != 2 and _survival


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	_toast_t = 3.5


func set_stats(lines: String) -> void:
	stats_label.text = lines


func set_prompt(text: String) -> void:
	prompt_label.text = text


func set_warning(text: String) -> void:
	warning_label.text = text
	warning_label.visible = text != ""


func flash_hurt(amount: float) -> void:
	_hurt = minf(_hurt + amount / 45.0, 1.0)


func set_vitals(p: PlayerController) -> void:
	_set_bar("health", p.health, p.health < 30.0)
	_set_bar("stamina", p.stamina, p.exhausted)
	_set_bar("hunger", p.hunger, p.hunger < 20.0)
	_set_bar("warmth", p.warmth, p.warmth < 20.0)
	_set_bar("thirst", p.thirst, p.thirst < 20.0)

	var inv_text := "Rocks %d   Branches %d   Logs %d   Planks %d" % [
		p.inv.rock, p.inv.branch, p.inv.log, p.inv.plank]
	var extras := []
	if int(p.inv.bandage) > 0:
		extras.append("Bandages %d" % p.inv.bandage)
	if int(p.inv.arrow) > 0:
		extras.append("Arrows %d" % p.inv.arrow)
	if int(p.inv.bottle) > 0:
		extras.append("Water %d/%d" % [p.water_sips, int(p.inv.bottle) * PlayerController.SIPS_PER_BOTTLE])
	if not extras.is_empty():
		inv_text += "\n" + "   ".join(extras)
	inv_label.text = inv_text
	var slots := []
	var bar := p.hotbar()
	for i in bar.size():
		var item: String = bar[i]
		var name := item
		if p.tools.has(item):
			name = "%s (%d)" % [item, p.tools[item]]
		slots.append(("[%d %s]" if item == p.held else " %d %s ") % [i + 1, name])
	hotbar_label.text = " ".join(slots)

	var food := []
	for k in Items.FOOD:
		var n := int(p.inv[k])
		if n > 0:
			food.append(Items.count_label(k, n))
	bag_label.text = "Food: none" if food.is_empty() else "Food: %s   (Q)" % ", ".join(food)

	var status := []
	if p.swimming:
		status.append("swimming")
	if p.crouching:
		status.append("sneaking")
	if p.exhausted:
		status.append("exhausted")
	if p.hunger <= 0.0:
		status.append("starving")
	if p.thirst <= 0.0:
		status.append("DEHYDRATED")
	if p.bleeding > 0.0:
		status.append("BLEEDING (Z)")
	if p.sick > 0.0:
		status.append("food poisoning")
	if p.swimming and p.stamina <= 0.0:
		status.append("DROWNING")
	if p.fire_heat > 0.0:
		status.append("by the fire")
	elif p.sheltered:
		status.append("sheltered")
	if p.warmth <= 0.0:
		status.append("FREEZING")
	elif p.warmth < 30.0:
		status.append("cold")
	status_label.text = "  ".join(status)

	# A low, steady red pulse when badly hurt.
	if p.alive and p.health < 30.0:
		_hurt = maxf(_hurt, 0.25 + sin(Time.get_ticks_msec() * 0.006) * 0.12)


func _set_bar(key: String, value: float, alarm: bool) -> void:
	var entry: Array = _bars[key]
	var bar: ProgressBar = entry[0]
	var fg: StyleBoxFlat = entry[1]
	var col: Color = entry[2]
	bar.value = value
	if alarm and fmod(Time.get_ticks_msec() * 0.001, 0.8) < 0.4:
		fg.bg_color = col.lightened(0.45)
	else:
		fg.bg_color = col


## The crafting list or build palette, pinned to the right edge.
func set_side_panel(text: String) -> void:
	side_label.text = text
	side_panel.visible = text != ""


func set_compass(text: String) -> void:
	compass_label.text = text
	compass_label.visible = hud_mode != 2


## Fade to black and back, for sleeping.
func fade_sleep() -> void:
	var tw := create_tween()
	fade.color.a = 1.0
	tw.tween_interval(0.6)
	tw.tween_property(fade, "color:a", 0.0, 1.4)


func show_game_over(text: String) -> void:
	game_over_label.text = text
	game_over.visible = true
	prompt_label.text = ""
	warning_label.visible = false


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.modulate.a = clampf(_toast_t, 0.0, 1.0)

	_hurt = maxf(_hurt - delta * 0.9, 0.0)
	vignette.color.a = _hurt * 0.85

	if warning_label.visible:
		_warn_t += delta
		warning_label.modulate.a = 0.65 + sin(_warn_t * 7.0) * 0.35
