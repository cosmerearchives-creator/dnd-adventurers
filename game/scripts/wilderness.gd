extends Node2D
## Playable, asset-free wilderness combat prototype.
## All gameplay is in world coordinates. Art can later be replaced with directional
## Blender-rendered sprite atlases without changing movement or combat rules.

const WORLD_RADIUS := 2200.0
const PLAYER_SPEED := 245.0
const ATTACK_RANGE := 118.0
const ATTACK_COOLDOWN := 0.55
const TOUCH_RADIUS := 105.0
const MAX_ENEMIES := 85
const ENEMY_TYPES := {
    "wolf": {"speed": 130.0, "hp": 22.0, "damage": 8.0, "radius": 14.0},
    "goblin": {"speed": 88.0, "hp": 34.0, "damage": 12.0, "radius": 17.0},
    "skeleton": {"speed": 72.0, "hp": 54.0, "damage": 16.0, "radius": 18.0}
}

var player_pos := Vector2.ZERO
var player_hp := 100.0
var player_max_hp := 100.0
var player_level := 1
var player_xp := 0
var xp_needed := 6
var player_damage := 18.0
var enemies: Array[Dictionary] = []
var pickups: Array[Vector2] = []
var trees: Array[Vector2] = []
var stones: Array[Vector2] = []
var elapsed := 0.0
var spawn_timer := 0.0
var attack_timer := 0.0
var hit_timer := 0.0
var attack_flash := 0.0
var game_over := false
var victory := false
var touch_index := -1
var touch_origin := Vector2.ZERO
var touch_vector := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var camera: Camera2D
var hud: CanvasLayer
var status_label: Label
var hint_label: Label
var result_panel: PanelContainer
var result_title: Label

func _ready() -> void:
    rng.seed = 20261122
    for i in range(260):
        trees.append(Vector2(rng.randf_range(-WORLD_RADIUS, WORLD_RADIUS), rng.randf_range(-WORLD_RADIUS, WORLD_RADIUS)))
    for i in range(130):
        stones.append(Vector2(rng.randf_range(-WORLD_RADIUS, WORLD_RADIUS), rng.randf_range(-WORLD_RADIUS, WORLD_RADIUS)))
    # Clear the initial spawn area.
    trees = trees.filter(func(p: Vector2) -> bool: return p.length() > 240.0)
    stones = stones.filter(func(p: Vector2) -> bool: return p.length() > 170.0)
    camera = Camera2D.new()
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 7.0
    add_child(camera)
    camera.make_current()
    hud = CanvasLayer.new()
    add_child(hud)
    status_label = Label.new()
    status_label.position = Vector2(22, 18)
    status_label.add_theme_font_size_override("font_size", 24)
    hud.add_child(status_label)
    hint_label = Label.new()
    hint_label.position = Vector2(22, 64)
    hint_label.add_theme_font_size_override("font_size", 17)
    hint_label.text = "Drag the left side to move. Attacks are automatic."
    hud.add_child(hint_label)
    _create_result_popup()
    _update_hud()

func _create_result_popup() -> void:
    var overlay := CenterContainer.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(overlay)
    result_panel = PanelContainer.new()
    result_panel.custom_minimum_size = Vector2(520, 300)
    overlay.add_child(result_panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 22)
    result_panel.add_child(content)
    result_title = Label.new()
    result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_title.add_theme_font_size_override("font_size", 38)
    content.add_child(result_title)
    var restart := Button.new()
    restart.text = "RESTART ADVENTURE"
    restart.custom_minimum_size = Vector2(470, 96)
    restart.add_theme_font_size_override("font_size", 28)
    restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
    content.add_child(restart)
    result_panel.hide()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1 and event.position.x < get_viewport_rect().size.x * 0.55:
            touch_index = event.index
            touch_origin = event.position
            touch_vector = Vector2.ZERO
        elif not event.pressed and event.index == touch_index:
            touch_index = -1
            touch_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == touch_index:
        touch_vector = (event.position - touch_origin).limit_length(TOUCH_RADIUS) / TOUCH_RADIUS

