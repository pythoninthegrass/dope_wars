class_name Copy
extends RefCounted

## Every player-visible string in the game, and nothing else.
##
## `docs/layer-boundaries.md` forbids hard-coded display text in GDScript, and
## `docs/abi-contract.md` keeps human-readable messages out of the ABI: the
## core emits structured payloads and this file formats them. The English text
## lives in game/translations/strings.csv, which Godot's importer compiles into
## the .translation that project.godot registers; a key with no row renders as
## the key itself, which is why the ui_flow test asserts on resolved prose.
##
## The English here is the prototype's own wording (index.html:1081-1710). Where
## a sentence interpolates a number the JS used `fmt()` for, it uses fmt() here
## too, including the comma grouping -- so the two builds read identically.

# --- chrome -----------------------------------------------------------------

const DAY_OF := "DOPE_WARS_DAY_OF"

const MENU_FILE := "MENU_FILE"
const MENU_SCORES := "MENU_SCORES"
const MENU_SOUNDS := "MENU_SOUNDS"
const MENU_HELP := "MENU_HELP"
const MENU_NO_SOUND := "MENU_NO_SOUND"
const ITEM_NEW_GAME := "ITEM_NEW_GAME"
const ITEM_EXIT := "ITEM_EXIT"
const ITEM_HIGH_SCORES := "ITEM_HIGH_SCORES"
const ITEM_HOW_TO_PLAY := "ITEM_HOW_TO_PLAY"

const LED_CASH := "LED_CASH"
const LED_BANK := "LED_BANK"
const LED_DEBT := "LED_DEBT"
const LED_GUNS := "LED_GUNS"
const HEALTH := "HEALTH"
const HEALTH_PERCENT := "HEALTH_PERCENT"

const SUBWAY_FROM := "SUBWAY_FROM"
const TABLE_AVAILABLE_DRUGS := "TABLE_AVAILABLE_DRUGS"
const TABLE_COAT_SPACE := "TABLE_COAT_SPACE"
const COL_DRUG := "COL_DRUG"
const COL_PRICE := "COL_PRICE"
const COL_QTY := "COL_QTY"

const BTN_BUY := "BTN_BUY"
const BTN_SELL := "BTN_SELL"
const BTN_FINANCES := "BTN_FINANCES"
const BTN_FINISH := "BTN_FINISH"
const BTN_OK := "BTN_OK"
const BTN_CANCEL := "BTN_CANCEL"
const BTN_CLOSE := "BTN_CLOSE"
const BTN_DECLINE := "BTN_DECLINE"
const BTN_RUN := "BTN_RUN"
const BTN_STAY := "BTN_STAY"
const BTN_FIGHT := "BTN_FIGHT"
const BTN_SAVE_SCORE := "BTN_SAVE_SCORE"
const BTN_SKIP := "BTN_SKIP"
const BTN_START_GAME := "BTN_START_GAME"

const TREND_UP := "▲"
const TREND_DOWN := "▼"
const TREND_NEUTRAL := "—"

# --- dialog titles ----------------------------------------------------------

const DLG_DEALER := "DLG_DEALER"
const DLG_BUY := "DLG_BUY"
const DLG_SELL := "DLG_SELL"
const DLG_FINANCES := "DLG_FINANCES"
const DLG_DEPOSIT := "DLG_DEPOSIT"
const DLG_WITHDRAW := "DLG_WITHDRAW"
const DLG_PAY_LOAN := "DLG_PAY_LOAN"
const DLG_WORD_ON_THE_STREET := "DLG_WORD_ON_THE_STREET"
const DLG_RANDOM_EVENT := "DLG_RANDOM_EVENT"
const DLG_COAT_DEALER := "DLG_COAT_DEALER"
const DLG_GUN_DEALER := "DLG_GUN_DEALER"
const DLG_COP_CHASE := "DLG_COP_CHASE"
const DLG_YOU_DIED := "DLG_YOU_DIED"
const DLG_GAME_OVER := "DLG_GAME_OVER"
const DLG_HIGH_SCORES := "DLG_HIGH_SCORES"
const DLG_NEW_GAME := "DLG_NEW_GAME"
const DLG_HOW_TO_PLAY := "DLG_HOW_TO_PLAY"
const DLG_LAST_DAY := "DLG_LAST_DAY"

# --- dialog bodies ----------------------------------------------------------

const MSG_LAST_DAY := "MSG_LAST_DAY"
const MSG_DEALER_TOO_DEAR := "MSG_DEALER_TOO_DEAR"
const MSG_COAT_FULL := "MSG_COAT_FULL"
const MSG_BUY_PROMPT := "MSG_BUY_PROMPT"
const MSG_SELL_PROMPT := "MSG_SELL_PROMPT"
const MSG_UNITS_AT := "MSG_UNITS_AT"

