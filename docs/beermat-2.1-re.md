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
| Game length | `0x004c2a0c`-`0x004c2a44` | 15, 30, 60 or 90 days, chosen at new game; `DAT_004e20f0` holds the limit | `numDays` | changed, N-01 |
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

`0x004bd758` starts it: `deputies = Random(0x4bda1c) + 2` (2-8), shows "Officer Hardass and N of his deputies are chasing you !" (`0x004bdc30`). `TCopChaseDlg.FormShow` (`0x004a3c34`) sets `DAT_004d398c = 0` and opens the dialog. `0x004a4c7c` is the cop-chase timer; `0x004a3f30` plays the next event. There is a single cop tier (Officer Hardass); the deputy count is not scaled by day or location. Dying (health 0) ends the game: "They wasted you man. What a drag!" (`0x004ddf20`), plays `DWDead`, records the score.

The cop-chase dialog is a real-time timer, not a turn menu: the deputy count is `DAT_004d398c` with a max of `0x004a5278` = 11 (a form placeholder; the runtime draw is 2-8), and `DAT_004d3998` is the event queue. Run (`0x004a528c`), Stay (`0x004a5308`), Fight (`0x004a5860`) and Dump (`0x004a5748`) each append an event to the queue; the timer (`0x004a4c7c`) drains it and plays the matching message/sound. Fight draws the weapon hit against `Random(100)` (`0x004a5860` line 33); run draws `Random(0x004a5300 = 10)` then `Random(3)`.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Deputy count | `0x004bd758` | `Random(7) + 2`, 2-8 | `randInt(2, 11)` | mismatch, N-23 |
| Run | `0x004a528c` | `Random(10) < 2`: escape (event 7), else `Random(3)`: 0 = fire (event 1), else fire (event 2) | `randInt` | mismatch, N-24 |
| Fight | `0x004a5860` | weapon hit vs `Random(100)`: hit on `Random(100) <= weapon`; kill (event 4) or wound (event 3) | `fight` | mismatch, N-25 |
| Stay | `0x004a5308` | cops fire; arrest on a failed run; "Officer Hardass pats you down for assault" | `stayInChase` | mismatch, N-26 |
| Dump drugs | `0x004a5748` | "Are you sure you want to dump all your drugs?" clears held drugs and weapons | none | new, N-06 |
| Chase win reward | `0x004bd758` | free drugs: `Random(0x4bda54 = 13)` drugs, quantity up to `Random(0x4bda48 = 2)`, min 1 | `fight` | mismatch, N-27 |

The win reward is a mismatch: 2.1 gives free drugs (constants `0x4bda34 = 1000` is a flag, `0x4bda48 = 2` is the max quantity draw, `0x4bda54 = 13` is the drug count pool, `0x4bda64 = 10` is a minimum quantity), where the engine gives a gun and cash. This is a new difference N-27.

## Loan sharks

`0x004bcfe8` (`ProcessLoanSharks`) processes due loans. `0x0047d720` (`FinanceDlg_DrawOfferings`) shows the offer; `0x0047d02c` (`LoanSharkDlg_SkinPayNowBtn1Click`) and `0x0047d0cc` (`LoanSharkDlg_SkinPayLaterBtnClick`) handle repayment. The loan-shark names are built at `0x004b7fe0` via `FUN_004bbe4c`: Honest Harry, Sandy Schwing, Tank NoNeck, Bulbous Bertha, Midget Mickey. The max total debt is `0x0047d8bc` = 1,000,000.