func _process(delta: float) -> void:
    if game_over:
        queue_redraw()
        return
    elapsed += delta
    if elapsed >= 600.0:
        game_over = true
        victory = true
        _show_result()
        _update_hud()
        return
    var movement := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if touch_vector.length() > 0.08:
        movement = touch_vector
    player_pos += movement.limit_length(1.0) * PLAYER_SPEED * delta
    player_pos = player_pos.clamp(Vector2.ONE * -WORLD_RADIUS, Vector2.ONE * WORLD_RADIUS)
    camera.position = player_pos
    attack_timer -= delta
    hit_timer -= delta
    attack_flash = maxf(0.0, attack_flash - delta)
    spawn_timer -= delta
    if spawn_timer <= 0.0 and enemies.size() < MAX_ENEMIES:
        var wave := int(elapsed / 60.0) + 1
        for i in range(mini(2 + wave / 2, MAX_ENEMIES - enemies.size())):
            _spawn_enemy(wave)
        spawn_timer = maxf(0.25, 2.0 - elapsed / 420.0)
    _update_enemies(delta)
    _auto_attack()
    _collect_pickups()
    _update_hud()
    queue_redraw()

func _spawn_enemy(wave: int) -> void:
    var angle := rng.randf_range(0.0, TAU)
    var pos := player_pos + Vector2.RIGHT.rotated(angle) * rng.randf_range(500.0, 720.0)
    pos = pos.clamp(Vector2.ONE * -WORLD_RADIUS, Vector2.ONE * WORLD_RADIUS)
    var kind := "wolf"
    var roll := rng.randf()
    if wave >= 4 and roll < 0.25:
        kind = "skeleton"
    elif roll < 0.60:
        kind = "goblin"
    var stats: Dictionary = ENEMY_TYPES[kind]
    enemies.append({"pos": pos, "kind": kind, "hp": stats["hp"], "attack": 0.0})

func _update_enemies(delta: float) -> void:
    for enemy in enemies:
        var kind: String = enemy["kind"]
        var stats: Dictionary = ENEMY_TYPES[kind]
        var offset: Vector2 = player_pos - enemy["pos"]
        var distance := offset.length()
        if distance > 35.0:
            enemy["pos"] += offset.normalized() * float(stats["speed"]) * delta
        enemy["attack"] = float(enemy["attack"]) - delta
        if distance < 43.0 and float(enemy["attack"]) <= 0.0:
            player_hp -= float(stats["damage"])
            enemy["attack"] = 1.0
            hit_timer = 0.2
            if player_hp <= 0.0:
                player_hp = 0.0
                game_over = true
                _show_result()

func _auto_attack() -> void:
    if attack_timer > 0.0:
        return
    var nearest := -1
    var best := ATTACK_RANGE
    for i in range(enemies.size()):
        var distance: float = player_pos.distance_to(enemies[i]["pos"])
        if distance < best:
            nearest = i
            best = distance
    if nearest < 0:
        return
    attack_timer = ATTACK_COOLDOWN
    attack_flash = 0.16
    enemies[nearest]["hp"] = float(enemies[nearest]["hp"]) - player_damage
    if float(enemies[nearest]["hp"]) <= 0.0:
        pickups.append(enemies[nearest]["pos"])
        enemies.remove_at(nearest)

func _collect_pickups() -> void:
    for i in range(pickups.size() - 1, -1, -1):
        if player_pos.distance_to(pickups[i]) < 44.0:
            pickups.remove_at(i)
            player_xp += 1
            if player_xp >= xp_needed:
                player_xp -= xp_needed
                player_level += 1
                xp_needed += 4
                player_damage += 5.0
                player_max_hp += 8.0
                player_hp = minf(player_max_hp, player_hp + 25.0)

