shader_type canvas_item;

uniform float skew = 0.2; // 倾斜程度
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // 背景颜色

void fragment() {
    // 基础 UV
    vec2 uv = UV;
    
    // 核心算法：根据 Y 轴位置偏移 X 轴读取位置
    // 1.0 - uv.y 是为了让底部向左斜，还是向右斜，取决于你的需求
    // 这里实现：上方靠右，下方靠左
    float x_offset = (1.0 - uv.y) * skew;
    
    // 修正 UV
    // 我们实际上不需要修正纹理读取，而是要裁剪边缘
    // 简单的平行四边形逻辑：
    
    // 计算当前像素在斜切后的相对位置
    // 这种写法比较简单：利用 step 函数裁剪左右边缘
    
    float width = 1.0 - skew; // 内容区域的有效宽度比例
    float left_edge = (1.0 - uv.y) * skew;
    float right_edge = left_edge + width;
    
    if (uv.x < left_edge || uv.x > right_edge) {
        COLOR.a = 0.0; // 裁剪掉，变透明
    } else {
        COLOR = color; // 显示颜色
    }
}