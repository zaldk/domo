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

CTX : Context
Context :: struct {
    x, y, w, h: i32,
    font_size: f32,
    title: string,
    allocator: mem.Allocator,
    commands: [1024]Command,
}

Command :: struct {
    type: CommandType,
    input: CommandInput,
}
CommandType :: enum {
    DRAW_RECT,
    DRAW_TEXT,
    BEGIN_SCISSOR_MODE,
    END_SCISSOR_MODE,
}
CommandInput :: union {
    DrawRect,
    DrawText,
    BeginScissorMode,
    EndScissorMode,
}
DrawRect :: struct { aabb: [4]i32, color: [4]f32 }
DrawText :: struct { text: string, pos: [2]i32, font_size: f32, color: [4]f32 }
BeginScissorMode :: struct { x, y, w, h: i32 }
EndScissorMode :: struct {}

WindowRenderer :: #type proc(ctx: ^Context, title: string, x,y,w,h: i32, font_size: f32)

MeasureTextWidth :: #type proc(text: string, size: f32) -> f32
MeasureTextHeight :: #type proc(text: string, size: f32) -> f32
GetMouseX :: #type proc() -> i32
GetMouseY :: #type proc() -> i32
GetMouseWheelMoveX :: #type proc() -> f32
GetMouseWheelMoveY :: #type proc() -> f32
IsMouseButtonDown :: #type proc(button: i32) -> bool
IsMouseButtonPressed :: #type proc(button: i32) -> bool

init :: proc(width, height: i32, title: string, font_size: f32, allocator := context.allocator) {
    CTX.w = width
    CTX.h = height
    CTX.font_size = font_size
    CTX.title = title
    CTX.allocator = allocator
}

destroy_layout :: proc(layout: ^Layout) {
    for part in layout.parts {
        if p, ok := part.(Layout); ok {
            destroy_layout(&p)
        }
    }
    // delete(layout.parts)
}

layout :: proc(ctx: ^Context, type: LayoutType, parts: ..Part, split := f32(0), active_tab := 0) -> Layout {
    _parts := make([]Part, len(parts), ctx.allocator)
    for p, i in parts do _parts[i] = p
    return { type, _parts, split, active_tab }
}
h :: proc(split: f32, top, bottom: Part) -> Layout { return layout(&CTX, .H, top, bottom, split=split)      }
v :: proc(split: f32, left, right: Part) -> Layout { return layout(&CTX, .V, left, right, split=split)      }
t :: proc(tabs: ..Part, active_tab := 0) -> Layout { return layout(&CTX, .T, ..tabs, active_tab=active_tab) }

render :: proc(layout: Layout) {
    _render(&CTX, layout)
    _render :: proc(ctx: ^Context, l: Layout) {
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
                case Layout: _render(&part_ctx, t)
                case string:
                    log.infof("RENDER (%v)", t)
                    // _renderer, ok := part_ctx._renderers[t]
                    // if !ok do _renderer = DEFAULT__renderER
                    // ctx.begin_scissor_mode(part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h)
                    // renderer(&part_ctx, t, part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h, part_ctx.font_size)
                    // ctx.end_scissor_mode()
                }
            }
            return
        } else {
            log.infof("RENDER (%v of %v)", l.parts[l.active], l.parts)
        }
    }
}

