# tests/mojo/replay.mojo — replay an oracle fixture against the Mojo core.
#
# This is the parity gate. For each recorded step it runs the equivalent Mojo
# call, compares the return value against the oracle's, then compares the whole
# world against the oracle's post-call snapshot. Any divergence fails with the
# fixture, step and call named.
#
# The runner helpers (setPrices, setPrevPrices, setInventory, setField, buyCheapest,
# insertHighScores, serializeRoundTrip) are the same ones tests/fixtures/README.md
# obliges every port to implement. They exist so a fixture can drive the engine
# into a specific state without depending on prior RNG history.

import combat
import dealers
import events
import finances
import fixtures
import harness
import prices
import record
import result
import rules
import score
import serialize
import trade
import travel
import world
from std.testing import assert_equal, assert_true


def records_for(fixture: String) raises -> List[record.Record]:
    var out = List[record.Record]()
    for line in fixtures.mjo_steps():
        var parsed = record.parse_record(String(line))
        if parsed.fixture == fixture:
            out.append(parsed^)
    return out^


def _drug_index(ref rec: record.Record) raises -> Int:
    var name = rec.args.string_at("drug")
    var index = rules.find_drug_index(name)
    if index < 0:
        raise Error("unknown drug in fixture args: " + name)
    return index


# setPrices replaces the whole roster with the given drug -> price map, in the
# order the fixture lists them.
def _apply_set_prices(mut game: world.World, ref rec: record.Record) raises:
    # The JS helper assigns state.prices only; state.priceEvents is untouched.
    game.clear_price_roster()
    for pair in rec.args.pairs:
        var index = rules.find_drug_index(pair.path)
        if index < 0:
            raise Error("setPrices got an unknown drug: " + pair.path)
        game.set_price(index, pair.as_int(), False)


# setPrevPrices replaces the previous market the arrival event draws its drugs from.
def _apply_set_prev_prices(mut game: world.World, ref rec: record.Record) raises:
    game.prev_price_order_len = 0
    for i in range(rules.NUM_DRUGS):
        game.prev_price_present[i] = 0
        game.prev_price_value[i] = 0
    for pair in rec.args.pairs:
        var index = rules.find_drug_index(pair.path)
        if index < 0:
            raise Error("setPrevPrices got an unknown drug: " + pair.path)
        game.prev_price_order[game.prev_price_order_len] = UInt8(index)
        game.prev_price_order_len += 1
        game.prev_price_present[index] = 1
        game.prev_price_value[index] = pair.as_int()


# setInventory replaces the whole inventory. The helper always uses avgPrice 0.
def _apply_set_inventory(mut game: world.World, ref rec: record.Record) raises:
    for i in range(rules.NUM_DRUGS):
        game.set_inventory(i, 0, 0.0)
    for pair in rec.args.pairs:
        var index = rules.find_drug_index(pair.path)
        if index < 0:
            raise Error("setInventory got an unknown drug: " + pair.path)
        game.set_inventory(index, pair.as_int(), 0.0)


# setField is Object.assign(state, args): only the named fields change.
def _apply_set_field(mut game: world.World, ref rec: record.Record) raises:
    ref args = rec.args
    if args.has("cash"):
        game.cash = args.float_at("cash")
    if args.has("debt"):
        game.debt = args.float_at("debt")
    if args.has("bank"):
        game.bank = args.float_at("bank")
    if args.has("health"):
        game.health = args.int_at("health")
    if args.has("coatCapacity"):
        game.coat_capacity = args.int_at("coatCapacity")
    if args.has("guns"):
        game.guns = args.int_at("guns")
    if args.has("day"):
        game.day = args.int_at("day")
    if args.has("dead"):
        game.dead = args.bool_at("dead")
    if args.has("location"):
        game.location_index = rules.find_location_index(args.string_at("location"))
    # An empty container argument means "set this to empty", which the flattener
    # records as a bare path with an empty lexeme.
    if args.has("inventory"):
        for i in range(rules.NUM_DRUGS):
            game.set_inventory(i, 0, 0.0)
    if args.has("prices"):
        game.clear_price_roster()


