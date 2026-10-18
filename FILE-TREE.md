# 文件树

> 最后更新：见下方「变更记录」。`tools/godot/` 与 `tools/tcc/` 是运行时下载的第三方程序，不属于源码。

```
数据抢救工程师_Godot原生版_v0.3/
├── .gitignore                 # 排除引擎/编译器、临时下载文件、密钥类文件、CLAUDE.md
├── FILE-TREE.md               # 本文件：文件树与一句话用途
├── AGENTS.md                  # 给 AI 的项目入口（GPT/Codex 自动读取）
├── PLAN.md                    # 游戏目标、山区工程师背景与矿场救援主线（用户所写，AI 不得改）
├── STORY-BEATS.md             # 剧情圣经与 18 幕节拍表 v2：核心设定、暗线节点、四个声音、矿场 3D 层、结局（作家定稿，用户可改）
├── progress.md                # 进度、关键决定、任务状态表
├── tasks/                     # 给不同 AI 执行的任务文档
│   ├── 00-总览.md             # 产品目标、已确认决定、通用规则、依赖图、里程碑、风险
│   ├── 派工指南.md            # 给用户：GPT 块与 Claude 块分开的任务顺序、开场话、剧情如何进入任务
│   ├── 关卡内容规范.md        # 支架渐隐、60 分钟结构、通关三检、关卡包格式、交付物
│   ├── 关卡表.md              # 18 章 190 关清单（R/B/G/H 阶段，S0 到 S4 支架）
│   ├── T01-关卡包与工作区.md  # 关卡加载器、工作区、GameState、存档
│   ├── T02-编译运行器与验证脚本.md # GDScript 运行器、回归、validate_levels
│   ├── T03-终端界面场景化.md  # 拆分 main.gd 为可放入 SubViewport 的终端
│   ├── T04-3D世界骨架.md      # glb 导入、玩家控制、交互射线
│   ├── T05-老电脑交互.md      # CRT 屏幕 SubViewport、聚焦相机、输入转发
│   ├── T06-室外环境.md        # 地形、森林、天气、昼夜
│   ├── T07-剧情系统.md        # 剧情节拍、传真/电台/地图物件、开场动画
│   ├── T08-学习系统.md        # 分层手册、提示阶梯、复盘笔记、学习工具
│   ├── T09-菜单设置存档音频.md # 菜单、设置、存档槽、音频总线、本地化
│   ├── T10-Steam与打包.md     # 导出、GodotSteam、成就、云存档、许可
│   ├── T11-打磨与测试.md      # 全流程走查、性能、无障碍、学习质量复查
│   ├── T13-矿场场景扩建.md    # [GPT] 矿场远景版与营地版建模，及接入 Godot
│   ├── T12-参考工具与样例库.md # ref_gzip、受控样例生成器、令牌/码长提取器、损坏样例库
│   ├── K-章节内容任务.md      # 章节内容任务通用模板（ch00 到 ch17，一章一个会话）
├── _reference/                # [本地文件，不入库，已在 .gitignore] 各关参考答案；学习者不打开
│   ├── .gdignore              # Godot 不导入
│   └── README.txt             # 目录用途说明
├── art_source/
│   ├── .gdignore              # Blender 源资产暂不自动导入 Godot
│   ├── AGENTS.md              # Blender 编辑规则：主文件唯一、不跑历史脚本
│   ├── 主工程说明.md          # 说明主 .blend 与 GLB 导出流程
│   ├── Data_Rescue_Forest_Station.blend  # 唯一主工程：森林加维修站
│   ├── Data_Rescue_Forest_Station.blend1 # Blender 备份
│   └── mine/                  # T13a 独立矿场资产；用户目视审核通过
│       ├── Data_Rescue_Mine.blend # mine_site 与 mine_vista 两个场景；SOLID 视口
│       ├── build_mine.py      # 本次初建记录；拒绝覆盖已有源文件
│       ├── export_mine.py     # 只从现有源文件导出两个 GLB，不重建
│       ├── validate_mine.py   # Blender 与 GLB 结构验证，生成完整节点清单
│       ├── validate_mine.gd   # Godot 直接无头加载 GLB 与节点检查
│       ├── node_manifest.json # 所有节点、坐标、面数、碰撞与交互标记清单
│       └── README.md          # 使用与导出说明、标记约定、用户目视检查清单
├── assets/
│   ├── mine/
│   │   ├── mine_site.glb      # 入口营地；28,104 三角形；23 碰撞标记、8 交互标记
│   │   └── mine_vista.glb     # 远景轮廓与四处发光体；444 三角形
│   └── mountain_station/
│       ├── mountain_repair_station.glb   # 维修站模型（含老电脑、传真机、电台、机架、地图），T04 未改
│       ├── mountain_repair_station.glb.import # Godot 场景导入配置
│       └── mountain_repair_station_MS_MAT_*_Color.png[.import] # Godot 从 GLB 提取的 18 张纹理及导入配置
├── project.godot              # Godot 工程配置：主场景 main.tscn，1480x940，GL Compatibility
├── main.tscn                  # 原有 2D 原型主场景：根节点 Control，挂 scripts/main.gd
├── scenes/world/
│   ├── world.tscn             # T04 独立世界入口：维修站、玩家、光照和碰撞容器
│   └── player.tscn            # 第一人称玩家、胶囊碰撞、相机和 HUD
├── 启动游戏.bat               # 启动器：引擎在则直接启动；否则调用 install-godot.ps1；--path 用 %PROJ%（无尾部反斜杠）
├── 安装引擎.bat               # 单独运行 install-godot.ps1
├── 安装编译器.bat             # 单独运行 setup-compiler.ps1
├── docs/
│   ├── T04-world.md           # T04 运行方法、接口、验证命令和用户目视检查清单
│   └── 设备手册.md            # 游戏内设备/任务背景手册
├── firmware/
│   ├── player.c               # 玩家要写的 C 固件（顶部有 out/used/capacity 等参数说明注释）；游戏内标签页为绿色可编辑
│   ├── player.h               # 函数签名；游戏内标签页为黄色只读
│   └── trace_harness.c        # 评分夹具（输出 SUMMARY| 等协议行）；游戏内黄色只读，每次 F5 前自动还原官方版
├── scripts/
│   ├── world/
│   │   ├── interactable.gd[.uid] # 可启用的交互基类、提示及信号；UID 由 Godot 生成
│   │   ├── player.gd[.uid]    # 行走、鼠标视角、暂停操作和遮挡射线
│   │   └── world.gd[.uid]     # 组合简化碰撞、五个占位交互点和开启门实例
│   ├── main.gd.uid           # Godot 为既有脚本生成的资源标识
│   ├── data_bus.gd.uid       # Godot 为既有脚本生成的资源标识
│   ├── main.gd                # 全部界面与游戏逻辑：关卡、可折叠侧栏、三文件标签页（绿可编辑/黄只读）、编译、回放、音效
│   ├── data_bus.gd            # 自绘动画数据总线控件，由真实探针帧驱动
│   ├── runner.ps1             # 编译并限时运行玩家 C 代码，写 run_result.txt
│   ├── setup-compiler.ps1     # 下载便携 TinyCC 到 tools/tcc
│   └── install-godot.ps1      # 安装 Godot：续传、进度/速度/ETA、SHA512 校验、暂存解压
├── tests/
│   ├── test_world.gd[.uid]   # T04 无头物理与交互回归测试及 Godot 资源标识
│   ├── README.txt             # 测试说明
│   └── test_c.sh              # C 固件测试脚本
└── tools/
    ├── README.txt             # 说明 tools 下的外部程序来源
    ├── godot/                 # [运行时下载] Godot_v4.7.2 win64 及 console 版
    └── tcc/                   # [运行时下载] 便携 TinyCC
```

