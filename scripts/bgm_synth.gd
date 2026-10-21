extends RefCounted
## 임시 배경음악 합성기(칩튠). audio/bgm/ 에 파일이 없는 곡만 여기서 만든다.
## 곡은 마디별 화음 + 8분음표 단위 멜로디로 적고, 리드(펄스파)·베이스(삼각파)·드럼(노이즈)·
## 환경음(새소리 등)을 따로 그려 섞는다. 반복 재생이 끊김 없이 이어지도록 곡 길이를 마디 단위로 딱 맞춘다.
## 한 곡 만드는 데 0.4초 정도라 따로 스레드를 두지 않고, Sound 가 한 번 만든 곡을 메모리에 들고 있는다.

const RATE := 22050

const NOTE_INDEX := {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

# 숲: 경쾌한 C장조, 132 BPM, 16마디(약 29초). 새소리가 살짝씩.
const SONGS := {
	"forest": {
		"bpm": 132,
		"chords": ["C", "G", "Am", "F", "C", "G", "F", "G", "Am", "F", "C", "G", "Am", "F", "G", "C"],
		# [음, 8분음표 길이]. "-" 는 쉼
		"melody": [
			["E5", 2], ["G5", 2], ["C6", 2], ["G5", 2],
			["D5", 2], ["G5", 2], ["B5", 3], ["A5", 1],
			["C6", 2], ["B5", 1], ["A5", 1], ["E5", 2], ["A5", 2],
			["F5", 2], ["A5", 2], ["C6", 3], ["-", 1],
			["E5", 1], ["F5", 1], ["G5", 2], ["E5", 2], ["C5", 2],
			["D5", 2], ["B4", 2], ["D5", 2], ["G5", 2],
			["A5", 2], ["G5", 2], ["F5", 2], ["A5", 2],
			["G5", 4], ["D5", 2], ["-", 2],
			["A5", 3], ["B5", 1], ["C6", 2], ["A5", 2],
			["F5", 3], ["G5", 1], ["A5", 2], ["F5", 2],
			["G5", 2], ["E5", 1], ["G5", 1], ["C6", 2], ["G5", 2],
			["B5", 2], ["A5", 2], ["G5", 2], ["D5", 2],
			["E5", 1], ["A5", 1], ["C6", 2], ["B5", 1], ["A5", 1], ["E5", 2],
			["F5", 2], ["A5", 2], ["C6", 2], ["A5", 2],
			["B5", 2], ["D6", 2], ["B5", 2], ["G5", 2],
			["C6", 4], ["G5", 2], ["E5", 2],
		],
		"lead_vol": 0.16, "bass_vol": 0.2, "drum_vol": 1.0,
		"ambient": "birds",
	},
}


static func has(name: String) -> bool:
	return SONGS.has(name)


static func midi(note: String) -> int:
	var name := note.substr(0, note.length() - 1)
	return NOTE_INDEX[name] + (int(note.right(1)) + 1) * 12


static func hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


static func make(name: String) -> AudioStreamWAV:
	var song: Dictionary = SONGS[name]
	var eighth: float = 60.0 / song.bpm / 2.0
	var bars: int = song.chords.size()
	var total := int(bars * 8 * eighth * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	buf.fill(0.0)

	# 리드: 25% 펄스파, 약한 비브라토, 짧은 감쇠 후 지속
	var t := 0.0
	for n: Array in song.melody:
		var len_s: float = n[1] * eighth
		if n[0] != "-":
			_note(buf, t, len_s * 0.92, hz(midi(n[0])), "pulse", song.lead_vol, 0.6)
		t += len_s

	# 베이스: 화음 근음 기준 [근음, 옥타브, 5도, 옥타브] 를 마디에 두 번, 짧게 끊어 통통 튀게
	for b in bars:
		var root := _chord_root(song.chords[b])
		var pattern := [root, root + 12, root + 7, root + 12, root, root + 12, root + 7, root + 12]
		for k in 8:
			_note(buf, (b * 8 + k) * eighth, eighth * 0.7, hz(pattern[k]), "tri", song.bass_vol, 0.3)

	# 드럼: 1·3박 킥, 2·4박 스네어, 엇박마다 하이햇
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for b in bars:
		for beat in 4:
			var at: float = (b * 8 + beat * 2) * eighth
			if beat % 2 == 0:
				_kick(buf, at, 0.32 * song.drum_vol)
			else:
				_noise_hit(buf, at, 0.12, 0.09 * song.drum_vol, 0.5, rng)
			_noise_hit(buf, at + eighth, 0.035, 0.035 * song.drum_vol, 0.9, rng)

	if song.get("ambient", "") == "birds":
		_birds(buf, rng)

	# 합친 소리가 1을 넘지 않게 부드럽게 눌러 준다(찢어짐 방지)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var v := tanh(buf[i] * 1.2) * 0.85
		data.encode_s16(i * 2, int(v * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = total
	return s


static func _chord_root(chord: String) -> int:
	var name := chord.trim_suffix("m")
	return NOTE_INDEX[name] + 36  # 베이스는 2옥타브(C2 = 36)


## 음 하나를 버퍼에 더한다. sustain = 감쇠 후 유지되는 비율. 끝은 짧게 줄여 클릭음 없이.
static func _note(buf: PackedFloat32Array, start: float, dur: float, f: float, wave: String, vol: float, sustain: float) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	var lp := 0.0
	var rel := int(0.03 * RATE)
	for k in n:
		var i := i0 + k
		if i >= buf.size():
			break
		var sec := float(k) / RATE
		var ff := f * (1.0 + (0.006 * sin(TAU * 5.5 * sec) if sec > 0.12 else 0.0))
		phase = fmod(phase + ff / RATE, 1.0)
		var s: float
		if wave == "pulse":
			s = 1.0 if phase < 0.25 else -0.33
		else:
			s = 1.0 - 4.0 * absf(phase - 0.5)
		lp += (s - lp) * 0.35  # 펄스파의 날카로운 배음을 조금 깎아 귀가 덜 피곤하게
		var env := minf(1.0, sec / 0.005)
		env *= lerpf(1.0, sustain, minf(1.0, sec / 0.12))
		if k > n - rel:
			env *= float(n - k) / rel
		buf[i] += lp * env * vol


static func _kick(buf: PackedFloat32Array, start: float, vol: float) -> void:
	var i0 := int(start * RATE)
	var n := int(0.13 * RATE)
	var phase := 0.0
	for k in n:
		if i0 + k >= buf.size():
			break
		var t := float(k) / n
		phase = fmod(phase + lerpf(130.0, 45.0, t) / RATE, 1.0)
		buf[i0 + k] += sin(TAU * phase) * pow(1.0 - t, 2.0) * vol


static func _noise_hit(buf: PackedFloat32Array, start: float, dur: float, vol: float, bright: float, rng: RandomNumberGenerator) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var lp := 0.0
	var prev := 0.0
	for k in n:
		if i0 + k >= buf.size():
			break
		var t := float(k) / n
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * bright
		# 밝은 소리(하이햇)는 저음을 빼서 "칙", 어두운 소리(스네어)는 그대로 "탁"
		var s := lp - prev * 0.6 if bright > 0.7 else lp
		prev = lp
		buf[i0 + k] += s * pow(1.0 - t, 3.0) * vol


## 새소리: 2~5초마다 짧은 지저귐 2~4번. 높은 사인파가 위아래로 빠르게 미끄러진다.
## 곡 끝 근처에는 넣지 않는다 — 반복될 때 지저귐이 잘려 이어지면 어색하다.
static func _birds(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var total := float(buf.size()) / RATE
	var t := rng.randf_range(0.8, 2.0)
	while t < total - 1.0:
		var chirps := rng.randi_range(2, 4)
		var base := rng.randf_range(2600.0, 3800.0)
		var at := t
		for c in chirps:
			var dur := rng.randf_range(0.05, 0.09)
			var i0 := int(at * RATE)
			var n := int(dur * RATE)
			var phase := 0.0
			var up := rng.randf() < 0.6
			for k in n:
				if i0 + k >= buf.size():
					break
				var x := float(k) / n
				var f := base * (1.0 + (0.35 * sin(PI * x) if up else -0.2 * x))
				phase = fmod(phase + f / RATE, 1.0)
				buf[i0 + k] += sin(TAU * phase) * sin(PI * x) * 0.06
			at += dur + rng.randf_range(0.03, 0.08)
		t += rng.randf_range(2.0, 5.0)
