# Beermat Dope Wars 2.1 analysis

What can and cannot be learned from Beermat Software's "Dope Wars for Windows" 2.1.0.0 (2001), `vendor/dopewars-2001/dw21.exe` (gitignored along with the rest of `vendor/dopewars-2001/`). The release history it is compared against is `vendor/CHANGELOG.md`. This document does not replace `docs/beermat-re.md`, which is read from the 1.2.0 binary; it records how far that document carries over to 2.1. Every rule below is read from a dump of the decrypted process, with a virtual address; the resource-only table in the older version of this document has been replaced. `docs/beermat-re.md` is the 1.2 source of truth and still governs the port wherever 2.1 differs.

Classifications compare each rule with the engine (`index.html`, `<script id="engine">`) and the Mojo core (`core/src/*.mojo`), which replay the engine seed for seed and are cited together as "the engine". Values:

- **match**: same rule and same constants.
- **mismatch**: the engine differs from Beermat. Each mismatch has an ID (`N-01`...) that a follow-up subtask will carry.
- **intentional**: a deliberate difference recorded in `docs/parity-deltas.md`.

## How to read the decompile

- Delphi uses the register calling convention: `EAX` is `Self`, `EDX` and `ECX` are the next two arguments, the rest go on the stack. Ghidra names these `param_1`, `param_2`, ...
- `FUN_00402b7c` (`0x00402b7c`) is `System.Random(n)`: `seed = seed * 0x8088405 + 1; return (n * seed) >> 32`, so it returns a uniform integer in `[0, n)`. `FUN_00402958` (`0x00402958`) is `Randomize`: the seed becomes milliseconds since midnight from `GetSystemTime`. It runs at startup (`0x00490508`) and at new game (`0x004b9ac0`). Unlike 1.2 it does not run before each arrival-event roll, so after new game the stream is one wall-clock-seeded LCG sequence and is not reproducible across runs.
- Numeric rules never appear as literals. `K(n)` and `S(n)` in the decompile are the constant decoder (`FUN_004c2c90` on an obfuscated string, see `tools/re/decode_constants.py`); `K(5)` means the value 5. A game number is stored as an obfuscated string and read back through the same decoder, which is why most globals below show as `FUN_004c2c90(param_1, DAT_...)`.
- `FUN_004c2c90(Self, value)` decodes a stored value and `FUN_004c2a88` stores one back; `FUN_004ba97c(Self, a, op, &out, b, bHigh)` is the arithmetic helper with `op` `'+'` (0x2b) or `'-'` (0x2d).
- Game state lives in globals. The Pascal pointer cells in `.data` (for example `PTR_DAT_004d2608`) point at the form object; their fields are at fixed offsets (for example `+0x2d0` is the cop-chase timer and `+0x38` its "busy" flag).

| Global | Meaning | Evidence |
| --- | --- | --- |
| `DAT_004d3044` | RNG seed | written by `Randomize` (`0x00402958`), consumed by `Random` (`0x00402b7c`) |
| `DAT_004e20b8` | cash, new game sets 2000 | `0x004b9ac0`; `AddHighScore` (`0x004c3230`) reads it |
| `DAT_004e20c4` | bank, new game sets 0 | compounds daily at `0x004c0358` |
| `DAT_004e20c8` | total debt, rebuilt daily as the sum of the loan balances | `0x004c0420` |
| `DAT_004e20dc` | health, new game sets 100; 0 ends the game | mugging `0x004bf420`, day-end `0x004bc790` |
| `DAT_004e20e0` | day, 1-based | incremented at `0x004bc9d4`; `LoseDay` (`0x004bdb8c`) also advances it |
| `DAT_004e20e4` | coat capacity, new game sets 100 | `0x004b9ac0`; coat dealer adds 11-20 |
| `DAT_004e20e8` | coat used (sum of drug units) | recomputed after each buy, sell or event |
| `DAT_004e20f0` | day limit (15/30/60/90) | new game sets it |
| `DAT_004e20f8` | kidneys, new game sets 2 | day-end `0x004bc790`, dialysis roll `0x004be728` |
| `DAT_004e2110` | days spent below 80 health (infection counter) | `0x004bc790` |
| `DAT_004e2145` | infection warning shown | `0x004bc790` |
| `DAT_004e2147` | owns a dialysis machine | `0x004befd8` |
| `DAT_004e210c` | loan count | new game sets 1 |
| `DAT_004e211c` | sharks released from jail so far, new game sets 1 | `0x004be728` |
| `DAT_004e212c` / `DAT_004e2130` | tip drug index (1000 means none) set by the Old Lady or after an arrest, copied to `2130` on the next travel and consumed by the price roll | `0x004bc9d4`, `0x004bbfc4` |
| `DAT_004e2118` | hospital price multiplier, `Random(9) + 1`, rolled with the prices | `0x004bbfc4`, `0x004c402c` |
| `DAT_004e2148` | player was arrested in a chase | `0x004bd758` |
| `DAT_004e214c` | travelling by air (new city) flag | text choice at `0x004bf420` |
| `DAT_004e2143` | Old Lady muted | `0x004be728` |
| `DAT_004de45c` | drug records, 13 x 860 bytes | built by `0x004bbc04` from `0x004b7fe0` |
| `DAT_004e1250` | loan shark records, 5 x 0x20 bytes | built by `0x004bbe4c` |
| `DAT_004e11ec` | loan records, 5 x 0x14 bytes | `0x004b9ac0`, `0x004c0420` |

## Drug table and price generation

`0x004b7fe0` builds the game's tables at new game. It calls `FUN_004bbc04` 13 times (drug indices 0-12), `FUN_004bbe4c` 5 times (loan sharks) and `FUN_004bbd34` 6 times (joke weapons). Each drug record is 0xd7 dwords (860 bytes) at `DAT_004de45c + index*0x35c`. The average cost is at +0x18 and the units held at +0x1c. `FUN_004bbc04(Self, index, name, crashMark, spikeMark, spread, min, ...)` stores the name at +0, the plural at +4, the singular at +8, min at +0xc, spread at +0x10, the price at +0x14, the availability byte at +0x28, the spike mark at +0x20 and the crash mark at +0x24. The per-day price history is at +0x28 + day*4 and the per-day event flag (0 none, 1 spike, 2 crash) at +0x1f0 + day*4.

A drug is a spike drug when its spike mark is 10 and a crash drug when its crash mark is 30; 11 means "not flagged". The marks come straight from the builder calls at `0x004b7fe0`:

| Index | Drug | min | spread | max | Crash (div 10) | Spike (x5) | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | Acid | 1000 | 3500 | 4500 | yes | no | matches 1.2 |
| 1 | Cocaine | 15000 | 15000 | 30000 | no | yes | matches 1.2 |
| 2 | Hashish | 450 | 900 | 1350 | yes | no | matches 1.2 |
| 3 | Heroin | 5000 | 9000 | 14000 | no | yes | matches 1.2 |
| 4 | Ecstasy | 10 | 50 | 60 | yes | no | matches 1.2 |
| 5 | MDA | 1500 | 3000 | 4500 | no | yes | replaces Smack; same range; gained the spike flag |
| 6 | Opium | 500 | 800 | 1300 | no | yes | matches 1.2 |
| 7 | Crack | 1000 | 2500 | 3500 | yes | no | gained the crash flag |
| 8 | Peyote | 200 | 500 | 700 | no | no | unflagged, as in 1.2 |
| 9 | Mushrooms | 600 | 750 | 1350 | no | no | replaces Shrooms; unflagged |
| 10 | Speed | 70 | 180 | 250 | no | yes | matches 1.2 |
| 11 | Weed | 300 | 600 | 900 | yes | no | matches 1.2 |
| 12 | Special K | 450 | 1000 | 1450 | no | yes | new in 2.1 |

Names are the strings at `0x004b88f0`-`0x004b8c30`. The five crash drugs are Acid, Hashish, Ecstasy, Crack and Weed; the six spike drugs are Cocaine, Heroin, MDA, Opium, Speed and Special K.

### Price roll (`0x004bbfc4`)

