extends RefCounted
## 화면과 분리된 순수 규칙.
## 3인칭/1인칭은 이 상태를 다른 카메라로 보는 것뿐이라, 여기에 Node 를 참조하는 코드가 들어오면
## 시점을 추가할 때 규칙까지 다시 짜야 한다.
## 전투원은 여럿일 수 있다: 0번이 플레이어(team 0), 1번부터가 적(team 1). 1대1 은 적이 하나인 경우일 뿐.

const Cards := preload("res://scripts/cards.gd")

const ROWS := 3
const COLS := 4
const MAX_HP := 100
const MAX_MP := 100
const START_MP := 100  # 첫 턴부터 강한 카드를 섞어 쓸 수 있게 가득 찬 채로 시작
const REST_MP := 25
const MP_REGEN := 10  # 턴이 끝날 때마다 회복. 없으면 MP 가 바닥난 뒤 기 모으기만 반복하는 턴이 길어진다
const GUARD_BLOCK := 15
const CARDS_PER_TURN := 3
# 적 수 → 시작 행. 여럿이면 오른쪽 끝 열에 위아래로 벌려 세워, 처음부터 한 줄로 겹치지 않게
const ENEMY_ROWS := {1: [1], 2: [0, 2], 3: [0, 1, 2]}


class Fighter:
	var char_id: String
	var team := 0
	var pos: Vector2i  # x = 열(0~3), y = 행(0~2, 0 이 화면 위쪽)
	var facing: int  # +1 이면 열이 커지는 쪽이 "앞"
	var max_hp := MAX_HP  # 몬스터는 캐릭터마다 다르다(cards.gd 의 hp)
	var hp := MAX_HP
	var mp := START_MP
	var extra: Array[String] = []  # 스테이지 보상으로 얻어 손패에 더해진 카드

	func alive() -> bool:
		return hp > 0

	func copy() -> Fighter:
		var f := Fighter.new()
		f.char_id = char_id
		f.team = team
		f.max_hp = max_hp
		f.pos = pos
		f.facing = facing
		f.hp = hp
		f.mp = mp
		f.extra = extra.duplicate()
		return f


var fighters: Array[Fighter] = []
var winner := -1  # -1 진행 중, 0 플레이어 승, 1 적 승, 2 무승부


## enemies: 적 캐릭터 id 하나(String) 또는 여럿(Array, 최대 3).
func _init(char0 := "sword", enemies = "archer") -> void:
	var list: Array = enemies if enemies is Array else [enemies]
	fighters = [_make(char0, 0, Vector2i(0, 1), 1)]
	var rows: Array = ENEMY_ROWS.get(list.size(), [0, 1, 2])
	for k in list.size():
		fighters.append(_make(list[k], 1, Vector2i(COLS - 1, rows[k]), -1))


func _make(char_id: String, team: int, pos: Vector2i, facing: int) -> Fighter:
	var f := Fighter.new()
	f.char_id = char_id
	f.team = team
	f.pos = pos
	f.facing = facing
	f.max_hp = Cards.CHARACTERS[char_id].get("hp", MAX_HP)
	f.hp = f.max_hp
	return f


## AI 가 수를 시뮬레이션할 때 원본을 건드리지 않도록 쓰는 복사본.
func clone():
	var c = get_script().new(fighters[0].char_id, [])
	c.fighters.clear()
	for f in fighters:
		c.fighters.append(f.copy())
	c.winner = winner
	return c


