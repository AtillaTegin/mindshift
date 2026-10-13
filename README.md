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
# generasiya (hər çətinliyin köhnə fayllarını əvəz edir; seed sabitdir, nəticə təkrarlanır)
godot --headless --path . --script res://tools/level_generator.gd -- --difficulty=all
godot --headless --path . --script res://tools/level_generator.gd -- --difficulty=medium --count=76 --seed=7
# mexanika səviyyələri və yol (generasiyadan sonra həmişə path_builder-i yenidən işə salın)
godot --headless --path . --script res://tools/mechanic_level_builder.gd
godot --headless --path . --script res://tools/path_builder.gd
# yoxlama (hər faylı Solver ilə yenidən həll edir, yolu da yoxlayır; --require=N hər çətinlikdə ən azı N klassik səviyyə tələb edir)
godot --headless --path . --script res://tools/level_validator.gd -- --require=16
```

Fayllar `data/levels/<çətinlik>/<çətinlik>_NNN.json` adlanır (asandan çətinə sıralanıb).
ID-lər: easy 1001+, medium 2001+, hard 3001+, expert 4001+. Çətinlik cədvəli [core/difficulty.gd](core/difficulty.gd)-dədir.

| Çətinlik | Gediş | Qüllə | Disk | Say |
|---|---|---|---|---|
| Easy | 5–11 | 3 | 3–4 | 16 |
| Medium | 12–20 | 3–4 | 5–6 | 76 |
| Hard | 21–33 | 4 | 7–8 | 74 |
| Expert | 34+ | 4 | 9–10 | 28 |

Asan: generator əvvəlki kimi 22 səviyyə çəkir, 3 disklilərdən yalnız ilk 4-ü qalır (səviyyə strukturu v4: 3 diskli asan yalnız yolun ilk 4 səviyyəsidir). Tutorial səviyyələri və 4 disklilər dəyişmir.

Üstəgəl 111 mexanika səviyyəsi (22 Doqquz Halqa, 24 karakuri, 30 Karvan Yolu, 5 Böyük Mübadilə boss-u, 30 Birləşmə Tapmacası): cəmi 305 səviyyə (915 ulduz).

Hard və Expert sətirləri sənəddəki ilkin cədvəldən fərqlənir: 4q/6d ilə maksimum 17, 4q/8d ilə 33, 5q/10d ilə 31 gediş mümkündür.
Gediş aralıqları əlavə sənəd 3-ün 1.1 bölməsinə görə yenidən tənzimlənib (köhnə: 3–8, 9–18, 19–35, 36+).

### Yol necə qurulur

[tools/path_builder.gd](tools/path_builder.gd) səviyyələri yola düzür (sabit seed, nəticə təkrarlanır), [səviyyə strukturu v4](../MindShift_Level_Structure_v4_ve_Birlesme_Tapmacasi.md)-ə görə:

- İlk 4 səviyyə 3 diskli klassik Asan-dır (öyrənmə), tutorial (1001, 1002) birinci gəlir. Sonra 4 diskli asanlar Orta-ya keçid olur. 50-ci səviyyədən sonra heç bir asan səviyyə yoxdur (nə klassik, nə mexanika).
- Fəsillər sabit yerdə başlayır (`PathBuilder.CHAPTER_STARTS`): karakuri 12, Karvan Yolu 17, Doqquz Halqa 20, Birləşmə Tapmacası 30. Böyük Mübadilə boss-ları 40, 80, 120, 160, 200-də, hər biri əvvəlkindən çətin.
- 50-yə qədər yalnız fəsillərin asan giriş səviyyələri gəlir. 51–200 arasında klassik və mexanika təxminən 1:1 növbələşir: təxminən hər iki yerdən birində mexanika olur, yeri seed ilə seçilir (nə sərt ritm, nə uzun blok). 200-dən sonra qalan mexanikalar seyrəlir, amma hər fəsil yolun sonuna qədər çatır.
- Hər mexanika yeri öz bərabər paylanmasından ən çox geri qalan fəslə verilir. Fəslin içində səviyyələr asandan çətinə gedir.
- Klassik yerlərdə çətinliklər çəki əyriləri ilə qarışdırılır: Asan yalnız əvvəldə, sonra Orta üstünlük təşkil edir, sonra Orta və Çətin qarışır, sona doğru Çətin artır. Hər addımda öz əyrisindən ən çox geri qalan çətinlik seçilir (az təsadüfi əlavə ilə).
- Builder sonda yolun çətinlik xəritəsini çap edir (E/M/H/X, mexanika kiçik hərflə).

### Mexanika səviyyələri

111 səviyyə [data/levels/mechanics/](data/levels/mechanics/)-dadır (22 Doqquz Halqa, 24 örtülü qüllə / karakuri, 30 Karvan Yolu, 5 Böyük Mübadilə, 30 Birləşmə Tapmacası). Onlar adi yol səviyyələridir: ardıcıl açılır, ulduz və jeton verir.

- **Faylların quruluşu:** ID-lər 9001-dən başlayır. `difficulty` gediş sayının düşdüyü çətinlikdir. Ölçü klassik cədvəldən fərqlənə bilər (Doqquz Halqa yalnız 4 qüllədə həlli etibarlı uzadır).
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
- **Böyük Mübadilə (variant E, boss):** `"boss": "great_exchange"`. 4 qüllə, hər ucda bir yığın (ağ və qara karvan), hədəf yığınların yer dəyişməsidir. Yeni qələbə yoxlaması lazım olmadı: səviyyələr onsuz da istənilən hədəf mövqeyi dəstəkləyir. Disklərin ölçüləri fərqlidir (mühərrik bərabər ölçülü disk tanımır), rəng isə karvanı göstərir. Bəziləri adi, bəziləri Karvan Yolu qaydası ilə: 17 → 20 → 22 → 29 → 33 gediş. Başlanğıcda boz izah mətni, xəritədə böyük, qızılı ikiqat halqalı dayanacaq.
- **Birləşmə Tapmacası** ([v4 əlavəsi](../MindShift_Level_Structure_v4_ve_Birlesme_Tapmacasi.md), bölmə 4, [düzəliş v2](../MindShift_Birlesme_Tapmacasi_Duzelis_v2.md)): bütün disklər eyni ölçüdədir, yalnız rəngləri fərqlidir. 7 rəngə qədər, hər birinin öz forması var: qırmızı dairə, göy kvadrat, sarı üçbucaq, yaşıl romb, bənövşəyi ulduz, narıncı altıbucaq, çəhrayı xaç. İstənilən disk istənilən diskin üstünə qoyula bilər, yeganə hədd qüllənin tutumudur (Water Sort kimi).
  - Format: `"rules": ["combination"]`, `"rule_params": {"combination": {"capacity": 4}}`, `"disk_colors": [...]` (disk id-sinin rəngi), `"color_goal"`. `goal` sahəsi saxlanmış həllin bitdiyi mövqedir.
  - Hədəf həmişə bütün diskləri əhatə edir. Hədəfdə olmayan rəng validatordan keçmir (düzəliş v2, xəta 1).
    - **Sadə Yığım** (`{"kind": "sort"}`): hər rəng öz qülləsinə yığılır, hansı qüllə olursa olsun. Önizləmədə taxtadakı bütün rənglər ikon sətri kimi görünür, altında "Hər rəng öz qülləsinə yığılmalıdır" yazılır.
    - **Konkret Kombinasiya** (`{"kind": "pattern", "pegs": [[...], [...], []]}`): hər qüllənin tam rəng sırası verilir, boş qüllə boş qalır. Yalnız şəkillə göstərilir. Önizləmə lövhə ilə eyni cərgə və sütunlarda çəkilir. Yerinə düşən disklər yaşıl haşiyə alır.
  - **Ölçülər yoldakı yerə görə mərhələ cədvəlindən gəlir** (`Difficulty.COMBINATION_STAGES`, düzəliş v2, xəta 2). Cədvəldə: N qüllənin tutumu, C rəng sayı (hər rəngdən N disk), E boş qüllə sayı, T = C + E.

    | Mərhələ | Yer | N | C | E | T | Disk |
    |---|---|---|---|---|---|---|
    | Giriş | ≤ 30 | 4 | 2 | 1 | 3 | 8 |
    | Orta-1 | 31–80 | 5 | 3 | 1 | 4 | 15 |
    | Orta-2 | 81–130 | 6 | 3–4 | 1–2 | 5–6 | 18–24 |
    | Çətin-1 | 131–200 | 7–8 | 4–5 | 2 | 6–7 | 28–40 |
    | Çətin-2 | 201–280 | 8–9 | 5–6 | 2–3 | 7–9 | 40–54 |
    | Ekspert | 280+ | 9–12 | 6–7 | 3–4 | 9–11 | 54–84 |

    - Mərhələ daxilində ölçü irəlilədikcə böyüyür, seed ilə müxtəliflik verilir. Ekspert mərhələsi əsas yolun sonundan (265) kənardadır.
    - Başlanğıc Water Sort-dakı kimidir: C dolu, E boş qüllə.
    - Pillə mərhələdən gəlir: Giriş asandır, Orta mərhələlər ortadır, Çətin mərhələlər çətindir.
    - Hədəf növləri: əvvəlki iki mərhələdə Sadə Yığım, Orta-2-də hər ikisi, sonra Konkret Kombinasiya.
  - **Həll və ulduzlar** (istifadəçi qərarı 2026-10-13): dəqiq minimum yalnız ≤10 diskdə hesablana bilir.
    - Builder hər səviyyəni yolun simulyasiyası ilə öz yerinə görə qurur ([tools/mechanic_level_builder.gd](tools/mechanic_level_builder.gd)).
    - Təsadüfi başlanğıc yalnız axtarış onun həllini tapanda saxlanır. ≤10 diskdə BFS işlədilir, ondan böyük lövhələrdə ağırlıqlı A*.
    - Həll faylda saxlanır və həll olunmanın sübutudur, validator onu yenidən oynayır.
    - `min_moves` bu nümunə həllin uzunluğudur. Lövhədə "Nümunə həll: N" yazılır. Ulduzlar ona görə verilir, oyunçu nümunədən də qısa həll tapa bilər.
  - Öz həlledicisi var ([core/combination_solver.gd](core/combination_solver.gd)), ölçüyə əsaslanan Solver-ə toxunulmayıb.
    - Hint qısa büdcəli A* ilə axtarılır. Tapılmasa, oyunçunu son gedişini geri alaraq nümunə həllin yoluna qaytarır.
  - 5-dən çox qüllə iki cərgədə dayanır, Water Sort-dakı kimi.
  - Eyni tapmacanın başqa rənglərdə təkrarı qadağandır.  - Don: "şüşə" (soyuq rəng, nöqtə şəbəkəsi). Bu fəsil şüurlu olaraq müasir, janrlar-arası fəsildir, mədəni kökü yoxdur.
- **Mədəni don** ([scripts/board_skin.gd](scripts/board_skin.gd), rənglər `ThemeManager.SKINS`-də): kodla çəkilir, şəkil faylı yoxdur.
  - Doqquz Halqa: jadeit yaşılı, damarlar və çubuqdan asılan doqquz halqa (Çin Doqquz Halqa).
  - Örtülü qüllə: ağac damarı və yosegi romb zolağı, qutunun özü də ağacdır (Yapon karakuri qutusu).
  - Karvan Yolu və Böyük Mübadilə: qum rəngi, təpələr, hər qüllənin altında karvansaray və onları birləşdirən qırıq cığır (İpək Yolu). Lövhə bunlar üçün qüllələrin altında zolaq saxlayır.
  - Lövhənin arxası, qüllələr, hədəf önizləməsi və xəritədəki dayanacağın halqası bu rəngdədir. Klassik səviyyələrin donu yoxdur.
- **Yenidən qurmaq** (sabit seed ilə, hər faylı validator yoxlayır):

  ```powershell
  godot --headless --path . --script res://tools/mechanic_level_builder.gd
  ```
- **Validator-un dizayn qaydaları:**
  - klassikdən əlavə qayda (Doqquz Halqa, Karvan Yolu) ən qısa həlli uzatmalıdır;
  - Böyük Mübadilə: 4 qüllə, hər ucda bir yığın, orta boş, hədəf yığınların yer dəyişməsi;
  - örtülü qüllədə ən azı 2 disk olmalıdır;
  - örtülü qüllə həllin ilk 3 gedişində istifadə olunmalıdır.
### Yeni qayda əlavə etmək

1. `core/rules/` altında `RuleBase`-dən miras alan klas yazın:
   - qərar yalnız hərəkət edən diskdən, iki qüllədən və hədəf qüllənin üst diskindən asılıdırsa:
     `is_disk_move_allowed()` + `supports_disk_move_check() -> true` (Solver sürətli yolu istifadə edə bilir);
   - qərar sonuncu tərpənən diskdən də asılıdırsa: `uses_last_move() -> true` + `is_disk_move_allowed_after()` (Solver sonuncu diski axtarışa daxil edir);
   - daha çox vəziyyət məlumatı lazımdırsa: `is_move_allowed()` (Solver ümumi BFS-ə keçir);
   - mövqe məhdudiyyəti varsa: `is_state_valid()`.
2. Onu `RuleSet.create_rule()` reyestrinə əlavə edin.

Solver-ə toxunmaq lazım deyil.

### Solver

`Solver.solve(start, goal, rules, max_states)` → `{ solvable, min_moves, path: Array[Move], states_visited, limit_reached, strategy }`.
Üç strategiya var, hamısı BFS-dir və ən qısa yolu tapır:

- **packed**: qaydalar qüllələri sıralı saxlayırsa (klassik Hanoi), vəziyyət tam ədəd kimi kodlanır
  ("hər disk hansı qüllədədir") və axtarış iki tərəfdən aparılır. 4 qüllə / 8 disk ≈ 60 ms.
- **packed_history**: qaydalardan biri sonuncu tərpənən diskə baxırsa (Doqquz Halqa), kod o diski də daşıyır və axtarış bir tərəfli aparılır. 4 qüllə / 7 disk ≈ 0.6 s.
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
- Hər mexanikanın əsas yoldakı ilk səviyyəsində ([v4 əlavəsi](../MindShift_Level_Structure_v4_ve_Birlesme_Tapmacasi.md), bölmə 2; karakuri 12, Karvan Yolu 17, Doqquz Halqa 20, Birləşmə 30, Böyük Mübadilə 40) eyni üsul işləyir.
  - Əvvəlcə ekranın yuxarısında mexanikanın öz izahı çıxır (5 saniyə).
  - Sonra ilk 3 gediş xəyali barmaqla göstərilir, yalnız göstərilən qüllə reaksiya verir.
  - Sonra "Əla! İndi özün sına!" və sərbəst oyun gəlir: yanlış gediş pozulan qaydanın mətnini göstərir.
  - Karakuri qutusu üçün əlavə addım lazım deyil: ilk gedişlər qutudan keçir, göstərilən qutuya toxunmaq onu açır.
  - Dəyirman / Bağlı Qüllələr hələ qurulmayıb, onun bələdçisi də yoxdur.
- Effekt parametrləri bir yerdədir: düymə `scripts/polished_button.gd`, keçid `scripts/screen_transition.gd`,
  disk bounce/kölgə `scenes/components/disk.gd`, konfeti `scripts/level_complete_popup.gd`, həlqə `focus_ring.gd`.
