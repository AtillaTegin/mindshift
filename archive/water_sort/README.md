# Water Sort / "Birləşmə Tapmacası" — archive

Taken out of the game on 2026-10-15 by the new mechanics specification v1, section 0
(`MindShift_Yeni_Mexanikalar_Detalli_Spesifikasiya_v1.md`). The code is kept, not
deleted, so it can be judged later as a product of its own (a separate decision).

The folder has a `.gdignore`: Godot does not import or compile it, it is not
exported, and nothing in the game refers to it.

## Contents

- `core/rules/combination_rule.gd`: `CombinationRule` ("combination"). Water Sort's
  rule: a disk only onto an empty peg or its own colour, capacity per peg; the
  same-colour run at the top is poured as far as it fits and counts as one move.
- `core/combination_solver.gd`: `CombinationSolver` (BFS up to 10 disks, weighted A*
  beyond, `shorten`).
- `core/color_goal.gd`: `ColorGoal` ("Sadə Yığım": every colour on a peg of its own).
- `scripts/disk_symbols.gd`: `DiskSymbols`, the domino pips of the ten colours.
- `tools/combination_e_min.gd`: the E_min measurement tool.
- `tests/test_combination.gd`: its tests.
- `levels/combo_01.json` … `combo_30.json`: the 30 built levels (ids 9082-9111).

## What it needs to run again

The last commit with the puzzle wired into the game is `c376864`. Besides the
files above, it used these hooks, removed from the game with it:

- `Level`: `disk_colors`, `color_goal`, `example_solution()`, the colour check in
  `check()`, the optional JSON keys `disk_colors` and `color_goal`.
- `RuleBase` / `RuleSet`: `bind_disk_colours()`, `disks_moved()`,
  `disks_picked_up()` (group pours, a lifted top run).
- `GameSession`: `COMBINATION_HINT_BUDGET`, the colour-letter path key, the
  CombinationSolver hint.
- `Difficulty`: `COMBINATION_STAGES`, `COMBINATION_E_MIN`, sizes up to 12 pegs / 70
  disks, the tier taken from the stage.
- Board and preview: block disks (34 high, radius 9) with pips, the colour-goal
  icons, the "glass" dress, "Nümunə həll" labels.
- Builder, validator and path builder: `combination_positions`, stage checks,
  the chapter at main 30.