## 数据流

```
启动游戏.bat → (缺引擎) install-godot.ps1 → tools/godot/*.exe --path <项目>
main.tscn → main.gd ─(F5)→ runner.ps1 → tcc/gcc 编译 firmware/*.c → run_result.txt
                    └→ 解析 SUMMARY| 等行 → 回放帧 → data_bus.gd 动画
```

## 变更记录

- 2026-10-18：用户明确确认 T13a 目视审核“通过”。更新 `progress.md`、`art_source/mine/README.md` 与本文件的验收状态。无文件新增或删除，模型与代码未修改。T06 与 T13b 等待另行派工。

- 2026-10-18：用户运行 T04 世界场景后反馈“完美！”。更新 `progress.md` 与 `docs/T04-world.md`，记录目视验收通过。无新增或删除文件，无游戏代码变更。

- 2026-10-18：完成 T13a 建模与数据验证，待用户目视审核。新增 `art_source/mine/` 下 7 个文件和 `assets/mine/` 下 2 个 GLB。更新本文件与 `progress.md`。无删除。未修改森林主文件、维修站 GLB 或游戏代码，未执行 T13b。两个矿场 GLB 通过 Blender 结构校验与 Godot 无头加载；源文件保持 SOLID。原 2D 主入口无头启动退出码为 0，但退出时提示 2 个 ObjectDB 实例泄漏，未在本任务内处理。没有截图、渲染检查、帧率测试或视觉自审。交付清单见 `art_source/mine/README.md`。开始及结束均排除 `_reference/`，未读取其内容；该目录条目沿用历史清单。