Loan sharks in 2.1 replace 1.2's single compounding debt. Each shark has a rate, a duration and an amount; borrowing raises the total debt, and a loan past due triggers a visit that can send the player to jail. The loan record is built by `0x004bbe4c` (called 5 times from `0x004b7fe0`, indices 0-4). It stores the name pointer at `0x004d27f8 + i*0x20`, the amount at `0x004d260c + i*0x20`, and the duration at `0x004d2720 + i*0x10`. The borrow handler `0x0047e558` reads the selected shark's amount, adds it to debt (`DAT_004e20c8`), bank (`DAT_004e20b8`), and the loan record, then increments the loan counter. The visit handler `0x004bcfe8` (`ProcessLoanSharks`) iterates the 5 loan slots, and for each due loan shows a visit dialog (`0x0047cf44` `DrawShark`) and, on non-payment, sends the player to jail (`0x004bdc34` `EndGame` with the jail outcome). The exact per-shark rate/duration/amount values are stored in the record fields at `0x004d27f8/0x004d260c/0x004d2720` and the jail-release order is not yet decoded from the builder and needs the bottle.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Single debt at 10% | 1.2 `0x0045e3d4` | replaced by loan sharks | none | changed, N-06 |
| Max debt | `0x0047d8bc` | 1,000,000 | none | new, N-07 |
| Loan visits | `0x004bcfe8` | due loans trigger visits, jail on non-payment | none | new, N-08 |
| Jail release order | 2.1 changelog | released in random order | none | new, N-09 |

## Hospital

`0x004b3198` (`HospitalDlg_FormPaint`) draws the dialog. The price is `0x004b8bf0` = 300 per health point (from the form caption "$300 per HEALTH POINT"). `0x004c402c` (`SkinHospitalBtnClick`) opens it. Buying health back is a 2.0 feature; the price and the quantity box are 2.1.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Hospital price | `0x004b8bf0` | 300 per health point | none | new, N-10 |

## Super Store

`0x004b0288` (`StoreDlg_ShowWeapons`) and `0x004b03e8` (`StoreDlg_ShowAmmo`) show the catalogue. `0x004b0968` (`SkinWeaponBtnClick`) and `0x004b0b18` (`SkinAmmoBtnClick`) select tabs; `0x004b0ca0` (`SkinRemoveBtnClick`) and `0x004b05b4` (`SkinOKBtnClick`) handle the basket. The store replaces the 1.2 gun dealer.

Weapons are built at `0x004b7fe0` via `FUN_004bbd34` (6 joke weapons): Handbag, Pea Shooter, Water Pistol, Monkey, Catapult, Rubber Chicken Launcher. The "real" weapons (Stick, Beretta, Colt-45, Shotgun, Uzi-9mm, Bazooka) appear only in the form's sample captions (`0x004b88a8` area) as layout placeholders. **The shipped build uses the 6 joke weapons** — this resolves the open question from the resource-only table.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Gun dealer | 1.2 | replaced by Super Store | none | changed, N-11 |
| Weapon set | `0x004b7fe0` | 6 joke weapons | none | new, N-12 |

## Health: infection, dialysis, kidneys

`0x004be728` rolls the infection check (`0x004beaac` = 3), the dialysis offer (`0x004bed10` = 3), and the doctor event. `0x004befd8` (`BuyDialysisMachine`) offers a portable dialysis machine for `0x004bf0d4` = 100,000. Infection below 80% health for 5 days (`0x004bea4c` = 5, `0x004bc9b0` = 80) kills the player; kidney failure also kills (`0x004ddf24`).

`0x004bf420` is the doctor event. It runs when the doctor flag is set (`0x004be728` case 2). It rolls `Random(0x4bf5f4 = 10)` minus current health; if positive it deducts that amount from health (`DAT_004e20dc`) and, with a `Random(2)` draw, either triggers kidney death (`0x004ddf24`) or a "kidney removed" event (`0x004be178` "kidney"). It then plays `DWMugged` ("You were mugged at the airport!") and deducts a portion of cash. The doctor dialog text is at `0x004b7668` ("Welcome to my surgery! ... for a mere 300 per health point") and the hospital is `0x004b3198` (`HospitalDlg_FormPaint`) at 300 per health point.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Dialysis machine | `0x004befd8` | 100,000 | none | new, N-13 |
| Infection death | `0x004beaac` | below 80% health for 5 days | none | new, N-14 |
| Kidney death | `0x004ddf24` | kidney failure kills | none | new, N-15 |
| Doctor event | `0x004bf420` | health deduction + kidney risk + mugged-at-airport | none | new, N-21 |

