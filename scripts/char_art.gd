extends RefCounted
## 캐릭터 애니메이션 프레임 공급.
## art/<캐릭터id>/<동작>_<프레임수>.png 가 있으면 그 그림을, 없으면 pixel_art.gd 의 임시 도트를 쓴다.
## 동작 단위로 섞이게 한 이유: 그림을 한 동작씩 그려 넣으면서 바로 게임에서 확인할 수 있게.
## 파일 규칙은 art/README.md 참고.
##
## 확대 방식: 도트 그림은 각지게(nearest), 큰 그림(캡처·일러스트 풍)은 부드럽게(linear + 밉맵) 보여야 한다.
## 프레임 높이가 SMOOTH_MIN_HEIGHT 이상이면 큰 그림으로 보고, art/<캐릭터>/art.cfg 의 filter 로 직접 정할 수도 있다.

const PixelArt := preload("res://scripts/pixel_art.gd")
const ART_DIR := "res://art"
const BG_DIR := "res://art/bg"
const IMAGE_EXTS := ["png", "webp", "jpg", "jpeg"]
const SMOOTH_MIN_HEIGHT := 96
const ANIMS := {
	"idle": {"fps": 3.0, "loop": true},
	"walk": {"fps": 10.0, "loop": true},
	"attack": {"fps": 12.0, "loop": false},
	"hit": {"fps": 8.0, "loop": false},
	"guard": {"fps": 1.0, "loop": true},
	"die": {"fps": 4.0, "loop": false},
}


## 캐릭터 동작 프레임. 메타 "smooth" 에 부드럽게 확대할지가 들어 있다(is_smooth).
static func build_frames(char_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var generated := {}
	var smooth := _smooth_setting(char_id)
	for anim: String in ANIMS:
		var texs := load_strip(char_id, anim, smooth)
		if texs.is_empty():
			if generated.is_empty():
				generated = PixelArt.build(char_id)
			texs.assign(generated.get(anim, []))
		frames.add_animation(anim)
		frames.set_animation_speed(anim, ANIMS[anim].fps)
		frames.set_animation_loop(anim, ANIMS[anim].loop)
		for t in texs:
			frames.add_frame(anim, t)
	frames.set_meta("smooth", smooth == 1)
	return frames


static func is_smooth(frames: SpriteFrames) -> bool:
	return frames.get_meta("smooth", false)


## 1 = 부드럽게, 0 = 도트, -1 = 아직 모름(첫 그림 크기로 정한다). art.cfg 의 [art] filter = "smooth" | "pixel".
static func _smooth_setting(char_id: String) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(ProjectSettings.globalize_path("%s/%s/art.cfg" % [ART_DIR, char_id])) == OK:
		match cfg.get_value("art", "filter", ""):
			"smooth":
				return 1
			"pixel":
				return 0
	# 그림 파일이 하나라도 있으면 그 높이로 정하고, 없으면(임시 도트) 도트
	var dir := DirAccess.open("%s/%s" % [ART_DIR, char_id])
	if dir != null:
		for f in dir.get_files():
			var file := f.trim_suffix(".import")
			if file.get_extension().to_lower() in IMAGE_EXTS:
				var img := load_image("%s/%s/%s" % [ART_DIR, char_id, file])
				if img != null:
					return 1 if img.get_height() >= SMOOTH_MIN_HEIGHT else 0
	return 0


## 큰 그림은 밉맵을 만들어 둔다 — 화면에서 작게 그려질 때 지글거림(계단·반짝임)을 없앤다.
static func make_texture(img: Image, smooth: bool) -> ImageTexture:
	if smooth and not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## "attack_6.png" → ["attack", 6]. 숫자가 없으면 1프레임짜리 한 장으로 본다.
static func parse_name(file: String) -> Array:
	var base := file.get_basename()
	var parts := base.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		return [parts[0], maxi(1, int(parts[1]))]
	return [base, 1]


## 가로로 같은 폭의 프레임이 이어진 스트립을 잘라 텍스처 배열로.
static func load_strip(char_id: String, anim: String, smooth := 0) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir_path := "%s/%s" % [ART_DIR, char_id]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		# 내보낸 빌드에선 원본 png 대신 .import 만 보이므로 이름을 되돌려 찾는다
		var file := f.trim_suffix(".import")
		if not file.get_extension().to_lower() in IMAGE_EXTS:
			continue
		var parsed := parse_name(file)
		if parsed[0] != anim:
			continue
		var img := load_image(dir_path + "/" + file)
		if img == null:
			push_warning("그림을 읽지 못함: %s/%s" % [dir_path, file])
			return out
		var count: int = parsed[1]
		var w := img.get_width() / count
		for k in count:
			out.append(make_texture(img.get_region(Rect2i(k * w, 0, w, img.get_height())), smooth == 1))
		return out
	return out


## 에디터가 임포트한 그림이면 리소스로, 방금 넣어서 아직 임포트 전이면 파일에서 바로 읽는다
## (에디터를 열지 않고 게임만 실행해도 새 그림이 보이게).
static func load_image(path: String) -> Image:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			return tex.get_image()
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		return Image.load_from_file(abs_path)
	return null


## 장 테마 배경 그림 art/bg/<테마>.png|webp|jpg. 없으면 null(코드로 만든 3D 배경을 쓴다).
static func background(theme_id: String) -> Texture2D:
	for ext in IMAGE_EXTS:
		var img := load_image("%s/%s.%s" % [BG_DIR, theme_id, ext])
		if img != null:
			return make_texture(img, true)
	return null
