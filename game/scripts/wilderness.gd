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
var move_bonus := 0.0
var attack_speed_bonus := 0.0
var dodge_chance := 0.0
var bolt_size_bonus := 0.0
var extra_fireball := false
var split_count := 0
var explosion_level := 0
var explosions: Array[Dictionary] = []
var leveling := false
var pending_levels := 0
var level_panel: PanelContainer
var upgrade_list: VBoxContainer
const UPGRADES := ["attack_speed", "move_speed", "dodge", "multishot", "split", "hitbox", "explosion"]
var enemies: Array[Dictionary] = []
var damage_popups: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var corpses: Array[Dictionary] = []
var pickups: Array[Vector2] = []
var firebolts: Array[Dictionary] = []
var facing := Vector2.RIGHT
var movement_facing := Vector2.RIGHT
var casting_target: Dictionary = {}
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
var druid_frames: Dictionary = {}
var enemy_frames: Dictionary = {}
var walk_clock := 0.0
var druid_state := "idle"
var walking := false
var aim_direction := Vector2.RIGHT
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
    _create_ground_cache()
    _load_druid_frames()
    _load_enemy_frames()
    _create_result_popup()
    _create_level_menu()
    _update_hud()

func _load_druid_frames() -> void:
    for direction in range(8):
        for animation in ["idle", "walk", "cast", "hit"]:
            var count := 8 if animation == "walk" else (2 if animation == "cast" else 1)
            for frame in range(count):
                var path := "res://assets/druid/%s_%d_%d.png" % [animation, direction, frame]
                if ResourceLoader.exists(path):
                    druid_frames["%s_%d_%d" % [animation, direction, frame]] = load(path)

func _load_enemy_frames() -> void:
    for kind in ["wolf", "goblin", "skeleton"]:
        for direction in range(8):
            for frame in range(12):
                var key := "%s_%d_%d" % [kind, direction, frame]
                if frame >= 4:
                    var action := "attack" if frame < 8 else ("hit" if frame == 8 else "death")
                    var index := frame - (4 if frame < 8 else (8 if frame == 8 else 9))
                    key = "%s_%s_%d_%d" % [kind, action, direction, index]
                var path := "res://assets/enemies/%s.png" % key
                if ResourceLoader.exists(path):
                    enemy_frames[key] = load(path)

# Blender faces -Y toward the camera at frame zero (screen down).
# Positive Blender Z rotation turns toward screen right, opposite screen angles.
func _enemy_direction(offset: Vector2) -> int:
    return int(round(fposmod(PI / 2.0 - offset.angle(), TAU) / (TAU / 8.0))) % 8

func _draw_enemy_sprite(enemy: Dictionary) -> bool:
    var kind: String = enemy["kind"]
    var pos: Vector2 = enemy["pos"]
    var direction_vector: Vector2 = player_pos - pos
    var direction := _enemy_direction(direction_vector)
    var frame := int(float(enemy.get("walk_clock", 0.0)) * (9.0 if kind == "wolf" else 6.0)) % 4
    var key := "%s_%d_%d" % [kind, direction, frame]
    if enemy.get("dead", false):
        direction = int(enemy["death_direction"])
        key = "%s_death_%d_%d" % [kind, direction, mini(2, int(float(enemy["age"]) * 8.0))]
    elif float(enemy.get("attack_age", -1.0)) >= 0.0:
        direction = int(enemy["attack_direction"])
        var age := float(enemy["attack_age"])
        frame = 0 if age < 0.35 else (1 if age < 0.48 else (2 if age < 0.65 else 3))
        key = "%s_attack_%d_%d" % [kind, direction, frame]
    elif float(enemy.get("hurt", 0.0)) > 0.0:
        key = "%s_hit_%d_0" % [kind, direction]
    if not enemy_frames.has(key):
        return false
    var texture: Texture2D = enemy_frames[key]
    var size := Vector2(84, 105) if kind == "wolf" else Vector2(80, 100)
    draw_texture_rect(texture, Rect2(pos - Vector2(size.x * 0.5, size.y * 0.85), size), false)
    return true

