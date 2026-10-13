# 数据抢救工程师｜DATA RESCUE · Windows 原生版 Demo v0.3

**这是 Godot 4 的 Windows 原生窗口项目，不是网页游戏。**

## 运行（Windows 10/11）

1. **解压整个 ZIP。** 不要在压缩包内部双击程序。
2. 双击 **`启动游戏.bat`**。如果没有 Godot，启动器会下载**官方 Godot 4.7.2 Windows 便携引擎**（一次即可，不需管理员权限）。之后会打开 Godot 原生游戏窗口。
3. 选择事件，查看左栏 **本关目标 OUTPUT**。
4. 点击 **F5 编译并测试**。如果显示 `NO_COMPILER`，双击 **`安装编译器.bat`**，下载官方便携 TinyCC；也可以用本机已有的 GCC/Clang/TCC。
5. 修改大号 C 编辑区中的 `copy_match()`。重新按 **F5**，观察右下方 **INPUT 与 OUTPUT** 的真实数据变化。
6. 测试全部 4 个关卡和 2 项安全检查。

游戏会在 Windows 电脑的 Godot 用户数据目录中保存真实 `player.c`： `%APPDATA%\Godot\app_userdata\...`（实际目录以游戏日志为准）。可以继续用 VS Code 修改。

## 本次按反馈实施的修改

- **取消右上角时间**：顶部只显示设备状态，不含时钟。
- **编辑器更大**：默认 19pt 字号，支持 A+、A−；可放大为占据右侧整个工作区，Ctrl+S 保存。
- **非网页**：由 Godot 原生渲染/UI/音频驱动，不需要浏览器、HTTP 服务器或后端 Web 服务。
- **明确每关完整目标输出**：左侧任务栏展示前缀、distance、length、完整期待字符串与字节数。
- **真正联动 INPUT 与 OUTPUT**：系统调用真实 C 编译器、执行 `player.c` + `trace_harness.c`；用实际字节构建 `STEP` 帧。INPUT 来源字节高亮；OUTPUT 写入字节根据真实结果显示，对不上目标时显示红色。
- **可重放**：F6 回放最近编译得到的数据。音效由 Godot 通过代码生成，并不是外部音效文件。

## 四个任务

| 事件 | 起始字节 | distance | length | 目标 OUTPUT |
| --- | --- | ---: | ---: | --- |
| A01 温室传感器 | `HELLO` | 5 | 3 | `HELLOHEL` |
| B02 医疗电台 | `ABC` | 3 | 6 | `ABCABCABC` |
| C03 矿井警报 | `X` | 1 | 7 | `XXXXXXXX` |
| D04 档案中心 | `NODE-` | 5 | 10 | `NODE-NODE-NODE-` |

此外还有 2 个安全检查：零距离必须拒绝、缓冲区空间不足必须拒绝。

## 数据真实性说明

每一帧的 `STEP k` 是：**把原始前缀恢复到输出缓冲区，然后运行一次用户写的真实 C 函数，令 length=k**。游戏逐一执行 k=1…N，给出真实运行结果，而不是自行预测程序结果。

因此，该动画反映的是**一组真实的前缀长度实验**，并不是对单次函数执行的逐条 CPU 指令跟踪。`CASE` 是以完整 length 执行一次所产生的实际最终结果。未来可以用 C 指针插桩实现真正的逐次内存写入追踪。

## 网页或原生：为什么选择 Godot？

浏览器并不天然限制 2D/3D 画质或音效质量（WebGL/WebGPU、Web Audio 很强）。上一版的主要缺陷是功能没有接通。但本游戏还需要**本地编辑真实 C 文件、启动编译器、调试与未来电路建模**。Godot 能更直接地管理场景、输入、界面、原生声音和桌面文件操作，避免维护浏览器与 PowerShell Web 服务两套体系。故采用 Godot 原生项目。

## 安全边界

**编译和运行玩家 C 代码，不是在操作系统隔离沙箱内。** 仅运行你自己编写/信任的 C 代码。编译时间限制 9 秒，执行 3.5 秒，但超时限制不等于安全隔离。Windows PowerShell 会在用户目录运行程序。不要复制陌生人的代码执行。游戏不上传代码。

## 已完成和未完成

- 已生成：Godot 场景/原生工业 UI/C 编辑器/音效和动画代码/真实 C 测试工具/Windows 启动器/官方依赖安装脚本/手册。
- **已在 Linux 用 GCC 真实测试 C 旧固件与修复固件**；请看 `tests/README.txt`。
- 当前制作环境**没有 Godot 运行时和 Windows 系统**，不能声称 Godot 窗口实机测试通过。Windows 相关启动及接口尚需在 Windows 11 上试运行确认。
- 未实现：完整 gzip/DEFLATE 解压器、电路升级系统、资源管理、独立导出的最终游戏 `DataRescue.exe`、商业级 AI 美术和配音。这是第一关的原生工程版本。

Godot 官网：https://godotengine.org/download/windows/  · DEFLATE 规范：https://www.rfc-editor.org/rfc/rfc1951
