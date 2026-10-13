extends Control

# Native Godot UI. Test output is produced by running the user's REAL C code.
# The animation plays separate real prefix-probe executions (not debugger traces).
const BG = Color("#091119")
const PANEL = Color("#111f2a")
const PANEL_ALT = Color("#0c1821")
const BORDER = Color("#284653")
const TEXT = Color("#d8eced")
const MUTED = Color("#77949f")
const GREEN = Color("#58efb3")
const AMBER = Color("#ffbd62")
const RED = Color("#ff7979")
const CYAN = Color("#79d8ff")
const CASES = [
    {"id": "A01", "name": "温室传感器", "prefix": "HELLO", "distance": 5, "length": 3, "expected": "HELLOHEL", "story": "温室网络发送了一条重复报文。先验证复制设备是否能工作。"},
    {"id": "B02", "name": "医疗电台", "prefix": "ABC", "distance": 3, "length": 6, "expected": "ABCABCABC", "story": "医疗电台信号出现缺口。复制必须读取刚刚写入的字节。"},
    {"id": "C03", "name": "矿井警报", "prefix": "X", "distance": 1, "length": 7, "expected": "XXXXXXXX", "story": "极短数据源发出长回声。任何复制中断都将破坏警报。"},
    {"id": "D04", "name": "档案中心", "prefix": "NODE-", "distance": 5, "length": 10, "expected": "NODE-NODE-NODE-", "story": "档案中心需要恢复较长数据。检验程序能否连续复制多轮。"}
]

var selected_case: int = 1
var work_dir: String
var editor: CodeEdit
var editor_size: int = 19
var code_caption: Label
var mission_buttons: Array[Button] = []
var mission_objective: Label
var mission_meta: Label
var mission_story: Label
var output_status: Label
var input_status: Label
var run_status: Label
var global_status: Label
var compile_button: Button
var replay_button: Button
var expand_button: Button
var monitor_panel: Control
var event_log: RichTextLabel
var output_cells: HFlowContainer
var input_cells: HFlowContainer
var data_bus: Control
var step_caption: Label
var left_caption: Label
var pass_flags: Array = [false, false, false, false]
var guard_flags: Array = [false, false]
var all_traces: Dictionary = {}
var all_results: Dictionary = {}
var playback_frames: Array = []
var frame_cursor: int = -1
var animation_clock: float = 0.0
var playing: bool = false
var worker: Thread
var compiling: bool = false
var maximized: bool = false
var sound_player: AudioStreamPlayer
var sound_on: bool = true
var footer_note: Label

func _ready() -> void:
    get_window().min_size = Vector2i(1180, 720)
    RenderingServer.set_default_clear_color(BG)
    work_dir = OS.get_user_data_dir()
    DirAccess.make_dir_recursive_absolute(work_dir)
    _ensure_firmware()
    _build_interface()
    _init_sound()
    _load_firmware()
    _select_case(1)
    _log("系统已上线。请选择事件，查看目标输出，再按 F5 编译真实 C 固件。", GREEN)
    _log("TRACE：输出帧来自多次真实 C 函数调用，每个长度单独测试。", CYAN)

func _ensure_firmware() -> void:
    for filename in ["player.c", "player.h", "trace_harness.c"]:
        var target: String = work_dir.path_join(filename)
        if not FileAccess.file_exists(target):
            var source: String = "res://firmware/" + filename
            var f: FileAccess = FileAccess.open(source, FileAccess.READ)
            if f != null:
                var dst: FileAccess = FileAccess.open(target, FileAccess.WRITE)
                if dst != null:
                    dst.store_buffer(f.get_buffer(f.get_length()))
                    dst.close()
                f.close()

func _style(fill: Color, edge: Color = BORDER, radius: int = 8, border: int = 1) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = fill
    sb.border_color = edge
    sb.border_width_left = border
    sb.border_width_right = border
    sb.border_width_top = border
    sb.border_width_bottom = border
    sb.corner_radius_top_left = radius
    sb.corner_radius_top_right = radius
    sb.corner_radius_bottom_left = radius
    sb.corner_radius_bottom_right = radius
    sb.content_margin_left = 12.0
    sb.content_margin_right = 12.0
    sb.content_margin_top = 10.0
    sb.content_margin_bottom = 10.0
    return sb

