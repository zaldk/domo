package main

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"
import "base:intrinsics"

_IS_HOVERING_OVER_BUTTONS := false
button :: proc(aabb: rl.Rectangle) -> (state: int, action: bool) {
    state = 0       // 0=normal 1=hover 2=press
    action = false

    if rl.CheckCollisionPointRec(rl.GetMousePosition(), aabb) {
        _IS_HOVERING_OVER_BUTTONS = true
        state = 1 + int(rl.IsMouseButtonDown(.LEFT))
        action = rl.IsMouseButtonPressed(.LEFT)
    } else { state = 0 }

    return
}

draw_text :: proc(text: string, pos: [2]f32, color: rl.Color = {}, font_size: f32 = FONT_SIZE) {
    text_cstr := strings.clone_to_cstring(text)
    defer delete(text_cstr)
    rl.DrawTextEx(FONT, text_cstr, pos, font_size * SCALE, 0, color == {} ? TW(.NEUTRAL0) : color)
}

// axis := { align_x = 0|1, align_y = 0|1 }
draw_text_align :: proc(text: string, aabb: rl.Rectangle, axis: [2]f32, color: rl.Color = {}, font_size: f32 = FONT_SIZE) {
    text_sizes := measure_text(text, font_size)
    draw_text(text, {aabb.x, aabb.y} + 0.5 * axis * {
        (aabb.width  - text_sizes[0]),
        (aabb.height - text_sizes[1]),
    }, color, font_size)
}

draw_text_center :: proc(text: string, aabb: rl.Rectangle, color: rl.Color = {}, font_size: f32 = FONT_SIZE) {
    draw_text_align(text, aabb, {1,1}, color, font_size)
}

draw_button :: proc(title: string, aabb: rl.Rectangle, bg, fg: rl.Color, border_width: f32) {
    rl.DrawRectangleRec(aabb, bg)
    rl.DrawRectangleLinesEx(aabb, border_width, fg)
    draw_text_center(title, aabb)
}

measure_text :: proc(text: string, text_size: f32 = FONT_SIZE) -> [2]f32 {
    return rl.MeasureTextEx(FONT, strings.unsafe_string_to_cstring(text), text_size * SCALE, 0)
}

// delta [+N or -N] == [scale UP or scale DOWN] N times
scale_global :: proc(delta: int) -> int {
    // {{{
    if SCALE_INDEX + delta > NUM_SCALES-1 { return 1 }
    if SCALE_INDEX + delta < 0 { return 2 }

    SCALE_INDEX += delta
    SCALE = SCALES[SCALE_INDEX]
    FONT  = FONTS[SCALE_INDEX]
    if FONT == {} {
        FONTS[SCALE_INDEX] = rl.LoadFontFromMemory(
            ".ttf",
            raw_data(FONT_RAW[:]),
            i32(len(FONT_RAW)),
            i32(FONT_SIZE * SCALES[SCALE_INDEX]),
            raw_data(CODEPOINTS[:]),
            len(CODEPOINTS),
        )
        rl.GenTextureMipmaps(&FONTS[SCALE_INDEX].texture)
        rl.SetTextureFilter(FONTS[SCALE_INDEX].texture, .BILINEAR)
        FONT = FONTS[SCALE_INDEX]
    }

    return 0
    // }}}
}

hash :: proc(i: u32) -> (o: u32) {
    // {{{
    o = i
    o = ((o >> 16) ~ o) * 0x45d9f3b
    o = ((o >> 16) ~ o) * 0x45d9f3b
    o = (o >> 16) ~ o
    return
    // }}}
}
