# Beermat DopeWars.exe reverse-engineering findings

Rules recovered from the decompile of Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999), `vendor/dopewars-1999/DopeWars.exe` (PE32, Delphi 4, image base `0x400000`). Every address below is a virtual address in that image. Regenerate the evidence with `task re:decompile` (writes one C file per function plus `index.tsv` to the gitignored `vendor/dopewars-1999/re/decompiled/`, named `<va>_<name>.c`) and `task re:disasm -- <va>[,<va>...]` for raw x87 disassembly. This document supersedes `docs/gameplay.md` and `docs/mechanics-notes.md` wherever they conflict with it, because it is read from the shipped binary rather than from a different implementation or from observation. `docs/gameplay.md` describes `benmwebb/dopewars`, which is a different codebase.

Classifications compare each rule with the prototype engine (`index.html`, `<script id="engine">`) and the Mojo core (`core/src/*.mojo`), which replays the engine seed for seed, so the two always agree and are cited together as "the engine". The values are:

- **match**: same rule and same constants.
- **mismatch**: the engine differs from Beermat. Each mismatch has an ID (`M-01`...) that a follow-up subtask will carry.
- **intentional**: a deliberate difference recorded in `docs/parity-deltas.md`.

## How to read the decompile

- Delphi uses the register calling convention: `EAX` is `Self`, `EDX` and `ECX` are the next two arguments, the rest go on the stack. Ghidra names these `param_1`, `param_2`, ...
- `FUN_00402acc(n)` (`0x00402acc`) is `System.Random(n)`: `seed = seed * 0x08088405 + 1; return (n * seed) >> 32`, so it returns a uniform integer in `[0, n)`. `FUN_004028e8` (`0x004028e8`) is `Randomize`: the seed becomes milliseconds since midnight from `GetSystemTime`. It runs at startup (`0x0045c260`) and again at the start of every post-travel event roll (`0x0045d96c`), so Beermat's randomness is wall-clock seeded and not reproducible.
- `FUN_00402944` (`0x00402944`) is `Round`: x87 `FISTP`, which rounds to nearest, ties to even.
- `FUN_0045f23c` (`0x0045f23c`) is the sound player. It does nothing unless the `AllowSound` flag is set. Its second argument is the sound event name (see "Sounds").
- Game state lives in globals. The Pascal pointer cells in `.data` (for example `PTR_DAT_0046cccc`) point at these:

| Global | Meaning | Evidence |
| --- | --- | --- |
| `0x0046d8f0` | cash | new game `0x0045ceb8` sets `2000` |
| `0x0046d8f4` | guns | new game sets `0`; chase win text "You find a gun" increments it; `PTR_DAT_0046cccc` points here |
| `0x0046d8f8` | health | new game sets `100`; `PTR_DAT_0046cc48` points here |
| `0x0046d8fc` | bank | new game sets `0`; compounds at `x1.05` |
| `0x0046d900` | debt | new game sets `0x157c` (5500); compounds at `x1.10` |
| `0x0046d904` | day, 1-based | new game sets `1`; the game ends at `0x1f` (31) |
| `0x0046d908` | coat capacity | new game sets `100` |
| `0x0046d90c` | coat used (sum of drug units) | recomputed by `0x0045eb68` |
| `0x0046d914` | deputies chasing | `PTR_DAT_0046cb50` points here |
| `0x0046d91c` | drug records, 12 x 28 bytes | name ptr, min, spread, price, held, avg cost, flags |