// render :: proc(ctx: ^Context, layout: Layout) {
//     l := layout
//     separator_girth := i32(8)
//
//     if l.type == .H || l.type == .V {
//         if len(l.parts) != 2 do return
//         for t, i in l.parts {
//             part_ctx := ctx^
//             if l.type == .H {
//                 if i == 0 { // top
//                     part_ctx.h = i32(f32(part_ctx.h) * l.split)
//                 }
//                 if i == 1 { // bottom
//                     part_ctx.y += i32(f32(part_ctx.h) * l.split)
//                     part_ctx.h  = i32(f32(part_ctx.h) * (1-l.split))
//                     part_ctx.y += separator_girth/2
//                 }
//                 part_ctx.h -= separator_girth/2
//             }
//             if l.type == .V {
//                 if i == 0 { // left
//                     part_ctx.w = i32(f32(part_ctx.w) * l.split)
//                 }
//                 if i == 1 { // right
//                     part_ctx.x += i32(f32(part_ctx.w) * l.split)
//                     part_ctx.w  = i32(f32(part_ctx.w) * (1-l.split))
//                     part_ctx.x += separator_girth/2
//                 }
//                 part_ctx.w -= separator_girth/2
//             }
//
//             switch t in l.parts[i] {
//             case Layout: render(&part_ctx, t)
//             case string:
//                 renderer, ok := part_ctx.renderers[t]
//                 if !ok do renderer = DEFAULT_RENDERER
//                 ctx.begin_scissor_mode(part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h)
//                 renderer(&part_ctx, t, part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h, part_ctx.font_size)
//                 ctx.end_scissor_mode()
//             }
//             if i == 1 {
//                 ab := [?]i32{part_ctx.x, part_ctx.y, part_ctx.w, part_ctx.h}
//                 s := separator_girth
//                 if l.type == .H {
//                     ctx.draw_rect({ab.x, ab.y-s  , ab.z, s  }, {0,0,0,1})
//                     ctx.draw_rect({ab.x, ab.y-s+1, ab.z, s-2}, {.3,.3,.3,1})
//                 }
//                 if l.type == .V {
//                     ctx.draw_rect({ab.x-s  , ab.y, s  , ab.w}, {0,0,0,1})
//                     ctx.draw_rect({ab.x-s+1, ab.y, s-2, ab.w}, {.3,.3,.3,1})
//                 }
//             }
//         }
//         return
//     } // else: l.type == .T
//
//     if len(l.parts) == 0 do return
//
//     tabbar_font_size := f32(18)
//     tabbar_height := i32(tabbar_font_size * 1.25)
//     tabbar := [?]i32{ ctx.x, ctx.y, ctx.w, tabbar_height }
//
//     ctx.draw_rect({tabbar.x,tabbar.y,tabbar.z,tabbar.w}, {0,0,0,.25})
//     // ctx.draw_rect_lines(tabbar.x+1,tabbar.y+1,tabbar_width-1,tabbar_height-1, 0,0,1,1)
//     total_width : f32 = tabbar_font_size/2
//     space_width := ctx.measure_text_width(" ", tabbar_font_size)
//     ctx.begin_scissor_mode(tabbar.x,tabbar.y,tabbar.z,tabbar_height)
//     for t in l.parts {
//         tw := ctx.measure_text_width(t.(string), tabbar_font_size)
//         th := ctx.measure_text_height(t.(string), tabbar_font_size)
//         defer total_width += tw + tabbar_font_size/2
//         text_pos := [2]i32{ ctx.x + i32(total_width), ctx.y + tabbar_height-i32(tabbar_font_size) }
//         box_delta := i32(tabbar_font_size/4)
//         ctx.draw_rect({text_pos.x-box_delta, text_pos.y, i32(tw)+box_delta*2, i32(th)}, {0,.3,.3,1})
//         ctx.draw_text(t.(string), text_pos.x, text_pos.y, tabbar_font_size, 1,1,1,1)
//     }
//     ctx.end_scissor_mode()
//
//     tab_ctx := ctx^
//     tab_ctx.h -= tabbar_height
//     tab_ctx.y += tabbar_height
//
//     _delta := int(rl.GetTime())
//     t := l.parts[(l.active + _delta) % len(l.parts)]
//     renderer, ok := tab_ctx.renderers[t.(string)]
//     if !ok do renderer = DEFAULT_RENDERER
//     ctx.begin_scissor_mode(tab_ctx.x, tab_ctx.y, tab_ctx.w, tab_ctx.h)
//     renderer(&tab_ctx, t.(string), tab_ctx.x, tab_ctx.y, tab_ctx.w, tab_ctx.h, tab_ctx.font_size)
//     ctx.end_scissor_mode()
// }
