extends Node
## audio_mgr.gd — 程序化音效生成器 (不依赖外部音频文件)
## 用 AudioStreamWAV 合成简单的提示音，挂在 autoload 下
##
## 公开 API:
##   play_sfx("escape")  挣脱 (下行扫频)
##   play_sfx("capture") 吞噬 (上行扫频)
##   play_sfx("hit")     受伤 (噪声)
##   play_sfx("levelup") 升级 (上行扫频)

# ─── 参数 ─────────────────────────────────────────────
const SAMPLE_RATE := 22050.0

# 各音效配置
const SFX_CONFIG := {
	"escape":  { "f0": 320.0, "f1": 120.0, "dur": 0.18, "kind": "tone", "amp": 0.3 },
	"capture": { "f0": 440.0, "f1": 880.0, "dur": 0.12, "kind": "tone", "amp": 0.25 },
	"hit":     { "f0": 0.0,   "f1": 0.0,   "dur": 0.22, "kind": "noise","amp": 0.35 },
	"levelup": { "f0": 520.0, "f1": 1200.0,"dur": 0.4,  "kind": "tone", "amp": 0.25 },
}

var _players: Dictionary = {}   # name -> AudioStreamPlayer
var _enabled := true

func _ready() -> void:
	for key in SFX_CONFIG:
		var player := AudioStreamPlayer.new()
		player.stream = _bake_sfx(key, SFX_CONFIG[key])
		add_child(player)
		_players[key] = player
	print("[AudioMgr] 初始化完成 — 程序化音效: ", SFX_CONFIG.keys())

## 播放指定音效 (不存在的名称则静默)
func play_sfx(name: String) -> void:
	if not _enabled or not _players.has(name):
		return
	var player: AudioStreamPlayer = _players[name]
	player.stream = _bake_sfx(name, SFX_CONFIG[name])
	player.play()

## 合成一段短音效为 AudioStreamWAV
func _bake_sfx(name: String, cfg: Dictionary) -> AudioStreamWAV:
	var f0: float = cfg["f0"]
	var f1: float = cfg["f1"]
	var dur: float = cfg["dur"]
	var kind: String = cfg["kind"]
	var amp: float = cfg["amp"]
	var n: int = int(SAMPLE_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)  # 16-bit mono
	var phase: float = 0.0
	for i in n:
		var t: float = i / float(n)
		var sample: float
		if kind == "tone":
			var f: float = lerpf(f0, f1, t)
			phase += TAU * f / SAMPLE_RATE
			var env: float = minf(t * 8.0, 1.0) * maxf(1.0 - t * 0.4, 0.0)
			sample = sin(phase) * amp * env
		else:  # noise
			var env: float = exp(-t * 6.0)
			sample = (randf() * 2.0 - 1.0) * amp * env
		var v16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i*2] = v16 & 0xFF
		data[i*2+1] = (v16 >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(SAMPLE_RATE)
	wav.stereo = false
	return wav

## 静音开关
func set_enabled(value: bool) -> void:
	_enabled = value

func is_enabled() -> bool:
	return _enabled
