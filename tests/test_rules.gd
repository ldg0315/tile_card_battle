extends SceneTree
## 규칙 회귀 테스트. 화면 없이 돈다:
##   godot --headless --path . -s tests/test_rules.gd

const Rules := preload("res://scripts/game_rules.gd")
const AI := preload("res://scripts/ai.gd")
const CharArt := preload("res://scripts/char_art.gd")
const PixelArt := preload("res://scripts/pixel_art.gd")
const GameState := preload("res://scripts/game_state.gd")
const BossPlan := preload("res://scripts/boss_plan.gd")
const Cards := preload("res://scripts/cards.gd")
const Themes := preload("res://scripts/themes.gd")
const Synth := preload("res://scripts/sfx_synth.gd")
const BgmSynth := preload("res://scripts/bgm_synth.gd")

var failed := 0


func _init() -> void:
	_test_forward_is_toward_opponent()
	_test_wall_blocks_move()
	_test_same_tile_and_swap_blocked()
	_test_attack_and_guard()
	_test_facing_flips_after_passing()
	_test_facing_locked_during_turn()
	_test_dash_backstab()
	_test_backstab()
	_test_simultaneous_ko_is_draw()
	_test_selection_rules()
	_test_ai_always_valid()
	_test_art_file_names()
	_test_generated_art_complete()
	_test_load_strip()
	_test_monster_hp()
	_test_single_progress()
	_test_chapter_data()
	_test_multi_enemy()
	_test_mp_regen()
	_test_dash()
	_test_dash_only_players_and_bosses()
	_test_reward_cards_in_battle()
	_test_reward_progress()
	_test_hires_art()
	_test_synth_sounds()
	_test_bgm()
	_test_bgm_slots()
	_test_ai_fixed_slots()
	_test_boss_pattern()
	print("ALL PASSED" if failed == 0 else "FAILED: %d" % failed)
	quit(0 if failed == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failed += 1
		printerr("FAIL: ", msg)


func _setup(p0: Vector2i, p1: Vector2i):
	var r = Rules.new()
	r.fighters[0].pos = p0
	r.fighters[1].pos = p1
	r._update_facing()
	return r


func _test_forward_is_toward_opponent() -> void:
	var r = Rules.new()
	r.resolve_turn(["right", "rest", "guard"], ["left", "rest", "guard"])
	check(r.fighters[0].pos == Vector2i(1, 1), "오른쪽 = 열 +1")
	check(r.fighters[1].pos == Vector2i(2, 1), "왼쪽 = 열 -1")
	# 이동은 바라보는 방향과 무관 — 왼쪽을 보고 있어도 "오른쪽"은 오른쪽
	r = _setup(Vector2i(2, 0), Vector2i(0, 1))
	check(r.fighters[0].facing == -1, "(준비) 왼쪽을 바라봄")
	r.resolve_turn(["right", "rest", "guard"], ["rest", "guard", "up"])
	check(r.fighters[0].pos == Vector2i(3, 0), "이동은 화면 기준")


func _test_wall_blocks_move() -> void:
	var r = Rules.new()
	r.resolve_turn(["up", "up", "rest"], ["right", "down", "down"])
	check(r.fighters[0].pos == Vector2i(0, 0), "보드 밖으로는 못 나감(위)")
	check(r.fighters[1].pos == Vector2i(3, 2), "보드 밖으로는 못 나감(뒤·아래)")


func _test_same_tile_and_swap_blocked() -> void:
	var r = _setup(Vector2i(0, 1), Vector2i(2, 1))
	r.resolve_turn(["right", "rest", "guard"], ["left", "rest", "guard"])
	check(r.fighters[0].pos == Vector2i(0, 1) and r.fighters[1].pos == Vector2i(2, 1), "같은 칸 진입은 둘 다 제자리")
	r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	r.resolve_turn(["right", "rest", "guard"], ["left", "rest", "guard"])
	check(r.fighters[0].pos == Vector2i(1, 1) and r.fighters[1].pos == Vector2i(2, 1), "자리 맞바꾸기는 둘 다 제자리")


func _test_attack_and_guard() -> void:
	var r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	var ev: Array = r.resolve_turn(["sword_slash", "rest", "rest"], ["guard", "rest", "rest"])
	check(ev[0].hits[0].hit and ev[0].hits[0].dmg == 25 - Rules.GUARD_BLOCK, "방어 중 피해 감소")
	check(r.fighters[1].hp == Rules.MAX_HP - (25 - Rules.GUARD_BLOCK), "HP 반영")
	check(ev[0].mp[0] == Rules.START_MP - 15, "공격 MP 소모")
	r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	r.resolve_turn(["sword_slash", "rest", "rest"], ["up", "rest", "rest"])
	check(r.fighters[1].hp == Rules.MAX_HP, "같은 단계 이동으로 회피")


func _test_facing_flips_after_passing() -> void:
	var r = _setup(Vector2i(1, 0), Vector2i(2, 1))
	r.resolve_turn(["right", "dash_right", "rest"], ["rest", "rest", "rest"])
	check(r.fighters[0].pos == Vector2i(3, 0), "상대 옆을 지나 이동")
	check(r.fighters[0].facing == -1 and r.fighters[1].facing == 1, "턴이 끝나면 서로 돌아섬")


## 이동한 쪽은 바로 돌아서고, 가만히 있던 쪽은 방향을 유지한다 — 그래서 지나친 상대에게 등을 내준다.
func _test_facing_locked_during_turn() -> void:
	var r = _setup(Vector2i(1, 0), Vector2i(2, 1))
	var ev: Array = r.resolve_turn(["right", "dash_right", "rest"], ["rest", "rest", "rest"])
	check(ev[0].facing[0] == 1, "같은 열로 오면 방향 유지")
	check(ev[1].facing[0] == -1, "상대를 지나친 이동 직후 돌아섬")
	check(ev[1].facing[1] == -1, "가만히 있던 쪽은 방향 유지(등을 내줌)")
	check(r.fighters[1].facing == 1 and r.fighters[0].facing == -1, "턴이 끝나면 모두 가장 가까운 적을 향함")


## 2칸 이동으로 넘어가 바로 베면 뒤잡기.
func _test_dash_backstab() -> void:
	var r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	var ev: Array = r.resolve_turn(["dash_right", "sword_slash", "guard"], ["rest", "guard", "rest"])
	check(ev[0].facing[0] == -1, "넘어가자마자 상대를 향해 돌아섬")
	check(ev[1].hits[0].back and ev[1].hits[0].dmg == int(25 * Rules.BACKSTAB_MULT), "넘어가서 벤 일반 베기가 뒤잡기, 방어도 무시")


func _test_backstab() -> void:
	# 상대가 나를 지나쳐 (0,0)에서 등을 보이는 상황: 상대 facing -1, 나는 오른쪽(1,1)
	var r = Rules.new()
	r.fighters[0].pos = Vector2i(1, 1)
	r.fighters[0].facing = 1
	r.fighters[1].pos = Vector2i(0, 0)
	r.fighters[1].facing = -1
	var ev: Array = r.resolve_turn(["sword_spin", "rest", "rest"], ["guard", "rest", "rest"])
	var expected := int(15 * Rules.BACKSTAB_MULT)
	check(ev[0].hits[0].back, "등 뒤 판정")
	check(ev[0].hits[0].dmg == expected, "뒤잡기 배율 적용, 방어는 등 뒤를 못 막음 (%d)" % ev[0].hits[0].dmg)
	r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	ev = r.resolve_turn(["sword_slash", "rest", "rest"], ["rest", "rest", "rest"])
	check(not ev[0].hits[0].back and ev[0].hits[0].dmg == 25, "정면 공격은 배율 없음")
	r = _setup(Vector2i(1, 0), Vector2i(1, 1))
	check(not Rules.is_behind(r.fighters[1], r.fighters[0].pos), "같은 열(옆)은 뒤가 아님")


func _test_simultaneous_ko_is_draw() -> void:
	var r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	r.fighters[0].hp = 10
	r.fighters[1].hp = 10
	var ev: Array = r.resolve_turn(["sword_slash", "rest", "rest"], ["archer_kick", "rest", "rest"])
	check(r.winner == 2, "동시 KO 는 무승부")
	check(ev.size() == 1, "승부가 나면 남은 단계는 진행하지 않음")


func _test_selection_rules() -> void:
	var r = Rules.new()
	check(r.is_valid_selection(0, ["right", "sword_slash", "guard"]), "정상 선택")
	check(not r.is_valid_selection(0, ["right", "right", "guard"]), "중복 카드 금지")
	r.fighters[0].mp = 50
	check(not r.is_valid_selection(0, ["sword_thrust", "sword_spin", "right"]), "MP 초과 금지 (30+25 > 50)")
	check(not r.is_valid_selection(0, ["archer_arrow", "right", "guard"]), "상대 캐릭터 카드 금지")


func _test_ai_always_valid() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 30:
		rng.seed = seed
		var r = Rules.new()
		r.fighters[1].mp = seed * 3
		var pick: Array = AI.choose(r, 1, rng)
		check(r.is_valid_selection(1, pick), "AI 선택이 유효해야 함 (seed %d)" % seed)


func _test_art_file_names() -> void:
	check(CharArt.parse_name("attack_6.png") == ["attack", 6], "동작_프레임수 파싱")
	check(CharArt.parse_name("idle.png") == ["idle", 1], "프레임수 생략은 1장")
	check(CharArt.parse_name("walk_x.png") == ["walk_x", 1], "숫자가 아니면 이름의 일부")


func _test_generated_art_complete() -> void:
	for char_id in ["sword", "archer"]:
		var frames: SpriteFrames = CharArt.build_frames(char_id)
		for anim: String in CharArt.ANIMS:
			check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "%s/%s 프레임 존재" % [char_id, anim])
		var t := frames.get_frame_texture("attack", 0)
		check(t.get_width() == PixelArt.W and t.get_height() == PixelArt.H, "%s 임시 도트 크기" % char_id)


