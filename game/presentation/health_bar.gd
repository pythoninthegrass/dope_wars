class_name HealthBar
extends Control

## The prototype's health readout, shared by the HUD row
## (index.html:553-558) and the chase dialog (:1485-1490) so the two cannot
## drift.
##
## A ProgressBar supplies the fill geometry the prototype gets from
## `style="width:N%"`; a Label on top of it supplies the centered percentage
## the prototype puts inside the fill. ProgressBar's own `show_percentage` is
## off because it prints the value, not the rounded percentage the prototype
## renders.

var _bar: ProgressBar
var _label: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 18)
	clip_contents = true

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.show_percentage = false
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.theme_type_variation = &"HealthBar"
	add_child(_bar)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func set_health(health: int) -> void:
	# index.html:1134-1135 clamps at 0 on both the width and the text.
	var clamped := maxi(0, health)
	_bar.value = clamped
	_label.text = Copy.health_percent(clamped)


func health_text() -> String:
	return _label.text