func _draw_druid() -> bool:
    if druid_frames.is_empty():
        return false
    var direction := _enemy_direction(facing)
    var frame := 0
    if druid_state == "walk":
        frame = int(walk_clock * 12.0) % 8
    elif druid_state == "cast":
        frame = 0 if cast_timer > 0.14 else 1
    var key := "%s_%d_%d" % [druid_state, direction, frame]
    if not druid_frames.has(key):
        return false
    var texture: Texture2D = druid_frames[key]
    var size := Vector2(100, 137)
    draw_texture_rect(texture, Rect2(player_pos - Vector2(size.x / 2.0, size.y * 0.76), size), false)
    return true

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

func _menu_style(fill: Color, outline: Color, thickness: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = outline
    style.set_border_width_all(thickness)
    style.set_corner_radius_all(18)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    return style

func _upgrade_color(id: String) -> Color:
    match id:
        "attack_speed": return Color("#d67af1")
        "move_speed": return Color("#83df55")
        "dodge": return Color("#77d5ef")
        "multishot": return Color("#ffb359")
        "split": return Color("#f2d05c")
        "hitbox": return Color("#77b9f2")
        "explosion": return Color("#ff7859")
    return Color("#e9b970")

func _create_level_menu() -> void:
    var overlay := CenterContainer.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(overlay)
    level_panel = PanelContainer.new()
    level_panel.custom_minimum_size = Vector2(610, 690)
    level_panel.add_theme_stylebox_override("panel", _menu_style(Color("#2a2328"), Color("#e9b970"), 4))
    overlay.add_child(level_panel)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 16)
    level_panel.add_child(layout)
    for text_value in ["✦  ✧  ✦", "LEVEL UP!", "Choose 1 Upgrade"]:
        var label := Label.new()
        label.text = text_value
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_color_override("font_color", Color("#f8d39a"))
        label.add_theme_font_size_override("font_size", 48 if text_value == "LEVEL UP!" else 26)
        layout.add_child(label)
    layout.add_child(HSeparator.new())
    upgrade_list = VBoxContainer.new()
    upgrade_list.add_theme_constant_override("separation", 17)
    layout.add_child(upgrade_list)
    level_panel.hide()

func _upgrade_label(id: String) -> String:
    match id:
        "attack_speed": return "Swift Casting  +2.5% (max 20%)"
        "move_speed": return "Forest Stride  +10% (max 100%)"
        "dodge": return "Wild Instinct  +5% (max 25%)"
        "multishot": return "Twin Flame  +1 fireball (once)"
        "split": return "Ember Seeds  +1 random split (max 5)"
        "hitbox": return "Growing Flame  +5% size (max 35%)"
        "explosion": return "Wildfire  larger blast radius"
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
        if id == "attack_speed" and attack_speed_bonus >= 0.199: continue
        if id == "move_speed" and move_bonus >= 0.999: continue
        if id == "dodge" and dodge_chance >= 0.249: continue
        if id == "split" and split_count >= 5: continue
        if id == "hitbox" and bolt_size_bonus >= 0.349: continue
        pool.append(id)
    if pool.is_empty():
        leveling = false
        pending_levels = 0
        level_panel.hide()
        return
    pool.shuffle()
    for i in range(mini(3, pool.size())):
        var id: String = pool[i]
        var choice := Button.new()
        choice.text = _upgrade_label(id).replace("  ", "\n")
        choice.custom_minimum_size = Vector2(550, 135)
        choice.add_theme_font_size_override("font_size", 24)
        choice.add_theme_color_override("font_color", Color("#fff1dc"))
        choice.add_theme_stylebox_override("normal", _menu_style(Color("#322c2c"), _upgrade_color(id), 4))
        choice.add_theme_stylebox_override("hover", _menu_style(Color("#4b3734"), _upgrade_color(id), 5))
        choice.add_theme_stylebox_override("pressed", _menu_style(Color("#59453d"), _upgrade_color(id), 5))
        choice.pressed.connect(_choose_upgrade.bind(id))
        upgrade_list.add_child(choice)
    level_panel.show()