- 2026-10-18：完成 T04 逻辑实现。新增世界和玩家场景、三个世界脚本、无头测试及运行说明。`project.godot` 加输入动作。主场景保持原 2D 原型。Godot 导入生成 GLB 配置、18 张纹理及其配置、脚本 UID 和已忽略的 `.godot/` 缓存。GLB 与 Blender 文件未改。无源码删除。修正原清单中的 `CLAUDE.md` 条目：开始核对时该文件已不存在，并非本次删除。未访问 `_reference/`，其条目沿用历史清单，未核验。既存 Git 改动均保留。无头启动与物理交互测试通过；画面、手感、性能等待用户检查，清单见 `docs/T04-world.md`。

- 2026-10-14：`STORY-BEATS.md` 升为 v2（作家回答 6 个开放问题，加入核心反转）；派工指南改为 GPT 块与 Claude 块分开，不重叠（块 A GPT、块 B 与 C Claude、块 D GPT 返工）；K 模板加入旧档口吻规则。

- 2026-10-14：新增 `STORY-BEATS.md`（18 幕节拍表，草稿）；T13 的 D1 到 D4 按推荐值；K 模板与 T07 改为引用它。`PLAN.md` 未改。

- 2026-10-14：新增根目录 `AGENTS.md`、`tasks/T13-矿场场景扩建.md`；派工指南标注 [Claude]/[GPT] 分工（T04、T06、T13 由 GPT 做）。

- 2026-10-14：关卡表替换为 18 章 190 关版本（合并他人修订：独立验收、辅助完成、检查点、世界效果）；规范加入每关验收标准；新增 T12；任务文档加入“3D 由用户审核，agent 不自审”规则。

- 2026-10-14：关卡改为 18 章 148 关。新增 `tasks/关卡表.md`、`tasks/派工指南.md`、`tasks/K-章节内容任务.md`；重写 `tasks/关卡内容规范.md`；删除 `tasks/C1` 到 `C6`（由 K 模板取代）；删除任务文档中的许可调查要求；关卡 id 改为 `chNN_MM_slug`。

- 2026-10-14：新增 `tasks/`（总览、关卡内容规范、T01 到 T11、C1 到 C6）、`progress.md`、`_reference/`；`.gitignore` 加 `_reference/`。校正树：移除已删除的 `README.md` 与不存在的 `art_source/botaniq_forest/`，补录 `art_source` 主工程文件与 `assets/mountain_station/` glb。未改任何游戏代码。

- 2026-10-14：补录 PLAN.md 与现有 Botaniq 森林源文件；新增住宅空地与灌木调整脚本，待用户保存当前 Blender 修改后执行。
- 2026-10-14：读取用户 17:48 保存版，完成住宅灌木版和山地草甸版，新增对应清单、日志与说明；用户允许基础地形建模。保留用户地面缩放（实际边长约 166 米）及树木数量、大小、随机种子、视口显示设置；不修改游戏代码。
- 2026-10-14：结束时文件清单中已无初版 Botaniq_Forest_400m.blend，同步移除树中的条目；本次操作未删除该文件。
- 2026-10-13：侧栏可折叠(Ctrl+B)；数据流改横排；编辑区三标签页(player.c 绿/可编辑，player.h 与 trace_harness.c 黄/只读)；F5 前还原只读文件；player.c 加参数说明。
- 2026-10-13：修复 F5（runner.ps1/setup-compiler.ps1 加 BOM）；编辑器改 VS Code Dark+ C 配色；新增 .gitignore；推送 GitHub。
- 2026-10-13：修复启动器（续传下载、`--path` 尾部反斜杠 bug）；新增 FILE-TREE.md、CLAUDE.md。
