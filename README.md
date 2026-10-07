# MindShift: Puzzle Logic

Qayda-əsaslı (rule-based), Tower-of-Hanoi üzərində qurulmuş məntiq puzzle oyunu.
Engine: **Godot 4.7.2** (GDScript, statik tiplə). Hədəf platformalar: Android, sonra iOS.

Tam texniki plan: `../MindShift_Project_Spec.md`.

## Oyunu işə salmaq

```powershell
& "C:\Users\User\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path . --resolution 540x960
```

Və ya Godot redaktorunda layihəni açıb F5 basın. Oyun Ana menyu ilə açılır: "Oyna" növbəti bitməmiş səviyyəni açır, "Səviyyələr" isə seçim ekranını.
Oyunda qülləyə toxunun və üst disk qalxır, başqa qülləyə toxunun və disk ora köçür. Qeyri-qanuni gedişdə qüllə qırmızı yanıb-sönür.

İrəliləyiş `user://save.json`-da saxlanılır (Windows-da `%APPDATA%\Godot\app_userdata\MindShift- Puzzle Logic\`).
Başqa save faylı ilə işə salmaq üçün: `... -- --save-path=user://test.json`.
Kilid qaydası: hər çətinliyin 1-ci səviyyəsi açıqdır, digərləri əvvəlki səviyyə tamamlananda açılır.

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

## Səviyyələr

```powershell
# generasiya (hər çətinliyin köhnə fayllarını əvəz edir; seed sabitdir, nəticə təkrarlanır)
godot --headless --path . --script res://tools/level_generator.gd -- --difficulty=all --count=50
godot --headless --path . --script res://tools/level_generator.gd -- --difficulty=medium --count=50 --seed=7
# yoxlama (hər faylı Solver ilə yenidən həll edir; --require=N hər çətinlikdə ən azı N səviyyə tələb edir)
godot --headless --path . --script res://tools/level_validator.gd -- --require=50
```

Fayllar `data/levels/<çətinlik>/<çətinlik>_NNN.json` adlanır (asandan çətinə sıralanıb).
ID-lər: easy 1001+, medium 2001+, hard 3001+, expert 4001+. Çətinlik cədvəli [core/difficulty.gd](core/difficulty.gd)-dədir.

| Çətinlik | Gediş | Qüllə | Disk |
|---|---|---|---|
| Easy | 3–8 | 3 | 3–4 |
| Medium | 9–18 | 3–4 | 5–6 |
| Hard | 19–35 | 4 | 7–8 |
| Expert | 36+ | 4 | 9–10 |

Hard və Expert sətirləri sənəddəki ilkin cədvəldən fərqlənir: 4q/6d ilə maksimum 17, 4q/8d ilə 33, 5q/10d ilə 31 gediş mümkündür.

### Yeni qayda əlavə etmək

1. `core/rules/` altında `RuleBase`-dən miras alan klas yazın:
   - qərar yalnız hərəkət edən diskdən, iki qüllədən və hədəf qüllənin üst diskindən asılıdırsa:
     `is_disk_move_allowed()` + `supports_disk_move_check() -> true` (Solver sürətli yolu istifadə edə bilir);
   - daha çox vəziyyət məlumatı lazımdırsa: `is_move_allowed()` (Solver ümumi BFS-ə keçir);
   - mövqe məhdudiyyəti varsa: `is_state_valid()`.
2. Onu `RuleSet.create_rule()` reyestrinə əlavə edin.

Solver-ə toxunmaq lazım deyil.

### Solver

`Solver.solve(start, goal, rules, max_states)` → `{ solvable, min_moves, path: Array[Move], states_visited, limit_reached, strategy }`.
İki strategiya var, hər ikisi BFS-dir və ən qısa yolu tapır:

- **packed**: qaydalar qüllələri sıralı saxlayırsa (klassik Hanoi), vəziyyət tam ədəd kimi kodlanır
  ("hər disk hansı qüllədədir") və axtarış iki tərəfdən aparılır. 4 qüllə / 8 disk ≈ 60 ms.
- **generic**: `PuzzleState` + `hash_key()` üzərində standart BFS, istənilən qayda dəsti üçün.
  4 qüllə / 8 disk burada ≈ 15 s çəkir. Səbəb də sürətli yolun yaradılmasıdır.

## İrəliləyiş

| Gün | Mövzu | Status |
|---|---|---|
| 1 | Əsas data strukturu (`PuzzleState`, `Move`, `RuleBase`, `ClassicHanoiRule`, `RuleSet`) | ✅ |
| 2 | BFS Solver (4 qüllə / 8 disk: ~60 ms, limit 5 s) | ✅ |
| 3 | Səviyyə generatoru + validator (4 × 50 səviyyə, hamısı yoxlanılıb) | ✅ |
| 4 | Oyun lövhəsi UI (toxun-seç, toxun-köçür, qırmızı flash, sayğac, hədəf önizləməsi) | ✅ |
| 5 | Ana menyu, səviyyə seçimi, tamamlama popup-ı, ulduzlar, save (`user://save.json`) | ✅ |
| 6 | Hint, Undo, Economy | — |
| 7 | Android build | — |
