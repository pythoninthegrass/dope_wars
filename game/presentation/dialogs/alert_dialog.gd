class_name AlertDialog
extends DopeDialog

## A title, an icon, a sentence, and one OK button. The prototype's most-used
## dialog: every arrival event, every chase outcome, the last-day warning
## (index.html:1234-1249).
##
## It has no cancel button, so `DopeDialog.cancel()` falls back to the default
## button -- which is exactly what the JS keydown did, since its Escape query
## lists `#alertOk` last (index.html:1680).

const ICON_INFO := "ℹ"
const ICON_MONEY := "💰"
const ICON_SHUGS := "🤷"
const ICON_COAT := "🧥"
const ICON_NEWS := "📈"
const ICON_WARNING := "⚠"
const ICON_SKULL := "☠"
const ICON_POLICE := "🚔"
const ICON_FLAG := "🏁"
const ICON_BULLET := "💥"
const ICON_DAGGER := "💨"
const ICON_HOURGLASS := "⏳"
const ICON_WAVE := "👋"
const ICON_QUESTION := "❓"


func present(title_key: String, message: String, icon: String = ICON_INFO) -> AlertDialog:
	custom_minimum_size = Vector2(320, 0)
	setup(title_key)

	var media := HBoxContainer.new()
	media.add_theme_constant_override("separation", 10)
	body().add_child(media)

	var icon_frame := PanelContainer.new()
	icon_frame.theme_type_variation = &"DialogIcon"
	icon_frame.custom_minimum_size = Vector2(40, 40)
	media.add_child(icon_frame)

	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.custom_minimum_size = Vector2(40, 40)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_frame.add_child(icon_label)

	var text := Label.new()
	text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media.add_child(text)

	add_button("alertOk", Copy.BTN_OK)
	return self