## Drug table and price generation

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Drug records | `0x0045c260` (calls `0x0045d09c` 12 times) | see table below | `index.html:641-705` RULES.drugs, same min/max as Beermat; the crash flag is stored as `cheap` and the spike flag as `expensive` | match (M-01, TASK-010.02.01) |
| Price roll | `0x0045d120` | `price = Random(spread + 1) + min`, re-rolled for all 12 drugs on every arrival and at new game | `randInt(min, max)` per listed drug | match, including the numbers (M-01) |
| Availability | `0x0045d120` | each drug is independently absent with probability 1/8 (`Random(8) == 0` clears the available flag), at every location | `randInt(0, 7) == 0` per drug, drawn right after the price roll, at every location; `RULES.absentOdds` is 8 and locations carry no drug count, so 0 to 12 drugs can be traded | match (M-03, TASK-010.02.03) |
| Price spike | `0x0045d120` | only for drugs with the spike flag, only if available: `Random(20) == 0` then `price *= 5`; the message is `Random(2)` between "Cops made a big `<drug>` bust!  Prices are outrageous!" and "Addicts are buying `<drug>` at outrageous prices!" | for each available spike-flagged drug, in drug-index order: `randInt(0, 19) == 0` multiplies the price by 5 and a following `randInt(0, 1)` picks the bust text (0) or the "Addicts are buying ..." text (1); events are `bust` and `expensive` | match (M-02, TASK-010.02.02) |
| Price crash | `0x0045d120` | only for drugs with the crash flag, only if available: `Random(20) == 0` then `price = price div 10`; a fixed message per drug (acid, hashish, ecstasy, weed) | for each available crash-flagged drug: `randInt(0, 19) == 0` divides the price by 10 (integer division) with the fixed per-drug message below; the event is `cheap` | match (M-02, TASK-010.02.02) |
| Selling an absent drug | `0x0045e884` | refused: "There is no `<drug>` on the market here?" | refused when the price is unset | match |
| Buying | `0x0045e448` | quantity at most `cash div price`; zero means "Duh ! Check the price of `<drug>` out, dude!"; pockets full means "Erm, your pockets are full, dude."; the dialog default is `min(free space, affordable)` | same floor division and "Duh! Check the price" text | match |
| Average cost | `0x0045e448` | `(qty * price + held * avg) div (held + qty)`, integer division | float average, no truncation | **mismatch M-12** (display only) |

The crash messages, indexed by the drug-record position at `0x0045d120` (acid 0, hashish 2, ecstasy 4, weed 11); the other drugs have no crash flag:

| Drug | Crash message |
| --- | --- |
| Acid | "The market has been flooded with cheap home-made acid!" |
| Hashish | "The Marrakesh Express has arrived!" |
| Ecstasy | "Rival dealers raided a pharmacy and are selling cheap ecstasy!" |
| Weed | "Columbian freighter dusted the Coast Guard!  Weed prices have bottomed out!" |

Per drug the engine draws, in engine (alphabetical) drug order and matching the Beermat order within a drug: the price, the availability roll, the spike roll if spike-flagged (plus the bust-or-addicts pick only when the spike hits an available drug), then the crash roll if crash-flagged. The spike and crash rolls are drawn even for an absent drug and simply have no effect, exactly as in `0x0045d120`.

Drug records as built at `0x0045c260`. `min` and `spread` are the fifth and sixth `0x0045d09c` arguments (`price = Random(spread + 1) + min`, so the maximum is `min + spread`). The crash and spike columns are the byte flags at record offsets `+0x19` and `+0x18`. The engine keeps its own alphabetical drug order (acid, cocaine, crack, ecstasy, ...) rather than the Beermat index order, so RNG draws per drug follow the engine order.

| Index | Drug | Beermat min | Beermat max | Crash (div 10) | Spike (x5) | Engine min-max | Engine flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | Acid | 1000 | 4500 | yes | no | 1000-4500 | cheap (crash) |
| 1 | Cocaine | 15000 | 30000 | no | yes | 15000-30000 | expensive (spike) |
| 2 | Hashish | 450 | 1350 | yes | no | 450-1350 | cheap (crash) |
| 3 | Heroin | 5000 | 14000 | no | yes | 5000-14000 | expensive (spike) |
| 4 | Ecstasy | 10 | 60 | yes | no | 10-60 | cheap (crash) |
| 5 | Smack | 1500 | 4500 | no | no | 1500-4500 | none |
| 6 | Opium | 500 | 1300 | no | yes | 500-1300 | expensive (spike) |
| 7 | Crack | 1000 | 3500 | no | no | 1000-3500 | none |
| 8 | Peyote | 200 | 700 | no | no | 200-700 | none |
| 9 | Shrooms | 600 | 1350 | no | no | 600-1350 | none |
| 10 | Speed | 70 | 250 | no | yes | 70-250 | expensive (spike) |
| 11 | Weed | 300 | 900 | yes | no | 300-900 | cheap (crash) |

Names are the strings at `0x0045c518`-`0x0045c5c8`.

## Travel, chase start and the day loop

`0x0045d428` is the common handler behind all six location buttons (`0x0045ef04`-`0x0045efcc`, argument 1-6) and the Finish button (`0x00460c10`, argument 7). Order of operations on a travel:

1. If the day is already 31: record the high score (`0x004609fc`) and offer "Play Again". Otherwise `day += 1`.
2. If the day just became 31: play `DWLastDay` and show "This is your last day, man." (with " Maybe you should offload your stash." when coat used is above zero); the location buttons are disabled and Finish is enabled.
3. `Random(6) == 0`: start a chase (`0x0045d6e4`). Otherwise run the arrival events and dealers (`0x0045d96c`). The two are exclusive.
4. Roll new prices (`0x0045d120`).
5. Bank interest (`0x0045e3a4`), then debt interest (`0x0045e3d4`).
6. At the top of the handler, before the day increment, `day == 5` enables the New Game button and the File > New menu item (both are disabled at new game, `0x0045ceb8`), so a restart is only possible from day 6. The Finance button is enabled from day 1. Confirmed on the oracle, see "Oracle checks".

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Game length | `0x0045d428`, `0x0045ceb8` | 31 days, day counter starts at 1 | `numDays: 31`, day starts at 1 | match |
| Start state | `0x0045ceb8` | cash 2000, debt 5500, bank 0, guns 0, health 100, coat 100 | same (`startCash`, `startDebt`, `startHealth`, `startCoatCapacity`) | match |
| Chase start chance | `0x0045d428` | `Random(6) == 0`, 1 in 6, the same at every location, and a chase suppresses the arrival events and dealers | `randInt(0, 5) === 0`, 1 in 6 at every location; the arrival sequence rolls the arrival event and dealers only when no chase started | match |
| New Game gate | `0x0045d428`, `0x0045ceb8` | New Game button and menu item disabled from new game until the first travel made on day 5, so usable from day 6 | New Game is available at any time | **mismatch M-11** |
| Last-day message and sound | `0x0045d428` | on arrival at day 31 | message text matches (`index.html:1163`); no sound | match for the text, sound in "Sounds" |

## Arrival events and dealers

`0x0045d96c` runs after every non-chase travel, in two independent stages, so one arrival can show a dealer and then an event.

| Stage | Beermat | Engine | Class |
| --- | --- | --- | --- |
| Dealer visit chance | `Random(14) == 0`, then `Random(4)`: 0 or 2 coat dealer, 1 or 3 gun dealer. One combined 1/14 chance, coat and gun equally likely | two independent 15% draws, coat and gun | **mismatch M-05** |
| Coat dealer | price `Random(150) + 201` (201-350), adds `Random(10) + 11` pockets (11-20); offered only if `price < cash`; paid from cash only. Prompt "Would you like to buy a trenchcoat with more pockets for $X?" | pockets 10-30, price 200-500, may be paid from the bank with a 25% fee | **mismatch M-05** |
| Gun dealer | price `Random(250) + 301` (301-550); offered only if `price < cash`; gun name drawn from Baretta, .38 Special, Ruger, Saturday Night Special (cosmetic); accepting adds one gun, uses no coat space; paid from cash only | price 250-600, a gun takes 4 coat space, may be paid from the bank with a 25% fee | **mismatch M-05** |
| Event chance | if `cash + bank >= 99,999,999` the event always fires and is forced to the mugging outcome; otherwise `Random(14) == 0` | one percentile roll over the whole arrival, event table below | **mismatch M-06** |
| Outcome 0 (1 in 4) | "You find N units of `<drug>` on a dead dude in the `<location>`"; drug is a random available one, `N = min(Random(7) + 2, free coat space)`; skipped when the coat is full. The average cost is diluted: `avg = held * avg div (held + N)` | "You found N units on a dead dude in the subway", 3-7 units, requires a roll in the 30-50% band | **mismatch M-06** |
| Outcome 1 (1 in 4) | plays `DWMugged`, "You were mugged on the `<location>`", cash `-= cash div (Random(2) + 3)` (one third or one quarter) | 10% band, keeps 80-95% of cash; if cash is zero, loses 5% health | **mismatch M-06** |
| Outcome 2 (1 in 4) | "You meet a friend! He lays some `<drug>` on you!", same quantity and dilution rules as outcome 0 | 20% band, 3-7 units | **mismatch M-06** |
| Outcome 3 (1 in 4) | plays `DWPoliceDog`, "Police dogs chased you for `Random(4) + 2` blocks." If coat used > 0, a random held drug is chosen; with probability 1/2 the player drops `min(Random(held) + 1, 10)` units and the text adds "You dropped some drugs! That's a drag, man!" | drop 3-7 units of a random held drug with 50% chance inside a 20% band | **mismatch M-06** |
| No Beermat equivalent | none | "Mama's brownies" (weed/hashish loss), "hallucinated for three days" death, "stopped to get a bite to eat" | **mismatch M-06** (engine-only events) |

## Chase

