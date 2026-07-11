extends Node
## EventBus — 全局事件总线
## 用于各系统之间的解耦通信

signal player_moved(direction: Vector2)
signal player_captured_enemy(enemy_type: String, value: float)
signal player_level_up(new_level: int)
signal player_hit(damage: int)
signal skill_cast(skill_id: String, direction: Vector2)
signal skill_ready(skill_id: String)
signal wave_started(wave_num: int)
signal wave_cleared(wave_num: int)
signal enemy_spawned(enemy_type: String, position: Vector2)
signal enemy_removed(enemy_type: String)
signal gesture_detected(gesture_type: String, data: Dictionary)
signal card_added(card_id: String)
signal fusion_triggered(fusion_name: String, cards: Array)
signal game_paused(paused: bool)
