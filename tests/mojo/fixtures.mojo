# tests/mojo/fixtures.mojo — GENERATED, do not edit.
#
# Source of truth is tests/fixtures/*.jsonl. Regenerate with
# `node tests/fixtures/gen-mojo.mjs`; `task core:test:check-generated` fails
# if this file is stale.
#
# One record per fixture step:
#   fixture | call | rng lexemes | arg pairs | return pairs | state pairs
# Pairs are `dotted.path=lexeme`, ';'-separated, in document order.
#
# Mojo 1.1.0 has no global variables, so the corpus is returned by a function.

def mjo_steps() -> List[String]:
    return [
        "02-buy-sell-edges|newGame|-|args.seed=1|ret.seed=1;ret.day=1;ret.numDays=31;ret.cash=2000;ret.debt=5500;ret.bank=0;ret.health=100;ret.coatCapacity=100;ret.guns=0;ret.location=bronx;ret.inventory=;ret.prices.cocaine=29716;ret.prices.crack=2532;ret.prices.ecstasy=31;ret.prices.hashish=890;ret.prices.heroin=7227;ret.prices.opium=553;ret.prices.peyote=343;ret.prices.shrooms=632;ret.prices.smack=3271;ret.prices.speed=123;ret.prices.weed=628;ret.prevPrices=;ret.dead=f;ret.lastDayWarned=f;ret.priceEvents=|state.cash=2000;state.coatCapacity=100;state.inventory=;state.prices.cocaine=29716;state.prices.crack=2532;state.prices.ecstasy=31;state.prices.hashish=890;state.prices.heroin=7227;state.prices.opium=553;state.prices.peyote=343;state.prices.shrooms=632;state.prices.smack=3271;state.prices.speed=123;state.prices.weed=628",
        "02-buy-sell-edges|setPrices|-|args.speed=100|ret.ok=t|state.cash=2000;state.coatCapacity=100;state.inventory=;state.prices.speed=100",
        "02-buy-sell-edges|setField|-|args.coatCapacity=5|ret.ok=t|state.cash=2000;state.coatCapacity=5;state.inventory=;state.prices.speed=100",
        "02-buy-sell-edges|buy|-|args.drug=speed;args.qty=5|ret.ok=t|state.cash=1500;state.coatCapacity=5;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|buy|-|args.drug=speed;args.qty=1|ret.ok=f;ret.reason=Not enough cash or coat space.|state.cash=1500;state.coatCapacity=5;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|buy|-|args.drug=speed;args.qty=0|ret.ok=f;ret.reason=Nothing to buy.|state.cash=1500;state.coatCapacity=5;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|buy|-|args.drug=cocaine;args.qty=1|ret.ok=f;ret.reason=Cocaine isn't traded here.|state.cash=1500;state.coatCapacity=5;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|setField|-|args.cash=5|ret.ok=t|state.cash=5;state.coatCapacity=5;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|setPrices|-|args.cocaine=15000|ret.ok=t|state.cash=5;state.coatCapacity=5;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.cocaine=15000",
        "02-buy-sell-edges|buy|-|args.drug=cocaine;args.qty=1|ret.ok=f;ret.reason=Duh! Check the price of Cocaine, dude!|state.cash=5;state.coatCapacity=5;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.cocaine=15000",
        "02-buy-sell-edges|setField|-|args.cash=2000;args.coatCapacity=100|ret.ok=t|state.cash=2000;state.coatCapacity=100;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.cocaine=15000",
        "02-buy-sell-edges|setPrices|-|args.speed=100|ret.ok=t|state.cash=2000;state.coatCapacity=100;state.inventory.speed.qty=5;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|sell|-|args.drug=speed;args.qty=3|ret.ok=t|state.cash=2300;state.coatCapacity=100;state.inventory.speed.qty=2;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|sell|-|args.drug=speed;args.qty=99|ret.ok=f;ret.reason=You don't have that many to sell.|state.cash=2300;state.coatCapacity=100;state.inventory.speed.qty=2;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|sell|-|args.drug=speed;args.qty=0|ret.ok=f;ret.reason=You don't have that many to sell.|state.cash=2300;state.coatCapacity=100;state.inventory.speed.qty=2;state.inventory.speed.avgPrice=100;state.prices.speed=100",
        "02-buy-sell-edges|setPrices|-|args.cocaine=20000|ret.ok=t|state.cash=2300;state.coatCapacity=100;state.inventory.speed.qty=2;state.inventory.speed.avgPrice=100;state.prices.cocaine=20000",
        "02-buy-sell-edges|sell|-|args.drug=speed;args.qty=1|ret.ok=f;ret.reason=Speed isn't traded here.|state.cash=2300;state.coatCapacity=100;state.inventory.speed.qty=2;state.inventory.speed.avgPrice=100;state.prices.cocaine=20000",
        "03-travel-interest|newGame|-|args.seed=1|ret.seed=1;ret.day=1;ret.numDays=31;ret.cash=2000;ret.debt=5500;ret.bank=0;ret.health=100;ret.coatCapacity=100;ret.guns=0;ret.location=bronx;ret.inventory=;ret.prices.cocaine=29716;ret.prices.crack=2532;ret.prices.ecstasy=31;ret.prices.hashish=890;ret.prices.heroin=7227;ret.prices.opium=553;ret.prices.peyote=343;ret.prices.shrooms=632;ret.prices.smack=3271;ret.prices.speed=123;ret.prices.weed=628;ret.prevPrices=;ret.dead=f;ret.lastDayWarned=f;ret.priceEvents=|state.day=1;state.bank=0",
        "03-travel-interest|setField|-|args.bank=1000|ret.ok=t|state.day=1;state.bank=1000",
        "03-travel-interest|travel|-|args.dest=ghetto|ret.ok=t;ret.priceEvents=|state.day=2;state.bank=1050",
        "03-travel-interest|setField|-|args.bank=70|ret.ok=t|state.day=2;state.bank=70",
        "03-travel-interest|travel|-|args.dest=bronx|ret.ok=t;ret.priceEvents=|state.day=3;state.bank=74",
        "03-travel-interest|setField|-|args.bank=0|ret.ok=t|state.day=3;state.bank=0",
        "03-travel-interest|travel|-|args.dest=ghetto|ret.ok=t;ret.priceEvents.0.type=expensive;ret.priceEvents.0.drug=heroin|state.day=4;state.bank=0",
        "03-travel-interest|setField|-|args.bank=-100|ret.ok=t|state.day=4;state.bank=-100",
        "03-travel-interest|travel|-|args.dest=bronx|ret.ok=t;ret.priceEvents=|state.day=5;state.bank=-100",
        "05-dealers|newGame|-|args.seed=1|ret.seed=1;ret.day=1;ret.numDays=31;ret.cash=2000;ret.debt=5500;ret.bank=0;ret.health=100;ret.coatCapacity=100;ret.guns=0;ret.location=bronx;ret.inventory=;ret.prices.cocaine=29716;ret.prices.crack=2532;ret.prices.ecstasy=31;ret.prices.hashish=890;ret.prices.heroin=7227;ret.prices.opium=553;ret.prices.peyote=343;ret.prices.shrooms=632;ret.prices.smack=3271;ret.prices.speed=123;ret.prices.weed=628;ret.prevPrices=;ret.dead=f;ret.lastDayWarned=f;ret.priceEvents=|state.cash=2000;state.bank=0;state.coatCapacity=100",
        "05-dealers|setField|-|args.cash=500;args.bank=0|ret.ok=t|state.cash=500;state.bank=0;state.coatCapacity=100",
        "05-dealers|acceptCoatOffer|0|args.offer.price=300|ret.ok=t;ret.pockets=11|state.cash=200;state.bank=0;state.coatCapacity=111",
        "05-dealers|setField|-|args.cash=500;args.bank=0;args.coatCapacity=100|ret.ok=t|state.cash=500;state.bank=0;state.coatCapacity=100",
        "05-dealers|acceptCoatOffer|d:0:1022:4494592428115755|args.offer.price=300|ret.ok=t;ret.pockets=20|state.cash=200;state.bank=0;state.coatCapacity=120",
        "05-dealers|setField|-|args.cash=0;args.bank=100000;args.coatCapacity=100|ret.ok=t|state.cash=0;state.bank=100000;state.coatCapacity=100",
        "05-dealers|acceptCoatOffer||args.offer.price=300|ret.ok=f|state.cash=0;state.bank=100000;state.coatCapacity=100",
        "07-finish-scoring|newGame|-|args.seed=1|ret.seed=1;ret.day=1;ret.numDays=31;ret.cash=2000;ret.debt=5500;ret.bank=0;ret.health=100;ret.coatCapacity=100;ret.guns=0;ret.location=bronx;ret.inventory=;ret.prices.cocaine=29716;ret.prices.crack=2532;ret.prices.ecstasy=31;ret.prices.hashish=890;ret.prices.heroin=7227;ret.prices.opium=553;ret.prices.peyote=343;ret.prices.shrooms=632;ret.prices.smack=3271;ret.prices.speed=123;ret.prices.weed=628;ret.prevPrices=;ret.dead=f;ret.lastDayWarned=f;ret.priceEvents=|state.day=1;state.cash=2000;state.bank=0;state.dead=f",
        "07-finish-scoring|setField|-|args.cash=1000;args.bank=500;args.debt=200|ret.ok=t|state.day=1;state.cash=1000;state.bank=500;state.dead=f",
        "07-finish-scoring|finish|-|args=|ret.score=1300;ret.dead=f;ret.day=1|state.day=1;state.cash=1000;state.bank=500;state.dead=f",
        "07-finish-scoring|setField|-|args.dead=t;args.cash=10;args.bank=0;args.debt=0|ret.ok=t|state.day=1;state.cash=10;state.bank=0;state.dead=t",
        "07-finish-scoring|finish|-|args=|ret.score=10;ret.dead=t;ret.day=1|state.day=1;state.cash=10;state.bank=0;state.dead=t",
        "10-rolls-and-helpers|newGame|-|args.seed=1|ret.seed=1;ret.day=1;ret.numDays=31;ret.cash=2000;ret.debt=5500;ret.bank=0;ret.health=100;ret.coatCapacity=100;ret.guns=0;ret.location=bronx;ret.inventory=;ret.prices.cocaine=29716;ret.prices.crack=2532;ret.prices.ecstasy=31;ret.prices.hashish=890;ret.prices.heroin=7227;ret.prices.opium=553;ret.prices.peyote=343;ret.prices.shrooms=632;ret.prices.smack=3271;ret.prices.speed=123;ret.prices.weed=628;ret.prevPrices=;ret.dead=f;ret.lastDayWarned=f;ret.priceEvents=|state.cash=2000;state.health=100;state.dead=f",
        "10-rolls-and-helpers|setField|-|args.cash=10000|ret.ok=t|state.cash=10000;state.health=100;state.dead=f",
        "10-rolls-and-helpers|rollCoatDealerOffer|0|args=|ret.price=201;ret.offered=t|state.cash=10000;state.health=100;state.dead=f",
        "10-rolls-and-helpers|rollCoatDealerOffer|d:0:1022:4503590620171241|args=|ret.price=350;ret.offered=t|state.cash=10000;state.health=100;state.dead=f",
        "10-rolls-and-helpers|setField|-|args.cash=201|ret.ok=t|state.cash=201;state.health=100;state.dead=f",
        "10-rolls-and-helpers|rollCoatDealerOffer|0|args=|ret.price=201;ret.offered=f|state.cash=201;state.health=100;state.dead=f",
        "10-rolls-and-helpers|setField|-|args.cash=202|ret.ok=t|state.cash=202;state.health=100;state.dead=f",
        "10-rolls-and-helpers|rollCoatDealerOffer|0|args=|ret.price=201;ret.offered=t|state.cash=202;state.health=100;state.dead=f",
        "10-rolls-and-helpers|setField|-|args.health=100;args.dead=f|ret.ok=t|state.cash=202;state.health=100;state.dead=f",
        "10-rolls-and-helpers|applyDamage|-|args.amount=30|ret.value=70|state.cash=202;state.health=70;state.dead=f",
        "10-rolls-and-helpers|applyDamage|-|args.amount=1000|ret.value=0|state.cash=202;state.health=0;state.dead=t",
        "11-finances|newGame|-|args.seed=1|ret.seed=1;ret.day=1;ret.numDays=31;ret.cash=2000;ret.debt=5500;ret.bank=0;ret.health=100;ret.coatCapacity=100;ret.guns=0;ret.location=bronx;ret.inventory=;ret.prices.cocaine=29716;ret.prices.crack=2532;ret.prices.ecstasy=31;ret.prices.hashish=890;ret.prices.heroin=7227;ret.prices.opium=553;ret.prices.peyote=343;ret.prices.shrooms=632;ret.prices.smack=3271;ret.prices.speed=123;ret.prices.weed=628;ret.prevPrices=;ret.dead=f;ret.lastDayWarned=f;ret.priceEvents=|state.cash=2000;state.bank=0",
        "11-finances|setField|-|args.cash=2000;args.bank=0|ret.ok=t|state.cash=2000;state.bank=0",
        "11-finances|finances|-|args.action=deposit;args.amount=500|ret.ok=t;ret.amount=500|state.cash=1500;state.bank=500",
        "11-finances|finances|-|args.action=deposit;args.amount=99999|ret.ok=t;ret.amount=1500|state.cash=0;state.bank=2000",
        "11-finances|finances|-|args.action=withdraw;args.amount=200|ret.ok=t;ret.amount=200|state.cash=200;state.bank=1800",
        "11-finances|finances|-|args.action=withdraw;args.amount=99999|ret.ok=t;ret.amount=1800|state.cash=2000;state.bank=0",
        "11-finances|setField|-|args.cash=100;args.bank=0|ret.ok=t|state.cash=100;state.bank=0",
        "11-finances|finances|-|args.action=deposit;args.amount=d:0:1026:1519964874237542|ret.ok=t;ret.amount=10|state.cash=90;state.bank=10",
        "11-finances|finances|-|args.action=deposit;args.amount=-50|ret.ok=t;ret.amount=0|state.cash=90;state.bank=10",
        "11-finances|finances|-|args.action=deposit;args.amount=0|ret.ok=t;ret.amount=0|state.cash=90;state.bank=10",
        "11-finances|finances|-|args.action=bogus;args.amount=100|ret.ok=f;ret.reason=Unknown finances action.|state.cash=90;state.bank=10",
    ]
