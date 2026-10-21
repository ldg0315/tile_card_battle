extends RefCounted
## 카드 정의.
## 이동의 dir 은 화면(보드) 기준 칸 수다(x+ = 오른쪽, y+ = 아래).
## 공격의 range 는 "상대좌표"(x = 앞쪽으로 몇 칸, y = 행 차이)라 실제 칸은 캐릭터의 facing 을 곱해 계산한다 —
## 캐릭터가 왼쪽/오른쪽 어디에 서 있든 공격 정의는 하나만 둔다.
## anim 은 화면 연출 종류(battle.gd 의 _attack_anim)다. 규칙은 읽지 않는다 — 새 스킬은 기존 연출을 골라 재사용하면 된다.

const COMMON := {
	# 이동은 화면(보드) 기준 방향이다. 몸이 향한 쪽 기준이면, 적을 넘어간 뒤 돌아서는 순간 "앞"이 바뀌어
	# 같은 카드가 반대로 움직이는 혼동이 생겼다. 공격만 바라보는 쪽 기준(뒤잡기는 그대로).
	"left": {"name": "← 왼쪽", "type": "move", "dir": Vector2i(-1, 0), "cost": 0},
	"up": {"name": "↑ 위", "type": "move", "dir": Vector2i(0, -1), "cost": 0},
	"down": {"name": "↓ 아래", "type": "move", "dir": Vector2i(0, 1), "cost": 0},
	"right": {"name": "→ 오른쪽", "type": "move", "dir": Vector2i(1, 0), "cost": 0},
	# 2칸 이동(질주). 중간 칸의 적은 뛰어넘고, 벽에 막히면 갈 수 있는 만큼만 간다(game_rules.move_target)
	"dash_left": {"name": "← 2칸", "type": "move", "dir": Vector2i(-2, 0), "cost": 5},
	"dash_up": {"name": "↑ 2칸", "type": "move", "dir": Vector2i(0, -2), "cost": 5},
	"dash_down": {"name": "↓ 2칸", "type": "move", "dir": Vector2i(0, 2), "cost": 5},
	"dash_right": {"name": "→ 2칸", "type": "move", "dir": Vector2i(2, 0), "cost": 5},
	"guard": {"name": "방어", "type": "guard", "cost": 0},
	"rest": {"name": "기 모으기", "type": "rest", "cost": 0},
}

