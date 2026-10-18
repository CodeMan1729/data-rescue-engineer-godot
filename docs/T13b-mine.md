# T13b 矿场接入

逻辑验证通过。等待用户目视审核。agent 未截图、未渲染检查、未测帧率。

## 位置（D1 到 D4 按推荐值）

- 矿场在东侧山的南麓平地上。节点 `World/Mine`，世界坐标 (92, -0.26, 96)，不旋转。
- 入口（门楼中心）在该点，朝南（+Z）。营地向北（-Z）延伸 30 米，背靠山脚。后方岩体在 z 约 65 到 68。
- 远景版与营地版是同一个矿场，共用入口原点。两者不叠放：玩家离营地中心 85 米以内显示营地版，以外显示远景版。
  切换点有 ±5 米死区，不会来回跳。
- 营地地面比平地高 6 厘米（-0.26 对 -0.32），避免与草甸网格（-0.315）重叠闪烁。
- 前窗中心到第一盏灯 128 米。从门廊下坡口走到入口前约 41 秒（正常速度 3.6 米/秒），途中穿过干河槽。
- 营地版范围内的植被与树石碰撞被移除（x 71 到 113，z 63 到 104，共 155 个实例）。

## 运行

```powershell
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/world/world.tscn -- --at-mine --mine=on
```

开发用参数（只影响初始状态，不是玩家功能），可组合：

- `--mine=off|on|flicker|rain`：远景状态。默认 `off`。
- `--mine-open`、`--mine-closed`：营地开放或关闭。`world.tscn` 现在默认开放（见下）。
- `--at-mine`：玩家出生在入口前 8 米。
- 天气参数照旧，例如 `--weather=storm --time=night`。

编辑器里也可改 `World/Mine/MineVista` 的 `Start State`，和 `World/Mine/MineSite` 的 `Start Open`。

**营地默认开放。** 首轮目视时，营地默认关闭，玩家在门口被不可见墙挡住，被当成故障。
剧情标志（T07）还不存在，所以 `world.tscn` 里 `MineSite.start_open` 先设为 `true`。
T07 接入时，游戏开始应调用 `set_open(false)`，到 ch12 再 `set_open(true)`。脚本自身的默认值仍是关闭。
想看关闭效果，加 `--mine-closed`。

## 接口（给 T07）

```gdscript
%MineVista.set_state("on")   # off | on | flicker | rain，返回 bool；无效名称返回 false，不改状态
%MineSite.set_open(true)     # 开放或关闭营地入口
```

在 `World` 场景内可用唯一名称 `%MineVista`、`%MineSite`，也可用路径 `Mine/MineVista`、`Mine/MineSite`。

**MineVista**（`scripts/world/mine_vista.gd`）

| 状态 | 表现 |
|---|---|
| `off` | 整个远景不可见，灯熄灭 |
| `on` | 四盏灯常亮 |
| `flicker` | 四盏灯各自随机熄灭、微亮、全亮 |
| `rain` | 四盏灯常亮，亮度降到 60% |

- 信号：`state_changed(state)`、`levels_changed(levels)`。
- 每盏灯有发光网格和一个加色光晕面片。灯体只有约 0.4 米，从站内看不见，所以靠光晕（`halo_size` 默认 6 米）。光晕不受雾影响。
- 营地版的 4 盏灯（发光网格加 `OmniLight3D`）由 `World` 脚本跟随远景亮度，远近两处同步。
- `STORY-BEATS.md` 第 7 节的章节对应表由 T07 实现。此处只提供接口。

**MineSite**（`scripts/world/mine_site.gd`）

- 关闭：入口外围有四面不可见墙（整个营地一圈）。玩家不能从门口，也不能绕过围栏端头进入。
  墙内面 x = ±17.5、前 z = +1.0、后 z = -31.5（营地空间）。玩家最近能站到离门线约 1.7 米处。
- 开放：墙的碰撞层清零。玩家可进入。围栏、小屋、发电机等简化碰撞照常生效。
- 信号：`open_changed(is_open)`、`interacted(key, player)`。
- `is_open()` 返回当前状态。

**碰撞与交互标记**（来自 GLB 的 `MN_Collision_*`、`MN_Interact_*`）

- 23 个 `MN_Collision_*` 变成 `MineSite/Collisions` 下同名的 `CollisionShape3D`（盒体，尺寸为标记缩放的两倍，层 1）。
- 8 个 `MN_Interact_*` 变成 `MineSite/Interactables/<名字>`，类型为 `Interactable`（层 2，T04 系统）。
  按 E 发出 `MineSite.interacted(key, player)`。`World` 显示占位反馈，不含剧情文本。

| key | 提示 |
|---|---|
| `Gate` | 按 E 查看入口 |
| `TornSeal` | 按 E 查看封条 |
| `Computer` | 按 E 使用调度电脑 |
| `WinchControl` | 按 E 查看绞车操作箱 |
| `MineCart` | 按 E 查看矿车 |
| `Adit` | 按 E 查看平硐口 |
| `Generator` | 按 E 查看发电机 |
| `WarningSign` | 按 E 阅读警示牌 |

`Gate` 与 `TornSeal` 的触发盒向营地外伸出，所以营地关闭时站在墙外也能触发。里面的物件在墙外够不到。

## 对旧代码的改动

