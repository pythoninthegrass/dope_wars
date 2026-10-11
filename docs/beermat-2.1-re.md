# Beermat Dope Wars 2.1 analysis

What can and cannot be learned from Beermat Software's "Dope Wars for Windows" 2.1.0.0 (2001), `vendor/dopewars-2001/dw21.exe` (gitignored along with the rest of `vendor/dopewars-2001/`). The release history it is compared against is `vendor/CHANGELOG.md`. This document does not replace `docs/beermat-re.md`, which is read from the 1.2.0 binary; it records how far that document carries over to 2.1. No numeric 2.1 rule is established yet: everything below is read from the installer's payload and the game's form resources, which carry captions and layout but no constants.

## Installer layout

`dw21.exe` is a Wise installer: a small PE32 stub followed by raw-deflate streams (no zip, 7z or NSIS container, so `7z l` rejects it). The streams were located by scanning for deflate data in memory; nothing was written to disk. The relevant contents:

| Item | Notes |
| --- | --- |
| `DopeWars.exe` | The game, 1.48 MB, PE32, Delphi, protected by PC Guard (next section). It is the stream at file offset `0xe0acd`. |
| `cities.txt` | 11 world cities, each with a country, 6 sub-locations, a transit name and an airport. The location model is not a fidelity target (`docs/parity-deltas.md` section 5), and airport flights are skipped for 2.1 as well. |
| `oldlady.txt` | The Old Lady phrase list. |
| `Sounds/*.wav` | 39 wavs, a larger set than the ten cues in 1.2 (weapon fire and hit per weapon, jail door, chainsaw, window, hospital, store, borrow, warnings, headlines and more). |
| Gator adware stub | `Trickler_PIC_Beermat_Dopewars.exe`. Never run it, and never extract it. |

## PC Guard

Every code and data section of the inner `DopeWars.exe` is named `.PCGW32` and has entropy near 8.0, and the file carries the string `PC Guard for Win32 (c) 1998/2001`. The code is encrypted on disk and decrypted at run time. Consequences:

- `task re:decompile` and `task re:disasm` produce nothing useful on the shipped file.
- The Delphi VMT and method map that `tools/re/extract_beermat.py` builds cannot be recovered statically.
- None of the virtual addresses in `docs/beermat-re.md` apply to 2.1. It is a different build, and the code has moved.
- Registering does not change this. Entering the license key only unlocks the registered-only features at run time, so the way through is a dump of the decrypted process (see "Unpack approach").

## What the resources show

The resource section is not encrypted, and all 25 Delphi forms decode: AboutDlg, AirportDlg, AmountDlg, BuyDlg, ChartForm, CityDetail, CityEditor, CopChaseDlg, DisclaimerDlg, DWForm, EndGameForm, FinanceDlg, GameTypeForm, HospitalDlg, IntroDlg, LoanSharkDlg, NMShow, OldLadyDlg, OptionsDlg, PromptDlg, ProxyForm, StatsForm, StoreDlg, ViewHiScoreDlg and WhyRegisterDlg.

