extends Node2D
## Playable, asset-free wilderness combat prototype.
## All gameplay is in world coordinates. Art can later be replaced with directional
## Blender-rendered sprite atlases without changing movement or combat rules.

const WORLD_RADIUS := 2200.0
const PLAYER_SPEED := 245.0
const ATTACK_RANGE := 370.0
const FIREBOLT_SPEED := 680.0
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
var move_multiplier := 1.0
var attack_multiplier := 1.0
var dodge_chance := 0.0
var bolt_radius := 10.0
var extra_fireball := false
var split_fireballs := false
var explosive_fireballs := false
var leveling := false
var pending_levels := 0
var level_panel: PanelContainer
var upgrade_list: VBoxContainer
const UPGRADES := ["attack_speed", "move_speed", "dodge", "multishot", "split", "hitbox", "explosion"]
var enemies: Array[Dictionary] = []
var pickups: Array[Vector2] = []
var firebolts: Array[Dictionary] = []
var facing := Vector2.RIGHT
var cast_timer := 0.0
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
    hint_label.text = "Drag to move. Fire bolts cast automatically."
    hud.add_child(hint_label)
    _create_result_popup()
    _create_level_menu()
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

func _create_level_menu() -> void:
    var overlay := CenterContainer.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(overlay)
    level_panel = PanelContainer.new()
    level_panel.custom_minimum_size = Vector2(590, 530)
    overlay.add_child(level_panel)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 18)
    level_panel.add_child(layout)
    var heading := Label.new()
    heading.text = "LEVEL UP!  CHOOSE ONE"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 30)
    layout.add_child(heading)
    upgrade_list = VBoxContainer.new()
    upgrade_list.add_theme_constant_override("separation", 14)
    layout.add_child(upgrade_list)
    level_panel.hide()

func _upgrade_label(id: String) -> String:
    match id:
        "attack_speed": return "Swift Casting  -  20% faster attacks"
        "move_speed": return "Forest Stride  -  15% faster movement"
        "dodge": return "Wild Instinct  -  +8% dodge chance"
        "multishot": return "Twin Flame  -  cast two fireballs"
        "split": return "Ember Seeds  -  split on impact"
        "hitbox": return "Growing Flame  -  +35% fireball size"
        "explosion": return "Wildfire  -  explosive impact"
    return id

func _show_level_menu() -> void:
    leveling = true
    touch_index = -1
    touch_vector = Vector2.ZERO
    for child in upgrade_list.get_children():
        child.queue_free()
    var pool: Array[String] = []
    for id in UPGRADES:
        if id == "multishot" and extra_fireball: continue
        if id == "split" and split_fireballs: continue
        if id == "explosion" and explosive_fireballs: continue
        pool.append(id)
    pool.shuffle()
    for i in range(mini(3, pool.size())):
        var id: String = pool[i]
        var choice := Button.new()
        choice.text = _upgrade_label(id)
        choice.custom_minimum_size = Vector2(550, 108)
        choice.add_theme_font_size_override("font_size", 23)
        choice.pressed.connect(_choose_upgrade.bind(id))
        upgrade_list.add_child(choice)
    level_panel.show()

func _choose_upgrade(id: String) -> void:
    match id:
        "attack_speed": attack_multiplier *= 1.20
        "move_speed": move_multiplier *= 1.15
        "dodge": dodge_chance = minf(0.75, dodge_chance + 0.08)
        "multishot": extra_fireball = true
        "split": split_fireballs = true
        "hitbox": bolt_radius *= 1.35
        "explosion": explosive_fireballs = true
    level_panel.hide()
    pending_levels -= 1
    if pending_levels > 0:
        _show_level_menu()
    else:
        leveling = false

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
    if game_over or leveling:
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
    player_pos += movement.limit_length(1.0) * PLAYER_SPEED * move_multiplier * delta
    if movement.length() > 0.1:
        facing = movement.normalized()
    player_pos = player_pos.clamp(Vector2.ONE * -WORLD_RADIUS, Vector2.ONE * WORLD_RADIUS)
    camera.position = player_pos
    attack_timer -= delta
    hit_timer -= delta
    attack_flash = maxf(0.0, attack_flash - delta)
    cast_timer = maxf(0.0, cast_timer - delta)
    spawn_timer -= delta
    if spawn_timer <= 0.0 and enemies.size() < MAX_ENEMIES:
        var wave := int(elapsed / 60.0) + 1
        for i in range(mini(2 + wave / 2, MAX_ENEMIES - enemies.size())):
            _spawn_enemy(wave)
        spawn_timer = maxf(0.25, 2.0 - elapsed / 420.0)
    _update_enemies(delta)
    _update_firebolts(delta)
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
            if rng.randf() < dodge_chance:
                enemy["attack"] = 1.0
                continue
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
    attack_timer = ATTACK_COOLDOWN / attack_multiplier
    cast_timer = 0.28
    attack_flash = 0.20
    var direction: Vector2 = (enemies[nearest]["pos"] - player_pos).normalized()
    facing = direction
    _spawn_bolt(player_pos + direction * 28.0, enemies[nearest], false)
    if extra_fireball:
        var second := -1
        var second_best := ATTACK_RANGE
        for i in range(enemies.size()):
            if i == nearest: continue
            var distance: float = player_pos.distance_to(enemies[i]["pos"])
            if distance < second_best:
                second = i
                second_best = distance
        _spawn_bolt(player_pos + direction * 28.0, enemies[second] if second >= 0 else enemies[nearest], false)

func _spawn_bolt(origin: Vector2, target: Dictionary, is_child: bool) -> void:
    var direction: Vector2 = (target["pos"] - origin).normalized()
    firebolts.append({"pos": origin, "target": target, "direction": direction, "life": 1.5, "child": is_child})

