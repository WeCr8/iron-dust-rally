extends Node

const TEXTURE := preload("res://assets/art/logo_ui_atlas.png")
const LOGO_REGION := Rect2(40, 10, 1450, 600)
const FRAME_REGION := Rect2(15, 620, 775, 395)
const PILL_REGION := Rect2(825, 645, 360, 95)
const GAUGE_REGION := Rect2(1195, 645, 335, 100)
const BADGE_REGIONS := [
	Rect2(825, 765, 160, 250),
	Rect2(1000, 765, 160, 250),
	Rect2(1175, 765, 160, 250),
	Rect2(1350, 765, 160, 250)
]

# environment_atlas.png is a 3x3 grid, 418px cells. Row 0 (ground textures)
# is near full-bleed so the whole cell is used. Rows 1-2 are small centered
# props with a lot of empty padding around them, so those regions are
# cropped tight to the actual artwork instead of the full cell — using the
# full cell there makes the prop look like a tiny speck when drawn at
# in-game sprite sizes.
const ENV_TEXTURE := preload("res://assets/art/environment_atlas.png")
const ENV_CELL := 418.0
const TERRAIN_CLAY := Rect2(0, 0, ENV_CELL, ENV_CELL)
const TIRE_WALL := Rect2(40, 468, 360, 265)
const SIGNPOST := Rect2(518, 463, 280, 275)
const ROCK_PILE := Rect2(876, 463, 360, 285)
const CACTUS := Rect2(20, 881, 370, 290)
const BATTERY := Rect2(558, 876, 160, 290)
const DUST := Rect2(851, 871, 390, 295)

const TIRE_WALL_ASPECT := 360.0 / 265.0
const ROCK_PILE_ASPECT := 360.0 / 285.0
const BATTERY_ASPECT := 160.0 / 290.0

# Dedicated ground-surface atlas (separate from ENV_TEXTURE's props): a
# 3-over-2 grid, top row split into thirds, bottom row split into halves.
const TERRAIN_ATLAS_TEXTURE := preload("res://assets/art/terrain_atlas.png")
const TERRAIN_DIRT := Rect2(0.0, 0.0, 418.0, 627.0)
const TERRAIN_SAND := Rect2(418.0, 0.0, 418.0, 627.0)
const TERRAIN_HARDPACK := Rect2(836.0, 0.0, 418.0, 627.0)
const TERRAIN_MUD := Rect2(0.0, 627.0, 627.0, 627.0)
const TERRAIN_GRAVEL := Rect2(627.0, 627.0, 627.0, 627.0)

# A row of 8 branded bollard posts (alternating liveries) used to line
# straight track sections.
const BOLLARD_TEXTURE := preload("res://assets/art/straight_bollards.png")
const BOLLARD_CELL := 271.5
const STRAIGHT_BOLLARD_A := Rect2(0.0, 0.0, BOLLARD_CELL, 724.0)
const STRAIGHT_BOLLARD_B := Rect2(BOLLARD_CELL, 0.0, BOLLARD_CELL, 724.0)
const BOLLARD_ASPECT := BOLLARD_CELL / 724.0

# A 90-degree arc of the same bollards, provided as a reference for turns.
# The full arc is composed for one specific radius/angle and can't be
# warped onto our arbitrary track corners, so one cleanly isolated post is
# cropped from its flat (non-overlapping) top row and used as the marker
# at every corner vertex instead — keeping the whole barrier system on the
# same branded bollard family rather than mixing in an unrelated asset.
const CORNER_BOLLARD_TEXTURE := preload("res://assets/art/corner_bollards.png")
const CORNER_BOLLARD := Rect2(195.0, 55.0, 160.0, 230.0)
const CORNER_BOLLARD_ASPECT := 160.0 / 230.0

# A shallow 30-degree arc of the same bollards, used the same way as
# CORNER_BOLLARD above but for gentle turns rather than sharp ones.
const GENTLE_BOLLARD_TEXTURE := preload("res://assets/art/gentle_corner_bollards.png")
const GENTLE_BOLLARD := Rect2(15.0, 90.0, 190.0, 300.0)
const GENTLE_BOLLARD_ASPECT := 190.0 / 300.0

# 45-degree and 60-degree arcs, filling out the corner-marker set between
# the shallow 30 and sharp 90 arts above. Same single-post-from-the-flat-
# lead-in crop approach as GENTLE_BOLLARD/CORNER_BOLLARD.
const BOLLARD_45_TEXTURE := preload("res://assets/art/bollards_45.png")
const BOLLARD_45 := Rect2(28.0, 51.0, 189.0, 285.0)
const BOLLARD_45_ASPECT := 189.0 / 285.0

const BOLLARD_60_TEXTURE := preload("res://assets/art/bollards_60.png")
const BOLLARD_60 := Rect2(56.0, 78.0, 188.0, 285.0)
const BOLLARD_60_ASPECT := 188.0 / 285.0

# A full 180-degree hairpin arch. Unlike the 30/45/60/90 arcs, every post
# in this art overlaps its neighbor along the whole curve (no flat,
# non-overlapping lead-in to crop from), so this region is the bottom
# terminal post only, accepting a little bleed from the post above it.
const BOLLARD_180_TEXTURE := preload("res://assets/art/bollards_180.png")
const BOLLARD_180 := Rect2(74.0, 1075.0, 152.0, 234.0)
const BOLLARD_180_ASPECT := 152.0 / 234.0
