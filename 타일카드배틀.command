#!/bin/sh
# 더블클릭하면 게임을 실행한다(Finder 에서 열면 터미널이 잠깐 떴다가 게임 창이 뜬다).
# 프로젝트 소스를 그대로 실행하므로 저장된 코드·그림·소리 변경은 다음 실행부터 바로 반영된다.
# 자주 쓰는 시작점이 있으면 이 파일을 복사해 아래 ARGS 만 바꾸면 된다. 예: ARGS="--stage=1-3 --char=archer"
ARGS=""
GODOT_APP="/Applications/Godot.app"
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$GODOT_APP" ]; then
	echo "Godot 이 $GODOT_APP 에 없습니다. 설치 위치가 다르면 이 파일의 GODOT_APP 을 고쳐 주세요."
	read -r _
	exit 1
fi
# open -n: 터미널과 분리된 새 앱으로 띄운다 — 터미널 창을 닫아도 게임이 꺼지지 않게
# shellcheck disable=SC2086
open -n -a "$GODOT_APP" --args --path "$DIR" -- $ARGS
