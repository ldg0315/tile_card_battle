extends RefCounted
## 임시 8비트 효과음 합성기. audio/sfx/ 에 파일이 없는 소리만 여기서 만든다.
## 파일 대신 숫자로 소리를 정의하는 이유: 소리 파일이 하나도 없어도 게임이 소리를 내고,
## 진짜 소리를 구하면 파일만 넣어 하나씩 바꿔 끼울 수 있게 하려는 것.
##
## 음 하나(note)의 값: wave(square·saw·tri·sine), f0→f1(Hz, 시작→끝으로 미끄러짐), dur(초), vol,
## noise(0~1 노이즈 섞는 비율), lp0→lp1(노이즈를 거르는 정도, 1 = 거르지 않음, 작을수록 둔탁),
## attack(초), curve(감쇠 곡선, 클수록 빨리 사라짐), vib(떨림 Hz), gap(이 음 뒤 쉼, 초).
## 프리셋의 notes 는 차례로 이어 붙는다(아르페지오 등).

# 44.1kHz: 22kHz 로 만들면 사각파·톱니파의 높은 배음이 접혀(에일리어싱) 찢어지는 소리가 났다
const RATE := 44100
const SMOOTH := 0.45  # 출력 전체에 거는 저역통과 계수(작을수록 부드럽다). 거친 고음을 깎는다
const FADE := 0.006  # 소리 끝을 이만큼(초) 줄여 끝낸다 — 뚝 끊기면 "틱" 하는 클릭음이 난다
const PEAK := 0.8  # 가장 큰 소리를 이 높이로 맞춘다(여러 소리가 겹칠 여유)

const PRESETS := {
	# UI
	"select": {"notes": [{"wave": "square", "f0": 880, "dur": 0.04, "vol": 0.18}]},
	"deselect": {"notes": [{"wave": "square", "f0": 660, "f1": 440, "dur": 0.05, "vol": 0.16}]},
	"click": {"notes": [{"wave": "square", "f0": 720, "dur": 0.03, "vol": 0.15}]},
	"go": {"notes": [{"wave": "square", "f0": 523, "f1": 1046, "dur": 0.12, "vol": 0.2}]},
	# 이동
	"move": {"notes": [{"wave": "sine", "f0": 180, "f1": 90, "dur": 0.09, "vol": 0.45, "noise": 0.35, "lp0": 0.08, "curve": 2.0}]},
	"dash": {"notes": [{"wave": "sine", "f0": 200, "dur": 0.22, "vol": 0.4, "noise": 0.9, "lp0": 0.04, "lp1": 0.35, "attack": 0.06, "curve": 1.5}]},
	# 근접
	"slash": {"notes": [{"wave": "saw", "f0": 1300, "f1": 350, "dur": 0.13, "vol": 0.3, "noise": 0.6, "lp0": 0.6, "lp1": 0.2, "curve": 1.6}]},
	"thrust": {"notes": [{"wave": "saw", "f0": 900, "f1": 260, "dur": 0.11, "vol": 0.32, "noise": 0.4, "lp0": 0.5, "curve": 1.4}]},
	"spin": {"notes": [{"wave": "sine", "f0": 300, "dur": 0.45, "vol": 0.42, "noise": 0.95, "lp0": 0.05, "lp1": 0.5, "attack": 0.12, "curve": 1.2}]},
	"jump": {"notes": [{"wave": "sine", "f0": 160, "f1": 620, "dur": 0.3, "vol": 0.35, "curve": 0.6}]},
	"slam": {"notes": [{"wave": "sine", "f0": 110, "f1": 35, "dur": 0.4, "vol": 0.6, "noise": 0.55, "lp0": 0.06, "curve": 1.8}]},
	# 원거리
	"arrow": {"notes": [{"wave": "tri", "f0": 260, "f1": 200, "dur": 0.05, "vol": 0.35, "curve": 2.0},
		{"wave": "sine", "f0": 900, "dur": 0.14, "vol": 0.22, "noise": 0.8, "lp0": 0.5, "lp1": 0.15, "curve": 1.2}]},
	"arrow_hit": {"notes": [{"wave": "sine", "f0": 220, "f1": 120, "dur": 0.06, "vol": 0.3, "noise": 0.6, "lp0": 0.2, "curve": 2.5}]},
	"volley": {"notes": [{"wave": "tri", "f0": 300, "f1": 220, "dur": 0.05, "vol": 0.3, "curve": 2.0},
		{"wave": "sine", "f0": 1200, "f1": 1800, "dur": 0.25, "vol": 0.18, "noise": 0.85, "lp0": 0.3, "curve": 1.0}]},
	"wave": {"notes": [{"wave": "sine", "f0": 1800, "f1": 2400, "dur": 0.3, "vol": 0.18, "vib": 28.0, "curve": 1.0}]},
	# 맞음·막음
	"hit": {"notes": [{"wave": "sine", "f0": 160, "f1": 60, "dur": 0.16, "vol": 0.55, "noise": 0.55, "lp0": 0.3, "curve": 2.0}]},
	"block": {"notes": [{"wave": "square", "f0": 1250, "dur": 0.18, "vol": 0.16, "curve": 2.5},
		{"wave": "square", "f0": 1870, "dur": 0.12, "vol": 0.1, "curve": 2.5}]},
	"backstab": {"notes": [{"wave": "sine", "f0": 180, "f1": 60, "dur": 0.14, "vol": 0.55, "noise": 0.6, "lp0": 0.35, "curve": 2.0},
		{"wave": "square", "f0": 1500, "f1": 2100, "dur": 0.2, "vol": 0.16, "curve": 1.5}]},
	"guard": {"notes": [{"wave": "square", "f0": 330, "f1": 440, "dur": 0.08, "vol": 0.2, "curve": 1.5}]},
	"rest": {"notes": [{"wave": "sine", "f0": 600, "f1": 1300, "dur": 0.28, "vol": 0.2, "vib": 12.0, "curve": 0.8}]},
	"heal": {"notes": [{"wave": "sine", "f0": 523, "dur": 0.1, "vol": 0.2, "curve": 0.6},
		{"wave": "sine", "f0": 659, "dur": 0.1, "vol": 0.2, "curve": 0.6},
		{"wave": "sine", "f0": 784, "dur": 0.25, "vol": 0.2, "vib": 8.0, "curve": 0.8}]},
	"death": {"notes": [{"wave": "square", "f0": 420, "f1": 70, "dur": 0.55, "vol": 0.25, "curve": 0.9}]},
	# 보스·결과
	"warn": {"notes": [{"wave": "square", "f0": 880, "dur": 0.12, "vol": 0.18, "curve": 0.3, "gap": 0.05},
		{"wave": "square", "f0": 660, "dur": 0.12, "vol": 0.18, "curve": 0.3, "gap": 0.05},
		{"wave": "square", "f0": 880, "dur": 0.12, "vol": 0.18, "curve": 0.3, "gap": 0.05},
		{"wave": "square", "f0": 660, "dur": 0.2, "vol": 0.18, "curve": 0.6}]},
	"victory": {"notes": [{"wave": "square", "f0": 523, "dur": 0.1, "vol": 0.2, "curve": 0.5},
		{"wave": "square", "f0": 659, "dur": 0.1, "vol": 0.2, "curve": 0.5},
		{"wave": "square", "f0": 784, "dur": 0.1, "vol": 0.2, "curve": 0.5},
		{"wave": "square", "f0": 1046, "dur": 0.35, "vol": 0.22, "vib": 6.0, "curve": 0.8}]},
	"defeat": {"notes": [{"wave": "tri", "f0": 392, "dur": 0.2, "vol": 0.3, "curve": 0.5},
		{"wave": "tri", "f0": 330, "dur": 0.2, "vol": 0.3, "curve": 0.5},
		{"wave": "tri", "f0": 262, "dur": 0.55, "vol": 0.3, "vib": 5.0, "curve": 0.8}]},
}


