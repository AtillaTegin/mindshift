class_name GameBoard
extends Control
## Game board screen (spec 5.3): pegs, disks, goal preview, move counter,
## coins, hint and undo. Tap a peg to pick up its top disk, tap another peg to
## move it there. Hints and the tutorial draw on the shared coaching overlay.

signal level_completed(level: Level, moves: int, seconds: float)
## A level was opened or restarted (emitted before position_changed).
signal level_started
## The position changed (move, undo, restart or a new level).
signal position_changed
## Pegs and disks were placed again (new position or new screen size).
signal layout_changed
## A disk was picked up (peg index) or put back (-1).
signal selection_changed(peg_index: int)
## A move was refused by the rules; `message` is the broken rule's text.
signal illegal_move(move: Move, message: String)
## The top disk of `peg_index` may not be picked up now (a rule holds it back).
signal pick_up_refused(peg_index: int, message: String)

const PEG_SCENE: PackedScene = preload("res://scenes/components/peg.tscn")
const DISK_SCENE: PackedScene = preload("res://scenes/components/disk.tscn")
const POPUP_SCENE: PackedScene = preload("res://scenes/level_complete_popup.tscn")
const COACHING_SCENE: PackedScene = preload("res://scenes/components/coaching/coaching_layer.tscn")
const PEG_FOG_SCENE: PackedScene = preload("res://scenes/components/peg_fog.tscn")
const MAX_DISK_HEIGHT: float = 52.0
## How long Güzgü's echo on the bottom board waits after the player's move.
const ECHO_DELAY: float = 0.15

## Level loaded in _ready() unless the App autoload asks for another one.
@export_file("*.json") var level_path: String = "res://data/levels/easy/easy_001.json"
## Where results are recorded; taken from the App autoload when left empty.
var save_system: SaveSystem
## Pays for hints and undos; taken from the App autoload when left empty.
var economy: EconomySystem
## Off-path hints are searched on a worker thread so the screen never freezes
## (an Expert search can take a few seconds on a phone). Tests turn it off.
var background_hints: bool = true
## Coaching on the first two levels (tests of other features turn it off).
var tutorials_enabled: bool = true
## Fade through ScreenTransition when "next level" swaps the board (tests turn it off).
var animate_transitions: bool = true
## Restricted input (addendum 2.2): when >= 0, only this peg reacts to taps and
## the hint, undo and restart buttons are off.
var restricted_peg: int = -1:
	set(value):
		restricted_peg = value
		_update_buttons()

var session: GameSession
## Result of the last completion: { stars, improved, tokens, keys, chests }
## (EconomySystem.add_tokens: keys earned, coins of each chest opened).
var last_result: Dictionary = {}
var coaching: CoachingLayer
var hints: HintController
var tutorial: TutorialDirector
## The dead-end rule (Mod Kataloqu v1.1, D.3): on levels that can dead-end.
var dead_ends: DeadEndWatcher

var _popup: LevelCompletePopup
## Short notice in the status line (e.g. not enough coins), cleared by the next action.
var _message: String = ""
## The notice is a gentle rule reminder (grey), not a warning (red).
var _message_soft: bool = false
var _peg_views: Array[PegView] = []
## Disk size -> view.
var _disk_views: Dictionary[int, DiskView] = {}
## Disk size -> where the disk is (or is gliding to), in board coordinates.
var _disk_targets: Dictionary[int, Rect2] = {}
## Peg index -> peg area (rod, base and the space for a lifted disk), board coordinates.
var _peg_areas: Array[Rect2] = []
## Karakuri boxes (covered pegs): peg index -> its box (PegFog), drawn on a
## layer above the disks.
var _fogs: Dictionary[int, PegFog] = {}
var _fog_layer: Control
## The balance scales of a Tərəzi level (hidden on other levels).
var _scale: BalanceScale
## Dress of a level with a special mechanic, behind the pegs.
var _board_skin: BoardSkin
## A mechanic's marks over the disks (a chain, locks), above them.
var _marks: BoardMarks
## Coins of a chest that are still flying to the counter (shown once they land).
var _coins_in_flight: int = 0
## The level's looks (BoardDress), kept for the layout: disk palette, peg
## layout kind, the most disks a peg can hold, and each rod's own room (empty:
## every rod is _stack tall).
var _palette: Dictionary = {}
var _layout_kind: String = BoardLayout.ROW
var _stack: int = 1
var _rod_rooms: Array[int] = []
## Where each peg's cell is on the board, from the last layout pass.
var _cells: Array[Rect2] = []

