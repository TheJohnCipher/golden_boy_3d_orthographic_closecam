extends RefCounted

# Declarative layout data that drives world setup.
# Keeping these values separate from behavior makes future edits safer and
# easier to review.

static func shadow_zones() -> Array:
	return [
		{"pos": Vector3(-9.5, 1.0, -20.0), "size": Vector3(5.8, 2.0, 2.2)},
		{"pos": Vector3(-16.0, 1.0, -4.8), "size": Vector3(2.2, 2.0, 2.2)},
		{"pos": Vector3(-12.0, 1.0, -4.9), "size": Vector3(2.2, 2.0, 2.2)},
		{"pos": Vector3(-16.0, 1.0, 6.0), "size": Vector3(2.4, 2.0, 2.8)},
		{"pos": Vector3(-10.0, 1.0, 6.0), "size": Vector3(2.4, 2.0, 2.8)},
		{"pos": Vector3(-25.0, 1.0, 11.0), "size": Vector3(4.4, 2.0, 5.8)},
		{"pos": Vector3(-27.0, 1.0, -14.7), "size": Vector3(3.0, 2.0, 2.0)},
		{"pos": Vector3(-2.2, 1.0, 3.2), "size": Vector3(2.4, 2.0, 2.4)},
		{"pos": Vector3(4.5, 1.0, 8.1), "size": Vector3(2.4, 2.0, 2.4)},
		{"pos": Vector3(17.0, 1.0, 7.4), "size": Vector3(3.6, 2.0, 2.2)},
		{"pos": Vector3(25.5, 1.0, 4.1), "size": Vector3(2.8, 2.0, 2.0)},
		{"pos": Vector3(16.0, 1.0, 17.2), "size": Vector3(5.6, 2.0, 2.8)},
		{"pos": Vector3(13.0, 1.0, 18.1), "size": Vector3(4.8, 2.0, 2.4)},
		{"pos": Vector3(27.0, 1.0, 18.2), "size": Vector3(3.2, 2.0, 3.4)},
	]

static func day_contacts() -> Array:
	return [
		{
			"name_text": "Mara",
			"role": "contact",
			"key": "alibi",
			"phase_tag": "day",
			"start_pos": Vector3(-9.5, 0.0, -15.0),
			"patrol": [],
			"speed": 0.0,
		},
		{
			"name_text": "Jules",
			"role": "contact",
			"key": "guest_pass",
			"phase_tag": "day",
			"start_pos": Vector3(-2.5, 0.0, 0.0),
			"patrol": [],
			"speed": 0.0,
		},
		{
			"name_text": "Nico",
			"role": "contact",
			"key": "route_intel",
			"phase_tag": "day",
			"start_pos": Vector3(7.0, 0.0, 8.0),
			"patrol": [],
			"speed": 0.0,
		},
	]

static func day_civilians() -> Array:
	return [
		{
			"name_text": "Day Civilian A",
			"role": "civilian",
			"key": "",
			"phase_tag": "day",
			"start_pos": Vector3(-6.5, 0.0, -10.0),
			"patrol": [Vector3(-6.5, 0.0, -10.0), Vector3(-3.5, 0.0, -3.5)],
			"speed": 0.7,
		},
		{
			"name_text": "Day Civilian B",
			"role": "civilian",
			"key": "",
			"phase_tag": "day",
			"start_pos": Vector3(0.5, 0.0, 5.5),
			"patrol": [Vector3(0.5, 0.0, 5.5), Vector3(3.5, 0.0, 11.0)],
			"speed": 0.75,
		},
		{
			"name_text": "Day Civilian C",
			"role": "civilian",
			"key": "",
			"phase_tag": "day",
			"start_pos": Vector3(9.0, 0.0, -2.0),
			"patrol": [Vector3(9.0, 0.0, -2.0), Vector3(6.0, 0.0, 3.0)],
			"speed": 0.72,
		},
	]

static func night_guards() -> Array:
	return [
		{
			"name_text": "Guard One",
			"role": "guard",
			"key": "",
			"phase_tag": "night",
			"start_pos": Vector3(-7.5, 0.0, -8.0),
			"patrol": [Vector3(-7.5, 0.0, -8.0), Vector3(-7.5, 0.0, 8.0), Vector3(-3.0, 0.0, 12.0)],
			"speed": 1.6,
		},
		{
			"name_text": "Guard Two",
			"role": "guard",
			"key": "",
			"phase_tag": "night",
			"start_pos": Vector3(7.5, 0.0, 10.0),
			"patrol": [Vector3(7.5, 0.0, 10.0), Vector3(7.5, 0.0, 20.0)],
			"speed": 1.7,
		},
		{
			"name_text": "Guard Three",
			"role": "guard",
			"key": "",
			"phase_tag": "night",
			"start_pos": Vector3(0.0, 0.0, 15.0),
			"patrol": [Vector3(0.0, 0.0, 15.0), Vector3(4.0, 0.0, 22.0)],
			"speed": 1.8,
		},
		{
			"name_text": "Guard Four",
			"role": "guard",
			"key": "",
			"phase_tag": "night",
			"start_pos": Vector3(-4.0, 0.0, 18.0),
			"patrol": [Vector3(-4.0, 0.0, 18.0), Vector3(2.0, 0.0, 25.0)],
			"speed": 1.65,
		},
	]

static func night_witness() -> Dictionary:
	return {
		"name_text": "Observer",
		"role": "witness",
		"key": "",
		"phase_tag": "night",
		"start_pos": Vector3(1.5, 0.0, 2.0),
		"patrol": [Vector3(1.5, 0.0, 2.0), Vector3(3.5, 0.0, 10.0)],
		"speed": 1.1,
	}

static func night_target() -> Dictionary:
	return {
		"name_text": "Target",
		"role": "target",
		"key": "",
		"phase_tag": "night",
		"start_pos": Vector3(0.0, 0.0, -12.0),
		"patrol": [Vector3(0.0, 0.0, -12.0), Vector3(3.5, 0.0, -4.0), Vector3(5.0, 0.0, 4.0), Vector3(4.5, 0.0, 14.0), Vector3(1.5, 0.0, 20.0)],
		"speed": 1.4,
	}

static func night_civilians() -> Array:
	return [
		{
			"name_text": "Civilian A",
			"role": "civilian",
			"key": "",
			"phase_tag": "night",
			"start_pos": Vector3(-4.5, 0.0, 3.0),
			"patrol": [Vector3(-4.5, 0.0, 3.0), Vector3(-5.5, 0.0, 8.0)],
			"speed": 0.9,
		},
		{
			"name_text": "Civilian B",
			"role": "civilian",
			"key": "",
			"phase_tag": "night",
			"start_pos": Vector3(2.5, 0.0, -4.0),
			"patrol": [Vector3(2.5, 0.0, -4.0), Vector3(5.5, 0.0, 2.0)],
			"speed": 0.8,
		},
		{
			"name_text": "Civilian C",
			"role": "civilian",
			"key": "",
			"phase_tag": "night",
			"start_pos": Vector3(9.0, 0.0, 12.0),
			"patrol": [Vector3(9.0, 0.0, 12.0), Vector3(11.0, 0.0, 18.0)],
			"speed": 0.85,
		},
	]
