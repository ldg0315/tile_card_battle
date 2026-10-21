// 회전베기 칼날 궤적. 수평 사각형 위에 극좌표로 고리 띠를 그리고,
// 칼끝(head)에서 뒤로 tail 만큼만 보이게 해서 "돌아가는 궤적"을 만든다.
// full 을 켜면 각도와 상관없이 고리 전체가 보인다(바닥 충격파).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float head = 0.0;   // 칼끝 각도(라디안). 0 → TAU 로 돌린다
uniform float tail = 4.2;   // 궤적 길이(라디안)
uniform float r_in = 0.55;  // 띠 안쪽 반지름(사각형 반폭 = 1 기준)
uniform float r_out = 0.92; // 띠 바깥 반지름
uniform float fade = 1.0;   // 전체 투명도
uniform bool full = false;
uniform vec4 core : source_color = vec4(1.0, 1.0, 0.92, 1.0); // 칼끝·바깥쪽 색
uniform vec4 edge : source_color = vec4(1.0, 0.5, 0.18, 1.0); // 꼬리·안쪽 색

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = 1.0;
	if (!full) {
		float behind = mod(head - a, 6.2831853);
		t = 1.0 - behind / tail;
		if (t <= 0.0) {
			discard;
		}
	}
	float band = smoothstep(r_in, r_in + 0.07, r) * (1.0 - smoothstep(r_out - 0.1, r_out, r));
	if (band <= 0.0) {
		discard;
	}
	// 바깥쪽일수록, 칼끝에 가까울수록 밝게 — 칼날 끝이 가장 빠르게 지나가는 느낌
	float k = clamp((r - r_in) / max(r_out - r_in, 0.001), 0.0, 1.0);
	vec3 col = mix(edge.rgb, core.rgb, smoothstep(0.3, 0.95, k) * t);
	float streak = 0.7 + 0.3 * sin(r * 80.0 + a * 4.0);
	float alpha = band * pow(t, 1.5) * streak * fade;
	ALBEDO = col * 1.6;
	ALPHA = alpha;
}
