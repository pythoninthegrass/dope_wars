# Beermat Dope Wars 2.1 analysis

What can and cannot be learned from Beermat Software's "Dope Wars for Windows" 2.1.0.0 (2001), `vendor/dopewars-2001/dw21.exe` (gitignored along with the rest of `vendor/dopewars-2001/`). The release history it is compared against is `vendor/CHANGELOG.md`. This document does not replace `docs/beermat-re.md`, which is read from the 1.2.0 binary; it records how far that document carries over to 2.1. No numeric 2.1 rule is established yet: everything below is read from the installer's payload and the game's form resources, which carry captions and layout but no constants.

## Installer layout

`dw21.exe` is a Wise installer: a small PE32 stub followed by raw-deflate streams (no zip, 7z or NSIS container, so `7z l` rejects it). Each stream is trailed by its little-endian CRC32, and one stream is the Wise script, whose install-file records give each file's path, stream extent and size. `task re:unwise` (`tools/re/unwise.py`) finds the streams, pairs them with the script's records and writes only the game files, leaving the Gator stub and the installer's helper executables in memory. The relevant contents:

| Item | Notes |
| --- | --- |
| `DopeWars.exe` | The game, 1.48 MB, PE32, Delphi, protected by PC Guard (next section). It is the stream at file offset `0xe0acd`. |
| `cities.txt` | 11 world cities, each with a country, 6 sub-locations, a transit name and an airport. The location model is not a fidelity target (`docs/parity-deltas.md` section 5), and airport flights are skipped for 2.1 as well. |
| `oldlady.txt` | The Old Lady phrase list. |
| `Sounds/*.wav` | 38 wavs, a larger set than the ten cues in 1.2 (weapon fire and hit per weapon, jail door, chainsaw, window, hospital, store, borrow, warnings, headlines and more). |
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
| Sound cues | Replaced, 38 wavs instead of 10. |
| New Game gated until day 6 (M-11) | Still gated, one day earlier: unlocks on day 5. An intentional delta for the port. |

### New Game gate (intentional delta)

`TDWForm_EnableNewGameButton` (`0x004b7f48`) disables the New Game button and the File > New menu item while the day counter at `DAT_004e20e0` is 4 or below, so a restart is only possible from day 5. This mirrors 1.2's lockout (M-11 in `docs/beermat-re.md`, which unlocked on day 6) but one day earlier. The Godot port does not gate New Game — it is available on every day, including day 1. This is recorded as an intentional delta in `docs/parity-deltas.md` section 6, not as a rule the port is missing.

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

- The 2.1 sound table is not in the exe as 1.2's records are. The image holds only the `DW*` event names, and the wav paths live in the registry entries the installer writes, which the Wise script lists. The extractor therefore joins `appevents.tsv` (event to wav and label, from the Wise script) with the event names in the dump, matching case-insensitively. The six `DW<Weapon>Hit` events (`DWHandBagHit`, `DWPeaShooterHit` and so on) have no string of their own, because the game builds them at run time from the weapon event name and the three-character suffix, which is below the string scan's 4-character minimum.
- `IntroDlg` and `NMShow` are form resources with no class in the image (no VMT, and no class-name string outside the resource). Their handlers (`FormActivate`, `Label8Click`, `Button1Click` to `Button5Click`) have no code, so the extractor warns about them and does not count them as unresolved.

Ghidra needed two changes for the dump. `DiscoverFunctions.java` looked up a block named `CODE`, and now falls back to the first executable block, which is `.PCGW32` in a dump. `ApplyLabels.java` now clears an instruction that straddles a labeled entry: the string and padding before a function had been disassembled as code and blocked three handlers, among them `TCityEditor_FormShow`.

Handling notes for the bottle:

- Shut the bottle down with `WINEPREFIX=<bottle> wineserver -k` followed by `wineserver -w`. A kill -9 of the wineserver loses unflushed registry writes, and every wine command needs an explicit `WINEPREFIX` or it can act on another bottle's server.
- Do not trace. `WINEDEBUG=+reg` made PC Guard hit a privileged instruction and crash under winedbg. Leftover wine processes from a previous run caused the same crash once, so clean up first.
- Fallbacks if pe-sieve fails, in order: a `winedbg` minidump, then the Windows oracle described in `CLAUDE.local.md`. Neither was needed.

Next: re-check every row of the table above against the decompiled functions and record the 2.1 virtual addresses and constants here (TASK-013.01.04).
