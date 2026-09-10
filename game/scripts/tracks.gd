extends Node

const TrackGeometry = preload("res://scripts/track_geometry.gd")

const LIST := [
	{
		"name": "Desert Oval",
		"width": 190.0,
		"control_points": [
			Vector2(640, 90), Vector2(930, 235), Vector2(920, 520),
			Vector2(640, 630), Vector2(350, 520), Vector2(350, 215)
		],
		"spawns": [Vector2(580, 145), Vector2(620, 145), Vector2(660, 145), Vector2(700, 145)],
		"pickups": [Vector2(900, 350), Vector2(640, 605), Vector2(380, 350)],
		"rocks": [Vector2(640, 360)],
		"jumps": []
	},
	{
		"name": "Canyon Switchback",
		"width": 175.0,
		"control_points": [
			Vector2(640, 80), Vector2(1050, 120), Vector2(1180, 300),
			Vector2(1080, 480), Vector2(850, 430), Vector2(850, 620),
			Vector2(500, 650), Vector2(180, 560), Vector2(100, 320),
			Vector2(280, 140)
		],
		"spawns": [Vector2(560, 105), Vector2(600, 105), Vector2(680, 105), Vector2(720, 105)],
		"pickups": [Vector2(1115, 210), Vector2(965, 525), Vector2(190, 440)],
		"rocks": [Vector2(965, 355), Vector2(340, 600)],
		"jumps": [{"center": Vector2(1115, 210), "radius": 95.0}]
	},
	{
		"name": "Salt Flat Sprint",
		"width": 210.0,
		"control_points": [
			Vector2(220, 200), Vector2(1060, 150), Vector2(1180, 360),
			Vector2(1060, 570), Vector2(220, 620), Vector2(100, 360)
		],
		"spawns": [Vector2(300, 175), Vector2(360, 168), Vector2(420, 163), Vector2(480, 158)],
		"pickups": [Vector2(1120, 260), Vector2(640, 595), Vector2(160, 280)],
		"rocks": [Vector2(640, 360)],
		"jumps": [{"center": Vector2(1120, 460), "radius": 100.0}]
	}
]

static func get_track(id: int) -> Dictionary:
	return TrackGeometry.prepare(LIST[clampi(id, 0, LIST.size() - 1)])

static func distance_to_centerline(pos: Vector2, centerline: Array) -> float:
	var best := INF
	var count := centerline.size()
	for i in count:
		var a: Vector2 = centerline[i]
		var b: Vector2 = centerline[(i + 1) % count]
		var d := _distance_to_segment(pos, a, b)
		if d < best:
			best = d
	return best

static func _distance_to_segment(pos: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq < 0.0001:
		return pos.distance_to(a)
	var t: float = clampf((pos - a).dot(ab) / length_sq, 0.0, 1.0)
	var closest := a + ab * t
	return pos.distance_to(closest)
