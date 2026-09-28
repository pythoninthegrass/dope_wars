class_name DialogHost
extends Control

## The modal layer: a scrim over the whole window with at most one DopeDialog
## centered on it, replacing the prototype's `#overlay` / `#dialogRoot` pair
## (index.html:605-607, `:1224-1232`).
##
## Owns nothing but the current dialog. The input router asks `is_open()` and
## then `confirm()` / `cancel()`; every other intent is swallowed while a modal
## is up, which is the prototype's early return at index.html:1678-1686.
##
## An incoming action is forwarded to the open dialog and then the dialog is
## closed, because in this game every dialog is terminal -- there is no "back"
## from the finances dialog to the market, and the prototype's reopen-the-
## dialog-after-commit dance (index.html:1348) is expressed by the caller
## re-opening it.

signal closed()

var _scrim: ColorRect
var _slot: CenterContainer
var _current: DopeDialog = null


func _init() -> void:
	name = "DialogHost"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	_scrim = ColorRect.new()
	_scrim.color = Palette.OVERLAY_SCRIM
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)

	_slot = CenterContainer.new()
	_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot)


## Replaces whatever is open with `dialog`. The dialog's `action` signal is
## forwarded to `on_action`.
##
## The close happens *before* the handler runs, matching the prototype's
## `closeDialog(); opts.onConfirm(qty)` (index.html:1277-1278). Order matters
## because several dialogs re-open themselves from their handler -- the
## finances dialog after a deposit (index.html:1348) -- and a host that closed
## afterwards would slam that replacement shut again.
##
## The dialog is freed with queue_free, so a handler may still read it for the
## rest of the frame, which is how the quantity dialog's value survives
## closing.
func open(dialog: DopeDialog, on_action: Callable) -> void:
	close()
	_current = dialog
	_current.action.connect(func(key: StringName) -> void:
		var handled := String(key)
		close()
		on_action.call(handled)
	)
	_slot.add_child(dialog)
	visible = true
	dialog.focus_default()


func is_open() -> bool:
	return _current != null and is_instance_valid(_current)


func confirm() -> void:
	if is_open():
		_current.confirm()


func cancel() -> void:
	if is_open():
		_current.cancel()


## The open dialog, for tests and for the flow controller to read. Null when
## nothing is up.
func current() -> DopeDialog:
	return _current if is_open() else null


## Every tr() key the open dialog is currently showing, flattened. The ui_flow
## test asserts on this so a key that fails to resolve shows up as a failing
## assertion rather than as "DIALOG_BUY" on someone's screen.
func visible_text() -> String:
	var parts: Array[String] = []
	if not is_open():
		return ""
	for node in _collect_labels(_current):
		parts.append(node.text)
	return " ".join(parts)


func _collect_labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	if node is Label:
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_labels(child))
	return found


func close() -> void:
	if _current == null:
		return
	var dialog := _current
	_current = null
	if is_instance_valid(dialog):
		dialog.queue_free()
	visible = false
	closed.emit()
