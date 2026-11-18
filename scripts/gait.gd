class_name Gait
extends RefCounted
## Distance-driven walk cycle maths. The stance foot moves back at exactly the ground speed.


static func step_length(speed: float) -> float:
    return clampf(0.45 + 0.13 * speed, 0.45, 1.15)


## Triangle wave in [-1, 1] (constant foot velocity instead of a sine).
static func tri(phase: float) -> float:
    return asin(sin(phase)) * 2.0 / PI


static func swing_amp(step: float, leg_len: float) -> float:
    return asin(clampf(step / (2.0 * leg_len), 0.0, 0.95))
