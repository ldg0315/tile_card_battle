#!/bin/sh
# 규칙 테스트 실행. Godot 은 스크립트 컴파일이 실패해도 남은 테스트를 돌려 "ALL PASSED" 를 찍을 수 있어서,
# 출력에 SCRIPT ERROR 가 있으면 실패로 처리한다.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
# 1) 모든 스크립트 문법 검사. 규칙 테스트는 화면 스크립트(battle.gd 등)를 읽지 않아서,
#    여기서 걸러내지 않으면 문법 오류가 게임을 켜 볼 때까지 숨어 있다.
#    이 모드엔 오토로드(Game)가 없어 "Identifier not found" 가 나므로 Parse Error 만 본다.
for f in scripts/*.gd; do
	err=$("$GODOT" --headless --path . --check-only --script "$f" 2>&1 | grep -E "Parse Error" -A1)
	if [ -n "$err" ]; then
		echo "$err"
		echo "FAILED: $f 문법 오류"
		exit 1
	fi
done
# 2) 규칙 테스트
out=$("$GODOT" --headless --path . -s tests/test_rules.gd 2>&1)
code=$?
echo "$out" | grep -v "^Godot Engine"
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "FAILED: 스크립트 오류"
	exit 1
fi
exit $code
