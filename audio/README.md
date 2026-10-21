# 소리 넣는 법

이 폴더에 파일을 넣으면 게임이 자동으로 사용합니다. 코드는 고칠 필요가 없습니다.

## 효과음: `audio/sfx/<이름>.wav` (또는 `.ogg`)

파일이 없는 효과음은 코드로 만든 임시 8비트 소리(`scripts/sfx_synth.gd`)가 대신 납니다. 하나씩 바꿔 넣어도 됩니다.

| 이름 | 언제 |
|---|---|
| `select` / `deselect` | 카드 고르기 / 해제 |
| `go` | 실행 |
| `click` | 메뉴 버튼 |
| `move` | 이동 착지 |
| `dash` | 2칸 이동 출발 |
| `slash` | 베기·발차기·몸통박치기 등 근접 공격 |
| `thrust` | 찌르기·급강하·돌진찌르기 |
| `spin` | 회전베기·산성 튀기기 등 주변 공격 |
| `jump` / `slam` | 킹슬라임 대점프 / 내려찍기 |
| `arrow` / `arrow_hit` | 화살 발사 / 화살이 바닥에 꽂힘 |
| `volley` | 화살비 |
| `wave` | 초음파 |
| `hit` / `backstab` / `block` | 맞음 / 뒤잡기 / 방어로 다 막음 |
| `guard` / `rest` | 방어 / 기 모으기 |
| `death` | 쓰러짐 |
| `warn` | 보스 대기술 예고 |
| `victory` / `defeat` | 승리 / 패배 |

## 배경음악: `audio/bgm/<이름>.ogg` (또는 `.wav`)

파일이 없으면 코드로 만든 임시 곡(`scripts/bgm_synth.gd`)이 나옵니다. 어떤 장면에 어떤 곡을 걸지는 그 파일의 `SLOTS`에서 정합니다. 지금 배치는 숲 = 민요풍(새소리 있음), 타이틀·캐릭터 선택·맵 = 잔잔함(새소리 없이 바람만), 보스전 = 모험이고, 동굴·해안은 아직 곡이 없어 무음입니다. 같은 곡이 걸린 장면끼리는(타이틀 → 캐릭터 선택 → 맵) 끊기지 않고 이어집니다. 반복 재생은 자동으로 켜집니다.

| 이름 | 언제 |
|---|---|
| `title` | 타이틀, 캐릭터 선택 |
| `map` | 던전 맵 |
| `forest` / `cave` / `coast` | 장 테마별 전투 |
| `boss` | 장 보스전 |

## 라이선스

저장소가 공개라서, 구한 소리는 CC0이나 CC-BY처럼 재배포가 허용된 것만 넣습니다. 출처는 [CREDITS.md](CREDITS.md)에 적습니다.

## 임시 소리 들어보기

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path ~/tile_card_battle -s tools/dump_sfx.gd -- ~/tile_card_battle/shots/sfx
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path ~/tile_card_battle -s tools/dump_bgm.gd -- ~/tile_card_battle/shots/bgm
```