static func in_board(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < COLS and t.y >= 0 and t.y < ROWS


func hand(idx: int) -> Array[String]:
	var h := Cards.hand_for(fighters[idx].char_id)
	for id in fighters[idx].extra:
		if not h.has(id):
			h.append(id)
	return h


## idx 의 적(다른 팀) 중 살아 있는 전투원 번호.
func foes_of(idx: int) -> Array[int]:
	var out: Array[int] = []
	for j in fighters.size():
		if fighters[j].team != fighters[idx].team and fighters[j].alive():
			out.append(j)
	return out


func cost_of(cards: Array) -> int:
	var total := 0
	for id: String in cards:
		total += int(Cards.get_card(id).cost)
	return total


## 같은 카드 중복 금지, 비용 합계는 "턴 시작 시 MP" 이하.
## 턴 중간의 기 모으기를 비용에 미리 반영하지 않는 이유: 그러면 MP 부족으로 카드가 헛도는 경우가 생겨
## 왜 공격이 안 나갔는지 플레이어가 이해하기 어렵다.
func is_valid_selection(idx: int, cards: Array) -> bool:
	if cards.size() != CARDS_PER_TURN:
		return false
	var h := hand(idx)
	var seen := {}
	for id: String in cards:
		if not h.has(id) or seen.has(id):
			return false
		seen[id] = true
	return cost_of(cards) <= fighters[idx].mp and first_dead_move(idx, cards) == -1


## 고른 순서대로 이동했을 때 보드 밖이라 한 칸도 못 가는 이동 카드의 순번(없으면 -1).
## 전투원끼리는 막지 않으니 내 이동 결과는 벽과 내 카드만으로 정해진다 → 고를 때 미리 막을 수 있다.
## 2칸 이동은 1칸이라도 가면 괜찮다(갈 수 있는 만큼 간다).
func first_dead_move(idx: int, cards: Array) -> int:
	var f := fighters[idx].copy()
	for k in cards.size():
		var c: Dictionary = Cards.get_card(cards[k])
		if c.get("type", "") != "move":
			continue
		var t := move_target(f, c.dir)
		if t == f.pos:
			return k
		f.pos = t
	return -1


## 이동 카드의 도착 칸. dir 은 화면(보드) 기준이라 바라보는 방향과 무관하다. 2칸 이동은 중간 칸을 따지지 않고 뛰어넘으며,
## 보드 밖이면 한 칸씩 줄여 갈 수 있는 만큼만 간다(질주 카드가 벽 앞에서 통째로 헛도는 건 손해가 너무 커서).
## 다른 전투원은 막지 않는다 — 같은 칸에 함께 설 수 있고, 지나가거나 자리를 맞바꿀 수도 있다.
static func move_target(f: Fighter, dir: Vector2i) -> Vector2i:
	var steps := maxi(absi(dir.x), absi(dir.y))
	var unit := Vector2i(signi(dir.x), signi(dir.y))
	for k in range(steps, 0, -1):
		var cand := f.pos + unit * k
		if in_board(cand):
			return cand
	return f.pos


func attack_tiles(f: Fighter, card: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off: Vector2i in card.range:
		var t := Vector2i(f.pos.x + off.x * f.facing, f.pos.y + off.y)
		if in_board(t):
			out.append(t)
	return out


## 한 턴을 처리하고 단계별 이벤트를 돌려준다. 화면은 이 이벤트만 보고 연출한다.
## 부르는 법: resolve_turn([전투원0 카드3장, 전투원1 카드3장, …]) — 1대1 은 resolve_turn(내 카드, 적 카드) 도 된다.
func resolve_turn(a: Array, b: Array = []) -> Array[Dictionary]:
	var plans: Array = a if b.is_empty() and not a.is_empty() and a[0] is Array else [a, b]
	var events: Array[Dictionary] = []
	for step in CARDS_PER_TURN:
		if winner != -1:
			break
		var ids := []
		for i in fighters.size():
			var plan: Array = plans[i] if i < plans.size() else []
			ids.append(plan[step] if fighters[i].alive() and step < plan.size() else "")
		events.append(_resolve_step(ids))
	_update_facing()
	for f in fighters:
		if f.alive():
			f.mp = mini(MAX_MP, f.mp + MP_REGEN)
	return events


static func _filled(n: int, v) -> Array:
	var arr := []
	arr.resize(n)
	arr.fill(v)
	return arr


func _resolve_step(ids: Array) -> Dictionary:
	var n := fighters.size()
	var cards := []
	for i in n:
		cards.append(Cards.get_card(ids[i]) if ids[i] != "" else {})
	var ev := {"cards": ids, "hits": [], "fizzled": _filled(n, false), "guarding": _filled(n, false), "died": [],
		"healed": _filled(n, 0)}
	var block_of := _filled(n, 0)  # 이번 단계 방어량(철벽 방어는 더 많이 막는다)

	# 1) 이동을 공격보다 먼저 처리한다 — 같은 단계에서 "피하는" 카드가 의미를 가지려면 이동이 선행해야 한다.
	#    전투원끼리는 막지 않는다(같은 칸 허용). 막는 규칙은 "왜 안 움직였나"를 읽기 어렵게 만들었다
	for i in n:
		if cards[i].get("type", "") == "move":
			# 이동도 비용이 있으면(2칸 이동) 여기서 낸다. 모자라면 공격과 같이 헛돈다
			var cost := int(cards[i].cost)
			if fighters[i].mp < cost:
				ev.fizzled[i] = true
				continue
			fighters[i].mp -= cost
			fighters[i].pos = move_target(fighters[i], cards[i].dir)
	# 방향은 턴 도중에 바꾸지 않는다(턴 끝에만 _update_facing). 공격은 바라보는 쪽으로 나가니,
	# 턴 중에 돌아서면 카드를 고를 때 본 범위와 실제 범위가 달라진다 — 특히 적이 넘어가는 경우는 미리 알 수도 없다

	# 2) 방어·기 모으기·치유
	for i in n:
		var type: String = cards[i].get("type", "")
		if type in ["guard", "heal"]:
			var cost := int(cards[i].get("cost", 0))
			if fighters[i].mp < cost:
				ev.fizzled[i] = true
				continue
			fighters[i].mp -= cost
		match type:
			"guard":
				ev.guarding[i] = true
				block_of[i] = int(cards[i].get("block", GUARD_BLOCK))
			"rest":
				fighters[i].mp = mini(MAX_MP, fighters[i].mp + REST_MP)
			"heal":
				var before := fighters[i].hp
				fighters[i].hp = mini(fighters[i].max_hp, fighters[i].hp + int(cards[i].heal))
				ev.healed[i] = fighters[i].hp - before

	# 3) 공격은 동시 판정. 데미지를 모았다가 마지막에 적용해야
	#    같은 단계에서 먼저 처리된 쪽 때문에 상대 공격이 사라지는 일이 없다(맞교환 → 무승부 가능).
	#    범위 안의 적은 전부 맞는다 — 둘이 붙어 있으면 범위 공격 한 번에 둘 다.
	var dmg := _filled(n, 0)
	for i in n:
		if cards[i].get("type", "") != "attack":
			continue
		var f := fighters[i]
		if f.mp < int(cards[i].cost):
			ev.fizzled[i] = true
			continue
		f.mp -= int(cards[i].cost)
		var tiles := attack_tiles(f, cards[i])
		var targets := []
		for j in foes_of(i):
			var foe := fighters[j]
			# 같은 칸에 있는 적은 어떤 공격이든 맞는다 — 범위는 모두 "앞 몇 칸"이라 이게 없으면 같은 칸이 안전지대가 된다
			if not tiles.has(foe.pos) and foe.pos != f.pos:
				continue
			var d := maxi(0, int(cards[i].dmg) - block_of[j])
			dmg[j] += d
			targets.append({"to": j, "dmg": d})
		var first: Dictionary = targets[0] if not targets.is_empty() else {}
		ev.hits.append({"from": i, "tiles": tiles, "targets": targets, "hit": not targets.is_empty(),
			"dmg": first.get("dmg", 0)})
	for j in n:
		if not fighters[j].alive():
			continue
		fighters[j].hp = maxi(0, fighters[j].hp - dmg[j])
		if not fighters[j].alive():
			ev.died.append(j)

	ev.pos = []
	ev.facing = []
	ev.hp = []
	ev.mp = []
	for f in fighters:
		ev.pos.append(f.pos)
		ev.facing.append(f.facing)
		ev.hp.append(f.hp)
		ev.mp.append(f.mp)
	_check_winner()
	return ev


## 턴이 끝나면 모두 가장 가까운 적 쪽으로 돌아선다. 다음 턴 카드는 이 방향을 기준으로 고른다.
func _update_facing() -> void:
	for i in fighters.size():
		_face_nearest(i)


## 가장 가까운 적 쪽 열을 바라보게 한다. 같은 열(위·아래)이면 직전 방향을 유지한다.
func _face_nearest(i: int) -> void:
	if not fighters[i].alive():
		return
	var best := -1
	var best_d := 99
	for j in foes_of(i):
		var d := absi(fighters[j].pos.x - fighters[i].pos.x) + absi(fighters[j].pos.y - fighters[i].pos.y)
		if d < best_d:
			best_d = d
			best = j
	if best == -1:
		return
	var dx := fighters[best].pos.x - fighters[i].pos.x
	if dx != 0:
		fighters[i].facing = signi(dx)


func _check_winner() -> void:
	var team_alive := [false, false]
	for f in fighters:
		if f.alive():
			team_alive[f.team] = true
	if not team_alive[0] and not team_alive[1]:
		winner = 2
	elif not team_alive[0]:
		winner = 1
	elif not team_alive[1]:
		winner = 0
