# core/src/world.mojo — the game state handle and its bookkeeping.
#
# Ported from newGame / coatUsed / addToInventory / removeFromInventory in
# index.html:686-716 and 842-859.
#
# The JS state is a plain object whose `prices`, `prevPrices` and `inventory`
# fields are insertion-ordered maps keyed by drug id. That order is not
# cosmetic: Object.keys(state.prices) picks the drug in randomTradeableDrug(),
# Object.keys(state.inventory) picks the drug in the dogChase branch, and the
# oracle's own deepEqual is JSON.stringify, so it compares order too. A dense
# per-drug array alone would lose it.
#
# So each map is stored twice: dense per-drug slots for O(1) lookup, plus an
# explicit order list of drug indices. The order list is the source of truth for
# iteration; the dense slots are the source of truth for value.
#
# The order lists are fixed-size `Array`s with an explicit length rather than
# `List`s. That is what lets the whole World live in caller-owned storage with
# no hidden heap allocation: `dw_world_size()` is `size_of[World]()`, the ABI
# placement-constructs a World into the caller's buffer, and plain `free()` on
# that buffer is a complete teardown (docs/abi-contract.md). A `List` field
# would leak its backing store with no `dw_world_destroy` to release it.
#
# `price_was_event` records whether a price came from a cheap/expensive event
# roll rather than the normal min..max band. The JS engine does not track it,
# but dw_price_slot exposes it, so it is captured here where the information is
# still available.

import prices
import rules
import rng as rng_mod
import sharks


# Six spike drugs and five crash drugs can all fire in one roll.
comptime MAX_PRICE_EVENTS = 13


struct PriceEvent(Copyable, Movable):
    # kind is one of PRICE_EVENT_CHEAP (crash) / PRICE_EVENT_EXPENSIVE (spike, addicts text) / PRICE_EVENT_BUST (spike, cops text) / PRICE_EVENT_VET (Special K spike). The JS event
    # also carries a presentation `message`, which core deliberately drops.
    var kind: Int
    var drug_index: Int

    def __init__(out self, kind: Int = 0, drug_index: Int = 0):
        self.kind = kind
        self.drug_index = drug_index


comptime PRICE_EVENT_CHEAP = 0
comptime PRICE_EVENT_EXPENSIVE = 1
comptime PRICE_EVENT_BUST = 2
comptime PRICE_EVENT_VET = 3


