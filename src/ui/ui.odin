package ui

import "core:log"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

Box :: struct { x, y, w, h: i32 }

Command :: struct {
    using box: Box,
    title: string,
}

// H => left, right
// V => top, bottom
// T => [..tabs]
Part :: union { Layout, string }
LayoutType :: enum { H, V, T }
Layout :: struct {
    type: LayoutType,
    parts: []Part,
    split: f32,  // H|V
    active: int, // T
    box: Box,
    title: string,
}

BarType :: enum { H, V }
Bar :: struct {
    type: BarType,
    box: Box,
}

MouseButton :: enum { LEFT }
MouseState :: enum { UP, DOWN }

CTX : ^Context
Context :: struct {
    layout: Layout,
    allocator: mem.Allocator,

    draw_rect: proc(x,y,w,h: i32, color: [4]u8),
    draw_text: proc(text: string, x,y: i32, font_size: f32, color: [4]u8),
    begin_scissor: proc(x,y,w,h: i32),
    end_scissor: proc(),
    measure_text_w: proc(text: string, font_size: f32) -> (f32),
    measure_text_h: proc(text: string, font_size: f32) -> (f32),

    mouse_x, mouse_y: i32,
    scroll_dx, scroll_dy: i32,
    mouse_state: [MouseButton]MouseState,
    mouse_state_changed: bool,

    commands: [dynamic]Command,
}

free_context :: proc(ctx: ^Context) {
    free_layout(ctx.layout)
    delete(ctx.commands)
    free(ctx, ctx.allocator)
}
free_layout :: proc(l: Layout) {
    if len(l.parts) > 0 {
        for part in l.parts {
            if p, ok := part.(Layout); ok { free_layout(p) }
        }
        delete(l.parts)
    }
}

init_context :: proc(allocator := context.allocator) -> ^Context {
    CTX = new_clone(Context{ allocator=allocator })
    CTX.commands = make([dynamic]Command)
    return CTX
}
set_layout :: proc(layout: Layout) {
    CTX.layout = layout
}
set_draw_rect :: proc(fn: proc(x,y,w,h: i32, color: [4]u8)) { CTX.draw_rect = fn }
set_draw_text :: proc(fn: proc(text: string, x,y: i32, font_size: f32, color: [4]u8)) { CTX.draw_text = fn }
set_begin_scissor :: proc(fn: proc(x,y,w,h: i32)) { CTX.begin_scissor = fn }
set_end_scissor   :: proc(fn: proc())             { CTX.end_scissor   = fn }
set_measure_text_w :: proc(fn: proc(text: string, font_size: f32) -> f32) { CTX.measure_text_w = fn }
set_measure_text_h :: proc(fn: proc(text: string, font_size: f32) -> f32) { CTX.measure_text_h = fn }

update_mouse_position :: proc(x, y: i32) { CTX.mouse_x=x; CTX.mouse_y=y }
update_mouse_wheel :: proc(dx, dy: i32) { CTX.scroll_dx=dx; CTX.scroll_dy=dy }
update_mouse_button_state :: proc(button: MouseButton, state: MouseState) {
    CTX.mouse_state_changed = CTX.mouse_state[button] != state
    CTX.mouse_state[button] = state
}

render :: proc(width, height: i32, font_size: f32) {
    queue := make([dynamic]Layout)
    defer delete(queue)
    CTX.layout.box = Box{0,0,width,height}
    append(&queue, CTX.layout)

    bar_width := i32(font_size * 0.2)

    for len(queue) > 0 {
        l := pop_front(&queue)

        if l.type == .H || l.type == .V {
            assert(len(l.parts) == 2)
            assert(l.split != 0)
            for part, i in l.parts {
                q := l.box
                if l.type == .H && i == 0 {
                    q.w  = i32(f32(q.w)*l.split) - bar_width/2
                }
                if l.type == .H && i == 1 {
                    q.x += i32(f32(q.w)*l.split) + bar_width/2
                    q.w  = i32(f32(q.w)*(1-l.split)) - bar_width/2
                }
                if l.type == .V && i == 0 {
                    q.h  = i32(f32(q.h)*l.split) - bar_width/2
                }
                if l.type == .V && i == 1 {
                    q.y += i32(f32(q.h)*l.split) + bar_width/2
                    q.h  = i32(f32(q.h)*(1-l.split)) - bar_width/2
                }
                switch &p in part {
                case Layout: p.box = q; append(&queue, p)
                case string: append(&CTX.commands, Command{ q, p })
                }
            }
        } else {
            assert(len(l.parts) > 0)
            // tabs := make([]string, len(l.parts))
            for part, i in l.parts {
                switch p in part {
                case Layout: append(&queue, p)
                case string: append(&CTX.commands, Command{ l.box, p })
                }
            }
        }
    }
}

