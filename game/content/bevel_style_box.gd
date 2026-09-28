class_name BevelStyleBox
extends StyleBox

## The 2px two-tone frame every panel in the game is made of
## (index.html:47-59): `.outset` is light top/left, dark bottom/right;
## `.inset` reverses the two; `.win` (index.html:45-50) adds a 1px black
## outer ring on top of the outset via its `box-shadow`. Drawn directly with
## flat rects rather than through a stretched texture -- a `StyleBoxTexture`
## 9-slice samples with the canvas item's filter, and a texture stretched from
## a few px up to hundreds bleeds its border texels across the whole face,
## which is where this game's earlier gradient-wash bug came from. Flat rects
## have no filter to bleed.

@export var face: Color = Color.WHITE
@export var light: Color = Color.WHITE
@export var dark: Color = Color.BLACK
## The `.win` frame's 1px black outer ring (index.html:49).
@export var ring: bool = false

const EDGE := 2


func _get_style_margin(_side: Side) -> float:
	return EDGE + (1.0 if ring else 0.0)


func _draw(canvas_item: RID, rect: Rect2) -> void:
	var r := rect
	if ring:
		RenderingServer.canvas_item_add_rect(canvas_item, r, Color.BLACK)
		r = r.grow(-1)
	RenderingServer.canvas_item_add_rect(canvas_item, r, light)
	# The dark bottom/right L-shape, drawn over the light fill.
	RenderingServer.canvas_item_add_rect(
		canvas_item,
		Rect2(r.position.x + EDGE, r.end.y - EDGE, r.size.x - EDGE, EDGE),
		dark
	)
	RenderingServer.canvas_item_add_rect(
		canvas_item,
		Rect2(r.end.x - EDGE, r.position.y + EDGE, EDGE, r.size.y - EDGE),
		dark
	)
	RenderingServer.canvas_item_add_rect(canvas_item, r.grow(-EDGE), face)
