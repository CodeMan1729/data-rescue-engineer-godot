# 文件树

> 最后更新：见下方「变更记录」。`tools/godot/` 与 `tools/tcc/` 是运行时下载的第三方程序，不属于源码。

```
数据抢救工程师_Godot原生版_v0.3/
├── CLAUDE.md                  # 给 AI 的项目规则（含「改动前后必看文件树」）
├── FILE-TREE.md               # 本文件：文件树与一句话用途
├── README.md                  # 玩家向说明：运行方式、玩法、反馈修改记录
├── project.godot              # Godot 工程配置：主场景 main.tscn，1480x940，GL Compatibility
├── main.tscn                  # 唯一场景：根节点 Control，挂 scripts/main.gd
├── 启动游戏.bat               # 启动器：引擎在则直接启动；否则调用 install-godot.ps1；--path 用 %PROJ%（无尾部反斜杠）
├── 安装引擎.bat               # 单独运行 install-godot.ps1
├── 安装编译器.bat             # 单独运行 setup-compiler.ps1
├── docs/
│   └── 设备手册.md            # 游戏内设备/任务背景手册
├── firmware/
│   ├── player.c               # 玩家要修改的 C 固件（copy_match 等）
│   ├── player.h               # player.c 的头文件
│   └── trace_harness.c        # 测试夹具：运行固件并输出 SUMMARY| 等协议行
├── scripts/
│   ├── main.gd                # 全部界面与游戏逻辑（约 660 行）：关卡、编辑器、编译、回放、音效
│   ├── data_bus.gd            # 自绘动画数据总线控件，由真实探针帧驱动
│   ├── runner.ps1             # 编译并限时运行玩家 C 代码，写 run_result.txt
│   ├── setup-compiler.ps1     # 下载便携 TinyCC 到 tools/tcc
│   └── install-godot.ps1      # 安装 Godot：续传、进度/速度/ETA、SHA512 校验、暂存解压
├── tests/
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

- 2026-10-13：修复启动器（续传下载、`--path` 尾部反斜杠 bug）；新增 FILE-TREE.md、CLAUDE.md。
