# Gameplay mechanics — Ben Webb's `dopewars` (GitHub)

Source: [github.com/benmwebb/dopewars](https://github.com/benmwebb/dopewars), cloned at commit `d8bb8ee7bc5e260d80311e1a7630145bc74b5b6d` (2026-01-14), latest tagged release `v1.6.2`. All line references below are `src/<file>:<line>` at that commit.

## This is one derivative among many

`dopewars` traces its lineage through John E. Dell's 1980s "Drug Wars" and its MS-DOS "Dopewars" rewrite. The upstream FAQ (`docs/dopewars_sourceforge_faq.md`) lists a long line of independent, non-interoperable reimplementations — Beermat's Windows game, Dopewars 2000, WinDealer, Chronic 2005, DrugWarz, the MacOS/PalmOS/PocketPC/Blackberry/Psion ports, Dope Mart, Java Dope Wars, eDrugTrader, and more. **This document covers only the mechanics implemented in the `benmwebb/dopewars` C source above.** It does not describe, and should not be read as describing, any other member of that family.

In particular, **Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999)** — the version Lance is most familiar with — is a separate, closed-source codebase. Its numbers (prices, odds, starting cash, interest rates, etc.) are not derivable from this repository and may differ from everything below; nothing here should be taken as a claim about how Beermat's game behaves. Any comparison to Beermat needs its own sourcing.

This is also the reference implementation behind the Keymash online version at <https://keymash.com/games/dopewars/> being played in a separate session (see `docs/playthrough.md`) — useful for spotting where the web port matches vs. diverges from the C server's rules.

## Game setup

- Default game length: **31 turns** (`NumTurns = 31`, `src/dopewars.c:226`), configurable via `NumTurns=` in the config file (`docs/dopewars_sourceforge_faq.md` confirms this is the documented way to lengthen a game) — a public server operator sets it and clients can't override it.
- Starting cash: **$2,000** (`StartCash = 2000`, `src/dopewars.c:114`).
- Starting debt: **$5,500** (`StartDebt = 5500`, `src/dopewars.c:114`).
- Starting health: **100** (`src/dopewars.c:881`).
- Starting coat (inventory) capacity: **100** (`src/dopewars.c:882`).
- Starting "bitches" (hired help) carried: **8** (`src/dopewars.c:879`) — reduces coat space cost per unit carried (see Inventory, below) and provides combat/looting protection (see Combat).
- Player armor: **100**; hired-help armor: **50** (`PlayerArmor = 100, BitchArmor = 50`, `src/dopewars.c:228`).
- All of the above are config-file overridable defaults, not hardcoded limits.

## Locations

Eight boroughs by default, each with a police-presence rating (used to weight cop encounters) and a min/max range for how many distinct drugs are on offer there (`struct LOCATION DefaultLocation[]`, `src/dopewars.c:738-748`; `NUMDRUG` = 12 default drugs):

| Location | Police presence | Min drugs offered | Max drugs offered |
| --- | --- | --- | --- |
| Bronx | 10 | 7 | 12 |
| Ghetto | 5 | 8 | 12 |
| Central Park | 15 | 6 | 12 |
| Manhattan | 90 | 4 | 10 |
| Coney Island | 20 | 6 | 12 |
| Brooklyn | 70 | 4 | 11 |
| Queens | 50 | 6 | 12 |
| Staten Island | 20 | 6 | 12 |

Manhattan and Brooklyn are the high-police-presence locations (90 and 70) with the narrowest drug selection; Ghetto is safest (5) with the widest.

In **antique mode** (`-a`/`--antique`, see below) only the first 6 locations exist — Bronx through Brooklyn (`src/dopewars.c:2474-2479`).

The Loan Shark and Bank are both located at location index 0 (Bronx) by default (`DEFLOANSHARK = DEFBANK = 1`, checked as `IsAt + 1 == Loc`, `src/dopewars.h:216-217`, `src/serverside.c:2351-2367`). The Gun Shop and (Rough Pub for hiring help) are both at location index 1 (Ghetto) by default (`DEFGUNSHOP = DEFROUGHPUB = 2`, `src/dopewars.h:218-219`) — but neither exists in antique mode (`src/dopewars.c:2449-2450`).

