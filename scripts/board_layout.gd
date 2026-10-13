class_name BoardLayout
extends RefCounted
## Geometry shared by the board and the goal preview.

const MIN_DISK_SHARE: float = 0.3
const MAX_DISK_SHARE: float = 0.94
## The one disk width of a "Birləşmə Tapmacası" level (all disks equal).
const EQUAL_DISK_SHARE: float = 0.72
## More pegs than this stand in two rows, on the board and in the goal preview
## (only large combination boards), like Water Sort.
const ONE_ROW_PEGS: int = 5


## Disk width inside a peg column: the smallest disk takes 30% of the column,
## the largest 94%.
static func disk_width(disk_size: int, disk_count: int, column_width: float) -> float:
	var share: float = MAX_DISK_SHARE
	if disk_count > 1:
		share = MIN_DISK_SHARE + (MAX_DISK_SHARE - MIN_DISK_SHARE) * float(disk_size - 1) / float(disk_count - 1)
	return column_width * share
