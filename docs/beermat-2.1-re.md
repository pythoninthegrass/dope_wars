# Beermat Dope Wars 2.1 analysis

What can and cannot be learned from Beermat Software's "Dope Wars for Windows" 2.1.0.0 (2001), `vendor/dopewars-2001/dw21.exe` (gitignored along with the rest of `vendor/dopewars-2001/`). The release history it is compared against is `vendor/CHANGELOG.md`. This document does not replace `docs/beermat-re.md`, which is read from the 1.2.0 binary; it records how far that document carries over to 2.1. Every rule below is read from a dump of the decrypted process, with a virtual address; the resource-only table in the older version of this document has been replaced. `docs/beermat-re.md` is the 1.2 source of truth and still governs the port wherever 2.1 differs.

Classifications compare each rule with the engine (`index.html`, `<script id="engine">`) and the Mojo core (`core/src/*.mojo`), which replay the engine seed for seed and are cited together as "the engine". Values:

- **match**: same rule and same constants.
- **mismatch**: the engine differs from Beermat. Each mismatch has an ID (`N-01`...) that a follow-up subtask will carry.
- **intentional**: a deliberate difference recorded in `docs/parity-deltas.md`.

## How to read the decompile

- Delphi uses the register calling convention: `EAX` is `Self`, `EDX` and `ECX` are the next two arguments, the rest go on the stack. Ghidra names these `param_1`, `param_2`, ...
- `FUN_00402b7c` (`0x00402b7c`) is `System.Random(n)`: `seed = seed * 0x8088405 + 1; return (n * seed) >> 32`, so it returns a uniform integer in `[0, n)`. `FUN_00402958` (`0x00402958`) is `Randomize`: the seed becomes milliseconds since midnight from `GetSystemTime`. It runs at startup and again at the start of every post-travel event roll, so Beermat's randomness is wall-clock seeded and not reproducible.
- `0x004c2c90` is `TComponent.FindComponent` / string compare helper used throughout as the field reader; in the decompile it appears as `FUN_004c2c90(param, address)` and reads the 32-bit value stored at `address`.
- Game state lives in globals. The Pascal pointer cells in `.data` (for example `PTR_DAT_004d2608`) point at objects; their fields are at fixed offsets (for example `+0x2d0` is the cop-chase deputy count, `+0x38` is the "fighting" flag).

| Global | Meaning | Evidence |
| --- | --- | --- |
| `DAT_004d3044` | RNG seed | written by `Randomize` (`0x00402958`), consumed by `Random` (`0x00402b7c`) |
| `DAT_004e20b8` | cash | `AddHighScore` (`0x004c3230`) reads it for the score |
| `DAT_004e20c4` | bank | compounds daily |
| `DAT_004e20c8` | debt | compounds daily |
| `DAT_004e20e0` | day, 1-based | incremented in `LoseDay` (`0x004bdb8c`) |
| `DAT_004e20e4` | coat capacity | new game sets 200 |
| `DAT_004e20e8` | coat used (sum of drug units) | recomputed by price gen |
| `DAT_004e20f0` | day limit (15/30/60/90) | new game sets it |
| `DAT_004e20f8` | health | 0 ends the game |
| `DAT_004de45c` | drug records, 13 x 0xd7 bytes | built by `0x004b7fe0` |

## Drug table and price generation

`0x004b7fe0` builds the game's tables at new game. It calls `FUN_004bbc04` 13 times (drug indices 0-12), `FUN_004bbe4c` 5 times (loan-shark names), and `FUN_004bbd34` 6 times (joke weapons). Each drug record is 0xd7 (215) bytes at `DAT_004de45c + index*0xd7`; the fields the price code reads are the name pointer at +0, the plural name at +4, the singular name at +8, the min price at +0xc, and the spread at +0x10. The price is `min + Random(spread + 1)`, re-rolled for all 13 drugs on every arrival and at new game.

