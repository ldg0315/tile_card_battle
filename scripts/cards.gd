extends RefCounted
## 카드 정의.
## 이동의 dir 과 공격의 range 는 모두 "상대좌표"(x = 앞쪽으로 몇 칸, y = 행 차이)다.
## 실제 칸은 캐릭터의 facing 을 곱해 계산하므로, 캐릭터가 왼쪽/오른쪽 어디에 서 있든 정의는 하나만 둔다.

const COMMON := {
	"up": {"name": "위로", "type": "move", "dir": Vector2i(0, -1), "cost": 0},
	"down": {"name": "아래로", "type": "move", "dir": Vector2i(0, 1), "cost": 0},
	"fwd": {"name": "앞으로", "type": "move", "dir": Vector2i(1, 0), "cost": 0},
	"back": {"name": "뒤로", "type": "move", "dir": Vector2i(-1, 0), "cost": 0},
	"guard": {"name": "방어", "type": "guard", "cost": 0},
	"rest": {"name": "기 모으기", "type": "rest", "cost": 0},
}

const CHARACTERS := {
	"sword": {
		"name": "검사",
		"body": Color(0.85, 0.22, 0.2),
		"attacks": {
			"sword_slash": {"name": "베기", "type": "attack", "cost": 15, "dmg": 25,
				"range": [Vector2i(1, 0)]},
			"sword_spin": {"name": "회전베기", "type": "attack", "cost": 25, "dmg": 15,
				"range": [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
					Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]},
			"sword_thrust": {"name": "찌르기", "type": "attack", "cost": 30, "dmg": 30,
				"range": [Vector2i(1, 0), Vector2i(2, 0)]},
		},
	},
	"archer": {
		"name": "궁수",
		"body": Color(0.2, 0.55, 0.9),
		"attacks": {
			"archer_arrow": {"name": "화살", "type": "attack", "cost": 15, "dmg": 20,
				"range": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
			"archer_volley": {"name": "화살비", "type": "attack", "cost": 25, "dmg": 20,
				"range": [Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)]},
			"archer_kick": {"name": "발차기", "type": "attack", "cost": 5, "dmg": 10,
				"range": [Vector2i(1, 0)]},
		},
	},
}


static func get_card(id: String) -> Dictionary:
	if COMMON.has(id):
		return COMMON[id]
	for c: Dictionary in CHARACTERS.values():
		if c.attacks.has(id):
			return c.attacks[id]
	return {}


## 공통 카드 + 캐릭터 고유 공격. 손패는 매 턴 전부 열려 있고 그중 3장을 고른다.
static func hand_for(char_id: String) -> Array[String]:
	var hand: Array[String] = []
	hand.assign(COMMON.keys())
	for id: String in CHARACTERS[char_id].attacks.keys():
		hand.append(id)
	return hand
