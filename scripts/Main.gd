extends Node3D

# EraFall 0.1: a compact, asset-independent, playable 3D foundation.
# Three explicit UI states and one data-driven era table keep changes isolated.
const Catalog = preload("res://scripts/EraCatalog.gd")
const SAVE_PATH := "user://erafall_save.json"
const TRACK_EDGE := 4.65
const HERO_Z := 7.0

enum Screen { TITLE, PLAYING, POPUP }
var screen: Screen = Screen.TITLE
var era_index := 0
var furthest_era := 0
var gold := 0
var attack_upgrade := 0
var hints_enabled := true
var pets: Dictionary = {}
var time_in_stage := 0.0
var spawn_clock := 0.0
var shoot_clock := 0.0
var player_x := 0.0
var allies := 1
var health := 4
var spawned_miniboss := false
var spawned_boss := false
var boss_defeated := false
var finished := false
var enemies: Array[Dictionary] = []
var gates: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var ally_models: Array[Node3D] = []
var arena: Node3D
var formations: Node3D
var track: MeshInstance3D
var camera: Camera3D
var menu: Control
var hud: Control
var popup: Control
var popup_title: Label
var popup_body: Label
var popup_action: Button
var play_button: TextureButton
var era_label: Label
var tagline: Label
var hud_label: Label
var hint_label: Label
var logo_image: TextureRect
var logo_fallback: Label
var title_background: TextureRect
var panel_kind := ""
var art_title_enabled := false


func _ready() -> void:
    _load_save()
    _create_world()
    _create_ui()
    _enter_title()


func _process(delta: float) -> void:
    if screen != Screen.PLAYING or finished:
        return
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        player_x -= 7.0 * delta
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        player_x += 7.0 * delta
    player_x = clampf(player_x, -TRACK_EDGE, TRACK_EDGE)
    _place_allies()
    time_in_stage += delta
    spawn_clock -= delta
    shoot_clock -= delta
    if spawn_clock <= 0.0 and time_in_stage < 50.0:
        spawn_clock = maxf(1.05, 2.65 - float(era_index) * 0.12)
        _spawn_enemy("grunt")
    if shoot_clock <= 0.0:
        shoot_clock = maxf(0.26, 0.82 - float(attack_upgrade) * 0.06 - float(era_index) * 0.025)
        _fire_volley()
    if not spawned_miniboss and time_in_stage >= 22.0:
        spawned_miniboss = true
        _spawn_enemy("mini")
    if not spawned_boss and time_in_stage >= 43.0:
        spawned_boss = true
        _spawn_enemy("boss")
    _move_gates(delta)
    _move_enemies(delta)
    _move_projectiles(delta)
    _update_hud()
    if health <= 0:
        _finish_level(false)


func _unhandled_input(event: InputEvent) -> void:
    if screen != Screen.PLAYING:
        return
    var width := maxf(1.0, get_viewport().get_visible_rect().size.x)
    if event is InputEventScreenDrag:
        player_x = clampf(player_x + event.relative.x * 11.0 / width, -TRACK_EDGE, TRACK_EDGE)
    elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            player_x = clampf(player_x + event.relative.x * 11.0 / width, -TRACK_EDGE, TRACK_EDGE)


func _create_world() -> void:
    var environment_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#102431")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#bfd4d8")
    env.ambient_light_energy = 0.65
    environment_node.environment = env
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -38, 0)
    sun.light_energy = 1.25
    add_child(sun)

    camera = Camera3D.new()
    camera.position = Vector3(0.0, 22.0, 28.0)
    camera.fov = 51.0
    camera.far = 110.0
    camera.current = true
    # Node3D.look_at needs an active tree/global transform. Calling it
    # before add_child leaves the camera facing the horizon on Android.
    add_child(camera)
    camera.look_at(Vector3(0.0, 0.0, -8.0), Vector3.UP)

    arena = Node3D.new()
    arena.name = "LevelObjects"
    add_child(arena)
    formations = Node3D.new()
    formations.name = "Tribe"
    add_child(formations)

    track = _box(arena, Vector3(11.0, 0.32, 95.0), Color("#70614b"), Vector3(0, -0.16, -13.0))
    _box(arena, Vector3(0.27, 0.24, 95), Color("#c2ab7a"), Vector3(-5.55, 0, -13))
    _box(arena, Vector3(0.27, 0.24, 95), Color("#c2ab7a"), Vector3(5.55, 0, -13))
    for i in range(20):
        var z := -54.0 + float(i) * 6.7
        for side in [-1, 1]:
            var x := float(side) * (7.7 + float(i % 3) * 1.5)
            _box(arena, Vector3(1.3, 1.7, 1.3), Color("#486651"), Vector3(x, 0.65, z))
            _sphere(arena, Color("#668465"), Vector3(x, 2.2, z), Vector3(1.15, 1.6, 1.15))
    _paint_era()