It runs after the day advance, interest and the arrival events (see "Travel"), so the events read the previous day's prices and availability exactly as in 1.2. Draw order:

1. `Random(9) + 1` is stored in `DAT_004e2118` (the hospital multiplier, see "Hospital").
2. For each of the 13 drugs in index order:
   1. Price. On day 1 the price is a fresh roll `min + Random(spread + 1)`. On later days `Random(5) == 0` (1 in 5) keeps yesterday's price when yesterday's event flag for the drug is 0; any other result, or a flagged yesterday, rolls fresh. The 1.2 model rolled fresh every arrival; this is the "flatter" pricing in the 2.0 changelog.
   2. Availability. `Random(8) == 0` (1 in 8, as in 1.2) clears the available byte and the day's event flag, unless the drug is the current tip drug (`DAT_004e2130`), which stays available. Otherwise the drug is available and the flag is 0.
   3. Spike drugs. `Random(40) == 0` (1 in 40; 1.2 was 1 in 20) spikes the drug only if it is available and yesterday's event flag is 0. A tip drug spikes without needing the roll to hit. The price is multiplied by 5 and the flag becomes 1. A hit on Special K shows the fixed news item below and draws nothing more. Any other spike draws `Random(2)`: 0, or the drug being the tip drug, gives the "bust" text, and 1 gives the "Addicts" text. The tip is cleared (`DAT_004e2130 = 1000`) afterwards.
   4. Crash drugs. `Random(40) == 0` under the same availability and flag conditions divides the price by 10 (integer division), sets the flag to 2 and shows the drug's fixed text. The roll is drawn for every crash drug whether or not it can apply.
   5. The day's price and flag are copied into the history arrays.

Peyote and Mushrooms therefore never spike or crash. Spike drugs are drawn `Random(40)` once; crash drugs once; an unflagged drug draws only the price and availability rolls.

Spike news, all via `TDWForm_AddNews`: "Cops made a big `<drug>` bust! Prices are outrageous!" (`0x004bc2cb`), "Addicts are buying `<drug>` at outrageous prices!" (`0x004bc317`) and, for Special K only, "Cops put the local vet out of business! The price of `<drug>` is astronomical!" (`0x004bc247`). This answers the per-drug pairing question: the pairing is not per drug. The bust/Addicts choice is `Random(2)` for every spike drug except Special K, which always shows the vet text.

| Drug | Crash message |
| --- | --- |
| Acid | "The market has been flooded with cheap home-made acid!" |
| Hashish | "The Marrakesh Express has arrived!" |
| Ecstasy | "Rival dealers raided a pharmacy and are selling cheap ecstasy!" |
| Crack | "Criminals have raided police stores and stolen tons of crack!" |
| Weed | "Columbian ship dusted by Coast Guard! Weed prices have bottomed out!" |

## Travel, chase start and the day loop

`0x004bc9d4` is the common handler behind all six location buttons (`0x004c168c`-`0x004c177c`, argument 1-6) and the Finish button (`0x004c35f0`, argument 7). Order of operations on a travel, from the decompile:

1. `ProcessLoanSharks` (`0x004bcfe8`) runs first, before the day advances, for every loan whose days-left counter is 0 or below (see "Loan sharks").
2. `0x004bce30` runs, and the news flag `DAT_004e2124` is cleared.
3. If the day already equals the day limit, `EndGame(5)` ends the game ("You ran out of time for peddling your wares!"). Otherwise `day += 1`.
4. From day 5 on (after the increment) the New Game button is enabled (`TDWForm_EnableNewGameButton`).
5. Day-end health checks (`0x004bc790`, see "Health"). On the day limit `TDWForm_SetLastDay` shows the last-day message.
6. The tip drug is moved: when `DAT_004e212c` is not 1000 it is copied to `DAT_004e2130` and reset.
7. Chase roll: `Random(8) == 0` (1 in 8) draws on every travel, but a chase only starts when `day < limit - 1`. A chase calls `0x004bd758`; if health is 0 afterwards `EndGame(4)`. With no chase, and unless the day equals the limit, `0x004be728` runs the arrival events (see "Arrival events"). The two are exclusive.
8. Bank interest `0x004c0358`, then loan interest `0x004c0420` (see "Interest").
9. Price roll `0x004bbfc4`, then the display refresh `0x004bfbe0` (this draws the day and the cash, bank and debt labels, and shrinks the LCD font past 1,000,000,000; it is not an interest handler) and `0x004c0034`.
10. Every loan with exactly 1 day left shows "`<shark>` will be visiting you tomorrow. Better get some cash from the bank!" (`0x004bcdec`).
11. If any news was queued, `TDWForm_DisplayNews` shows it.

`LoseDay` (`0x004bdb8c`) is the lost-day path used after an arrest: it rolls prices, both interest handlers, `0x004bce30` and the day-end checks, then advances the day.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Game length | `0x004c2a0c`-`0x004c2a44` | 15, 30, 60 or 90 days, chosen at new game; `DAT_004e20f0` holds the limit | `num_days`, default 30, chosen at new game (TASK-013.02.02); the registration gate is an intentional delta, `docs/parity-deltas.md` section 9 | match |
| Start state | `0x004b9ac0` | cash 2000, one starter loan of 5500 from the first shark (10 days, 15%), bank 0, health 100, kidneys 2, coat 100 | `startCash`, `startDebt`, `startHealth`, `startCoatCapacity` | match for the numbers; the starter loan carries a rate and a due date, N-06 |
| Chase start chance | `0x004bc9d4` | `Random(8) == 0`, 1 in 8, only while `day < limit - 1` | `randInt(0, 5) === 0` | mismatch, N-22 |
| New Game gate | `0x004bc9d4` | New Game enabled once the day reaches 5 (after the increment), so usable from day 5 | New Game available any time | intentional, `docs/parity-deltas.md` section 6 |

The chase start chance is a mismatch: 2.1 draws `Random(8)` (1 in 8) where the engine draws `randInt(0, 5)` (1 in 6). The chase is also suppressed on the last two days.

## Arrival events and dealers

`0x004be728` runs after every non-chase travel that is not on the last day. It rolls five independent stages in a fixed order, so one arrival can show several. This replaces 1.2's two-stage "dealer, then event" model, and answers the arrival-event split question: the dealer and the event are no longer both `Random(14)`.

| Stage | Draws | Beermat 2.1 | Engine (1.2 model) | Class |
| --- | --- | --- | --- | --- |
| 1. Shark release | `Random(7)`, then `Random(5)` until an unreleased shark comes up | only while fewer than 5 sharks are released: `Random(7) < 3` (3 in 7) releases one shark chosen uniformly among those still in jail, news "`<shark>` was released from jail today!" | none | new, N-09 |
| 2. Coat dealer | `Random(15)` | `Random(15) == 0` (1 in 15), and only while coat capacity is below `day + 150`; then `0x004bee64` | `Random(14) == 0` then `Random(4)` | mismatch, N-28 |
| 3. Dialysis machine | `Random(3)` | `Random(3) == 0`, only with no machine and 0 or 1 kidneys; then `0x004befd8` | none | new, N-13 |
| 4. Event | `Random(13)`, then outcome draws | `Random(13) == 0` (1 in 13) fires an event | `Random(14) == 0` | mismatch, N-29 |
| 5. Old Lady | `Random(5)` | `Random(5) == 0` (1 in 5), only with no pending tip and not muted | none | new, N-16 |

The gun dealer is gone (see "Super Store"), so the 1.2 `Random(4)` coat-or-gun draw no longer exists. 1.2's wealth cap (`cash + bank > 99,999,999` forces a mugging) is not in `0x004be728`, so it is removed in 2.1.

### Coat dealer (`0x004bee64`)

Price `Random(150) + 201` (201-350, as in 1.2), drawn before the cash check; offered only when `price < cash`. Prompt "Would you like to buy a trenchcoat with more pockets for $`<price>`?" (a Yes/No box). On Yes the pockets are `Random(10) + 11` (11-20, drawn only on acceptance) and the price is paid from cash. Matches 1.2 apart from the trigger.