func _update_hud() -> void:
    var wave := int(elapsed / 60.0) + 1
    status_label.text = "HP %d/%d   LV %d   XP %d/%d   WAVE %d   %02d:%02d" % [
        int(player_hp), int(player_max_hp), player_level, player_xp, xp_needed,
        wave, int(elapsed) / 60, int(elapsed) % 60
    ]
    if game_over:
        hint_label.text = "Choose Restart Adventure to play again."

func _show_result() -> void:
    result_title.text = "WILDERNESS SURVIVED!" if victory else "ADVENTURE ENDED"
    result_panel.show()

func _draw() -> void:
    var visible := get_viewport_rect().size / camera.zoom
    var area := Rect2(player_pos - visible * 0.7, visible * 1.4)
    draw_rect(Rect2(Vector2.ONE * -WORLD_RADIUS, Vector2.ONE * WORLD_RADIUS * 2.0), Color("#426a3d"))
    # Ground detail is deterministic and cheap: only draw near the camera.
    var start_x := int(floor(area.position.x / 100.0))
    var end_x := int(ceil(area.end.x / 100.0))
    var start_y := int(floor(area.position.y / 100.0))
    var end_y := int(ceil(area.end.y / 100.0))
    for x in range(start_x, end_x):
        for y in range(start_y, end_y):
            var center := Vector2(x * 100.0 + 35.0, y * 100.0 + 47.0)
            draw_circle(center, 17.0, Color("#4a7440"))
            draw_circle(center + Vector2(30, -21), 7.0, Color("#60834a"))
    for stone in stones:
        if area.has_point(stone):
            draw_circle(stone, 13.0, Color("#7e8074"))
            draw_circle(stone + Vector2(-4, -4), 7.0, Color("#a6a69b"))
    for tree in trees:
        if area.has_point(tree):
            draw_circle(tree + Vector2(7, 11), 35.0, Color(0.08, 0.18, 0.08, 0.35))
            draw_rect(Rect2(tree - Vector2(5, 3), Vector2(10, 28)), Color("#5a3c28"))
            draw_circle(tree + Vector2(0, -15), 33.0, Color("#204d2e"))
            draw_circle(tree + Vector2(-11, -24), 21.0, Color("#31643a"))
    for pickup in pickups:
        if area.has_point(pickup):
            draw_circle(pickup, 8.0, Color("#63e5e7"))
    for enemy in enemies:
        var pos: Vector2 = enemy["pos"]
        if not area.has_point(pos):
            continue
        var kind: String = enemy["kind"]
        var color := Color("#bbd4c4")
        if kind == "goblin":
            color = Color("#a8ba52")
        elif kind == "wolf":
            color = Color("#9c8571")
        draw_circle(pos + Vector2(4, 7), 19.0, Color(0.0, 0.0, 0.0, 0.24))
        draw_circle(pos, float(ENEMY_TYPES[kind]["radius"]), color)
        draw_circle(pos + Vector2(0, -5), 4.0, Color("#252922"))
    draw_circle(player_pos + Vector2(4, 9), 21.0, Color(0, 0, 0, 0.3))
    draw_circle(player_pos, 19.0, Color("#376bba") if hit_timer <= 0 else Color("#e65d52"))
    draw_circle(player_pos + Vector2(0, -7), 7.0, Color("#f0cfac"))
    if attack_flash > 0.0:
        draw_arc(player_pos, ATTACK_RANGE, 0, TAU, 60, Color("#f5e6aa", 0.5), 4.0)
    if touch_index >= 0:
        var base := touch_origin + camera.get_screen_center_position() - get_viewport_rect().size / 2.0
        draw_circle(base, TOUCH_RADIUS, Color(1, 1, 1, 0.15))
        draw_circle(base + touch_vector * TOUCH_RADIUS, 35.0, Color(1, 1, 1, 0.4))