## Old Lady

`0x004beae0` (`OldLadyComment`) shows the Old Lady's phrase. `0x004bed1c` = 13 phrases from `oldlady.txt`. The mute option (`MuteOldLady`) is a 2.1 feature. The Old Lady can say the player's name.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Old Lady | `0x004beae0` | phrases from oldlady.txt | none | new, N-16 |
| Mute | `0x004797e` | mute option | none | new, N-17 |

## Finances

`0x0047d680` (`FinanceDlg_FormShow`) opens the finance dialog. `0x0047de28` (`DepositBtnClick`), `0x0047dfe8` (`WithdrawBtnClick`), `0x0047e1cc` (`SkinDepositAllBtnClick`), `0x0047e1c0` (`SkinOKBtnClick`), `0x0047e4b0` (`SkinPayAllLoanBtnClick`), `0x0047e558` (`SkinBorrowBtnClick`), `0x0047e85c` (`SkinRepayBtnClick`) are the buttons. "Deposit All But.." with a withhold amount set in `0x004b1574` (`OptionsDlg_SkinOkBtnClick`) is a 2.1 redesign.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Deposit all but | `0x0047e1cc` | withhold amount | none | new, N-18 |

## Score and high scores

`0x004c3230` (`AddHighScore`) computes `cash + bank - debt` and records it if above 0. The list size is `0x004c3520` = 30 (1.2 had 10). The score table has three pages: 15, 30, 60, 90 day games (`0x004c2a0c`, `0x004c2a28`, `0x004c2a44`, `0x004c3520`, `0x004c3530`, `0x004c3540`).

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Final score | `0x004c3230` | `cash + bank - debt` | `cash + bank - debt` | match |
| Score recorded | `0x004c3230` | above 0 | same | match |
| List size | `0x004c3520` | 30 entries | 10 entries | changed, N-19 |
| Score pages | `0x004c2a0c` | 15/30/60/90 day pages | one page | changed, N-20 |

## Interest

`0x004bfbe0` handles bank interest. The rate constants are at `0x004bfffc`, `0x004c000c`, `0x004c001c` (BSS, not decoded). The changelog has the bank interest cut to 3% in 2.2, which implies 5% in 2.1. The debt handling is replaced by loan sharks (N-06).

## Sounds

The 2.1 sound table is not in the exe as 1.2's records are. The image holds only the `DW*` event names, and the wav paths live in the registry entries the installer writes, which the Wise script lists. The extractor joins `appevents.tsv` (event to wav and label, from the Wise script) with the event names in the dump, matching case-insensitively. The six `DW<Weapon>Hit` events have no string of their own, because the game builds them at run time from the weapon event name and the three-character suffix. All 38 events resolve to handlers.

## Unpack approach

Everything below is reproducible from `vendor/dopewars-2001/dw21.exe` and a 32-bit Windows XP bottle in CrossOver (or any Wine that runs a 32-bit prefix). The installer is never run, and the Gator stub is never extracted.

