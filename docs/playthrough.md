# Playing Dope Wars with chrome-devtools-axi

How to drive a full 31-day run of Keymash's [Dope Wars](https://keymash.com/games/dopewars/)
through the `chrome-devtools-axi` browser automation CLI.

## Play Custom Game only — never Standard

The in-game help text is explicit:

> **Fair Play** — The leaderboard is for players, not bots. Submissions that
> look automated ... will be removed without warning and the source may be
> banned from submitting. **Custom-mode runs are local-only and never touch
> the leaderboard.**

`chrome-devtools-axi` runs are scripted by construction, so **only ever start
a run from "Custom Game (unranked)…"**. Never automate "Start Standard Game" —
that mode posts to the ranked/seasonal leaderboard and is exactly what the
fair-play policy is warning against. A Custom Game run is local-only and safe
to script.

## Setup

```bash
npx -y chrome-devtools-axi open "https://keymash.com/games/dopewars/"
npx -y chrome-devtools-axi snapshot
```

`snapshot` prints an accessibility tree with `uid=...` refs for every element.
Refs are stable only within one snapshot generation — if a click errors with
`STALE_REF`, just re-run `snapshot` and use the fresh uid.

1. Click **"Custom Game (unranked)…"** (not "Start Standard Game").
2. The Custom Game dialog defaults to `Number of Days = 31`, `Starting Cash =
   $2,000` — that's the classic ruleset, so no changes are needed unless you
   want a different length.
3. Click **"Start Game"**.

## The game screen

Each day/location screen exposes:

- **Status row** — Cash, Bank, Debt, Guns, Health (all plain `StaticText`,
  read them off the snapshot to track progress).
- **Price table** — one row per drug (Acid, Crack, Ecstasy, Hashish, Peyote,
  Shrooms, Smack, Speed, Weed) with today's price at this location.
- **Travel buttons** — six boroughs (Bronx, Manhattan, Ghetto, Coney Island,
  Central Park, Brooklyn). Clicking one travels there **and advances the day
  counter** ("Dope Wars, Day N of 31"). You can't stay in place to pass a day;
  travel is the only clock advance.
- **Buy / Sell buttons** — disabled until a drug row is selected.
- **Finances** button — opens Deposit / Withdraw / Pay Loan against Cash,
  Bank, Debt.

## Trading loop

1. Click a drug name (e.g. `Acid`) in the price table to select it — this
   enables the **Buy**/**Sell** buttons.
2. Click **Buy** (or **Sell**, if you're holding that drug). A dialog opens:
   *"You can afford N units of X, and have room in your coat for M units."*
   with a `spinbutton` quantity field.
3. Use `fill` on the spinbutton ref to set a quantity, then click **OK** (or
   **Cancel** to back out).
4. Repeat for other drugs, then click a borough button to travel — this
   advances to the next day and re-rolls prices at the new location.

Trenchcoat capacity (shown as "Trenchcoat Space: X/100") caps total units
carried across all drugs — check it before buying more.

## Managing money

Click **Finances** to open Cash/Bank/Debt. Each *travel* (not each day)
charges 10% interest on Debt and pays 2% interest on Bank balance per the
help text, so paying down debt or banking cash before a travel matters more
than doing it mid-location.

- **Deposit** — move Cash → Bank (protects it from debt seizure on capture).
- **Withdraw** — move Bank → Cash.
- **Pay Loan** — pay down Debt from Cash.

## A scripted loop, in outline

```bash
# 1. open + start Custom Game (unranked), leave Days=31 default
npx -y chrome-devtools-axi open "https://keymash.com/games/dopewars/"
npx -y chrome-devtools-axi snapshot
npx -y chrome-devtools-axi click @<uid of "Custom Game (unranked)…">
npx -y chrome-devtools-axi click @<uid of "Start Game">

# 2. loop for 31 days
#    - snapshot to read current prices + refs
#    - pick a cheap drug relative to its historical range, click its row, Buy
#    - click a borough to travel (advances the day)
#    - repeat; sell into high prices at later stops
#    - occasionally open Finances to pay down Debt / bank surplus Cash
```

Because refs regenerate every snapshot, don't try to script far ahead from a
stale snapshot — `snapshot` → act → `snapshot` → act is the reliable cadence.

## Ending the run

The game ends automatically after day 31 (or earlier if you die/get caught).
Since this is a Custom Game, the result is **local-only** — nothing is
submitted anywhere, so there's no leaderboard step to worry about.