# buyCheapest: sort the roster by price ascending (stable, so ties keep roster
# order) and buy one unit of the first drug that is affordable and fits.
def _apply_buy_cheapest(mut game: world.World, ref rec: record.Record) raises:
    var order = game.price_order.copy()
    var count = game.price_count()
    # Stable insertion sort by price.
    for i in range(1, count):
        var key = order[i]
        var j = i
        while j > 0 and game.price_value[Int(order[j - 1])] > game.price_value[Int(key)]:
            order[j] = order[j - 1]
            j -= 1
        order[j] = key
    for i in range(count):
        var index = Int(order[i])
        var outcome = trade.buy(game, index, 1)
        if outcome.ok():
            assert_equal(rec.ret.string_at("drug"), rules.drugs()[index].id)
            assert_equal(rec.ret.int_at("price"), game.price_value[index])
            return
    assert_equal(rec.ret.bool_at("ok"), False)


def _apply_insert_high_scores(mut game: world.World, ref rec: record.Record) raises:
    var count = rec.args.int_at("count")
    var offset = rec.args.int_at("offset") if rec.args.has("offset") else Int64(0)
    var scores = List[score.HighScore]()
    for i in range(Int(count)):
        _ = score.insert_high_score(
            scores,
            score.HighScore("p" + String(i), Float64(i * 100 + Int(offset)), 31, False, "2026-01-01"),
        )
    var expected = rec.ret.children("scores")
    var entries = harness.first_segments(expected)
    assert_equal(len(scores), len(entries))
    for i in range(len(entries)):
        var prefix = "scores." + String(i) + "."
        assert_equal(scores[i].name, rec.ret.string_at(prefix + "name"))
        assert_equal(scores[i].score, rec.ret.float_at(prefix + "score"))
        assert_equal(scores[i].day, rec.ret.int_at(prefix + "day"))
        assert_equal(scores[i].dead, rec.ret.bool_at(prefix + "dead"))
        assert_equal(scores[i].date, rec.ret.string_at(prefix + "date"))


def _apply_serialize_round_trip(mut game: world.World, ref rec: record.Record) raises:
    var before = serialize.dump(game)
    var restored = serialize.load(before)
    # The oracle asserts the two snapshots are deep-equal; comparing the
    # re-dumped bytes is the same claim and is exact.
    var after = serialize.dump(restored)
    assert_equal(len(before), len(after))
    for i in range(len(before)):
        assert_equal(before[i], after[i])
    assert_equal(rec.ret.bool_at("equal"), True)


def _assert_cop_fire(fire: combat.CopFire, ref rec: record.Record) raises:
    assert_equal(fire.hit, rec.ret.bool_at(_hit_key(rec.call)))
    assert_equal(fire.damage, rec.ret.int_at("damage"))
    assert_equal(fire.dead, rec.ret.bool_at("dead"))


# fight reports the cops' shot as copHit, because hit would read as the player's.
def _hit_key(call: String) -> String:
    if call == "fight":
        return "copHit"
    return "hit"


