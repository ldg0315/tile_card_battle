extends RefCounted
## 단순 AI. 상대 카드를 모르는 상태라 "상대는 제자리에 있다"고 가정하고 내 3장을 시뮬레이션한다.
## 조합이 최대 9P3 = 504가지라 전수 탐색해도 순간이다.
## 점수에 약간의 난수를 섞는다 — 없으면 같은 상황에서 늘 같은 수를 둬서 플레이어가 금방 파훼한다.

const Cards := preload("res://scripts/cards.gd")

const NOISE := 6.0
const DANGER_WEIGHT := 0.4
const MP_WEIGHT := 0.15


## fixed: 칸별로 꼭 낼 카드(null 이면 AI 가 고름). 보스 패턴이 일부 칸만 정하고 나머지를 맡길 때 쓴다.
## pattern_only 카드는 fixed 로 지정됐을 때만 나온다.
static func choose(rules, idx: int, rng: RandomNumberGenerator, fixed: Array = []) -> Array:
	var hand: Array = rules.hand(idx)
	var best: Array = []
	var best_score := -INF
	for a: String in hand:
		for b: String in hand:
			for c: String in hand:
				var pick := [a, b, c]
				if not _fits(pick, fixed) or not rules.is_valid_selection(idx, pick):
					continue
				var score := _score(rules, idx, pick) + rng.randf() * NOISE
				if score > best_score:
					best_score = score
					best = pick
	return best


static func _fits(pick: Array, fixed: Array) -> bool:
	for k in pick.size():
		var want = fixed[k] if k < fixed.size() else null
		if want != null:
			if pick[k] != want:
				return false
		elif Cards.get_card(pick[k]).get("pattern_only", false):
			return false
	return true


## 상대들은 제자리에서 기 모으기만 한다고 가정하고 내 3장을 굴려 본다.
static func _score(rules, idx: int, pick: Array) -> float:
	var sim = rules.clone()
	var foes: Array[int] = rules.foes_of(idx)
	var plans := []
	for k in sim.fighters.size():
		plans.append(pick if k == idx else ["rest", "rest", "rest"])
	var before := 0
	for j in foes:
		before += sim.fighters[j].hp
	sim.resolve_turn(plans)
	var dealt := before
	for j in foes:
		dealt -= sim.fighters[j].hp

	# 턴이 끝난 자리에서 상대들이 지금 MP 로 쓸 수 있는 공격에 몇 개나 걸리는지 = 위험도
	var me = sim.fighters[idx]
	var danger := 0
	for j in foes:
		var them = sim.fighters[j]
		var foe_mp: int = rules.fighters[j].mp
		for id: String in rules.hand(j):
			var card: Dictionary = Cards.get_card(id)
			if card.type == "attack" and not card.get("pattern_only", false) and int(card.cost) <= foe_mp \
					and sim.attack_tiles(them, card).has(me.pos):
				danger += int(card.dmg)
	return dealt - danger * DANGER_WEIGHT + me.mp * MP_WEIGHT
