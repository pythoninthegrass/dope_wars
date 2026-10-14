---
id: TASK-013.02.22
title: 'Finances layout fidelity: match the 2.1 FinanceDlg form'
status: Done
assignee:
  - '@Claude'
created_date: '2026-10-14 05:18'
updated_date: '2026-10-14 07:02'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.06
documentation:
  - docs/beermat-2.1-re.md
modified_files:
  - game/presentation/dialogs/finances_dialog.gd
  - game/presentation/dialogs/dope_dialog.gd
  - game/presentation/main.gd
  - game/content/copy.gd
  - game/translations/strings.csv
  - game/godot_tests/ui_flow_test.gd
parent_task_id: TASK-013.02
ordinal: 82000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Finances dialog's behaviour matches 2.1 (TASK-013.02.06) but its layout does not. The oracle's form is extracted verbatim at `vendor/dopewars-2001/re/forms/FinanceDlg.dfm` (564x446 client, two columns at x=4..356 and x=362..562); the port renders a single 540px column of bare labels and tables.

Rebuild `game/presentation/dialogs/finances_dialog.gd` against that form. The shark portrait, which 2.1 paints in `FormPaint` from EXE resources, is out of scope: nothing is extracted into `vendor/` yet and it raises a separate asset question. The right column should still exist, carrying the shark-name label and the OK button.

Confirmed against the live 2.1 container: the Cash and Bank boxes are focusable and select their text but reject typing, so they are read-only displays and Deposit still opens its own "How much?" prompt. The port's QuantityDialog model is correct and must not change.

Not a defect: the untranslated `FIN_*` / `BTN_*` keys seen in local screenshots were a stale Godot translation import, fixed by re-running `task game:import`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Cash and Bank sit in a bevelled panel as read-only value boxes with their own labels, beside the Deposit, Deposit All But.., Withdraw and Withdraw All buttons in the form's 2x2 arrangement
- [x] #2 The loans table and Repay Loan are enclosed in a titled group box captioned with the outstanding total, and the offerings table, the debt-cap note, the borrow prompt, the spinner and Borrow are enclosed in a second group box captioned 'Loan Shark offerings:'
- [x] #3 The dialog is laid out in two columns, with the shark-name label and the dialog's OK button in the right column; the label reads 'Loan Sharks' with no selection and the selected shark's name otherwise
- [x] #4 The dialog's accept button is captioned OK rather than Close and is the default action
- [x] #5 The Days Left column shows a bare day count, and no column title is clipped at the form's column widths
- [x] #6 Double-clicking a loans row repays and double-clicking an offerings row borrows, matching the form's OnDblClick handlers
- [x] #7 Every button in the dialog carries the hint text from the form as its tooltip
- [x] #8 game:ui-test covers the group-box structure, the shark-name label's two states, the double-click paths and the Days Left formatting
- [x] #9 Strings are tr() keys
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read `vendor/dopewars-2001/re/forms/FinanceDlg.dfm` for the geometry, captions, hints and event handlers.
2. Add the failing `finances_layout` ui-test case first: money panel, group boxes, right column, OK default, tooltips, bare Days Left, unclipped column titles, double-click borrow and repay.
3. Rebuild `finances_dialog.gd` around a two-column HBox: a bevelled MoneyPanel with a 4-column grid, two captioned group boxes on the left, the shark-name label and OK on the right.
4. Add the form's hints and the 'Loan Sharks' caption as tr() keys; rename the accept button finClose -> finOk and follow it in `main.gd`.
5. Re-run `task game:import` so the new keys land in the compiled translation, then `game:ui-test`, `game:boundary-check` and `game:smoke-test`.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Delphi's `TListView` column widths are carried over as `LOAN_COLUMNS` / `OFFER_COLUMNS`, widened per column when the port's bold table font needs more room than the form's did -- a clipped heading is worse than a wide column.

`add_button()` makes the first button added the dialog's default, so the right column is filled before the left one; the form's `Default = True` is on OK.

The new keys only render once `task game:import` recompiles `strings.en.translation`; the stale import is what produced the untranslated `FIN_*` keys noted in the description. The generated file is gitignored, so it had to be deleted to defeat the import task's `status:` check.

`Copy.loan_days()` is now unused by the game -- the Days Left column is a bare count -- but is left in place with its own assertions rather than deleted.

Follow-up at Lance's call: the Deposit All But.. hint reads "Deposit all your cash" rather than reproducing the form's own "all you cash" typo, and the code the rebuild stranded is gone -- `Copy.loan_days()` with its five `MSG_LOAN_*` keys, and `FIN_DEBT`, which the LED strip never used. The `units_at` doc comment that had drifted above `loan_days` moved back onto `units_at`.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Rebuilt the Finances dialog against the oracle's extracted form (`vendor/dopewars-2001/re/forms/FinanceDlg.dfm`).

**Layout** - the dialog is now two columns. The left carries a bevelled money panel whose 4-column grid holds read-only Cash and Bank boxes with their labels beside Deposit / Deposit All But.. and Withdraw / Withdraw All in the form's 2x2 arrangement, then a group box captioned with the outstanding total around the loans table and Repay Loan, then a second captioned "Loan Shark offerings:" around the offerings table, the debt-cap note and the borrow row. The right column carries the shark-name label (reading "Loan Sharks" with no selection and the selected shark otherwise) over the dialog's OK button. The shark portrait 2.1 paints from EXE resources is out of scope, as the task states.

**Behaviour** - unchanged except where the form dictates: the accept button is captioned OK, is the default action and is keyed `finOk` (was `finClose`); double-clicking a loans row repays and double-clicking an offerings row borrows, matching the form's `OnDblClick` handlers; the Days Left column is a bare day count; every button carries the form's hint as its tooltip. Deposit and Withdraw still open a QuantityDialog, matching the oracle's "How much?" prompt.

**Columns** - the lists use the form's column widths, widened per column when the port's bold table font needs more room for the heading.

**Tests** - a new `finances_layout` ui-test case (48 assertions) covers the group-box structure, the shark-name label's two states, the double-click paths, the tooltips, the bare Days Left formatting and that no column title is clipped. `task game:ui-test` passes at 834 assertions; `game:boundary-check` and `game:smoke-test` pass.

**Note** - the Deposit All But.. tooltip reproduces the form's own typo ("Deposit all you cash"), as a fidelity target.

**Follow-up** - the Deposit All But.. hint corrects the form's "all you cash" typo to "all your cash". `Copy.loan_days()` and its five `MSG_LOAN_*` keys, stranded by the bare Days Left column, are removed along with the long-unused `FIN_DEBT` key; `game:ui-test` passes at 820 assertions.
<!-- SECTION:FINAL_SUMMARY:END -->
