extends RefCounted
## 화면과 분리된 순수 규칙.
## 3인칭/1인칭은 이 상태를 다른 카메라로 보는 것뿐이라, 여기에 Node 를 참조하는 코드가 들어오면
## 시점을 추가할 때 규칙까지 다시 짜야 한다.

const Cards := preload("res://scripts/cards.gd")

const ROWS := 3
const COLS := 4
const MAX_HP := 100
const MAX_MP := 100
const START_MP := 50
const REST_MP := 25
const GUARD_BLOCK := 15
const CARDS_PER_TURN := 3


class Fighter:
	var char_id: String
	var pos: Vector2i  # x = 열(0~3), y = 행(0~2, 0 이 화면 위쪽)
	var facing: int  # +1 이면 열이 커지는 쪽이 "앞"
	var hp := MAX_HP
	var mp := START_MP

	func copy() -> Fighter:
		var f := Fighter.new()
		f.char_id = char_id
		f.pos = pos
		f.facing = facing
		f.hp = hp
		f.mp = mp
		return f


var fighters: Array[Fighter] = []
var winner := -1  # -1 진행 중, 0/1 승자, 2 무승부


func _init(char0 := "sword", char1 := "archer") -> void:
	fighters = [_make(char0, Vector2i(0, 1), 1), _make(char1, Vector2i(COLS - 1, 1), -1)]


func _make(char_id: String, pos: Vector2i, facing: int) -> Fighter:
	var f := Fighter.new()
	f.char_id = char_id
	f.pos = pos
	f.facing = facing
	return f


## AI 가 수를 시뮬레이션할 때 원본을 건드리지 않도록 쓰는 복사본.
func clone():
	var c = get_script().new(fighters[0].char_id, fighters[1].char_id)
	for i in 2:
		c.fighters[i] = fighters[i].copy()
	c.winner = winner
	return c


static func in_board(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < COLS and t.y >= 0 and t.y < ROWS


func hand(idx: int) -> Array[String]:
	return Cards.hand_for(fighters[idx].char_id)


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


func attack_tiles(f: Fighter, card: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off: Vector2i in card.range:
		var t := Vector2i(f.pos.x + off.x * f.facing, f.pos.y + off.y)
		if in_board(t):
			out.append(t)
	return out


## 한 턴(양쪽 카드 3장)을 처리하고 단계별 이벤트를 돌려준다. 화면은 이 이벤트만 보고 연출한다.
func resolve_turn(cards0: Array, cards1: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in CARDS_PER_TURN:
		if winner != -1:
			break
		events.append(_resolve_step(cards0[i], cards1[i]))
	return events


func _resolve_step(id0: String, id1: String) -> Dictionary:
	var cards := [Cards.get_card(id0), Cards.get_card(id1)]
	var ev := {"cards": [id0, id1], "hits": [], "fizzled": [false, false], "guarding": [false, false]}

	# 1) 이동을 공격보다 먼저 처리한다 — 같은 단계에서 "피하는" 카드가 의미를 가지려면 이동이 선행해야 한다
	var p0 := fighters[0].pos
	var p1 := fighters[1].pos
	var targets: Array[Vector2i] = [p0, p1]
	for i in 2:
		if cards[i].type == "move":
			var f := fighters[i]
			var d: Vector2i = cards[i].dir
			var cand := Vector2i(f.pos.x + d.x * f.facing, f.pos.y + d.y)
			if in_board(cand):
				targets[i] = cand
	# 같은 칸으로 들어가거나 서로 자리를 맞바꾸려 하면 둘 다 제자리.
	# 한쪽에 우선권을 주면 P1/P2 순서가 곧 유불리가 돼 버린다.
	if targets[0] == targets[1] or (targets[0] == p1 and targets[1] == p0):
		targets = [p0, p1]
	for i in 2:
		fighters[i].pos = targets[i]
	_update_facing()

	# 2) 방어·기 모으기
	for i in 2:
		if cards[i].type == "guard":
			ev.guarding[i] = true
		elif cards[i].type == "rest":
			fighters[i].mp = mini(MAX_MP, fighters[i].mp + REST_MP)

	# 3) 공격은 동시 판정. 데미지를 모았다가 마지막에 적용해야
	#    같은 단계에서 먼저 처리된 쪽 때문에 상대 공격이 사라지는 일이 없다(맞교환 → 무승부 가능).
	var dmg := [0, 0]
	for i in 2:
		if cards[i].type != "attack":
			continue
		var f := fighters[i]
		var foe := fighters[1 - i]
		if f.mp < int(cards[i].cost):
			ev.fizzled[i] = true
			continue
		f.mp -= int(cards[i].cost)
		var tiles := attack_tiles(f, cards[i])
		var hit := tiles.has(foe.pos)
		var d := 0
		if hit:
			d = maxi(0, int(cards[i].dmg) - (GUARD_BLOCK if ev.guarding[1 - i] else 0))
		dmg[1 - i] += d
		ev.hits.append({"from": i, "tiles": tiles, "hit": hit, "dmg": d})
	for i in 2:
		fighters[i].hp = maxi(0, fighters[i].hp - dmg[i])

	ev.pos = [fighters[0].pos, fighters[1].pos]
	ev.facing = [fighters[0].facing, fighters[1].facing]
	ev.hp = [fighters[0].hp, fighters[1].hp]
	ev.mp = [fighters[0].mp, fighters[1].mp]
	_check_winner()
	return ev


## "앞"은 항상 상대 쪽. 같은 열에 서면 직전 방향을 유지한다(위아래로 스쳐 지나갈 때 방향이 튀지 않게).
func _update_facing() -> void:
	for i in 2:
		var dx := fighters[1 - i].pos.x - fighters[i].pos.x
		if dx != 0:
			fighters[i].facing = signi(dx)


func _check_winner() -> void:
	var dead0 := fighters[0].hp <= 0
	var dead1 := fighters[1].hp <= 0
	if dead0 and dead1:
		winner = 2
	elif dead0:
		winner = 1
	elif dead1:
		winner = 0