func _choose_upgrade(id: String) -> void:
    match id:
        "attack_speed": attack_speed_bonus = minf(0.20, attack_speed_bonus + 0.025)
        "move_speed": move_bonus = minf(1.0, move_bonus + 0.10)
        "dodge": dodge_chance = minf(0.25, dodge_chance + 0.05)
        "multishot": extra_fireball = true
        "split": split_count = mini(5, split_count + 1)
        "hitbox": bolt_size_bonus = minf(0.35, bolt_size_bonus + 0.05)
        "explosion": explosion_level += 1
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
    walking = movement.length() > 0.1
    if walking:
        walk_clock += delta
    else:
        walk_clock = 0.0
    player_pos += movement.limit_length(1.0) * PLAYER_SPEED * (1.0 + move_bonus) * delta
    if movement.length() > 0.1:
        movement_facing = movement.normalized()
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
    _separate_enemies()
    _update_feedback(delta)
    _update_firebolts(delta)
    _update_explosions(delta)
    _auto_attack()
    if cast_timer > 0.0:
        if not casting_target.is_empty() and enemies.has(casting_target):
            var target_offset: Vector2 = casting_target["pos"] - player_pos
            if target_offset.length_squared() > 0.001:
                aim_direction = target_offset.normalized()
        facing = aim_direction
        druid_state = "cast"
    else:
        if walking:
            facing = movement_facing
        druid_state = "hit" if hit_timer > 0.0 else ("walk" if walking else "idle")
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
    enemies.append({"pos": pos, "kind": kind, "hp": stats["hp"], "attack": 0.0, "walk_clock": rng.randf_range(0.0, 1.0)})

func _update_enemies(delta: float) -> void:
    for i in range(corpses.size() - 1, -1, -1):
        corpses[i]["age"] = float(corpses[i]["age"]) + delta
        if float(corpses[i]["age"]) > 0.85:
            corpses.remove_at(i)
    for enemy in enemies:
        var kind: String = enemy["kind"]
        var stats: Dictionary = ENEMY_TYPES[kind]
        var offset: Vector2 = player_pos - enemy["pos"]
        var distance := offset.length()
        enemy["hurt"] = maxf(0.0, float(enemy.get("hurt", 0.0)) - delta)
        var age := float(enemy.get("attack_age", -1.0))
        if age >= 0.0:
            var next_age := age + delta
            if age < 0.35 and next_age >= 0.35:
                var aim: Vector2 = enemy["attack_aim"]
                if distance <= 52.0 and offset.normalized().dot(aim) >= 0.5 and rng.randf() >= dodge_chance:
                    player_hp = maxf(0.0, player_hp - float(stats["damage"]))
                    hit_timer = 0.2
                    if player_hp <= 0.0:
                        game_over = true
                        _show_result()
                        return
            enemy["attack_age"] = -1.0 if next_age >= 1.0 else next_age
            continue
        if distance > 40.0:
            enemy["pos"] += offset.normalized() * minf(distance - 40.0, float(stats["speed"]) * delta)
            enemy["walk_clock"] = float(enemy["walk_clock"]) + delta
        else:
            enemy["attack_age"] = 0.0
            enemy["attack_aim"] = offset.normalized() if distance > 0.01 else Vector2.DOWN
            enemy["attack_direction"] = _enemy_direction(offset)

func _separate_enemies() -> void:
    for pass_index in range(3):
        for i in range(enemies.size()):
            var a: Dictionary = enemies[i]
            for j in range(i + 1, enemies.size()):
                var b: Dictionary = enemies[j]
                var offset: Vector2 = b["pos"] - a["pos"]
                var distance := offset.length()
                var spacing := float(ENEMY_TYPES[a["kind"]]["radius"]) + float(ENEMY_TYPES[b["kind"]]["radius"])
                if distance < spacing:
                    var axis := offset / distance if distance > 0.001 else Vector2.RIGHT.rotated(float(i + j))
                    var push := axis * (spacing - distance) * 0.5
                    a["pos"] = (a["pos"] - push).clamp(Vector2.ONE * -WORLD_RADIUS, Vector2.ONE * WORLD_RADIUS)
                    b["pos"] = (b["pos"] + push).clamp(Vector2.ONE * -WORLD_RADIUS, Vector2.ONE * WORLD_RADIUS)

