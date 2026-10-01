# tests/mojo/rules_test.mojo — slice 2 parity: the rule tables.
#
# The tables are transcribed from index.html:641-681. They are the input to
# every price, event and combat roll, so a wrong bound here shows up as a
# divergence much later and in a confusing place. Checking them directly keeps
# that failure local.
#
# The end-to-end check is fixture 01, whose price roster is generated from these
# bounds; this test is the fast, precise one.

import lexeme
import rules
from std.testing import assert_equal, assert_true, assert_false, TestSuite


def test_scalar_rules_match_js() raises:
    assert_equal(rules.NUM_DAYS, 31)
    assert_equal(rules.START_CASH, 2000)
    assert_equal(rules.START_DEBT, 5500)
    assert_equal(rules.START_HEALTH, 100)
    assert_equal(rules.START_COAT_CAPACITY, 100)
    assert_equal(rules.DEBT_INTEREST, 0.10)
    assert_equal(rules.BANK_INTEREST, 0.05)
    assert_equal(rules.START_LOCATION, "bronx")
    assert_equal(rules.CHEAP_DIVIDE, 10)
    assert_equal(rules.EXPENSIVE_MULTIPLY, 5)
    assert_equal(rules.DEALER_ODDS, 14)
    assert_equal(rules.COAT_MIN_POCKETS, 11)
    assert_equal(rules.COAT_MAX_POCKETS, 20)
    assert_equal(rules.COAT_MIN_PRICE, 201)
    assert_equal(rules.COAT_MAX_PRICE, 350)
    assert_equal(rules.GUN_MIN_PRICE, 301)
    assert_equal(rules.GUN_MAX_PRICE, 550)
    assert_equal(rules.GUN_NAME_COUNT, 4)


def test_locations_match_js() raises:
    # id|name, in RULES order.
    var expected: List[String] = [
        "bronx|Bronx",
        "ghetto|Ghetto",
        "centralpark|Central Park",
        "manhattan|Manhattan",
        "coneyisland|Coney Island",
        "brooklyn|Brooklyn",
    ]
    var table = rules.locations()
    assert_equal(len(table), len(expected))
    for i in range(len(expected)):
        var parts = expected[i].split("|")
        assert_equal(table[i].id, String(parts[0]))
        assert_equal(table[i].name, String(parts[1]))


def test_drugs_match_js() raises:
    # id|name|min|max|cheap|expensive, in RULES order.
    var expected: List[String] = [
        "acid|Acid|1000|4500|t|f",
        "cocaine|Cocaine|15000|30000|f|t",
        "crack|Crack|1000|3500|f|f",
        "ecstasy|Ecstasy|10|60|t|f",
        "hashish|Hashish|450|1350|t|f",
        "heroin|Heroin|5000|14000|f|t",
        "opium|Opium|500|1300|f|t",
        "peyote|Peyote|200|700|f|f",
        "shrooms|Shrooms|600|1350|f|f",
        "smack|Smack|1500|4500|f|f",
        "speed|Speed|70|250|f|t",
        "weed|Weed|300|900|t|f",
    ]
    var table = rules.drugs()
    assert_equal(len(table), len(expected))
    for i in range(len(expected)):
        var parts = expected[i].split("|")
        assert_equal(table[i].id, String(parts[0]))
        assert_equal(table[i].name, String(parts[1]))
        assert_equal(table[i].min_price, lexeme.to_int(String(parts[2])))
        assert_equal(table[i].max_price, lexeme.to_int(String(parts[3])))
        assert_equal(table[i].cheap, lexeme.to_bool(String(parts[4])))
        assert_equal(table[i].expensive, lexeme.to_bool(String(parts[5])))


def test_find_location_index() raises:
    # Index order is the RULES order, which the ABI's location_index uses.
    assert_equal(rules.find_location_index("bronx"), 0)
    assert_equal(rules.find_location_index("ghetto"), 1)
    assert_equal(rules.find_location_index("centralpark"), 2)
    assert_equal(rules.find_location_index("manhattan"), 3)
    assert_equal(rules.find_location_index("coneyisland"), 4)
    assert_equal(rules.find_location_index("brooklyn"), 5)
    # JS findLocation returns undefined for an unknown id; -1 is the Mojo
    # equivalent and matches dw_find_location_index.
    assert_equal(rules.find_location_index("atlantis"), -1)


def test_find_drug_index() raises:
    assert_equal(rules.find_drug_index("acid"), 0)
    assert_equal(rules.find_drug_index("cocaine"), 1)
    assert_equal(rules.find_drug_index("crack"), 2)
    assert_equal(rules.find_drug_index("ecstasy"), 3)
    assert_equal(rules.find_drug_index("hashish"), 4)
    assert_equal(rules.find_drug_index("heroin"), 5)
    assert_equal(rules.find_drug_index("opium"), 6)
    assert_equal(rules.find_drug_index("peyote"), 7)
    assert_equal(rules.find_drug_index("shrooms"), 8)
    assert_equal(rules.find_drug_index("smack"), 9)
    assert_equal(rules.find_drug_index("speed"), 10)
    assert_equal(rules.find_drug_index("weed"), 11)
    assert_equal(rules.find_drug_index("aspirin"), -1)


def test_drug_ids_are_unique() raises:
    # find_drug_index returns the first match, so a duplicate id would silently
    # shadow a drug.
    var table = rules.drugs()
    for i in range(len(table)):
        for j in range(i + 1, len(table)):
            assert_false(table[i].id == table[j].id)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
