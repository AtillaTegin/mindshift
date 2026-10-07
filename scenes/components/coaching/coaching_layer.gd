class_name CoachingLayer
extends CanvasLayer
## Holds the four coaching primitives above the game screen. It only groups
## them; what to point at is decided by TutorialDirector and HintController.

@onready var scrim: Scrim = $Scrim
@onready var ring: FocusRing = $FocusRing
@onready var pointer: GhostPointer = $GhostPointer
@onready var toast: CoachToast = $CoachToast


## Hides scrim, ring and pointer (a running toast finishes by itself).
func clear() -> void:
	scrim.hide_scrim()
	ring.hide_ring()
	pointer.stop()