func _update_feedback(delta: float) -> void:
    for collection in [damage_popups, impacts]:
        for i in range(collection.size() - 1, -1, -1):
            collection[i]["age"] = float(collection[i]["age"]) + delta
            if float(collection[i]["age"]) >= float(collection[i]["duration"]):
                collection.remove_at(i)

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
    attack_timer = ATTACK_COOLDOWN * (1.0 - attack_speed_bonus)
    cast_timer = 0.28
    attack_flash = 0.20
    var direction: Vector2 = (enemies[nearest]["pos"] - player_pos).normalized()
    aim_direction = direction
    casting_target = enemies[nearest]
    _spawn_bolt(_casting_origin(direction), enemies[nearest], false)
    if extra_fireball:
        var second := -1
        var second_best := ATTACK_RANGE
        for i in range(enemies.size()):
            if i == nearest: continue
            var distance: float = player_pos.distance_to(enemies[i]["pos"])
            if distance < second_best:
                second = i
                second_best = distance
        _spawn_bolt(_casting_origin(direction), enemies[second] if second >= 0 else enemies[nearest], false)

# Sprite feet sit at player_pos; upper torso is about 45 px above the feet.
# Launch bolts from the raised casting hand rather than the collision origin.
func _casting_origin(direction: Vector2) -> Vector2:
    return player_pos + Vector2(0.0, -45.0) + direction * 24.0

func _spawn_bolt(origin: Vector2, target: Dictionary, is_child: bool) -> void:
    var direction: Vector2 = (target["pos"] - origin).normalized()
    firebolts.append({"pos": origin, "target": target, "direction": direction, "life": 1.5, "child": is_child, "random": false})

func _spawn_split_bolt(origin: Vector2, source_enemy: Dictionary) -> void:
    var angle := rng.randf_range(0.0, TAU)
    var direction := Vector2.RIGHT.rotated(angle)
    firebolts.append({"pos": origin, "target": {}, "direction": direction, "life": 0.85, "child": true, "random": true, "excluded_enemy": source_enemy})

func _damage_enemy(target: Dictionary, damage: float) -> void:
    if not enemies.has(target):
        return
    target["hp"] = float(target["hp"]) - damage
    target["hurt"] = 0.15
    damage_popups.append({"pos": target["pos"], "amount": damage, "age": 0.0, "duration": 0.75})
    if float(target["hp"]) <= 0.0:
        var corpse := target.duplicate()
        corpse["dead"] = true
        corpse["age"] = 0.0
        var offset: Vector2 = player_pos - target["pos"]
        corpse["death_direction"] = _enemy_direction(offset)
        corpses.append(corpse)
        pickups.append(target["pos"])
        enemies.erase(target)

func _impact_bolt(bolt: Dictionary, target: Dictionary) -> void:
    var point: Vector2 = bolt["pos"]
    impacts.append({"pos": point, "age": 0.0, "duration": 0.28})
    _damage_enemy(target, player_damage * (0.65 if bolt["child"] else 1.0))
    if explosion_level > 0:
        var radius := 65.0 + 25.0 * float(explosion_level)
        explosions.append({"pos": point, "radius": radius, "age": 0.0, "duration": 0.38})
        for enemy in enemies.duplicate():
            if bolt.has("excluded_enemy") and enemy == bolt["excluded_enemy"]:
                continue
            if point.distance_to(enemy["pos"]) <= radius:
                _damage_enemy(enemy, player_damage * 0.65)
    # Every primary bolt produces its splits, even if there are no other targets.
    # Split children fly straight in random directions and do not recursively split.
    if split_count > 0 and not bolt["child"]:
        for i in range(split_count):
            _spawn_split_bolt(point, target)

