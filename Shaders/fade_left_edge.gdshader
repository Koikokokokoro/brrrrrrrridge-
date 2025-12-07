// fade_left_edge.gdshader
shader_type canvas_item;

uniform float screen_width = 1000.0; // 视口宽度，需要在GDScript中更新
uniform float fade_start_x_ratio = 0.3; // 从屏幕左侧 30% 位置开始渐变
uniform float fade_end_x_ratio = 0.0;   // 在屏幕左侧 0% 位置完全透明 (可选，可根据需要调整)

void fragment() {
    // 获取当前像素在屏幕上的绝对 X 坐标
    // SCREEN_UV.x 是 0.0 到 1.0 的相对坐标
    float absolute_x = SCREEN_UV.x * screen_width;

    // 计算渐变范围的像素坐标
    float fade_start_x = screen_width * fade_start_x_ratio;
    float fade_end_x = screen_width * fade_end_x_ratio;

    // 计算当前像素的透明度乘数
    float alpha_multiplier = 1.0;

    // 如果像素在渐变区域内 (从 fade_start_x 到 fade_end_x)
    if (absolute_x < fade_start_x) {
        // 使用 smoothstep 进行平滑渐变
        // 当 absolute_x = fade_start_x 时，alpha_multiplier = 1.0
        // 当 absolute_x = fade_end_x 时，alpha_multiplier = 0.0
        alpha_multiplier = smoothstep(fade_end_x, fade_start_x, absolute_x);
    }

    // 获取原始纹理颜色
    vec4 color = texture(TEXTURE, UV);

    // 应用透明度乘数
    color.a *= alpha_multiplier;

    COLOR = color;
}