@onready var _level_label: Label = %LevelLabel
@onready var _moves_label: Label = %MovesLabel
## Count-up stopwatch (economy/UX addendum, section 2). Not the same thing as a
## level's time_limit_seconds countdown (none in v1; kept for a later
## "against the clock" mode, which would get its own label).
@onready var _time_label: Label = %TimeLabel
@onready var _min_label: Label = %MinLabel
@onready var _status_label: Label = %StatusLabel
## The mode's name (bold) and one-sentence rule under the board (mode labels
## specification v1, section 2; texts from ModeTexts).
@onready var _rule_name: Label = %RuleName
@onready var _rule_text: Label = %RuleText
@onready var _variant_text: Label = %VariantText
@onready var _goal_preview: BoardPreview = %GoalPreview
@onready var _board: Control = %Board
@onready var _peg_layer: Control = %PegLayer
@onready var _disk_layer: Control = %DiskLayer
@onready var _restart_button: Button = %RestartButton
@onready var _back_button: Button = %BackButton
@onready var _coin_label: Label = %CoinLabel
@onready var _coin_icon: Control = %CoinIcon
@onready var _hint_button: Button = %HintButton
@onready var _undo_button: Button = %UndoButton
## Beside the status line, only in a dead end: the free way back.
@onready var _way_back_button: Button = %WayBackButton
## Beside the status line on a level whose weight stone may be carried over
## (the Tərəzi island's "Hərəkətli daş"), while it still may.
@onready var _stone_button: Button = %StoneButton


func _ready() -> void:
	var app: Node = get_node_or_null("/root/App")
	if save_system == null:
		save_system = app.save if app != null else SaveSystem.new()
	if economy == null:
		if app != null and app.save == save_system:
			economy = app.economy
		else:
			economy = EconomySystem.new()
			economy.setup(save_system)
			add_child(economy)
	economy.coins_changed.connect(func(_coins: int) -> void: _update_buttons())
	economy.allowances_changed.connect(_update_buttons)
	coaching = COACHING_SCENE.instantiate()
	add_child(coaching)
	hints = HintController.new()
	hints.name = "HintController"
	hints.background = background_hints
	hints.setup(self, coaching, economy)
	hints.message_changed.connect(show_message)
	add_child(hints)
	tutorial = TutorialDirector.new()
	tutorial.name = "TutorialDirector"
	tutorial.enabled = tutorials_enabled
	tutorial.setup(self, coaching, save_system)
	add_child(tutorial)
	dead_ends = DeadEndWatcher.new()
	dead_ends.name = "DeadEndWatcher"
	dead_ends.background = background_hints
	dead_ends.setup(self)
	dead_ends.changed.connect(_on_dead_end_changed)
	add_child(dead_ends)
	_way_back_button.pressed.connect(request_way_back)
	_stone_button.pressed.connect(request_special_move)
	var bold: FontVariation = FontVariation.new()
	bold.base_font = _rule_name.get_theme_default_font()
	bold.variation_embolden = 0.8
	_rule_name.add_theme_font_override("font", bold)
	_hint_button.pressed.connect(request_hint)
	_undo_button.pressed.connect(request_undo)
	_restart_button.pressed.connect(restart)
	_back_button.pressed.connect(_show_level_select)
	_board.resized.connect(_layout.bind(false))
	_board_skin = BoardSkin.new()
	_board_skin.name = "BoardSkin"
	_board_skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(_board_skin)
	_board.move_child(_board_skin, 0)
	# Tərəzi levels: the balance scales under the pegs (behind them).
	_scale = BalanceScale.new()
	_scale.name = "BalanceScale"
	_scale.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scale.visible = false
	_board.add_child(_scale)
	_board.move_child(_scale, 1)
	_fog_layer = Control.new()
	_fog_layer.name = "FogLayer"
	_fog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(_fog_layer)
	_marks = BoardMarks.new()
	_marks.name = "BoardMarks"
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(_marks)
	_popup = POPUP_SCENE.instantiate()
	_popup.visible = false
	_popup.next_requested.connect(play_next_level)
	_popup.replay_requested.connect(restart)
	_popup.levels_requested.connect(_show_level_select)
	_popup.chest_coins_landed.connect(_on_chest_coins_landed)
	add_child(_popup)
	var pending: Dictionary = app.take_pending_level() if app != null else {}
	if not pending.is_empty():
		var level: Level = LevelCatalog.load_at(pending["track"], pending["position"])
		if level != null:
			start_level(level)
			return
	if not level_path.is_empty():
		load_level_file(level_path)