- `scripts/world/outdoor.gd`：加 `clearings`、`cleared_instances` 与 `_is_cleared()`。加入组 `outdoor_clearing` 的节点（`MineSite`）报告范围，范围内的植被实例和树石碰撞不再生成。
- `scripts/world/world.gd`：加 `_connect_mine()`，连灯光、交互反馈和 `--at-mine`。
- `scenes/world/world.tscn`：加 `Mine`、`MineVista`、`MineSite` 三个节点。
- `tests/test_outdoor.gd`：植被数量检查扣除被移除的实例。
- 未改：维修站 GLB、`.blend`、两个矿场 GLB、玩家与交互基类。

## 自动验证

```powershell
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script res://tests/test_mine.gd
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_world.gd
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_outdoor.gd
```

`test_mine.gd` 的行走段约 4,000 个物理帧。加 `--fixed-fps 60` 几秒跑完。不加则按实时跑，约 1.5 分钟。

`test_mine.gd` 检查：

- 23 个碰撞标记和 8 个交互标记都存在，盒体尺寸与位置同标记一致，节点未被重复缩放。
- 四盏灯、四个光晕、四个营地灯光。
- `set_state`：四种状态的亮度，灯体能量，光晕显隐，营地灯光跟随；无效名称不改状态；信号顺序；
  闪烁出现全灭和全亮，各灯独立，同一随机种子复现同一图案。
- 远近切换：死区，远景关闭时仍显示营地。
- 植被：移除数量等于源数据范围内的实例数，其余全部生成，范围内无树石碰撞。
- 地面贴合：营地范围内无地形穿出地面，下方无悬空超过 15 厘米，每点都有地板。
- `set_open`：前门、侧面、绕过围栏端头在关闭时都挡住，开放后通行；来回切换两轮；信号序列。
- 交互：8 个区域都能被射线命中；关闭时在墙外能触发 `Gate`、`TornSeal`，够不到 `Computer`；开放后在小屋里能触发并发出信号。
- 视线：前窗和门口到四盏灯的射线不被地形挡住。
- 真实行走：玩家从门廊下坡口出发，规划绕开树干和岩石的路线，走到入口前（42 秒，最低高度 -1.77，即河槽）。
  关闭时顶住入口被挡；开放后通过入口，绕过矿车走到平硐口前，再返回并进入调度小屋。全程不卡、不掉。
- 变异检查：临时让关闭墙失效，测试如预期失败；已还原。

另外：`tests/test_world.gd`、`tests/test_outdoor.gd` 通过。`art_source/mine/validate_mine.gd` 通过（GLB 未改）。
世界场景带 `--mine=flicker --mine-open --at-mine` 等参数无头启动，无报错。

**未验证**

- 一切画面：灯光与光晕观感、光晕大小、矿场与地形接缝、岩体与山的衔接、清空范围的边缘、材质风格是否协调。
- 光晕与加色混合在 GPU 上的实际效果；雾和暴雨下灯光是否仍可见。无头模式不编译着色器。
- 从站内窗口实际能否看到灯。测试只查地形和 2.5 米树干碰撞桩。真实树冠比碰撞桩高，可能挡住部分视线。
- 切换点附近远近两版是否有明显跳变。
- 帧率与性能。营地版有 471 个网格和 4 盏灯，远景版 444 个三角形。
- 真实鼠标手感；手柄；T07 剧情标志（尚不存在）的接入。

## 用户目视检查清单

坐标为 Godot 世界坐标，Y 向上。先运行：

```powershell
& './tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/world/world.tscn -- --mine=on --time=night --static
```

| 节点或位置 | 操作 | 检查内容 |
|---|---|---|
| 站内前窗（约 (0.95, 1.5, 3)）、门口 | 站在窗内或门口，朝东南（约 128 米外）看 | 四盏灯是否可见；光晕大小和亮度；有无树挡住 |
| 同上，换 `--mine=flicker`、`--mine=rain` | 同上，暴雨加 `--weather=storm` | 闪烁节奏；雨中亮度；雾里是否仍可见 |
| 同上，`--mine=off`（默认） | 同上 | 远景完全看不见 |
| 路线：门廊坡 → 河槽 → 营地入口 | 正常走约 1 分钟，或用 `--at-mine` 直达 | 路是否顺；河槽能否过；有无被树挡路 |
| 距营地约 85 米处 | 慢慢走近，再退回 | 远景换成营地时的跳变是否可接受 |
| `World/Mine/MineSite`，入口前 | `--at-mine`，看门楼、围栏、封条 | 营地与地面接缝（6 厘米台阶）；清空范围边缘是否自然；营地朝向与背后山脚的衔接 |
| 营地入口外约 1.7 米 | 加 `--mine-closed`，走向门口 | 不可见墙位置是否合理；围栏两侧和后侧是否走不进去；按 E 对准门和封条有提示 |
| 营地内（默认开放） | 进门，沿矿车旁走到平硐口，进调度小屋 | 通行是否顺；矿车、绞车房、发电机、油桶的碰撞范围；小屋门宽；每个交互点的提示和位置 |
| 四根灯柱（营地版） | `--mine=on`、`flicker`、`rain`，夜间在营地内 | 营地灯光亮度和范围；与远景的灯是否同步 |
| 营地后侧岩体 | 走到平硐口前，向两侧看 | 岩体与山坡衔接；能否看见穿帮 |
| 性能 | 自行观察 | 营地版和天气同时开启时的帧率（agent 未测） |
