extends Node
# Autoload "Tune" — live-tunable gameplay knobs, edited from the F1 settings panel.
# Player, Enemy and DeathCar read these every frame, so dragging a slider takes
# effect instantly (including on cars already on the road).

# Player handling
var player_accel := 1500.0   # how hard the throttle pulls toward top speed
var player_top := 1050.0     # your maximum speed
var player_brake := 2000.0   # how hard DOWN/S sheds speed
var player_turn := 3.4       # steering rate (rad/s)

# Enemy handling
var enemy_top := 880.0        # rival base chase speed (each rival varies a little)
var enemy_turn := 2.2         # rival base turn rate (rad/s)

# Combat
var ram_keep_speed := true    # if true, ramming a rival no longer bleeds your speed
