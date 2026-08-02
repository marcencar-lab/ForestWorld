class_name Species
extends RefCounted

## Body plan + behaviour tuning for every creature in the world.
## Sizes are in metres, speeds in m/s.

const DATA := {
	"deer": {
		"label": "Roe deer",
		"count": 12,
		"body_color": Color(0.52, 0.36, 0.22),
		"belly_color": Color(0.84, 0.78, 0.68),
		"dark_color": Color(0.24, 0.17, 0.11),
		"body_len": 1.35, "body_rad": 0.33, "leg_len": 0.82, "leg_w": 0.085,
		"neck_len": 0.44, "neck_pitch": -0.80, "head_len": 0.34, "head_rad": 0.165,
		"ear_len": 0.20, "ear_rad": 0.055, "snout": 0.22,
		"antlers": true, "hump": false, "tusks": false,
		"tail_len": 0.16, "tail_rad": 0.075, "tail_pitch": 0.5,
		"walk_speed": 2.1, "run_speed": 12.0, "accel": 15.0, "turn": 4.5,
		"health": 100.0, "flee_radius": 36.0, "stamina": 7.0,
		"gait": "trot", "gait_scale": 1.6, "step_amp": 0.62,
	},
	"rabbit": {
		"label": "Hare",
		"count": 14,
		"body_color": Color(0.55, 0.48, 0.39),
		"belly_color": Color(0.90, 0.88, 0.83),
		"dark_color": Color(0.33, 0.28, 0.22),
		"body_len": 0.42, "body_rad": 0.155, "leg_len": 0.17, "leg_w": 0.05,
		"neck_len": 0.10, "neck_pitch": -0.75, "head_len": 0.17, "head_rad": 0.095,
		"ear_len": 0.30, "ear_rad": 0.035, "snout": 0.08,
		"antlers": false, "hump": false, "tusks": false,
		"tail_len": 0.07, "tail_rad": 0.065, "tail_pitch": 0.9,
		"walk_speed": 1.6, "run_speed": 13.5, "accel": 26.0, "turn": 7.5,
		"health": 45.0, "flee_radius": 30.0, "stamina": 4.5,
		"gait": "hop", "gait_scale": 3.4, "step_amp": 0.85,
	},
	"fox": {
		"label": "Red fox",
		"count": 6,
		"body_color": Color(0.72, 0.34, 0.12),
		"belly_color": Color(0.92, 0.89, 0.84),
		"dark_color": Color(0.18, 0.13, 0.10),
		"body_len": 0.72, "body_rad": 0.185, "leg_len": 0.36, "leg_w": 0.06,
		"neck_len": 0.20, "neck_pitch": -0.55, "head_len": 0.22, "head_rad": 0.105,
		"ear_len": 0.16, "ear_rad": 0.055, "snout": 0.17,
		"antlers": false, "hump": false, "tusks": false,
		"tail_len": 0.55, "tail_rad": 0.135, "tail_pitch": 0.25,
		"walk_speed": 2.4, "run_speed": 12.5, "accel": 20.0, "turn": 6.5,
		"health": 65.0, "flee_radius": 32.0, "stamina": 6.0,
		"gait": "trot", "gait_scale": 2.4, "step_amp": 0.70,
	},
	"boar": {
		"label": "Wild boar",
		"count": 7,
		"body_color": Color(0.26, 0.21, 0.17),
		"belly_color": Color(0.34, 0.29, 0.24),
		"dark_color": Color(0.13, 0.11, 0.09),
		"body_len": 1.05, "body_rad": 0.34, "leg_len": 0.44, "leg_w": 0.085,
		"neck_len": 0.16, "neck_pitch": -0.15, "head_len": 0.40, "head_rad": 0.175,
		"ear_len": 0.12, "ear_rad": 0.06, "snout": 0.26,
		"antlers": false, "hump": true, "tusks": true,
		"tail_len": 0.16, "tail_rad": 0.035, "tail_pitch": 0.4,
		"walk_speed": 2.0, "run_speed": 9.5, "accel": 13.0, "turn": 3.6,
		"health": 150.0, "flee_radius": 24.0, "stamina": 5.5,
		"gait": "trot", "gait_scale": 2.0, "step_amp": 0.50,
	},
	"bear": {
		"label": "Brown bear",
		"count": 1,
		"body_color": Color(0.35, 0.23, 0.14),
		"belly_color": Color(0.22, 0.15, 0.10),
		"dark_color": Color(0.13, 0.09, 0.06),
		"body_len": 1.75, "body_rad": 0.52, "leg_len": 0.72, "leg_w": 0.165,
		"neck_len": 0.26, "neck_pitch": -0.20, "head_len": 0.46, "head_rad": 0.245,
		"ear_len": 0.11, "ear_rad": 0.085, "snout": 0.30,
		"antlers": false, "hump": true, "tusks": false,
		"tail_len": 0.11, "tail_rad": 0.06, "tail_pitch": 0.2,
		"walk_speed": 2.6, "run_speed": 11.6, "accel": 14.0, "turn": 3.4,
		"health": 600.0, "flee_radius": 0.0, "stamina": 16.0,
		"gait": "trot", "gait_scale": 1.5, "step_amp": 0.48,
	},
}

const PREY := ["deer", "rabbit", "fox", "boar"]


static func get_cfg(name: String) -> Dictionary:
	return DATA[name]
