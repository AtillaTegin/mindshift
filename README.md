# MindShift: Puzzle Logic

Qayda-əsaslı (rule-based), Tower-of-Hanoi üzərində qurulmuş məntiq puzzle oyunu.
Engine: **Godot 4.7.2** (GDScript, statik tiplə). Hədəf platformalar: Android, sonra iOS.

Tam texniki plan: `../MindShift_Project_Spec.md`.

## Testlər

Godot-un console versiyası lazımdır (`Godot_v4.7.2-stable_win64_console.exe`).

```powershell
.\run_tests.ps1                  # bütün testlər
.\run_tests.ps1 -Filter rule_set # yalnız tests/test_*rule_set*.gd
```

Godot başqa yerdədirsə, `GODOT_BIN` mühit dəyişənini həmin exe-yə yönəldin.
Əl ilə:

```powershell
godot --headless --path . --import          # class_name keşini qurur (bir dəfə)
godot --headless --path . --script res://tests/test_runner.gd
```

Runner `tests/test_*.gd` fayllarındakı hər `test_*` metodunu ayrıca instansiyada işə salır.
Test zamanı loq edilən istənilən engine/script xətası da testi uğursuz edir. Uğursuzluq olarsa exit code 1 olur.

## Struktur

| Qovluq | Məzmun |
|---|---|
| `core/` | Oyun məntiqi: `PuzzleState`, `Move`, `RuleSet`, `rules/` (qaydalar), `solver.gd` |
| `tools/` | Headless skriptlər: səviyyə generatoru və validatoru |
| `data/levels/` | Generasiya olunmuş səviyyə JSON-ları (`easy/`, `medium/`, `hard/`, `expert/`) |
| `scenes/`, `scripts/` | UI səhnələri və controller-lər |
| `tests/` | Headless testlər (`test_runner.gd`, `test_case.gd` bazası) |
| `assets/` | Sprite və şriftlər (hələlik placeholder) |

### Yeni qayda əlavə etmək

1. `core/rules/` altında `RuleBase`-dən miras alan klas yazın (`get_id`, `is_move_allowed`, `is_state_valid`).
2. Onu `RuleSet.create_rule()` reyestrinə əlavə edin.

Solver-ə toxunmaq lazım deyil.

## İrəliləyiş

| Gün | Mövzu | Status |
|---|---|---|
| 1 | Əsas data strukturu (`PuzzleState`, `Move`, `RuleBase`, `ClassicHanoiRule`, `RuleSet`) | ✅ |
| 2 | BFS Solver | — |
| 3 | Səviyyə generatoru + validator | — |
| 4 | Oyun lövhəsi UI | — |
| 5 | Səviyyə seçimi, tamamlama ekranı, save | — |
| 6 | Hint, Undo, Economy | — |
| 7 | Android build | — |
