# T06 室外环境

实现与逻辑验证完成。2026-10-18 用户目视审核通过（返工一轮后反馈“完美！”）。

## 运行

在 Godot 中打开 `scenes/world/world.tscn`，按 F6。
WASD 行走。鼠标转向。Shift 慢走。Esc 释放鼠标。
原 `main.tscn` 仍是 2D 原型入口。

玩家不能切换天气或昼夜。游戏自己运行：时间流逝，天气按气候规律变化。
默认从上午 9 点、晴天开始。每次运行的天气序列不同。

## 自动天气与昼夜

- 一整天为 30 现实分钟（`day_length_seconds`）。1 游戏小时约 75 秒。日出 5:30，日落 19:00。
- 太阳从东升到西落，月亮在夜里反向走过。黄昏有暖色地平线，入夜与天亮都是渐变。
- 天气只走相邻的一步：晴 ↔ 阴 ↔ 暴雨。晴天不会直接变暴雨。
- 变暴雨前云层先加厚，先下毛毛雨，再逐渐变大。雨声随雨量由小到大。雨停后云层慢慢散开。
- 下午到傍晚（13:00 到 20:00）阴天转暴雨的概率更高。刚下完暴雨，很少马上再下。
- 地面遇雨约 25 秒变湿，雨后约 140 秒才干。
- 天气持续时间：晴 3 到 7 分钟，阴 2 到 5 分钟，暴雨 4 到 7 分钟（现实时间）。
- 草地与泥土任何时候都不反光（不映月亮、太阳和天空）。湿了只会变暗。前廊缓坡等硬表面湿了才有高光。

检查画面时想定格某个状态（开发用，不是玩家功能）。

在编辑器里按 F6：选中 `World/Environment` 节点，在检查器里改 `Start Hour`（钟点）、`Start Weather`（初始天气），关掉 `Auto Progress` 就冻结。

命令行也可以，参数只影响初始状态：

```powershell
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/world/world.tscn -- --weather=storm --time=night
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/world/world.tscn -- --hour=18.5 --weather=overcast
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/world/world.tscn -- --weather=storm --static
```

`--weather=` 支持 `sunny`、`overcast`、`storm`。`--time=` 支持 `day`（中午）、`night`（午夜）。
`--hour=` 设置钟点（0 到 24）。`--static` 冻结天气与时间，方便定格检查画面。

## 山坡

玩家可走的最大坡度（`floor_max_angle`）为 55°。源地形山腰最陡约 50°，旧值 45° 会在半山腰被当作墙。
地形中有约 1% 的采样点陡于 60°，仍是墙（崖面）。

## 内容与接口

- `World/Outdoor`：42 个地形分块。每块约 32 米。包含源文件的草甸、地形、小径空带与干河槽。
- `World/Outdoor/Species*`：70 类 Botaniq 植被与石块。3,086 个源实例。近、远两级 MultiMesh 各保留一份实例变换。
- 树木在 55 米切换远级，在 140 米剔除。其他植被及石块在 28 米切换，在 55 米剔除。距离针对批次包围盒中心，非每株植物。批次另有视锥剔除。
- `World/Outdoor/Trunks` 与 `Rocks`：树干圆柱及石块包围盒碰撞。草、蕨类和灌木允许穿行。
- `World/Outdoor/Boundary`：四面地图边界。地形网格碰撞不随显示距离关闭。
- `World/Outdoor/PorchRamp`：前廊至地面缓坡。替代 T04 的前廊临时边界。
- `World/Environment`：程序天空、雾，以及 `Sun`、`Moon` 两盏平行光。随时钟与云量连续变化。
- `World/Environment/Rain`：CPU 雨粒子。跟随玩家。着色器按雨量丢弃一部分雨滴（小雨稀、大雨密），并遮掉屋内及廊下的雨滴。
- `World/Environment/RainAudioPlaceholder`：固定种子的循环噪声占位。音量随雨量渐变，室内降低 10 dB。没有引入正式音效。
- 雨天地形与草甸只变暗，不反光。前廊缓坡的粗糙度随湿度降低，产生高光。此方案没有积水模拟或屏幕空间反射。
- 植被（草、蕨、灌木、树）材质关闭高光。石块保留。

T07 可把剧情标志对应的预设名传给本地节点。切换是瞬时的，之后自动模拟从新状态继续：

```gdscript
$Environment.set_preset("storm")
$Environment.set_preset("night")
```

天气切换保留昼夜。昼夜切换保留天气（`day` 为中午，`night` 为午夜）。
需要固定状态时，把 `Environment.auto_progress` 设为 `false`。
无效名称返回 `false`，不改变状态。
成功切换发出 `preset_changed(weather, time_of_day)`。自动模拟改变天气或昼夜时也会发出。
此处提供接口，不实现 T07 的剧情标志系统。

## 导出