`0x0045d6e4` starts it: `deputies = Random(10) + 2` (2-11), shows "Officer Hardass and N of his deputies are chasing you !" (`0x0045d818`). `TCopChaseDlg.FormShow` (`0x0045a7d0`) plays `DWCopChase` and enables the Fight button only when the player owns a gun. There is a single cop tier (Officer Hardass); the deputy count is not scaled by day or location. Dying (health 0) ends the game: "They wasted you, man! What a drag!", plays `DWDead`, records the score.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Deputy count | `0x0045d6e4` | `Random(10) + 2`, 2-11 | `randInt(2, 11)` | match |
| Cop tiers | `0x0045d6e4` | none, a single cop | one cop, "Officer Hardass" | match |
| Run | `0x0045a878` | `Random(6) < 3`: escape ("You lost them in the alleys."), 50% regardless of guns. On failure the cops fire: `Random(2)`, 1 = hit, 0 = miss | 30% when aggressor, 60% otherwise; on failure always take 3-12 damage | **mismatch M-07** |
| Stay | `0x0045a9f8` | the cops fire: `Random(2)`, 1 = hit for 5-15, 0 = miss | the Stay button only shows a message; the cops do not fire (`index.html:1512`) | **mismatch M-07** |
| Cop hit damage | `0x0045a834` | `Random(11) + 5` (5-15), health floored at 0 | run: 3-12; fight: scaled `0-5`, minimum 1 | **mismatch M-07** |
| Player shot | `0x0045ab38` | `Random(2)`: 1 kills one deputy (plays `DWCopHitByGun`), 0 misses (plays `DWYourGunShot`) | attack roll against defend roll from `80 + guns * 5` against 100 | **mismatch M-08** |
| Win condition | `0x0045ab38` | the deputy count is decremented per kill and the chase ends when it goes below 0, so `deputies + 1` kills are needed | ends when the count reaches 0 | **mismatch M-08** |
| Cop return fire in a fight | `0x0045ab38` | only while deputies >= 0 after the shot: `Random(2)`, 1 = hit (5-15) | hit and miss are one roll; the loser takes damage | **mismatch M-08** |
| Win reward | `0x0045ab38` | guns `+= 1`; cash `+= (Random(1000) + 1000) + Random(1500)`, which is 1000-3499; then "Will you pay $X to have a doctor sew you up?" where X is the first term (1000-1999): yes sets health to 100 and deducts X | none | **mismatch M-09** |

## Money

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Debt interest | `0x0045e3d4` | once per day advance, only when debt > 0: `debt = Round(debt * 1.1)` with the extended-precision constant at `0x0045e3f8` (`1.1`), ties to even | `Math.round(debt * 1.1)` (ties away from zero in the positive direction) | **mismatch M-10** (ties only) |
| Bank interest | `0x0045e3a4` | once per day advance, only when bank > 0: `bank = Round(bank * 1.05)`, constant at `0x0045e3c8` (`1.05`), integer result | `bank * 1.05`, fractional dollars kept | **mismatch M-10** |
| Deposit / withdraw | `0x0045a17c`, `0x0045a214` | any amount up to cash / up to bank | same | match |
| Pay loan | `0x0045a2ac` | default and maximum `min(cash, debt)` | `min(amount, cash, debt)` | match |

## Score and high scores

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Final score | `0x004609fc` | `cash + bank - debt`, also computed on death | `cash + bank - debt` | match |
| Score recorded | `0x004609fc` | only if the score is above 0; otherwise "was not good enough to get on your highest score list" | every score is offered for the list | **mismatch M-13** |
| List size | `0x004609fc` | 10 entries, a new score ranks above existing entries it strictly beats | 10 entries | match |
| Storage | `0x0045cd70`, `0x0045cc28` | registry `Software\Beermat Software\DopeWars\Scores\Score<n>`, value encrypted by `0x004604b0` | `localStorage` / `user://` | intentional, `docs/parity-deltas.md` section 3 |

## Sounds

The sound player (`0x0045f23c`) is a no-op unless the global `AllowSound` flag (`0x0046daf4`) is true. The flag is toggled by `TForm1.EnableSndClick` (`0x0046026c`), which also persists it as the registry value `AllowSound`. A sound event name resolves to a wav through `AppEvents\Schemes\Apps\DopeWars\<event>\.current`, which the first-run initialiser (`0x0045f3a8`) populates. The event-to-file table is `vendor/dopewars-1999/re/sounds.tsv` (`task re:extract`).

