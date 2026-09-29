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
comptime CHEAP_DIVIDE = 4
comptime EXPENSIVE_MULTIPLY = 4
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
    var min_drugs: Int64
    var max_drugs: Int64

    def __init__(
        out self,
        id: String,
        name: String,
        police: Int64,
        min_drugs: Int64,
        max_drugs: Int64,
    ):
        self.id = id
        self.name = name
        self.police = police
        self.min_drugs = min_drugs
        self.max_drugs = max_drugs


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
        Location("bronx", "Bronx", 10, 7, 12),
        Location("ghetto", "Ghetto", 5, 8, 12),
        Location("centralpark", "Central Park", 15, 6, 12),
        Location("manhattan", "Manhattan", 90, 4, 10),
        Location("coneyisland", "Coney Island", 20, 6, 12),
        Location("brooklyn", "Brooklyn", 70, 4, 11),
    ]


def drugs() -> List[Drug]:
    return [
        Drug("acid", "Acid", 1000, 4400, True, False),
        Drug("cocaine", "Cocaine", 15000, 29000, False, True),
        Drug("crack", "Crack", 1500, 4800, False, False),
        Drug("ecstasy", "Ecstasy", 10, 75, False, False),  # beermat-verified (TASK-009): was 800-2200
        Drug("hashish", "Hashish", 480, 1320, True, False),
        Drug("heroin", "Heroin", 5500, 13500, False, True),
        Drug("opium", "Opium", 540, 3700, False, True),
        Drug("peyote", "Peyote", 220, 700, False, False),
        Drug("shrooms", "Shrooms", 600, 1300, False, False),
        Drug("smack", "Smack", 1500, 4500, False, True),  # beermat-verified (TASK-009): was 3500-10000
        Drug("speed", "Speed", 90, 250, True, True),
        Drug("weed", "Weed", 300, 1100, True, False),
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