const FIN_CASH := "FIN_CASH"
const FIN_BANK := "FIN_BANK"
const FIN_DEBT := "FIN_DEBT"
const BTN_DEPOSIT := "BTN_DEPOSIT"
const BTN_WITHDRAW := "BTN_WITHDRAW"
const BTN_PAY_LOAN := "BTN_PAY_LOAN"
const MSG_DEPOSIT_PROMPT := "MSG_DEPOSIT_PROMPT"
const MSG_WITHDRAW_PROMPT := "MSG_WITHDRAW_PROMPT"
const MSG_PAY_LOAN_PROMPT := "MSG_PAY_LOAN_PROMPT"

const MSG_PRICE_CHEAP := "MSG_PRICE_CHEAP"
const MSG_PRICE_EXPENSIVE := "MSG_PRICE_EXPENSIVE"
const MSG_DEALER_FEE_NOTE := "MSG_DEALER_FEE_NOTE"
const MSG_COAT_OFFER := "MSG_COAT_OFFER"
const MSG_GUN_OFFER := "MSG_GUN_OFFER"

const MSG_CHASE_INTRO := "MSG_CHASE_INTRO"
const MSG_CHASE_ESCAPED := "MSG_CHASE_ESCAPED"
const MSG_CHASE_FIRED_ON := "MSG_CHASE_FIRED_ON"
const MSG_CHASE_STAND_GROUND := "MSG_CHASE_STAND_GROUND"
const MSG_CHASE_WON := "MSG_CHASE_WON"
const MSG_CHASE_HIT_DEPUTY := "MSG_CHASE_HIT_DEPUTY"
const MSG_CHASE_DAMAGE := "MSG_CHASE_DAMAGE"
const MSG_YOU_DIED := "MSG_YOU_DIED"

const MSG_FINAL_SCORE := "MSG_FINAL_SCORE"
const MSG_FINAL_SCORE_DEAD := "MSG_FINAL_SCORE_DEAD"
const LBL_YOUR_NAME := "LBL_YOUR_NAME"
const DEFAULT_NAME := "DEFAULT_NAME"
const LBL_NAME := "LBL_NAME"
const LBL_SCORE := "LBL_SCORE"
const LBL_DAY := "LBL_DAY"
const LBL_STATUS := "LBL_STATUS"
const LBL_DATE := "LBL_DATE"
const STATUS_DEAD := "STATUS_DEAD"
const MSG_NO_SCORES := "MSG_NO_SCORES"

const LBL_NUM_DAYS := "LBL_NUM_DAYS"
const LBL_START_CASH := "LBL_START_CASH"
const MSG_HOW_TO_PLAY := "MSG_HOW_TO_PLAY"

const ARRIVAL_MUGGED_CASH := "ARRIVAL_MUGGED_CASH"
const ARRIVAL_MUGGED_BEATEN := "ARRIVAL_MUGGED_BEATEN"
const ARRIVAL_FREE_DRUGS := "ARRIVAL_FREE_DRUGS"
const ARRIVAL_DOG_CHASE := "ARRIVAL_DOG_CHASE"
const ARRIVAL_FOUND_DRUGS := "ARRIVAL_FOUND_DRUGS"
const ARRIVAL_MAMAS_BROWNIES := "ARRIVAL_MAMAS_BROWNIES"
const ARRIVAL_FREE_WEED_DEATH := "ARRIVAL_FREE_WEED_DEATH"
const ARRIVAL_FLAVOR := "ARRIVAL_FLAVOR"


# --- formatting -------------------------------------------------------------


## tr() for the static helpers below. `Object.tr()` is an instance method, so
## a static function cannot call it; this is the same lookup it performs,
## against the translation project.godot registers. Node-side code may use
## tr() directly.
static func t(key: String) -> String:
	return TranslationServer.translate(key)


## index.html:1085 -- Math.round(n).toLocaleString('en-US'). Rounds first, then
## groups in threes with commas, and keeps the sign outside the grouping the
## way toLocaleString does ("-1,234", not "(1,234)").
static func fmt(value: float) -> String:
	return group(int(round(value)))


