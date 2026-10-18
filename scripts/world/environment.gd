extends WorldEnvironment

signal preset_changed(weather: String, time_of_day: String)

# Weather and the clock run by themselves. T07 can still force a state with set_preset().
@export var auto_progress := true
@export var day_length_seconds := 1800.0 # Real seconds for one 24 h cycle.
@export var start_hour := 9.0
@export_enum("sunny", "overcast", "storm") var start_weather := "sunny"
@export var weather_seed := 0 # 0 gives a different weather sequence every run.

const SUNRISE := 5.5
const SUNSET := 19.0
const MAX_SUN_ELEVATION := 50.0
const MAX_MOON_ELEVATION := 40.0
const CLOUD := {"sunny": 0.05, "overcast": 0.6, "storm": 1.0}
const DWELL := {"sunny": Vector2(180, 420), "overcast": Vector2(120, 300), "storm": Vector2(240, 420)}
const CLOUD_RISE := 0.0065 # Per real second. Sunny to overcast takes about 85 s.
const CLOUD_FALL := 0.005 # Clearing is slower than building up.
const WET_RATE := 0.04 # Ground soaks in about 25 s.
const DRY_RATE := 0.007 # And takes about 140 s to dry.
const SKY_CLEAR := Color(0.31, 0.53, 0.78)
const SKY_OVERCAST := Color(0.27, 0.31, 0.36)
const SKY_STORM := Color(0.2, 0.23, 0.28)
const SKY_NIGHT := Color(0.025, 0.04, 0.09)
const SKY_UPDATE_INTERVAL := 0.25 # The sky is heavy to refresh. Slow changes do not need every frame.

var weather := "sunny" # Weather the sky is in, or heading to.
var time_of_day := "day" # "day" while the sun is above the horizon.
var hour := 9.0
var cloud := 0.05 # 0 clear, 0.6 overcast, 1 storm cloud.
var rain_level := 0.0 # 0 to 1.
var wetness := 0.0 # 0 to 1.
var previous_weather := "sunny"
var weather_timer := 0.0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var rain: CPUParticles3D
var rain_material: ShaderMaterial
var rain_audio: AudioStreamPlayer
var sky_material: ProceduralSkyMaterial
var indoor_mix := 0.0
var sky_timer := 0.0
var shown_wetness := -1.0
var announced := ""

func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.62, 0.8)
	environment.reflected_light_source = 1 # Sky (ReflectedLightSource).
	environment.fog_enabled = true
	environment.sky = Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	environment.sky.sky_material = sky_material
	sun = _make_light("Sun")
	moon = _make_light("Moon")
	moon.light_color = Color(0.52, 0.65, 1.0)
	_build_rain()
	reseed(weather_seed)
	hour = start_hour
	set_preset(start_weather)
	for argument in OS.get_cmdline_user_args():
		if argument == "--static":
			auto_progress = false
		elif argument.begins_with("--hour="):
			hour = fposmod(argument.trim_prefix("--hour=").to_float(), 24.0)
		elif argument.begins_with("--weather="):
			set_preset(argument.trim_prefix("--weather="))
		elif argument.begins_with("--time="):
			set_preset(argument.trim_prefix("--time="))
	_derive_state()
	_apply_sky()
	_apply_rain()
	announced = weather + "/" + time_of_day

func reseed(value: int) -> void:
	if value == 0:
		rng.randomize()
	else:
		rng.seed = value

func set_preset(preset: String) -> bool:
	# T07 can pass its story flag value directly to this scene-local interface.
	# The jump is instant. Slow changes come from the automatic simulation.
	if preset in CLOUD:
		previous_weather = weather
		weather = preset
		weather_timer = _dwell(preset)
		cloud = CLOUD[preset]
		wetness = 1.0 if preset == "storm" else 0.0
	elif preset == "day":
		hour = 12.0
	elif preset == "night":
		hour = 0.0
	else:
		return false
	if is_node_ready():
		_derive_state()
		_apply_sky()
		_apply_rain()
		announced = weather + "/" + time_of_day
		preset_changed.emit(weather, time_of_day)
	return true