func _label(s: String, font_size: int = 15, col: Color = TEXT, wrap: bool = false) -> Label:
    var l := Label.new()
    l.text = s
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", col)
    if wrap:
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _button(s: String, accent: Color = BORDER) -> Button:
    var b := Button.new()
    b.text = s
    b.custom_minimum_size = Vector2(0, 38)
    b.add_theme_font_size_override("font_size", 14)
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    b.add_theme_stylebox_override("normal", _style(PANEL_ALT, accent, 6))
    b.add_theme_stylebox_override("hover", _style(Color("#193442"), accent, 6))
    b.add_theme_stylebox_override("pressed", _style(Color("#18414a"), GREEN, 6))
    b.add_theme_stylebox_override("disabled", _style(PANEL_ALT, BORDER, 6))
    return b

func _section(title_text: String, description: String = "") -> VBoxContainer:
    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 6)
    outer.add_child(_label(title_text, 15, CYAN))
    if description != "":
        outer.add_child(_label(description, 12, MUTED, true))
    return outer

func _panel() -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", _style(PANEL))
    return p

func _build_interface() -> void:
    var pad := MarginContainer.new()
    pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        pad.add_theme_constant_override("margin_" + side, 15)
    add_child(pad)
    var app := VBoxContainer.new()
    app.add_theme_constant_override("separation", 12)
    pad.add_child(app)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 16)
    app.add_child(top)
    var mark := _label("◈  DATA RESCUE", 28, GREEN)
    top.add_child(mark)
    var header_text := VBoxContainer.new()
    header_text.add_child(_label("数据抢救工程师   /   维修站 07", 18, TEXT))
    header_text.add_child(_label("NATIVE CONTROL SYSTEM  ·  GZIP / DEFLATE LAB  ·  UNIT 01", 12, MUTED))
    top.add_child(header_text)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(spacer)
    global_status = _label("●  待命  /  本机离线", 14, AMBER)
    top.add_child(global_status)
    var audio_toggle := _button("♫  声音：开")
    audio_toggle.pressed.connect(func() -> void:
        sound_on = not sound_on
        audio_toggle.text = "♫  声音：开" if sound_on else "♫  声音：关"
        _beep("click")
    )
    top.add_child(audio_toggle)

    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation", 12)
    app.add_child(columns)

    var left_p := _panel()
    left_p.custom_minimum_size.x = 318
    columns.add_child(left_p)
    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 14)
    left_p.add_child(left)
    left.add_child(_label("01 / 待处理事件", 16, GREEN))
    left.add_child(_label("每个事件都写明输入、复制指令与目标输出。", 12, MUTED, true))
    for i in range(CASES.size()):
        var idx := i
        var c: Dictionary = CASES[i]
        var b := _button(str(c.id) + "   " + str(c.name))
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(func() -> void: _select_case(idx))
        mission_buttons.append(b)
        left.add_child(b)
    left.add_child(HSeparator.new())
    left.add_child(_label("任务委托 / MISSION BRIEF", 13, AMBER))
    mission_story = _label("", 15, TEXT, true)
    left.add_child(mission_story)
    mission_meta = _label("", 15, MUTED, true)
    left.add_child(mission_meta)
    mission_objective = _label("", 17, GREEN, true)
    left.add_child(mission_objective)
    var separation := Control.new()
    separation.size_flags_vertical = Control.SIZE_EXPAND_FILL
    left.add_child(separation)
    left.add_child(HSeparator.new())
    left.add_child(_label("基地运行情况", 14, CYAN))
    left_caption = _label("解锁：0 / 4 条链路", 14, TEXT)
    left.add_child(left_caption)
    left.add_child(_label("后续：扩建电路 / 电力分配 / 数据吞吐", 12, MUTED, true))
    var manual := _button("打开设备手册（原始规范）", CYAN)
    manual.pressed.connect(func() -> void:
        OS.shell_open("https://www.rfc-editor.org/rfc/rfc1951")
    )
    left.add_child(manual)

    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 11)
    columns.add_child(right)

    var ebox := _panel()
    ebox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(ebox)
    var editor_area := VBoxContainer.new()
    editor_area.add_theme_constant_override("separation", 7)
    ebox.add_child(editor_area)
    var edit_title := HBoxContainer.new()
    editor_area.add_child(edit_title)
    edit_title.add_child(_label("02 / 固件工作台   player.c", 16, GREEN))
    var title_space := Control.new()
    title_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    edit_title.add_child(title_space)
    var reduce := _button("A−")
    reduce.pressed.connect(func() -> void: _resize_editor(-1))
    edit_title.add_child(reduce)
    var grow := _button("A+")
    grow.pressed.connect(func() -> void: _resize_editor(1))
    edit_title.add_child(grow)
    expand_button = _button("⛶  放大编辑区", CYAN)
    expand_button.pressed.connect(_toggle_expand)
    edit_title.add_child(expand_button)

    editor = CodeEdit.new()
    editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
    editor.custom_minimum_size.y = 250
    editor.gutters_draw_line_numbers = true
    editor.indent_use_spaces = true
    editor.indent_size = 4
    editor.add_theme_font_size_override("font_size", editor_size)
    editor.add_theme_color_override("font_color", Color("#dce9ee"))
    editor.add_theme_color_override("font_readonly_color", MUTED)
    editor.add_theme_color_override("caret_color", GREEN)
    editor.add_theme_stylebox_override("normal", _style(Color("#08141a"), Color("#355a66"), 5))
    # 配色参照 VS Code Dark+ 对 C 的标准着色
    var highlight := CodeHighlighter.new()
    highlight.number_color = Color("#b5cea8")
    highlight.symbol_color = Color("#d4d4d4")
    highlight.function_color = Color("#dcdcaa")
    highlight.member_variable_color = Color("#dce9ee")
    for kw in ["void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "const", "static", "volatile", "extern", "register", "inline", "struct", "union", "enum", "typedef", "sizeof"]:
        highlight.add_keyword_color(kw, Color("#569cd6"))
    for kw in ["if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return", "goto"]:
        highlight.add_keyword_color(kw, Color("#c586c0"))
    for kw in ["size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "int8_t", "int16_t", "int32_t", "int64_t", "bool", "ptrdiff_t", "FILE"]:
        highlight.add_keyword_color(kw, Color("#4ec9b0"))
    for kw in ["NULL", "true", "false"]:
        highlight.add_keyword_color(kw, Color("#569cd6"))
    highlight.add_color_region("/*", "*/", Color("#6a9955"))
    highlight.add_color_region("//", "", Color("#6a9955"), true)
    highlight.add_color_region("\"", "\"", Color("#ce9178"))
    highlight.add_color_region("'", "'", Color("#ce9178"))
    highlight.add_color_region("#", "", Color("#c586c0"), true)
    editor.syntax_highlighter = highlight
    editor_area.add_child(editor)
    var edit_footer := HBoxContainer.new()
    editor_area.add_child(edit_footer)
    code_caption = _label("编辑器：19 pt  |  F5 编译  |  Ctrl+S 保存  |  F6 回放", 12, MUTED)
    code_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    edit_footer.add_child(code_caption)
    var save := _button("保存 C 文件")
    save.pressed.connect(func() -> void: _save_firmware(true))
    edit_footer.add_child(save)
    var reset := _button("恢复旧固件", AMBER)
    reset.pressed.connect(_restore_firmware)
    edit_footer.add_child(reset)
    compile_button = _button("▶ F5  编译并测试", GREEN)
    compile_button.pressed.connect(_compile)
    edit_footer.add_child(compile_button)

    monitor_panel = _panel()
    monitor_panel.custom_minimum_size.y = 250
    right.add_child(monitor_panel)
    var monitor := VBoxContainer.new()
    monitor.add_theme_constant_override("separation", 5)
    monitor_panel.add_child(monitor)
    var monitor_header := HBoxContainer.new()
    monitor.add_child(monitor_header)
    monitor_header.add_child(_label("03 / LIVE DATA STREAM   ·   真实 C 数据探针", 16, GREEN))
    var monitor_gap := Control.new()
    monitor_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    monitor_header.add_child(monitor_gap)
    replay_button = _button("↻ F6  重放")
    replay_button.pressed.connect(_replay)
    monitor_header.add_child(replay_button)
    run_status = _label("尚未编译", 13, AMBER)
    monitor_header.add_child(run_status)
    var data_row := HBoxContainer.new()
    data_row.add_theme_constant_override("separation", 10)
    data_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    monitor.add_child(data_row)
    var input_side := VBoxContainer.new()
    input_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input_side.add_theme_constant_override("separation", 4)
    data_row.add_child(input_side)
    input_side.add_child(_label("INPUT / 起始输出字节 + 复制指令", 12, CYAN))
    input_status = _label("", 13, TEXT)
    input_side.add_child(input_status)
    var in_scroll := ScrollContainer.new()
    in_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    input_side.add_child(in_scroll)
    input_cells = HFlowContainer.new()
    input_cells.add_theme_constant_override("h_separation", 3)
    input_cells.add_theme_constant_override("v_separation", 3)
    in_scroll.add_child(input_cells)
    data_bus = Control.new()
    data_bus.set_script(load("res://scripts/data_bus.gd"))
    data_bus.custom_minimum_size = Vector2(75, 70)
    data_row.add_child(data_bus)
    var output_side := VBoxContainer.new()
    output_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    output_side.add_theme_constant_override("separation", 4)
    data_row.add_child(output_side)
    output_side.add_child(_label("OUTPUT / 真实缓冲区", 12, AMBER))
    output_status = _label("尚未执行", 13, TEXT)
    output_side.add_child(output_status)
    var out_scroll := ScrollContainer.new()
    out_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    output_side.add_child(out_scroll)
    output_cells = HFlowContainer.new()
    output_cells.add_theme_constant_override("h_separation", 3)
    output_cells.add_theme_constant_override("v_separation", 3)
    out_scroll.add_child(output_cells)
    step_caption = _label("等待 C 代码运行。", 13, MUTED, true)
    monitor.add_child(step_caption)

    var log_box := _panel()
    log_box.custom_minimum_size.y = 86
    right.add_child(log_box)
    var log_vertical := VBoxContainer.new()
    log_box.add_child(log_vertical)
    log_vertical.add_child(_label("04 / ENGINEER LOG", 12, CYAN))
    event_log = RichTextLabel.new()
    event_log.bbcode_enabled = true
    event_log.scroll_following = true
    event_log.fit_content = false
    event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    event_log.add_theme_font_size_override("normal_font_size", 13)
    log_vertical.add_child(event_log)
    footer_note = _label("提示：输出帧由 C 程序多次实测取得。不是伪造的数据流。  |  编辑器内的代码只在你的电脑上编译。", 11, MUTED)
    app.add_child(footer_note)

func _load_firmware() -> void:
    var f := FileAccess.open(work_dir.path_join("player.c"), FileAccess.READ)
    if f != null:
        editor.text = f.get_as_text()
        f.close()

func _save_firmware(display_message: bool) -> bool:
    var file := FileAccess.open(work_dir.path_join("player.c"), FileAccess.WRITE)
    if file == null:
        _log("不能保存 player.c。请检查文件权限。", RED)
        return false
    file.store_string(editor.text)
    file.close()
    if display_message:
        _log("已保存真实 C 源码 → " + work_dir.path_join("player.c"), GREEN)
        _beep("click")
    return true

func _restore_firmware() -> void:
    var f := FileAccess.open("res://firmware/player.c", FileAccess.READ)
    if f != null:
        editor.text = f.get_as_text()
        f.close()
        _save_firmware(true)
        _log("已恢复带有故障的旧固件。再按 F5 观察失败数据。", AMBER)

func _resize_editor(delta: int) -> void:
    editor_size = clampi(editor_size + delta, 13, 30)
    editor.add_theme_font_size_override("font_size", editor_size)
    code_caption.text = "编辑器：%d pt  |  F5 编译  |  Ctrl+S 保存  |  F6 回放" % editor_size

func _toggle_expand() -> void:
    maximized = not maximized
    monitor_panel.visible = not maximized
    expand_button.text = "⛶  恢复监测区" if maximized else "⛶  放大编辑区"
    _beep("click")

func _select_case(index: int) -> void:
    selected_case = index
    var c: Dictionary = CASES[selected_case]
    mission_story.text = str(c.story)
    mission_meta.text = "起始：%s\n距离 distance：%s\n长度 length：%s" % [c.prefix, c.distance, c.length]
    mission_objective.text = "本关目标 OUTPUT：\n%s\n（共 %d 字节）" % [c.expected, str(c.expected).length()]
    for i in range(mission_buttons.size()):
        var active: bool = i == selected_case
        var flag: String = "  ✓" if pass_flags[i] else ""
        mission_buttons[i].text = str(CASES[i].id) + "  " + str(CASES[i].name) + flag
        mission_buttons[i].add_theme_color_override("font_color", GREEN if active else TEXT)
        mission_buttons[i].add_theme_stylebox_override("normal", _style(Color("#1a3a3b") if active else PANEL_ALT, GREEN if active else BORDER, 6))
    _rebuild_input(-1)
    _begin_playback()
    _beep("click")

func _rebuild_input(active_index: int) -> void:
    var c: Dictionary = CASES[selected_case]
    input_status.text = "SOURCE: %s  |  BACK: %d  |  COPY: %d" % [c.prefix, c.distance, c.length]
    _clear_children(input_cells)
    for i in range(str(c.prefix).length()):
        var on: bool = active_index == i
        _make_byte(input_cells, i, str(c.prefix).substr(i, 1), Color("#66d8ff") if on else CYAN, on)

func _clear_children(where: Node) -> void:
    for child in where.get_children():
        where.remove_child(child)
        child.queue_free()

func _make_byte(parent: Control, index: int, content: String, color: Color, emphasized: bool) -> void:
    var p := PanelContainer.new()
    p.custom_minimum_size = Vector2(47, 54)
    p.add_theme_stylebox_override("panel", _style(Color("#17413e") if emphasized else PANEL_ALT, color if emphasized else BORDER, 5))
    parent.add_child(p)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 1)
    p.add_child(stack)
    var pos := _label("%02d" % index, 10, MUTED)
    pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(pos)
    var symbol := _label(content, 18, color)
    symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(symbol)

func _begin_playback() -> void:
    playback_frames = []
    if all_traces.has(selected_case):
        playback_frames = all_traces[selected_case].duplicate(true)
    frame_cursor = -1
    animation_clock = 0.0
    playing = not playback_frames.is_empty()
    data_bus.set("activity", 0.0)
    data_bus.set("accepted", false)
    _clear_children(output_cells)
    var c: Dictionary = CASES[selected_case]
    if playback_frames.is_empty():
        output_status.text = "目标：%s  |  等待真实程序" % c.expected
        step_caption.text = "按 F5 运行 C 代码。INPUT 和 OUTPUT 将显示实际字节。"
        run_status.text = "尚未运行"
    else:
        var result: Dictionary = all_results.get(selected_case, {})
        run_status.text = "校验通过" if result.get("pass", false) else "存在故障"
        run_status.add_theme_color_override("font_color", GREEN if result.get("pass", false) else RED)
        output_status.text = "程序运行完成，开始逐字节回放…"
        step_caption.text = "每个 STEP 由真实 C 函数以指定长度独立执行。"

func _compile() -> void:
    if compiling:
        return
    if not _save_firmware(false):
        return
    if FileAccess.file_exists(work_dir.path_join("run_result.txt")):
        DirAccess.remove_absolute(work_dir.path_join("run_result.txt"))
    compiling = true
    compile_button.disabled = true
    global_status.text = "●  固件编译中…"
    global_status.add_theme_color_override("font_color", AMBER)
    _log("固件已提交。正在调用本机编译器，随后运行测试。", CYAN)
    _beep("start")
    worker = Thread.new()
    var err: int = worker.start(_run_compile_worker)
    if err != OK:
        compiling = false
        compile_button.disabled = false
        _log("不能启动编译线程，错误码：%s" % err, RED)

func _run_compile_worker() -> void:
    var root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
    var runner: String = root.path_join("scripts/runner.ps1")
    var output: Array = []
    # Work is off the UI thread. Main UI never changes from this worker.
    OS.execute("powershell.exe", PackedStringArray([
        "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
        "-File", runner, "-WorkDir", work_dir, "-GameRoot", root
    ]), output, true, false)

func _process(delta: float) -> void:
    if compiling and worker != null and not worker.is_alive():
        worker.wait_to_finish()
        worker = null
        compiling = false
        compile_button.disabled = false
        _read_results()
    if playing and not maximized:
        animation_clock += delta
        if animation_clock >= 0.20:
            animation_clock = 0.0
            frame_cursor += 1
            if frame_cursor < playback_frames.size():
                _show_frame(playback_frames[frame_cursor])
            else:
                playing = false
                var result: Dictionary = all_results.get(selected_case, {})
                var good: bool = result.get("pass", false)
                data_bus.set("activity", 0.15)
                data_bus.set("accepted", good)
                step_caption.text = "回放结束。完整长度的真实测试结果：" + ("恢复成功。" if good else "与目标不符，检查红色字节。")
                _beep("success" if good else "error")

func _read_results() -> void:
    var f := FileAccess.open(work_dir.path_join("run_result.txt"), FileAccess.READ)
    if f == null:
        _log("后台没有生成结果文件。检查 PowerShell 是否可以运行。", RED)
        global_status.text = "●  编译程序未启动"
        return
    var data: String = f.get_as_text()
    f.close()
    all_traces.clear()
    all_results.clear()
    pass_flags = [false, false, false, false]
    guard_flags = [false, false]
    var fatal: bool = false
    var processed: bool = false
    for raw in data.split("\n"):
        var line := raw.strip_edges().trim_prefix("\ufeff")
        var v := line.split("|", true)
        if v.is_empty():
            continue
        match v[0]:
            "COMPILER":
                if v.size() > 1: _log("使用 C 编译器：" + v[1], MUTED)
            "COMPILE":
                _log("C 源码编译成功。正在读取真实输出缓冲区。", GREEN)
            "ERROR":
                fatal = true
                var details: String = line.replace("ERROR|", "").replace("|", " / ")
                _log("执行失败：" + details, RED)
            "STEP":
                if v.size() >= 7:
                    var index: int = int(v[1])
                    if not all_traces.has(index): all_traces[index] = []
                    all_traces[index].append({"k": int(v[2]), "rc": int(v[3]), "used": int(v[4]), "guard": int(v[5]) == 1, "hex": v[6]})
            "CASE":
                if v.size() >= 6:
                    var index: int = int(v[1])
                    var correct: bool = int(v[2]) == 1
                    pass_flags[index] = correct
                    all_results[index] = {"pass": correct, "rc": int(v[3]), "used": int(v[4]), "hex": v[5]}
                    processed = true
                    _log("事件 %s：%s" % [CASES[index].id, "校验通过" if correct else "输出与目标不符"], GREEN if correct else AMBER)
            "GUARD":
                if v.size() >= 3:
                    guard_flags[int(v[1])] = int(v[2]) == 1
            "NOTICE":
                if v.size() > 1: _log(v[1], AMBER)
    if fatal or not processed:
        global_status.text = "●  编译/执行失败"
        global_status.add_theme_color_override("font_color", RED)
    else:
        var count: int = 0
        for ok in pass_flags:
            if ok: count += 1
        left_caption.text = "已恢复 %d / 4 条链路  |  安全检查 %d / 2" % [count, int(guard_flags[0]) + int(guard_flags[1])]
        global_status.text = "●  %d / 4 条链路恢复" % count
        global_status.add_theme_color_override("font_color", GREEN if count == 4 and guard_flags[0] and guard_flags[1] else AMBER)
        if count == 4 and guard_flags[0] and guard_flags[1]:
            _log("任务达成：所有数据链路已恢复，安全检查通过。", GREEN)
    _select_case(selected_case)

func _replay() -> void:
    if playback_frames.is_empty() and all_traces.is_empty():
        _log("先按 F5 编译 C 代码，才能回放真实运行结果。", AMBER)
    else:
        _begin_playback()
        _log("重放：事件 " + str(CASES[selected_case].id), CYAN)

func _show_frame(frame: Dictionary) -> void:
    var c: Dictionary = CASES[selected_case]
    var k: int = int(frame.k)
    var used: int = int(frame.used)
    var hex_data: String = str(frame.hex)
    var bytes: PackedByteArray = hex_data.hex_decode()
    var expected: String = str(c.expected)
    var source_index: int = str(c.prefix).length() + k - 1 - int(c.distance)
    var dest_index: int = str(c.prefix).length() + k - 1
    data_bus.set("activity", 1.0)
    _rebuild_input(source_index)
    _clear_children(output_cells)
    var incorrect: int = 0
    for i in range(mini(bytes.size(), 64)):
        var byte: int = bytes[i]
        var glyph: String = String.chr(byte) if byte >= 32 and byte <= 126 else "·"
        var right: bool = i < expected.length() and byte == expected.unicode_at(i)
        var colored: Color = GREEN if right else RED
        if i < str(c.prefix).length(): colored = CYAN
        if i == dest_index: colored = AMBER if right else RED
        if not right: incorrect += 1
        _make_byte(output_cells, i, glyph, colored, i == dest_index or i == source_index)
    var read_text: String = "OUTPUT[%d]" % source_index if source_index >= str(c.prefix).length() else "INPUT[%d]" % source_index
    output_status.text = "已写 %d 字节  |  本步长度 %d / %d  |  %s" % [used, k, c.length, "OK" if incorrect == 0 else "有异常字节"]
    step_caption.text = "读取 %s → 写入 OUTPUT[%d]  ·  C 返回 %d  ·  本步实际字节：%s" % [read_text, dest_index, frame.rc, hex_data]
    if k > 0 and k % 2 == 0: _beep("tick")

func _log(s: String, color: Color = TEXT) -> void:
    if event_log == null:
        return
    event_log.append_text("[color=#%s]›  %s[/color]\n" % [color.to_html(false), s.replace("[", "(").replace("]", ")")])

func _init_sound() -> void:
    sound_player = AudioStreamPlayer.new()
    add_child(sound_player)

func _make_tone(kind: String) -> AudioStreamWAV:
    var rate: int = 22050
    var seconds: float = 0.09 if kind == "tick" else 0.19
    if kind == "success": seconds = 0.33
    if kind == "error": seconds = 0.30
    var sample_count: int = int(float(rate) * seconds)
    var samples := PackedByteArray()
    samples.resize(sample_count * 2)
    for n in range(sample_count):
        var time: float = float(n) / float(rate)
        var envelope: float = pow(1.0 - float(n) / float(sample_count), 2.0)
        var freq: float = 470.0
        if kind == "success": freq = 630.0 + 310.0 * minf(time / seconds, 1.0)
        elif kind == "error": freq = 290.0 - 100.0 * minf(time / seconds, 1.0)
        elif kind == "click": freq = 730.0
        elif kind == "start": freq = 310.0 + 170.0 * time / seconds
        var sample: int = int(sin(TAU * freq * time) * 9000.0 * envelope)
        if sample < 0: sample += 65536
        samples[n * 2] = sample & 255
        samples[n * 2 + 1] = (sample >> 8) & 255
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.stereo = false
    stream.data = samples
    return stream

func _beep(kind: String) -> void:
    if not sound_on or sound_player == null:
        return
    sound_player.stream = _make_tone(kind)
    sound_player.play()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F5:
            _compile()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_F6:
            _replay()
            get_viewport().set_input_as_handled()
        elif event.ctrl_pressed and event.keycode == KEY_S:
            _save_firmware(true)
            get_viewport().set_input_as_handled()
        elif event.ctrl_pressed and event.keycode == KEY_EQUAL:
            _resize_editor(1)
            get_viewport().set_input_as_handled()
        elif event.ctrl_pressed and event.keycode == KEY_MINUS:
            _resize_editor(-1)
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if worker != null:
        worker.wait_to_finish()
