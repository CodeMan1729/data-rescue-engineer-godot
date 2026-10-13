extends Control
# Native, procedurally drawn moving data bus. Animated state is driven by real C probe frames.
var activity: float = 0.0
var position_on_bus: float = 0.0
var accepted: bool = false
var phase: float = 0.0

func _process(delta: float) -> void:
    phase += delta * (1.0 + activity * 5.0)
    position_on_bus = fposmod(phase * 0.25, 1.0)
    queue_redraw()

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w < 40.0:
        return
    var base: Color = Color("#284350")
    var lit: Color = Color("#55f2b4") if accepted else Color("#ffb45b")
    for j in range(3):
        var y: float = h * (0.30 + j * 0.23)
        draw_line(Vector2(12, y), Vector2(w - 12, y), base, 2.0)
        for n in range(8):
            var fraction: float = fposmod(n / 8.0 + phase * (0.10 + activity * 0.19) + j * 0.12, 1.0)
            var xx: float = 12.0 + (w - 24.0) * fraction
            draw_line(Vector2(xx - 12.0, y), Vector2(xx + 5.0, y), lit.darkened(0.5 - activity * 0.3), 3.0)
    draw_circle(Vector2(12, h * 0.50), 4.0, lit)
    draw_circle(Vector2(w - 12, h * 0.50), 4.0, lit)