def run_step(mut game: world.World, ref rec: record.Record) raises:
    # A step that carries a scripted RNG replaces the draw source for that call
    # only; the next step without one goes back to the seeded stream.
    if rec.has_rng:
        game.rng.set_script(rec.rng)
    else:
        game.rng.clear_script()
    var call = rec.call
    if call == "generatePrices":
        var produced = prices.generate_prices(game)
        harness.assert_price_event_list_match(produced, rec.ret.pairs)
    elif call == "buy":
        var outcome = trade.buy(game, _drug_index(rec), rec.args.int_at("qty"))
        harness.assert_outcome_matches(outcome, rec)
    elif call == "sell":
        var outcome = trade.sell(game, _drug_index(rec), rec.args.int_at("qty"))
        harness.assert_outcome_matches(outcome, rec)
    elif call == "travel":
        var dest = rules.find_location_index(rec.args.string_at("dest"))
        var outcome = travel.travel(game, dest)
        harness.assert_outcome_matches(outcome, rec)
    elif call == "finances":
        var action = finances.parse_action(rec.args.string_at("action"))
        var outcome = finances.finances(game, action, rec.args.float_at("amount"))
        harness.assert_outcome_matches(outcome, rec)
    elif call == "rollArrivalEvent":
        var produced = events.roll_arrival_event(game)
        harness.assert_arrival_event_matches(produced, rec.ret)
    elif call == "rollDealerVisit":
        var kind = dealers.roll_dealer_visit(game)
        var expected = rec.ret.string_at("kind")
        if expected == "coat":
            assert_equal(kind, dealers.DEALER_COAT)
        elif expected == "gun":
            assert_equal(kind, dealers.DEALER_GUN)
        else:
            assert_equal(kind, dealers.DEALER_NONE)
    elif call == "rollCoatDealerOffer":
        var offer = dealers.roll_coat_dealer_offer(game)
        assert_equal(offer.price, rec.ret.int_at("price"))
        assert_equal(offer.offered, rec.ret.bool_at("offered"))
    elif call == "rollGunDealerOffer":
        var offer = dealers.roll_gun_dealer_offer(game)
        assert_equal(offer.price, rec.ret.int_at("price"))
        assert_equal(offer.offered, rec.ret.bool_at("offered"))
        assert_equal(offer.name_index, rec.ret.int_at("nameIndex"))
    elif call == "acceptCoatOffer":
        var offer = dealers.CoatOffer(rec.args.int_at("offer.price"), True)
        var outcome = dealers.accept_coat_offer(game, offer)
        harness.assert_purchase_matches(outcome, rec)
    elif call == "acceptGunOffer":
        var offer = dealers.GunOffer(
            rec.args.int_at("offer.price"), True, rec.args.int_at("offer.nameIndex")
        )
        var outcome = dealers.accept_gun_offer(game, offer)
        harness.assert_purchase_matches(outcome, rec)
    elif call == "shouldStartChase":
        assert_equal(combat.should_start_chase(game), rec.ret.bool_at("value"))
    elif call == "startChase":
        var chase = combat.start_chase(game)
        assert_equal(chase.deputies, rec.ret.int_at("deputies"))
        assert_equal(rec.ret.string_at("cop"), "Officer Hardass")
        assert_equal(rec.ret.bool_at("canFight"), game.guns > 0)
    elif call == "applyDamage":
        var health = events.apply_damage(game, rec.args.int_at("amount"))
        assert_equal(health, rec.ret.int_at("value"))
    elif call == "runFromChase":
        var outcome = combat.run_from_chase(game)
        assert_equal(outcome.escaped, rec.ret.bool_at("escaped"))
        _assert_cop_fire(outcome.fire, rec)
    elif call == "stayInChase":
        _assert_cop_fire(combat.stay_in_chase(game), rec)
    elif call == "fight":
        var chase = combat.Chase(rec.args.int_at("chase.deputies"))
        var outcome = combat.fight(game, chase)
        assert_equal(outcome.killed, rec.ret.bool_at("killed"))
        assert_equal(outcome.won, rec.ret.bool_at("won"))
        assert_equal(outcome.reward, rec.ret.int_at("reward"))
        assert_equal(outcome.doctor.price, rec.ret.int_at("doctor.price"))
        _assert_cop_fire(outcome.fire, rec)
    elif call == "acceptDoctorOffer":
        var code = combat.accept_doctor_offer(game, combat.DoctorOffer(rec.args.int_at("offer.price")))
        assert_equal(code == result.OK, rec.ret.bool_at("ok"))
    elif call == "finish":
        var outcome = score.finish(game)
        assert_equal(outcome.score, rec.ret.float_at("score"))
        assert_equal(outcome.dead, rec.ret.bool_at("dead"))
        assert_equal(outcome.day, rec.ret.int_at("day"))
    elif call == "setPrices":
        _apply_set_prices(game, rec)
    elif call == "setPrevPrices":
        _apply_set_prev_prices(game, rec)
    elif call == "setInventory":
        _apply_set_inventory(game, rec)
    elif call == "setField":
        _apply_set_field(game, rec)
    elif call == "buyCheapest":
        _apply_buy_cheapest(game, rec)
    elif call == "insertHighScores":
        _apply_insert_high_scores(game, rec)
    elif call == "serializeRoundTrip":
        _apply_serialize_round_trip(game, rec)
    else:
        raise Error("replay has no case for call: " + call)


def replay_fixture(fixture: String) raises:
    var records = records_for(fixture)
    assert_true(len(records) > 0)
    ref first = records[0]
    assert_equal(first.call, "newGame")
    var game = world.new_game(
        UInt32(first.args.int_at("seed")), 0, -1
    )
    harness.assert_state_matches(game, first.state)
    for i in range(1, len(records)):
        try:
            run_step(game, records[i])
            harness.assert_state_matches(game, records[i].state)
        except e:
            raise Error(
                fixture + " step " + String(i) + " (" + records[i].call + "): " + String(e)
            )