func _paint_era() -> void:
    var c: Color = Color(Catalog.get_era(era_index)["accent"])
    if track != null:
        var material := StandardMaterial3D.new()
        material.albedo_color = c.darkened(0.54)
        material.roughness = 1.0
        track.material_override = material


func _box(parent: Node3D, dimensions: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    instance.mesh = mesh
    instance.position = at
    instance.material_override = _material(color)
    parent.add_child(instance)
    return instance


func _sphere(parent: Node3D, color: Color, at: Vector3, dimensions: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    instance.mesh = mesh
    instance.scale = dimensions
    instance.position = at
    instance.material_override = _material(color)
    parent.add_child(instance)
    return instance


func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.78
    return material


func _fighter(color: Color, is_boss: bool = false) -> Node3D:
    var unit := Node3D.new()
    arena.add_child(unit)
    _box(unit, Vector3(0.55, 0.9, 0.45), color, Vector3(0, 1.13, 0))
    _sphere(unit, Color("#e9bd96"), Vector3(0, 1.93, 0), Vector3(0.63, 0.68, 0.62))
    _box(unit, Vector3(0.2, 0.85, 0.23), Color("#34363a"), Vector3(-0.16, 0.44, 0))
    _box(unit, Vector3(0.2, 0.85, 0.23), Color("#34363a"), Vector3(0.16, 0.44, 0))
    _box(unit, Vector3(0.19, 0.7, 0.2), color.darkened(0.25), Vector3(-0.41, 1.2, 0))
    _box(unit, Vector3(0.19, 0.7, 0.2), color.darkened(0.25), Vector3(0.41, 1.2, 0))
    if is_boss:
        unit.scale = Vector3(1.75, 1.75, 1.75)
        _box(unit, Vector3(1.1, 0.24, 0.28), Color("#dbb66e"), Vector3(0, 2.35, 0))
    return unit


func _beast(color: Color, is_boss: bool = false) -> Node3D:
    var beast := Node3D.new()
    arena.add_child(beast)
    _sphere(beast, color, Vector3(0, 0.86, 0), Vector3(1.5, 1.1, 1.9))
    _sphere(beast, color.lightened(0.17), Vector3(0, 1.0, -0.75), Vector3(0.95, 0.85, 0.85))
    for x in [-0.52, 0.52]:
        for z in [-0.54, 0.54]:
            _box(beast, Vector3(0.27, 0.74, 0.29), color.darkened(0.25), Vector3(x, 0.38, z))
    _sphere(beast, Color("#f8cc61"), Vector3(-0.26, 1.12, -1.15), Vector3(0.15, 0.14, 0.15))
    _sphere(beast, Color("#f8cc61"), Vector3(0.26, 1.12, -1.15), Vector3(0.15, 0.14, 0.15))
    if is_boss:
        beast.scale = Vector3(1.5, 1.5, 1.5)
    return beast


func _clear_run() -> void:
    for record in enemies:
        (record["node"] as Node3D).queue_free()
    for record in gates:
        (record["node"] as Node3D).queue_free()
    for record in projectiles:
        (record["node"] as Node3D).queue_free()
    enemies.clear()
    gates.clear()
    projectiles.clear()
    for model in ally_models:
        model.queue_free()
    ally_models.clear()


func _start_level() -> void:
    _clear_run()
    finished = false
    screen = Screen.PLAYING
    time_in_stage = 0.0
    spawn_clock = 4.0
    shoot_clock = 0.4
    player_x = 0
    allies = 1
    health = 4
    spawned_miniboss = false
    spawned_boss = false
    boss_defeated = false
    _paint_era()
    _add_allies(1)
    menu.visible = false
    hud.visible = true
    popup.visible = false
    _spawn_gate(1, -2.3, -18.0)
    _spawn_gate(2, 2.25, -44.0)
    _spawn_gate(3, -0.1, -70.0)
    _spawn_gate(3, 2.5, -96.0)
    _update_hud()


func _add_allies(count: int) -> void:
    var goal := mini(18, ally_models.size() + count)
    for i in range(ally_models.size(), goal):
        var unit := _fighter(Color("#e7c88b"))
        ally_models.append(unit)
    allies = ally_models.size()
    _place_allies()


func _place_allies() -> void:
    for i in range(ally_models.size()):
        var row := 0 if i == 0 else 1 + int((i - 1) / 5)
        var column := 0 if i == 0 else (i - 1) % 5 - 2
        var x_offset := float(column) * 0.77
        ally_models[i].position = Vector3(clampf(player_x + x_offset, -TRACK_EDGE, TRACK_EDGE), 0, HERO_Z + float(row) * 1.04)


func _spawn_gate(amount: int, x: float, z: float) -> void:
    var gate := Node3D.new()
    arena.add_child(gate)
    gate.position = Vector3(x, 0.0, z)
    var color := Color("#66e4ac")
    _box(gate, Vector3(0.26, 3.0, 0.28), color, Vector3(-1.13, 1.5, 0))
    _box(gate, Vector3(0.26, 3.0, 0.28), color, Vector3(1.13, 1.5, 0))
    _box(gate, Vector3(2.52, 0.43, 0.3), color, Vector3(0, 3.08, 0))
    gates.append({"node": gate, "amount": amount, "speed": 3.85})


func _move_gates(delta: float) -> void:
    for i in range(gates.size() - 1, -1, -1):
        var gate := gates[i]
        var node := gate["node"] as Node3D
        node.position.z += float(gate["speed"]) * delta
        if node.position.z >= HERO_Z:
            if absf(node.position.x - player_x) <= 1.36:
                _add_allies(int(gate["amount"]))
                _show_hint("+%d ALLIES!" % int(gate["amount"]))
            node.queue_free()
            gates.remove_at(i)


func _spawn_enemy(kind: String) -> void:
    var era := Catalog.get_era(era_index)
    var x := randf_range(-3.7, 3.7)
    var hp := 2 + int(era_index / 2)
    var speed := 2.5 + float(era_index) * 0.11
    var award := 2
    var radius := 0.78
    var visual: Node3D
    if kind == "mini":
        visual = _beast(Color("#8e6b60"), true)
        hp = 10 + era_index * 3
        speed = 1.65
        award = 15
        radius = 1.6
        _show_hint("MINIBOSS: %s" % str(era["mini"]))
    elif kind == "boss":
        visual = _fighter(Color("#9b5550"), true)
        hp = 24 + era_index * 6
        speed = 1.4
        award = 38
        radius = 1.35
        _show_hint("ERA BOSS: %s" % str(era["boss"]))
        x = 0.0
    else:
        visual = _fighter(Color("#b96f63"))
    visual.position = Vector3(x, 0, -31.0)
    enemies.append({"node": visual, "kind": kind, "hp": hp, "speed": speed, "award": award, "radius": radius})


func _move_enemies(delta: float) -> void:
    for i in range(enemies.size() - 1, -1, -1):
        var foe := enemies[i]
        var node := foe["node"] as Node3D
        node.position.z += float(foe["speed"]) * delta
        if node.position.z > HERO_Z + 0.2:
            health -= 2 if str(foe["kind"]) == "boss" else 1
            if allies > 1:
                var lost: Node3D = ally_models.pop_back()
                lost.queue_free()
                allies = ally_models.size()
            node.queue_free()
            enemies.remove_at(i)


func _fire_volley() -> void:
    if enemies.is_empty():
        return
    for ally in ally_models:
        var shot := Node3D.new()
        arena.add_child(shot)
        shot.position = Vector3(ally.position.x, 1.65, ally.position.z - 0.3)
        var color := Color(Catalog.get_era(era_index)["accent"]).lightened(0.1)
        _sphere(shot, color, Vector3.ZERO, Vector3(0.23, 0.23, 0.61))
        projectiles.append({"node": shot, "damage": 1 + int(attack_upgrade / 2)})


func _move_projectiles(delta: float) -> void:
    for i in range(projectiles.size() - 1, -1, -1):
        var projectile := projectiles[i]
        var node := projectile["node"] as Node3D
        node.position.z -= 21.0 * delta
        if enemies.size() > 0:
            var nearest_index := 0
            var best := 99999.0
            for j in range(enemies.size()):
                var target := enemies[j]["node"] as Node3D
                var dist := absf(node.position.z - target.position.z) + absf(node.position.x - target.position.x) * 2.0
                if dist < best:
                    best = dist
                    nearest_index = j
            var chosen := enemies[nearest_index]["node"] as Node3D
            node.position.x = move_toward(node.position.x, chosen.position.x, 9.0 * delta)
            if absf(node.position.z - chosen.position.z) < float(enemies[nearest_index]["radius"]) and absf(node.position.x - chosen.position.x) < float(enemies[nearest_index]["radius"]):
                enemies[nearest_index]["hp"] = int(enemies[nearest_index]["hp"]) - int(projectile["damage"])
                if int(enemies[nearest_index]["hp"]) <= 0:
                    _defeat_enemy(nearest_index)
                node.queue_free()
                projectiles.remove_at(i)
                continue
        if node.position.z < -39.0:
            node.queue_free()
            projectiles.remove_at(i)


func _defeat_enemy(index: int) -> void:
    var enemy := enemies[index]
    gold += int(enemy["award"])
    var kind := str(enemy["kind"])
    (enemy["node"] as Node3D).queue_free()
    enemies.remove_at(index)
    if kind == "mini":
        _show_hint("MINIBOSS DOWN! +%d GOLD" % int(enemy["award"]))
    if kind == "boss":
        boss_defeated = true
        _finish_level(true)


func _finish_level(won: bool) -> void:
    if finished:
        return
    finished = true
    hud.visible = false
    menu.visible = false
    screen = Screen.POPUP
    if won:
        var old_era := Catalog.get_era(era_index)
        pets[str(old_era["pet"])] = true
        if era_index + 1 < Catalog.era_count():
            era_index += 1
            furthest_era = maxi(furthest_era, era_index)
            _save()
            _show_popup("ERA CONQUERED!", "%s defeated!\nPet unlocked: %s\nNext weapon: %s\nEntering %s." % [old_era["boss"], old_era["pet"], old_era["reward"], Catalog.get_era(era_index)["name"]], "NEXT ERA", "continue")
        else:
            _save()
            _show_popup("ALL ERAS CONQUERED!", "You defeated the Titan Overlord!\nFinal reward: %s\nYour journey is saved." % old_era["reward"], "BACK TO TITLE", "continue")
    else:
        _save()
        _show_popup("TRIBE DEFEATED", "Your tribe fell in %s.\nKeep your earned gold and return stronger." % Catalog.get_era(era_index)["name"], "TRY AGAIN", "retry")


func _enter_title() -> void:
    screen = Screen.TITLE
    _clear_run()
    popup.visible = false
    hud.visible = false
    menu.visible = true
    _refresh_menu()


func _refresh_menu() -> void:
    var era := Catalog.get_era(era_index)
    era_label.text = str(era["name"]).to_upper() + "  |  " + str(era["weapon"])
    tagline.text = "Hunt. Recruit. Conquer. Evolve.\nEarned Gold: %d   |   Tribe Strength: %d" % [gold, 1 + attack_upgrade]
    if not art_title_enabled:
        play_button.texture_normal = load(str(era["button"])) as Texture2D
    _paint_era()
    _update_logo()


func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    menu = Control.new()
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(menu)
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015, 0.025, 0.036, 0.52)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu.add_child(shade)
    title_background = TextureRect.new()
    title_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    title_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    title_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    title_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu.add_child(title_background)
    var heading := _label(menu, "ERAFALL", 66, Color("#fff3d6"))
    heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    heading.offset_top = 116
    heading.offset_bottom = 202
    var subtitle := _label(menu, "AGE OF ONSLAUGHT", 29, Color("#e2c994"))
    subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    subtitle.offset_top = 205
    subtitle.offset_bottom = 247
    era_label = _label(menu, "", 24, Color("#f8e9cd"))
    era_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    era_label.offset_top = 294
    era_label.offset_bottom = 342
    tagline = _label(menu, "", 22, Color("#f2e7d3"))
    tagline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    tagline.offset_top = -228
    tagline.offset_bottom = -150

    var bar := HBoxContainer.new()
    bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bar.offset_left = 16
    bar.offset_right = -16
    bar.offset_top = -139
    bar.offset_bottom = -37
    bar.add_theme_constant_override("separation", 7)
    menu.add_child(bar)
    play_button = _image_button(bar, "res://assets/ui/play_stone.svg")
    play_button.pressed.connect(_start_level)
    var upgrades := _image_button(bar, "res://assets/ui/upgrades.svg")
    upgrades.pressed.connect(func() -> void: _open_menu_panel("upgrades"))
    var collection := _image_button(bar, "res://assets/ui/collection.svg")
    collection.pressed.connect(func() -> void: _open_menu_panel("collection"))
    var settings := _image_button(bar, "res://assets/ui/settings.svg")
    settings.pressed.connect(func() -> void: _open_menu_panel("settings"))

    logo_image = TextureRect.new()
    logo_image.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    logo_image.offset_left = -125
    logo_image.offset_right = -20
    logo_image.offset_top = -272
    logo_image.offset_bottom = -164
    logo_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu.add_child(logo_image)
    logo_fallback = _label(menu, "DABSKY", 18, Color("#c2acd6"))
    logo_fallback.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    logo_fallback.offset_left = -145
    logo_fallback.offset_right = -12
    logo_fallback.offset_top = -264
    logo_fallback.offset_bottom = -194

    # Use the original illustrated title and four extracted button textures when available.
    _add_approved_title_art()

    hud = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(hud)
    hud_label = _label(hud, "", 22, Color.WHITE)
    hud_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    hud_label.offset_top = 26
    hud_label.offset_bottom = 112
    hint_label = _label(hud, "DRAG LEFT / RIGHT TO COLLECT ALLIES", 27, Color("#c9ffe6"))
    hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    hint_label.offset_top = 148
    hint_label.offset_bottom = 214
    var exit := Button.new()
    exit.text = "EXIT RUN"
    exit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    exit.offset_left = -155
    exit.offset_right = -24
    exit.offset_top = -88
    exit.offset_bottom = -34
    exit.pressed.connect(_enter_title)
    hud.add_child(exit)

    popup = Control.new()
    popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    popup.mouse_filter = Control.MOUSE_FILTER_STOP
    ui.add_child(popup)
    var fade := ColorRect.new()
    fade.color = Color(0, 0, 0, 0.79)
    fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    popup.add_child(fade)
    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -310
    panel.offset_right = 310
    panel.offset_top = -275
    panel.offset_bottom = 275
    popup.add_child(panel)
    var contents := VBoxContainer.new()
    contents.add_theme_constant_override("separation", 24)
    panel.add_child(contents)
    popup_title = _label(contents, "", 37, Color("#f4d78f"))
    popup_title.custom_minimum_size = Vector2(580, 110)
    popup_body = _label(contents, "", 23, Color("#f9f7f1"))
    popup_body.custom_minimum_size = Vector2(580, 260)
    popup_action = Button.new()
    popup_action.custom_minimum_size = Vector2(520, 72)
    popup_action.add_theme_font_size_override("font_size", 24)
    popup_action.pressed.connect(_do_popup_action)
    contents.add_child(popup_action)
    var close_button := Button.new()
    close_button.text = "CLOSE / RETURN"
    close_button.custom_minimum_size = Vector2(520, 52)
    close_button.pressed.connect(_enter_title)
    contents.add_child(close_button)
    popup.visible = false


func _update_logo() -> void:
    if art_title_enabled:
        # The approved artwork already includes both logos.
        logo_image.visible = false
        logo_fallback.visible = false
        title_background.visible = false
        return
    # Never invent or redraw the user's actual emblem; use it once imported.
    var emblem := "res://assets/branding/dabsky_emblem.png"
    var title_art := "res://assets/branding/title_background.png"
    logo_image.visible = ResourceLoader.exists(emblem)
    logo_fallback.visible = not logo_image.visible
    if logo_image.visible:
        logo_image.texture = load(emblem) as Texture2D
    title_background.visible = ResourceLoader.exists(title_art)
    if title_background.visible:
        title_background.texture = load(title_art) as Texture2D


func _label(parent: Node, value: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label


func _image_button(parent: Node, texture_path: String) -> TextureButton:
    # Godot SVG textures do not reliably render SVG <text> elements.
    var button := TextureButton.new()
    button.ignore_texture_size = true
    button.custom_minimum_size = Vector2(150, 94)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.texture_normal = load(texture_path) as Texture2D
    button.stretch_mode = TextureButton.STRETCH_SCALE
    parent.add_child(button)
    var caption := ""
    if "play_" in texture_path:
        caption = "PLAY"
    elif "upgrades" in texture_path:
        caption = "UPGRADES"
    elif "collection" in texture_path:
        caption = "COLLECTION"
    elif "settings" in texture_path:
        caption = "SETTINGS"
    if not caption.is_empty():
        var label := _label(button, caption, 21 if caption.length() > 6 else 27, Color("#fff3d6"))
        label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.add_theme_color_override("font_shadow_color", Color("#1c1315"))
        label.add_theme_constant_override("shadow_offset_x", 1)
        label.add_theme_constant_override("shadow_offset_y", 2)
    return button


func _add_approved_title_art() -> void:
    const BACKGROUND := "res://assets/branding/title_background.png"
    const PLAY := "res://assets/ui/approved_play.png"
    const UPGRADES := "res://assets/ui/approved_upgrades.png"
    const COLLECTION := "res://assets/ui/approved_collection.png"
    const SETTINGS := "res://assets/ui/approved_settings.png"

    # Only enable artwork mode when all exact artwork and button crops exist.
    # The labeled fallback remains usable until the image assets are installed.
    for source in [BACKGROUND, PLAY, UPGRADES, COLLECTION, SETTINGS]:
        if not ResourceLoader.exists(source):
            return

    art_title_enabled = true
    for child in menu.get_children():
        if child is CanvasItem:
            (child as CanvasItem).visible = false

    var poster := TextureRect.new()
    poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    poster.texture = load(BACKGROUND) as Texture2D
    poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    poster.stretch_mode = TextureRect.STRETCH_SCALE
    poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu.add_child(poster)

    var hit_layer := Control.new()
    hit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu.add_child(hit_layer)

    # Exact positions measured in the original 941 x 1672 artwork.
    play_button = _approved_button(hit_layer, PLAY, Rect2(180, 1175, 574, 163))
    play_button.pressed.connect(_start_level)
    var upgrade_button := _approved_button(hit_layer, UPGRADES, Rect2(50, 1350, 270, 116))
    upgrade_button.pressed.connect(func() -> void: _open_menu_panel("upgrades"))
    var collection_button := _approved_button(hit_layer, COLLECTION, Rect2(340, 1350, 271, 116))
    collection_button.pressed.connect(func() -> void: _open_menu_panel("collection"))
    var settings_button := _approved_button(hit_layer, SETTINGS, Rect2(624, 1350, 276, 116))
    settings_button.pressed.connect(func() -> void: _open_menu_panel("settings"))


func _approved_button(parent: Control, path: String, crop_rect: Rect2) -> TextureButton:
    var button := TextureButton.new()
    button.anchor_left = crop_rect.position.x / 941.0
    button.anchor_right = (crop_rect.position.x + crop_rect.size.x) / 941.0
    button.anchor_top = crop_rect.position.y / 1672.0
    button.anchor_bottom = (crop_rect.position.y + crop_rect.size.y) / 1672.0
    button.ignore_texture_size = true
    button.stretch_mode = TextureButton.STRETCH_SCALE
    button.texture_normal = load(path) as Texture2D
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.focus_mode = Control.FOCUS_ALL
    parent.add_child(button)
    return button


func _update_hud() -> void:
    hud_label.text = "%s  |  %s\nTRIBE: %d   LIFE: %d   GOLD: %d" % [Catalog.get_era(era_index)["name"], Catalog.get_era(era_index)["weapon"], allies, health, gold]
    if time_in_stage < 7.0 and hints_enabled:
        hint_label.text = "DRAG LEFT / RIGHT TO COLLECT ALLIES"
    elif time_in_stage >= 7.0 and time_in_stage < 13.0 and hints_enabled:
        hint_label.text = "YOUR TRIBE ATTACKS AUTOMATICALLY"
    elif time_in_stage > 16.0:
        hint_label.text = "MINIBOSS > BOSS > NEXT ERA"
    if not hints_enabled:
        hint_label.text = ""


func _show_hint(message: String) -> void:
    if hints_enabled and hint_label != null:
        hint_label.text = message


func _open_menu_panel(kind: String) -> void:
    panel_kind = kind
    match kind:
        "upgrades":
            _show_popup("TRIBE UPGRADES", "Gold: %d\nStrength Level: %d\nImprove projectile damage and firing speed.\nUpgrade cost: %d gold" % [gold, attack_upgrade, _upgrade_cost()], "BUY UPGRADE", kind)
        "collection":
            var owned: Array[String] = []
            for key in pets.keys():
                if pets[key]:
                    owned.append(str(key))
            var pet_text := ", ".join(owned) if owned.size() > 0 else "No pets yet. Defeat an era boss!"
            _show_popup("YOUR COLLECTION", "Unlocked eras: %d of %d\nCompanions: %s\nBeat bosses to collect their miniature pets." % [furthest_era + 1, Catalog.era_count(), pet_text], "CLOSE", kind)
        "settings":
            _show_popup("SETTINGS", "Tutorial hints: %s\nControls: drag or use arrow keys.\nProgress saves automatically after victories." % ("ON" if hints_enabled else "OFF"), "TOGGLE HINTS", kind)


func _show_popup(heading: String, body: String, action_text: String, action: String) -> void:
    panel_kind = action
    popup_title.text = heading
    popup_body.text = body
    popup_action.text = action_text
    popup.visible = true
    menu.visible = false
    hud.visible = false
    screen = Screen.POPUP


func _upgrade_cost() -> int:
    return 15 + attack_upgrade * 12


func _do_popup_action() -> void:
    match panel_kind:
        "upgrades":
            if gold >= _upgrade_cost():
                gold -= _upgrade_cost()
                attack_upgrade += 1
                _save()
                _open_menu_panel("upgrades")
            else:
                popup_body.text = "Not enough gold!\nEarn more by fighting in %s." % Catalog.get_era(era_index)["name"]
        "settings":
            hints_enabled = not hints_enabled
            _save()
            _open_menu_panel("settings")
        "collection":
            _enter_title()
        "retry":
            _start_level()
        "continue":
            _enter_title()
        _:
            _enter_title()


func _save() -> void:
    var save := {
        "schema": 1, "era": era_index, "furthest_era": furthest_era,
        "gold": gold, "attack_upgrade": attack_upgrade,
        "hints_enabled": hints_enabled, "pets": pets
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(save))


func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var raw: Variant = JSON.parse_string(file.get_as_text())
    if raw is not Dictionary:
        return
    era_index = clampi(int(raw.get("era", 0)), 0, Catalog.era_count() - 1)
    furthest_era = clampi(int(raw.get("furthest_era", 0)), 0, Catalog.era_count() - 1)
    era_index = mini(era_index, furthest_era)
    gold = maxi(0, int(raw.get("gold", 0)))
    attack_upgrade = clampi(int(raw.get("attack_upgrade", 0)), 0, 100)
    hints_enabled = bool(raw.get("hints_enabled", true))
    var loaded_pets: Variant = raw.get("pets", {})
    if loaded_pets is Dictionary:
        pets = loaded_pets