const CHARACTERS := {
	"sword": {
		"name": "검사",
		"body": Color(0.85, 0.22, 0.2),
		"attacks": {
			"sword_slash": {"name": "베기", "anim": "lunge", "type": "attack", "cost": 15, "dmg": 25,
				"range": [Vector2i(1, 0)]},
			"sword_spin": {"name": "회전베기", "anim": "spin", "type": "attack", "cost": 25, "dmg": 15,
				"range": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
					Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]},
			"sword_thrust": {"name": "찌르기", "anim": "thrust", "type": "attack", "cost": 30, "dmg": 30,
				"range": [Vector2i(1, 0), Vector2i(2, 0)]},
		},
	},
	"archer": {
		"name": "궁수",
		"body": Color(0.2, 0.55, 0.9),
		"attacks": {
			"archer_arrow": {"name": "화살", "anim": "arrow", "type": "attack", "cost": 15, "dmg": 20,
				"range": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
			"archer_volley": {"name": "화살비", "anim": "volley", "type": "attack", "cost": 25, "dmg": 20,
				"range": [Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)]},
			"archer_kick": {"name": "발차기", "anim": "lunge", "type": "attack", "cost": 5, "dmg": 10,
				"range": [Vector2i(1, 0)]},
		},
	},
	# ---- 싱글 플레이 몬스터. hp 를 생략하면 MAX_HP, scale 은 화면에서의 키 배율
	"slime": {
		"name": "슬라임",
		"dash": false,  # 2칸 이동은 플레이어와 보스만 — 일반 몬스터까지 뛰어다니면 판이 산만하다
		"hp": 60,
		"attacks": {
			"slime_tackle": {"name": "몸통박치기", "anim": "lunge", "type": "attack", "cost": 10, "dmg": 15,
				"range": [Vector2i(1, 0)]},
			"slime_splash": {"name": "산성 튀기기", "anim": "spin", "type": "attack", "cost": 20, "dmg": 10,
				"range": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
					Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]},
		},
	},
	"mushroom": {
		"name": "독버섯",
		"dash": false,  # 2칸 이동은 플레이어와 보스만 — 일반 몬스터까지 뛰어다니면 판이 산만하다
		"hp": 30,
		"attacks": {
			"mush_bonk": {"name": "박치기", "anim": "lunge", "type": "attack", "cost": 5, "dmg": 8,
				"range": [Vector2i(1, 0)]},
			"mush_spore": {"name": "독포자", "anim": "spin", "type": "attack", "cost": 15, "dmg": 6,
				"range": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
					Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]},
			"mush_puff": {"name": "포자 뿜기", "anim": "wave", "type": "attack", "cost": 10, "dmg": 7,
				"range": [Vector2i(1, 0), Vector2i(2, 0)]},
		},
	},
	"king_slime": {
		"name": "킹슬라임",
		"hp": 80,
		"scale": 1.6,
		"attacks": {
			"king_tackle": {"name": "몸통박치기", "anim": "lunge", "type": "attack", "cost": 10, "dmg": 15,
				"range": [Vector2i(1, 0)]},
			"king_splash": {"name": "점액 튀기기", "anim": "spin", "type": "attack", "cost": 20, "dmg": 10,
				"range": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
					Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]},
			# 패턴 전용 대기술. 자기 위아래와 앞 2열을 덮지만 등 뒤는 비어 있다 — 뒤로 돌아가는 게 정답
			"king_crush": {"name": "대점프 압살", "anim": "jump", "type": "attack", "cost": 0, "dmg": 25,
				"pattern_only": true,
				"range": [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
					Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)]},
		},
		"phases": [
			{"until_hp": 0.5, "pattern": [
				{"cards": "ai"},
				{"cards": "ai"},
				{"cards": ["rest", "guard", "rest"], "warn": "킹슬라임이 몸을 크게 부풀린다… 다음 턴 [대점프 압살]!"},
				{"cards": ["king_crush", "ai", "ai"]},
			]},
			{"enter": "킹슬라임이 끓어오른다! 압살이 잦아진다.", "pattern": [
				{"cards": ["guard", "rest", "ai"], "warn": "킹슬라임이 다시 부풀어 오른다… 다음 턴 [대점프 압살]!"},
				{"cards": ["king_crush", "ai", "ai"]},
				{"cards": "ai"},
			]},
		],
	},
	"bat": {
		"name": "박쥐",
		"dash": false,  # 2칸 이동은 플레이어와 보스만 — 일반 몬스터까지 뛰어다니면 판이 산만하다
		"hp": 50,
		"attacks": {
			"bat_bite": {"name": "물기", "anim": "lunge", "type": "attack", "cost": 5, "dmg": 12,
				"range": [Vector2i(1, 0)]},
			"bat_sonic": {"name": "초음파", "anim": "wave", "type": "attack", "cost": 15, "dmg": 10,
				"range": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
			"bat_dive": {"name": "급강하", "anim": "thrust", "type": "attack", "cost": 20, "dmg": 18,
				"range": [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]},
		},
	},
	"skeleton": {
		"name": "해골 무사",
		"hp": 140,
		"scale": 1.25,
		"attacks": {
			"skel_slash": {"name": "베기", "anim": "lunge", "type": "attack", "cost": 15, "dmg": 25,
				"range": [Vector2i(1, 0)]},
			"skel_whirl": {"name": "대회전", "anim": "spin", "type": "attack", "cost": 30, "dmg": 20,
				"range": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
					Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]},
			"skel_charge": {"name": "돌진찌르기", "anim": "thrust", "type": "attack", "cost": 35, "dmg": 30,
				"range": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
			# 패턴 전용 대기술 — AI 가 아무 때나 고르지 못하고 boss_plan 이 정한 턴에만 나온다
			"skel_storm": {"name": "망령 참격", "anim": "thrust", "type": "attack", "cost": 0, "dmg": 35,
				"pattern_only": true,
				"range": [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)]},
		},
		# 보스 패턴(boss_plan.gd). HP 비율이 until_hp 보다 높은 동안 그 페이즈.
		# cards 의 "ai" 칸은 AI 가 채운다. 예고 턴에 방어·기 모으기만 하는 건 일부러 만든 반격 기회
		"phases": [
			{"until_hp": 0.5, "pattern": [
				{"cards": "ai"},
				{"cards": "ai"},
				{"cards": ["guard", "rest", "rest"], "warn": "해골 무사가 칼에 망령을 모은다… 다음 턴 대기술 [망령 참격]!"},
				{"cards": ["skel_storm", "ai", "ai"]},
			]},
			{"enter": "해골 무사가 분노했다! 대기술이 잦아진다.", "pattern": [
				{"cards": ["rest", "guard", "ai"], "warn": "분노한 해골 무사가 망령을 모은다… 다음 턴 [망령 참격]!"},
				{"cards": ["skel_storm", "ai", "ai"]},
				{"cards": "ai"},
			]},
		],
	},
}