```powershell
& E:/blender.exe --background --factory-startup --python art_source/export_outdoor.py
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import
```

脚本重新读取唯一主文件。脚本不保存 `.blend`。
依赖源文件引用的本机 `E:/polygoniq_asset_packs/` 素材库。
游戏运行仅依赖导出资产，不依赖 Blender 或素材库。

坐标原点采用维修站地板中心。Blender 坐标减去 `(-53.910122, 49.763187, 0.32)` 后，转换为 Godot 的 `(x, z, -y)`。
地形全部保留。植被使用主文件保存的轻量视口粒子分布，不展开完整渲染密度，不重新撒点。
近级网格预算：树木 6,000 面，其他 1,800 面。
远级预算：树木 900 面，其他 250 面。
预算按 Blender 多边形数设置减面比例，不等同于最终三角形数。

Botaniq 程序材质不能直接等价转入 glTF。
本次采用源材质的实体预览色和简单 PBR。没有烘焙纹理，没有复制 Blender 的完整叶片、树皮着色。
森林密度、叶片形态、材质风格及 LOD 跳变需用户审核。
该选择不改动主文件的材质、粒子数量、随机种子或视口设置。

`assets/outdoor/manifest.json` 记录源文件 SHA256、坐标偏移、分块、物种、实例变换与各 GLB 的 SHA256。
两次独立导出的清单及所有 43 个 GLB 完全一致。

## 已验证

```powershell
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/test_outdoor.gd
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/test_world.gd
```

- Godot 4.7.2 无头导入及世界启动。
- 六种天气与昼夜组合。无效预设不改变状态。
- 雨粒子与音频启停。湿润参数切换。
- 固定种子模拟 8 个游戏日：天气只走相邻一步；云量、雨量、湿度无跳变；时钟在 0 到 24 内；同种子序列相同，不同种子不同。
- 毛毛雨到暴雨的渐变；雨声随雨量增大；雨停后地面仍湿，慢慢变干。
- 地形与植被材质无高光；雨天地形变暗；昼夜只亮一盏光（日光或月光）。
- 玩家 `floor_max_angle` 为 55°。无头步行：旧 45° 在南坡停在高度 8 米；55° 可走到 31 米，并从北侧和西南侧走上 36 米山顶。
- 近远级实例数量一致。距离范围有效。
- 四面边界阻挡。树干与石块碰撞存在。
- 121 处地形射线均有碰撞。前廊衔接点有地面。
- 玩家通过门口、缓坡走到室外，再返回室内。
- T04 室内碰撞、五类交互、遮挡、暂停及慢走回归。
- 重复导出哈希一致。主 `.blend`、备份和维修站 GLB 哈希未变。

未验证全部室外路线、实际输入手感、画面、音效听感或性能。
未验证雨量着色器（用 `INSTANCE_ID` 丢弃雨滴）在 GPU 上的编译与效果：无头模式不编译着色器。
未验证日出日落、云层与雨的视觉渐变，以及真实游玩中的天气节奏是否合适。
没有截图、渲染检查、帧率测试或视觉自审。
无头模式不验证 GPU 着色器最终表现。

## 用户目视检查清单

1. 运行 `world.tscn`。从前门出发，沿 `PorchRamp` 下到空地，再返回室内。检查门槛、坡面和地面接缝。检查是否卡住或悬空。
2. 从空地沿草甸小径走向森林。检查 `Outdoor/Species*` 的密度、大小、地面贴合、实体预览色及远近切换。
3. 绕树干和石块行走。检查可见模型与简化碰撞是否吻合。灌木和草允许穿行。
4. 从维修站向东南方向探索河槽。源河槽中心大致位于世界 `(59, -1.67, 50)`。河槽为干河槽，没有新增水面。检查地形、小径、山坡及分块接缝。
5. 尝试走向地图四周。检查 `Outdoor/Boundary` 是否阻止掉出地图。检查边界位置是否自然。
6. 正常运行并等待（约 3 到 7 分钟出现阴天，再过几分钟可能暴雨；想直接看，把 `Start Weather` 改为 `storm`）。检查云层加厚、毛毛雨渐大、雨声渐强，以及雨后天空慢慢变亮。检查屋内和廊下是否漏雨。
7. 检查草地和泥土在白天、夜晚、暴雨时都没有太阳或月亮的反光。前廊缓坡雨天有高光是预期的。
8. 把 `Start Hour` 改为 18.5 看黄昏，改为 5 看黎明。检查日落到夜晚、夜晚到天亮是否平滑，夜间可辨识度、月光和室内暖灯是否合适。
9. 检查山腰（约 50° 的坡）能走上去，山顶约在世界坐标 (96, 36, 19)。陡于 60° 的崖面仍走不上去是预期的。
10. 用户自行检查室外与室内性能。任务目标为室外 ≥45 FPS、室内 ≥60 FPS。agent 未测量，不宣称达标。
