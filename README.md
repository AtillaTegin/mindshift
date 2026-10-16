# MindShift: Puzzle Logic

Qayda-əsaslı (rule-based), Tower-of-Hanoi üzərində qurulmuş məntiq puzzle oyunu.
Engine: **Godot 4.7.2** (GDScript, statik tiplə). Hədəf platformalar: Android, sonra iOS.

Tam texniki plan: `../MindShift_Project_Spec.md`.

## Oyunu işə salmaq

```powershell
& "C:\Users\User\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path . --resolution 540x960
```

Və ya Godot redaktorunda layihəni açıb F5 basın. Oyun Ana menyu ilə açılır:
- "Oyna" oyunçunun qaldığı yeri açır (yoldakı ilk bitməmiş səviyyə);
- "Səviyyələr" səviyyə xəritəsini açır;
- "Mağaza" mağaza ekranını açır;
- "Parametrlər"də səs, qaranlıq mod və dil var.
Oyunda qülləyə toxunun və üst disk qalxır, başqa qülləyə toxunun və disk ora köçür. Qeyri-qanuni gedişdə qüllə qırmızı yanıb-sönür.

İrəliləyiş `user://save.json`-da saxlanılır (Windows-da `%APPDATA%\Godot\app_userdata\MindShift- Puzzle Logic\`).
Başqa save faylı ilə işə salmaq üçün: `... -- --save-path=user://test.json`.
Testlər, e2e skriptləri və alətlər (`--script` ilə işləyənlər) bu qovluğa heç vaxt yazmır.
Onların `user://` faylları layihədəki `.test_saves/` qovluğuna yönləndirilir ([scripts/storage_paths.gd](scripts/storage_paths.gd)). Bu qovluq git-ə düşmür.
Vaxt limiti: v1-də heç bir səviyyədə yoxdur. `time_limit_seconds` sahəsi formatda qalır, amma validator dolu dəyəri rədd edir. Vaxt limiti gələcəkdə ayrıca "Vaxta Qarşı" rejimində olacaq.
Səviyyə yolu ([səviyyə strukturu v3](../MindShift_Level_Structure_Addendum.md)): tab, bölmə adı və bonus guşəsi yoxdur.
- Bütün səviyyələr bir nömrəli yoldadır (`data/levels/path.json`, [core/level_catalog.gd](core/level_catalog.gd)). Hər səviyyə yolda özündən əvvəlki bitəndə açılır, başqa kilid yoxdur. Bitmiş səviyyə həmişə açıq qalır.
- Əsas yolun 50-ci səviyyəsi bitəndə yolun kənarında "Gizli ada" (ayrıca budaq) görünür: bütün Ekspert səviyyələri, ən çətin Çətin-lər və bir neçə Orta "nəfəs" səviyyəsi. O vaxta qədər heç bir işarəsi yoxdur.
- Xəritə ([scripts/path_map.gd](scripts/path_map.gd)) aşağıdan yuxarı qıvrılan yoldur: bitmiş səviyyələr (təkrar oynayıb ulduz artırmaq olar), növbəti səviyyə (vurğulu) və 3 kilidli dayanacaq görünür.
- Çətinlik yalnız daxildə qalır: generasiya, yol sırası və hint qiyməti üçün.

Economy ([əlavə sənəd 3](../MindShift_Economy_UX_Addendum.md) 8.1, [iqtisadiyyat düsturları v3](../MindShift_Economy_Formulas_Addendum.md)). Hamısı [scripts/economy_system.gd](scripts/economy_system.gd)-də sabitdir:
- Səviyyə coin vermir. Hər yeni ulduz 1 jeton verir (təkrar oyunda yalnız fərq). 15 jeton = 1 açar, 3 açar = 1 sandıq, sandıq özü açılır.
  - Sandığın içi: 60% boş, 30% 1 coin, 10% 3 coin (orta hesabla ~0.6 coin). Rəqəmlər ilkin təxmindir, playtest ilə tənzimlənəcək.
  - Xəritənin yuxarısında sandıq göstəricisi var ([scripts/chest_meter.gd](scripts/chest_meter.gd)): sandıq, açarlar və "7/15 jeton" zolağı. Açar xəbəri tamamlama pəncərəsində yazılır.
  - Sandıq tamamlama pəncərəsində ulduzlardan sonra açılır ([scripts/chest_opening.gd](scripts/chest_opening.gd)): qapaq titrəyir və səviyyənin don rəngində (klassikdə qızılı) parıldayır, sonra şüa və qığılcımla açılır. Coin varsa sikkə sayğaca uçur, sayğac yalnız sikkə çatanda artır, "ding" çalınır. Boş sandıqda yumşaq toz buludu, iki kiçik sıçrayış və "Bu dəfə boş çıxdı. Davam et!" görünür.
  - "Ding" kodla sintez olunur ([scripts/sound_fx.gd](scripts/sound_fx.gd), səs faylı yoxdur) və Parametrlərdə səs söndürüləndə çalınmır.
- Yeni save 20 coin ilə başlayır. Gündəlik giriş bonusu 2 coin.
- Hint Asan/Orta-da 3, Çətin/Ekspert-də 5 coin. Eyni vəziyyətdə təkrar basmaq pulsuzdur.
- Gündə 3 pulsuz undo var (bütün səviyyələr üçün ortaq), sonra hər biri 1 coin. Undo gedişi sayğacdan da geri alır.

Mağaza ([scripts/shop_catalog.gd](scripts/shop_catalog.gd)) **stub rejimindədir**: alış məhsulu dərhal verir, real ödəniş yoxdur.
- Coin paketləri (təxminən 25–36 coin/$1, oxşar oyunlar kimi): Bürünc Kisə 25 ($0.99), Gümüş Kisə 60 ($1.99), Qızıl Disk 150 ($4.99), Jadeit Sandığı 320 ($9.99), Karakuri Xəzinəsi 700 ($19.99), Brahma Məbədinin Xəzinəsi 1800 ($49.99). Qiymət sırada "25 coin → $0.99" kimi görünür. Real satış datası olmadan heç bir paketdə "ən populyar" nişanı yoxdur.
- Reklam: 4 coin, gündə 5 dəfə (gündə ən çox 20 coin).
- "24 saat limitsiz Hint": $2.99 (ayrıca qiymət nöqtəsi, ən ucuz paketdən həmişə baha).
- "Reklamları sil" reklam sistemi gələnə qədər bağlıdır.
- Google Play Billing [scripts/store_service.gd](scripts/store_service.gd)-dəki `# TODO: real Billing SDK` yerlərinə qoşulacaq.

Saniyəölçən gediş sayğacının yanındadır: ilk gedişlə başlayır, səviyyə həll olunanda dayanır, "Yenidən" ilə sıfırlanır.
Popup və save-dəki `best_time_seconds` eyni vaxtı göstərir (saniyə aşağı kəsilir).
Bu, spesifikasiyadakı `time_limit_seconds` (aşağı sayan, uduzduran taymer) deyil. O gələcəkdə ayrıca element olacaq.

Hint-ə yönləndirmə ([core/hint_nudge_watcher.gd](core/hint_nudge_watcher.gd), HintController-in içində):
9 saniyə heç bir toxunuş olmasa, və ya ardıcıl 2 qanunsuz gediş cəhdi olsa, eyni FocusRing Hint düyməsinin ətrafında "nəfəs alır".
Səhv halında səviyyə başına bir dəfə toast da çıxır. İstənilən toxunuş, gediş, undo və ya hint onu dərhal söndürür.
Tutorial zamanı, hint ekranda olanda, səviyyə həll olunanda və coin hint-ə çatmayanda göstərilmir.

## Prototip: Rəng ardıcıllığı

Üç mexanikanı sınamaq üçün ayrıca, oynanıla bilən bir səviyyə ([tapşırıq](../MindShift_Mechanics_Prototype.md)): hədəf rəng ardıcıllığı, eyni ölçülü rəngli disklər və gediş limiti.
Hamısı `prototype/sort_pattern/`-dadır. Əsas oyuna, səviyyələrə, Solver-ə, yola və qənaətə toxunmur.

```powershell
& "C:\Users\User\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path . --resolution 540x960 res://prototype/sort_pattern/sort_menu.tscn
```

Və ya redaktorda `prototype/sort_pattern/sort_menu.tscn` açıb F6 basın.

- **Qaydalar**: yalnız üst disk götürülür. Disk boş qülləyə, eyni ölçülü və ya daha böyük diskin üstünə qoyulur. Hədəf rəngə görə oxunur, diskin kimliyinə görə yox: bütün disklər sağ qüllədə hədəfdəki rəng ardıcıllığı ilə (aşağıdan yuxarı) durmalıdır.
- **Gediş limiti**: yalnız uğurlu köçürmə sayılır (seçmək, geri qoymaq, qanunsuz cəhd pulsuzdur). Hədəf limit daxilində yığılan kimi qələbədir, son gedişdə də. Hədəf olmadan qalan gediş 0 olanda uduzulur. Bu, oyunun "uduzma yoxdur" qaydasına ziddir: prototip üçün qəbul edilib, istehsala keçərsə ayrıca qərar lazımdır.
- **Səviyyə** (`sort_level.json`): 3 qüllə, 6 disk (1 böyük, 4 eyni ölçülü orta, 1 kiçik). Ən qısa həll S = 13, limit M = S + 2 = 15.
  - Limiti sınaq zamanı menyuda −/+ ilə dəyişmək olar (S ilə S + 20 arası, oyun bağlanana qədər).
  - Daimi dəyişiklik üçün: `godot --headless --path . --script res://prototype/sort_pattern/sort_builder.gd -- --slack=3` (və ya `--limit=18`). Alət həlli və S-i yenidən hesablayıb faylı yoxlayır.
- **Solver**: əsas Solver diski ölçüsü ilə tanıyır və hədəfi dəqiq mövqe sayır, ona görə prototipin öz kiçik BFS-i və validatoru var (`sort_solver.gd`).
- Lövhə oyunun `PegView`, `DiskView`, `Move`, `BoardLayout` hissələrini, düymələrini və mövzusunu təkrar istifadə edir. Hər rəngin öz forması var (qırmızı dairə, göy kvadrat, sarı üçbucaq, yaşıl romb).
- Mətnlər yalnız Azərbaycanca, `sort_texts.gd`-dədir (`locale/`-a düşmür). Disk rəngləri `sort_palette.gd`-dədir. Testlər: `tests/test_sort_prototype.gd`.

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
| `data/levels/` | Səviyyə JSON-ları (`easy/`, `medium/`, `hard/`, `expert/`, `mechanics/`) və yol (`path.json`) |
| `scenes/`, `scripts/` | UI səhnələri və controller-lər |
| `prototype/` | Oyuna qoşulmayan sınaq prototipləri (hazırda: `sort_pattern/`, rəng ardıcıllığı) |
| `tests/` | Headless testlər (`test_runner.gd`, `test_case.gd` bazası) |
| `assets/` | Sprite və şriftlər (hələlik placeholder) |

## Səviyyələr

```powershell
# bütün yol: hər səviyyə faylını və path.json-u əvəz edir, sonda hamısını yoxlayır (seed sabitdir, nəticə təkrarlanır)
godot --headless --path . --script res://tools/road_builder.gd                 # BUILT_WORLDS (indi 1-2)
godot --headless --path . --script res://tools/road_builder.gd -- --worlds=1-2
# yoxlama (hər faylı Solver ilə yenidən həll edir, yolu da yoxlayır; --require=N hər çətinlikdə ən azı N klassik səviyyə tələb edir)
godot --headless --path . --script res://tools/level_validator.gd -- --require=16
```

### Fəsil sistemi

[Fəsil Sistemi v1](../MindShift_Fesil_Sistemi_v1.md) (2026-10-15) səviyyə quruluşunu əvəz edir: 7 dünya, ~2020 səviyyə. Hər mod öz fəslində öyrədilir, fəsillər arasında klassik Hanoi nəfəs kimi gəlir, 2-3 moddan sonra 50 səviyyəlik kombinasiya fəsli gəlir. Plan [core/chapter_plan.gd](core/chapter_plan.gd)-dədir (`ChapterPlan`), səviyyələri [tools/road_builder.gd](tools/road_builder.gd) slot-slot qurur ([tools/level_forge.gd](tools/level_forge.gd) bir səviyyəni çəkib yoxlayır).

İndi qurulub: **Dünya 1-2**, 350 əsas yol + 4 adada 70 = 420 səviyyə (1260 ulduz).

| Dünya | Səviyyələr | Fəsil |
|---|---|---|
| 1 | 1–50 | Klassik (yalnız klassik; 1-2 tutorial dəyişmir) |
| 1 | 51–100 | Tutum (36 mod + 14 klassik) |
| 2 | 101–200 | Karakuri (70 + 25 klassik + 5 təkrar) |
| 2 | 201–300 | Kilid (70 + 25 klassik + 5 təkrar) |
| 2 | 301–350 | Kombinasiya I: Tutum+Karakuri, Tutum+Kilid, Karakuri+Kilid (25 kombinasiya, 15 tək mod, 10 klassik) |

- **Pillələr** (istifadəçi qərarı: əsas yolda 33 gediş həddi qalır): fəslin ilk 15%-i asan-orta 7–12, 45%-ə qədər orta 12–18, 75%-ə qədər orta-çətin 18–25, son 25% çətin 25–33. Klassik 1–100 öz cədvəli ilə (1–5 asan 5–7, 6–20, 21–45, 46–75, 76–100). Adalar ekspert 34–70. Daxili çətinlik (Hint qiyməti) yenə gediş sayından gəlir: 5–11, 12–20, 21–33, 34+.
- **Mod fəsli:** mod ilə açılır (bələdçi), hər 3 mod səviyyəsinə 1 klassik (Dünya 1-də 2,5:1). Klassiklər bərabər aralıqla, çətin səviyyədən sonra gəlir (dalğalar aşağıda). İkinci yarıda hər 10 səviyyədən biri əvvəlki fəsillərin modudur (ən yenisindən geriyə növbə ilə). 100-dən sonrakı klassiklər orta-çətin və çətin arasında növbələşir, hərdən 7 disk / 3 qüllə "böyük sınaq" gəlir.
- **Kombinasiya fəsli:** 50% kombinasiya, 30% həmin dünyanın tək modları, 20% klassik. Birinci kombinasiya fəsli açır, digərləri ilk yarıda bir-bir qoşulur. Hər kombinasiyanın ilk səviyyəsində mini-bələdçi (iki qayda birlikdə). Xəritədə "Tutum + Kilid", paneldə iki qayda. Kombinasiya hər iki moddan ayrı-ayrılıqda uzun olmalıdır (`LevelForge.matters`). Yalnız siyahıdakı (whitelist) cütlər; kateqoriya qaydaları `ChapterPlan.is_combo_allowed`-dadır, siyahıdan kənar kombinasiya validator-da xəta verir.
- **Adalar** (istifadəçi qərarı: hər fəslin sonunda öz adası): klassik ada 50-dən sonra (28 ekspert, 8 çətin, 4 orta), hər mod fəslinin adası öz fəsli bitəndə açılır, 10 ekspert səviyyə. Xəritədə hər açıq adanın öz markeri var; başlıq "Gizli ada · Tutum".
- **Hər qrup** (bir axın: klassik, mod və ya kombinasiya, bir pillə) birlikdə çəkilir, gediş sayları pillənin aralığına yayılır, slotlara asandan çətinə paylanır.
- **Fayllar və id-lər:** klassik `data/levels/<çətinlik>/<çətinlik>_NNN.json`, id-lər çətinliyə görə (1001+, 2001+, 3001+, 4001+). Mod və kombinasiyalar `data/levels/mechanics/<ad>_NNN.json` (`capacity`, `fog`, `foundation`, kombinasiya: `capacity_foundation` və s.), hər modun və kombinasiyanın 10001-dən başlayan 1000-lik öz id bloku var.
- Builder sonda hər fəsil və ada üçün status çap edir.

### Fəsil daxilində dalğalar

[Dalğalar v1](../MindShift_Fesil_Daxili_Dalgalar_v1.md) (2026-10-16): mod fəsli dalğalarla gedir (`ChapterPlan.WAVES`).
- **Ardıcıllıq:** əvvəl modun əsas forması, sonra hər dalğa bir yeni alt-element gətirir. Ardınca qarışıq dalğa (10 səviyyə) gəlir, ən sonda fəslin **Böyük Sınağı** ([Fəsil Sistemi v1.2](../MindShift_Fesil_Sistemi_v1.2.md), 3.2a).
- **Böyük Sınaq:** hər mod və kombinasiya fəslinin son səviyyəsi (Dünya 1-2-də 100, 200, 300, 350), 34-65 gediş. Mod fəslində birlikdə ola bilən bütün alt-elementləri daşıyır, kombinasiya fəslində ən yeni kombinasiyadır. Xəritədə böyük dairə və tacla görünür, ipucusu 5 sikkədir (ekspert). 1-50 klassik fəslində yoxdur. 65 gedişdən uzun səviyyələr yalnız adalardadır.
- **Dalğanın içi:** tanıtma səviyyəsi yeni elementi təkbaşına verir, aşağı gediş pəncərəsində, öz bələdçisi ilə: "Yeni: Tağ — ...". Sonra 3 səviyyə yalnız o element, sonra əvvəlki alt-elementlərlə qarışıq gəlir.
- **Dişli xətt:** hər səviyyənin öz gediş pəncərəsi var. Dalğa qalxır, növbəti dalğa bir az aşağıdan başlayır, ümumi xətt yuxarı gedir. Klassik səviyyələr çətin səviyyədən sonra gəlir.

| Mod | Alt-elementlər | Ada |
|---|---|---|
| Tutum | Dar keçid (tutum 1), Tağ (yalnız ≤ N keçir) | Deşikli qüllə (boş qülləyə yalnız ≥ N) |
| Karakuri | Say lövhəsi, Şüşə disk, Boş qutu, Möhürlü qutu (yalnız ən kiçik disk qapağa qoyulur və möhürü qırır) | Yenidən bağlanan qutu (3 gediş toxunulmasa bağlanır) |
| Kilid | Açar disk, Ortadakı kilid, Zəncirvari kilid (2-3 kilid ardıcıl) | — |

- **Panel:** üçüncü sətirdə alt-elementin qaydası yazılır.
- **Şans qaydası:** Say lövhəsi və Boş qutu səviyyələrində söndürülüb (istifadəçi qərarı): qutuda 0-1 disk ola bilər, ilk gedişlərdə açılmaya bilər. Möhürlü qutu yalnız "ilk gedişlərdə açılmalıdır" şərtindən azaddır.
- **Validator:** səviyyənin adını çəkdiyi alt-elementlərin həqiqətən olduğunu yoxlayır. Qaydanı dəyişən hər alt-element həlli öz-özlüyündə uzatmalıdır.
- **İpucu sürəti:** əsas yolda ≤0,7 s, Karakuri adasında 1,6 s.
- Dünya 3-7 hələ qurulmayıb: Karvan, Zolaqlı, Dairə, Doqquz Halqa, Tərəzi, Mübadilə, Cığır, Zəncir, Güzgü, Maqnit onlar qurulana qədər yolda yoxdur (qaydaları və testləri qalır). Bağlı Qüllələr hələ yoxdur.

### Mexanika səviyyələri

- **Faylların quruluşu:** `difficulty` gediş sayının düşdüyü çətinlikdir. Ölçü klassik cədvəldən fərqlənə bilər (Doqquz Halqa yalnız 4 qüllədə həlli etibarlı uzadır).
- **Doqquz Halqa (alternasiya qaydası, D variantı):** `"rules": ["classic_hanoi", "alternation"]` ([mədəni inteqrasiya əlavəsi](../MindShift_Kulturoloji_Inteqrasiya_Addendum.md), bölmə 1).
  - 1-ci disk həmişə gedə bilər; 1-ci diskdən sonra istənilən disk; başqa diskdən sonra yalnız 1-ci disk və ya ±1 qonşu. Başlanğıcda yalnız 1-ci disk.
  - İndi gedə bilən üst disklər lövhədə jadeit halqası ilə işarələnir. Qadağan diskə toxunanda disk titrəyir və qayda yazılır, cəza yoxdur.
  - Vəziyyət sonuncu tərpənən diski xatırlayır (`PuzzleState.last_moved_disk`, mövqenin hissəsi deyil). Solver bunu ümumi şəkildə dəstəkləyir (`RuleBase.uses_last_move`, `packed_history` axtarışı), qaydanın adını çəkmir.
  - Sənəddəki hərfi qayda (`1-dən sonra istənilən` olmadan) 3–4 qüllədə yalnız 1–3-cü diskləri tərpənməyə qoyurdu (ölçülüb), ona görə istifadəçi D variantını seçdi.
- **Örtülü qüllə (karakuri qutusu):** `"covered_pegs": [1, 2]`. Yalnız təqdimatdır, Solver və ulduzlar dəyişmir ([mədəni inteqrasiya əlavəsi](../MindShift_Kulturoloji_Inteqrasiya_Addendum.md), bölmə 2).
  - Qüllə bağlı ağac qutu kimi başlayır: bütün disklər, hətta neçə disk olduğu da görünmür.
  - İlk toxunuş qutunu açır (gediş sayılmır) və yalnız üst disk görünür. Üst disk gedəndə altındakı açılır, hər dəfə bir qat.
  - Qutunun üstünə qoyulan disklər görünür qalır. Undo heç nəyi yenidən gizlətmir, "Yenidən" bütün qutuları bağlayır.
  - Hədəf önizləməsindəki duman qutu açılanda qalxır.
- **Karvan Yolu (variant C, xətti qonşuluq):** `"rules": ["classic_hanoi", "adjacent_pegs"]` ([Karvan Yolu əlavəsi](../MindShift_Karvan_Yolu_ve_BossLevel_Addendum.md), bölmə 1). Disk yalnız qonşu qülləyə gedə bilər, üstündən tullanmaq olmaz. Bu, Bağlı Qüllələrin sabit xətti halıdır; Bağlı Qüllələr hələ qurulmadığı üçün ayrıca sadə qayda kimi yazılıb (`AdjacentPegsRule`), Solver-in sürətli yolu ilə işləyir. 3 qüllədə 3–4, 4–5 qüllədə 3–6 disk (3 qüllə / 5 diskdə həll artıq ~100 gedişdir).
- **Böyük Mübadilə v2** ([əlavə](../MindShift_Boyuk_Mubadile_v2_ve_Birlesme_AutoGroup_Addendum.md), bölmə 1, və istifadəçinin iki alt-tip qərarı): `"rules": ["color_swap"]`, `"rule_params": {"color_swap": {"colour": false | true}}` (`ColorSwapRule`). Hər ölçüdən bir ağ, bir qara disk var. Disk id-si ikisini də daşıyır: 2s−1 ağ, 2s qara, ölçü s. Ölçüyə görə sıralı yığın id-yə görə də sıralıdır, ona görə Solver sürətli yolla işləyir.
  - Uclarda k-şar disk, aralarında 2–4 boş qüllə. Hədəf həmişə eynidir: bütün qaralar sol ucda, bütün ağlar sağ ucda.
  - **Təmiz Dəyişmə** (`colour: false`): ağlar solda, qaralar sağda başlayır, yalnız ölçü qaydası var. Yığınlar yer dəyişir.
  - **Qarışıq-Ayırma** (`colour: true`): hər ucda hər ölçüdən bir disk var, rənglər qarışıqdır. Ölçü qaydası və "fərqli rəngli disklər toxunmur" qaydası birlikdə işləyir. Ən böyük cüt həmişə səhv ucda başlayır, yoxsa bu, sabit bazalı daha kiçik tapmaca olardı. Həlli olmayan başlanğıclar atılır.
  - Eyni ölçülü disklər üst-üstə qoyulmur. Qadağan gediş həmişə səbəbini status sətrində yazır: "böyük kiçiyin üstünə", "eyni ölçü" və ya "fərqli rənglər toxuna bilməz" (boz, cəza yoxdur).
  - Lövhələr 2026-10-14-də ölçülüb. Bir bufer heç vaxt həll olunmur. Ən çox 8 disk saxlanılır, çünki yoldan kənar Hint 6 qüllə / 8 diskdə kompüterdə 3,2 s-ə qədər çəkir, 5 qüllə / 10 diskdə 4,6 s, 6 qüllə / 10 diskdə 22 s. Uclardan başlayanda cəmi ~40 fərqli tapmaca var (təmiz növün hər lövhədə biri), ona görə Dünya 5-in 150 səviyyəlik fəsli üçün istifadəçi yarı yoldan başlanğıcları seçdi.
  - Hər alt-tipin öz bələdçisi var (`Level.lesson()`). Pillə gediş sayından gəlir. 6 qüllə də bir cərgədə qalır, disklərdə ölçü rəqəmi yazılır.
- **Yeni mexanikalar** ([spesifikasiya v1](../MindShift_Yeni_Mexanikalar_Detalli_Spesifikasiya_v1.md), istifadəçi cavabları 2026-10-15): hamısı klassik Hanoi + öz qaydasıdır, qayda həlli uzatmalıdır, yoxsa səviyyə alınmır. Qadağan gediş səbəbini status sətrində yazır. Pilotları fəsil sistemi ilə öz fəsillərinə çevrildi.
  - **Qeyri-Bərabər Tutum** (`peg_capacity`, `{"capacities": [5, 2, 2, 5]}`): hər qüllə öz sayı qədər disk tutur, dirək də o qədər hündürdür. 3 qüllədə tutum heç vaxt həlli dəyişmir (ən böyük diski köçürmək üçün qalanların hamısı onsuz da üçüncü qüllədə olmalıdır), ona görə 4 qüllə; 5 qüllə yavaş axtarılır və qısa qalır, ona görə yalnız 6 disklə. Tutum hər qüllədə başlanğıc və hədəfin tələbi + 0..slack-dır. Fəsil 51–100.
  - **Addımlı Kilidlənmə / Təməl Daşı** (`foundation`, `{"locked": [7, 6], "keys": [1, 2, 3], "targets": [1, 1, 1]}`): ən böyük 1–2 disk qıfıllıdır, ən kiçik 1–3 disk hədəf qüllələrinə çatana qədər. İstifadəçi qərarı: bir dəfə açılır, açıq qalır (qaydanın yaddaşında bir bit). Qıfıl disklərin üstündə çəkilir, status "Təməl: 2/3 kiçik disk yerindədir" yazır. Fəsil 201–300.
  - **Dövrəvi Hanoi / Saat Qülləsi** (`cyclic`): disk yalnız saat əqrəbi istiqamətində növbəti qülləyə gedir. Qüllələr siferblatın üstündə dairəvi düzülür, mərkəzdə ox var. Tanınmış dəyərlər yoxlanır: 3 disk qonşuya 15, o birinə 21 gediş. Fəsil 551–650 (Dünya 3).
  - **İkirəngli Hanoi / Zolaqlı Qüllə** (`stripes`): tək və cüt ölçülər iki rəngdədir, eyni rəng eyni rəngin üstünə qoyulmur. 3 qüllədə qüllədən qülləyə klassik həll onsuz da belədir. Fəsil 451–550.
  - **Tərəzi Hanoi / Qədim Tərəzi** (`balance`, `{"tolerance": 6}`): qüllələr cüt-cütdür (0–1, 2–3). İstifadəçi qərarı: hər mövqedə, başlanğıc və hədəf də daxil, cütün iki qülləsindəki ölçü cəmlərinin fərqi tolerantlığı keçmir. Təsadüfi mövqelər demək olar ki, heç vaxt taraz olmur, ona görə səviyyələr bütün taraz mövqelərin arasından seçilir. T 1–2-də heç vaxt maraqlı səviyyə alınmır (ölçülüb), istifadəçi qərarı: T fəsil boyu lövhənin işlək aralığında azalır. Fəsil 821–970.
    - **Tərəzi vizualı** ([v1.2](../MindShift_Fesil_Sistemi_v1.2.md), bölmə 5; [scripts/balance_scale.gd](scripts/balance_scale.gd)): hər cütün altında Roberval tipli tərəzi var. Platformalar üfüqi qalır, ağır tərəf aşağı enir, qüllə və disklər onunla birlikdə şaquli hərəkət edir.
      - Hərəkət yaylıdır: ~0,4 s-də sakitləşir, mərkəzdəki əqrəb də yellənir.
      - Altdakı 7-seqmentli LCD "FƏRQ x · HƏDD T" yazır: həddən aşağı yaşıl, həddə sarı, qadağan gedişdə iki dəfə qırmızı.
      - Qadağan gedişdə qol titrəyir və qısa "tık" səsi gəlir. Səviyyə bitəndə yumşaq zəng çalınır. Hər iki səs kodla sintez olunur (`SoundFx`).
      - Disk götürüləndə hər mümkün hədəfin üstündə yeni fərq ("→ 6") və ya həddi aşanlarda qırmızı "✕" görünür.
      - Rənglər `ThemeManager.MARK_COLORS`-dadır. 3 nümunə səviyyə pilot menyusundadır.
  - **Zəncirlənmiş Disklər** (`chain`, `{"disks": [2, 5]}`): iki disk yalnız birlikdə, bir gedişdə, iki fərqli hədəfə gedir. Ikisi də üstdə olmalıdır. Toxunuş ikisini də qaldırır, sonra əvvəl toxunulan diskin, sonra yoldaşının qülləsi seçilir. Faylda belə gediş dörd rəqəmdir: `[from, to, from_2, to_2]`. 3 qüllədə cüt demək olar ki, həmişə ilişir, ona görə 4 qüllə. Fəsil 1321–1470.
  - **Güzgü Hanoi, "Əks-səda"** (`mirror`, [v1.2](../MindShift_Fesil_Sistemi_v1.2.md), bölmə 6): iki lövhə var, oyunçu yalnız yuxarıda oynayır. Hər gediş aşağıda güzgüdəki kimi təkrarlanır (qüllə i ↔ n−1−i; 3 qüllədə 1↔3, 2↔2). Mümkün olmasa, aşağı lövhə yerində qalır. Hədəf: yuxarı öz hədəfinə çatır, aşağı onun əksi olur. Mühərrikdə bu, ümumi `echo_of` imkanıdır, Solver belə qaydaları generic axtarışla həll edir. Aşağı lövhə solğun və mavimtıldır, əks-səda 0,15 s gecikir, bloklanan əks-səda güzgü xəttini qırmızı yandırır və aşağı qüllənin üstündə "✕" göstərir. 5 pilot `prototype/pilots/`-dadır (`oyun.ps1 -Pilot`), hamısı "birləşmiş həll ≥ 1,3 × yuxarının tək həlli" filtrindən keçir. Fəsil (1471–1570) istifadəçinin pilot qərarından sonra qurulacaq.
  - **İz Qadağası / Qumlu Cığır** (`trail`, `{"disk": 1, "recent": 2}`): izli disk son iki dayandığı qülləyə qayıda bilməz, qumda iz qalır. Sənədin öz sözü ilə (bütün tarixçə) qayda 100 təsadüfi lövhədən yalnız 0–6-sında həlli dəyişirdi, həm də az. Sənəd "son N qüllə" seçimini builder-ə buraxıb. 3 qüllə, çünki 4 qüllədə yaddaş axtarışı dəqiqələrlə uzadırdı. Fəsil 1171–1270.
  - **Maqnit Hanoi** (`magnet`): qayda yazılıb və ölçülüb, fəsli 1771–1920-dir (Dünya 7). Ölçmə (kompüter, qüllədən qülləyə, 2026-10-15):
    - 3 qüllə, 3–7 disk: 11 / 30 / 83 / 236 / 687 gediş (klassik 7 / 15 / 31 / 63 / 127), hamısı 0,1 s-dən az. Təsadüfi mövqelər: 4 diskdə 9–30, 5 diskdə median 53.
    - 4 qüllə, 4–7 disk: 12 / 19 / 26 / 37 gediş, 0,03 / 0,14 / 0,7 / 11 s. Təsadüfi mövqelər 5 diskdə 3–11, 6 diskdə 8–18 (ən pis 0,4 s), 7 diskdə 12–24 (ən pis 3,2 s).
    - 5 qüllə, 5–6 disk: 15 / 20 gediş, 3,2 / 22 s.
    - Nəticə: əsas yol üçün (33 gedişə qədər, sürətli Hint) 3 qüllə / 3–4 disk və 4 qüllə / 4–6 disk uyğundur. 4 qüllə / 7 disk və 5 qüllə Hint üçün çox yavaşdır. 3 qüllə / 5+ disk isə əsas yol üçün çox uzundur (83+).
  - Yoldan kənar Hint kompüterdə ən çox 1,4 s çəkir (Təməl, 4 qüllə / 7 disk). Ən ağır ekspert səviyyəsi 1,6 s-dir.
- **Birləşmə Tapmacası (Water Sort)** 2026-10-15-də arxivə köçdü ([archive/water_sort/](archive/water_sort/README.md), `.gdignore`: Godot onu görmür). Kodu, testləri və 30 səviyyəsi orada durur, oyuna bağlı son commit `c376864`-dür.
- **Mədəni don** ([scripts/board_skin.gd](scripts/board_skin.gd), rənglər `ThemeManager.SKINS`-də): kodla çəkilir, şəkil faylı yoxdur.
  - Doqquz Halqa: jadeit yaşılı, damarlar və çubuqdan asılan doqquz halqa (Çin Doqquz Halqa).
  - Örtülü qüllə: ağac damarı və yosegi romb zolağı, qutunun özü də ağacdır (Yapon karakuri qutusu).
  - Karvan Yolu və Böyük Mübadilə: qum rəngi, təpələr, hər qüllənin altında karvansaray və onları birləşdirən qırıq cığır (İpək Yolu). Lövhə bunlar üçün qüllələrin altında zolaq saxlayır.
  - Qeyri-Bərabər Tutum: qumdaşı hörgü, qızılı zolaq (Brahma məbədinin müxtəlif hündürlükdə qüllələri). Təməl Daşı: iri boz daş bloklar.
  - Tərəzi: bazar piştaxtasının taxtaları, hər cütün altında tərəzi qolu. Qumlu Cığır: qum ləpələri, izlər.
  - Dövrəvi: gecə mavisi siferblat, 12 bölgü, saat əqrəbi istiqamətində ox. Zolaqlı Qüllə: bərbərxana sütunu kimi çəp zolaqlar. Zəncir: polad, yuxarıda zəncir halqaları. Güzgü: ağ mərmər, iki lövhə arasında güzgü xətti.
  - Lövhənin arxası, qüllələr, hədəf önizləməsi və xəritədəki dayanacağın halqası bu rəngdədir. Klassik səviyyələrin donu yoxdur.
- **Yenidən qurmaq:** `tools/road_builder.gd` (yuxarıda), sabit seed ilə, hər faylı validator yoxlayır.
- **Validator-un dizayn qaydaları:**
  - klassikdən əlavə hər qayda ən qısa həlli uzatmalıdır: onlardan hər hansı biri olmadan həll qısalır (kombinasiya hər iki moddan ayrı-ayrılıqda uzundur);
  - yolda hər səviyyə öz fəslinə uyğundur, kombinasiyalar plandakı siyahıdadır, ekspert yalnız adalarda, hər ada öz modunun ekspert səviyyələridir;
  - Böyük Mübadilə: `color_swap` tək qaydadır, uclar arasında ən azı 2 boş qüllə var, hər ucda hər ölçüdən bir disk (cütün o biri qarşı ucda), hədəf qaralar solda, ağlar sağda; təmiz növ ağlarla solda başlayır, qarışıq növün hər iki ucu qarışıqdır və ən böyük ağ disk soldadır;
  - örtülü qüllədə ən azı 2 disk olmalıdır;
  - örtülü qüllə həllin ilk 3 gedişində istifadə olunmalıdır;
  - Təməl Daşının qıfılı başlanğıcda bağlı olmalıdır, Zəncirin cütü həlldə ən azı bir dəfə tərpənməlidir.
### Yeni qayda əlavə etmək

1. `core/rules/` altında `RuleBase`-dən miras alan klas yazın:
   - qərar yalnız hərəkət edən diskdən, iki qüllədən və hədəf qüllənin üst diskindən asılıdırsa:
     `is_disk_move_allowed()` + `supports_disk_move_check() -> true` (Solver sürətli yolu istifadə edə bilir);
   - qərar sonuncu tərpənən diskdən də asılıdırsa: `uses_last_move() -> true` + `is_disk_move_allowed_after()` (Solver sonuncu diski axtarışa daxil edir);
   - daha çox vəziyyət məlumatı lazımdırsa: `is_move_allowed()` (Solver ümumi BFS-ə keçir);
   - mövqe məhdudiyyəti varsa: `is_state_valid()`;
   - bir neçə səbəbdən rədd edə bilirsə: `get_violation_message()` pozulan şərtin mətnini qaytarır;
   - qüllənin disk sayına, ölçü cəminə, diskin harada olduğuna baxırsa: `needs_facts() -> true` + `is_move_allowed_with(..., facts: MoveFacts)`;
   - mövqedən başqa bir şey xatırlamalıdırsa (açılmış qıfıl, izlər, üzlər): `uses_memory()`, `memory_states()`, `start_memory()`, `memory_after()` (`PuzzleState.memory`; bir qayda dəstində ən çox bir belə qayda);
   - iki disk yalnız birlikdə gedirsə: `partner_of()` (RuleSet və Solver birləşmiş `Move` yaradır);
   - lövhə bir-birinə disk verməyən hissələrə bölünürsə: `peg_groups()` (Solver hər hissəni ayrıca həll edir).
2. Onu `RuleSet.create_rule()` reyestrinə əlavə edin.
3. Görünüşü (düzülüş, disk rəngləri, dirəklər, mətnlər, işarələr) `scripts/board_dress.gd`-yə yazın. Lövhə özü mexanikanın adını çəkmir.

Solver-ə toxunmaq lazım deyil.

### Solver

`Solver.solve(start, goal, rules, max_states)` → `{ solvable, min_moves, path: Array[Move], states_visited, limit_reached, strategy }`.
Dörd strategiya var, hamısı BFS-dir və ən qısa yolu tapır:

- **packed**: qaydalar qüllələri sıralı saxlayırsa (klassik Hanoi), vəziyyət tam ədəd kimi kodlanır
  ("hər disk hansı qüllədədir") və axtarış iki tərəfdən aparılır. 4 qüllə / 8 disk ≈ 60 ms.
- **packed_history**: qaydalardan biri sonuncu tərpənən diskə baxırsa (Doqquz Halqa), yaddaş saxlayırsa, `MoveFacts` istəyirsə və ya disklər zəncirlidirsə, kod lazım olanı da daşıyır və axtarış bir tərəfli aparılır. Son disk açarda yalnız ona baxan qayda olanda saxlanır. 4 qüllə / 7 disk ≈ 0.8 s.
- **split**: lövhə hissələrə bölünürsə (Güzgü), hər hissə ayrıca həll olunur, yollar birləşir.
- **generic**: `PuzzleState` + `RuleSet.search_key()` üzərində standart BFS, istənilən qayda dəsti üçün.
  4 qüllə / 8 disk burada ≈ 15 s çəkir. Səbəb də sürətli yolun yaradılmasıdır.

## İrəliləyiş

| Gün | Mövzu | Status |
|---|---|---|
| 1 | Əsas data strukturu (`PuzzleState`, `Move`, `RuleBase`, `ClassicHanoiRule`, `RuleSet`) | ✅ |
| 2 | BFS Solver (4 qüllə / 8 disk: ~60 ms, limit 5 s) | ✅ |
| 3 | Səviyyə generatoru + validator (ilk versiya 4 × 50 səviyyə, hamısı yoxlanılıb) | ✅ |
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
| B-1 | Bonus: Dondurulmuş disk (`FrozenDiskRule`), 4 səviyyə ([əlavə sənəd 4](../MindShift_Bonus_Mechanics_Addendum.md)) | ✅ (Doqquz Halqa ilə əvəz olundu) |
| B-2 | Bonus: Örtülü qüllə (`PegFog`, yalnız vizual), 4 səviyyə | ✅ |
| B-3 | Bonus xanaları hər tabın sonunda (hədiyyə ikonu, həmişə açıq) | ✅ (v3 ilə əvəz olundu) |
| E-2.1 | İqtisadiyyat düsturları: 1/2/3 coin, reklam 4 coin, başlanğıc 20 coin ([əlavə](../MindShift_Economy_Formulas_Addendum.md)) | ✅ (v3 ilə əvəz olundu) |
| E-3 | Ulduzdan coin yerinə jeton → açar → sandıq, gündəlik bonus 2 coin, 6 coin paketi (25–1800) | ✅ |
| E-3.1 | Mədəni paket adları, 24 s limitsiz Hint $2.99, 3 mərhələli sandıq animasiyası, kodla sintez olunan "ding" | ✅ |
| M-1 | Karakuri qutuları (lay-lay açılma), 24 səviyyə bütün yol boyu | ✅ |
| M-2 | Doqquz Halqa (alternasiya, D variantı) dondurulmuş diskin yerinə | ✅ |
| M-3 | Karvan Yolu (30 səviyyə) və Böyük Mübadilə boss-ları (5) | ✅ |
| L-3 | Səviyyə yolu və xəritə, gizli ada, bonus kateqoriyasının ləğvi, 208 səviyyə yenidən, mədəni donlar ([əlavə](../MindShift_Level_Structure_Addendum.md)) | ✅ |
| P-1 | Prototip: rəng ardıcıllığı, eyni ölçülü rəngli disklər, gediş limiti (ayrıca səhnə, oyuna qoşulmayıb) | ✅ sınaqda |
| L-4 | Səviyyə strukturu v4: asan yalnız öyrənmə üçün, 51–200 arası 1:1 qarışıq; Birləşmə Tapmacası (30 səviyyə) ([əlavə](../MindShift_Level_Structure_v4_ve_Birlesme_Tapmacasi.md)) | ✅ |
| L-4.2 | Hər mexanikanın ilk səviyyəsində animasiyalı bələdçi (Dəyirman hələ yoxdur) | ✅ |
| M-4 | Böyük Mübadilə v2: iki alt-tip, 30 səviyyəlik fəsil, boss-lar ləğv; Birləşmədə Water Sort qaydası və qrup köçürmə ([əlavə](../MindShift_Boyuk_Mubadile_v2_ve_Birlesme_AutoGroup_Addendum.md)) | ✅ |
| M-5 | Birləşmə arxivə; 8 yeni mexanika, hər birinin 4 pilotu; Maqnit yalnız ölçülüb ([spesifikasiya v1](../MindShift_Yeni_Mexanikalar_Detalli_Spesifikasiya_v1.md)) | ✅ pilotlar sınaqda |
| UI-1 | Rejim etiketləri: xəritədə hər dayanacağın yanında rejim adı, lövhənin altında ad + qayda, tək registr ([sənəd](../MindShift_Rejim_Etiketleri_Xerite_ve_Qayda_Paneli.md)) | ✅ |
| F-1 | Fəsil sistemi: skelet + Dünya 1-2 (420 səviyyə), kombinasiyalar, hər fəslin adası ([sənəd](../MindShift_Fesil_Sistemi_v1.md)) | ✅ sınaqda |
| F-1.1 | Fəsil daxilində dalğalar: Dünya 1-2-də 11 alt-element, dişli çətinlik ([sənəd](../MindShift_Fesil_Daxili_Dalgalar_v1.md)) | ✅ sınaqda |
| F-1.2 | Fəsil Sistemi v1.2: Böyük Sınaq (34-65, tac), Boş qutuda şans qaydası söndürülüb ([sənəd](../MindShift_Fesil_Sistemi_v1.2.md)) | ✅ sınaqda |
| F-2 | Tərəzi vizualı (Roberval, LCD, önizləmə, səslər), Güzgü "Əks-səda" qaydası + 5 pilot | ✅ pilotlar sınaqda |
| F-3 | Dünya 3-7 (Bağlı Qüllələr gözləyir) | — |
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

### Rejim etiketləri

- **Mənbə:** bütün rejim mətnləri bir registrdədir ([scripts/mode_texts.gd](scripts/mode_texts.gd), `ModeTexts`). Hər rejim (`Level.lesson()`) üçün qısa xəritə etiketi, ad və bir cümləlik qayda var. Mətnlərin özü `locale/az.po`-dadır, hələ qurulmamış rejimlərinki də (Bağlı Qüllələr).
- **Xəritə:** hər dayanacağın yanında rejimin qısa adı yazılır (22 şrift, boz). Etiket dayanacağın hündürlüyündə, xəritənin ortasına baxan tərəfdə durur. Ada markeri olan dayanacaqda etiket o biri tərəfə keçir, heç bir tərəfdə yer yoxdursa dayanacağın altına düşür. Gizli adalarda ekspert pilləli səviyyələrə "· Ekspert" əlavə olunur (istifadəçi qərarı: yalnız onlara). Kombinasiya "Tutum + Kilid" kimi yazılır, paneldə də bu ad və iki qayda (3 sətrə qədər) görünür.
- **Lövhə:** status sətrinin altında iki hissə var: rejimin adı (qalın) və qaydası (540 px enində, ən çox 2 sətir). Tərəzinin qaydası səviyyənin həddini də göstərir. Status sətri müvəqqəti mesajlar üçün qalır: rədd səbəbi, irəliləyiş, Hint.
- **Testlər:**
  - yoldakı hər səviyyənin və `RuleSet.RULE_IDS`-dəki hər qaydanın registrdə qeydi olmalıdır;
  - hər qeydin üç mətni az.po-da olmalıdır;
  - adlar bir, qaydalar ən çox iki sətrə sığmalıdır;
  - etiketlər dayanacağa, ada markerinə toxunmamalı və xəritədən çıxmamalıdır.
- **Sənəddən fərqli mətnlər** (istifadəçi təsdiqləyib):
  - Klassik: "Diskləri hədəfdəki kimi düz…", çünki hədəf həmişə tək qüllə deyil.
  - Doqquz Halqa: "ondan sonra istənilən disk" hissəsi əlavə olundu (D variantı).
  - Cığır: "son iki dayandığı qülləyə", çünki qayda budur.

### 6B qeydləri

- Coaching primitivləri `scenes/components/coaching/`-dadır (Scrim, FocusRing, GhostPointer, CoachToast).
  Onları ayrıca görmək üçün redaktorda `coaching_demo.tscn` açıb F6 basın.
- Tutorial `easy_001`-də addım-addım, `easy_002`-də sərbəst rejimdə işləyir və yalnız səviyyə ilk dəfə tamamlanana qədər görünür.
- Hər mexanikanın əsas yoldakı ilk səviyyəsində ([v4 əlavəsi](../MindShift_Level_Structure_v4_ve_Birlesme_Tapmacasi.md), bölmə 2; karakuri 12, Karvan Yolu 17, Doqquz Halqa 20, Böyük Mübadilə 40, onun qarışıq növü 43, yeni mexanikaların hər biri öz fəslinin ilk yerində) eyni üsul işləyir. Zəncirin birləşmiş gedişi iki addımla göstərilir: əvvəl birinci diskin, sonra yoldaşının hədəfi.
  - Əvvəlcə ekranın yuxarısında mexanikanın öz izahı çıxır (5 saniyə).
  - Sonra ilk 3 gediş xəyali barmaqla göstərilir, yalnız göstərilən qüllə reaksiya verir.
  - Sonra "Əla! İndi özün sına!" və sərbəst oyun gəlir: yanlış gediş pozulan qaydanın mətnini göstərir.
  - Karakuri qutusu üçün əlavə addım lazım deyil: ilk gedişlər qutudan keçir, göstərilən qutuya toxunmaq onu açır.
  - Dəyirman / Bağlı Qüllələr hələ qurulmayıb, onun bələdçisi də yoxdur.
- Effekt parametrləri bir yerdədir: düymə `scripts/polished_button.gd`, keçid `scripts/screen_transition.gd`,
  disk bounce/kölgə `scenes/components/disk.gd`, konfeti `scripts/level_complete_popup.gd`, həlqə `focus_ring.gd`.
