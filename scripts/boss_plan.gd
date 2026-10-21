extends RefCounted
## 보스 패턴. 보스는 cards.gd 의 phases 를 따라 턴마다 정해진 카드를 내고, "ai" 칸만 AI 가 채운다.
## 순수 함수로 둔 이유: "예고 턴 다음엔 반드시 대기술" 같은 플레이어와의 약속을 테스트로 고정하려고.
## 패턴이 읽히는 게 핵심이라, 예고(warn)는 반드시 대기술 한 턴 전에 나와야 한다.

const AI := preload("res://scripts/ai.gd")
const Cards := preload("res://scripts/cards.gd")


static func has_pattern(char_id: String) -> bool:
	return not Cards.CHARACTERS[char_id].get("phases", []).is_empty()


static func new_state() -> Dictionary:
	return {"phase": 0, "turn": 0}


## 지금 HP 비율로 몇 번째 페이즈인지. until_hp 보다 HP 비율이 높으면 그 페이즈에 머문다.
static func phase_index(rules, idx: int) -> int:
	var f = rules.fighters[idx]
	var phases: Array = Cards.CHARACTERS[f.char_id].phases
	var ratio: float = float(f.hp) / f.max_hp
	for k in phases.size():
		if ratio > float(phases[k].get("until_hp", 0.0)):
			return k
	return phases.size() - 1


## 이번 턴 카드를 정한다. 부를 때마다 state 의 턴이 하나 진행되고,
## 페이즈가 바뀌면 그 페이즈 패턴의 처음부터 다시 시작한다.
## 반환: {cards, warn(다음 턴 예고 문구), phase_msg(페이즈 진입 문구, 바뀐 턴에만)}
static func plan(rules, idx: int, rng: RandomNumberGenerator, state: Dictionary) -> Dictionary:
	var phases: Array = Cards.CHARACTERS[rules.fighters[idx].char_id].phases
	var ph := phase_index(rules, idx)
	var phase_msg := ""
	if ph != state.phase:
		state.phase = ph
		state.turn = 0
		phase_msg = phases[ph].get("enter", "")
	var pattern: Array = phases[ph].pattern
	var step: Dictionary = pattern[state.turn % pattern.size()]
	state.turn += 1

	var fixed := [null, null, null]
	var want = step.get("cards", "ai")
	if want is Array:
		for k in want.size():
			fixed[k] = null if want[k] == "ai" else want[k]
	return {"cards": AI.choose(rules, idx, rng, fixed), "warn": step.get("warn", ""), "phase_msg": phase_msg}
