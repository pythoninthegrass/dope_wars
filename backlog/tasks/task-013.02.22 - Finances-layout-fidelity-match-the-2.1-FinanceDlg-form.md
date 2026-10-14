---
id: TASK-013.02.22
title: 'Finances layout fidelity: match the 2.1 FinanceDlg form'
status: To Do
assignee:
  - '@Claude'
created_date: '2026-10-14 05:18'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.06
documentation:
  - docs/beermat-2.1-re.md
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
- [ ] #1 Cash and Bank sit in a bevelled panel as read-only value boxes with their own labels, beside the Deposit, Deposit All But.., Withdraw and Withdraw All buttons in the form's 2x2 arrangement
- [ ] #2 The loans table and Repay Loan are enclosed in a titled group box captioned with the outstanding total, and the offerings table, the debt-cap note, the borrow prompt, the spinner and Borrow are enclosed in a second group box captioned 'Loan Shark offerings:'
- [ ] #3 The dialog is laid out in two columns, with the shark-name label and the dialog's OK button in the right column; the label reads 'Loan Sharks' with no selection and the selected shark's name otherwise
- [ ] #4 The dialog's accept button is captioned OK rather than Close and is the default action
- [ ] #5 The Days Left column shows a bare day count, and no column title is clipped at the form's column widths
- [ ] #6 Double-clicking a loans row repays and double-clicking an offerings row borrows, matching the form's OnDblClick handlers
- [ ] #7 Every button in the dialog carries the hint text from the form as its tooltip
- [ ] #8 game:ui-test covers the group-box structure, the shark-name label's two states, the double-click paths and the Days Left formatting
- [ ] #9 Strings are tr() keys
<!-- AC:END -->
