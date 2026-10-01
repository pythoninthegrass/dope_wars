# core/src/rules.mojo — the rulebook: fixed tables and lookup helpers.
#
# Ported from RULES / findDrug / findLocation in index.html:641-684. Every price
# band, event probability and combat number in the game comes from here, so this
# file is the single place a ruleset change belongs.
#
# Tables are returned by value rather than held in module-level storage: core/
# forbids global mutable state (docs/layer-boundaries.md), and a six- or
# twelve-entry list is cheap enough that rebuilding it per call is not worth
# trading the invariant for.
#
# Lookups return an index, not a struct, matching dw_find_drug_index /
# dw_find_location_index in include/dopewars.h. -1 means "not found", which is
# the Mojo equivalent of the JS findDrug/findLocation returning undefined.

comptime NUM_DAYS = 31
comptime START_CASH = 2000
comptime START_DEBT = 5500
comptime START_HEALTH = 100
comptime START_COAT_CAPACITY = 100
comptime DEBT_INTEREST = 0.10
comptime BANK_INTEREST = 0.05  # beermat-verified (TASK-009): was 0.02
comptime START_LOCATION = "bronx"
comptime GUN_DAMAGE = 5
comptime GUN_SPACE = 4
comptime PLAYER_ARMOR = 100
comptime CHEAP_DIVIDE = 10
comptime EXPENSIVE_MULTIPLY = 5
comptime ABSENT_ODDS = 8
comptime EVENT_ODDS = 20
comptime BANK_PURCHASE_FEE = 0.25

comptime COAT_MIN_POCKETS = 10
comptime COAT_MAX_POCKETS = 30
comptime COAT_MIN_PRICE = 200
comptime COAT_MAX_PRICE = 500
comptime GUN_MIN_PRICE = 250
comptime GUN_MAX_PRICE = 600

# Per-dealer chance of showing up on arrival when no chase started
# (`index.html:1387-1388`).
comptime DEALER_VISIT_CHANCE = 0.15

comptime NUM_LOCATIONS = 6
comptime NUM_DRUGS = 12


struct Location:
    var id: String
    var name: String
    var police: Int64

    def __init__(
        out self,
        id: String,
        name: String,
        police: Int64,
    ):
        self.id = id
        self.name = name
        self.police = police


struct Drug:
    var id: String
    var name: String
    var min_price: Int64
    var max_price: Int64
    var cheap: Bool
    var expensive: Bool

    def __init__(
        out self,
        id: String,
        name: String,
        min_price: Int64,
        max_price: Int64,
        cheap: Bool,
        expensive: Bool,
    ):
        self.id = id
        self.name = name
        self.min_price = min_price
        self.max_price = max_price
        self.cheap = cheap
        self.expensive = expensive


def locations() -> List[Location]:
    return [
        Location("bronx", "Bronx", 10),
        Location("ghetto", "Ghetto", 5),
        Location("centralpark", "Central Park", 15),
        Location("manhattan", "Manhattan", 90),
        Location("coneyisland", "Coney Island", 20),
        Location("brooklyn", "Brooklyn", 70),
    ]


def drugs() -> List[Drug]:
    return [
        Drug("acid", "Acid", 1000, 4500, True, False),
        Drug("cocaine", "Cocaine", 15000, 30000, False, True),
        Drug("crack", "Crack", 1000, 3500, False, False),
        Drug("ecstasy", "Ecstasy", 10, 60, True, False),
        Drug("hashish", "Hashish", 450, 1350, True, False),
        Drug("heroin", "Heroin", 5000, 14000, False, True),
        Drug("opium", "Opium", 500, 1300, False, True),
        Drug("peyote", "Peyote", 200, 700, False, False),
        Drug("shrooms", "Shrooms", 600, 1350, False, False),
        Drug("smack", "Smack", 1500, 4500, False, False),
        Drug("speed", "Speed", 70, 250, False, True),
        Drug("weed", "Weed", 300, 900, True, False),
    ]


def find_location_index(id: String) -> Int:
    var table = locations()
    for i in range(len(table)):
        if table[i].id == id:
            return i
    return -1


def find_drug_index(id: String) -> Int:
    var table = drugs()
    for i in range(len(table)):
        if table[i].id == id:
            return i
    return -1