## 그림 파일이 있으면 임시 도트 대신 쓰이고, 가로 스트립이 프레임 수대로 잘리는지.
func _test_load_strip() -> void:
	var dir := ProjectSettings.globalize_path("res://art/_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(30, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(dir + "/attack_3.png")
	var texs := CharArt.load_strip("_test", "attack")
	check(texs.size() == 3 and texs[0].get_width() == 10, "스트립을 3프레임으로 자름")
	var frames: SpriteFrames = CharArt.build_frames("_test")
	check(frames.get_frame_count("attack") == 3, "그림이 있는 동작은 그림을 사용")
	check(frames.get_frame_count("idle") > 0, "그림이 없는 동작은 임시 도트로 채움")
	DirAccess.remove_absolute(dir + "/attack_3.png")
	DirAccess.remove_absolute(dir)


func _test_monster_hp() -> void:
	var r = Rules.new("sword", "skeleton")
	check(r.fighters[1].max_hp == 140 and r.fighters[1].hp == 140, "몬스터는 자기 최대 HP 로 시작")
	check(r.fighters[0].max_hp == Rules.MAX_HP, "hp 를 안 적은 캐릭터는 기본 HP")
	check(r.fighters[1].copy().max_hp == 140, "복사본도 최대 HP 유지(AI 시뮬레이션)")


func _test_single_progress() -> void:
	var g = GameState.new()
	g.player_char = "archer"
	g.start_single()
	var cfg: Dictionary = g.battle_config()
	check(cfg.player == "archer" and cfg.enemies == ["slime"] and cfg.enemy_hp == [20], "1-1: 선택 캐릭터 vs HP 20 슬라임")
	check(cfg.theme == "forest" and cfg.player_hp == -1, "1장은 숲, 최대 HP 로 시작")
	g.on_single_won(40)
	check(g.stage == 1 and g.player_hp == 40 + GameState.HEAL_BETWEEN, "스테이지를 넘어가면 HP 이어짐 + 회복")
	cfg = g.battle_config()
	check(cfg.enemies == ["slime", "mushroom"] and cfg.enemy_hp == [20, 20], "1-2 는 슬라임과 독버섯이 동시에")
	check(not g.has_next_wave(), "1-2 는 한 번의 전투")
	g.on_single_won(95)
	check(g.stage == 2 and g.player_hp == GameState.max_hp("archer"), "회복은 최대 HP 를 넘지 않음")
	check(g.current_stage().get("boss", false) and g.battle_config().enemies == ["king_slime"], "1-3 보스는 킹슬라임")
	g.on_single_won(10)
	check(g.chapter == 1 and g.stage == 0 and g.player_hp == -1, "장 보스를 잡으면 다음 장, HP 전부 회복")
	check(g.battle_config().theme == "cave", "2장은 동굴")
	check(GameState.stage_code(0, 2) == "1-3", "스테이지 표기")
	g.start_versus()
	check(g.battle_config().enemies == ["sword"], "대전 상대는 고르지 않은 캐릭터")
	g.free()


## 모든 장 데이터가 실제 캐릭터·테마를 가리키는지(오타로 전투가 깨지지 않게).
func _test_chapter_data() -> void:
	for ch: Dictionary in GameState.CHAPTERS:
		check(Themes.THEMES.has(ch.theme), "%s 테마 존재" % ch.name)
		check(ch.stages[-1].get("boss", false), "%s 마지막 스테이지는 보스" % ch.name)
		for st: Dictionary in ch.stages:
			for group: Array in st.waves:
				check(group.size() >= 1 and group.size() <= 3, "%s: 한 전투의 적은 1~3마리" % st.name)
			for e: Dictionary in GameState.stage_enemies(st):
				check(Cards.CHARACTERS.has(e.id), "%s 의 적 %s 존재" % [st.name, e.id])


func _test_ai_fixed_slots() -> void:
	var rng := RandomNumberGenerator.new()
	var r = Rules.new("sword", "skeleton")
	for seed in 10:
		rng.seed = seed
		var pick: Array = AI.choose(r, 1, rng)
		check(not pick.has("skel_storm"), "패턴 전용 카드는 AI 가 스스로 고르지 않음")
		pick = AI.choose(r, 1, rng, ["skel_storm", null, null])
		check(pick[0] == "skel_storm" and r.is_valid_selection(1, pick), "고정 칸은 지정한 카드로")


## 보스와의 약속: 예고(warn)가 나온 바로 다음 턴엔 반드시 대기술, 예고 없는 대기술은 없음. 분노 페이즈에선 주기가 짧아진다.
## 패턴이 있는 모든 보스에 대해 검사한다.
func _test_boss_pattern() -> void:
	var rng := RandomNumberGenerator.new()
	for boss: String in Cards.CHARACTERS:
		if not BossPlan.has_pattern(boss):
			continue
		var special := ""
		for id: String in Cards.CHARACTERS[boss].attacks:
			if Cards.CHARACTERS[boss].attacks[id].get("pattern_only", false):
				special = id
		var r = Rules.new("sword", boss)
		var st: Dictionary = BossPlan.new_state()
		var warned := false
		var count := 0
		for t in 8:
			var plan: Dictionary = BossPlan.plan(r, 1, rng, st)
			if warned:
				check(plan.cards.has(special), "%s: 예고 다음 턴은 대기술 (턴 %d)" % [boss, t])
			if plan.cards.has(special):
				count += 1
				check(warned, "%s: 예고 없이 대기술을 쓰지 않음 (턴 %d)" % [boss, t])
			warned = plan.warn != ""
		check(count == 2, "%s: 1페이즈는 4턴마다 대기술 (%d회)" % [boss, count])
		r.fighters[1].hp = r.fighters[1].max_hp / 2 - 1
		var plan: Dictionary = BossPlan.plan(r, 1, rng, st)
		check(plan.phase_msg != "" and plan.warn != "", "%s: HP 절반 이하면 분노 페이즈 + 바로 예고" % boss)
		check(BossPlan.plan(r, 1, rng, st).cards.has(special), "%s: 분노 페이즈도 예고 다음 턴 대기술" % boss)
	check(not BossPlan.has_pattern("slime"), "일반 몬스터는 패턴 없음")


## 2대1: 적 둘이 위아래로 서서 시작, 범위 공격은 둘 다 맞고, 둘 다 쓰러져야 승리.
func _test_multi_enemy() -> void:
	var r = Rules.new("sword", ["slime", "mushroom"])
	check(r.fighters.size() == 3 and r.fighters[1].pos == Vector2i(3, 0) and r.fighters[2].pos == Vector2i(3, 2), "적 둘은 오른쪽 끝 위아래")
	check(r.fighters[1].team == 1 and r.fighters[2].team == 1 and r.foes_of(0) == [1, 2], "적 팀 구분")
	r.fighters[0].pos = Vector2i(2, 1)
	r.fighters[1].pos = Vector2i(3, 0)
	r.fighters[2].pos = Vector2i(3, 2)
	r.fighters[0].facing = 1
	var ev: Array = r.resolve_turn([["sword_spin", "rest", "guard"], ["rest", "rest", "rest"], ["rest", "rest", "rest"]])
	check(ev[0].hits[0].targets.size() == 2, "회전베기 한 번에 두 마리")
	r.fighters[1].hp = 1
	r.fighters[2].hp = 1
	r.fighters[0].mp = 50
	ev = r.resolve_turn([["sword_spin", "rest", "guard"], ["rest", "rest", "rest"], ["rest", "rest", "rest"]])
	check(ev[0].died == [1, 2] and r.winner == 0, "둘 다 쓰러지면 승리")
	check(ev.size() == 1, "승부가 나면 남은 단계 생략")

	r = Rules.new("sword", ["slime", "mushroom"])
	r.fighters[1].hp = 1
	r.fighters[0].pos = Vector2i(2, 0)
	r.fighters[0].facing = 1
	ev = r.resolve_turn([["sword_slash", "rest", "guard"], ["rest", "rest", "rest"], ["left", "rest", "rest"]])
	check(ev[0].died == [1] and r.winner == -1, "하나만 쓰러지면 계속")
	check(ev[1].cards[1] == "", "쓰러진 적은 남은 카드를 내지 않음")
	# 같은 칸 진입 충돌은 셋 이상이어도 관련된 쪽 모두 제자리
	r = Rules.new("sword", ["slime", "mushroom"])
	r.fighters[0].pos = Vector2i(2, 1)
	r.resolve_turn([["rest", "rest", "rest"], ["down", "rest", "rest"], ["up", "rest", "rest"]])
	check(r.fighters[1].pos == Vector2i(3, 0) and r.fighters[2].pos == Vector2i(3, 2), "두 적이 같은 칸으로 가려 하면 둘 다 제자리")


func _test_mp_regen() -> void:
	var r = Rules.new()
	r.resolve_turn(["right", "sword_slash", "guard"], ["rest", "guard", "right"])
	check(r.fighters[0].mp == Rules.START_MP - 15 + Rules.MP_REGEN, "턴이 끝나면 MP 회복")
	check(r.fighters[1].mp == mini(Rules.MAX_MP, Rules.START_MP + Rules.REST_MP + Rules.MP_REGEN), "회복은 최대치까지")


## 2칸 이동: 비용 5, 중간의 적은 뛰어넘고, 벽 앞에선 갈 수 있는 만큼만.
func _test_dash() -> void:
	var r = Rules.new()
	var ev: Array = r.resolve_turn(["dash_right", "rest", "guard"], ["rest", "guard", "right"])
	check(r.fighters[0].pos == Vector2i(2, 1), "오른쪽 2칸")
	check(ev[0].mp[0] == Rules.START_MP - 5, "2칸 이동은 MP 5 소모")
	r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	r.resolve_turn(["dash_right", "rest", "guard"], ["rest", "guard", "rest"])
	check(r.fighters[0].pos == Vector2i(3, 1), "가운데 적을 뛰어넘음")
	check(r.fighters[0].facing == -1, "넘어가면 턴 끝에 돌아섬")
	r = _setup(Vector2i(0, 1), Vector2i(3, 1))
	r.resolve_turn(["dash_up", "rest", "guard"], ["rest", "guard", "rest"])
	check(r.fighters[0].pos == Vector2i(0, 0), "위가 1칸뿐이면 1칸만")
	r = _setup(Vector2i(1, 1), Vector2i(3, 1))
	r.resolve_turn(["dash_right", "rest", "guard"], ["rest", "guard", "rest"])
	check(r.fighters[0].pos == Vector2i(1, 1), "도착 칸에 적이 있으면 제자리")


## 임시 효과음이 모두 만들어지고, 소리가 실제로 있으며(무음 아님), 찢어지지 않는지.
func _test_synth_sounds() -> void:
	for name: String in Synth.PRESETS:
		var s: AudioStreamWAV = Synth.make(name)
		var n: int = s.data.size() / 2
		var peak := 0
		for i in n:
			peak = maxi(peak, absi(s.data.decode_s16(i * 2)))
		check(n > 0 and peak > 1000, "%s: 소리가 남" % name)
		check(peak < 32767, "%s: 최대 음량 이하(클리핑 없음)" % name)


## 장면 슬롯마다 곡이 걸려 있는지(사용자가 정한 배치).
func _test_bgm_slots() -> void:
	check(BgmSynth.resolve("forest") == "folk", "숲 = 민요풍")
	check(BgmSynth.resolve("title") == "calm" and BgmSynth.resolve("map") == "calm", "타이틀·맵 = 잔잔함(같은 곡이라 이어짐)")
	check(not "birds" in BgmSynth.song_of("calm").ambient and "wind" in BgmSynth.song_of("calm").ambient, "메뉴 곡엔 새소리 없이 바람만")
	check(BgmSynth.resolve("boss") == "adventure", "보스전 = 모험")
	check(BgmSynth.resolve("cave") == "", "곡이 없는 슬롯은 무음")
	for slot: String in BgmSynth.SLOTS:
		check(BgmSynth.SONGS.has(BgmSynth.SLOTS[slot]), "%s 슬롯의 곡이 존재" % slot)


## 임시 배경음악: 마디 단위로 딱 떨어지는 길이(끊김 없는 반복), 반복 설정, 찢어짐 없음, 멜로디가 마디 수와 맞음.
func _test_bgm() -> void:
	for name: String in BgmSynth.SONGS:
		var song: Dictionary = BgmSynth.song_of(name)
		var eighths := 0
		for n: Array in song.melody:
			eighths += n[1]
		var per: int = BgmSynth.bar_eighths(song)
		check(eighths == song.chords.size() * per, "%s: 멜로디 길이가 마디 수와 맞음 (%d/%d)" % [name, eighths, song.chords.size() * per])
		var s: AudioStreamWAV = BgmSynth.make(name)
		var frames: int = s.data.size() / 2
		var expect := int(song.chords.size() * per * BgmSynth.eighth_sec(song) * BgmSynth.RATE)
		check(frames == expect and s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.loop_end == frames, "%s: 반복 재생 설정" % name)
		var peak := 0
		for i in range(0, frames, 7):
			peak = maxi(peak, absi(s.data.decode_s16(i * 2)))
		check(peak > 3000 and peak < 32767, "%s: 소리가 있고 찢어지지 않음 (peak %d)" % [name, peak])


## 2칸 이동은 플레이어와 보스만.
func _test_dash_only_players_and_bosses() -> void:
	for id in ["sword", "archer", "king_slime", "skeleton"]:
		check(Cards.hand_for(id).has("dash_right"), "%s 는 2칸 이동 가능" % id)
	for id in ["slime", "mushroom", "bat"]:
		check(not Cards.hand_for(id).has("dash_right") and Cards.hand_for(id).has("right"), "%s 는 1칸 이동만" % id)
	var r = Rules.new("sword", "slime")
	check(not r.is_valid_selection(1, ["dash_left", "rest", "guard"]), "일반 몬스터는 2칸 이동 카드를 낼 수 없음")


## 보상 카드가 전투 규칙에서 제대로 동작하는지: 손패에 더해짐, 치유, 철벽 방어, 복사본(AI 시뮬레이션) 유지.
func _test_reward_cards_in_battle() -> void:
	var r = Rules.new("sword", "slime")
	check(not r.hand(0).has("heal"), "보상 전엔 치유 카드 없음")
	r.fighters[0].extra.assign(["heal", "iron_guard", "sword_iai"])
	check(r.hand(0).has("heal") and r.hand(0).has("sword_iai"), "얻은 카드가 손패에 더해짐")
	check(r.clone().fighters[0].extra.size() == 3, "복사본도 얻은 카드 유지")
	check(r.is_valid_selection(0, ["heal", "sword_iai", "right"]), "얻은 카드로 선택 가능")
	r.fighters[0].hp = 50
	var ev: Array = r.resolve_turn(["heal", "rest", "right"], ["rest", "guard", "up"])
	check(r.fighters[0].hp == 75 and ev[0].healed[0] == 25 and ev[0].mp[0] == Rules.START_MP - 20, "치유: HP +25, MP 20 소모")
	r.fighters[0].hp = r.fighters[0].max_hp - 5
	r.resolve_turn(["heal", "rest", "right"], ["rest", "guard", "up"])
	check(r.fighters[0].hp == r.fighters[0].max_hp, "치유는 최대 HP 를 넘지 않음")
	r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	r.fighters[1].extra.assign(["iron_guard"])
	ev = r.resolve_turn(["sword_slash", "rest", "guard"], ["iron_guard", "rest", "up"])
	check(ev[0].hits[0].dmg == 0, "철벽 방어는 30까지 막음(베기 25 → 0)")


## 보상 후보·적용·초기화.
func _test_reward_progress() -> void:
	var g = GameState.new()
	g.player_char = "archer"
	g.start_single()
	var rng := RandomNumberGenerator.new()
	for seed in 20:
		rng.seed = seed
		var opts: Array = g.reward_options(rng)
		var ids := {}
		var has_card := false
		for o: Dictionary in opts:
			ids[o.id] = true
			has_card = has_card or o.kind == "card"
			if o.kind == "card":
				check(Cards.reward_cards_for("archer").has(o.id), "궁수 보상에 검사 기술이 섞이지 않음 (%s)" % o.id)
		check(opts.size() == 3 and ids.size() == 3 and has_card, "후보 3개, 중복 없음, 카드 최소 1장 (seed %d)" % seed)
	g.on_single_won(60)
	g.take_reward({"kind": "card", "id": "archer_snipe"})
	check(g.battle_config().extra_cards == ["archer_snipe"], "얻은 카드는 다음 전투로 이어짐")
	rng.seed = 1
	for o: Dictionary in g.reward_options(rng):
		check(o.id != "archer_snipe", "이미 얻은 카드는 다시 안 나옴")
	g.player_hp = 50
	g.take_reward({"kind": "instant", "id": "training"})
	check(g.player_max_hp() == 115 and g.player_hp == 65, "단련: 최대 HP +15, 그만큼 회복")
	g.take_reward({"kind": "instant", "id": "first_aid"})
	check(g.player_hp == 105, "응급 처치: HP +40")
	g.start_single()
	check(g.extra_cards.is_empty() and g.max_hp_bonus == 0, "처음부터 다시 하면 보상 초기화")
	g.free()


## 큰 그림은 부드럽게(밉맵 포함), 도트·임시 도트는 각지게. 배경 그림은 테마 이름으로 찾는다.
func _test_hires_art() -> void:
	check(not CharArt.is_smooth(CharArt.build_frames("sword")), "임시 도트는 각지게")
	var dir := ProjectSettings.globalize_path("res://art/_hires")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(dir + "/idle_2.png")
	var frames: SpriteFrames = CharArt.build_frames("_hires")
	check(CharArt.is_smooth(frames), "높이 128px 그림은 부드럽게")
	check(frames.get_frame_texture("idle", 0).get_image().has_mipmaps(), "큰 그림은 밉맵 생성")
	var cfg := ConfigFile.new()
	cfg.set_value("art", "filter", "pixel")
	cfg.save(dir + "/art.cfg")
	check(not CharArt.is_smooth(CharArt.build_frames("_hires")), "art.cfg 로 도트 강제")
	for f in ["idle_2.png", "art.cfg"]:
		DirAccess.remove_absolute(dir + "/" + f)
	DirAccess.remove_absolute(dir)

	check(CharArt.background("_nope") == null, "배경 그림이 없으면 null")
	var bg := ProjectSettings.globalize_path("res://art/bg")
	var made_dir := not DirAccess.dir_exists_absolute(bg)
	DirAccess.make_dir_recursive_absolute(bg)
	img.save_png(bg + "/_testtheme.png")
	check(CharArt.background("_testtheme") != null, "art/bg/<테마>.png 를 찾음")
	DirAccess.remove_absolute(bg + "/_testtheme.png")
	if made_dir:
		DirAccess.remove_absolute(bg)
