extends RefCounted
## 캐릭터 애니메이션 프레임 공급.
## art/<캐릭터id>/<동작>_<프레임수>.png 가 있으면 그 그림을, 없으면 pixel_art.gd 의 임시 도트를 쓴다.
## 동작 단위로 섞이게 한 이유: 그림을 한 동작씩 그려 넣으면서 바로 게임에서 확인할 수 있게.
## 파일 규칙은 art/README.md 참고.

const PixelArt := preload("res://scripts/pixel_art.gd")
const ART_DIR := "res://art"
const ANIMS := {
	"idle": {"fps": 3.0, "loop": true},
	"walk": {"fps": 10.0, "loop": true},
	"attack": {"fps": 12.0, "loop": false},
	"hit": {"fps": 8.0, "loop": false},
	"guard": {"fps": 1.0, "loop": true},
	"die": {"fps": 4.0, "loop": false},
}


static func build_frames(char_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var generated := {}
	for anim: String in ANIMS:
		var texs := load_strip(char_id, anim)
		if texs.is_empty():
			if generated.is_empty():
				generated = PixelArt.build(char_id)
			texs.assign(generated.get(anim, []))
		frames.add_animation(anim)
		frames.set_animation_speed(anim, ANIMS[anim].fps)
		frames.set_animation_loop(anim, ANIMS[anim].loop)
		for t in texs:
			frames.add_frame(anim, t)
	return frames


## "attack_6.png" → ["attack", 6]. 숫자가 없으면 1프레임짜리 한 장으로 본다.
static func parse_name(file: String) -> Array:
	var base := file.get_basename()
	var parts := base.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int():
		return [parts[0], maxi(1, int(parts[1]))]
	return [base, 1]


## 가로로 같은 폭의 프레임이 이어진 스트립을 잘라 텍스처 배열로.
static func load_strip(char_id: String, anim: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir_path := "%s/%s" % [ART_DIR, char_id]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		# 내보낸 빌드에선 원본 png 대신 .import 만 보이므로 이름을 되돌려 찾는다
		var file := f.trim_suffix(".import")
		if file.get_extension().to_lower() != "png":
			continue
		var parsed := parse_name(file)
		if parsed[0] != anim:
			continue
		var img := _load_image(dir_path + "/" + file)
		if img == null:
			push_warning("그림을 읽지 못함: %s/%s" % [dir_path, file])
			return out
		var count: int = parsed[1]
		var w := img.get_width() / count
		for k in count:
			out.append(ImageTexture.create_from_image(img.get_region(Rect2i(k * w, 0, w, img.get_height()))))
		return out
	return out


## 에디터가 임포트한 그림이면 리소스로, 방금 넣어서 아직 임포트 전이면 파일에서 바로 읽는다
## (에디터를 열지 않고 게임만 실행해도 새 그림이 보이게).
static func _load_image(path: String) -> Image:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			return tex.get_image()
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		return Image.load_from_file(abs_path)
	return null