1. Run `task re:unwise`. It writes `DopeWars.exe`, `cities.txt`, `oldlady.txt`, `Olchk32.dll`, the wavs and `appevents.tsv` (38 event, wav and label rows read from the Wise script) into gitignored `vendor/dopewars-2001/game/`.
2. Copy those files into a directory in the bottle (for example `C:\dopewars`). `Olchk32.dll` is PC Guard's runtime check library, and the installer puts it in the system directory. Without it the game stops with "DLL loading error: OLCHK32.DLL".
3. Seed the settings the installer would have written, under `HKCU\Software\Beermat Software\DopeWars\2.0\Settings`. The Wise script holds 33 values as key, data and name triples. Numbers must be `REG_DWORD`, and names, dates, the proxy values and `License` are strings, with `Name` and `License` left empty. Delphi's errors tell the cases apart: "Failed to get data for X" means the value is missing, and "Invalid data type for X" means the wrong type. One more value, `Registered` (`REG_DWORD`, 0), is not in the script, and the game fails with "Failed to get data for registered" without it once a key has been entered.
4. Start the game with the bottle's `wine` from the install directory, for example `wine --bottle <name> --workdir 'C:\dopewars' 'C:\dopewars\DopeWars.exe'`. PC Guard unpacks for about 45 to 60 seconds at roughly 100% CPU, and then the process idles. The disclaimer dialog appears first.
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
- Fallbacks if pe-sieve fails, in order: a `winedbg` minidump, then the Windows oracle described in `CLAUDE.local.md`. Neither was needed.

## Open questions

- The loan shark rate/duration/amount per shark and the jail-release order are not yet decoded from the builder; the bottle confirms them.
- The exact per-drug spike message pairing is not yet decoded from the builder.
- The bank interest rate constant at `0x004bfffc` is in BSS and not decoded; the changelog implies 5%.
- The arrival-event split between "dealer visit" and "arrival event" is not yet separated in the decompile; the bottle confirms it.

## New difference index

| ID | Rule | Section | Subtask |
| --- | --- | --- | --- |
| N-01 | Game length 15/30/60/90 days | Travel | TASK-013.02.02 |
| N-02 | Run resolution (Random(10), Random(3)) | Chase | TASK-013.02.09 |
| N-03 | Fight resolution (weapon hit vs Random(100)) | Chase | TASK-013.02.09 |
| N-04 | Stay resolution (cops fire, arrest) | Chase | TASK-013.02.09 |
| N-05 | Dump drugs in a chase | Chase | TASK-013.02.09 |
| N-06 | Loan sharks replace single debt | Money | TASK-013.02.04 |
| N-07 | Max total debt 1,000,000 | Money | TASK-013.02.04 |
| N-08 | Loan visits and jail on non-payment | Money | TASK-013.02.05 |
| N-09 | Jail release in random order | Money | TASK-013.02.05 |
| N-10 | Hospital 300 per health point | Health | TASK-013.02.07 |
| N-11 | Super Store replaces gun dealer | Store | TASK-013.02.08 |
| N-12 | Joke weapon set (6 weapons) | Store | TASK-013.02.08 |
| N-13 | Dialysis machine 100,000 | Health | TASK-013.02.13 |
| N-14 | Infection death (below 80% for 5 days) | Health | TASK-013.02.10 |
| N-15 | Kidney death | Health | TASK-013.02.10 |
| N-16 | Old Lady phrases | Arrival | TASK-013.02.11 |
| N-17 | Old Lady mute | Arrival | TASK-013.02.11 |
| N-18 | Deposit All But withhold | Finances | TASK-013.02.06 |
| N-19 | Score list 30 entries | Score | TASK-013.02 |
| N-20 | Score pages 15/30/60/90 | Score | TASK-013.02 |
| N-21 | Doctor event (health deduction + kidney risk) | Health | TASK-013.02.10 |
| N-22 | Chase start chance 1 in 8 (Random(8)) | Travel | TASK-013.02.04 |
| N-23 | Deputy count 2-8 (Random(7)+2) | Chase | TASK-013.02.09 |
| N-24 | Run resolution Random(10) escape threshold | Chase | TASK-013.02.09 |
| N-25 | Fight resolution weapon hit vs Random(100) | Chase | TASK-013.02.09 |
| N-26 | Stay resolution cops fire, arrest | Chase | TASK-013.02.09 |
| N-27 | Chase win reward free drugs | Chase | TASK-013.02.09 |
