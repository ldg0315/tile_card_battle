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
const BACKSTAB_MULT := 1.5
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
	return Cards.hand_for(fighters[idx].char_id)


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
	return cost_of(cards) <= fighters[idx].mp


## from 이 defender 의 등 뒤(바라보는 반대쪽 열)에 있는가. 같은 열(위·아래)은 옆이라 뒤로 치지 않는다.
static func is_behind(defender: Fighter, from: Vector2i) -> bool:
	return (from.x - defender.pos.x) * defender.facing < 0


## 이동 카드의 도착 칸. dir 은 화면(보드) 기준이라 바라보는 방향과 무관하다. 2칸 이동은 중간 칸을 따지지 않고 뛰어넘으며,
## 보드 밖이면 한 칸씩 줄여 갈 수 있는 만큼만 간다(질주 카드가 벽 앞에서 통째로 헛도는 건 손해가 너무 커서).
## 다른 전투원과의 충돌은 여기서 보지 않는다 — 동시 이동이라 모두의 목적지가 정해진 뒤 한꺼번에 판정한다.
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
	var ev := {"cards": ids, "hits": [], "fizzled": _filled(n, false), "guarding": _filled(n, false), "died": []}

	# 1) 이동을 공격보다 먼저 처리한다 — 같은 단계에서 "피하는" 카드가 의미를 가지려면 이동이 선행해야 한다
	var old := []
	var dest := []
	for f in fighters:
		old.append(f.pos)
		dest.append(f.pos)
	for i in n:
		if cards[i].get("type", "") == "move":
			# 이동도 비용이 있으면(2칸 이동) 여기서 낸다. 모자라면 공격과 같이 헛돈다
			var cost := int(cards[i].cost)
			if fighters[i].mp < cost:
				ev.fizzled[i] = true
				continue
			fighters[i].mp -= cost
			dest[i] = move_target(fighters[i], cards[i].dir)
	# 같은 칸으로 들어가거나 서로 자리를 맞바꾸려 하면 관련된 쪽 모두 제자리. 한 번 되돌리면
	# 그 자리로 들어오려던 다른 전투원과 새로 겹칠 수 있어서 더 이상 바뀌지 않을 때까지 반복한다.
	# 한쪽에 우선권을 주지 않는 이유: 처리 순서가 곧 유불리가 돼 버린다.
	var changed := true
	while changed:
		changed = false
		for i in n:
			for j in range(i + 1, n):
				if not fighters[i].alive() or not fighters[j].alive():
					continue
				var clash: bool = dest[i] == dest[j] or (dest[i] == old[j] and dest[j] == old[i])
				if clash and (dest[i] != old[i] or dest[j] != old[j]):
					dest[i] = old[i]
					dest[j] = old[j]
					changed = true
	for i in n:
		fighters[i].pos = dest[i]
	# 이동 카드를 쓴 쪽은 이동 직후 가장 가까운 적을 향해 돌아선다. 가만히 있던 쪽은 방향을 유지한다.
	# 지나친 뒤에도 등을 보인 채 걸어다니는 어색함을 없애면서, "움직이지 않은 쪽이 등을 내준다"로 뒤잡기는 살린다
	for i in n:
		if cards[i].get("type", "") == "move" and not ev.fizzled[i]:
			_face_nearest(i)

	# 2) 방어·기 모으기
	for i in n:
		match cards[i].get("type", ""):
			"guard":
				ev.guarding[i] = true
			"rest":
				fighters[i].mp = mini(MAX_MP, fighters[i].mp + REST_MP)

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
			if not tiles.has(foe.pos):
				continue
			var back := is_behind(foe, f.pos)
			var raw := int(cards[i].dmg)
			if back:
				raw = int(raw * BACKSTAB_MULT)
			# 방어는 정면만 막는다 — 등을 내준 쪽이 방어 카드로 손해를 만회하지 못해야 뒤잡기가 의미 있다
			var block := GUARD_BLOCK if ev.guarding[j] and not back else 0
			var d := maxi(0, raw - block)
			dmg[j] += d
			targets.append({"to": j, "dmg": d, "back": back})
		var first: Dictionary = targets[0] if not targets.is_empty() else {}
		ev.hits.append({"from": i, "tiles": tiles, "targets": targets, "hit": not targets.is_empty(),
			"dmg": first.get("dmg", 0), "back": first.get("back", false)})
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


## 턴이 끝나면 모두 가장 가까운 적 쪽으로 돌아선다. 턴 도중엔 이동한 쪽만 돌아선다(_resolve_step).
## 매 단계 모두를 돌려세우지 않는 이유: 상대가 늘 나를 바라보게 돼 뒤잡기가 성립하지 않는다.
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
