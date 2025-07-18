package ui

import "core:log"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

SplitID :: distinct i32

// H => top, bottom
// V => left, right
// T => [..tabs]
LayoutType :: enum { H, V, T }
Part :: union { Layout, string }
Layout :: struct {
    type: LayoutType,
    parts: []Part,
    split: f32, // H|V
    active: int, // T
}

Context :: struct {
    x, y, w, h: i32,
    font_size: f32,
    title: string,
    renderers: map[string]WindowRenderer,
    allocator: mem.Allocator,

    draw_rect: DrawRect,
    draw_text: DrawText,
    measure_text_width: MeasureTextWidth,
    measure_text_height: MeasureTextHeight,
    begin_scissor_mode: BeginScissorMode,
    end_scissor_mode: EndScissorMode,
    get_mouse_x: GetMouseX,
    get_mouse_y: GetMouseY,
    get_mouse_wheel_move_x: GetMouseWheelMoveX,
    get_mouse_wheel_move_y: GetMouseWheelMoveY,
    is_mouse_button_down: IsMouseButtonDown,
    is_mouse_button_pressed: IsMouseButtonPressed,
}

WindowRenderer :: #type proc(ctx: ^Context, title: string, x,y,w,h: i32, font_size: f32)
DEFAULT_RENDERER :: proc(ctx: ^Context, title: string, x,y,w,h: i32, font_size: f32) {
    tw := i32(math.ceil(ctx.measure_text_width(title, font_size)))
    th := i32(math.ceil(ctx.measure_text_height(title, font_size)))

    ctx.draw_rect({x,y,w,h}, {1,0,0,.25})
    // ctx.draw_rect_lines({x+1,y+1,w-1,h-1}, {1,0,0,1})

    ctx.draw_rect({x + w/2 - tw/2, y + h/2 - th/2, tw, th}, {0,1,0,.25})
    // ctx.draw_rect_lines({x + w/2 - tw/2 + 1, y + h/2 - th/2 + 1, tw-1, th-1}, {0,1,0,1})

    ctx.draw_text(title, x + w/2 - tw/2, y + h/2 - th/2, font_size, 1,1,1,1)
}
set_renderer :: proc(ctx: ^Context, title: string, renderer: WindowRenderer) {
    ctx.renderers[title] = renderer
}

DrawRect :: #type proc(aabb: [4]i32, color: [4]f32)
set_draw_rect :: proc(ctx: ^Context, fn: DrawRect) { ctx.draw_rect = fn }

DrawText :: #type proc(text: string, x,y: i32, font_size: f32, r,g,b,a: f32)
set_draw_text :: proc(ctx: ^Context, fn: DrawText) { ctx.draw_text = fn }

MeasureTextWidth :: #type proc(text: string, size: f32) -> f32
set_measure_text_width :: proc(ctx: ^Context, fn: MeasureTextWidth)  { ctx.measure_text_width = fn }

MeasureTextHeight :: #type proc(text: string, size: f32) -> f32
set_measure_text_height :: proc(ctx: ^Context, fn: MeasureTextHeight) { ctx.measure_text_height = fn }

BeginScissorMode :: #type proc(x, y, w, h: i32)
set_begin_scissor_mode :: proc(ctx: ^Context, fn: BeginScissorMode)  { ctx.begin_scissor_mode = fn }

EndScissorMode :: #type proc()
set_end_scissor_mode :: proc(ctx: ^Context, fn: EndScissorMode)  { ctx.end_scissor_mode = fn }

GetMouseX :: #type proc() -> i32
set_get_mouse_x :: proc(ctx: ^Context, fn: GetMouseX) { ctx.get_mouse_x = fn }

GetMouseY :: #type proc() -> i32
set_get_mouse_y :: proc(ctx: ^Context, fn: GetMouseY) { ctx.get_mouse_x = fn }

GetMouseWheelMoveX :: #type proc() -> f32
set_get_mouse_wheel_move_x :: proc(ctx: ^Context, fn: GetMouseWheelMoveX) { ctx.get_mouse_wheel_move_x = fn }

GetMouseWheelMoveY :: #type proc() -> f32
set_get_mouse_wheel_move_y :: proc(ctx: ^Context, fn: GetMouseWheelMoveY) { ctx.get_mouse_wheel_move_x = fn }

IsMouseButtonDown :: #type proc(button: i32) -> bool
set_is_mouse_button_down :: proc(ctx: ^Context, fn: IsMouseButtonDown) { ctx.is_mouse_button_down = fn }

IsMouseButtonPressed :: #type proc(button: i32) -> bool
set_is_mouse_button_pressed :: proc(ctx: ^Context, fn: IsMouseButtonPressed) { ctx.is_mouse_button_pressed = fn }

init :: proc(ctx: ^Context, width, height: i32, title: string, font_size: f32, allocator := context.allocator) {
    ctx.w = width
    ctx.h = height
    ctx.font_size = font_size
    ctx.title = title
    ctx.allocator = allocator
    ctx.renderers = make(map[string]WindowRenderer, allocator)
}

destroy :: proc(ctx: ^Context) {
    delete(ctx.renderers)
}