static func has(name: String) -> bool:
	return PRESETS.has(name)


static func make(name: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	# 노이즈도 매번 같은 소리가 나도록 시드를 고정한다(소리마다 다르게 이름으로)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for note: Dictionary in PRESETS[name].notes:
		_render(note, samples, rng)
	_finish(samples, PRESETS[name].notes)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


## 마무리: 거친 고음 깎기 → 끝 페이드 → 음량 맞추기. 음량은 프리셋 vol 중 가장 큰 값을 기준으로 해서
## 조용해야 할 소리(클릭 등)는 그대로 조용하게 둔다.
static func _finish(samples: PackedFloat32Array, notes: Array) -> void:
	var lp := 0.0
	var peak := 0.0
	for i in samples.size():
		lp += (samples[i] - lp) * SMOOTH
		samples[i] = lp
		peak = maxf(peak, absf(lp))
	var fade_n := mini(int(FADE * RATE), samples.size())
	for k in fade_n:
		samples[samples.size() - 1 - k] *= float(k) / fade_n
	var loudest := 0.0
	for n: Dictionary in notes:
		loudest = maxf(loudest, n.get("vol", 0.3))
	var target := minf(PEAK, loudest * 1.4)
	if peak > target:
		for i in samples.size():
			samples[i] *= target / peak


static func _render(n: Dictionary, out: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var dur: float = n.get("dur", 0.1)
	var f0: float = n.get("f0", 440.0)
	var f1: float = n.get("f1", f0)
	var wave: String = n.get("wave", "square")
	var vol: float = n.get("vol", 0.3)
	var noise: float = n.get("noise", 0.0)
	var lp0: float = n.get("lp0", 1.0)
	var lp1: float = n.get("lp1", lp0)
	var attack: float = n.get("attack", 0.004)
	var curve: float = n.get("curve", 1.0)
	var vib: float = n.get("vib", 0.0)
	var count := int(dur * RATE)
	var phase := 0.0
	var lp := 0.0
	for i in count:
		var t := float(i) / count
		var sec := float(i) / RATE
		var f := lerpf(f0, f1, t)
		if vib > 0.0:
			f *= 1.0 + 0.03 * sin(TAU * vib * sec)
		phase = fmod(phase + f / RATE, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"saw":
				s = 2.0 * phase - 1.0
			"tri":
				s = 1.0 - 4.0 * absf(phase - 0.5)
			_:
				s = sin(TAU * phase)
		if noise > 0.0:
			# 한 극 저역통과로 노이즈를 거른다 — 계수가 작을수록 "쉭"이 아니라 "퍽"에 가까워진다
			lp += (rng.randf_range(-1.0, 1.0) - lp) * lerpf(lp0, lp1, t)
			s = lerpf(s, lp * 2.0, noise)
		var env := minf(1.0, sec / attack) * pow(1.0 - t, curve)
		out.append(s * env * vol)
	var gap: float = n.get("gap", 0.0)
	for i in int(gap * RATE):
		out.append(0.0)
