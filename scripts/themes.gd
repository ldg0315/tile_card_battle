extends RefCounted
## 장(chapter) 테마별 전투 배경: 하늘·땅·타일 색, 조명, 보드 둘레 소품 수.
## 색과 소품을 데이터로 두고 battle.gd 가 그린다 — 테마 추가는 여기 한 항목이면 된다.
## props 의 키는 prop_art.gd 의 make() 종류, 값은 [개수, 화면 높이]. prop_tint 는 소품 밝기(어두운 동굴),
## fog 는 안개 농도, water 가 있으면 보드 뒤편이 바다.

const THEMES := {
	"forest": {
		"sky_top": Color(0.32, 0.58, 0.85), "sky_horizon": Color(0.78, 0.9, 0.82),
		"ground": Color(0.2, 0.36, 0.17), "tile_a": Color(0.44, 0.62, 0.3), "tile_b": Color(0.37, 0.54, 0.25),
		"ambient": Color(0.78, 0.84, 0.72), "ambient_energy": 0.7, "sun": Color(1.0, 0.95, 0.84), "sun_energy": 1.1,
		"props": {"tree": [16, 3.6], "bush": [10, 0.9], "flower": [14, 0.4]},
		"ui_bg": Color(0.07, 0.12, 0.09),
	},
	"cave": {
		"sky_top": Color(0.04, 0.03, 0.07), "sky_horizon": Color(0.12, 0.09, 0.17),
		"ground": Color(0.13, 0.12, 0.16), "tile_a": Color(0.38, 0.36, 0.43), "tile_b": Color(0.32, 0.3, 0.37),
		"ambient": Color(0.55, 0.5, 0.75), "ambient_energy": 0.55, "sun": Color(0.7, 0.65, 0.9), "sun_energy": 0.55,
		"props": {"stalagmite": [14, 2.6], "rock": [10, 0.8], "crystal": [9, 1.1]},
		"prop_tint": Color(0.72, 0.7, 0.85), "fog": 0.035,
		"ui_bg": Color(0.06, 0.05, 0.09),
	},
	"coast": {
		"sky_top": Color(0.3, 0.62, 0.95), "sky_horizon": Color(0.85, 0.93, 0.98),
		"ground": Color(0.86, 0.78, 0.56), "tile_a": Color(0.9, 0.82, 0.6), "tile_b": Color(0.82, 0.74, 0.52),
		"ambient": Color(0.85, 0.85, 0.85), "ambient_energy": 0.75, "sun": Color(1.0, 0.97, 0.9), "sun_energy": 1.25,
		"props": {"palm": [8, 4.0], "rock": [7, 0.8], "shell": [12, 0.35]},
		"water": Color(0.15, 0.5, 0.75, 0.85),
		"ui_bg": Color(0.05, 0.1, 0.14),
	},
}


static func get_theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES.forest)
