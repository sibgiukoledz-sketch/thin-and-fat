# FPS Multiplayer FSM Engine (Godot 4)

Архитектура системы конечных автоматов (FSM) для FPS персонажа и базовой мультиплеерной системы на Godot 4.

## 🏗 Архитектура системы

### 1. Конечный автомат (FSM - Finite State Machine)
- [`scripts/fsm/state.gd`](file:///C:/projects/thin-and-fat/scripts/fsm/state.gd) — Базовый класс состояния `State`.
- [`scripts/fsm/state_machine.gd`](file:///C:/projects/thin-and-fat/scripts/fsm/state_machine.gd) — Контроллер переходов состояний, управляющий активным состоянием.
- [`scripts/player/states/player_state.gd`](file:///C:/projects/thin-and-fat/scripts/player/states/player_state.gd) — Базовый класс состояний персонажа (содержит ссылку на `Player`).
- **Состояния персонажа:**
  - `PlayerIdle` (`Idle`) — Покой, ожидание ввода.
  - `PlayerWalk` (`Walk`) — Обычная ходьба (`WALK_SPEED = 5.0`).
  - `Sprint` (`Sprint`) — Бег с фоновым изменением FOV камеры (`SPRINT_SPEED = 8.5`).
  - `Crouch` (`Crouch`) — Приседание с плавной интерполяцией высоты хитбокса и камеры (`CROUCH_SPEED = 2.5`).
  - `Air` (`Air`) — Прыжок/падение, физика гравитации и инерции в воздухе.

### 2. Мультиплеерная система (Godot 4 High-Level Multiplayer)
- [`scripts/network/network_manager.gd`](file:///C:/projects/thin-and-fat/scripts/network/network_manager.gd) — Autoload-синглтон сети:
  - Настройка `ENetMultiplayerPeer`.
  - Режимы `Host` (Сервер) и `Join` (Клиент).
  - Управление жизненным циклом игроков.
- [`scripts/world/world.gd`](file:///C:/projects/thin-and-fat/scripts/world/world.gd) — Спавн игроков через `MultiplayerSpawner`.
- **Синхронизация:**
  - `MultiplayerSynchronizer` на сцене игрока реплицирует позицию, поворот тела, поворот головы, здоровье, состояние crouching и имя текущего FSM состояния (`synced_state_name`).
  - **RPC (Remote Procedure Calls):**
    - `@rpc("any_peer", "call_local", "reliable") func _handle_fire_rpc(...)` — синхронный выстрел, эффекты трассера и проверка попаданий raycast на стороне сервера.
    - `@rpc("any_peer", "call_local", "reliable") func _apply_damage_rpc(...)` — регистрация урона и смерть/респавн.

---

## 🎮 Управление (Controls)
- **W / A / S / D**: Перемещение
- **Shift**: Спринт
- **Ctrl**: Приседание
- **Space**: Прыжок
- **LMB (Левая кнопка мыши)**: Стрельба
- **Escape**: Захват / Освобождение курсора мыши

---

## 🚀 Как запустить и протестировать мультиплеер

1. Откройте проект `thin-and-fat` в Godot 4.
2. В редакторе Godot нажмите **Debug -> Run Multiple Instances -> Run 2 Instances** (или запустите 2 окна).
3. В первом окне нажмите **HOST GAME**.
4. Во втором окне оставьте `127.0.0.1:8910` и нажмите **JOIN GAME**.
5. Оба игрока появятся на карте, смогут передвигаться (с синхронизацией FSM состояний), приседать, бегать и стрелять друг в друга с подсчетом HP и респавном!