func advance(delta: float) -> void:
	# Moves the clock, the cloud cover and the ground wetness. Does not touch any node.
	elapsed += delta
	hour = fposmod(hour + delta * 24.0 / day_length_seconds, 24.0)
	weather_timer -= delta
	if weather_timer <= 0.0:
		previous_weather = weather
		weather = _next_weather()
		weather_timer = _dwell(weather)
	var target: float = CLOUD[weather]
	cloud = move_toward(cloud, target, (CLOUD_RISE if target > cloud else CLOUD_FALL) * delta)
	_derive_state()
	var soaking := rain_level > 0.05
	wetness = move_toward(wetness, 1.0 if soaking else 0.0, (WET_RATE if soaking else DRY_RATE) * delta)

func sun_elevation(h: float) -> float:
	# Degrees above the horizon. Below zero at night, and the moon is the mirror image.
	var day_hours := SUNSET - SUNRISE
	if h >= SUNRISE and h <= SUNSET:
		return MAX_SUN_ELEVATION * sin(PI * (h - SUNRISE) / day_hours)
	return -MAX_MOON_ELEVATION * sin(PI * fposmod(h - SUNSET, 24.0) / (24.0 - day_hours))

func _azimuth(h: float) -> float:
	# Sun yaw. East to west by day, then on around the far side. The moon sits opposite.
	var day_hours := SUNSET - SUNRISE
	if h >= SUNRISE and h <= SUNSET:
		return lerpf(-115.0, 65.0, (h - SUNRISE) / day_hours)
	return lerpf(65.0, 245.0, fposmod(h - SUNSET, 24.0) / (24.0 - day_hours))

func _dwell(state: String) -> float:
	var span: Vector2 = DWELL[state]
	return rng.randf_range(span.x, span.y)

func _next_weather() -> String:
	# Weather never skips a step: sunny and storm are only reached through overcast.
	if weather != "overcast":
		return "overcast"
	var storm_chance := 0.55 if hour >= 13.0 and hour < 20.0 else 0.3 # Afternoon storms build up in the mountains.
	if previous_weather == "storm":
		storm_chance = 0.08 # A storm that just passed rarely comes straight back.
	return "storm" if rng.randf() < storm_chance else "sunny"

func _derive_state() -> void:
	var gust := 0.9 + 0.1 * sin(elapsed * 0.07) * sin(elapsed * 0.031 + 1.3)
	# Rain starts as drizzle while the cloud thickens, and thins out again as it clears.
	rain_level = smoothstep(0.62, 0.95, cloud) * gust
	time_of_day = "day" if sun_elevation(hour) > 0.0 else "night"

func _apply_sky() -> void:
	var elev := sun_elevation(hour)
	var day := smoothstep(-5.0, 8.0, elev) # 0 at night, 1 in full daylight.
	var dusk := clampf(1.0 - absf(elev - 1.0) / 14.0, 0.0, 1.0) # Strongest at the horizon.
	var grey := clampf(cloud / 0.6, 0.0, 1.0) # 0 clear, 1 overcast.
	var storm := clampf((cloud - 0.6) / 0.4, 0.0, 1.0) # 0 up to overcast, 1 full storm.
	var tint := SKY_NIGHT.lerp(SKY_CLEAR.lerp(SKY_OVERCAST, grey).lerp(SKY_STORM, storm), day)
	var horizon := tint.lightened(lerpf(0.1, 0.22, day)).lerp(Color(0.95, 0.55, 0.32), dusk * (1.0 - cloud * 0.75) * 0.7)
	sky_material.sky_top_color = tint
	sky_material.sky_horizon_color = horizon
	sky_material.ground_bottom_color = tint.darkened(0.4)
	sky_material.ground_horizon_color = horizon
	var sun_power := smoothstep(-3.0, 14.0, elev) * lerpf(lerpf(1.0, 0.4, grey), 0.18, storm)
	sun.visible = sun_power > 0.001
	sun.light_energy = sun_power
	sun.light_color = Color(1.0, 0.91, 0.76).lerp(Color(1.0, 0.62, 0.38), dusk)
	sun.rotation_degrees = Vector3(-elev, _azimuth(hour), 0.0)
	var moon_power := 0.12 * smoothstep(0.0, 10.0, -elev) * lerpf(1.0, 0.45, cloud)
	moon.visible = moon_power > 0.001
	moon.light_energy = moon_power
	moon.rotation_degrees = Vector3(elev, _azimuth(hour) + 180.0, 0.0)
	environment.ambient_light_energy = lerpf(0.18, lerpf(0.55, 0.38, grey), day)
	environment.fog_light_color = horizon
	environment.fog_density = lerpf(lerpf(0.002, 0.006, grey), 0.018, storm)
	if wetness != shown_wetness:
		shown_wetness = wetness
		get_node("../Outdoor").set_wetness(wetness)