| Feature | Evidence in the forms | Changelog |
| --- | --- | --- |
| Loan sharks | FinanceDlg lists lenders with rate, duration and amount, a borrow button, an outstanding loans list with days left and a repay button, and the note "maximum TOTAL debt cannot exceed 1,000,000". LoanSharkDlg shows "Visit 1 of 1", due date, "Your loan is 2 days past due", Pay Now and Pay Later, and the health of the person being visited. | 2.0 (loan sharks), 2.1 (released from jail in random order) |
| Hospital | HospitalDlg: "$300 per HEALTH POINT" and a quantity box. | 2.0 |
| Super Store | StoreDlg: weapons list, ammo list, shopping basket, cash remaining, remove, checkout. | 2.0 |
| Weapons | The weapon rack on the main form and the statistics form name Handbag, Pea Shooter, Water Pistol, Monkey, Catapult and Chicken; the main form's sample line also shows Stick, Beretta, Colt-45, Shotgun, Uzi-9mm and Bazooka. The 2.1 changelog says the real weapons were replaced. Which set the shipped build uses is unresolved. | 2.1 |
| Cop chase | CopChaseDlg actions: stay, run, fight with a selectable weapon, and "Dump the drugs in your trenchcoat". Its sample caption shows 22 deputies, where 1.2 allowed at most 11. | 2.0, 2.1 |
| Health | A health bar, a kidney indicator, and a status line "Health: 100%, infected, dialysis (2 kidneys)". EndGameForm: "Your infection got the better of you. You're dead." | 2.1 (doctor, dialysis, infection) |
| Old Lady | OldLadyDlg, "An old lady on the aeroplane says:", with an option to mute her. | 2.1 (can say your name) |
| Game length | GameTypeForm offers 15, 30, 60 and 90 days; only 30 is available unregistered. | 2.0 |
| Price History | ChartForm, a per-drug chart with a 3D view, and price direction arrows on the drug list. Registered only. | 2.0 |
| Statistics | StatsForm: cops faced, cops scared, possession arrests, assault arrests, chases, loans (borrowed, repaid, interest, owed), per-weapon counts, a day-end financial history chart. | 2.1 |
| Finances | FinanceDlg has "Deposit All But..", with the amount withheld set in OptionsDlg (up to 1,000,000). | 2.1 (redesigned) |
| Airport | AirportDlg and a "John F. Kennedy Airport" button. | 2.0 |

Out of scope for the port: registration and license keys, online scores and cartels, update checks, proxy settings, the city editor, skins, the LCD font and anti-cheat.

## Does the 1.2.0 reverse engineering hold?

Not established. Only the start state is confirmed, and only by text: IntroDlg still says $2,000 cash and $5,500 debt. Everything else is open until the process is dumped.

| 1.2 rule (`beermat-re.md`) | Status for 2.1 |
| --- | --- |
| Start cash 2000, debt 5500 | Holds, per the intro text. |
| Single debt compounding at 10% per day | Unverified, and likely replaced: 2.0 added loan sharks with their own rates and durations. |
| Bank interest 5% per day | Unverified. The changelog has the cut to 3% in 2.2, which implies 5% in 2.1. |
| Drug table, price ranges, spike and crash | Unverified. 2.0 made pricing "flatter and more varied". |
| Drug availability 1 in 8 absent | Unverified. |
| Chase start 1 in 6, deputies 2 to 11, run 50%, fight 50% | Unverified, and likely changed (more deputies, weapon choice, scared cops). |
| Dealer visits, coat and gun dealers | Gun dealer likely replaced by the Super Store. |
| Arrival event table (find, mugging, friend, police dogs) | Unverified. 2.1 adds the doctor, dialysis machine and infection events. |
| Win reward and doctor offer after a chase | Unverified, and likely replaced by the hospital. |
| Score `cash + bank - debt` | Unverified, now with several loans. |
| 31-day game | Replaced by 15, 30, 60 and 90 days. |
| Sound cues | Replaced, 39 wavs instead of 10. |

## Unpack approach

1. Extract the inner `DopeWars.exe`, `cities.txt`, `oldlady.txt` and the wavs from the Wise payload into gitignored `vendor/dopewars-2001/game/` (TASK-013.01.01). The installer itself is not run.
2. Run the extracted game in a dedicated 32-bit CrossOver bottle, enter the license key, and check that the registered-only features unlock (TASK-013.01.03).
3. Dump the running process once PC Guard has decrypted it, rebuild its import table, and point the existing Ghidra pipeline at the dump (TASK-013.01.03). The first fallback is a `winedbg` minidump, the second is the Windows oracle described in `CLAUDE.local.md`.
4. Re-check every row of the table above and record the 2.1 virtual addresses and constants in this document (TASK-013.01.04).
