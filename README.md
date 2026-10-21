# 타일 카드 배틀

3×4 타일 위에서 카드 3장을 동시에 고르고 순서대로 실행하는 턴제 대전 게임입니다(Godot 4, 2.5D 3인칭 시점).

## 실행

Godot 에디터에서 이 폴더를 열고 F5를 누르면 타이틀(모드 선택)부터 시작합니다. 터미널에서는 다음 명령으로 실행합니다.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path ~/tile_card_battle
```

### 개발할 때 메뉴 건너뛰기

- 에디터에서 `battle.tscn`을 열고 **F6**(현재 장면 실행)을 누르면 기본 대전(검사 대 궁수)으로 바로 시작합니다. `stage_map.tscn`도 F6으로 바로 열 수 있습니다.
- 터미널에서는 실행 명령 뒤에 `-- --stage=1-3`(싱글 해당 스테이지 전투), `-- --map`(던전 맵), `-- --versus`(AI 대전)를 붙입니다. `--char=archer`를 함께 쓰면 궁수로, `--wave=2`면 연속전의 두 번째 적부터 시작합니다.

## 화면 흐름

`title.tscn`(모드 선택) → `char_select.tscn`(검사·궁수) → 싱글: `stage_map.tscn`(던전 진행) ↔ `battle.tscn`(전투) / AI 대전: `battle.tscn`(고르지 않은 캐릭터가 상대).
화면 사이의 진행 상태(모드, 캐릭터, 장·스테이지, 이어지는 HP)는 오토로드 `Game`(`scripts/game_state.gd`)이 들고 있고, 장·스테이지 목록(`CHAPTERS`)도 거기에 있습니다. 장마다 마지막 스테이지가 보스입니다.
한 스테이지는 전투(`waves`) 목록이고, 한 전투 안의 적들은 동시에 나옵니다(최대 3마리). 규칙(`game_rules.gd`)은 전투원 0번이 플레이어, 1번부터가 적인 N명 전투입니다.
장마다 테마(`theme`)가 있어 전투 배경(하늘·땅·타일 색, 소품)이 바뀝니다. 테마 색과 소품 수는 `scripts/themes.gd`, 소품 도트는 `scripts/prop_art.gd`에 있습니다.
보스 패턴(예고 턴 → 대기술, HP 절반 이하 분노 페이즈)은 `scripts/cards.gd`의 `phases`에 데이터로 적고, `scripts/boss_plan.gd`가 따릅니다.

## 구조

- `scripts/game_rules.gd`: 순수 규칙(이동, 공격, 방어, 승패). 화면 코드를 참조하지 않습니다.
- `scripts/cards.gd`: 카드와 캐릭터 정의. 새 캐릭터나 공격은 여기에만 추가하면 됩니다.
- `scripts/ai.gd`: 단순 AI. 가능한 조합을 전부 시뮬레이션한 뒤 약간의 난수를 섞어 고릅니다.
- `scripts/battle.gd`: 3D 보드, 빌보드 도트 스프라이트, UI, 연출. 규칙이 돌려준 이벤트만 읽어서 보여줍니다.
- `scripts/char_art.gd`: 캐릭터 동작 프레임을 공급합니다. `art/` 폴더에 그림이 있으면 그 그림을, 없으면 `scripts/pixel_art.gd`의 임시 도트를 씁니다. 그림 넣는 규칙은 [art/README.md](art/README.md)에 있습니다.
- 1인칭 시점(V 키)과 카드 엿보기는 화면 기능이라 `battle.gd`에만 있습니다. 규칙은 시점을 모릅니다.
- 앞으로 할 일과 아이디어는 [docs/ROADMAP.md](docs/ROADMAP.md)에 있습니다.

## 테스트

```bash
~/tile_card_battle/tools/run_tests.sh
```
