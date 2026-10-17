class_name MoveCoach
extends RefCounted
## "Show this move" on the coaching overlay, shared by the hint and the
## tutorial so both look the same: the board is dimmed except the pegs
## involved, a ring marks the disk to pick up (or, once it is picked up, the
## target peg), and a ghost finger glides from the disk to the target peg.
## A compound move (linked disks) is shown step by step: the first disk to its
## target, then, once that target is chosen, the next one to its own.


static func present(coaching: CoachingLayer, board: GameBoard, move: Move, picked_up: bool) -> void:
	if move.from_peg == move.to_peg:
		# A rule's own piece (the island's weight stone, RuleBase.special_moves):
		# its button.
		var button: Rect2 = board.get_stone_button_rect()
		coaching.scrim.show_scrim(button.grow(12.0))
		coaching.ring.show_around(button)
		coaching.pointer.play(button.get_center(), button.get_center())
		return
	var from_peg: int = move.from_peg
	var to_peg: int = move.to_peg
	var area: Rect2 = board.get_peg_rect(move.from_peg).merge(board.get_peg_rect(move.to_peg))
	if move.is_compound():
		var parts: Array = move.parts()
		for part: Array in parts:
			area = area.merge(board.get_peg_rect(part[0])).merge(board.get_peg_rect(part[1]))
		var step: int = board.session.pending_targets.size() if picked_up else 0
		if step > 0 and step < parts.size():
			from_peg = parts[step][0]
			to_peg = parts[step][1]
	var disk_rect: Rect2 = board.get_disk_rect(board.session.state.get_top_disk(from_peg))
	var target_rect: Rect2 = board.get_peg_rect(to_peg)
	coaching.scrim.show_scrim(area.grow(12.0))
	coaching.ring.show_around(target_rect if picked_up else disk_rect)
	var drop_point: Vector2 = Vector2(target_rect.get_center().x, target_rect.position.y + disk_rect.size.y)
	coaching.pointer.play(disk_rect.get_center(), drop_point)
