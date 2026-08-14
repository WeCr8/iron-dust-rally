extends Node2D

const Racer = preload("res://scripts/racer.gd")
const COLORS := [Color("ef476f"), Color("ffd166"), Color("06d6a0"), Color("70a1ff")]
const CENTER := Vector2(640, 360)
const CHECKPOINTS := [Vector2(640, 90), Vector2(930, 235), Vector2(920, 520), Vector2(640, 630), Vector2(350, 520), Vector2(350, 215)]
const SPAWNS := [Vector2(580, 145), Vector2(620, 145), Vector2(660, 145), Vector2(700, 145)]
const PICKUP_SPOTS := [Vector2(900, 350), Vector2(640, 605), Vector2(380, 350)]

var racers: Array[RallyRacer] = []
var pickup_active := [true, true, true]
var pickup_timers := [0.0, 0.0, 0.0]
var finish_count := 0
var countdown := 3.0
var race_started := false
var title_font: Font

func _ready() -> void:
	title_font = ThemeDB.fallback_font
	_start_race()

func _start_race() -> void:
	for racer in racers:
		racer.queue_free()
	racers.clear()
	finish_count = 0
	countdown = 3.0
	race_started = false
	pickup_active = [true, true, true]
	pickup_timers = [0.0, 0.0, 0.0]
	var pads := Input.get_connected_joypads()
	for i in 4:
		var racer := Racer.new()
		add_child(racer)
		var is_human := i < 2 or i < pads.size()
		racer.setup(i, is_human, COLORS[i], SPAWNS[i])
		racer.set_physics_process(false)
		racers.append(racer)
	queue_redraw()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		_start_race()
	if not race_started:
		countdown -= delta
		if countdown <= 0.0:
			race_started = true
			for racer in racers:
				racer.set_physics_process(true)
	else:
		_update_race_progress()
		_update_pickups(delta)
	queue_redraw()

func _update_race_progress() -> void:
	for racer in racers:
		if racer.finished:
			continue
		var target: Vector2 = CHECKPOINTS[racer.checkpoint]
		racer.next_target = target
		if racer.position.distance_to(target) < 68.0:
			racer.checkpoint += 1
			if racer.checkpoint >= CHECKPOINTS.size():
				racer.checkpoint = 0
				racer.lap += 1
				if racer.lap >= 3:
					finish_count += 1
					racer.finished = true
					racer.finish_place = finish_count

func _update_pickups(delta: float) -> void:
	for i in PICKUP_SPOTS.size():
		if not pickup_active[i]:
			pickup_timers[i] -= delta
			if pickup_timers[i] <= 0.0:
				pickup_active[i] = true
			continue
		for racer in racers:
			if racer.position.distance_to(PICKUP_SPOTS[i]) < 34.0:
				racer.add_boost(35.0)
				pickup_active[i] = false
				pickup_timers[i] = 5.0
				break

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("b66d32"), true)
	draw_circle(CENTER, 350.0, Color("d69a50"))
	draw_circle(CENTER, 330.0, Color("6b4a2f"))
	draw_circle(CENTER, 155.0, Color("c7823d"))
	for i in CHECKPOINTS.size():
		draw_circle(CHECKPOINTS[i], 7.0, Color(1, 1, 1, 0.25))
	for i in PICKUP_SPOTS.size():
		if pickup_active[i]:
			draw_circle(PICKUP_SPOTS[i], 18.0, Color("56cfe1"))
			draw_string(title_font, PICKUP_SPOTS[i] + Vector2(-6, 6), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("102a43"))
	draw_line(Vector2(565, 105), Vector2(715, 105), Color.WHITE, 8.0)
	draw_string(title_font, Vector2(28, 42), "IRON DUST RALLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("fff3d4"))
	for i in racers.size():
		var racer: RallyRacer = racers[i]
		var status: String = ("FIN %d" % racer.finish_place) if racer.finished else ("LAP %d/3  BOOST %d" % [min(racer.lap + 1, 3), int(racer.boost)])
		draw_rect(Rect2(28, 66 + i * 34, 255, 26), Color(0.05, 0.04, 0.03, 0.78), true)
		draw_circle(Vector2(42, 79 + i * 34), 7.0, COLORS[i])
		draw_string(title_font, Vector2(56, 85 + i * 34), "P%d  %s%s" % [i + 1, status, " CPU" if not racer.human else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if not race_started:
		var text: String = str(max(1, ceili(countdown))) if countdown > 0.0 else "GO!"
		draw_string(title_font, Vector2(585, 380), text, HORIZONTAL_ALIGNMENT_CENTER, 110, 64, Color.WHITE)
	elif finish_count == 4:
		draw_rect(Rect2(440, 265, 400, 160), Color(0.04, 0.03, 0.02, 0.9), true)
		draw_string(title_font, Vector2(490, 320), "RACE COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, 300, 34, Color.WHITE)
		draw_string(title_font, Vector2(490, 372), "Press R to rematch", HORIZONTAL_ALIGNMENT_CENTER, 300, 20, Color("ffd166"))