// expand_layout :: proc(width, height: i32, font_size: f32) {
//     // finds all windows and splitting bars and inserts them into CTX
//
//     l := CTX.layout
//
//     helper(l, {0, 0, width, height}, font_size)
//
//     helper_split :: proc(l: Layout, b: Box, font_size: f32) {}
//     helper_tab   :: proc(l: Layout, b: Box, font_size: f32, tabs: []string) {}
//
//     helper :: proc(l: Layout, b: Box, font_size: f32) {
//         bar_width := i32(font_size * .2)
//         if len(l.parts) == 0 do return
//         switch {
//         case l.type == .H || l.type == .V:
//             if len(l.parts) != 2 {
//                 log.warnf("Split [%v] has [%v] out of 2 parts (%v)", l.type, len(l.parts), l)
//                 break
//             }
//             if l.split == 0 {
//                 log.warnf("Split [%v] has zero split (%v)", l.type, l)
//                 break
//             }
//             if l.type == .H do append(&CTX.layout_bars, Bar{.H, {
//                 b.x + i32(f32(b.w)*l.split) - bar_width/2,
//                 b.y,
//                 bar_width,
//                 b.h,
//             }})
//             if l.type == .V do append(&CTX.layout_bars, Bar{.V, {
//                 b.x,
//                 b.y + i32(f32(b.h)*l.split) - bar_width/2,
//                 b.w,
//                 bar_width,
//             }})
//             for part, i in l.parts {
//                 q := b
//                 if l.type == .H && i == 0 {
//                     q.w  = i32(f32(q.w)*l.split) - bar_width/2
//                 }
//                 if l.type == .H && i == 1 {
//                     q.x += i32(f32(q.w)*l.split) + bar_width/2
//                     q.w  = i32(f32(q.w)*(1-l.split)) - bar_width/2
//                 }
//                 if l.type == .V && i == 0 {
//                     q.h  = i32(f32(q.h)*l.split) - bar_width/2
//                 }
//                 if l.type == .V && i == 1 {
//                     q.y += i32(f32(q.h)*l.split) + bar_width/2
//                     q.h  = i32(f32(q.h)*(1-l.split)) - bar_width/2
//                 }
//                 switch p in part {
//                 case Renderer: append(&CTX.layout_split_windows, SplitWindow{ box=q, renderer=p })
//                 case Layout: helper(p, q, font_size)
//                 }
//             }
//         case l.type == .T:
//             part := l.parts[l.active]
//             tabbar_height := i32(font_size * 1.5)
//             q := b; q.h -= tabbar_height; q.y += tabbar_height
//             switch p in part {
//             case Renderer: append(&CTX.layout_tab_windows, TabWindow{ box=q, renderer=p })
//             case Layout: helper(p, q, font_size)
//             }
//         }
//     }
// }

// render :: proc(WIDTH, HEIGHT: i32, FONT_SIZE: f32) {
//     expand_layout(WIDTH, HEIGHT, FONT_SIZE)
//     // log.infof("\n%#v\n", CTX)
//     for b in CTX.layout_bars {
//         CTX.draw_rect(b.box.x, b.box.y, b.box.w, b.box.h, {0,0,0,255})
//         if b.type == .H do CTX.draw_rect(b.box.x+1, b.box.y, b.box.w-2, b.box.h, {100,100,100,255})
//         if b.type == .V do CTX.draw_rect(b.box.x, b.box.y+1, b.box.w, b.box.h-2, {100,100,100,255})
//     }
//     for w in CTX.layout_split_windows {
//         CTX.begin_scissor(w.box.x, w.box.y, w.box.w, w.box.h)
//         w.renderer.fn(w.renderer.title, w.box.x, w.box.y, w.box.w, w.box.h)
//         CTX.end_scissor()
//     }
//     for w in CTX.layout_tab_windows {
//         CTX.begin_scissor(w.box.x, w.box.y, w.box.w, w.box.h)
//         w.renderer.fn(w.renderer.title, w.box.x, w.box.y, w.box.w, w.box.h)
//         CTX.end_scissor()
//     }
//     clear(&CTX.layout_split_windows)
//     clear(&CTX.layout_bars)
// }

layout :: proc(ctx: ^Context, type: LayoutType, parts: ..Part, split := f32(0), active_tab := 0, title := "") -> Layout {
    _parts := make([]Part, len(parts), ctx.allocator)
    for p, i in parts do _parts[i] = p
    return { type, _parts, split, active_tab, {}, title }
}
h :: proc(split: f32, top, bottom: Part) -> Layout { return layout(CTX, .H, top, bottom, split=split) }
v :: proc(split: f32, left, right: Part) -> Layout { return layout(CTX, .V, left, right, split=split) }
t :: proc(title: string, tabs: ..Part, active_tab := 0) -> Layout {
    return layout(CTX, .T, ..tabs, active_tab=active_tab, title=title)
}