# 스테이지 보상으로만 얻는 카드. 캐릭터별 기술 + 공용(아무 캐릭터나).
# 얻은 카드는 그 던전을 도는 동안 손패에 더해진다(Game.extra_cards → Fighter.extra).
const REWARDS := {
	"sword": {
		"sword_cross": {"name": "십자베기", "anim": "lunge", "type": "attack", "cost": 20, "dmg": 20,
			"range": [Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]},
		"sword_iai": {"name": "발도술", "anim": "thrust", "type": "attack", "cost": 40, "dmg": 45,
			"range": [Vector2i(1, 0)]},
		"sword_rush": {"name": "돌진베기", "anim": "thrust", "type": "attack", "cost": 25, "dmg": 20,
			"range": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	},
	"archer": {
		"archer_pierce": {"name": "관통 화살", "anim": "arrow", "type": "attack", "cost": 25, "dmg": 28,
			"range": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
		"archer_spread": {"name": "산탄 화살", "anim": "volley", "type": "attack", "cost": 20, "dmg": 15,
			"range": [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)]},
		"archer_snipe": {"name": "저격", "anim": "arrow", "type": "attack", "cost": 35, "dmg": 45,
			"range": [Vector2i(3, 0)]},
	},
	"common": {
		"heal": {"name": "치유", "type": "heal", "cost": 20, "heal": 25},
		"iron_guard": {"name": "철벽 방어", "type": "guard", "cost": 10, "block": 30},
	},
}


static func get_card(id: String) -> Dictionary:
	if COMMON.has(id):
		return COMMON[id]
	for c: Dictionary in CHARACTERS.values():
		if c.attacks.has(id):
			return c.attacks[id]
	for group: Dictionary in REWARDS.values():
		if group.has(id):
			return group[id]
	return {}


## 이 캐릭터가 보상으로 얻을 수 있는 카드(자기 기술 + 공용).
static func reward_cards_for(char_id: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(REWARDS.get(char_id, {}).keys())
	out.append_array(REWARDS.common.keys())
	return out


## 공통 카드 + 캐릭터 고유 공격. 손패는 매 턴 전부 열려 있고 그중 3장을 고른다.
## "dash": false 인 캐릭터(일반 몬스터)는 2칸 이동 카드를 받지 않는다.
static func hand_for(char_id: String) -> Array[String]:
	var hand: Array[String] = []
	var can_dash: bool = CHARACTERS[char_id].get("dash", true)
	for id: String in COMMON:
		if can_dash or not id.begins_with("dash_"):
			hand.append(id)
	for id: String in CHARACTERS[char_id].attacks.keys():
		hand.append(id)
	return hand
