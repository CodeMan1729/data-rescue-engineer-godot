# T13a 矿场资产交付

建模与数据验证完成。2026-10-18，用户明确确认目视审核“通过”。T13b 已接入 Godot，见 `docs/T13b-mine.md`。本文件只记录建模交付，模型与导出未因 T13b 改动。

## 打开资产

用 Blender 打开本目录的 `Data_Rescue_Mine.blend`。
顶部场景选择器提供 `mine_site` 和 `mine_vista`。
默认打开 `mine_site`。视口保持 SOLID，使用材质颜色。
两场景共用入口原点。不要同时叠放两个版本。

单位为米。Blender 的 Z 向上，+Y 指向营地内部。
导出后 glTF 的 +Y 向上，-Z 指向营地内部。
营地地面宽 32 米，纵向从 -2 米到 30 米。
调度室门宽 1.3 米。主入口宽约 5.5 米。
平硐口只有外壳和黑色封底，没有矿洞内部。

材质采用灰蓝金属、旧木、铸铁、锈色和米色电脑。
电脑、铁件和金属墙面参数参照维修站 GLB 的对应材质。
本资产采用常量 PBR 材质，不使用图片纹理，不依赖外部字体。
中文标牌已转为网格。没有新增剧情文本。
实际材质风格与比例是否协调，由用户审核。
灯罩内含 `MN_MAT_Lamp_Emissive` 发光网格。
没有添加实际照明灯节点。实际照明与灯光状态接口留给 T13b。

## 节点清单

完整对象清单见 `node_manifest.json`。其中记录父节点、类型、坐标、缩放与三角形数。

| 场景 | 根节点 | 节点数 | GLB 三角形 | 预算 |
|---|---|---:|---:|---:|
| mine_site | MN_MineSite | 512 | 28,104 | 150,000 |
| mine_vista | MN_MineVista | 35 | 444 | 20,000 |

| 营地分组 | 内容 |
|---|---|
| MN_Ground | 泥地、轨道碎石层、积水与散石 |
| MN_Gate | 关闭标牌、旧门楼、围栏、开启门扇与分离封条 |
| MN_Dispatch | 调度室、桌椅、CRT 电脑和键盘占位 |
| MN_WinchHouse | 绞车房、卷筒、电机和操作箱 |
| MN_Railway | 矿轨、枕木、矿车 |
| MN_Adit | 平硐口外壳、封底与后方岩体 |
| MN_GeneratorCamp | 临时发电机、油桶、地面电缆与雨棚 |
| MN_Lighting | 四根灯柱、灯罩和发光体 |
| MN_WarningSign | 塌方警示牌 |
| MN_Vista_Silhouette（远景） | 简化建筑、门楼、围栏、岩体、雨棚和四处发光体 |

## 交互标记清单

全部为 `Empty` 空节点。没有交互脚本。
以下为 Blender 坐标。glTF 坐标按 `(x, z, -y)` 转换。

| 节点 | 位置（米） | 对应物件 |
|---|---|---|
| MN_Interact_Gate | (0, 0, 1.2) | 入口 |
| MN_Interact_TornSeal | (-2.8, 0.3, 1.35) | 左门扇封条 |
| MN_Interact_Computer | (-8, 8.85, 1.35) | 调度室电脑 |
| MN_Interact_WinchControl | (6.6, 16.95, 1.3) | 绞车操作箱 |
| MN_Interact_MineCart | (0, 12.8, 1.15) | 矿车 |
| MN_Interact_Adit | (0, 26, 1.5) | 平硐口 |
| MN_Interact_Generator | (9.6, 6.2, 0.95) | 发电机操作面板 |
| MN_Interact_WarningSign | (-4, 21.8, 1.8) | 塌方警示牌 |

## 碰撞交接

23 个 `MN_Collision_*` 节点使用立方体显示的 Empty。
它们覆盖地面、两侧前围栏、开启门扇、两座小屋的侧墙和后墙及前墙、桌面设备、绞车、矿车、洞口封底、后方岩体、发电机和油桶组。
节点没有可见网格，不会把代理盒显示为建筑。
每个节点导出 `shape=box` 和 `half_extents_from_node_scale=true` 元数据。
在 T13b 中使用导入节点的局部变换创建碰撞体。
盒子的完整尺寸为导入节点缩放绝对值的两倍。
创建碰撞形状后，应将碰撞节点缩放还原为一，避免重复缩放。
Blender 到 glTF 的轴转换已由导出器处理，不要再手动交换导入节点的坐标。
这些节点目前不是 Godot 物理碰撞体。尚未验证实际通行。
入口开放控制、围界补齐和站外路径衔接留给 T13b。

## 导出与验证

在项目根目录运行。示例使用本机 Blender 路径。

```powershell
& E:/blender.exe --background --factory-startup --python-exit-code 1 --python art_source/mine/export_mine.py
& E:/blender.exe --background --factory-startup --python-exit-code 1 --python art_source/mine/validate_mine.py
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script art_source/mine/validate_mine.gd
```

`export_mine.py` 读取已保存的 Blender 文件，只导出两个 GLB，不重建、不保存源文件。
修改前先在 Blender 中保存。命令行导出不会读取尚未保存的编辑。
`build_mine.py` 是本次初建记录。已有源文件时拒绝覆盖。后续编辑直接修改 `.blend`。
`validate_mine.py` 校验命名、单位、视口模式、节点保留、面数、发光材质和坐标转换，并更新完整节点清单。
`validate_mine.gd` 直接读取两个 GLB 并实例化，不接入世界，不需要新增 `.import` 配置。

已验证两个 GLB 无头加载、发光网格数量和电脑标记坐标。
未截图，未渲染检查，未测帧率，未做视觉评估。
以上是 T13a 当时的验证范围。实际碰撞、通行、交互与灯光切换在 T13b 做了无头逻辑验证，见 `docs/T13b-mine.md`。

## 需用户目视检查清单

打开 `.blend`，保持 SOLID。在场景选择器选场景，在 Outliner 选节点，按小键盘句点聚焦。

| 场景或节点 | 操作路径 | 检查内容 |
|---|---|---|
| mine_site / MN_MineSite | 打开默认场景，绕营地观察 | 整体尺度、布局、材质风格与维修站是否协调 |
| MN_Gate | 聚焦门楼，从入口正面观察 | “矿场·关闭”文字、旧围栏、开门姿态和分离封条是否清楚 |
| MN_Dispatch | 聚焦小屋，从正门观察内部 | 门窗、桌椅、CRT 和键盘的比例，电脑占位是否合适 |
| MN_WinchHouse、MN_Railway | 沿轨道观察绞车房和矿车 | 设备辨识度、轨距、矿车和枕木的接触关系 |
| MN_Adit | 从轨道朝后方观察 | 洞口外壳、岩体衔接和封底；不要期待矿洞内部 |
| MN_GeneratorCamp | 从入口右侧观察 | 临时电缆、发电机、油桶、雨棚是否表达重启痕迹 |
| MN_Ground、MN_WarningSign | 聚焦地面和警示牌 | 泥地、积水边缘、散石与警示文字 |
| MN_Interact_*、MN_Collision_* | Outliner 选节点并显示叠加层 | 交互标记位置和简化盒体范围是否适合后续接入 |
| mine_vista / MN_MineVista | 顶部切换场景，缩远观察 | 建筑轮廓和四处灯体是否足够辨认；实际远距离亮度待 T13b 接入后审核 |

用户审核后再按反馈调整。森林主文件与维修站 GLB 未修改。