func _damage_enemy(target: Dictionary, damage: float) -> void:
    if not enemies.has(target): return
    target["hp"] = float(target["hp"]) - damage
    if float(target["hp"]) <= 0.0:
        pickups.append(target["pos"])
        enemies.erase(target)

func _impact_bolt(bolt: Dictionary, target: Dictionary) -> void:
    var point: Vector2 = bolt["pos"]
    var candidates: Array[Dictionary] = []
    for enemy in enemies:
        if enemy != target and point.distance_to(enemy["pos"]) < 270.0:
            candidates.append(enemy)
    _damage_enemy(target, player_damage * (0.65 if bolt["child"] else 1.0))
    if explosive_fireballs:
        for enemy in enemies.duplicate():
            if point.distance_to(enemy["pos"]) <= 90.0 + bolt_radius:
                _damage_enemy(enemy, player_damage * 0.65)
    if split_fireballs and not bolt["child"]:
        candidates.shuffle()
        for i in range(mini(2, candidates.size())):
            if enemies.has(candidates[i]):
                _spawn_bolt(point, candidates[i], true)

func _update_firebolts(delta: float) -> void:
    for i in range(firebolts.size() - 1, -1, -1):
        var bolt: Dictionary = firebolts[i]
        bolt["life"] = float(bolt["life"]) - delta
        var target: Dictionary = bolt["target"]
        if not enemies.has(target) or float(bolt["life"]) <= 0.0:
            firebolts.remove_at(i)
            continue
        var direction: Vector2 = (target["pos"] - bolt["pos"]).normalized()
        bolt["direction"] = direction
        bolt["pos"] += direction * FIREBOLT_SPEED * delta
        if (bolt["pos"] as Vector2).distance_to(target["pos"]) < 15.0 + bolt_radius:
            _impact_bolt(bolt, target)
            firebolts.remove_at(i)

func _collect_pickups() -> void:
    for i in range(pickups.size() - 1, -1, -1):
        if player_pos.distance_to(pickups[i]) < 44.0:
            pickups.remove_at(i)
            player_xp += 1
            if player_xp >= xp_needed:
                player_xp -= xp_needed
                player_level += 1
                xp_needed += 4
                pending_levels += 1
                if not leveling:
                    _show_level_menu()

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
    # Woodland druid silhouette: layered moss cloak, leather, auburn hair, and antler ornaments.
    # shoulder ornaments and an extended casting hand. Placeholder 2.5D art.
    draw_circle(player_pos + Vector2(5, 12), 25.0, Color(0, 0, 0, 0.28))
    var robe := PackedVector2Array([
        player_pos + Vector2(-13, -5), player_pos + Vector2(13, -5),
        player_pos + Vector2(20, 22), player_pos + Vector2(-20, 22)
    ])
    draw_colored_polygon(robe, Color("#42583c") if hit_timer <= 0 else Color("#dc6666"))
    draw_circle(player_pos + Vector2(-13, -13), 12.0, Color("#714b35"))
    draw_circle(player_pos + Vector2(12, -13), 12.0, Color("#553044"))
    draw_circle(player_pos + Vector2(0, -10), 16.0, Color("#553044"))
    draw_circle(player_pos + Vector2(0, -9), 11.0, Color("#f0c6a9"))
    draw_arc(player_pos + Vector2(0, -9), 13.0, PI, TAU, 16, Color("#a56d45"), 5.0)
    draw_line(player_pos + Vector2(-9, 5), player_pos + Vector2(9, 5), Color("#b49a6d"), 7.0)
    # Leaf mantle, leather belt, and branch-like crown add naturalistic detail.
    draw_line(player_pos + Vector2(-14, 4), player_pos + Vector2(13, 4), Color("#6e4b30"), 5.0)
    draw_circle(player_pos + Vector2(0, 4), 3.0, Color("#c1a567"))
    draw_line(player_pos + Vector2(-10, -20), player_pos + Vector2(-18, -31), Color("#8b734c"), 3.0)
    draw_line(player_pos + Vector2(10, -20), player_pos + Vector2(18, -31), Color("#8b734c"), 3.0)
    draw_line(player_pos + Vector2(-17, -29), player_pos + Vector2(-23, -33), Color("#8b734c"), 2.0)
    draw_line(player_pos + Vector2(17, -29), player_pos + Vector2(23, -33), Color("#8b734c"), 2.0)
    var hand := player_pos + facing * (37.0 if cast_timer > 0.0 else 22.0)
    draw_line(player_pos + facing * 10.0, hand, Color("#6f8b54"), 9.0)
    draw_circle(hand, 7.0, Color("#f0c6a9"))
    if cast_timer > 0.0:
        draw_circle(hand + facing * 5.0, 13.0 + 7.0 * sin(elapsed * 30.0), Color("#ffb32b", 0.65))
        draw_circle(hand + facing * 5.0, 7.0, Color("#fff2a1"))
    for bolt in firebolts:
        var p: Vector2 = bolt["pos"]
        var d: Vector2 = bolt["direction"]
        draw_line(p - d * 34.0, p, Color("#ff5722", 0.45), bolt_radius * 1.6)
        draw_line(p - d * 19.0, p, Color("#ffb331", 0.85), bolt_radius * 0.9)
        draw_circle(p, bolt_radius, Color("#ff7a19"))
        draw_circle(p, bolt_radius * 0.5, Color("#fff3a4"))
    if touch_index >= 0:
        var base := touch_origin + camera.get_screen_center_position() - get_viewport_rect().size / 2.0
        draw_circle(base, TOUCH_RADIUS, Color(1, 1, 1, 0.15))
        draw_circle(base + touch_vector * TOUCH_RADIUS, 35.0, Color(1, 1, 1, 0.4))
