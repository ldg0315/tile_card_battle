extends RefCounted
## 임시 배경음악 합성기(칩튠). audio/bgm/ 에 파일이 없는 곡만 여기서 만든다.
## 곡은 마디별 화음 + 8분음표 단위 멜로디로 적고, 리드(펄스파)·베이스(삼각파)·드럼(노이즈)·
## 환경음(새소리 등)을 따로 그려 섞는다. 반복 재생이 끊김 없이 이어지도록 곡 길이를 마디 단위로 딱 맞춘다.
## 한 곡 만드는 데 0.4초 정도라 따로 스레드를 두지 않고, Sound 가 한 번 만든 곡을 메모리에 들고 있는다.

const RATE := 22050

const NOTE_INDEX := {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

# 장면(슬롯) → 곡. Sound.play_bgm 은 슬롯 이름(forest, title …)으로 부르고, 여기서 실제 곡을 고른다.
# 같은 곡을 여러 슬롯에 걸면(타이틀·맵) 화면을 넘어가도 끊기지 않고 이어진다. 동굴·해안은 아직 곡이 없다
const SLOTS := {
	"forest": "folk",
	"title": "calm_quiet",
	"map": "calm",
	"boss": "adventure",
}

const SONGS := {
	# 경쾌한 C장조 칩튠, 132 BPM, 16마디(약 29초). 새소리가 살짝씩. (지금은 어느 슬롯에도 안 걸려 있음)
	"chiptune": {
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
		"ambient": ["birds"],
	},
	# 민요풍: 6/8 지그, 플루트 같은 삼각파, 탬버린
	"folk": {
		"bpm": 104, "beat_eighths": 3, "bar_eighths": 6,
		"chords": ["C", "F", "C", "G", "C", "F", "G", "C", "Am", "F", "C", "G", "Am", "F", "G", "C"],
		"melody": [
			["E5", 2], ["D5", 1], ["C5", 2], ["E5", 1],
			["F5", 2], ["A5", 1], ["C6", 2], ["A5", 1],
			["G5", 2], ["E5", 1], ["C5", 2], ["E5", 1],
			["D5", 3], ["B4", 2], ["D5", 1],
			["E5", 2], ["G5", 1], ["C6", 2], ["G5", 1],
			["A5", 2], ["F5", 1], ["A5", 2], ["C6", 1],
			["B5", 2], ["A5", 1], ["G5", 2], ["D5", 1],
			["C5", 3], ["-", 3],
			["A5", 2], ["G5", 1], ["E5", 2], ["A5", 1],
			["F5", 2], ["E5", 1], ["F5", 2], ["A5", 1],
			["G5", 2], ["E5", 1], ["C5", 2], ["E5", 1],
			["D5", 2], ["E5", 1], ["G5", 3],
			["A5", 2], ["B5", 1], ["C6", 2], ["A5", 1],
			["F5", 2], ["A5", 1], ["C6", 2], ["F5", 1],
			["G5", 2], ["B5", 1], ["D6", 2], ["B5", 1],
			["C6", 3], ["G5", 2], ["E5", 1],
		],
		"lead_wave": "tri", "lead_vol": 0.2, "lead_sustain": 0.7,
		"bass": "folk", "bass_vol": 0.2, "drums": "folk", "drum_vol": 1.0,
		"ambient": ["birds"],
	},
	# 잔잔함: 느린 4/4, 드럼 없이 화음 패드와 종소리 멜로디, 새소리와 바람
	"calm": {
		"bpm": 84,
		"chords": ["C", "Am", "F", "G", "C", "Em", "F", "G"],
		"melody": [
			["E5", 4], ["G5", 4],
			["A5", 6], ["G5", 2],
			["F5", 4], ["A5", 2], ["C6", 2],
			["B5", 6], ["-", 2],
			["C6", 4], ["G5", 4],
			["B5", 4], ["G5", 2], ["E5", 2],
			["A5", 4], ["F5", 2], ["A5", 2],
			["G5", 8],
		],
		# 높은 사인파 멜로디는 휘파람·새 지저귐처럼 들려서(새소리를 뺀 타이틀에서도 "새소리"로 들림)
		# 한 옥타브 낮춘 부드러운 삼각파로
		"lead_wave": "tri", "lead_vol": 0.2, "lead_sustain": 0.35, "lead_transpose": -12,
		"pad_vol": 0.045, "bass": "long", "bass_vol": 0.14, "drums": "none",
		"ambient": ["birds", "wind"],
	},
	# 잔잔함에서 새소리만 뺀 판(타이틀용). base 의 값을 그대로 쓰고 적은 값만 덮어쓴다
	"calm_quiet": {"base": "calm", "ambient": ["wind"]},
	# 모험: A 단조, 빠르고 힘찬 드럼과 달리는 베이스
	"adventure": {
		"bpm": 150,
		"chords": ["Am", "F", "C", "G", "Am", "F", "G", "E", "F", "G", "Em", "Am", "F", "G", "E", "Am"],
		"melody": [
			["A4", 1], ["C5", 1], ["E5", 2], ["A5", 2], ["G5", 1], ["E5", 1],
			["F5", 2], ["E5", 1], ["D5", 1], ["C5", 2], ["A4", 2],
			["G4", 1], ["C5", 1], ["E5", 2], ["G5", 3], ["E5", 1],
			["D5", 2], ["B4", 2], ["G4", 2], ["B4", 2],
			["A4", 1], ["C5", 1], ["E5", 2], ["A5", 2], ["B5", 1], ["C6", 1],
			["A5", 2], ["F5", 2], ["C5", 2], ["F5", 2],
			["G5", 2], ["F5", 1], ["E5", 1], ["D5", 2], ["B4", 2],
			["G#4", 2], ["B4", 2], ["E5", 4],
			["F5", 3], ["E5", 1], ["F5", 2], ["A5", 2],
			["G5", 3], ["F5", 1], ["G5", 2], ["B5", 2],
			["E5", 2], ["G5", 2], ["B5", 2], ["G5", 2],
			["A5", 4], ["E5", 2], ["C5", 2],
			["F5", 1], ["A5", 1], ["C6", 2], ["A5", 2], ["F5", 2],
			["G5", 1], ["B5", 1], ["D6", 2], ["B5", 2], ["G5", 2],
			["G#5", 2], ["B5", 2], ["E6", 2], ["D6", 2],
			["C6", 2], ["B5", 2], ["A5", 4],
		],
		"lead_wave": "saw", "lead_vol": 0.12, "lead_sustain": 0.7,
		"bass": "drive", "bass_vol": 0.22, "drums": "rock", "drum_vol": 1.0,
	},
}


## 슬롯 이름이면 걸린 곡 이름으로, 곡 이름이면 그대로. 없으면 "".
static func resolve(name: String) -> String:
	var song: String = SLOTS.get(name, name)
	return song if SONGS.has(song) else ""


static func has(name: String) -> bool:
	return resolve(name) != ""


static func midi(note: String) -> int:
	var name := note.substr(0, note.length() - 1)
	return NOTE_INDEX[name] + (int(note.right(1)) + 1) * 12


static func hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## 8분음표 길이(초). beat_eighths 는 한 박이 8분음표 몇 개인지(4/4 는 2, 6/8 은 점4분 = 3).
static func eighth_sec(song: Dictionary) -> float:
	return 60.0 / song.bpm / song.get("beat_eighths", 2)


static func bar_eighths(song: Dictionary) -> int:
	return song.get("bar_eighths", 8)


## 곡 정의. base 가 있으면 그 곡을 바탕으로 적은 값만 덮어쓴다(같은 곡의 변주를 짧게 적으려고).
static func song_of(name: String) -> Dictionary:
	var song: Dictionary = SONGS[name]
	if song.has("base"):
		var merged: Dictionary = SONGS[song.base].duplicate()
		merged.merge(song, true)
		merged.erase("base")
		return merged
	return song


static func make(name: String) -> AudioStreamWAV:
	name = resolve(name)
	var song := song_of(name)
	var eighth := eighth_sec(song)
	var per := bar_eighths(song)
	var bars: int = song.chords.size()
	var total := int(bars * per * eighth * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	buf.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)

	# 리드
	var lead_wave: String = song.get("lead_wave", "pulse")
	var t := 0.0
	for n: Array in song.melody:
		var len_s: float = n[1] * eighth
		if n[0] != "-":
			_note(buf, t, len_s * 0.92, hz(midi(n[0]) + song.get("lead_transpose", 0)), lead_wave, song.lead_vol,
				song.get("lead_sustain", 0.6), song.get("lead_attack", 0.005))
		t += len_s

	# 패드: 마디마다 화음 세 음을 길게, 천천히 들어오게 — 잔잔한 곡의 바탕
	if song.get("pad_vol", 0.0) > 0.0:
		for b in bars:
			for m: int in _triad(song.chords[b]):
				_note(buf, b * per * eighth, per * eighth, hz(m + 24), "sine", song.pad_vol, 0.9, 0.35)

	# 베이스
	for b in bars:
		var root := _chord_root(song.chords[b])
		match song.get("bass", "bounce"):
			"bounce":  # 근음·옥타브·5도·옥타브 8분음표로 통통 튀게
				var pat := [root, root + 12, root + 7, root + 12]
				for k in per:
					_note(buf, (b * per + k) * eighth, eighth * 0.7, hz(pat[k % 4]), "tri", song.bass_vol, 0.3)
			"folk":  # 6/8: 쿵·(쉼)·짝짝 — 근음 길게, 5도·옥타브 짧게
				for k: int in [0, 2, 3, 5]:
					var m: int = root if k == 0 else (root + 7 if k % 2 == 0 else root + 12)
					_note(buf, (b * per + k) * eighth, eighth * (1.5 if k == 0 else 0.6), hz(m), "tri", song.bass_vol, 0.4)
			"long":  # 마디 내내 근음 하나
				_note(buf, b * per * eighth, per * eighth * 0.95, hz(root), "tri", song.bass_vol, 0.8, 0.05)
			"drive":  # 근음 8분음표 연타 — 달리는 느낌
				for k in per:
					_note(buf, (b * per + k) * eighth, eighth * 0.55, hz(root if k % 4 != 3 else root + 12), "tri", song.bass_vol, 0.5)

	# 드럼
	var dv: float = song.get("drum_vol", 1.0)
	for b in bars:
		var bar0: float = b * per * eighth
		match song.get("drums", "pop"):
			"pop":  # 1·3박 킥, 2·4박 스네어, 엇박 하이햇
				for beat in 4:
					var at: float = bar0 + beat * 2 * eighth
					if beat % 2 == 0:
						_kick(buf, at, 0.32 * dv)
					else:
						_noise_hit(buf, at, 0.12, 0.09 * dv, 0.5, rng)
					_noise_hit(buf, at + eighth, 0.035, 0.035 * dv, 0.9, rng)
			"folk":  # 6/8: 1에 부드러운 킥, 4에 탬버린, 나머지에 아주 작은 찰랑임
				_kick(buf, bar0, 0.22 * dv)
				_noise_hit(buf, bar0 + 3 * eighth, 0.09, 0.06 * dv, 0.95, rng)
				for k: int in [2, 5]:
					_noise_hit(buf, bar0 + k * eighth, 0.04, 0.025 * dv, 0.95, rng)
			"rock":  # 킥 1·3박 + 3박 앞 8분, 스네어 2·4박 세게, 하이햇 8분마다
				for k in 8:
					var at: float = bar0 + k * eighth
					if k in [0, 3, 4]:
						_kick(buf, at, 0.34 * dv)
					if k in [2, 6]:
						_noise_hit(buf, at, 0.14, 0.12 * dv, 0.45, rng)
					_noise_hit(buf, at, 0.03, 0.03 * dv, 0.92, rng)
			_:
				pass

	var amb: Array = song.get("ambient", [])
	if "birds" in amb:
		_birds(buf, rng)
	if "wind" in amb:
		_wind(buf, rng)

	# 합친 소리가 1을 넘지 않게 부드럽게 눌러 준다(찢어짐 방지)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var v := tanh(buf[i] * 1.2) * 0.85
		data.encode_s16(i * 2, int(v * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = total
	return st


## 화음 이름(C, Am, E …) → 세 음(midi, 베이스 옥타브 기준).
static func _triad(chord: String) -> Array[int]:
	var root := _chord_root(chord)
	var third := 3 if chord.ends_with("m") else 4
	return [root, root + third, root + 7]


static func _chord_root(chord: String) -> int:
	var name := chord.trim_suffix("m")
	return NOTE_INDEX[name] + 36  # 베이스는 2옥타브(C2 = 36)


## 음 하나를 버퍼에 더한다. sustain = 감쇠 후 유지되는 비율. 끝은 짧게 줄여 클릭음 없이.
static func _note(buf: PackedFloat32Array, start: float, dur: float, f: float, wave: String, vol: float, sustain: float, attack := 0.005) -> void:
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
		match wave:
			"pulse":
				s = 1.0 if phase < 0.25 else -0.33
			"saw":
				s = 2.0 * phase - 1.0
			"sine":
				s = sin(TAU * phase)
			_:
				s = 1.0 - 4.0 * absf(phase - 0.5)
		lp += (s - lp) * 0.35  # 펄스파의 날카로운 배음을 조금 깎아 귀가 덜 피곤하게
		var env := minf(1.0, sec / attack)
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


## 바람: 걸러 낸 노이즈가 천천히 커졌다 작아진다. 주기를 곡 길이에 딱 맞춰 반복될 때 이음매가 없게.
static func _wind(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var total := float(buf.size()) / RATE
	var cycles := maxf(1.0, roundf(total / 7.0))
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		var swell := 0.5 - 0.5 * cos(TAU * cycles * float(i) / buf.size())
		buf[i] += lp2 * 1.6 * (0.25 + 0.75 * swell) * 0.18
