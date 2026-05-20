import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flame/collisions.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';

class EnglishQuestGame extends FlameGame with HasCollisionDetection {
  late Player _player;
  late JoystickComponent joystick;
  late TiledComponent mapComponent;

  final Function(Enemy) onBattleTriggered;

  EnglishQuestGame({required this.onBattleTriggered});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load Tiled Map
    mapComponent = await TiledComponent.load('map.tmx', Vector2.all(32));
    add(mapComponent);

    // Parse Spawns
    final spawnGroup = mapComponent.tileMap.getLayer<ObjectGroup>('Spawns');
    bool hasPlayerSpawn = false;
    if (spawnGroup != null) {
      for (final obj in spawnGroup.objects) {
        if (obj.name == 'Player') {
          _player = Player(position: Vector2(obj.x, obj.y));
          hasPlayerSpawn = true;
        } else if (obj.name == 'Enemy') {
          add(Enemy(position: Vector2(obj.x, obj.y)));
        }
      }
    } else {
      // Add random enemies if no spawn layer
      final rng = Random();
      for (int i = 0; i < 5; i++) {
        add(Enemy(
          position: Vector2(
            max(40.0, rng.nextDouble() * (mapComponent.size.x - 40.0)),
            max(40.0, rng.nextDouble() * (mapComponent.size.y - 40.0)),
          ),
        ));
      }
    }

    // Fallback if player wasn't in the map
    if (!hasPlayerSpawn) {
      _player = Player(position: mapComponent.size / 2);
    }
    
    // Add collisions from map (ObjectGroup)
    final collisionsGroup = mapComponent.tileMap.getLayer<ObjectGroup>('Collisions');
    if (collisionsGroup != null) {
      for (final obj in collisionsGroup.objects) {
        add(MapBoundary(Vector2(obj.x, obj.y), Vector2(obj.width, obj.height)));
      }
    }

    // Add collisions from map (Tile Layer "Colisao")
    final colLayer = mapComponent.tileMap.getLayer<TileLayer>('Colisao');
    if (colLayer != null && colLayer.tileData != null) {
      final w = colLayer.width;
      final h = colLayer.height;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final gid = colLayer.tileData![y][x].tile;
          if (gid != 0) {
            add(MapBoundary(Vector2(x * 32.0, y * 32.0), Vector2(32, 32)));
          }
        }
      }
    }

    // Setup joystick
    final knobPaint = BasicPalette.blue.withAlpha(200).paint();
    final backgroundPaint = BasicPalette.blue.withAlpha(100).paint();

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 40, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );

    add(_player);
    _player.joystick = joystick;
    add(joystick);
    
    // Camera follow player
    camera.follow(_player);
  }

  void resumeGame() {
    resumeEngine();
  }
}

class MapBoundary extends PositionComponent with CollisionCallbacks {
  MapBoundary(Vector2 position, Vector2 size) : super(position: position, size: size) {
    add(RectangleHitbox());
  }
}

class Player extends SpriteComponent with CollisionCallbacks {
  JoystickComponent? joystick;
  final double speed = 150.0;
  Vector2 _lastPosition = Vector2.zero();

  Player({required Vector2 position}) : super(position: position, size: Vector2(32, 32), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = await Sprite.load('player.png');
    add(RectangleHitbox(size: Vector2(24, 24), position: Vector2(4, 4)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (joystick != null && !joystick!.delta.isZero()) {
      _lastPosition = position.clone();
      position.add(joystick!.relativeDelta * speed * dt);
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      if (!other.isDefeated) {
        (parent as EnglishQuestGame).pauseEngine();
        (parent as EnglishQuestGame).onBattleTriggered(other);
      }
    } else if (other is MapBoundary) {
      // Basic collision resolution: revert to last position
      position = _lastPosition.clone();
    }
  }
}

class Enemy extends SpriteComponent with CollisionCallbacks {
  bool isDefeated = false;

  Enemy({required Vector2 position}) : super(position: position, size: Vector2(32, 32), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = await Sprite.load('enemy.png');
    add(RectangleHitbox(size: Vector2(24, 24), position: Vector2(4, 4)));
  }

  void defeat() async {
    isDefeated = true;
    // Just dim the sprite for now
    setOpacity(0.3);
  }
}

