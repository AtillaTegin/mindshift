# MindShift: Puzzle Logic

Qayda-əsaslı (rule-based), Tower-of-Hanoi üzərində qurulmuş məntiq puzzle oyunu.
Engine: **Godot 4.7.2** (GDScript, statik tiplə). Hədəf platformalar: Android, sonra iOS.

Tam texniki plan: `../MindShift_Project_Spec.md`.

## Oyunu işə salmaq

```powershell
& "C:\Users\User\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path . --resolution 540x960
```

Və ya Godot redaktorunda layihəni açıb F5 basın. Oyun Ana menyu ilə açılır:
- "Oyna" növbəti bitməmiş səviyyəni açır;
- "Səviyyələr" seçim ekranını açır;
- "Mağaza" mağaza ekranını açır;
- "Parametrlər"də səs, qaranlıq mod və dil var.
Oyunda qülləyə toxunun və üst disk qalxır, başqa qülləyə toxunun və disk ora köçür. Qeyri-qanuni gedişdə qüllə qırmızı yanıb-sönür.

İrəliləyiş `user://save.json`-da saxlanılır (Windows-da `%APPDATA%\Godot\app_userdata\MindShift- Puzzle Logic\`).
Başqa save faylı ilə işə salmaq üçün: `... -- --save-path=user://test.json`.
Testlər, e2e skriptləri və alətlər (`--script` ilə işləyənlər) bu qovluğa heç vaxt yazmır.
Onların `user://` faylları layihədəki `.test_saves/` qovluğuna yönləndirilir ([scripts/storage_paths.gd](scripts/storage_paths.gd)). Bu qovluq git-ə düşmür.
Vaxt limiti: v1-də heç bir səviyyədə yoxdur. `time_limit_seconds` sahəsi formatda qalır, amma validator dolu dəyəri rədd edir. Vaxt limiti gələcəkdə ayrıca "Vaxta Qarşı" rejimində olacaq.
Kilid qaydası ([əlavə sənəd 3](../MindShift_Economy_UX_Addendum.md), bölmə 1.2): Asan həmişə açıqdır; Orta Asan-da 15, Çətin Orta-da 10,
Ekspert Çətin-də 10 səviyyə tamamlananda açılır (say `completed_levels`-dən hesablanır, yeni save sahəsi yoxdur).
Açıq bölmənin içində səviyyələr ardıcıl açılır. Artıq tamamlanmış səviyyə həmişə açıq qalır.
"Oyna" ən çətin açıq bölmənin növbəti bitməmiş səviyyəsini açır.
Rəqəmlər [core/difficulty.gd](core/difficulty.gd)-də `UNLOCK_AFTER_COMPLETED` sabitindədir.

Economy ([əlavə sənəd 3](../MindShift_Economy_UX_Addendum.md), 8.1). Hamısı [scripts/economy_system.gd](scripts/economy_system.gd)-də sabitdir:
- Mükafat: 3★ = 8, 2★ = 5, 1★ = 3 coin. Təkrar oyunda yalnız əvvəlki ən yaxşı nəticədən fərq verilir.
- Gündəlik giriş bonusu 10 coin.
- Hint Asan/Orta-da 3, Çətin/Ekspert-də 5 coin. Eyni vəziyyətdə təkrar basmaq pulsuzdur.
- Gündə 3 pulsuz undo var (bütün səviyyələr üçün ortaq), sonra hər biri 1 coin. Undo gedişi sayğacdan da geri alır.

Mağaza ([scripts/shop_catalog.gd](scripts/shop_catalog.gd)) **stub rejimindədir**: alış məhsulu dərhal verir, real ödəniş yoxdur.
- Coin paketləri: 60 / 200 / 500 coin ($0.99 / $2.99 / $6.99). Qiymət sırada "60 coin → $0.99" kimi görünür, düymədə "Al" yazılıb.
- Reklam: 5 coin, gündə 5 dəfə.
- "24 saat limitsiz Hint": $0.99.
- "Reklamları sil" reklam sistemi gələnə qədər bağlıdır.
- Google Play Billing [scripts/store_service.gd](scripts/store_service.gd)-dəki `# TODO: real Billing SDK` yerlərinə qoşulacaq.

Saniyəölçən gediş sayğacının yanındadır: ilk gedişlə başlayır, səviyyə həll olunanda dayanır, "Yenidən" ilə sıfırlanır.
Popup və save-dəki `best_time_seconds` eyni vaxtı göstərir (saniyə aşağı kəsilir).
Bu, spesifikasiyadakı `time_limit_seconds` (aşağı sayan, uduzduran taymer) deyil. O gələcəkdə ayrıca element olacaq.

Hint-ə yönləndirmə ([core/hint_nudge_watcher.gd](core/hint_nudge_watcher.gd), HintController-in içində):
9 saniyə heç bir toxunuş olmasa, və ya ardıcıl 2 qanunsuz gediş cəhdi olsa, eyni FocusRing Hint düyməsinin ətrafında "nəfəs alır".
Səhv halında səviyyə başına bir dəfə toast da çıxır. İstənilən toxunuş, gediş, undo və ya hint onu dərhal söndürür.
Tutorial zamanı, hint ekranda olanda, səviyyə həll olunanda və coin hint-ə çatmayanda göstərilmir.

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
| Easy | 5–11 | 3 | 3–4 |
| Medium | 12–20 | 3–4 | 5–6 |
| Hard | 21–33 | 4 | 7–8 |
| Expert | 34+ | 4 | 9–10 |

Hard və Expert sətirləri sənəddəki ilkin cədvəldən fərqlənir: 4q/6d ilə maksimum 17, 4q/8d ilə 33, 5q/10d ilə 31 gediş mümkündür.
Gediş aralıqları əlavə sənəd 3-ün 1.1 bölməsinə görə yenidən tənzimlənib (köhnə: 3–8, 9–18, 19–35, 36+).

### Bonus səviyyələr

8 bonus səviyyə [data/levels/bonus/](data/levels/bonus/)-dadır. Hər tabın sonunda bir dondurulmuş və bir dumanlı səviyyə var.

- **Necə işləyir:**
  - Bonus səviyyələr həmişə açıqdır və açılma sayğacına (15/10/10) daxil olmur.
  - Ulduzları ümumi saya düşür (624), coin verir.
- **Faylların quruluşu:**
  - ID-lər 9001-dən başlayır, `"difficulty": "bonus"`.
  - Hansı səviyyənin hansı tabda olduğunu `index.json` göstərir.
- **Dondurulmuş disk:** `"rules": [..., "frozen_disk"]`, `"rule_params": {"frozen_disk": {"disk_size": 2}}`.
  - Disk heç vaxt tərpənmir, üstünə kiçik disk qoyula bilər.
  - Solver və Generator dəyişməyib.
- **Örtülü qüllə:** `"covered_pegs": [1, 2]`. Yalnız vizual qatdır: qüllədən ilk istifadədə duman açılır, "Yenidən" ilə qayıdır. Hədəf önizləməsində də eyni duman var.
- **Yenidən qurmaq** (sabit seed ilə, hər faylı validator yoxlayır):

  ```powershell
  godot --headless --path . --script res://tools/bonus_level_builder.gd
  ```
- **Validator-un dizayn qaydaları:**
  - dondurulmuş disk ən alt disk ola bilməz və ən qısa həlli uzatmalıdır;
  - örtülü qüllədə ən azı 2 disk olmalıdır;
  - örtülü qüllə həllin ilk 3 gedişində istifadə olunmalıdır.

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
| 6 | Hint (yolda: dərhal, yoldan kənar: arxa planda Solver), Undo, Economy | ✅ |
| 6B | Coaching overlay, tutorial (Asan 1–2), yeni hint təqdimatı, game feel ([əlavə sənəd](../MindShift_Polish_Tutorial_Addendum.md)) | ✅ |
| UX-1 | Yeni çətinlik aralıqları, qismən-say kilid qaydası ([əlavə sənəd 3](../MindShift_Economy_UX_Addendum.md)) | ✅ |
| UX-2 | Yuxarı sayan saniyəölçən (ilk gedişlə başlayır, həll olunanda dayanır) | ✅ |
| UX-3 | Hint-ə yönləndirmə: 9 s hərəkətsizlik və ya ardıcıl 2 səhv → Hint düyməsində FocusRing | ✅ |
| UX-4 | ThemeManager (işıqlı/qaranlıq mod), dil infrastrukturu (az tam; tr/ru/en `[TODO]`) | ✅ |
| UX-5 | Ana menyu: Oyna, Səviyyələr, Mağaza (ekran hələlik boşdur, Bölmə 8 doldurur), Parametrlər | ✅ |
| UX-6 | Hədəf önizləməsində hər diskin üstündə ölçü rəqəmi; önizləmə hündürlüyü disk sayına uyğunlaşır | ✅ |
| UX-7 | Kodla çəkilən ikonlar (coin, hint lampası, undo oxu), sabit funksional rənglər, `PolishedButton.icon_kind` | ✅ |
| UX-8 | Yeni coin balansı, mağaza (stub alış, reklam, 24 s limitsiz Hint), gündəlik pulsuz undo | ✅ |
| B-1 | Bonus: Dondurulmuş disk (`FrozenDiskRule`), 4 səviyyə ([əlavə sənəd 4](../MindShift_Bonus_Mechanics_Addendum.md)) | ✅ |
| B-2 | Bonus: Örtülü qüllə (`PegFog`, yalnız vizual), 4 səviyyə | ✅ |
| B-3 | Bonus xanaları hər tabın sonunda (hədiyyə ikonu, həmişə açıq) | ✅ |
| 7 | Android build | — |

### Rənglər və dillər

- **Rənglər**: UI kodu rəng kodu yazmır.
  - Ya `ThemeManager.color("accent")` kimi rol istəyir, ya da səhnədə theme variation istifadə edir (`SecondaryLabel`, `SuccessLabel`, `DangerLabel`, `CoinLabel`, `CardPanel`).
  - İki palitra ([scripts/theme_manager.gd](scripts/theme_manager.gd)) eyni rolları təyin edir. Rejim Parametrlərdə dəyişir və save-də saxlanılır.
  - Ekran fonları üçün `ThemedColorRect` istifadə olunur.
  - İstisnalar (coaching overlay, konfeti) `tests/test_theme.gd`-də siyahıdadır.
- **İkonlar**: [scripts/game_icons.gd](scripts/game_icons.gd) coin, hint və undo ikonlarını kodla çəkir.
  - Rəngləri `ThemeManager.ICON_COLORS`-dadır: coin qızılı, hint mavi-bənövşəyi, undo boz-mavi. Bu rənglər hər iki modda eynidir.
  - Düyməyə ikon vermək üçün `PolishedButton.icon_kind = "hint"` yazmaq kifayətdir. Düymə söndürüləndə ikon solğun görünür.
  - Ayrıca ikon üçün `IconView` istifadə olunur. Məsələn, coin balansının yanındakı ikon budur.
  - İkonların çəkilməsi real pəncərədə yoxlanılıb, çünki headless test kadr çəkmir.
- **Mətnlər**: hər mətn [locale/az.po](locale/az.po)-da açarla saxlanılır (`MENU_PLAY` → "Oyna"). Kodda `tr("MENU_PLAY")` yazılır, səhnələrdə isə mətn kimi açarın özü.
  - Yeni mətn əlavə etmək üçün açarı `az.po`-ya yazın, sonra `godot --headless --path . --script res://tools/sync_translations.gd` işə salın.
  - Bu əmr açarı `tr/ru/en.po`-ya boş `msgstr` və `#. [TODO: XX] az: ...` qeydi ilə köçürür.
  - Tərcümə edilməmiş mətn Azərbaycanca görünür (`locale/fallback="az"`).
  - Real tərcümə ayrıca işdir: `msgstr`-ləri doldurmaq kifayətdir.

### 6B qeydləri

- Coaching primitivləri `scenes/components/coaching/`-dadır (Scrim, FocusRing, GhostPointer, CoachToast).
  Onları ayrıca görmək üçün redaktorda `coaching_demo.tscn` açıb F6 basın.
- Tutorial `easy_001`-də addım-addım, `easy_002`-də sərbəst rejimdə işləyir və yalnız səviyyə ilk dəfə tamamlanana qədər görünür.
- Effekt parametrləri bir yerdədir: düymə `scripts/polished_button.gd`, keçid `scripts/screen_transition.gd`,
  disk bounce/kölgə `scenes/components/disk.gd`, konfeti `scripts/level_complete_popup.gd`, həlqə `focus_ring.gd`.
