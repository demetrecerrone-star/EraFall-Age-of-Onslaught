extends SceneTree

# Run with: godot --headless --path . --script res://tests/controls_smoke.gd
# Catches regressions where the mobile player can see combat but cannot steer.
func _initialize() -> void:
    call_deferred("_exercise_controls")


func _exercise_controls() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        push_error("Cannot load EraFall gameplay scene")
        quit(1)
        return
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    game.call("_start_level")
    if int(game.get("screen")) != 1:
        push_error("Game did not enter PLAYING state")
        quit(1)
        return

    var finger := InputEventScreenTouch.new()
    finger.index = 0
    finger.pressed = true
    finger.position = Vector2(320, 950)
    game.call("_input", finger)

    var swipe := InputEventScreenDrag.new()
    swipe.index = 0
    swipe.position = Vector2(500, 950)
    swipe.relative = Vector2(180, 0)
    game.call("_input", swipe)
    var after_swipe := float(game.get("player_x"))
    if after_swipe < 0.5:
        push_error("Android drag did not steer hunter right: x=%f" % after_swipe)
        quit(1)
        return

    finger.pressed = false
    game.call("_input", finger)
    game.call("_input", swipe)
    if not is_equal_approx(float(game.get("player_x")), after_swipe):
        push_error("Drag continued controlling hunter after finger release")
        quit(1)
        return

    game.set("left_held", true)
    game.call("_process", 0.3)
    var after_left := float(game.get("player_x"))
    game.set("left_held", false)
    if after_left >= after_swipe:
        push_error("On-screen LEFT hold did not steer hunter")
        quit(1)
        return

    game.set("right_held", true)
    game.call("_process", 0.3)
    game.set("right_held", false)
    if float(game.get("player_x")) <= after_left:
        push_error("On-screen RIGHT hold did not steer hunter")
        quit(1)
        return

    print("ERAFALL CONTROL SMOKE: touch swipe + on-screen hold both moved hero")
    quit(0)
