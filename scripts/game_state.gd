extends Node
## 화면(장면)을 넘나드는 진행 상태. 오토로드 "Game" 으로 등록돼 있다.
## 전투 장면은 여기 모드가 비어 있으면 기본 대전(검사 vs 궁수)으로 시작한다 —
## 에디터에서 battle.tscn 을 F6 으로 바로 실행해 메뉴를 건너뛸 수 있게 하려는 것.

const Cards := preload("res://scripts/cards.gd")
const Rules := preload("res://scripts/game_rules.gd")

const TITLE_SCENE := "res://title.tscn"
const SELECT_SCENE := "res://char_select.tscn"
const MAP_SCENE := "res://stage_map.tscn"
const BATTLE_SCENE := "res://battle.tscn"

const PLAYABLE := ["sword", "archer"]
# 스테이지 사이 회복량. 회복 없이 HP 만 이어지면 보스 전에 거의 빈사가 돼서, 휴식 칸이 생기기 전까지의 임시 완충.
# 장(chapter)을 넘어가면 전부 회복한다.
const HEAL_BETWEEN := 30
# 장마다 마지막 스테이지가 그 장의 보스. 장을 추가하면 2-1, 2-2… 로 자동으로 이어진다.
# theme 은 전투 배경(themes.gd). waves 는 스테이지 안의 전투 목록이고, 한 wave 안의 적들은 동시에 나온다.
# wave 가 여럿이면 연속전(HP 회복 없이 이어 싸움).
# hp 를 적으면 그 스테이지에서만 몬스터 체력을 바꾼다 — 같은 몬스터를 뒤쪽 장에서 더 단단하게 재사용하려고.
# 3장(해안가, theme "coast")은 배경만 준비돼 있고 몬스터가 생기면 여기 추가한다
const CHAPTERS := [
	{"name": "초록 숲", "theme": "forest", "stages": [
		{"name": "숲 입구", "waves": [[{"id": "slime", "hp": 20}]]},
		{"name": "버섯 군락", "waves": [[{"id": "slime", "hp": 20}, {"id": "mushroom", "hp": 20}]]},
		{"name": "킹슬라임의 둥지", "boss": true, "waves": [[{"id": "king_slime"}]]},
	]},
	{"name": "망령의 동굴", "theme": "cave", "stages": [
		{"name": "습한 동굴", "waves": [[{"id": "bat"}]]},
		{"name": "박쥐 굴", "waves": [[{"id": "bat"}, {"id": "slime", "hp": 45}]]},
		{"name": "무사의 무덤", "boss": true, "waves": [[{"id": "skeleton"}]]},
	]},
]
const VERSUS_THEME := "forest"
const PRACTICE_TARGET := "slime"  # 기술 체험의 기본 연습 상대

var mode := ""  # "single" | "versus" | "practice"(기술 체험) | "" (전투 장면을 바로 실행)
var practice_target := PRACTICE_TARGET  # 기술 체험에서 고른 연습 상대(다시 들어와도 유지)
var mode_before_practice := ""  # 기술 체험에서 캐릭터 선택으로 돌아갈 때 원래 모드(싱글/대전)로 되돌리려고
var player_char := "sword"
var chapter := 0
var stage := 0  # 장 안에서의 순서
var wave := 0  # 스테이지 안 연속전에서 몇 번째 전투인지
var player_hp := -1  # -1 이면 최대 HP 로 시작
var extra_cards: Array[String] = []  # 이번 던전에서 보상으로 얻은 카드
var max_hp_bonus := 0  # 보상 "단련"으로 늘어난 최대 HP

# 카드가 아닌 즉시 보상. 카드 보상과 함께 후보로 섞여 나온다
const INSTANT_REWARDS := {
	"first_aid": {"name": "응급 처치", "desc": "HP 40 회복", "heal": 40},
	"training": {"name": "단련", "desc": "최대 HP +15", "max_hp": 15},
}
const REWARD_CHOICES := 3


func _ready() -> void:
	_handle_ui_shot()


static func max_hp(char_id: String) -> int:
	return Cards.CHARACTERS[char_id].get("hp", Rules.MAX_HP)


static func stage_code(c: int, s: int) -> String:
	return "%d-%d" % [c + 1, s + 1]


func start_single(from_chapter := 0, from_stage := 0) -> void:
	mode = "single"
	chapter = clampi(from_chapter, 0, CHAPTERS.size() - 1)
	stage = clampi(from_stage, 0, CHAPTERS[chapter].stages.size() - 1)
	wave = 0
	player_hp = -1
	extra_cards.clear()
	max_hp_bonus = 0


func start_versus() -> void:
	mode = "versus"