### Event outcomes

Event draws: `Random(2)`. A 0 gives outcome `Random(2)` (0 or 1). A 1 gives outcome `Random(3) + 2` (2 to 4). Two substitutions then apply: outcome 2 becomes 3 when cash is 0, and outcome 4 becomes 3 when neither Weed (`DAT_004e096c`, held count) nor Hashish (`DAT_004deb30`, held count) is held.

| Outcome | Chance given an event | VA | Behaviour |
| --- | --- | --- | --- |
| 0 find | 1/4 | `0x004bf134` | Skipped when the coat is full, before any draw. Drug `Random(13)` redrawn until available (all 13 drugs, 1.2 used 11), then `N = min(Random(7) + 2, free space)`. "You find N units of `<drug>` on a dead dude in the `<location>`!" (airport variant "... at the airport!"). Average cost diluted as in 1.2. Plays `DWGoodEvent`. |
| 1 friend | 1/4 | `0x004bf680` | Same drug and quantity draws. "You meet a friend! He gives you some `<drug>`". Plays `DWGoodEvent`. |
| 2 mugging | 1/6 | `0x004bf420` | Health loses `Random(10) + 1`, floored at 1. Plays `DWMugged`. "You were mugged on the `<location>`!" (airport variant "You were mugged at the airport!"). Cash `-= cash div (Random(2) + 3)`. |
| 3 police dogs | 1/6 | `0x004bf8b4` | Plays `DWPoliceDog`. With drugs held: drug `Random(12)` redrawn up to 21 times until one is held, then `Random(4) > 1` drops `min(Random(held) + 1, 10)` units. Then `Random(4) + 2` blocks: "Police dogs chased you for N blocks." plus " You dropped some drugs! That's a drag, man!" when units dropped. |
| 4 brownies | 1/6 | `0x004bed68` | "Your mother made some brownies, and used your `<drug>`. They were great!" The drug is Weed (index 11) if Weed is held, otherwise Hashish (index 2); its held count and average cost are zeroed. |

Mugging now costs health, which 1.2's did not, and brownies are an outcome the 1.2 binary did not have. The found and given picks read the availability flags of the previous roll, as in 1.2. The found and given drug loops never end when no drug is available, as in 1.2.

### Event text

| Event | VA | Text |
| --- | --- | --- |
| Loan visit tomorrow | `0x004bcdec` | "`<shark>` will be visiting you tomorrow. Better get some cash from the bank!" |
| Tip (Old Lady) | `0x004beae0` | "I hear there is going to be `<drug plural>` raid tomorrow." |
| Tip (after arrest) | `0x004bd758` | "As you leave the jail, you overhear cops talking about making `<drug>` raid tomorrow." |
| Death: wasted | `0x004ddf20` | "They wasted you man. What a drag!" |
| Death: infection | `0x004ddf24` | "Your infection got the better of you. You're dead. What a drag!" |
| Death: kidney | `0x004ddf28` | "Your kidney problems killed you. You're dead. What a drag!" |
| Death: out of time | `0x004ddf2c` | "You ran out of time for peddling your wares!" |
| Last day | `0x004ddf60` | "This is your last day, man." |

The tip texts are assembled from a prefix and the drug name and are not exact strings in the image; the exact joining words were not decoded (unresolved, cosmetic).

## Chase

`0x004bd758` starts it: `deputies = Random(7) + 2` (2-8, 1.2 was 2-11), shows "Officer Hardass and N of his deputies are chasing you!" and runs the modal `TCopChaseDlg`. There is a single cop tier; the deputy count is not scaled by day or location. The dialog is a real-time timer (`0x004a4c7c`): Run (`0x004a528c`), Stay (`0x004a5308`), Fight (`0x004a5860`) and Dump (`0x004a5748`) each queue an event in `DAT_004d3998` and the timer plays them in order through `0x004a3f30`. Buttons do nothing while the timer is busy.

When the dialog returns anything but death and the arrest flag `DAT_004e2148` is set, `0x004bd758` calls `RemoveDrugs`, `RemoveWeapons` and `LoseDay` (the night in the slammer costs a day with a full price, interest and day-end pass), clears the flag, and with `Random(2) == 0` picks a spike drug (`Random(13)` redrawn until one has the spike mark) as the tip drug, with the jail tip text from "Event text". Death from the chase calls `EndGame(4)`.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Deputy count | `0x004bd758` | `Random(7) + 2`, 2-8 | `randInt(2, 11)` | mismatch, N-23 |
| Run | `0x004a528c` | `Random(10) < 2` (20%) escapes (event 7, "You lost them in the alleys." / "You escaped from them all!"); otherwise `Random(3)`: 0 queues event 1 (cop "fired and missed you!"), 1 or 2 queues event 2 ("shot you!") | `Random(6) < 3` escapes | mismatch, N-24 |
| Cop hit damage | `0x004a5190` | `Random(11) + 5` (5-15), health floored at 0 | same | match |
| Fight | `0x004a5860` | sets the assault flag, counts a weapon use, hits when `Random(100) + 1 <= weapon accuracy` (record field +0x18): event 4 (hit) else event 3 (miss, "You're `<attacking>`. You missed `<n>` ...") | `Random(2)` kill | mismatch, N-25 |
| Return fire | `0x004a4c7c` | after event 3 or 4: if the deputy counter is below 0 the chase is won (event 8), else `Random(2)` queues event 5 or 6 (cops fire back) | `Random(2)` return fire | mismatch, N-25 |
| Stay | `0x004a5308` | no draw. Arrest ("Officer Hardass pats you down and finds your stash! You're under arrest! You get to spend the night in the slammer. Officer Hardass confiscates your drugs", plays `DWJail`, possession arrest counted) when drugs or weapons are held and no fight started; always arrest after a fight ("You're under arrest for assaulting Police Officers! ...", assault arrest counted); otherwise "Officer Hardass pats you down, but finds nothing of interest. He mumbles something about getting you next time, but lets you go." | cops fire, 5-15 damage | mismatch, N-26 |
| Dump drugs | `0x004a5748` | "Are you sure you want to dump all your drugs?"; Yes clears the held count and average cost of all 13 drugs (weapons are kept) | none | new, N-05 |
| Chase win reward | `0x004a4c7c` event 8 | cash: `base = min(cash + bank, 1,000,000) div 10`, reward `base + Random(base) + Random(base)`; "As Officer Hardass beats a hasty retreat, he drops `$X` in cash." | gun and 1000-3499 cash | mismatch, N-27 |

The win reward is cash, not drugs. Fight messages use "You scared Officer Hardass off. He ran away!" when the last deputy goes and "You scared `<n>` away!" for the others, because the joke weapons scare cops off instead of killing them.

How many deputies a hit scares away (`0x004a3f30` case 4, from `0x004a43bf`) is only partly decoded: a weapon accuracy of 100 or less scares one away, and above 100 the count is drawn with `Random(accuracy div 100) + 1`, capped at the deputies left, with a further test against `DAT_004d236c` (the deputy counter) that was not traced. The joke weapon table passed to `FUN_004bbd34` (`0x004b7fe0`) has accuracy-like values up to 450,000. This is listed as unresolved; TASK-013.02.09 needs the Windows reference to fix the exact count.

## Loan sharks

Loan sharks replace 1.2's single debt. The finance dialog (`0x0047d680`) lists the sharks that are released from jail and not currently owed money (`0x0047d720`, `DrawOfferings`) with the columns Name, % Rate, Duration and Amount; the note under the list reads "Note: Your maximum TOTAL debt cannot exceed 1,000,000" (`0x0047d8bc`, `K(1000000)`).

### Shark records (`0x004bbe4c`, built by `0x004b7fe0`)

`FUN_004bbe4c(Self, index, name, amount, bruisers, duration, rate, sex)` stores the record at `DAT_004e1250 + index*0x20`: name +0, sex +4 (`M` or `F`), rate +8, duration +0xc, bruisers +0x10, amount +0x14, a "currently borrowed" byte +0x18 and a "released from jail" byte +0x19. `DrawOfferings` prints +8, +0xc and +0x14 under the Rate, Duration and Amount columns, so the argument mapping is read off the dialog, not inferred.

