class_name UIPalette
extends RefCounted
## Placeholder flat colours until the visual theme is chosen (spec 5).

const BACKGROUND: Color = Color("f4f1ea")
const SURFACE: Color = Color("e7e2d6")
const TEXT_PRIMARY: Color = Color("2b2d42")
const TEXT_SECONDARY: Color = Color("6c6f7f")
const PEG: Color = Color("8d8a80")
const ACCENT: Color = Color("2a9d8f")
const ERROR: Color = Color("e63946")
const SUCCESS: Color = Color("2a9d8f")


## A distinct colour per disk size, spread evenly over the hue circle.
static func disk_color(disk_size: int, disk_count: int) -> Color:
	var hue: float = 0.02 + 0.85 * float(disk_size - 1) / float(maxi(disk_count, 2) - 1)
	return Color.from_ok_hsl(hue, 0.7, 0.62)