The record builder `FUN_004bbc04` is called as `FUN_004bbc04(Self, index, namePtr, fieldA, fieldB, maxPtr, minPtr, singular, plural)`. Mapping the arguments for each drug gives min and spread:

| Index | Drug | min | spread | max | Crash (div 10) | Spike (x5) | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | Acid | 1000 | 3500 | 4500 | yes | no | matches 1.2 |
| 1 | Cocaine | 15000 | 15000 | 30000 | no | yes | matches 1.2 |
| 2 | Hashish | 450 | 900 | 1350 | yes | no | matches 1.2 |
| 3 | Heroin | 5000 | 9000 | 14000 | no | yes | matches 1.2 |
| 4 | Ecstasy | 10 | 50 | 60 | yes | no | matches 1.2 |
| 5 | MDA | 1500 | 3000 | 4500 | no | yes | replaces Smack; same range |
| 6 | Opium | 500 | 800 | 1300 | no | yes | matches 1.2 |
| 7 | Crack | 1000 | 2500 | 3500 | yes | no | gained crash flag in 2.1 |
| 8 | Peyote | 200 | 500 | 700 | yes | no | gained crash flag in 2.1 |
| 9 | Mushrooms | 600 | 750 | 1350 | yes | no | replaces Shrooms; same max; gained crash flag in 2.1 |
| 10 | Speed | 70 | 180 | 250 | no | yes | matches 1.2 |
| 11 | Weed | 300 | 600 | 900 | yes | no | matches 1.2 |
| 12 | Special K | 450 | 1000 | 1450 | no | yes | new in 2.1 |

The crash flag is the byte at record offset +0x18 (the `param_4` argument to the builder): `2000` means crash, `11` means spike. The crash messages, indexed by the drug-record position at `0x004b7fe0` (acid 0, hashish 2, ecstasy 4, crack 7, weed 11); the other drugs have no crash flag. Peyote (8) and Mushrooms (9) are crash-flagged but have no crash message, so they crash silently:

| Drug | Crash message |
| --- | --- |
| Acid | "The market has been flooded with cheap home-made acid!" |
| Hashish | "The Marrakesh Express has arrived!" |
| Ecstasy | "Rival dealers raided a pharmacy and are selling cheap ecstasy!" |
| Crack | "Criminals have raided police stores and stolen tons of crack!" |
| Weed | "Columbian ship dusted by Coast Guard! Weed prices have bottomed out!" |

The spike messages are built at run time from two halves: a prefix (`"Cops made a big"`, `"Addicts are buying"`, `"The market has been flooded with cheap home-made"`, `"Rival dealers raided a pharmacy and are selling cheap"`) and a suffix (`"<drug> bust! Prices are outrageous!"`, `"<drug> at outrageous prices!"`). The exact per-drug pairing is not yet decoded from the builder; the crash messages are the strings at `0x004b7030`-`0x004b7204`.

Names are the strings at `0x004b88f0`-`0x004b8c30`. Two drugs were renamed between 1.2 and 2.1: Smack (1500-4500) became MDA (same range, index 5) and Shrooms (600-1350) became Mushrooms (same max, index 9). Special K (index 12) is new. Crack, Peyote, Mushrooms and Weed gained crash flags in 2.1; the four spike drugs (Cocaine, Heroin, Opium, Speed) keep theirs.

## Travel, chase start and the day loop

`0x004bc9d4` is the common handler behind all six location buttons (`0x004c168c`-`0x004c177c`, argument 1-6) and the Finish button (`0x004c35f0`, argument 7). Order of operations on a travel:

1. `day += 1` (the day counter is `DAT_004e20e0`, incremented in `LoseDay`).
2. `ProcessLoanSharks` (`0x004bcfe8`): process any due loans before the arrival sequence.
3. Price generation (`0x004bbfc4`), which also rolls the new prices and their availability and spike/crash draws.
4. Interest: bank (`0x004bfbe0`) then debt.
5. Day-end health checks (`0x004bc790`): debt above the loan cap, health from the dialysis machine, and death from zero health or unpaid loans.
6. New Game unlocks when the day is above 4 (see "New Game gate").
7. Last day (`0x004bce80`) when the day counter reaches the limit.