struct World:
    var seed: UInt32
    var rng: rng_mod.Rng
    var day: Int64
    var num_days: Int64
    var cash: Float64
    # The resolved starting cash, retained so dw_world_reset can rebuild the
    # same fresh game without the caller re-supplying the config. Never mutated
    # after construction.
    var start_cash: Float64
    var bank: Float64
    var health: Int64
    var coat_capacity: Int64
    var guns: Int64
    var location_index: Int
    var dead: Bool
    var last_day_warned: Bool
    # The hospital price multiplier, (Random(9)+1), rolled daily with the prices.
    # The per-point cost is this times 50; 1..9 -> 50..450.
    var health_price_multiplier: Int64
    # The nasty-doctor infection flag (1 in 5 after a hospital purchase). Set by
    # hospital.buy_health; the later infection-counter consumption is out of scope.
    var infected: Bool

    # Loans in the order they were taken, at most one per shark. Balance is whole dollars and
    # days_left goes negative once a loan is past due.
    var loan_count: Int
    var loan_shark: Array[UInt8, sharks.NUM_SHARKS]
    var loan_balance: Array[Int64, sharks.NUM_SHARKS]
    var loan_days_left: Array[Int64, sharks.NUM_SHARKS]
    # Sharks out of jail; only released sharks who are not owed money make an offer.
    var shark_released: Array[UInt8, sharks.NUM_SHARKS]

    # Current prices, keyed by drug index.
    var price_value: Array[Int64, rules.NUM_DRUGS]
    var price_present: Array[UInt8, rules.NUM_DRUGS]
    var price_was_event: Array[UInt8, rules.NUM_DRUGS]
    var price_order: Array[UInt8, rules.NUM_DRUGS]
    var price_order_len: Int

    # The previous turn's prices, kept for the UI's price-delta display.
    var prev_price_value: Array[Int64, rules.NUM_DRUGS]
    var prev_price_present: Array[UInt8, rules.NUM_DRUGS]
    var prev_price_order: Array[UInt8, rules.NUM_DRUGS]
    var prev_price_order_len: Int

    # What the last roll recorded for every drug, available or not: the price the
    # keep-one-day-in-five rule reuses and the event flag (0 none, 1 spike, 2 crash)
    # that blocks both the keep and a repeat event. last_price is 0 before a roll.
    var last_price: Array[Int64, rules.NUM_DRUGS]
    var last_event: Array[UInt8, rules.NUM_DRUGS]
    # The price on the most recent day each drug was available, 0 if never; the
    # direction arrow compares against it.
    var seen_price: Array[Int64, rules.NUM_DRUGS]
    # Price direction against seen_price: -1 down, 0 flat or not comparable, 1 up.
    var price_direction: Array[Int8, rules.NUM_DRUGS]

    # Inventory, keyed by drug index.
    var inv_qty: Array[Int64, rules.NUM_DRUGS]
    var inv_avg_price: Array[Float64, rules.NUM_DRUGS]
    var inv_present: Array[UInt8, rules.NUM_DRUGS]
    var inv_order: Array[UInt8, rules.NUM_DRUGS]
    var inv_order_len: Int

    # Cheap/expensive events surfaced by the last generate_prices, in the order
    # the JS Set produced them.
    var price_events: Array[PriceEvent, MAX_PRICE_EVENTS]
    var price_events_len: Int

    def __init__(out self, seed: UInt32, num_days: Int64, start_cash: Float64):
        self.seed = seed
        self.rng = rng_mod.Rng(seed)
        self.day = 1
        self.num_days = num_days
        self.cash = start_cash
        self.start_cash = start_cash
        self.bank = 0.0
        self.health = rules.START_HEALTH
        self.coat_capacity = rules.START_COAT_CAPACITY
        self.guns = 0
        self.location_index = rules.find_location_index(rules.START_LOCATION)
        self.dead = False
        self.last_day_warned = False

        self.health_price_multiplier = 1
        self.infected = False

        self.loan_count = 0
        self.loan_shark = Array[UInt8, sharks.NUM_SHARKS]()
        self.loan_balance = Array[Int64, sharks.NUM_SHARKS]()
        self.loan_days_left = Array[Int64, sharks.NUM_SHARKS]()
        self.shark_released = Array[UInt8, sharks.NUM_SHARKS]()
        # The starter debt is a real loan from the first shark (N-06).
        self.shark_released[0] = 1
        self.loan_shark[0] = 0
        self.loan_balance[0] = Int64(rules.START_DEBT)
        self.loan_days_left[0] = sharks.shark(0).duration
        self.loan_count = 1

        self.price_value = Array[Int64, rules.NUM_DRUGS]()
        self.price_present = Array[UInt8, rules.NUM_DRUGS]()
        self.price_was_event = Array[UInt8, rules.NUM_DRUGS]()
        self.price_order = Array[UInt8, rules.NUM_DRUGS]()
        self.price_order_len = 0

        self.prev_price_value = Array[Int64, rules.NUM_DRUGS]()
        self.prev_price_present = Array[UInt8, rules.NUM_DRUGS]()
        self.prev_price_order = Array[UInt8, rules.NUM_DRUGS]()
        self.prev_price_order_len = 0

        self.last_price = Array[Int64, rules.NUM_DRUGS]()
        self.last_event = Array[UInt8, rules.NUM_DRUGS]()
        self.seen_price = Array[Int64, rules.NUM_DRUGS]()
        self.price_direction = Array[Int8, rules.NUM_DRUGS]()

        self.inv_qty = Array[Int64, rules.NUM_DRUGS]()
        self.inv_avg_price = Array[Float64, rules.NUM_DRUGS]()
        self.inv_present = Array[UInt8, rules.NUM_DRUGS]()
        self.inv_order = Array[UInt8, rules.NUM_DRUGS]()
        self.inv_order_len = 0

        self.price_events = Array[PriceEvent, MAX_PRICE_EVENTS](fill=PriceEvent())
        self.price_events_len = 0

    def health_price(ref self) -> Int64:
        return Int64(rules.HOSPITAL_MULTIPLIER_BASE) * self.health_price_multiplier

    # ---- loans ------------------------------------------------------------

    def total_debt(ref self) -> Int64:
        var total: Int64 = 0
        for i in range(self.loan_count):
            total += self.loan_balance[i]
        return total

    # The slot of the loan owed to this shark, or -1.
    def loan_slot_of(ref self, shark_index: Int) -> Int:
        for i in range(self.loan_count):
            if Int(self.loan_shark[i]) == shark_index:
                return i
        return -1

    def add_loan(mut self, shark_index: Int, balance: Int64, days_left: Int64):
        self.loan_shark[self.loan_count] = UInt8(shark_index)
        self.loan_balance[self.loan_count] = balance
        self.loan_days_left[self.loan_count] = days_left
        self.loan_count += 1

    def remove_loan(mut self, slot: Int):
        for i in range(slot, self.loan_count - 1):
            self.loan_shark[i] = self.loan_shark[i + 1]
            self.loan_balance[i] = self.loan_balance[i + 1]
            self.loan_days_left[i] = self.loan_days_left[i + 1]
        self.loan_count -= 1
        self.loan_shark[self.loan_count] = 0
        self.loan_balance[self.loan_count] = 0
        self.loan_days_left[self.loan_count] = 0

    # ---- prices -----------------------------------------------------------

    def price_count(ref self) -> Int:
        return self.price_order_len

    def prev_price_count(ref self) -> Int:
        return self.prev_price_order_len

    def has_price(ref self, drug_index: Int) -> Bool:
        return self.price_present[drug_index] != 0

    def price_of(ref self, drug_index: Int) -> Int64:
        return self.price_value[drug_index]

    def was_event_price(ref self, drug_index: Int) -> Bool:
        return self.price_was_event[drug_index] != 0

    # Drops the roster but keeps the event list. generate_prices clears both;
    # the fixture's setPrices helper replaces only state.prices, so the events
    # from the previous turn survive it.
    def clear_price_roster(mut self):
        for i in range(rules.NUM_DRUGS):
            self.price_present[i] = 0
            self.price_was_event[i] = 0
        self.price_order_len = 0

    def clear_prices(mut self):
        self.clear_price_roster()
        self.price_events_len = 0

    def set_price(mut self, drug_index: Int, value: Int64, was_event: Bool):
        if self.price_present[drug_index] == 0:
            self.price_order[self.price_order_len] = UInt8(drug_index)
            self.price_order_len += 1
        self.price_present[drug_index] = 1
        self.price_value[drug_index] = value
        self.price_was_event[drug_index] = 1 if was_event else 0

    def add_price_event(mut self, kind: Int, drug_index: Int):
        self.price_events[self.price_events_len] = PriceEvent(kind, drug_index)
        self.price_events_len += 1

    # state.prevPrices = state.prices, before state.prices is replaced.
    def snapshot_prices_to_prev(mut self):
        for i in range(rules.NUM_DRUGS):
            self.prev_price_present[i] = self.price_present[i]
            self.prev_price_value[i] = self.price_value[i]
        for i in range(self.price_order_len):
            self.prev_price_order[i] = self.price_order[i]
        self.prev_price_order_len = self.price_order_len

    # ---- inventory --------------------------------------------------------

    def inv_count(ref self) -> Int:
        return self.inv_order_len

    def has_inventory(ref self, drug_index: Int) -> Bool:
        return self.inv_present[drug_index] != 0

    def inv_qty_of(ref self, drug_index: Int) -> Int64:
        return self.inv_qty[drug_index]

    def inv_avg_price_of(ref self, drug_index: Int) -> Float64:
        return self.inv_avg_price[drug_index]

    def set_inventory(mut self, drug_index: Int, qty: Int64, avg_price: Float64):
        if qty == 0:
            self._drop_inventory(drug_index)
            return
        if self.inv_present[drug_index] == 0:
            self.inv_order[self.inv_order_len] = UInt8(drug_index)
            self.inv_order_len += 1
        self.inv_present[drug_index] = 1
        self.inv_qty[drug_index] = qty
        self.inv_avg_price[drug_index] = avg_price

    def _drop_inventory(mut self, drug_index: Int):
        if self.inv_present[drug_index] == 0:
            return
        self.inv_present[drug_index] = 0
        self.inv_qty[drug_index] = 0
        self.inv_avg_price[drug_index] = 0.0
        var write = 0
        for i in range(self.inv_order_len):
            if Int(self.inv_order[i]) != drug_index:
                self.inv_order[write] = self.inv_order[i]
                write += 1
        self.inv_order_len = write

    # addToInventory: grant as much as fits, return the amount granted.
    def add_to_inventory(mut self, drug_index: Int, qty: Int64) -> Int64:
        var space_left = self.coat_capacity - self.coat_used()
        var grant = qty
        if grant > space_left:
            grant = space_left
        if grant <= 0:
            return 0
        var held = self.inv_qty[drug_index]
        # The JS helper does not touch avgPrice, so a granted unit keeps the
        # existing average. That is a quirk of the original, preserved here.
        self.set_inventory(drug_index, held + grant, self.inv_avg_price[drug_index])
        return grant

    # removeFromInventory: remove at most what is held, return the amount removed.
    def remove_from_inventory(mut self, drug_index: Int, qty: Int64) -> Int64:
        if self.inv_present[drug_index] == 0:
            return 0
        var held = self.inv_qty[drug_index]
        var removed = qty
        if removed > held:
            removed = held
        self.set_inventory(drug_index, held - removed, self.inv_avg_price[drug_index])
        return removed

    # ---- coat -------------------------------------------------------------

    # coatUsed: every held unit; a gun takes no coat space.
    def coat_used(ref self) -> Int64:
        var used: Int64 = 0
        for i in range(self.inv_order_len):
            used += self.inv_qty[Int(self.inv_order[i])]
        return used


# newGame. num_days 0 means "use the ruleset default"; start_cash -1 means the
# same, matching dw_config's sentinels. start_cash 0 is a real value.
def new_game(seed: UInt32, num_days: Int64, start_cash: Int64) raises -> World:
    var days = num_days
    if days == 0:
        days = rules.NUM_DAYS
    var cash = Float64(start_cash)
    if start_cash < 0:
        cash = Float64(rules.START_CASH)
    var game = World(seed, days, cash)
    _ = prices.generate_prices(game)
    return game^