func _process(delta: float) -> void:
	if session != null:
		session.add_time(delta)
		_update_clock()


func _update_clock() -> void:
	var text: String = GameSession.format_clock(session.elapsed_seconds)
	if _time_label.text != text:
		_time_label.text = text


func load_level_file(path: String) -> bool:
	var errors: Array[String] = []
	var level: Level = Level.load_file(path, errors)
	if level == null:
		_status_label.text = tr("BOARD_LOAD_FAILED")
		push_error("Cannot load level %s: %s" % [path, "; ".join(errors)])
		return false
	level_path = path
	start_level(level)
	return true


func start_level(level: Level) -> void:
	session = GameSession.new(level)
	last_result = {}
	_message = ""
	_release_chest()
	_popup.visible = false
	_board_skin.skin = ThemeManager.skin_for(level.mechanic())
	_board_skin.peg_count = level.get_peg_count()
	_build_views()
	_scale.visible = level.rule_ids.has(BalanceRule.ID)
	if _scale.visible:
		_scale.sound_on = save_system.sound_enabled
		_scale.peg_views = _peg_views
		_scale.disk_views = _disk_views
		_scale.rule = _balance_rule(level)
		_scale.show_position(level.start, _tolerance(level), true)
	_goal_preview.skin = _board_skin.skin
	_goal_preview.layout_kind = BoardDress.layout_kind(level)
	_goal_preview.stack_room = BoardDress.stack_room(level)
	_goal_preview.rod_rooms = BoardDress.rod_rooms(level)
	_goal_preview.disk_palette = _palette
	_goal_preview.disk_total = level.get_disk_count()
	_goal_preview.gates = BoardDress.goal_gates(level)
	_goal_preview.silhouette = BoardDress.goal_silhouette(level)
	_goal_preview.position_state = BoardDress.goal_view(level)
	_level_label.text = LevelCatalog.level_title(level)
	_min_label.text = tr("BOARD_MINIMUM") % level.min_moves
	_rule_name.text = ModeTexts.name_of(level)
	_rule_text.text = ModeTexts.rule_of(level)
	# The sub-elements' rules under the mode's (chapter waves v1).
	_variant_text.text = ModeTexts.variants_of(level)
	_variant_text.visible = not _variant_text.text.is_empty()
	_show_goal_words()
	_refresh(false)
	level_started.emit()
	position_changed.emit()


func restart() -> void:
	if session == null:
		return
	session.restart()
	last_result = {}
	_message = ""
	_release_chest()
	_popup.visible = false
	_show_goal_words()
	_refresh(true)
	level_started.emit()
	position_changed.emit()


## A note before the first move, on every attempt (BoardDress.goal_text, e.g.
## the foundation's keys in place); the mode's rule itself stands in the rule
## panel. The caller refreshes.
func _show_goal_words() -> void:
	var words: String = BoardDress.goal_text(session.level)
	if words.is_empty():
		return
	_message = words
	_message_soft = true


## Spec 4.7 hint, shown by the HintController on the coaching overlay.
func request_hint() -> void:
	if session != null and not session.is_solved():
		hints.request()


## Takes back the last move. The first EconomySystem.FREE_UNDOS_PER_DAY undos
## of a day are free (over all levels), later ones cost EconomySystem.UNDO_COST.
func request_undo() -> void:
	if session == null or not session.can_undo():
		return
	if not economy.pay_for_undo():
		show_message(tr("BOARD_UNDO_NO_COINS"))
		return
	session.undo()
	_message = ""
	_refresh(true)
	position_changed.emit()