static func group(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return "-" + out if value < 0 else out


static func money(value: float) -> String:
	return "$" + fmt(value)


## For the HUD's LED strips (Win98Theme.led_font()): DSEG7-Classic has no
## comma glyph, so LED text groups thousands with "." instead -- also how a
## real seven-segment display would do it, reusing its one decimal-point
## segment. See Win98Theme.led_font() for why this isn't just a cosmetic
## substitution: mixing a fallback font into the line for a missing comma
## glyph changed that line's computed height depending on whether the string
## had a comma, which broke vertical centering across the LED rows.
static func led_fmt(value: float) -> String:
	return fmt(value).replace(",", ".")


# --- structured payloads -> sentences ----------------------------------------


## "Day 3 of 31" (index.html:1129, without the prototype's "Dope Wars,"
## which the OS window title already carries).
static func day_of(day: int, num_days: int) -> String:
	return t(DAY_OF).format([day, num_days])


## "Subway from Bronx:" (index.html:562).
static func subway_from(location_name: String) -> String:
	return t(SUBWAY_FROM).format([location_name])


## "Trenchcoat Space: 12/100" (index.html:588).
static func coat_space(used: int, capacity: int) -> String:
	return t(TABLE_COAT_SPACE).format([fmt(used), fmt(capacity)])


static func health_percent(health: int) -> String:
	return t(HEALTH_PERCENT).format([health])


## The ▲/▼/— glyph for a market row. `previous` is null when the drug was not
## traded last turn, and the prototype renders a neutral dash for that case
## too (index.html:1182). Nothing is shown at all on day 1, which is
## `show_trend`'s job, not this one's.
static func trend(current: int, previous: Variant) -> String:
	if previous == null:
		return TREND_NEUTRAL
	if current > int(previous):
		return TREND_UP
	if current < int(previous):
		return TREND_DOWN
	return TREND_NEUTRAL


## "units @ $1,234" (index.html:1302).
static func units_at(price: float) -> String:
	return t(MSG_UNITS_AT).format([fmt(price)])


## The cheap/expensive price-event toasts (index.html:742-745). `drug_name` is
## the display name out of rules_drugs(), never the id.
static func price_event_message(kind: int, drug_name: String) -> String:
	if kind == SimWorld.PRICE_EVENT_EXPENSIVE:
		return t(MSG_PRICE_EXPENSIVE).format([drug_name])
	return t(MSG_PRICE_CHEAP).format([drug_name])


## The arrival event (index.html:869-927) as a sentence. The core hands over a
## structured dw_arrival_event, so the branch that JS picked with `state.cash
## == 0` shows up here as `damage != 0` -- the mugging only deals damage on
## the cashless path, and the header documents that pairing.
static func arrival_message(event: Dictionary, drug_name: String) -> String:
	match int(event.get("kind", SimWorld.ARRIVAL_NONE)):
		SimWorld.ARRIVAL_MUGGED:
			if int(event.get("damage", 0)) != 0:
				return t(ARRIVAL_MUGGED_BEATEN)
			return t(ARRIVAL_MUGGED_CASH).format([group(int(event.get("amount", 0)))])
		SimWorld.ARRIVAL_FREE_DRUGS:
			return t(ARRIVAL_FREE_DRUGS).format([int(event.get("qty", 0)), drug_name])
		SimWorld.ARRIVAL_DOG_CHASE:
			return t(ARRIVAL_DOG_CHASE).format([int(event.get("qty", 0)), drug_name])
		SimWorld.ARRIVAL_FOUND_DRUGS:
			return t(ARRIVAL_FOUND_DRUGS).format([int(event.get("qty", 0)), drug_name])
		SimWorld.ARRIVAL_MAMAS_BROWNIES:
			return t(ARRIVAL_MAMAS_BROWNIES).format([int(event.get("qty", 0)), drug_name])
		SimWorld.ARRIVAL_FREE_WEED_DEATH:
			return t(ARRIVAL_FREE_WEED_DEATH)
		SimWorld.ARRIVAL_FLAVOR:
			return t(ARRIVAL_FLAVOR).format([group(int(event.get("amount", 0)))])
	return ""


## "Officer Hardass and 3 of his deputies are chasing you!" (index.html:1483).
## The cop's name is presentation, not a game fact, so it lives here rather
## than crossing the ABI.
static func chase_intro(deputies: int) -> String:
	return t(MSG_CHASE_INTRO).format([deputies])


## "You hit a deputy! 2 left." or "You got hit for 4 damage!"
## (index.html:1521).
static func fight_message(hit: bool, deputies: int, damage: int) -> String:
	if hit:
		return t(MSG_CHASE_HIT_DEPUTY).format([deputies])
	return t(MSG_CHASE_DAMAGE).format([damage])


## "Final score: $12,345 (dead)" (index.html:1573).
static func final_score(score: int, dead: bool) -> String:
	var amount := t(MSG_FINAL_SCORE).format([fmt(score)])
	return t(MSG_FINAL_SCORE_DEAD).format([amount]) if dead else amount


## index.html:1630, which folds the current game's length into the rules text.
static func how_to_play(num_days: int) -> String:
	return t(MSG_HOW_TO_PLAY).format([num_days])