func _update_firebolts(delta: float) -> void:
    for i in range(firebolts.size() - 1, -1, -1):
        var bolt: Dictionary = firebolts[i]
        bolt["life"] = float(bolt["life"]) - delta
        if float(bolt["life"]) <= 0.0:
            firebolts.remove_at(i)
            continue
        var direction: Vector2 = bolt["direction"]
        if not bolt["random"]:
            var target: Dictionary = bolt["target"]
            if not enemies.has(target):
                firebolts.remove_at(i)
                continue
            direction = (target["pos"] - bolt["pos"]).normalized()
            bolt["direction"] = direction
        var previous: Vector2 = bolt["pos"]
        bolt["pos"] = previous + direction * FIREBOLT_SPEED * delta
        var hit_radius := 10.0 * (1.0 + bolt_size_bonus)
        var hit: Dictionary = {}
        for enemy in enemies:
            if bolt.has("excluded_enemy") and enemy == bolt["excluded_enemy"]:
                continue
            var enemy_radius: float = float(ENEMY_TYPES[enemy["kind"]]["radius"])
            var center: Vector2 = enemy["pos"]
            var segment: Vector2 = bolt["pos"] - previous
            var t := clampf((center - previous).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
            if center.distance_to(previous + segment * t) <= hit_radius + enemy_radius:
                hit = enemy
                break
        if not hit.is_empty():
            _impact_bolt(bolt, hit)
            firebolts.remove_at(i)

func _update_explosions(delta: float) -> void:
    for i in range(explosions.size() - 1, -1, -1):
        explosions[i]["age"] = float(explosions[i]["age"]) + delta
        if float(explosions[i]["age"]) >= float(explosions[i]["duration"]):
            explosions.remove_at(i)

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
    var area := Rect2(camera.get_screen_center_position() - visible * 0.5, visible).grow(100.0)

    for pickup in pickups:
        if area.has_point(pickup):
            var bob := Vector2(0, sin(elapsed * 4.0 + pickup.x) * 3.0)
            draw_circle(pickup, 12.0, Color(0.3, 0.9, 0.9, 0.18))
            draw_colored_polygon(PackedVector2Array([pickup + bob + Vector2(0,-10), pickup + bob + Vector2(6,0), pickup + bob + Vector2(0,8), pickup + bob + Vector2(-6,0)]), Color("#63e5e7"))
    var actors: Array[Dictionary] = []
    actors.append({"pos": player_pos, "player": true})
    for tree in trees:
        if area.grow(150.0).has_point(tree):
            actors.append({"pos": tree, "tree": true})
    for corpse in corpses:
        if area.has_point(corpse["pos"]):
            actors.append(corpse)
    for enemy in enemies:
        if area.has_point(enemy["pos"]):
            actors.append(enemy)
    actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)
    for actor in actors:
        if actor.get("tree", false):
            _draw_forest_tree(actor["pos"])
        elif actor.get("player", false):
            _draw_player_actor()
        elif actor.get("dead", false):
            _draw_enemy_sprite(actor)
        else:
            _draw_living_enemy(actor)
    for enemy in enemies:
        if not area.has_point(enemy["pos"]):
            continue
        var ratio := clampf(float(enemy["hp"]) / float(ENEMY_TYPES[enemy["kind"]]["hp"]), 0.0, 1.0)
        if ratio < 1.0:
            var bar: Vector2 = enemy["pos"] - Vector2(19, 83)
            draw_rect(Rect2(bar, Vector2(38, 5)), Color("#302422"))
            draw_rect(Rect2(bar, Vector2(38 * ratio, 5)), Color("#e26b50"))
    for effect in impacts:
        if not area.has_point(effect["pos"]):
            continue
        var t := float(effect["age"]) / float(effect["duration"])
        var p: Vector2 = effect["pos"]
        for k in range(8):
            var d := Vector2.RIGHT.rotated(k * TAU / 8.0)
            draw_line(p + d * 8, p + d * (12 + 30 * t), Color(1, 0.65, 0.2, 1-t), 3)
    for popup in damage_popups:
        if not area.has_point(popup["pos"]):
            continue
        var t := float(popup["age"]) / float(popup["duration"])
        var p: Vector2 = popup["pos"] - Vector2(12, 60 + 38 * t)
        draw_string(ThemeDB.fallback_font, p, str(roundi(float(popup["amount"]))), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.9, 0.65, 1-t))
    if cast_timer > 0.0:
        var hand := _casting_origin(aim_direction)
        draw_circle(hand, 12.0 + 4.0 * sin(elapsed * 30.0), Color("#ffb32b", 0.60))
        draw_circle(hand, 6.0, Color("#fff2a1"))
    for blast in explosions:
        var progress: float = float(blast["age"]) / float(blast["duration"])
        var radius: float = float(blast["radius"]) * (0.2 + 0.8 * progress)
        var alpha := 1.0 - progress
        draw_circle(blast["pos"], radius, Color(1.0, 0.27, 0.05, alpha * 0.28))
        draw_arc(blast["pos"], radius, 0.0, TAU, 40, Color(1.0, 0.76, 0.2, alpha), 10.0)
        draw_circle(blast["pos"], radius * 0.45, Color(1.0, 0.85, 0.28, alpha * 0.32))
    for bolt in firebolts:
        var bolt_radius := 10.0 * (1.0 + bolt_size_bonus)
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

