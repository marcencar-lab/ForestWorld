class_name ForestHUD
extends CanvasLayer

## Minimal on-screen readout: controls on the left, live world state on the right,
## and a centred toast line for events like a kill.

var help_panel: PanelContainer
var help_label: Label
var stats_label: Label
var toast_label: Label

var _toast_t := 0.0

const HELP_TEXT := """FOREST WORLD
  Mouse            look
  W A S D          move        (Shift = sprint)
  Space            jump / fly up
  Ctrl             fly down
  F                toggle fly mode
  Tab              camera: player / bear / prey
  R                teleport to the bear
  T                toggle day-night cycle
  V                toggle volumetric fog
  M                mute / unmute audio
  H                hide this panel
  Esc              release mouse   (click to recapture)"""


func _ready() -> void:
	layer = 10

	help_panel = PanelContainer.new()
	help_panel.add_theme_stylebox_override("panel", _bg())
	help_panel.offset_left = 16
	help_panel.offset_top = 16
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help_panel)

	help_label = Label.new()
	help_label.text = HELP_TEXT
	help_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.90))
	help_label.add_theme_font_size_override("font_size", 14)
	help_panel.add_child(help_label)

	# Pinned to the top-right corner; grows leftward as the text gets wider.
	var right := PanelContainer.new()
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
	stats_label.add_theme_font_size_override("font_size", 15)
	right.add_child(stats_label)

	toast_label = Label.new()
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.offset_left = 0
	toast_label.offset_right = 0
	toast_label.offset_top = 34
	toast_label.offset_bottom = 34
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.add_theme_font_size_override("font_size", 22)
	toast_label.modulate.a = 0.0
	add_child(toast_label)


func _bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.42)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	_toast_t = 3.5


func set_stats(lines: String) -> void:
	stats_label.text = lines


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.modulate.a = clampf(_toast_t, 0.0, 1.0)
