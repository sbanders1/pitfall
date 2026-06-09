extends Node
# Autoload "Tune" — live-tunable gameplay knobs, edited from the F1 settings panel.
# Player, Enemy and DeathCar read these every frame, so dragging a slider takes
# effect instantly (including on cars already on the road).

# Player handling
var player_accel := 1500.0   # how hard the throttle pulls toward top speed
var player_top := 1050.0     # your maximum speed
var player_brake := 2000.0   # how hard DOWN/S sheds speed
var player_turn := 3.4       # steering rate (rad/s)

# Enemy handling — defined RELATIVE to the player so rivals stay catchable and don't
# fly off. Each rival rolls a fixed spot inside these ± bands, and paces around your
# current speed. Set a divergence to 0 to make rivals mechanically identical to you.
var enemy_turn := 2.2         # rival turn rate (rad/s)
var enemy_speed_div := 0.12   # how much their top speed varies around yours (± fraction)
var enemy_accel_div := 0.25   # how much punchier/softer their acceleration is than yours
var enemy_brake_div := 0.25   # ...and their braking

# Combat
var ram_keep_speed := true    # if true, ramming a rival no longer bleeds your speed

# The Doom — the wall of dark chasing you up out of the pit
var wall_base := 0.8           # wall cruises at this FRACTION of your top speed
var wall_ramp := 10.0          # +units/s it gains every second — soon outpaces you
var wall_push_kill := 250.0    # distance you regain for each rival you kill
var wall_push_skull := 120.0   # distance regained per skeleton hurled into it (Q = HOLD)
