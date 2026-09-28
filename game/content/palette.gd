class_name Palette
extends RefCounted

## The `:root` custom properties from `index.html:8-24`, as named constants so
## the theme builder and any one-off Control can agree without a string
## lookup. Values are the prototype's verbatim; there is no second palette
## anywhere in game/.

const WIN_FACE := Color("c0c0c0")
const WIN_FACE_DARK := Color("808080")
const WIN_FACE_DARKER := Color("404040")
const WIN_FACE_LIGHT := Color("ffffff")
const WIN_FACE_LIGHT2 := Color("dfdfdf")

const TITLEBAR := Color("000080")
const TITLEBAR_TEXT := Color("ffffff")

const LED_GREEN := Color("00ff2f")
const LED_GREEN_BG := Color("003300")
const LED_RED := Color("ff3030")
const LED_RED_BG := Color("330000")
const LED_YELLOW := Color("ffe000")
const LED_YELLOW_BG := Color("333300")

## Health-bar fill is the one colour the prototype hardcodes inline rather than
## naming in :root (`index.html:207`).
const HEALTH_FILL := Color("0000c0")

const OVERLAY_SCRIM := Color(0, 0, 0, 0.35)

## Row states for a held drug that is not traded here (`index.html:336-339`).
const ROW_SELECTED := TITLEBAR
const ROW_SELECTED_TEXT := Color("ffffff")
const ROW_UNAVAILABLE := Color("5a1010")
const ROW_UNAVAILABLE_TEXT := Color("ff8080")

## Market-table price-trend glyph colors (`index.html:489-491`).
const TREND_UP := Color("008800")
const TREND_DOWN := Color("cc0000")
const TREND_NEUTRAL := Color("777777")