## 기술 체험: 그 캐릭터의 모든 기술(보상 기술 포함)을 MP·HP 걱정 없이 하나씩 써 보는 연습장.
## 플레이어용 둘러보기이자, 개발할 때 새 기술의 모션·이펙트를 1·3인칭으로 바로 확인하는 곳.
func start_practice(char_id: String) -> void:
	if mode != "practice":
		mode_before_practice = mode
	mode = "practice"
	player_char = char_id
	goto_battle()


## 연습 상대로 고를 수 있는 캐릭터: 내 캐릭터를 뺀 전부(몬스터·보스·다른 플레이 캐릭터), cards.gd 순서대로.
## 보스의 크기·피격 연출이나 큰 몸에 1인칭 카메라가 어떻게 보이는지도 여기서 확인한다.
func practice_targets() -> Array[String]:
	var out: Array[String] = []
	for id: String in Cards.CHARACTERS:
		if id != player_char:
			out.append(id)
	return out


func end_practice() -> void:
	mode = mode_before_practice if mode_before_practice != "" else "single"
	goto_select()


func player_max_hp() -> int:
	return max_hp(player_char) + (max_hp_bonus if mode == "single" else 0)


func is_cleared() -> bool:
	return mode == "single" and chapter >= CHAPTERS.size()


func current_chapter() -> Dictionary:
	return CHAPTERS[mini(chapter, CHAPTERS.size() - 1)]


func current_stage() -> Dictionary:
	if mode != "single" or is_cleared():
		return {}
	return CHAPTERS[chapter].stages[stage]


## 지금 전투에 동시에 나오는 적들.
func current_group() -> Array:
	var st := current_stage()
	return st.waves[mini(wave, st.waves.size() - 1)] if not st.is_empty() else []


func has_next_wave() -> bool:
	var st := current_stage()
	return not st.is_empty() and wave < st.waves.size() - 1


## 스테이지에 나오는 모든 적(맵 표시용).
static func stage_enemies(st: Dictionary) -> Array:
	var out := []
	for group: Array in st.waves:
		out.append_array(group)
	return out


func is_final_stage() -> bool:
	return chapter == CHAPTERS.size() - 1 and stage == CHAPTERS[chapter].stages.size() - 1 and not has_next_wave()


## 스테이지 데이터의 hp 덮어쓰기가 있으면 그 값, 없으면 캐릭터 기본 HP.
static func enemy_hp(enemy: Dictionary) -> int:
	return enemy.get("hp", max_hp(enemy.id))


## 대전 상대는 내가 고르지 않은 쪽 캐릭터.
func versus_enemy() -> String:
	for c: String in PLAYABLE:
		if c != player_char:
			return c
	return player_char


## 전투 장면이 시작할 때 읽는 설정.
func battle_config() -> Dictionary:
	if mode == "single" and not is_cleared():
		var ids := []
		var hps := []
		for e: Dictionary in current_group():
			ids.append(e.id)
			hps.append(enemy_hp(e))
		return {"player": player_char, "enemies": ids, "enemy_hp": hps, "player_hp": player_hp,
			"theme": current_chapter().theme, "extra_cards": extra_cards, "max_hp_bonus": max_hp_bonus}
	if mode == "practice":
		# 상대는 아무것도 하지 않는 연습 상대. HP 는 넉넉하게(battle.gd 가 행동마다 다시 채운다)
		if not practice_targets().has(practice_target):
			practice_target = PRACTICE_TARGET
		return {"player": player_char, "enemies": [practice_target], "enemy_hp": [999], "player_hp": -1,
			"theme": VERSUS_THEME, "extra_cards": Cards.reward_cards_for(player_char), "max_hp_bonus": 0}
	return {"player": player_char, "enemies": [versus_enemy()], "enemy_hp": [-1], "player_hp": -1, "theme": VERSUS_THEME,
		"extra_cards": [], "max_hp_bonus": 0}


## 이긴 뒤 진행. 연속전이 남았으면 같은 스테이지의 다음 적(회복 없음), 아니면 다음 스테이지로.
func on_single_won(hp_left: int) -> void:
	if has_next_wave():
		wave += 1
		player_hp = hp_left
		return
	wave = 0
	stage += 1
	if stage >= CHAPTERS[chapter].stages.size():
		chapter += 1
		stage = 0
		player_hp = -1
	else:
		player_hp = mini(hp_left + HEAL_BETWEEN, player_max_hp())