func _draw_player_actor() -> void:
    if not _draw_druid():
        draw_circle(player_pos + Vector2(4, 12), 24.0, Color(0, 0, 0, 0.28))
        var cloak := PackedVector2Array([player_pos + Vector2(-18, -14), player_pos + Vector2(18, -14), player_pos + Vector2(25, 24), player_pos + Vector2(-25, 24)])
        draw_colored_polygon(cloak, Color("#344e36"))
        var tunic := PackedVector2Array([player_pos + Vector2(-15, -13), player_pos + Vector2(15, -13), player_pos + Vector2(9, 4), player_pos + Vector2(20, 18), player_pos + Vector2(-20, 18), player_pos + Vector2(-9, 4)])
        draw_colored_polygon(tunic, Color("#65814c"))
        draw_circle(player_pos + Vector2(-11, -17), 12.0, Color("#865239"))
        draw_circle(player_pos + Vector2(11, -17), 12.0, Color("#865239"))
        draw_circle(player_pos + Vector2(0, -17), 14.0, Color("#b87d51"))
        draw_circle(player_pos + Vector2(0, -14), 10.0, Color("#edc4a5"))

func _draw_living_enemy(enemy: Dictionary) -> void:
    var pos: Vector2 = enemy["pos"]
    var kind: String = enemy["kind"]
    var color := Color("#bbd4c4")
    if kind == "goblin":
        color = Color("#a8ba52")
    elif kind == "wolf":
        color = Color("#9c8571")
    draw_circle(pos + Vector2(4, 7), 19.0, Color(0.0, 0.0, 0.0, 0.24))
    if not _draw_enemy_sprite(enemy):
        draw_circle(pos, float(ENEMY_TYPES[kind]["radius"]), color)
        draw_circle(pos + Vector2(0, -5), 4.0, Color("#252922"))

func _draw_rock(p: Vector2) -> void:
    var scale_factor := 0.7 + fposmod(absf(sin(p.x * 0.31 + p.y)), 1.0)
    draw_set_transform(p, 0.0, Vector2.ONE * scale_factor)
    draw_circle(Vector2(5, 5), 16, Color(0.08, 0.14, 0.08, 0.25))
    draw_colored_polygon(PackedVector2Array([Vector2(-17,4),Vector2(-12,-10),Vector2(2,-15),Vector2(15,-7),Vector2(18,5),Vector2(5,11)]), Color("#777d70"))
    draw_colored_polygon(PackedVector2Array([Vector2(-12,-10),Vector2(2,-15),Vector2(15,-7),Vector2(0,0),Vector2(-17,4)]), Color("#a2a394"))
    draw_set_transform(Vector2.ZERO)

