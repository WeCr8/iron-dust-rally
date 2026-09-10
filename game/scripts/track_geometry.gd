extends RefCounted

static func prepare(definition: Dictionary) -> Dictionary:
	var track := definition.duplicate(true)
	var controls: Array = track.get("control_points", track.get("centerline", []))
	var centerline := smooth_loop(controls)
	var half_width: float = track["width"] * 0.5
	track["control_points"] = controls
	track["centerline"] = centerline
	track["outer_boundary"] = offset_loop(centerline, half_width)
	track["inner_boundary"] = offset_loop(centerline, -half_width)
	var start_direction := (centerline[1] - centerline[centerline.size() - 1]).normalized()
	var start_normal := Vector2(-start_direction.y, start_direction.x)
	track["start_direction"] = start_direction
	track["start_normal"] = start_normal
	var start: Vector2 = centerline[0]
	var lateral := minf(half_width * 0.34, 34.0)
	track["spawns"] = [
		start - start_direction * 48.0 - start_normal * lateral,
		start - start_direction * 48.0 + start_normal * lateral,
		start - start_direction * 88.0 - start_normal * lateral,
		start - start_direction * 88.0 + start_normal * lateral,
	]
	return track

static func smooth_loop(control_points: Array, samples_per_segment := 8) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := control_points.size()
	if count < 3:
		return Array(control_points, TYPE_VECTOR2, "", null)
	for i in count:
		var p0: Vector2 = control_points[(i - 1 + count) % count]
		var p1: Vector2 = control_points[i]
		var p2: Vector2 = control_points[(i + 1) % count]
		var p3: Vector2 = control_points[(i + 2) % count]
		for sample in samples_per_segment:
			var t := float(sample) / float(samples_per_segment)
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return result

static func offset_loop(points: Array, offset: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var count := points.size()
	for i in count:
		var prev: Vector2 = points[(i - 1 + count) % count]
		var cur: Vector2 = points[i]
		var next: Vector2 = points[(i + 1) % count]
		var incoming := (cur - prev).normalized()
		var outgoing := (next - cur).normalized()
		var normal_in := Vector2(-incoming.y, incoming.x)
		var normal_out := Vector2(-outgoing.y, outgoing.x)
		var miter := (normal_in + normal_out).normalized()
		if miter.length_squared() < 0.01:
			miter = normal_out
		var denominator: float = maxf(absf(miter.dot(normal_out)), 0.35)
		var miter_length: float = minf(absf(offset) / denominator, absf(offset) * 1.7)
		result.append(cur + miter * miter_length * signf(offset))
	return result

static func closed(points: Array) -> PackedVector2Array:
	var loop := PackedVector2Array(points)
	if not points.is_empty():
		loop.append(points[0])
	return loop
