extends Node

const LIST := [
	{"name": "Scorpion Red", "color": Color("ef476f"), "speed_mult": 1.0, "accel_mult": 1.0, "boost_mult": 1.0, "blurb": "Balanced all-rounder"},
	{"name": "Canyon Gold", "color": Color("ffd166"), "speed_mult": 1.18, "accel_mult": 0.85, "boost_mult": 0.95, "blurb": "High top speed, slow to wind up"},
	{"name": "Verde Teal", "color": Color("06d6a0"), "speed_mult": 0.88, "accel_mult": 1.28, "boost_mult": 1.0, "blurb": "Snappy acceleration, lower top speed"},
	{"name": "Blue Thunder", "color": Color("70a1ff"), "speed_mult": 0.95, "accel_mult": 1.0, "boost_mult": 1.35, "blurb": "Boost pickups hit much harder"}
]

static func get_vehicle(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]

# Paint colours. These are HUE ROTATIONS applied to the existing buggy art, not new
# sprites - the four vehicles keep their shape, shading, tyres and numbers, and only the
# painted panels move around the colour wheel. Index order matches the generated atlases
# vehicles_atlas_tint<N>.png produced by tools/recolor_buggies.py.
const TINTS := [
	{"name": "Crimson", "hue": 0, "color": Color("e02020")},
	{"name": "Ember", "hue": 20, "color": Color("e06020")},
	{"name": "Amber", "hue": 40, "color": Color("e0a020")},
	{"name": "Sand", "hue": 55, "color": Color("d8c040")},
	{"name": "Lime", "hue": 90, "color": Color("80e020")},
	{"name": "Jade", "hue": 140, "color": Color("20e060")},
	{"name": "Teal", "hue": 175, "color": Color("20d8d0")},
	{"name": "Azure", "hue": 205, "color": Color("20a0e0")},
	{"name": "Cobalt", "hue": 225, "color": Color("2060e0")},
	{"name": "Violet", "hue": 265, "color": Color("8020e0")},
	{"name": "Magenta", "hue": 300, "color": Color("e020d0")},
	{"name": "Rose", "hue": 330, "color": Color("e02080")}
]

static func get_tint(index: int) -> Dictionary:
	return TINTS[clampi(index, 0, TINTS.size() - 1)]

static func tint_count() -> int:
	return TINTS.size()