func _draw_forest_tree(p: Vector2) -> void:
    var f := absf(sin(p.x * 0.17 + p.y * 0.29))
    var size_factor := 0.75 + f * 0.85
    draw_set_transform(p, 0.0, Vector2.ONE * size_factor)
    draw_circle(Vector2(12, 8), 35, Color(0.05, 0.12, 0.06, 0.28))
    if f < 0.18:
        for i in range(5):
            var q := Vector2(i * 12 - 24, -absf(sin(i * 2.1)) * 12)
            draw_circle(q, 15, Color("#294c2c"))
            draw_circle(q - Vector2(3, 5), 11, Color("#52723b"))
    else:
        draw_colored_polygon(PackedVector2Array([Vector2(-10,3),Vector2(-5,-70),Vector2(6,-70),Vector2(11,3)]), Color("#63472e"))
        draw_line(Vector2(-3,-3), Vector2(-2,-60), Color("#98704a"), 3)
        if f > 0.65:
            for i in range(3):
                var y := -25.0 - i * 22.0
                var w := 40.0 - i * 8.0
                draw_colored_polygon(PackedVector2Array([Vector2(-w,y),Vector2(0,y-58),Vector2(w,y),Vector2(0,y+9)]), Color("#234e35").lightened(i * 0.07))
                draw_colored_polygon(PackedVector2Array([Vector2(-w,y),Vector2(0,y-58),Vector2(0,y+9)]), Color("#426b40").lightened(i * 0.05))
        else:
            for i in range(7):
                var q := Vector2(cos(i * 2.4) * 26, -65 + sin(i * 2.4) * 21)
                draw_circle(q, 25, Color("#234c2e"))
                draw_circle(q - Vector2(5, 7), 20, Color("#3d6938").lightened(i * 0.025))
    draw_set_transform(Vector2.ZERO)

func _create_ground_cache() -> void:
    # CanvasItem draw commands are retained until queue_redraw is called.
    # Separate static chunks from the dynamic combat canvas.
    for cx in range(-5, 5):
        for cy in range(-5, 5):
            var chunk := Node2D.new()
            chunk.z_index = -2
            add_child(chunk)
            chunk.position = Vector2(cx, cy) * 512.0
            var area := Rect2(Vector2.ZERO, Vector2(512, 512))
            chunk.draw.connect(_draw_ground_chunk.bind(chunk, area))
    var rocks := Node2D.new()
    rocks.z_index = -1
    add_child(rocks)
    rocks.draw.connect(_draw_static_rocks.bind(rocks))

func _draw_ground_chunk(chunk: Node2D, area: Rect2) -> void:
    chunk.draw_rect(area, Color("#426a3d"))
    for x in range(floori(area.position.x / 64.0), ceili(area.end.x / 64.0)):
        for y in range(floori(area.position.y / 64.0), ceili(area.end.y / 64.0)):
            var h := absf(sin((x + chunk.position.x / 64.0) * 127.1 + (y + chunk.position.y / 64.0) * 311.7) * 43758.5453)
            var f := fposmod(h, 1.0)
            var p := Vector2(x * 64.0 + f * 57.0, y * 64.0 + fposmod(h * 17.3, 1.0) * 57.0)
            chunk.draw_circle(p, 14.0 + f * 26.0, Color(0.19, 0.32, 0.16, 0.12))
            for k in range(3):
                var q := p + Vector2(k * 4 - 4, 0)
                chunk.draw_line(q, q + Vector2(k * 3 - 3, -5 - f * 8), Color("#72904b"), 1.5)
            if f > 0.88:
                chunk.draw_circle(p + Vector2(12, 8), 2.0, Color("#d0b477"))

func _draw_static_rocks(node: Node2D) -> void:
    for p in stones:
        var scale_factor := 0.7 + fposmod(absf(sin(p.x * 0.31 + p.y)), 1.0)
        node.draw_set_transform(p, 0.0, Vector2.ONE * scale_factor)
        node.draw_circle(Vector2(5, 5), 16, Color(0.08, 0.14, 0.08, 0.25))
        node.draw_colored_polygon(PackedVector2Array([Vector2(-17,4),Vector2(-12,-10),Vector2(2,-15),Vector2(15,-7),Vector2(18,5),Vector2(5,11)]), Color("#777d70"))
        node.draw_colored_polygon(PackedVector2Array([Vector2(-12,-10),Vector2(2,-15),Vector2(15,-7),Vector2(0,0),Vector2(-17,4)]), Color("#a2a394"))
    node.draw_set_transform(Vector2.ZERO)
