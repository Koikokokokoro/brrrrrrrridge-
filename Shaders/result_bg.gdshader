shader_type canvas_item;

// —— 常量角度（度），顺序定义扇区边界 ——
const int RAY_COUNT = 6;
const float RAY_ANGLES_DEGREE[RAY_COUNT] = float[](
    -135.0,
    -45.0,
    -15.0,
     15.0,
    165.0,
    195.0
);

// —— uniform: 仿射从本地像素 -> 全局像素（屏幕）空间 ——
uniform vec2 u_basis_x = vec2(1.0, 0.0);
uniform vec2 u_basis_y = vec2(0.0, 1.0);
uniform vec2 u_origin_px = vec2(0.0, 0.0);

// 本地节点像素大小（用于把 UV -> local_px）
uniform vec2 u_rect_size_px = vec2(100.0, 100.0);

// 局部中心（0..1，相对于本节点 local rect），例如 (0.5,0.9)
uniform vec2 u_center_local = vec2(0.5, 0.9);

// 颜色与半径（像素）
uniform vec4 color_orange : source_color = vec4(1.0, 0.6, 0.2, 0.9);
uniform vec4 color_green  : source_color = vec4(0.2, 0.8, 0.4, 0.9);
uniform float radius_px = 200.0;      // 最大可见半径
uniform float feather_px = 2.0;

// 动画进度：0=完全收缩在中心，1=展开到 radius_px
uniform float animation_progress = 1.0;

// 索引输出调试（0=color; 1=alpha=idx_norm; 2=gray idx visual）
uniform int index_output_mode = 0;

// ------- 工具函数 -------
float ang_mod360(float a) {
    float m = mod(a, 360.0);
    if (m < 0.0) { m += 360.0; }
    return m;
}

bool angle_in_sector(float a, float s, float e) {
    float da = ang_mod360(a - s);
    float len = ang_mod360(e - s);
    return da <= len;
}

// 把 local_px 映射到 global_px（像素空间）
vec2 local_to_global_px(vec2 local_px) {
    vec2 g;
    g.x = u_basis_x.x * local_px.x + u_basis_y.x * local_px.y;
    g.y = u_basis_x.y * local_px.x + u_basis_y.y * local_px.y;
    return g + u_origin_px;
}

void fragment() {
    vec4 out_col = vec4(0.0);

    // 1) UV -> 本地像素坐标
    vec2 local_px = UV * u_rect_size_px;

    // 2) 本地像素 -> 全局像素（屏幕空间）
    vec2 global_px = local_to_global_px(local_px);

    // 3) center 全局坐标
    vec2 center_local_px = u_center_local * u_rect_size_px;
    vec2 center_global_px = local_to_global_px(center_local_px);

    // 4) 方向向量与距离
    vec2 dir = global_px - center_global_px;
    float dist = length(dir);

    // 5) 根据动画进度控制半径
    float current_radius = radius_px * animation_progress;
    if (dist > current_radius + feather_px) {
        COLOR = vec4(0.0);
    }

    // 6) 角度（度）
    float ang = 0.0;
    if (dist > 1e-6) {
        ang = degrees(atan(dir.y, dir.x));
    }

    // 7) 找所属扇区
    int found_idx = -1;
    for (int i = 0; i < RAY_COUNT; i++) {
        float s = RAY_ANGLES_DEGREE[i];
        float e = RAY_ANGLES_DEGREE[(i + 1) % RAY_COUNT];
        if (angle_in_sector(ang, s, e)) {
            found_idx = i;
            break;
        }
    }
    if (found_idx == -1) {
        found_idx = RAY_COUNT - 1;
    }
    int sector_number = found_idx + 1;

    // 第1扇区透明
    if (sector_number != 1) {
        bool use_green = (mod(float(sector_number), 2.0) > 0.5);
        vec4 chosen_color = use_green ? color_green : color_orange;

        float mask = smoothstep(current_radius, current_radius - feather_px, dist);
        out_col = vec4(chosen_color.rgb, chosen_color.a * mask);

        if (index_output_mode == 1) {
            float idx_norm = float(sector_number) / float(RAY_COUNT);
            out_col.a = idx_norm;
        } else if (index_output_mode == 2) {
            float idx_norm = float(sector_number) / float(RAY_COUNT);
            out_col = vec4(vec3(idx_norm), 1.0);
            out_col.rgb *= mask;
        }
    }

    COLOR = out_col;
}
