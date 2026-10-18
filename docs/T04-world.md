# T04 世界骨架

状态：逻辑验证通过。2026-10-18，用户运行世界场景后反馈“完美！”，目视验收通过。未测帧率。

## 运行

用 Godot 打开项目。打开 `scenes/world/world.tscn`。按 F6 运行当前场景。
也可在项目目录运行：

```powershell
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/world/world.tscn
```

默认主场景仍为原有 `main.tscn`。启动游戏批处理仍进入 2D 原型。
本场景的五个物件只显示交互反馈。电脑屏幕和剧情接入属于后续任务。

## 操作与接口

- WASD 移动。鼠标转向。Shift 慢走。E 交互。Esc 暂停操作并释放鼠标。再按 Esc 恢复。
- 玩家胶囊高 1.75 米，半径 0.22 米。视点高 1.62 米。普通速度 2.4 米/秒。慢走速度 1.2 米/秒。
- 射线距离为 2.5 米。墙体和家具阻挡射线。禁用交互物时不显示提示，不发出信号。
- `Interactable` 提供 `prompt_text`、`enabled` 和 `interacted(player)`。
- `Player.set_controls_enabled()` 供后续电脑聚焦接入。它只控制玩家，不暂停整个场景树。
- `move_*`、`interact`、`pause` 是输入动作。`look_*` 预留给手柄视角。本任务未实现手柄。
- 物理层 1 是环境，层 2 是交互区域，层 3 是玩家。

## 场景结构

`World/Station` 实例化原 GLB。`world.gd` 在进入场景时生成 `Collisions` 和 `Interactables` 子节点。可在运行后的 Remote 树检查。
碰撞使用建筑段及家具整体的包围盒。未给每个小网格创建碰撞。
门铰链在当前实例旋转到 -100 度。GLB 与 Blender 文件未改。
前廊临时碰撞面与室内齐平。门槛不形成凸起。前廊外沿有临时边界，防止走入尚未实现的室外区域。T06 接入室外时应替换前廊边界和地面衔接。
室内用一盏无阴影暖色灯。环境光用冷色。未评估画面或性能。

## 自动验证

```powershell
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . res://scenes/world/world.tscn --quit-after 60
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_world.gd
```

测试检查节点、输入动作、五个提示、E 触发信号及占位反馈、禁用状态、超距、实体遮挡、地板支撑、墙体阻挡、门口双向通行、前廊边界、行走速度、慢走及暂停恢复。
这些检查不等于完整人工走查。未检查画面、真实鼠标手感、手柄、性能或后续系统集成。

## 用户目视检查清单

坐标使用 Godot 世界坐标，Y 向上。出生点为 `Player`，约 (-0.1, 0.04, 2.1)。

| 节点或位置 | 操作 | 检查内容 |
|---|---|---|
| `World/Station` 室内 | 从出生点走到各角落，绕过床、椅子、工作台、炉子和机架 | 不穿墙、不掉落；家具碰撞没有不合理阻挡 |
| `MS_Door_Hinge`，门口 x=-1.135、z=3 | 从室内走到前廊再返回 | 门已打开；门框与门槛不卡住；前廊边界符合本任务临时范围 |
| `Interactables/Computer`，西侧工作台 z=0.55 | 对准 CRT 外壳，按 E | 显示“按 E 使用电脑”，左上显示占位反馈 |
| `Interactables/Fax`，西侧工作台 z=1.30 | 对准传真机，按 E | 显示“按 E 查看传真机”和反馈 |
| `Interactables/Radio`，西侧工作台 z=-0.44 | 对准电台，按 E | 显示“按 E 使用电台”和反馈 |
| `Interactables/Manual`，西侧工作台 z=-0.85 | 向下看手册，按 E | 显示“按 E 阅读手册”和反馈 |
| `Interactables/Map`，西墙 z=-1.72、y=2.10 | 抬头看地图，按 E | 显示“按 E 查看地图”和反馈 |
| `Player/Camera3D` 与 HUD | 鼠标转向、WASD、Shift、Esc 两次 | 视角和速度舒适；提示清楚；暂停后能恢复 |
| `WarmCeilingLight`、`WorldEnvironment` | 观察室内和窗口 | 暖色灯与冷色环境光效果由用户判断；性能由用户实测 |