| Index | Shark | Rate (% per day) | Duration (days) | Amount (multiple of cash + bank) | Bruisers | Sex |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Honest Harry | 15 | 10 | 10x | 1 | M |
| 1 | Sandy Schwing | 10 | 15 | 20x | 1 | F |
| 2 | Tank NoNeck | 20 | 7 | 30x | 2 | M |
| 3 | Bulbous Bertha | 30 | 1 | 50x | 3 | F |
| 4 | Midget Mickey | 25 | 5 | 100x | 4 | M |

The Amount column is a multiplier: the offering text appends an `x` (`0x0047d918`) and the running game lists Bulbous Bertha as "30, 1, 50x" and Midget Mickey as "25, 5, 100x". When a shark is selected (`0x0047ec50`) the borrow box is limited to `multiplier * (cash + bank)` (the two pointer cells `PTR_DAT_004d260c` and `PTR_DAT_004d25d8`, read as cash and bank from how the chase reward uses them), further capped at `1,000,000 - total debt`; with nothing left the box is disabled. On the running game, selecting Bertha with 1,780 cash and 65 in the bank filled the box with 92250, which is 50 x 1,845. Borrowing (`0x0047e558`) needs an amount above 0, adds it to cash and total debt, marks the shark borrowed, appends a loan record (shark, amount, rate, a value copied from `PTR_DAT_004d28f0`, duration) and increments the loan count. 2.2 later limits this to one loan per day (changelog); 2.1 has no such check.

The starter debt is a real loan: new game (`0x004b9ac0`) writes loan 0 as shark 0 (Honest Harry), amount 5500, rate 15, that field 1, duration 10, marks Harry borrowed and released, and sets the released count and loan count to 1.

### Daily interest and early payoff

`0x004c0420` rebuilds `DAT_004e20c8` each day: total debt is reset to 0, then every loan is compounded, `amount = Round(amount * (rate / 100.0) + amount)` (single-precision constant `100.0` at `0x004c055c`, x87 `Round`), added to the total, and its days-left counter is decremented. Compounding is per day at the shark's percentage, so Harry's 5500 becomes 6325 after one day. The rate is not the old fixed 10%. The rate is `15 / 100.0` as a double, so it is a hair below 0.15 and exact ties round down: 22,250 became 25,587 on the running game (22,250 * 1.15 is 25,587.5, which ties-to-even or a plain integer `* 115 / 100` would turn into 25,588). A port has to reproduce `Round(amount * (rate / 100.0) + amount)` in double precision, not integers.

Paying early (days left above 0, `0x0047c3a4`): the loan is projected forward by days-left compoundings, the interest remaining is the projection minus today's balance, and the payoff is `balance + Round(remaining * 30 / 100.0)`, so the player pays 30% of the remaining interest. The running game showed "You owe: $11,103" for a 6,325 balance with 9 days left at 15%, which this formula reproduces exactly. The dialog says "Because you are paying early, `<shark>` is adding 30% of the interest remaining."

### Visits (`0x004bcfe8`, `0x0047c3a4`)

Before the day advances, every loan with days left of 0 or below opens the shark dialog. Warning level is `|days left| + bruisers - 1`, clamped at 0. Text and sound by level:

| Level | Sound | Dialog |
| --- | --- | --- |
| 0 or 1 | `DWSharkWantMoney` | "Your loan is due today." / "was due yesterday" / "N days past due"; "You owe `$X` to `<shark>`. Pay now, or suffer the consequences." |
| 2 | `DWSharkFirstWarning` | same, with the warning sound |
| 3 | `DWSharkSecondWarning` | same, "`<shark>` says that you had better pay your loan, like you agreed, or it could spell trouble for you." |
| 4 and up | beating | Pay Now and Pay Later are disabled |

At level 4 and up the dialog applies the beating in `FormShow`: damage `Random(16) + 15` (15-30), capped at the player's health, subtracted from health. The text is picked by `Random(3) + 1`, or message 1 with no draw when the damage equals the remaining health: 1 "As a little lesson, `<shark>` and `<HIS|HER>` boys tossed you through the nearest window." (`DWSharkWindow`), 2 "To serve as a reminder, `<shark>` and `<HIS|HER>` boys threw you down a flight of stairs." (`DWSharkStairs`), 3 "Your memory seems to be lacking. To help you remember, `<shark>` and `<HIS|HER>` boys introduce you to their favourite chainsaw." (`DWSharkChainsaw`). The pronoun follows the shark's sex. Paying now needs cash of at least the balance ("You do not have enough cash to pay off this loan!" otherwise). Paying removes the balance from cash and debt and removes the loan; refusing leaves it, and if health is 0 after the visit the game ends with `EndGame(3, shark)`.

### Jail release order

The sharks start in jail except Harry. Each travel, `0x004be728` rolls `Random(7) < 3` while fewer than 5 sharks are released; on a hit it draws `Random(5)` repeatedly until it lands on a shark whose released byte is 0, sets it, increments `DAT_004e211c` and queues "`<shark>` was released from jail today!". That is the "released from jail in random order" line of the 2.1 changelog: a uniform random pick among the sharks still in jail, no fixed order, at 3 chances in 7 per day. Players are never jailed by sharks; the arrest in a chase (`DWJail`) is a different mechanism (see "Chase").

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Single debt at 10% | 1.2 `0x0045e3d4` | replaced by up to 5 loans, daily compounding at 10-30% per shark | none | changed, N-06 |
| Shark table | `0x004b7fe0` | rates 15/10/20/30/25, durations 10/15/7/1/5, multipliers 10/20/30/50/100x | none | new, N-06 |
| Max debt | `0x0047d8bc` | 1,000,000 | none | new, N-07 |
| Early payoff | `0x0047c3a4` | balance plus 30% of the remaining interest | none | new, N-30 |
| Loan visits | `0x004bcfe8` | overdue loans open the dialog; level 4 and up beats the player (15-30 health) | none | new, N-08 |
| Jail release order | `0x004be728` | `Random(7) < 3` per day, uniform among sharks still in jail | none | new, N-09 |

## Hospital

`0x004c402c` (`SkinHospitalBtnClick`) opens the hospital (`0x004b3198`). At full health it only says "You are perfectly healthy." The price per health point is `DAT_004e2118 * K(50)`, where `DAT_004e2118` is the `Random(9) + 1` rolled with the day's prices, so a point costs 50 to 450 and changes daily. The "$300 per HEALTH POINT" in the form caption and in the doctor's welcome text (`0x0053e25e`) is a design-time sample, not the runtime price: a running 2.1 quoted "a mere $200 per health point. You can afford 8 health points" with 1,780 cash (200 is 4 x 50, inside the range). The affordable maximum is `cash div price` and the dialog caps the quantity at `100 - health`; with a maximum of 0 the player is told they cannot afford a point.

After a purchase, `Random(5) == 0` (1 in 5) and `day < limit - 1` trigger the "nasty doctor" roll `Random(3) + 1`: 1 removes all drugs (`RemoveDrugs`, becomes 3 when no drugs are held), 2 caps health below 80 and sets the infection counter and warning flag (becomes 4 when `DAT_004e20f8` equals a decoded literal), and 3 or 4 show a text from `_DAT_004ddf40`-`_DAT_004ddf4c`. The draw order and the 1-in-5 gate are read from the decompile; the texts and the effect of outcomes 3 and 4 on cash and kidneys were not decoded (unresolved, N-31 carries the confirmed part).

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Hospital price | `0x004c402c` | `(Random(9) + 1) * 50` per health point, rolled daily | none | new, N-10 |
| Nasty doctor | `0x004c402c` | 1 in 5 after a purchase: drugs taken, infection, or cash and kidney outcomes (partly decoded) | none | new, N-31 |

## Super Store