## Drugs

Twelve drugs by default, each with a price range, and flags for whether it can go especially cheap and/or especially expensive (`struct DRUG DefaultDrug[]`, `src/dopewars.c:714-734`):

| Drug | Min price | Max price | Can go cheap | Can go expensive |
| --- | --- | --- | --- | --- |
| Acid | $1,000 | $4,400 | yes | no |
| Cocaine | $15,000 | $29,000 | no | yes |
| Hashish | $480 | $1,280 | yes | no |
| Heroin | $5,500 | $13,000 | no | yes |
| Ludes | $11 | $60 | yes | no |
| MDA | $1,500 | $4,400 | no | no |
| Opium | $540 | $1,250 | no | yes |
| PCP | $1,000 | $2,500 | no | no |
| Peyote | $220 | $700 | no | no |
| Shrooms | $630 | $1,300 | no | no |
| Speed | $90 | $250 | no | yes |
| Weed | $315 | $890 | yes | no |

Each "cheap" drug has its own flavor-text message shown when it triggers (e.g. Weed: "Colombian freighter dusted the Coast Guard! Weed prices have bottomed out!", `src/dopewars.c:731-733`); "expensive" events share one of two generic drug-bust/high-demand messages (`struct DRUGS DefaultDrugs`, `src/dopewars.c:751-756`).

## Turn structure and travel

Arriving at a location advances several things at once — travel is the only clock advance (`C_REQUESTJET` handler, `src/serverside.c:433-477`):

1. The player's turn counter increments and the in-game date advances by one day.
2. **Debt interest accrues at 10% per turn** on the current debt (`DebtInterest = 10`, `src/dopewars.c:108`; applied as `Debt *= 1.10`, `src/serverside.c:464`).
3. **Bank interest accrues at 5% per turn** on the current bank balance (`BankInterest = 5`, `src/dopewars.c:108`; `src/serverside.c:466`).
4. New drug prices are generated for the new location, and any special events (busts, random offers, cop attacks) for that arrival are rolled.

Travel is blocked while the player is dead, mid-fight, or once `Turn >= NumTurns` (which ends the game instead of moving, `src/serverside.c:452-456`).

## Pricing

Prices are regenerated fresh every time the player arrives somewhere (`GenerateDrugsHere`, `src/serverside.c:3205-3252`):

1. Roll for how many drugs get a special event this stop: 70% chance of at least 1, then (if 1) a 40% chance of a 2nd, then (if 2) a 5% chance of a 3rd (`src/serverside.c:3214-3219`).
2. For each such event slot, pick a random drug. If it's flagged `Expensive` (and either isn't also `Cheap`, or wins a 50/50), price it **expensive**: `random(min,max) × ExpensiveMultiply` (default multiplier **4**, `src/dopewars.c:755`). Otherwise, if it's flagged `Cheap`, price it **cheap**: `random(min,max) ÷ CheapDivide` (default divisor **4**, `src/dopewars.c:755`).
3. Fill the remaining drug slots for this location — a count randomly chosen within that location's min/max drug range — with ordinary `random(min,max)` prices. Drugs not selected at all simply aren't on offer here today.

So a "cheap" event drops a drug to roughly 1/4 its normal randomized price, and an "expensive" event raises it to roughly 4× — both are relative to the drug's own baseline min/max range, not a fixed discount.

## Random events

On arrival (state `E_OFFOBJECT`, before the drug listing), a chain of checks fires, first-match-wins-ish (`src/serverside.c:2245-2426`, `SendCopOffer`/`RandomOffer`/`OfferObject`):

- Pending tip-offs against the player force an immediate cop encounter.
- Spies working for the player have a small, growing chance each turn of being discovered (base 10% + turns-active, `src/serverside.c:2286-2287`); if discovered, the player may lose a bitch, and the outcome (escape/get shot/defect) is randomized among 3 possibilities (`Discover[]`, `NUMDISCOVER = 3`, `src/serverside.c:69-70`, `2289-2296`).
- A general random-encounter roll then happens, weighted up if the player is carrying a lot of cash (net worth `Cash + Bank − Debt`): threshold 100 normally, 115 above $1M, 130 above $3M (`src/serverside.c:2315-2320`); if `random(0, threshold) > 75` a `SendCopOffer` roll fires.
- `SendCopOffer` itself rolls `random(0, 80 + PolicePresence)` (unless forced): **< 33** → offer an object (bitch or gun); **33–49** → `RandomOffer` (see below); **≥ 50** → cops attack outright (`src/serverside.c:2437-2462`). Higher police-presence locations skew this roll toward combat.