## The dead-end rule's free way back (no coins, not counted as an undo): to the
## last position from which the level can still be solved.
func request_way_back() -> void:
	if session == null or not dead_ends.is_dead() or restricted_peg >= 0:
		return
	session.rewind_to(dead_ends.way_back())
	_message = ""
	_refresh(true)
	position_changed.emit()


## The level's special move now (RuleBase.special_moves: the weight stone
## carried to the other pan), or null.
func special_move() -> Move:
	if session == null or session.is_solved():
		return null
	var facts: MoveFacts = MoveFacts.of(session.state, session.rules)
	for rule: RuleBase in session.rules.active_rules:
		var moves: Array[Move] = rule.special_moves(facts)
		if not moves.is_empty():
			return moves[0]
	return null


## Plays the special move (the stone's button), like any move; where the
## scale cannot take it now, it is refused like a disk move.
func request_special_move() -> void:
	if session == null:
		return
	# A guided step that is the stone's own move keeps its button open.
	var guided: bool = tutorial != null and tutorial.step_move != null and tutorial.step_move.from_peg == tutorial.step_move.to_peg
	if restricted_peg >= 0 and not guided:
		return
	var move: Move = special_move()
	if move == null or not session.try_move(move):
		var rule: BalanceRule = _balance_rule(session.level)
		if rule != null and _scale.visible:
			_scale.refuse(rule.stone_pan())
		show_message(tr("RULE_BALANCE"), true)
		return
	_message = ""
	_refresh(true)
	position_changed.emit()
	if session.is_solved():
		_on_solved()


## The stone's button, in viewport coordinates.
func get_stone_button_rect() -> Rect2:
	return _stone_button.get_global_rect()


## A dead end was found (its words replace any older note) or left.
func _on_dead_end_changed() -> void:
	if session == null:
		return
	if dead_ends.is_dead():
		_message = ""
	_show_status()
	_update_buttons()


## Opens the level after the current one on its track of the level path.
func play_next_level() -> void:
	var next: Dictionary = _next_level()
	if next.is_empty():
		return
	var level: Level = LevelCatalog.load_at(next["track"], next["position"])
	if level == null:
		return
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.map_track = next["track"]
		app.map_focus = next["position"]
	var transition: Node = get_node_or_null("/root/ScreenTransition")
	if animate_transitions and transition != null:
		transition.run(start_level.bind(level))
	else:
		start_level(level)


func get_popup() -> LevelCompletePopup:
	return _popup


## Shows a short notice in the status line until the next action; `soft` for a
## rule reminder that should not look like a mistake.
func show_message(text: String, soft: bool = false) -> void:
	_message = text
	_message_soft = soft
	if session != null:
		_refresh(false)


## Where disk `disk_size` is drawn (or is gliding to), in viewport coordinates.
func get_disk_rect(disk_size: int) -> Rect2:
	var rect: Rect2 = _disk_targets.get(disk_size, Rect2())
	return Rect2(rect.position + _board.global_position, rect.size)


## The area of peg `peg_index`: its rod and base plus the room above it where a
## picked-up disk hovers, in viewport coordinates.
func get_peg_rect(peg_index: int) -> Rect2:
	if peg_index < 0 or peg_index >= _peg_areas.size():
		return Rect2()
	var rect: Rect2 = _peg_areas[peg_index]
	return Rect2(rect.position + _board.global_position, rect.size)


## The Hint button, in viewport coordinates.
func get_hint_button_rect() -> Rect2:
	return _hint_button.get_global_rect()


## The fog over covered peg `peg_index`, or null if that peg never had one.
func get_peg_fog(peg_index: int) -> PegFog:
	return _fogs.get(peg_index)


func get_board_skin() -> BoardSkin:
	return _board_skin


