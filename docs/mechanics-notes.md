# Dope Wars mechanics & strategy notes

Observations from one scripted 31-day Custom Game run against the Keymash web
version (`https://keymash.com/games/dopewars/`), played via
`chrome-devtools-axi` per `docs/playthrough.md`. Screenshots for each
numbered point are in the gitignored `screenshots/` directory (not checked
in). Goal was to document mechanics/strategy, not optimize for score — final
result: **$17,748 net worth** (cash + bank) starting from $2,000 cash /
$5,500 debt, with 0 guns and never fighting.

This build differs from the classic DOS Dope Wars in a few ways worth
noting up front: there's no Standard/Custom mode picker — it launches
straight into a classic-ruleset game (Day 1/31, $2,000 cash, $5,500 debt).
No leaderboard UI was visible in this build at all.

## Core loop

1. Click a drug row in the **Available drugs** table (left) to select it —
   enables **Buy**.
2. Click a drug row in the **Trenchcoat** table (right, your held inventory)
   to select it — enables **Sell**. Buy/Sell selection are independent; you
   must click in the correct table for the button you want.
3. A Buy/Sell dialog opens with a spinbutton quantity, defaulting to the max
   you can afford / max you hold. Confirm or adjust.
4. Click a borough button to travel — this is the **only** way to advance
   the day counter. There's no "wait here" option.

## Per-location drug rosters differ

Each borough trades only a **subset** of the ~11 total drugs (Acid, Cocaine,
Crack, Ecstasy, Hashish, Heroin, Opium, Peyote, Shrooms, Smack, Speed, Weed)
— never all of them at once. A drug you're holding that isn't in the
current location's **Available drugs** list cannot be bought *or sold*
there — selecting it in the trenchcoat table leaves Sell disabled. Plan
routes around where your held drug is actually tradeable, not just where
prices look good.

## Price volatility & events

- Baseline day-to-day price swings for the same drug across boroughs are
  large — Speed ranged from $50 to $441 across the run, a >8x spread.
- **"Addicts are buying `<drug>` at outrageous prices!"** — spikes that
  drug's *local* price dramatically (observed Cocaine at 3x-20x normal, and
  once Speed at $441 vs. a $65-80 baseline — sell into these immediately if
  you're holding).
- **"Cops made a big `<drug>` bust! Prices are outrageous!"** — same effect,
  different flavor text; one instance pushed Cocaine to $49,714 (vs. a
  ~$16-20k baseline elsewhere).
- **"Market is flooded with `<drug>`."** — the inverse: crashes that drug's
  local price (observed Speed at $50, a good buy signal). No observed
  "outrageous"/"flooded" pair for the same drug in the same run, but they
  read as opposite ends of one mechanic.
- Multiple events can chain on a single travel (e.g., a price-spike toast +
  a mugging + a cop chase all fired off one border crossing).
- Attempting to buy a drug you can't afford even 1 unit of doesn't open the
  quantity dialog — it shows a flavor-text refusal ("Duh! Check the price of
  Peyote, dude!") instead.

## Free-drug and money events (pure upside)

Random "You found N units of X on a dead dude in the subway!" or "You meet
a friend! He lays N units of X on you!" events hand you free inventory at
$0 cost basis — pure profit the moment you can sell it. One instance handed
4 units of Ecstasy that immediately sold for $1,960/unit (~$7,840 free).
Always worth a special mental note to sell these ASAP since there's no
capital at risk.

## Negative random events

- **Mugged on the Subway** — flat cash loss (observed $9-$47), no health
  impact, no choice offered.
- **Cop Chase** — a mini-encounter with **Run / Stay / Fight** choices.
  **Fight is disabled with 0 guns.** Run can fail on a given round ("They're
  firing on you, man! You've been hit!" — costs ~5% health) before
  eventually succeeding ("You lost them in the alleys."). Treat it as a
  multi-round skill check, not a single roll — keep clicking Run. The
  deputy count scales up over the game (observed 1 deputy early, 9 deputies
  by day ~22) but didn't visibly change outcome odds in this run.
- Pure flavor-text danger cues with no mechanical effect were also observed
  ("Police dogs chased you for 2 blocks.").

## Dealer offers (opt-in purchases)

- **Coat Dealer** — offers +N trenchcoat pockets (capacity) for a price;
  Buy/Decline. Price and pocket count vary per offer.
- **Gun Dealer** — offers a gun for a flat price; Buy/Decline. Never bought
  one this run (cash-constrained each time it appeared), so combat-with-guns
  behavior is undocumented here.
- Both are declinable with no penalty; they don't force a decision.

## Debt & interest

- Debt starts at $5,500 (classic ruleset) against $2,000 starting cash —
  you start underwater.
- **Interest compounds on every travel, not every day-equivalent** — roughly
  10% growth per border crossing on outstanding debt. Left untouched for a
  stretch, debt visibly snowballed (e.g., $5,500 → $8,303 over ~8 travels
  with only prices/events in between).
- Bank balance separately earns ~2% per travel and is **immune to
  muggings/debt seizure** (per in-game Finances help text) — deposit cash
  you're not actively trading with.
- Paying debt down aggressively whenever cash is flush is clearly worth it:
  once cleared entirely (day ~20 this run), the compounding drag disappears
  and net worth accelerates.
- Finances dialog: Deposit / Withdraw / Pay Loan, each opens a spinbutton
  pre-filled to the max sane value (all cash for deposit/pay-loan, full
  balance for withdraw).

## Trenchcoat capacity

Starts at 100 units and is a hard cap on total units carried across *all*
drugs combined, not per-drug. Coat Dealer offers are the only observed way
to raise it. Watch the "Trenchcoat Space: X/100" readout before committing
to a large buy.

## Endgame

- On Day 31, the travel buttons are replaced by a single **Finish** button.
  A one-time reminder fires on entering the last day: "This is your last
  day, man. Maybe you should offload your stash." — confirms **unsold
  inventory does not count toward the final score**, only cash + bank.
  Liquidate everything before hitting Finish.
- Clicking Finish shows a "Custom Game Complete" summary with the final
  score (cash + bank) and an explicit note that custom games are never
  posted to any leaderboard.

## Strategy takeaways for a Godot reference implementation

1. **A single reliably-available commodity (Speed here) as a workhorse**:
   cheap, present at most locations, and its baseline volatility alone
   (roughly $50–$240 swings even without special events) is enough to fund
   steady profit on a simple "buy low here, sell high next stop" loop.
2. **React to event toasts as strong buy/sell signals** — "outrageous
   prices" = sell now if holding that drug (or a rare buy-into-a-dip if it's
   actually the "flooded" crash variant); free-drug finds = sell on sight.
3. **Debt is a ticking clock** — the interest-per-travel model means early,
   opportunistic paydowns compound in your favor just as much as ignoring it
   compounds against you. Treat "any spare cash" as fungible between
   trading capital and debt paydown, not just the latter.
4. **Bank cash you're not actively about to spend** — it's both safer
   (mugging-proof) and earns passive interest, at the cost of not being
   liquid for the next Buy dialog.
5. **Per-location drug rosters mean route planning matters** — carrying a
   drug through a city that doesn't trade it is dead weight until you reach
   a location that does; check the Available Drugs list before committing to
   a large single-drug position.
6. **Liquidate before the last day** — there is no inventory-value credit at
   game end.
