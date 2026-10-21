extends RefCounted
## 단순 AI. 상대 카드를 모르는 상태라 "상대는 제자리에 있다"고 가정하고 내 3장을 시뮬레이션한다.
## 조합이 최대 9P3 = 504가지라 전수 탐색해도 순간이다.
## 점수에 약간의 난수를 섞는다 — 없으면 같은 상황에서 늘 같은 수를 둬서 플레이어가 금방 파훼한다.

const Cards := preload("res://scripts/cards.gd")

const NOISE := 6.0
const DANGER_WEIGHT := 0.4
const MP_WEIGHT := 0.15


static func choose(rules, idx: int, rng: RandomNumberGenerator) -> Array:
	var hand: Array = rules.hand(idx)
	var best: Array = []
	var best_score := -INF
	for a: String in hand:
		for b: String in hand:
			for c: String in hand:
				var pick := [a, b, c]
				if not rules.is_valid_selection(idx, pick):
					continue
				var score := _score(rules, idx, pick) + rng.randf() * NOISE
				if score > best_score:
					best_score = score
					best = pick
	return best


static func _score(rules, idx: int, pick: Array) -> float:
	var foe := 1 - idx
	var sim = rules.clone()
	var idle := ["rest", "rest", "rest"]
	var before: int = sim.fighters[foe].hp
	if idx == 0:
		sim.resolve_turn(pick, idle)
	else:
		sim.resolve_turn(idle, pick)
	var dealt: int = before - sim.fighters[foe].hp

	# 턴이 끝난 자리에서 상대가 지금 MP 로 쓸 수 있는 공격에 몇 개나 걸리는지 = 위험도
	var me = sim.fighters[idx]
	var them = sim.fighters[foe]
	var foe_mp: int = rules.fighters[foe].mp
	var danger := 0
	for id: String in rules.hand(foe):
		var card: Dictionary = Cards.get_card(id)
		if card.type == "attack" and int(card.cost) <= foe_mp and sim.attack_tiles(them, card).has(me.pos):
			danger += int(card.dmg)
	return dealt - danger * DANGER_WEIGHT + me.mp * MP_WEIGHT