`0x004b0288` (`StoreDlg_ShowWeapons`) and `0x004b03e8` (`StoreDlg_ShowAmmo`) show the catalogue (weapons with Weapon and Price columns, ammo with Ammo and Price columns, a shopping basket and Checkout). `0x004b0968` (`SkinWeaponBtnClick`) and `0x004b0b18` (`SkinAmmoBtnClick`) add items; `0x004b0ca0` (`SkinRemoveBtnClick`) and `0x004b05b4` (`SkinOKBtnClick`) handle the basket. The store replaces the 1.2 gun dealer, which no longer appears among the arrival stages.

Weapons are built at `0x004b7fe0` via `FUN_004bbd34(Self, index, name, class, accuracy, ammoField, price, ...)`, 11 dwords per record from `DAT_004e1008`. The shipped build uses the 6 joke weapons; the "real" weapons (Stick, Beretta, Colt-45, Shotgun, Uzi-9mm, Bazooka) exist only as design-time captions in the store form.

| Index | Weapon | Class (+0x1c) | Accuracy (+0x18) | Ammo price per round (+0x10) | Builder price (+0x14, store shows x1.2) |
| --- | --- | --- | --- | --- | --- |
| 0 | Handbag | 1 | 5 | 0 | 50 |
| 1 | Pea Shooter | 2 | 30 | 20 | 2,000 |
| 2 | Water Pistol | 2 | 50 | 40 | 6,000 |
| 3 | Monkey | 2 | 80 | 70 | 12,000 |
| 4 | Catapult | 3 | 200 | 700 | 30,000 |
| 5 | Rubber Chicken Launcher | 4 | 500 | 5,000 | 450,000 |

Accuracy is the value tested in `Random(100) + 1 <= accuracy` in the chase (above 100 it scares several deputies away at once). The store shows every price 20% above the builder value: Handbag 60, Pea Shooter 2,400, Water Pistol 7,200, Monkey 14,400, Catapult 36,000, Rubber Chicken Launcher 540,000, identical on day 2 and day 12, so the markup is a constant. The field at +0x10 is the ammo price per round: the store sells ammo in packs of 10 at `field * 10 * 1.2` (10 peas for the Pea Shooter 240, 10 water cups 480, 10 bananas 840, 10 marshmallows 8,400, 10 rubber chickens 60,000); the Handbag has no ammo. The store has no real weapons. These rows were confirmed on a running 2.1 (see "Verification on the 2.1 build").

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Gun dealer | 1.2 | replaced by Super Store | none | changed, N-11 |
| Weapon set | `0x004b7fe0` | 6 joke weapons; store prices are the builder value times 1.2 (60 to 540,000); ammo in packs of 10 | none | new, N-12 |

## Health: infection, dialysis, kidneys

Day-end checks run at `0x004bc790` on every travel and from `LoseDay`. They draw nothing.

- Infection: each day with health below 80 (`K(80)`) increments the counter `DAT_004e2110`. At 5 days (`K(5)`) the player first sees "You have a nasty infection. You should see a doctor, or your health will just get worse." and from then on loses 10 health a day; 0 health ends the game with `EndGame(1)` ("Your infection got the better of you. You're dead. What a drag!"). The hospital clears the counter and the warning flag when health is restored to 80 or more (`0x004c402c`).
- Kidneys: with fewer than 2 kidneys and no dialysis machine the player loses `(2 - kidneys) * 5` health a day (5 with one kidney, 10 with none); 0 health ends the game with `EndGame(2)` ("Your kidney problems killed you. You're dead. What a drag!").
- Dialysis machine: `0x004be728` offers it with `Random(3) == 0` when the player has no machine and 0 or 1 kidneys. `0x004befd8` (`BuyDialysisMachine`) asks "Would you like to buy a portable dialysis machine for $100,000?" (a Yes/No box) and only when cash is above 100,000 (`K(100000)`); Yes sets `DAT_004e2147` and subtracts 100,000 from cash. A machine stops the daily kidney damage.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Dialysis machine | `0x004befd8` | 100,000, 1 in 3 offer per travel with 0 or 1 kidneys | none | new, N-13 |
| Infection | `0x004bc790` | health below 80 for 5 days, then 10 health a day, death at 0 | none | new, N-14 |
| Kidney damage and death | `0x004bc790` | `(2 - kidneys) * 5` a day without a machine, death at 0 | none | new, N-15 |
| Mugging health loss | `0x004bf420` | `Random(10) + 1` health, floored at 1 | none | new, N-21 |

How kidneys are removed is the unresolved part of the nasty doctor (see "Hospital").

## Old Lady

`0x004beae0` (`OldLadyComment`) runs from `0x004be728` with `Random(5) == 0` when no tip is pending and she is not muted (`DAT_004e2143`, set by the mute option). The dialog text is "An old lady on the `<location>` says:" followed by a line. `Random(3) == 0` (1 in 3) gives a tip: a spike drug (`Random(13)` redrawn until the drug has the spike mark) becomes the tip drug and the line is "I hear there is going to be `<drug plural>` raid tomorrow." The tip forces that drug to spike on the next price roll (see "Price roll"). Otherwise the line is phrase `Random(DAT_004e2160)` from `oldlady.txt`. She can say the player's name in her phrases (2.1 changelog); the `%NAME%` token is at `0x004bed3c` area.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Old Lady | `0x004beae0` | 1 in 5 per travel; 1 in 3 of those is a spike tip, else a file phrase | none | new, N-16 |
| Tip raid | `0x004beae0`, `0x004bbfc4` | tipped drug spikes next day | none | new, N-32 |
| Mute | `0x004be728` | mute flag `DAT_004e2143` stops her | none | new, N-17 |

## Finances

`0x0047d680` (`FinanceDlg_FormShow`) opens the finance dialog. `0x0047de28` (`DepositBtnClick`), `0x0047dfe8` (`WithdrawBtnClick`), `0x0047e1cc` (`SkinDepositAllBtnClick`), `0x0047e1c0` (`SkinOKBtnClick`), `0x0047e4b0` (`SkinPayAllLoanBtnClick`), `0x0047e558` (`SkinBorrowBtnClick`), `0x0047e85c` (`SkinRepayBtnClick`) are the buttons. "Deposit All But.." with a withhold amount set in `0x004b1574` (`OptionsDlg_SkinOkBtnClick`) is a 2.1 redesign.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Deposit all but | `0x0047e1cc` | withhold amount | none | new, N-18 |

## Score and high scores

`0x004c3230` (`AddHighScore`) computes `cash + bank - debt` and records it if above 0. The list size is `0x004c3520` = 30 (1.2 had 10). The score table has four pages: 15, 30, 60 and 90 day games (`0x004c2a0c`, `0x004c2a28`, `0x004c2a44`, `0x004c3520`, `0x004c3530`, `0x004c3540`).

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Final score | `0x004c3230` | `cash + bank - debt` | `cash + bank - debt` | match |
| Score recorded | `0x004c3230` | above 0 | same | match |
| List size | `0x004c3520` | 30 entries | 10 entries | changed, N-19 |
| Score pages | `0x004c2a0c` | 15/30/60/90 day pages | one page | changed, N-20 |

## Interest