destroy_layout :: proc(layout: ^Layout) {
    for tab in layout.parts {
        if t, ok := tab.(Layout); ok {
            destroy_layout(&t)
        }
    }
    delete(layout.parts)
}

h :: proc(ctx: ^Context, split: f32, top: Part, bottom: Part) -> Layout {
    sps := make([]Part, 2, ctx.allocator)
    sps[0] = top; sps[1] = bottom
    return { type = .H, split = split, parts = sps }
}
v :: proc(ctx: ^Context, split: f32, left: Part, right: Part) -> Layout {
    sps := make([]Part, 2, ctx.allocator)
    sps[0] = left; sps[1] = right
    return { type = .V, split = split, parts = sps }
}
t :: proc(ctx: ^Context, tabs: ..string) -> Layout {
    l := Layout { type = .T, parts = make([]Part, len(tabs), ctx.allocator) }
    for t, i in tabs do l.parts[i] = t
    return l
}


render :: proc(ctx: ^Context, layout: Layout) {
    l := layout
    separator_girth := i32(8)

    if l.type == .H || l.type == .V {
        if len(l.parts) != 2 do return
        for t, i in l.parts {
            part_ctx := ctx^
            if l.type == .H {
                if i == 0 { // top
                    part_ctx.h = i32(f32(part_ctx.h) * l.split)
                }
                if i == 1 { // bottom
                    part_ctx.y += i32(f32(part_ctx.h) * l.split)
                    part_ctx.h  = i32(f32(part_ctx.h) * (1-l.split))
                    part_ctx.y += separator_girth/2
                }
                part_ctx.h -= separator_girth/2
            }
            if l.type == .V {
                if i == 0 { // left
                    part_ctx.w = i32(f32(part_ctx.w) * l.split)
                }
                if i == 1 { // right
                    part_ctx.x += i32(f32(part_ctx.w) * l.split)
                    part_ctx.w  = i32(f32(part_ctx.w) * (1-l.split))
                    part_ctx.x += separator_girth/2
                }
                part_ctx.w -= separator_girth/2
            }

            switch t in l.parts[i] {
            case Layout: render(&part_ctx, t)
            case string:
                renderer, ok := part_ctx.renderers[t]
                if !ok do renderer = DEFAULT_RENDERER
                ctx.begin_scissor_mode(part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h)
                renderer(&part_ctx, t, part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h, part_ctx.font_size)
                ctx.end_scissor_mode()
            }
            if i == 1 {
                ab := [?]i32{part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h}
                s := separator_girth
                if l.type == .H {
                    ctx.draw_rect({ab.x, ab.y-s  , ab.z, s  }, {0,0,0,1})
                    ctx.draw_rect({ab.x, ab.y-s+1, ab.z, s-2}, {.3,.3,.3,1})
                }
                if l.type == .V {
                    ctx.draw_rect({ab.x-s  , ab.y, s  , ab.w}, {0,0,0,1})
                    ctx.draw_rect({ab.x-s+1, ab.y, s-2, ab.w}, {.3,.3,.3,1})
                }
            }
        }
        return
    } // else: l.type == .T

    if len(l.parts) == 0 do return

    tabbar_font_size := f32(18)
    tabbar_height := i32(tabbar_font_size * 1.25)
    tabbar := [?]i32{ ctx.x, ctx.y, ctx.w, tabbar_height }

    ctx.draw_rect({tabbar.x,tabbar.y,tabbar.z,tabbar.w}, {0,0,0,.25})
    // ctx.draw_rect_lines(tabbar.x+1,tabbar.y+1,tabbar_width-1,tabbar_height-1, 0,0,1,1)
    total_width : f32 = tabbar_font_size/2
    space_width := ctx.measure_text_width(" ", tabbar_font_size)
    ctx.begin_scissor_mode(tabbar.x,tabbar.y,tabbar.z,tabbar_height)
    for t in l.parts {
        tw := ctx.measure_text_width(t.(string), tabbar_font_size)
        th := ctx.measure_text_height(t.(string), tabbar_font_size)
        defer total_width += tw + tabbar_font_size/2
        text_pos := [2]i32{ ctx.x + i32(total_width), ctx.y + tabbar_height-i32(tabbar_font_size) }
        box_delta := i32(tabbar_font_size/4)
        ctx.draw_rect({text_pos.x-box_delta, text_pos.y, i32(tw)+box_delta*2, i32(th)}, {0,.3,.3,1})
        ctx.draw_text(t.(string), text_pos.x, text_pos.y, tabbar_font_size, 1,1,1,1)
    }
    ctx.end_scissor_mode()

    tab_ctx := ctx^
    tab_ctx.h -= tabbar_height
    tab_ctx.y += tabbar_height

    _delta := int(rl.GetTime())
    t := l.parts[(l.active + _delta) % len(l.parts)]
    renderer, ok := tab_ctx.renderers[t.(string)]
    if !ok do renderer = DEFAULT_RENDERER
    ctx.begin_scissor_mode(tab_ctx.x, tab_ctx.y, tab_ctx.w, tab_ctx.h)
    renderer(&tab_ctx, t.(string), tab_ctx.x, tab_ctx.y, tab_ctx.w, tab_ctx.h, tab_ctx.font_size)
    ctx.end_scissor_mode()
}