## 스테이지 보상 후보 3개. 아직 없는 카드(내 기술 + 공용)와 즉시 보상을 섞어 뽑는다.
## 카드 후보가 남아 있으면 최소 한 장은 카드가 나오게 한다 — 즉시 보상만 나오면 덱이 자라는 재미가 없다.
## 반환: [{kind: "card"|"instant", id, name, desc}]
func reward_options(rng: RandomNumberGenerator) -> Array:
	var cards := []
	for id in Cards.reward_cards_for(player_char):
		if not extra_cards.has(id):
			cards.append(id)
	var pool := []
	for id in cards:
		pool.append(_card_option(id))
	for id: String in INSTANT_REWARDS:
		pool.append({"kind": "instant", "id": id, "name": INSTANT_REWARDS[id].name, "desc": INSTANT_REWARDS[id].desc})
	var out := []
	if not cards.is_empty():
		var first: Dictionary = _card_option(cards[rng.randi_range(0, cards.size() - 1)])
		out.append(first)
		pool = pool.filter(func(o: Dictionary) -> bool: return o.id != first.id)
	while out.size() < REWARD_CHOICES and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func _card_option(id: String) -> Dictionary:
	var c: Dictionary = Cards.get_card(id)
	var desc := ""
	match c.type:
		"attack":
			desc = "새 기술 · 피해 %d · MP %d" % [c.dmg, c.cost]
		"heal":
			desc = "카드 · HP +%d · MP %d" % [c.heal, c.cost]
		"guard":
			desc = "카드 · 받는 피해 -%d · MP %d" % [c.block, c.cost]
	return {"kind": "card", "id": id, "name": c.name, "desc": desc}


## 고른 보상을 적용한다. 스테이지를 넘긴 뒤(on_single_won 다음)에 부른다 — HP 회복이 넘어갈 때의 회복과 겹쳐도 최대치를 넘지 않게.
func take_reward(opt: Dictionary) -> void:
	if opt.kind == "card":
		extra_cards.append(opt.id)
		return
	var r: Dictionary = INSTANT_REWARDS[opt.id]
	var cur := player_hp if player_hp >= 0 else player_max_hp()
	if r.has("max_hp"):
		max_hp_bonus += r.max_hp
		cur += r.max_hp
	if r.has("heal"):
		cur += r.heal
	player_hp = mini(cur, player_max_hp())


func goto_title() -> void:
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


func goto_select() -> void:
	get_tree().change_scene_to_file.call_deferred(SELECT_SCENE)


func goto_map() -> void:
	get_tree().change_scene_to_file.call_deferred(MAP_SCENE)


func goto_battle() -> void:
	get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE)


## 캐릭터를 고른 뒤 모드에 맞는 다음 화면으로.
func choose_character(char_id: String) -> void:
	player_char = char_id
	if mode == "single":
		start_single()
		goto_map()
	else:
		goto_battle()


## 개발용: 타이틀에서 메뉴를 건너뛴다. 처리했으면 true.
##   -- --char=archer   플레이 캐릭터 (기본 검사, 아래 옵션과 함께)
##   -- --stage=1-3     싱글 해당 스테이지 전투로 바로 ("3" 처럼 숫자만 쓰면 1장)
##   -- --wave=2        (--stage 와 함께) 연속전의 N번째 적부터
##   -- --extra=heal,sword_iai  (--stage 와 함께) 보상 카드를 얻은 상태로
##   -- --map           싱글 스테이지 맵으로 바로
##   -- --versus        AI 대전으로 바로
##   -- --practice      기술 체험으로 바로(--char 와 함께, --target=king_slime 으로 연습 상대)
func handle_skip_args() -> bool:
	var args := OS.get_cmdline_user_args()
	var extra := []
	for a in args:
		if a.begins_with("--char="):
			player_char = a.substr(7)
		elif a.begins_with("--target="):
			practice_target = a.substr(9)
		elif a.begins_with("--extra="):
			extra = Array(a.substr(8).split(","))  # 보상 카드를 미리 얻은 상태로 시작(개발용)
	for a in args:
		if a.begins_with("--stage="):
			var code := a.substr(8).split("-")
			if code.size() == 2:
				start_single(int(code[0]) - 1, int(code[1]) - 1)
			else:
				start_single(0, int(code[0]) - 1)
			extra_cards.assign(extra)
			for w in args:
				if w.begins_with("--wave="):
					wave = clampi(int(w.substr(7)) - 1, 0, current_stage().waves.size() - 1)
			goto_battle()
			return true
		if a == "--map":
			start_single()
			goto_map()
			return true
		if a == "--versus":
			start_versus()
			goto_battle()
			return true
		if a == "--practice":
			start_practice(player_char)
			return true
	return false


## 개발용: `-- --uishot=경로.png` 면 1초 뒤 화면을 저장하고 종료(타이틀·맵 같은 메뉴 화면 확인용).
func _handle_ui_shot() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uishot="):
			path = a.substr(9)
	if path == "":
		return
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