| Event | File | Trigger (handler VA, condition) |
| --- | --- | --- |
| `DWCashReg` | `cashreg.wav` | `TBuyDlg.OKBtnClick` (`0x0045999c`) and Enter in the quantity box (`0x004598f0`): every confirmed buy and sell |
| `DWLastDay` | `uhoh.wav` | `0x0045d428`, when the day counter becomes 31 |
| `DWCopChase` | `siren.wav` | `TCopChaseDlg.FormShow` (`0x0045a7d0`), each time the chase dialog opens |
| `DWCopGunShot` | `gun.wav` | cops fire and miss: Run (`0x0045a878`), Stay (`0x0045a9f8`), Fight (`0x0045ab38`) |
| `DWYouHitByGun` | `youhit.wav` | cops fire and hit: Run, Stay, Fight |
| `DWYourGunShot` | `gun2.wav` | Fight, the player's shot misses (`0x0045ab38`) |
| `DWCopHitByGun` | `cophit.wav` | Fight, the player's shot kills a deputy (`0x0045ab38`) |
| `DWMugged` | `hrdpunch.wav` | arrival event outcome 1 (`0x0045d96c`) |
| `DWPoliceDog` | `bark.wav` | arrival event outcome 3 (`0x0045d96c`) |
| `DWDead` | `wasted.wav` | `0x0045d6e4`, when the chase dialog returns death |

No sound plays for the dealer offers, finances, price events, travel itself, victory over the cops or the end-of-game screen.

**AllowSound default: on.** The first-run initialiser `0x0045f3a8` runs from `0x0045c260` (called by `FormCreate`, `0x0045e404`) and calls `TForm1.SetRegKeyBool(..., "AllowSound", 1)` when the settings probe `0x004601c8` finds no `Software\Beermat Software\DopeWars\Scores` key. `0x0045c260` then reads the value back into the flag, and `FUN_0043b300` mirrors it onto the check mark of the Sounds menu item (the control at `TForm1+0x338`). The flag's BSS default is 0, so an installation whose registry value is missing or unreadable plays no sound until the item is ticked; a normal first run writes 1. The engine has no sound at all, so this is not a mismatch with the engine but an input to the sound work in TASK-010.

## Intentional differences

Recorded in `docs/parity-deltas.md` section 5. The location model (one city of six named sub-locations, `cities.txt`) and the borough and city names are not fidelity targets. The per-borough police weights and drug counts affected game rules rather than the location model, so they were listed as M-04 and M-03; both are gone.

## Oracle checks

Checked on the live oracle (see `CLAUDE.local.md` for how to reach it; none of that is recorded here):

- **New Game gate (M-11).** The decompile suggested a control pair at `TForm1+0x330` and `TForm1+0x344` is disabled until day 5. On the oracle, Finances is enabled on day 1 and New Game is greyed on days 1-5 and enabled on day 6, so the pair is the File > New item and the New Game button.
- **Debt rounding (M-10).** Debt read 5500, 6050, 6655, 7320, 8052, 8857 on days 1-6. `6655 * 1.1 = 7320.5` shows as 7,320, which is ties-to-even (`Math.round` would give 7,321).
- **Chase dialog (Chase).** With no gun, Fight is greyed and Run and Stay are enabled; "Officer Hardass and 5 of his deputies are chasing you !" and "You lost them in the alleys." match the decoded strings.
- **Police dogs (Arrival events).** "Police dogs chased you for 4 blocks." with an empty coat, no drop clause, matches outcome 3.
- **Prices.** Every price observed on days 1-6 fell inside the decoded ranges (Ecstasy 55, 40, 52; Speed 174, 77, 156; Cocaine 27,133). The samples are too few to separate the decoded ranges from the engine's.

## Mismatch index

| ID | Rule | Section | Subtask |
| --- | --- | --- | --- |
| M-01 | Drug table names, ranges and flags (fixed, match) | Drug table | TASK-010.02.01 |
| M-02 | Price spike and crash events (fixed, match) | Drug table | TASK-010.02.02 |
| M-03 | Drug availability (1/8 absent, location independent; fixed, match) | Drug table | TASK-010.02.03 |
| M-04 | Chase start chance (1 in 6, flat; fixed, match) | Travel | TASK-010.02.04 |
| M-05 | Dealer visits, coat and gun prices, payment | Arrival events | TASK-010.02.05 |
| M-06 | Arrival event table | Arrival events | TASK-010.02.06 |
| M-07 | Run, stay and cop damage | Chase | TASK-010.02.07 |
| M-08 | Fight resolution and win condition | Chase | TASK-010.02.07 |
| M-09 | Chase win reward and doctor | Chase | TASK-010.02.07 |
| M-10 | Interest rounding | Money | TASK-010.02.08 |
| M-11 | New Game locked until day 6 | Travel | TASK-010.02.09 |
| M-12 | Average cost integer division | Drug table | TASK-010.02.10 |
| M-13 | Score must be above 0 to be recorded | Score | TASK-010.02.11 |