`RandomOffer` (`src/serverside.c:3047-3152`) is a flat percentile roll:

| Roll (0-99) | Outcome |
| --- | --- |
| < 10 | Mugged in the subway — lose 5-20% of cash (`Cash × random(80,95)/100`) |
| 10-29 | "Meet a friend" — gain or trade away 3-7 units of a random drug (coat-space permitting) |
| 30-49 | Police-dog chase (lose 3-7 units of a carried drug) or find 3-7 units of a random drug on "a dead dude" |
| 50-59 | "Mama's brownies" — lose 2-6 units of Weed or Hashish (whichever you're carrying more of) |
| 60-64 | Offered free-looking weed; accepting it is an instant-death event (see Health and death) |
| ≥ 65 | Minor flavor "stopped to..." event costing $1-10, if the server config defines any such messages |

`OfferObject` (`src/serverside.c:3159-3194`) offers, 50/50 (or forced): hiring a bitch (normal mode: price `random($50,000, $150,000) / 10`, i.e. $5,000-$15,000; antique mode: a "bigger trenchcoat" for a flat `random($200, $300)`) — or, the other half of the time, a random gun at 1/10 its shop price, if the player isn't already over-armed relative to their bitch count.

## Inventory ("coat space")

Every drug unit and every carried gun consumes coat space; guns cost `Gun.Space` each (default **4** for all four stock guns, `src/dopewars.c:706-712`) and drugs cost 1 unit each. Base capacity is 100; hiring a bitch adds +10 capacity and reduces looting exposure (see Combat) rather than directly expanding coat space beyond that flat bonus (`GainBitch`, `src/serverside.c:3545-3548`).

## Finances

- **Bank**: deposit/withdraw only while at the bank location and mid-`E_BANK` event; deposits/withdrawals can't take cash or the bank balance negative (`C_DEPOSIT` handler, `src/serverside.c:491-499`). Balance accrues 5%/turn regardless of location once opened (see Turn structure).
- **Loan Shark**: pay down debt only while at the loan-shark location and mid-`E_LOANSHARK` event; can't overpay past $0 debt or past available cash (`C_PAYLOAN` handler, `src/serverside.c:500-508`). Debt accrues 10%/turn everywhere (see Turn structure) — there's no way to stop it compounding except paying it off or ending the game.
- Net worth used for scoring and for weighting event odds is always `Cash + Bank − Debt` (e.g. `src/serverside.c:2259`, `2149`).

## Police and combat

Stock guns (`struct GUN DefaultGun[]`, `src/dopewars.c:706-712`):

| Gun | Price | Coat space | Damage |
| --- | --- | --- | --- |
| Baretta | $3,000 | 4 | 5 |
| .38 Special | $3,500 | 4 | 9 |
| Ruger | $2,900 | 4 | 4 |
| Saturday Night Special | $3,100 | 4 | 7 |

Three stock cop tiers, escalating as the player kills off lower ones (`struct COP DefaultCop[]`, `src/dopewars.c:693-704`; fields are Armor / DeputyArmor / AttackPenalty / DefendPenalty / MinDeputies / MaxDeputies / GunIndex / CopGun-per-deputy-multiplier / DeputyGun-per-deputy-multiplier):

| Cop | Armor | Deputy armor | Attack penalty | Defend penalty | Deputies | Gun used |
| --- | --- | --- | --- | --- | --- | --- |
| Officer Hardass | 4 | 3 | 30 | 30 | 2-8 | Baretta |
| Officer Bob | 15 | 4 | 30 | 20 | 4-10 | Baretta |
| Agent Smith | 50 | 6 | 20 | 20 | 6-18 | .38 Special |

**Not beermat-verified**: real beermat 1.2.0.0 play (TASK-009) observed Officer
Hardass deputy counts of 2, 2, 4, 6, 10, and 11 across days 2-20 (no cops were
ever killed, so no tier escalation was observed) — a wider range than this
table's 2-8, and with no day correlation. `index.html`'s `startChase` uses a
flat `randInt(2, 11)` beermat-verified range rather than this C-source table's
narrower bounds.

Whether cops attack at all in a given random-encounter roll depends on the location's police-presence rating (see Random events, above).

**Combat math** (`GetFightRatings`, `src/serverside.c:2616-2637`; `Fire`, `src/serverside.c:2845-2894`):

- Attack rating starts at **80**, +`Gun.Damage` for every gun the attacker carries; a cop attacker is further penalized by `AttackPenalty`.
- Defend rating starts at **100**, −5 per bitch the defender carries (more hired help = a worse defend roll, i.e. bitches soak hits rather than improve odds directly); a cop defender is further penalized by `DefendPenalty`.
- Both ratings floor at 10.
- A shot lands if `random(0, AttackRating) > random(0, DefendRating)`.
- On a hit, raw damage sums `random(0, Gun.Damage)` for every gun carried, then scales by `100 / Armor` (armor 100 → no reduction; higher armor → less damage taken; damage floors at 1 if it would round to 0).
- **Running from a fight**: 60% base escape chance, halved (to 30%) if the player is the aggressor (`src/serverside.c:2689-2732`). A failed cop-chase run has a further 30% chance of demoting the pursuing cop tier by one.
- **Losing a bitch** (`LoseBitch`, `src/serverside.c:3556-3630`): triggered when a hit would otherwise kill the player but bitches are carried — health resets to 100 instead of dying, one bitch is removed, and there's a chance (scaled by guns-carried vs. bitches-carried) of losing a gun plus a portion of every carried drug, proportional to `1/(bitches+2)`.
- **Death**: health hits 0 with zero bitches carried → game over, and the killer loots the player's cash, bank-minus-debt bounty, guns, and drugs (`HandleDamage`, `src/serverside.c:2565-2614`).
- **After a fight ends** without death, there's a `100 − PolicePresence`% chance of a doctor offer to heal to full health for `random($50,000,$150,000) × Health / 500` (i.e. scaled both by the going bitch-price range and by how much health is missing) (`src/serverside.c:3019-3033`).

## Health and death

- Health starts at 100 and never exceeds it except via the doctor (see above).
- Accepting the "free weed" random event (roll 60-64 in `RandomOffer`) is an unconditional instant-death event regardless of current health ("You hallucinated for three days... then you died because your brain disintegrated!", `src/serverside.c:3133-3140`, `3384-3388`).
- Scoring on any game-ending event uses `Cash + Bank − Debt`, and a death is recorded separately as `Dead` in the high-score table (`src/serverside.c:2148-2149`).

## Antique mode

`-a` / `--antique` at launch (`src/dopewars.c:2582`, `2619`) reproduces the original MS-DOS ruleset more closely:

- Only 6 locations exist instead of 8 (no Queens, no Staten Island) (`src/dopewars.c:2474-2479`).
- No Gun Shop and no Rough Pub location — guns and hired help are obtainable only through the random `OfferObject` encounter, never bought on demand (`src/dopewars.c:2449-2450`).
- Hired help is framed as buying a bigger trenchcoat rather than hiring a "bitch," and is priced flat at `random($200, $300)` instead of the normal `random($5,000, $15,000)` (`MINTRENCHPRICE`/`MAXTRENCHPRICE`, `src/serverside.c:64`, `3164-3177`).
- High scores are tracked in a separate antique leaderboard table (`src/serverside.c:2144-2147`).

## Configurable settings relevant to comparison

Everything above marked as a default (`NumTurns`, `StartCash`, `StartDebt`, `DebtInterest`, `BankInterest`, `PlayerArmor`, `BitchArmor`, the drug/location/gun tables, etc.) is overridable via the dopewars config file — a public server operator picks these, and a client connecting to that server plays by its values, not the compiled-in defaults (`src/configfile.c`; see `dopewars.sourceforge.io/docs/configfile.html`, referenced from the FAQ). Single-player/local games use the compiled-in defaults documented here unless the local config file overrides them.
