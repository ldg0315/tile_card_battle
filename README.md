# 타일 카드 배틀

3×4 타일 위에서 카드 3장을 동시에 고르고 순서대로 실행하는 턴제 대전 게임입니다(Godot 4, 2.5D 3인칭 시점).

## 실행

Godot 에디터에서 이 폴더를 열고 F5를 누릅니다. 터미널에서는 다음 명령으로 실행합니다.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path ~/tile_card_battle
```

## 구조

- `scripts/game_rules.gd`: 순수 규칙(이동, 공격, 방어, 승패). 화면 코드를 참조하지 않습니다.
- `scripts/cards.gd`: 카드와 캐릭터 정의. 새 캐릭터나 공격은 여기에만 추가하면 됩니다.
- `scripts/ai.gd`: 단순 AI. 가능한 조합을 전부 시뮬레이션한 뒤 약간의 난수를 섞어 고릅니다.
- `scripts/main.gd`: 3D 보드, 빌보드 도트 스프라이트, UI, 연출. 규칙이 돌려준 이벤트만 읽어서 보여줍니다.
- 1인칭 시점은 `main.gd`에 카메라를 하나 더 두면 됩니다. 규칙은 수정할 필요가 없습니다.

## 테스트

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path ~/tile_card_battle -s tests/test_rules.gd
```