`0x004bfbe0`, which the first pass of this document took for the interest handler, is the status-line refresh: it writes "Day `<day>`/`<limit>`" and the cash, bank and debt labels, and shrinks the LCD font once cash plus bank passes 1,000,000,000 (the 2.1 changelog's "LCD font decreases" entry). The BSS addresses `0x004bfffc`, `0x004c000c` and `0x004c001c` are format-string cells it passes to the display helpers, not rates.

Bank interest is `0x004c0358`, called once per travel after the arrival events. When bank is above 0 it computes `rate = K(5) / 100.0` (a single-precision `100.0` at `0x004c041c`) and `bank += Round(bank * rate)`, so the rate is 5% per day, which matches the changelog's cut to 3% in 2.2. `Round` is the same x87 `FISTP` (`0x004029f4`) as in 1.2. Because the rate is built as a double from `5 / 100.0` and the product is formed in extended precision, an exact `.5` tie (bank of 10 mod 20) lands a hair above the tie and rounds up, so the 1.2 ties-to-even and the extended-`1.05` analysis in `docs/beermat-re.md` ("Interest arithmetic") do not carry over. The running game confirmed it: a bank of 30 became 32 and a bank of 50 became 53 (1.2 gave 31 and 52); the other balances seen (32, 34, 36, 38, 40, 42, 46, 48, 53, 56, 59, 62) all moved by `Round(bank * 0.05)`. N-33 carries this arithmetic.

Debt interest is per loan (see "Loan sharks"): `0x004c0420` compounds each loan at its shark's daily rate.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Bank interest | `0x004c0358` | 5% per day, `Round(bank * 0.05)`, only above 0 | 5%, `bank * 1.05` ties-to-even | changed, N-33 |
| Debt interest | `0x004c0420` | per loan, daily compounding at the shark's rate | 10% on one debt | changed, N-06 |

## Statistics counters

`0x004b25a4` (`StatsForm_FormShow`) fills the "Dope Wars 2.1 Statistics" window from counters kept in the game state. The captions come from `forms/StatsForm.dfm`; the counters whose increment site was traced are listed with it, the rest are unresolved.

| Counter | Increment site |
| --- | --- |
| Chases | `0x004bd758`, `+1` per chase (`DAT_004e1eb0`) |
| Cops faced | `0x004bd758` writes `DAT_004e1ebc` from the deputy draw (the exact formula was not traced) |
| Possession arrests | `0x004a5308`, `+1` on a drugs or weapons arrest (stats block `+4`) |
| Assault arrests | `0x004a5308`, `+1` on an arrest after a fight (stats block `+8`) |
| Cops scared | per-weapon hit counter, `0x004a5860` (+0x28 of the weapon record), shown with the per-weapon "hits/uses" and a hit percentage |
| Weapon uses | `0x004a5860`, `+1` per Fight (+0x24 of the weapon record) |
| Loans | `0x0047e558`, `+1` per borrow (stats block `+0x14`) |
| Total borrowed | `0x0047e558`, `+= amount` (stats block `+0x18`), plus the 5500 starter loan in `DAT_004e1ec8` |
| Total repaid, total interest, total owed | not traced (unresolved, cosmetic) |

## Sounds

The 2.1 sound table is not in the exe as 1.2's records are. The image holds only the `DW*` event names, and the wav paths live in the registry entries the installer writes, which the Wise script lists. The extractor joins `appevents.tsv` (event to wav and label, from the Wise script) with the event names in the dump, matching case-insensitively. The six `DW<Weapon>Hit` events have no string of their own, because the game builds them at run time from the weapon event name and the three-character suffix. All 38 events resolve to the handlers below (from `sound_handlers.tsv`):

| Event | Wav | Handler |
| --- | --- | --- |
| `DWBlanks` | `blank.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWGoodEvent` | `Charge.wav` | `0x004bf134` FUN_004bf134, `0x004bf680` FUN_004bf680 |
| `DWDump` | `dump.wav` | `0x004a5748` TCopChaseDlg_SkinDumpBtnClick, `0x004c3bf8` TDWForm_SkinDumpBtnClick |
| `DWRegistered` | `cheer.wav` | `0x004c3754` FUN_004c3754 |
| `DWAirport` | `airport.wav` | `0x004c3a60` TDWForm_AirportBtnClick |
| `DWLastDay` | `lastday.wav` | `0x004bce80` TDWForm_SetLastDay |
| `DWDead` | `dead.wav` | `0x004bdc34` TDWForm_EndGame |
| `DWMugged` | `mugged.wav` | `0x004bf420` FUN_004bf420 |
| `DWCashReg` | `cashreg.wav` | `0x0047ba64` TBuyDlg_OKBtnClick |
| `DWPoliceDog` | `policedog.wav` | `0x004bf8b4` FUN_004bf8b4 |
| `DWCopChase` | `copchase.wav` | `0x004a3c34` TCopChaseDlg_FormShow |
| `DWYouHitByGun` | `youhit.wav` | `0x004a3f30` TCopChaseDlg_PlayNextEvent |
| `DWCopGunShot` | `copmiss.wav` | `0x004a3f30` TCopChaseDlg_PlayNextEvent |
| `DWHeadlines` | `headlines.wav` | `0x004bc708` TDWForm_DisplayNews |
| `DWHospital` | `hospital.wav` | `0x004c402c` TDWForm_SkinHospitalBtnClick |
| `DWJail` | `jaildoor.wav` | `0x004a5308` TCopChaseDlg_SkinStayBtnClick |
| `DWStore` | `store.wav` | `0x004c3b18` TDWForm_SkinStoreBtnClick |
| `DWLeaveStore` | `thankyou.wav` | `0x004b05b4` TStoreDlg_SkinOKBtnClick |
| `DWEscape` | `whew.wav` | `0x004a3f30` TCopChaseDlg_PlayNextEvent |
| `DWSharkChainsaw` | `chainsaw.wav` | `0x0047c3a4` TLoanSharkDlg_FormShow |
| `DWSharkFirstWarning` | `firstwarn.wav` | `0x004bcfe8` TDWForm_ProcessLoanSharks |
| `DWSharkSecondWarning` | `secwarn.wav` | `0x004bcfe8` TDWForm_ProcessLoanSharks |
| `DWSharkStairs` | `stairs.wav` | `0x0047c3a4` TLoanSharkDlg_FormShow |
| `DWSharkWantMoney` | `money.wav` | `0x0047e85c` TFinanceDlg_SkinRepayBtnClick, `0x004bcfe8` TDWForm_ProcessLoanSharks |
| `DWBorrow` | `borrow.wav` | `0x0047e558` TFinanceDlg_SkinBorrowBtnClick |
| `DWHandBag` | `handbag.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWHandBagHit` | `handbaghit.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWMonkey` | `monkey.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWMonkeyHit` | `monkeyhit.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWPeaShooter` | `peashoot.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWPeaShooterHit` | `peashoothit.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWWaterPistol` | `pistol.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWWaterPistolHit` | `pistolhit.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWCatapult` | `catapult.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWCatapultHit` | `catapulthit.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWRubberChicken` | `chicken.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWRubberChickenHit` | `chickenhit.wav` | `0x004a4a80` TCopChaseDlg_PlayWeaponSound |
| `DWSharkWindow` | `window.wav` | `0x0047c3a4` TLoanSharkDlg_FormShow |

New in 2.1 relative to 1.2's ten events: the loan shark events (`DWBorrow`, `DWSharkWantMoney`, `DWSharkFirstWarning`, `DWSharkSecondWarning`, `DWSharkWindow`, `DWSharkStairs`, `DWSharkChainsaw`), the store and hospital events, `DWJail`, `DWDump`, `DWEscape`, `DWBlanks`, `DWGoodEvent`, `DWHeadlines`, `DWAirport`, `DWRegistered` and the six weapon pairs. Slice TASK-013.02.17 carries them. The sound player's `AllowSound` gate is not re-read in this pass.

## Unpack approach

Everything below is reproducible from `vendor/dopewars-2001/dw21.exe` and a 32-bit Windows XP bottle in CrossOver (or any Wine that runs a 32-bit prefix). The installer is never run, and the Gator stub is never extracted.

1. Run `task re:unwise`. It writes `DopeWars.exe`, `cities.txt`, `oldlady.txt`, `Olchk32.dll`, the wavs and `appevents.tsv` (38 event, wav and label rows read from the Wise script) into gitignored `vendor/dopewars-2001/game/`.
2. Copy those files into a directory in the bottle. `Olchk32.dll` is PC Guard's runtime check library, and the installer puts it in the system directory. Without it the game stops with "DLL loading error: OLCHK32.DLL".
3. Seed the settings the installer would have written, under `HKCU\Software\Beermat Software\DopeWars\2.0\Settings`. The Wise script holds 33 values as key, data and name triples. Numbers must be `REG_DWORD`, and names, dates, the proxy values and `License` are strings, with `Name` and `License` left empty. Delphi's errors tell the cases apart: "Failed to get data for X" means the value is missing, and "Invalid data type for X" means the wrong type. One more value, `Registered` (`REG_DWORD`, 0), is not in the script, and the game fails with "Failed to get data for registered" without it once a key has been entered.
4. Start the game with the bottle's `wine` from a working directory that holds the copied files. PC Guard unpacks for about 45 to 60 seconds at roughly 100% CPU, and then the process idles. The disclaimer dialog appears first.
5. Enter the license key in the registration dialog. The game then lists the registered features (15, 60 and 90 day games, Price History, direction indicators, extra weapons, Top 20 scores, the Elite league) and shows itself as registered. The key never goes into the repo or this document.
6. Dump the running process with `pe-sieve32.exe /pid <windows pid> /imp 3 /dmode 3 /dir <dump dir>` (hasherezade's pe-sieve, v0.4.1.1). Take the Windows pid from `wine tasklist`. Copy the `400000.DopeWars.exe` file to gitignored `vendor/dopewars-2001/dump/DopeWars.dump.exe`.
   - `/dmode 3` (realigned) is required. The default virtual layout leaves the section headers inconsistent with the file, and pefile then reads none of the form resources.
   - The code section drops from entropy near 8.0 to about 6.5 once decrypted. The dump has no import directory, but pe-sieve lists about 530 recovered imports in `*.imports.txt`, and 61 of them are PC Guard redirect thunks (`0x1000xxxx`) rather than API addresses. The entry point is still in the PC Guard stub, so function discovery in Ghidra comes from the VMTs, not the entry point.
   - pe-sieve was used instead of the Scylla x86 named in the task because it is a command-line tool that rebuilds imports without a GUI, which suits a bottle with no scripted input.
7. Extract and decompile with the existing pipeline:
   - `task re:extract EXE=vendor/dopewars-2001/dump/DopeWars.dump.exe OUT=vendor/dopewars-2001/re APPEVENTS=vendor/dopewars-2001/game/appevents.tsv`
   - `task re:decompile` and `task re:disasm` with the same `EXE` and `OUT`. `re:decompile` writes about 4280 functions. The one reported failure is the PC Guard stub at the entry point, which times out in the decompiler and is not game code.
   - `task re:sound-handlers OUT=vendor/dopewars-2001/re` writes `sound_handlers.tsv`, which maps each of the 38 events to the decompiled functions that reference its name string. All 38 resolve.

What the extractor recovers from the dump: 25 forms, 298 VMTs, 24 classes with 305 published methods, 603 labels, and a 38-row `sounds.tsv`. `extract_beermat.py` treats a `.PCGW32` section as encrypted only while its entropy is at least 7.5, so a dump is handled as a normal image.

Findings from the dump:

- `IntroDlg` and `NMShow` are form resources with no class in the image (no VMT, and no class-name string outside the resource). Their handlers (`FormActivate`, `Label8Click`, `Button1Click` to `Button5Click`) have no code, so the extractor warns about them and does not count them as unresolved.

Ghidra needed two changes for the dump. `DiscoverFunctions.java` looked up a block named `CODE`, and now falls back to the first executable block, which is `.PCGW32` in a dump. `ApplyLabels.java` now clears an instruction that straddles a labeled entry: the string and padding before a function had been disassembled as code and blocked three handlers, among them `TCityEditor_FormShow`.

Handling notes for the bottle:

- Shut the bottle down with `WINEPREFIX=<bottle> wineserver -k` followed by `wineserver -w`. A kill -9 of the wineserver loses unflushed registry writes, and every wine command needs an explicit `WINEPREFIX` or it can act on another bottle's server.
- Do not trace. `WINEDEBUG=+reg` made PC Guard hit a privileged instruction and crash under winedbg. Leftover wine processes from a previous run caused the same crash once, so clean up first.
- Fallbacks if pe-sieve fails, in order: a `winedbg` minidump, then a Windows reference machine. Neither was needed.

## 1.2 findings re-checked against 2.1

Every 1.2 rule M-01 to M-13 from `docs/beermat-re.md`, with its 2.1 address and verdict:

| 1.2 ID | Rule | 2.1 VA | Verdict | New ID |
| --- | --- | --- | --- | --- |
| M-01 | Drug table, ranges and flags | `0x004b7fe0`, `0x004bbc04` | changed: 13 drugs, Smack to MDA, Shrooms to Mushrooms, Special K added, Crack gained the crash flag and MDA the spike flag; every shared range is unchanged | N-34 |
| M-02 | Price spike and crash | `0x004bbfc4` | changed: 1 in 40 not 1 in 20, needs no event the previous day, Special K has its own spike text, a tip forces a spike; the x5 and div 10 effects and the `Random(2)` bust or Addicts pick are unchanged | N-35 |
| M-03 | Availability | `0x004bbfc4` | unchanged: `Random(8) == 0` absent, location independent; drawn after the price instead of before the spike, and a tip drug stays available | none |
| M-04 | Chase start chance | `0x004bc9d4` | changed: `Random(8) == 0` (1 in 8), and no chase on the last two days | N-22 |
| M-05 | Dealers, coat and gun prices | `0x004be728`, `0x004bee64` | changed: coat price 201-350 and pockets 11-20 unchanged, but a separate 1 in 15 trigger limited to capacity below `day + 150`; the gun dealer is removed | N-28 |
| M-06 | Arrival event table | `0x004be728` | changed: gate `Random(13)` not `Random(14)`, five outcomes with different weights, drug pool is 13 not 11, mugging costs health, brownies added, wealth cap removed; found, friend and police-dog draws are otherwise unchanged | N-29 |
| M-07 | Run, stay and cop damage | `0x004a528c`, `0x004a5308`, `0x004a5190` | changed for run (`Random(10) < 2`) and stay (arrest, no draw); cop hit damage `Random(11) + 5` is unchanged | N-24, N-26 |
| M-08 | Fight resolution and win condition | `0x004a5860`, `0x004a4c7c` | changed: weapon accuracy against `Random(100) + 1`, a hit scares deputies away, win when the counter drops below 0 is kept | N-25 |
| M-09 | Chase win reward and doctor | `0x004a4c7c` | changed: cash only, no gun and no doctor offer | N-27 |
| M-10 | Interest rounding | `0x004c0358`, `0x004c0420` | changed: bank 5% via `Round(bank * 0.05)`, debt per loan at shark rates | N-33, N-06 |
| M-11 | New Game gate | `0x004bc9d4` | unchanged in kind, usable from day 5 where 1.2 was day 6 (intentional delta kept) | none |
| M-12 | Average cost integer division | `0x004bf134`, `0x004bf680`, `0x004bf8b4` | unchanged: the same integer dilution on find and friend, and the same rescale on drops | none |
| M-13 | Score above 0 to record | `0x004c3230` | unchanged | none |

No 1.2 rule is removed outright, though the 1.2 gun dealer and the cash-plus-bank mugging cap lose their 2.1 counterparts, which is recorded under M-05 and M-06. Buying and selling are not re-read in this pass.

## Verification on the 2.1 build

2.1 was run natively on a Windows 11 machine (the PC Guard protection needs no unpacking there), registered, and played for 15 days of a 90-day game in New York. The observations below were read off the running game. The game's randomness is wall-clock seeded, so only deterministic rules and rare events seen first-hand count as confirmed; rates are not measured.

| Rule | Observed on the running game | Result |
| --- | --- | --- |
| Registration and game lengths | the registered build offers 15, 30, 60 and 90 day games | confirms N-01 |
| Start state | cash 2,000, bank 0, debt 5,500, health 100%, two kidney icons, coat space 100/100 | confirms the start-state row and the coat 100 correction |
| Starter loan | Honest Harry, 5,500, 15%, 10 days left | confirms the starter loan |
| Debt interest | 5,500, 6,325, 7,274, 8,365, 9,620, 11,063, 12,722, 14,630, 16,824, 19,348, 22,250, 25,587, 29,425, 33,839, 38,915, 44,752 | confirms per-loan daily compounding; the 25,587 step confirms the double-precision rounding |
| Bank interest | 30 to 32, 50 to 53, and the other balances above | confirms N-33 including tie rounding |
| Early payoff | "You owe $11,103" on a 6,325 loan with 9 days left | confirms N-30 exactly |
| Shark offers | Bulbous Bertha 30 / 1 / 50x and Midget Mickey 25 / 5 / 100x appeared after day 5, none on day 1 | confirms the shark table and release |
| Borrow cap | 92250 for Bertha with 1,780 cash and 65 bank | confirms the multiple of cash plus bank |
| Visit warnings | "will be visiting you tomorrow" on day 10, then "due today", "was due yesterday", "2 days past due", "3 days past due" with the "had better pay your loan" text | confirms the visit levels and texts |
| Beating | at "4 days past due" health went from 55% to 34% (21 points) with the chainsaw text and "his boys" for a male shark | confirms N-08 and the 15-30 range |
| Hospital | "$200 per health point", affordable 8 with 1,780 cash | confirms N-10 and that $300 is a caption |
| Store | weapons 60 / 2,400 / 7,200 / 14,400 / 36,000 / 540,000, ammo packs of 10, the same on day 2 and day 12 | confirms N-12 with the 1.2x markup |
| Drug set and ranges | 13 drugs including MDA, Mushrooms, Special K; every price seen inside the table ranges; prices kept for a day on some drugs (Crack, Special K, Cocaine, Opium) | confirms N-34 and the flat pricing |
| Price crash | "The market has been flooded with cheap home-made acid!" with Acid at 316; "The Marrakesh Express has arrived!" (Hashish 78) and "Rival dealers raided a pharmacy and are selling cheap ecstasy!" (Ecstasy 2) on one day | confirms the crash texts and the divide by 10 |
| Price spike | "Cops made a big MDA bust! Prices are outrageous!" with MDA at 18,165 | confirms the spike text and the multiply by 5 |
| New Game gate | New Game was greyed on days 1-4 and enabled once the day reached 5 | confirms N-22's companion row |
| Chase | "Officer Hardass and 2 / 8 / 5 of his deputies are chasing you!" (2 and 8 are the range ends); Dump greyed with an empty coat | confirms N-23 |
| Stay, nothing carried | the pat-down text with no cop fire | confirms N-26 |
| Stay, drugs carried | the arrest text, drugs confiscated, and the day counter jumped from 7 to 9 | confirms N-26 and the lost day; debt and bank compounded for both days |
| Run | 8 runs in one chase: 7 failed (5 hits of 10, 9, 5, 12 and 9 health, 2 misses) and the 8th escaped | consistent with N-24 (hit damage 5-15) |
| Chases seen | 3 chases in about 15 travels | consistent with 1 in 8, not a measurement |

Not observed in 15 days, so still read from the decompile only: the arrival event table (find, friend, mugging, police dogs, brownies), the coat dealer, the dialysis offer, the Old Lady, infection and kidney damage, the nasty doctor, the Fight resolution with a weapon, the chase win reward, and the shark release news text (the offers appeared, but the news line was not caught).

Seeding note for reproducing the run: besides the `Settings` values, the game reads a `Registered` value from each score key under `Scores15`, `Scores30`, `Scores60` and `Scores90`; without them it stops at startup with "Failed to get data for 'Registered'". The Wise script holds 80 score keys with `Name`, `Key` and `Registered`, and all of them have to be present.

## Open questions

All four questions from the first pass are answered from the decompile:

- Loan shark rate, duration and amount per shark, and the jail-release order: answered in "Loan sharks" (rates 15/10/20/30/25 per day, durations 10/15/7/1/5 days, amounts 10x/20x/30x/50x/100x of cash plus bank, release by `Random(7) < 3` and a uniform pick among those still in jail).
- Per-drug spike message pairing: answered in "Price roll". The pairing is not per drug: `Random(2)` picks bust or Addicts for every spike drug except Special K, which has its own text.
- Bank interest: answered in "Interest". `0x004bfffc` is a display format cell, and the real handler `0x004c0358` uses 5%.
- Arrival-event split: answered in "Arrival events". The dealer and the event are separate rolls of 1 in 15 and 1 in 13.

Still unresolved, each with the reason:

- How many deputies a Fight hit scares away (`0x004a3f30` case 4): the weapon field mapping is read from the builder arguments only, and the compare against `DAT_004d236c` was not traced.
- The outcomes of the nasty doctor beyond the 1-in-5 gate and the drug removal (`0x004c402c`): the texts at `_DAT_004ddf40`-`_DAT_004ddf4c` and the cash and kidney effects are not decoded.
- The exact joining words of the Old Lady and post-arrest tip texts: they are assembled at run time from a prefix, the drug name and a suffix.
- What `DAT_004e2160` (the Old Lady phrase count) and `oldlady.txt` contain beyond the 13 phrases noted from `0x004bed1c`.
- The effect of changing any of the above on 2.2: this document is 2.1 only.

Rows not listed under "Verification on the 2.1 build" were read from decompiled code and cross-checked against the form captions only.

## New difference index

| ID | Rule | Section | Subtask |
| --- | --- | --- | --- |
| N-01 | Game length 15/30/60/90 days | Travel | TASK-013.02.02 |
| N-05 | Dump drugs in a chase | Chase | TASK-013.02.09 |
| N-06 | Loan sharks replace single debt; shark table; starter loan; per-loan daily compounding | Loan sharks | TASK-013.02.04 |
| N-07 | Max total debt 1,000,000 and the borrow cap | Loan sharks | TASK-013.02.04 |
| N-08 | Loan visits, warning levels and beatings | Loan sharks | TASK-013.02.05 |
| N-09 | Sharks released from jail in random order | Loan sharks | TASK-013.02.05 |
| N-10 | Hospital price `(Random(9) + 1) * 50` per point | Hospital | TASK-013.02.07 |
| N-11 | Super Store replaces gun dealer | Super Store | TASK-013.02.08 |
| N-12 | Joke weapon set (6 weapons) | Super Store | TASK-013.02.08 |
| N-13 | Dialysis machine 100,000 | Health | TASK-013.02.13 |
| N-14 | Infection (below 80 for 5 days, 10 a day) | Health | TASK-013.02.14 |
| N-15 | Kidney damage and death | Health | TASK-013.02.10 |
| N-16 | Old Lady phrases and tips | Old Lady | TASK-013.02.11 |
| N-17 | Old Lady mute | Old Lady | TASK-013.02.11 |
| N-18 | Deposit All But withhold | Finances | TASK-013.02.06 |
| N-19 | Score list 30 entries | Score | TASK-013.02 (no dedicated slice) |
| N-20 | Score pages 15/30/60/90 | Score | TASK-013.02 (no dedicated slice) |
| N-21 | Mugging costs health | Arrival | TASK-013.02.10 |
| N-22 | Chase start chance 1 in 8, none on the last two days | Travel | TASK-013.02.09 |
| N-23 | Deputy count 2-8 (`Random(7) + 2`) | Chase | TASK-013.02.09 |
| N-24 | Run: `Random(10) < 2` escape, then `Random(3)` | Chase | TASK-013.02.09 |
| N-25 | Fight: weapon accuracy against `Random(100) + 1`, return fire | Chase | TASK-013.02.09 |
| N-26 | Stay is an arrest check, no cop fire | Chase | TASK-013.02.12 |
| N-27 | Chase win reward is cash | Chase | TASK-013.02.09 |
| N-28 | Coat dealer 1 in 15 with a capacity gate; gun dealer removed | Arrival | TASK-013.02.10 (no dedicated slice) |
| N-29 | Event gate 1 in 13 and five-outcome table | Arrival | TASK-013.02.10 (no dedicated slice) |
| N-30 | Early payoff: balance plus 30% of the remaining interest | Loan sharks | TASK-013.02.04 |
| N-31 | Nasty doctor (partly decoded) | Hospital | TASK-013.02.10 |
| N-32 | Old Lady tip forces a spike | Old Lady | TASK-013.02.11 |
| N-33 | Bank interest 5% with the 2.1 rounding | Interest | TASK-013.02.04 |
| N-34 | 13-drug table and flags | Drug table | TASK-013.02.03 |
| N-35 | Flat price model, 1 in 40 spike and crash, Special K text | Price roll | TASK-013.02.03 |