func _apply_rain() -> void:
	var raining := rain_level > 0.01
	rain.emitting = raining
	rain_material.set_shader_parameter("density", rain_level)
	if raining and not rain_audio.playing:
		rain_audio.play()
	elif not raining and rain_audio.playing:
		rain_audio.stop()
	# Sound swells with the rain. The 10 dB step is the wall and roof when the player is inside.
	rain_audio.volume_db = -20.0 + linear_to_db(maxf(rain_level, 0.001)) * 0.8 - 10.0 * indoor_mix

func _make_light(light_name: String) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.shadow_enabled = true
	add_child(light)
	return light

func _build_rain() -> void:
	rain = CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1800
	rain.lifetime = 1.2
	rain.preprocess = 0.0
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(14, 0.2, 14)
	rain.direction = Vector3(0.12, -1, 0.04)
	rain.spread = 3.0
	rain.initial_velocity_min = 13.0
	rain.initial_velocity_max = 17.0
	rain.gravity = Vector3(0, -4, 0)
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.32, 0.012)
	var shader := Shader.new()
	# Each drop gets a fixed random rank. Only drops ranked below "density" are drawn,
	# so light rain shows a thin sample of the same 1800 drops.
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float density = 1.0;
varying vec3 world_position;
varying flat float rank;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    rank = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
}
void fragment() {
    if (rank > density) { discard; }
    if (world_position.x > -2.6 && world_position.x < 2.6 && world_position.z > -3.5 && world_position.z < 4.5 && world_position.y < 3.5) { discard; }
    ALBEDO = vec3(0.55, 0.65, 0.76);
}
"""
	rain_material = ShaderMaterial.new()
	rain_material.shader = shader
	drop.material = rain_material
	rain.mesh = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	add_child(rain)
	rain_audio = AudioStreamPlayer.new()
	rain_audio.name = "RainAudioPlaceholder"
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 44100
	var bytes := PackedByteArray()
	bytes.resize(88200)
	var noise := RandomNumberGenerator.new()
	noise.seed = 6006
	var filtered := 0.0
	for i in 44100:
		filtered = filtered * 0.72 + noise.randf_range(-1, 1) * 0.28
		bytes.encode_s16(i * 2, int(filtered * 18000))
	stream.data = bytes
	rain_audio.stream = stream
	add_child(rain_audio)

func _process(delta: float) -> void:
	if auto_progress:
		advance(delta)
		var key := weather + "/" + time_of_day
		if key != announced:
			announced = key
			preset_changed.emit(weather, time_of_day)
	sky_timer -= delta
	if sky_timer <= 0.0:
		sky_timer = SKY_UPDATE_INTERVAL
		_apply_sky()
	var player := get_node_or_null("../Player") as Node3D
	if player:
		rain.global_position = player.global_position + Vector3(0, 10, 0)
		var indoors := absf(player.position.x) < 2.5 and player.position.z > -3.3 and player.position.z < 4.3
		indoor_mix = move_toward(indoor_mix, 1.0 if indoors else 0.0, delta * 3.0)
	_apply_rain()
