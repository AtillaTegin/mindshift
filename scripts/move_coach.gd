class_name MoveCoach
extends RefCounted
## "Show this move" on the coaching overlay, shared by the hint and the
## tutorial so both look the same: the board is dimmed except the two pegs
## involved, a ring marks the disk to pick up (or, once it is picked up, the
## target peg), and a ghost finger glides from the disk to the target peg.


static func present(coaching: CoachingLayer, board: GameBoard, move: Move, picked_up: bool) -> void:
	var disk_rect: Rect2 = board.get_disk_rect(board.session.state.get_top_disk(move.from_peg))
	var source_rect: Rect2 = board.get_peg_rect(move.from_peg)
	var target_rect: Rect2 = board.get_peg_rect(move.to_peg)
	coaching.scrim.show_scrim(source_rect.merge(target_rect).grow(12.0))
	coaching.ring.show_around(target_rect if picked_up else disk_rect)
	var drop_point: Vector2 = Vector2(target_rect.get_center().x, target_rect.position.y + disk_rect.size.y)
	coaching.pointer.play(disk_rect.get_center(), drop_point)