## Handles a tap on peg `peg_index` (also the entry point for tests).
func on_peg_pressed(peg_index: int) -> void:
	if session == null or (restricted_peg >= 0 and peg_index != restricted_peg):
		return
	var selected_before: int = session.selected_peg
	var target_move: Move = Move.new(session.selected_peg, peg_index)
	# The last target of a linked group completes a compound move.
	var pegs: Array[int] = session.get_selected_pegs()
	if pegs.size() > 1 and session.pending_targets.size() == pegs.size() - 1:
		var targets: Array[int] = session.pending_targets.duplicate()
		targets.append(peg_index)
		target_move = Move.of_parts(pegs, targets)
	var result: GameSession.TapResult = session.tap_peg(peg_index)
	if result != GameSession.TapResult.IGNORED:
		_message = ""
	_refresh(true)
	match result:
		GameSession.TapResult.ILLEGAL:
			_peg_views[peg_index].flash_invalid()
			if _scale.visible:
				_scale.refuse(peg_index)
			var reason: String = tr(BoardDress.refusal_key(session.level, session.rules.get_violation_message(session.state, target_move)))
			# Some mechanics say which condition the move broke (e.g. the great
			# exchange v2: never a silent refusal); soft, nothing is punished.
			if BoardDress.says_why(session.level):
				show_message(reason, true)
			illegal_move.emit(target_move, reason)
		GameSession.TapResult.TARGETED:
			# The partner's target comes next (a coach follows the selection).
			show_message(tr("CHAIN_SECOND_TARGET"), true)
			selection_changed.emit(session.selected_peg)
		GameSession.TapResult.MOVED:
			# Güzgü: an echo that could not happen shows over its bottom peg.
			if session.echo_blocked:
				var half: int = session.state.get_peg_count() / 2
				_marks.flash_cross(MirrorRule.mirror_peg(session.history[-1].to_peg, half))
			# A mechanic's progress note (e.g. the foundation's keys in place).
			var note: String = BoardDress.progress_text(session)
			if not note.is_empty() and not session.is_solved():
				show_message(note, true)
			position_changed.emit()
			if session.is_solved():
				_on_solved()
		GameSession.TapResult.BLOCKED:
			_disk_views[session.state.get_top_disk(peg_index)].wobble()
			var message: String = tr(BoardDress.refusal_key(session.level, session.rules.get_pick_up_violation_message(session.state, peg_index)))
			# A held-back disk is no mistake to scold (cultural addendum 1: no punishment).
			show_message(message, true)
			pick_up_refused.emit(peg_index, message)
	if session.selected_peg != selected_before:
		selection_changed.emit(session.selected_peg)


## The limit of a Tərəzi level (its BalanceRule's tolerance), 0 for others.
static func _tolerance(level: Level) -> int:
	var rule: BalanceRule = _balance_rule(level)
	return rule.tolerance if rule != null else 0


## A Tərəzi level's rule (its stone, long arms and limits), or null.
static func _balance_rule(level: Level) -> BalanceRule:
	for rule: RuleBase in level.get_rule_set().active_rules:
		if rule is BalanceRule:
			return rule
	return null


## The level after this one on its track: {track, position}, or {} after the
## last one (and for a level that is not on the path).
func _next_level() -> Dictionary:
	var place: Dictionary = LevelCatalog.place_of(session.level.id)
	return {} if place.is_empty() else LevelCatalog.next_after(place["track"], place["position"])


## Back to the level map, centred on this level.
func _show_level_select() -> void:
	var app: Node = get_node_or_null("/root/App")
	if app == null:
		return
	var place: Dictionary = LevelCatalog.place_of(session.level.id) if session != null else {}
	app.show_level_select(place.get("track", ""), place.get("position", 0))


## Spec 4.6/4.9: stars from the move count, saved right away, chest tokens for
## the stars gained over the best result so far (formulas addendum v3: no coins
## for playing well), then the popup with any key, chest or island news.
func _on_solved() -> void:
	var level: Level = session.level
	var stars: int = level.stars_for_moves(session.move_count)
	var previous_stars: int = save_system.get_stars(level.id)
	var islands_open: int = LevelCatalog.open_islands(save_system).size()
	if _scale.visible:
		_scale.ring()
	var improved: bool = save_system.record_completion(level.id, stars, session.move_count, session.elapsed_seconds)
	var chest: Dictionary = economy.add_tokens(EconomySystem.level_tokens(stars, previous_stars))
	last_result = {"stars": stars, "improved": improved, "tokens": chest["tokens"], "keys": chest["keys"],
			"chests": chest["chests"]}
	_popup.show_result(stars, session.move_count, level.min_moves, session.elapsed_seconds,
			improved, not _next_level().is_empty(), chest["tokens"])
	# A chest opens on screen after the stars (formulas v3.1); its coins join the
	# counter when the flying coin lands there.
	var chests: Array[int] = chest["chests"]
	if not chests.is_empty():
		_coins_in_flight = chests[0]
		_update_buttons()
		_popup.show_chest(chests[0], _board_skin.skin, _coin_icon.get_global_rect().get_center(), save_system.sound_enabled)
	var notes: PackedStringArray = PackedStringArray()
	if chest["keys"] > 0 and chests.is_empty():
		notes.append(tr("POPUP_KEY") % [economy.keys(), EconomySystem.KEYS_PER_CHEST])
	# An island appears as a surprise (level structure addendum v3, one at the
	# end of each chapter since the chapter system): say so once.
	if LevelCatalog.open_islands(save_system).size() > islands_open:
		notes.append(tr("POPUP_ISLAND_OPENED"))
	_popup.set_note("\n".join(notes))
	level_completed.emit(level, session.move_count, session.elapsed_seconds)