Chase start is `Random(0x4bcde0 = 8) == 0` (`0x004bc9d4` line ~129 tests the day counter against `DAT_004e20f0`); the two are exclusive — a chase suppresses the arrival events and dealers.

| Rule | VA | Beermat | Engine | Class |
| --- | --- | --- | --- | --- |
| Game length | `0x004c2a0c`-`0x004c2a44` | 15, 30, 60 or 90 days, chosen at new game; `DAT_004e20f0` holds the limit | `numDays` | changed, N-01 |
| Start state | new game | cash 2000, debt 5500, bank 0, health 100, coat 200 | `startCash`, `startDebt`, `startHealth`, `startCoatCapacity` | match (start cash/debt confirmed by IntroDlg text) |
| Chase start chance | `0x004bc9d4` | `Random(8) == 0`, 1 in 8, the same at every location | `randInt(0, 5) === 0` | mismatch, N-22 |
| New Game gate | `0x004bc9d4` | New Game disabled until day > 4, so usable from day 5 | New Game available any time | intentional, `docs/parity-deltas.md` section 6 |

The chase start chance is a mismatch: 2.1 draws `Random(8)` (1 in 8) where the engine draws `randInt(0, 5)` (1 in 6). This is a new difference N-22.

## Arrival events and dealers

In 2.1 the arrival sequence is split differently from 1.2's two-stage dealer-then-event model. `0x004bc9d4` (the travel handler) calls the price-generation loop `0x004bbfc4`, which rolls the new market, then folds in the price spike/crash draws and the "found on a dead dude" find event; then `0x004be728` runs after every non-chase travel and rolls, in order, the loan-release check, the coat-dealer offer, the dialysis-machine offer, the infection check, the doctor event, and the Old Lady. The mugging, friend, and police-dog outcomes are the doctor handler (`0x004bf420`) and two price-loop helpers (`0x004bf134` found, `0x004bf8b4` police dog). The exact split between "dealer visit" and "arrival event" is therefore: dealer visit (coat) in `0x004be728` via `0x004bee64`; find/mugging/friend/police-dog events across `0x004bbfc4`/`0x004bf134`/`0x004bf420`/`0x004bf680`/`0x004bf8b4`.

The events read from `DAT_004dde88`-`DAT_004ddf68`, built at startup by `0x004b657c`:

| Event | VA | Text | Trigger |
| --- | --- | --- | --- |
| Loan due | `0x004ddea4` | "Your loan is due ..." | loan shark visit |
| Raid warning | `0x004dde88` | "I hear there is going to be an air raid tomorrow." | Old Lady |
| Friend | `0x004ddecc` | "You meet a friend! He gives you some" | arrival event |
| Trenchcoat | `0x004ddec8` | "Would you like to buy a trenchcoat with more pockets for" | coat dealer |
| Spike prefix | `0x004ddee0` | "Cops made a big" | spike |
| Spike suffix | `0x004ddee4` | "bust! Prices are outrageous!" | spike |
| Crash messages | `0x004ddef0`-`0x004ddf00` | see table above | crash |
| Death: wasted | `0x004ddf20` | "They wasted you man. What a drag!" | chase death |
| Death: infection | `0x004ddf24` | "Your infection got the better of you. You're dead. What a drag!" | infection death |
| Death: kidney | `0x004ddf28` | "Your kidney problems killed you. You're dead. What a drag!" | kidney death |
| Death: out of time | `0x004ddf2c` | "You ran out of time for peddling your wares!" | end of game |
| Last day | `0x004ddf60` | "This is your last day, man." | last day |

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
