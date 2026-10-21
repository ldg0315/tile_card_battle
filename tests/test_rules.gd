extends SceneTree
## 규칙 회귀 테스트. 화면 없이 돈다:
##   godot --headless --path . -s tests/test_rules.gd

const Rules := preload("res://scripts/game_rules.gd")
const AI := preload("res://scripts/ai.gd")

var failed := 0


func _init() -> void:
	_test_forward_is_toward_opponent()
	_test_wall_blocks_move()
	_test_same_tile_and_swap_blocked()
	_test_attack_and_guard()
	_test_facing_flips_after_passing()
	_test_simultaneous_ko_is_draw()
	_test_selection_rules()
	_test_ai_always_valid()
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
	r.resolve_turn(["fwd", "rest", "guard"], ["fwd", "rest", "guard"])
	check(r.fighters[0].pos == Vector2i(1, 1), "P1 앞으로 = 열 +1")
	check(r.fighters[1].pos == Vector2i(2, 1), "P2 앞으로 = 열 -1")


func _test_wall_blocks_move() -> void:
	var r = Rules.new()
	r.resolve_turn(["up", "up", "rest"], ["back", "down", "down"])
	check(r.fighters[0].pos == Vector2i(0, 0), "보드 밖으로는 못 나감(위)")
	check(r.fighters[1].pos == Vector2i(3, 2), "보드 밖으로는 못 나감(뒤·아래)")


func _test_same_tile_and_swap_blocked() -> void:
	var r = _setup(Vector2i(0, 1), Vector2i(2, 1))
	r.resolve_turn(["fwd", "rest", "guard"], ["fwd", "rest", "guard"])
	check(r.fighters[0].pos == Vector2i(0, 1) and r.fighters[1].pos == Vector2i(2, 1), "같은 칸 진입은 둘 다 제자리")
	r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	r.resolve_turn(["fwd", "rest", "guard"], ["fwd", "rest", "guard"])
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
	r.resolve_turn(["fwd", "fwd", "rest"], ["rest", "rest", "rest"])
	# (1,0) → (2,0) 같은 열이라 방향 유지 → (3,0) 상대를 지나쳤으니 방향이 뒤집혀야 함
	check(r.fighters[0].pos == Vector2i(3, 0), "상대 옆을 지나 이동")
	check(r.fighters[0].facing == -1 and r.fighters[1].facing == 1, "지나치면 서로 방향 반전")


func _test_simultaneous_ko_is_draw() -> void:
	var r = _setup(Vector2i(1, 1), Vector2i(2, 1))
	r.fighters[0].hp = 10
	r.fighters[1].hp = 10
	var ev: Array = r.resolve_turn(["sword_slash", "rest", "rest"], ["archer_kick", "rest", "rest"])
	check(r.winner == 2, "동시 KO 는 무승부")
	check(ev.size() == 1, "승부가 나면 남은 단계는 진행하지 않음")


func _test_selection_rules() -> void:
	var r = Rules.new()
	check(r.is_valid_selection(0, ["fwd", "sword_slash", "guard"]), "정상 선택")
	check(not r.is_valid_selection(0, ["fwd", "fwd", "guard"]), "중복 카드 금지")
	check(not r.is_valid_selection(0, ["sword_thrust", "sword_spin", "fwd"]), "MP 초과 금지 (30+25 > 50)")
	check(not r.is_valid_selection(0, ["archer_arrow", "fwd", "guard"]), "상대 캐릭터 카드 금지")


func _test_ai_always_valid() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 30:
		rng.seed = seed
		var r = Rules.new()
		r.fighters[1].mp = seed * 3
		var pick: Array = AI.choose(r, 1, rng)
		check(r.is_valid_selection(1, pick), "AI 선택이 유효해야 함 (seed %d)" % seed)