func _on_chest_coins_landed(_coins: int) -> void:
	_coins_in_flight = 0
	_update_buttons()
	_coin_icon.pivot_offset = _coin_icon.size * 0.5
	var pop: Tween = create_tween()
	pop.tween_property(_coin_icon, "scale", Vector2(1.5, 1.5), 0.09)
	pop.tween_property(_coin_icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The player moved on before a chest finished: its coins count at once.
func _release_chest() -> void:
	_popup.stop_chest()
	_coins_in_flight = 0


## Under a rule that looks at the last move (the Nine Rings alternation) the
## top disks that may go right now wear a ring.
func _update_rings() -> void:
	var watch: bool = session.rules.uses_last_move() and not session.is_solved()
	var facts: MoveFacts = MoveFacts.of(session.state, session.rules) if watch else null
	for peg_index: int in session.state.get_peg_count():
		var top: int = session.state.get_top_disk(peg_index)
		for disk: int in session.state.pegs[peg_index]:
			_disk_views[disk].movable_ring = watch and disk == top and session.rules.is_disk_movable_with(disk, facts)


func _update_buttons() -> void:
	if session == null or not is_node_ready():
		return
	var locked: bool = restricted_peg >= 0
	# The coin icon next to it says what the number is.
	_coin_label.text = str(economy.coins - _coins_in_flight)
	_hint_button.disabled = locked or session.is_solved() or hints.is_pending()
	if economy.has_unlimited_hints():
		_hint_button.text = tr("BOARD_HINT_UNLIMITED")
	else:
		_hint_button.text = tr("BOARD_HINT") % economy.hint_cost(session.level.difficulty)
	_undo_button.disabled = locked or not session.can_undo()
	_way_back_button.visible = dead_ends.is_dead() and not session.is_solved()
	_way_back_button.disabled = locked
	# Until the stone has been carried over or the pass is spent (the rule's memory).
	var facts: MoveFacts = MoveFacts.of(session.state, session.rules)
	_stone_button.visible = false
	for rule: RuleBase in session.rules.active_rules:
		if rule.has_special_moves() and rule.special_open(facts) and not session.is_solved():
			_stone_button.visible = true
			_stone_button.text = rule.special_label()
	_stone_button.disabled = locked
	_restart_button.disabled = locked
	var free_left: int = economy.free_undos_left()
	if free_left > 0:
		_undo_button.text = tr("BOARD_UNDO_FREE") % free_left
	else:
		_undo_button.text = tr("BOARD_UNDO_PAID") % EconomySystem.UNDO_COST


func _build_views() -> void:
	for layer: Control in [_peg_layer, _disk_layer]:
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_peg_views.clear()
	_disk_views.clear()
	_disk_targets.clear()
	_peg_areas.clear()
	for fog: PegFog in _fogs.values():
		_fog_layer.remove_child(fog)
		fog.queue_free()
	_fogs.clear()
	for peg_index: int in session.level.covered_pegs:
		var fog: PegFog = PEG_FOG_SCENE.instantiate()
		fog.skin = _board_skin.skin
		_fog_layer.add_child(fog)
		_fogs[peg_index] = fog
	var disk_count: int = session.state.get_disk_count()
	var palette: Dictionary = BoardDress.disk_palette(session.level)
	_palette = palette
	_marks.disk_views = _disk_views
	_layout_kind = BoardDress.layout_kind(session.level)
	_stack = BoardDress.stack_room(session.level)
	_rod_rooms = BoardDress.rod_rooms(session.level)
	for peg_index: int in session.state.get_peg_count():
		var peg: PegView = PEG_SCENE.instantiate()
		peg.peg_index = peg_index
		peg.skin = _board_skin.skin
		peg.pressed.connect(on_peg_pressed)
		_peg_layer.add_child(peg)
		_peg_views.append(peg)
	for peg: Array in session.state.pegs:
		for disk_size: int in peg:
			var disk: DiskView = DISK_SCENE.instantiate()
			disk.disk_size = disk_size
			disk.color = ThemeManager.disk_color(disk_size, disk_count)
			if palette.has(disk_size):
				disk.color = palette[disk_size]["fill"]
				disk.number_color = palette[disk_size]["text"]
				disk.outline_color = palette[disk_size].get("outline")
				disk.label = palette[disk_size].get("label", 0)
			disk.ring_color = ThemeManager.skin_color(_board_skin.skin, "mark") if not _board_skin.skin.is_empty() \
					else ThemeManager.color("accent")
			disk.glass = session.level.glass_disks.has(disk_size)
			_disk_layer.add_child(disk)
			_disk_views[disk_size] = disk


func _refresh(animated: bool) -> void:
	_moves_label.text = tr("BOARD_MOVES") % session.move_count
	_update_clock()
	_show_status()
	for peg: PegView in _peg_views:
		peg.highlighted = peg.peg_index == session.selected_peg
	_board_skin.marks = BoardDress.skin_marks(session)
	_marks.marks = BoardDress.overlay_marks(session)
	# Zolaqlı's paint peg: a painted disk takes its new colour, the pot drips.
	var now: Dictionary = BoardDress.disk_palette_now(session)
	for disk: int in now:
		if _disk_views.has(disk) and _disk_views[disk].color != now[disk]["fill"]:
			_disk_views[disk].color = now[disk]["fill"]
			_disk_views[disk].number_color = now[disk]["text"]
			_disk_views[disk].outline_color = now[disk].get("outline")
			if animated:
				_marks.flash_paint()
	if _scale.visible:
		_scale.show_position(session.state, _tolerance(session.level), false, session.rules.memory_of(session.state))
		_scale.show_preview(session.selected_peg, session.get_selected_disk())
	_update_rings()
	_update_buttons()
	_layout(animated)


## The status line: solved, the current note, else in a dead end its kind
## words (a gentle grey, nobody loses).
func _show_status() -> void:
	if session.is_solved():
		_status_label.text = tr("BOARD_SOLVED") % [session.move_count, session.level.min_moves]
		_status_label.theme_type_variation = &"SuccessLabel"
	elif _message.is_empty() and dead_ends.is_dead():
		_status_label.text = tr("DEAD_END")
		_status_label.theme_type_variation = &"SecondaryLabel"
	else:
		_status_label.text = _message
		_status_label.theme_type_variation = &"SecondaryLabel" if _message_soft else &"DangerLabel"


## Places pegs and disks for the current board size and position.
func _layout(animated: bool) -> void:
	if session == null or _peg_views.is_empty():
		return
	var peg_count: int = session.state.get_peg_count()
	var disk_count: int = maxi(session.state.get_disk_count(), 1)
	# The dress may keep a strip under the pegs free (the caravan road's stops).
	var floor_room: float = _board_skin.bottom_room()
	# Never below zero: before the first layout pass the board has no size yet,
	# and a coach pointing at a peg then must not get a negative area.
	var area: Vector2 = Vector2(_board.size.x, maxf(_board.size.y - floor_room, 0.0))
	_cells = BoardLayout.peg_cells(_layout_kind, peg_count, area)
	var cell_height: float = _cells[0].size.y
	# Room for the fullest peg there can be plus the lifted disk above the rod.
	var disk_height: float = minf(cell_height / (_stack + (2.6 if BoardLayout.is_compact(_layout_kind) else 3.5)),
			MAX_DISK_HEIGHT)
	var base_height: float = maxf(disk_height * 0.4, 10.0)
	var base_top: float = cell_height - base_height
	var rod_top: float = base_top - disk_height * (_stack + 0.6)
	var lifted_y: float = rod_top - disk_height * 1.5
	_peg_areas.clear()
	var rods: Array[Rect2] = []
	for peg: PegView in _peg_views:
		var cell: Rect2 = _cells[peg.peg_index]
		var column: float = cell.size.x
		peg.position = cell.position
		# The bottom pegs also cover the dress's strip below them.
		peg.size = cell.size + Vector2(0.0, floor_room if cell.end.y >= area.y - 0.5 else 0.0)
		# A rod of its own room is exactly that tall (a full peg looks full).
		var own_top: float = rod_top if _rod_rooms.is_empty() \
				else base_top - disk_height * (_rod_rooms[peg.peg_index] + 0.3)
		peg.configure(base_top, base_height, own_top, maxf(column * 0.05, 6.0), column * 0.96)
		_peg_areas.append(Rect2(cell.position.x + column * 0.02, cell.position.y + lifted_y,
				column * 0.96, base_top + base_height - lifted_y))
		rods.append(Rect2(cell.position.x + column * 0.02, cell.position.y + own_top, column * 0.96,
				base_top + base_height - own_top))
	_marks.peg_rects = rods
	_scale.cells = _cells
	_scale.base_bottom = base_top + base_height
	var rod_tops: Array[float] = []
	for rod: Rect2 in rods:
		rod_tops.append(rod.position.y - _cells[rod_tops.size()].position.y)
	_scale.rod_tops = rod_tops
	_scale.queue_redraw()
	_board_skin.set_cells(_cells, base_top + base_height)
	# The picked-up disks hover above their pegs (a linked group all); once a
	# disk's target is chosen, it hovers above that peg instead.
	var lifted: Array[int] = session.get_selected_disks()
	for peg_index: int in peg_count:
		var peg: Array = session.state.pegs[peg_index]
		for level_index: int in peg.size():
			var disk_size: int = peg[level_index]
			var view: DiskView = _disk_views[disk_size]
			var raised: bool = lifted.has(disk_size)
			var cell: Rect2 = _cells[peg_index]
			var order: int = lifted.find(disk_size)
			if raised and order < session.pending_targets.size():
				cell = _cells[session.pending_targets[order]]
			var column: float = cell.size.x
			var width: float = BoardLayout.disk_width(disk_size, disk_count, column)
			if _palette.has(disk_size) and _palette[disk_size].has("size"):
				width = BoardLayout.disk_width(_palette[disk_size]["size"], _palette[disk_size]["sizes"], column)
			var y: float = lifted_y if raised else base_top - disk_height * (level_index + 1)
			view.selected = raised
			view.size = Vector2(width, disk_height - 4.0)
			var target: Vector2 = cell.position + Vector2(column * 0.5 - width * 0.5, y + 2.0)
			_disk_targets[disk_size] = Rect2(target, view.size)
			# Güzgü: the echoed disk on the bottom board follows a moment later.
			var echo: Move = session.last_echo
			var late: bool = echo != null and peg_index == echo.to_peg and disk_size == session.state.get_top_disk(echo.to_peg)
			view.move_to(target, animated, ECHO_DELAY if late else 0.0)
	_sync_fogs(disk_height, base_top, base_top + base_height, rod_top, animated)
	layout_changed.emit()


## Keeps each karakuri box over the disks the player cannot see: a closed box
## covers the whole peg (so not even the disk count shows), an opened one only
## the disks still hidden at its bottom, shrinking a layer at a time. An empty
## box fades away. The goal preview is never covered.
func _sync_fogs(disk_height: float, base_top: float, bottom: float, rod_top: float, animated: bool) -> void:
	for peg_index: int in _fogs:
		var fog: PegFog = _fogs[peg_index]
		var closed: bool = session.is_covered(peg_index)
		# A seal stays on the lid until it breaks.
		fog.sealed = session.is_sealed(peg_index)
		var hidden: int = session.hidden_count(peg_index)
		if not closed and hidden == 0:
			if fog.is_shown():
				fog.reveal()
			continue
		var cell: Rect2 = _cells[peg_index]
		var top: float = rod_top - disk_height * 0.4 if closed else base_top - disk_height * hidden
		var area: Rect2 = Rect2(cell.position.x + cell.size.x * 0.02, cell.position.y + top, cell.size.x * 0.96, bottom - top)
		if fog.is_shown():
			fog.follow(area, animated)
		else:
			fog.cover(area)