package ui

import "core:log"
import "core:math"
import "core:mem"
import rl "vendor:raylib"

Renderer :: #type proc(x, y, w, h: i32)

// H => left, right
// V => top, bottom
// T => [..tabs]
LayoutType :: enum { H, V, T }
Part :: union { Layout, Renderer }
Layout :: struct {
    type: LayoutType,
    parts: []Part,
    split: f32,  // H|V
    active: int, // T
}

Window :: struct {
    x,y,w,h: i32,
    renderer: Renderer,
}

Bar :: struct {
    x,y,w,h: i32,
}

MouseButton :: enum { LEFT }
MouseState :: enum { UP, DOWN }

CTX : ^Context
Context :: struct {
    layout: Layout,
    allocator: mem.Allocator,

    mouse_x, mouse_y: i32,
    scroll_dx, scroll_dy: i32,
    mouse_state: [MouseButton]MouseState,
    mouse_state_changed: bool,

    layout_windows: [dynamic]Window,
    layout_bars: [dynamic]Bar,
}

free_context :: proc(ctx: ^Context) {
    free_layout(ctx.layout)
    delete(ctx.layout_windows)
    delete(ctx.layout_bars)
    free(CTX, CTX.allocator)
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
    return CTX
}
set_layout :: proc(layout: Layout) {
    CTX.layout = layout
    CTX.layout_windows = make([dynamic]Window)
    CTX.layout_bars = make([dynamic]Bar)
}

update_mouse_position :: proc(x, y: i32) { CTX.mouse_x=x; CTX.mouse_y=y }
update_mouse_wheel :: proc(dx, dy: i32) { CTX.scroll_dx=dx; CTX.scroll_dy=dy }
update_mouse_button_state :: proc(button: MouseButton, state: MouseState) {
    CTX.mouse_state_changed = CTX.mouse_state[button] != state
    CTX.mouse_state[button] = state
}

expand_layout :: proc(width, height: i32, font_size: f32) {
    // finds all windows and splitting bars and inserts them into CTX

    l := CTX.layout
    Box :: struct { x, y, w, h: i32 }

    helper(l, {0, 0, width, height}, font_size)
    helper :: proc(l: Layout, b: Box, font_size: f32) {
        bar_width := i32(font_size * 0.2 / 2)
        if len(l.parts) == 0 do return
        switch {
        case l.type == .H || l.type == .V:
            if len(l.parts) != 2 {
                log.warnf("Split [%v] has [%v] out of 2 parts (%v)", l.type, len(l.parts), l)
                break
            }
            if l.split == 0 {
                log.warnf("Split [%v] has zero split (%v)", l.type, l)
                break
            }
            for part, i in l.parts {
                q := b
                switch {
                case l.type == .H && i == 0: q.w = i32(f32(q.w)*l.split) - bar_width
                case l.type == .H && i == 1:
                    q.x += i32(f32(q.w)*l.split) + bar_width
                    q.w = i32(f32(q.w)*(1-l.split)) - bar_width
                case l.type == .V && i == 0: q.h = i32(f32(q.h)*l.split) - bar_width
                case l.type == .V && i == 1:
                    q.y += i32(f32(q.h)*l.split) + bar_width
                    q.h = i32(f32(q.h)*(1-l.split)) - bar_width
                }
                switch p in part {
                case Renderer: append(&CTX.layout_windows, Window{q.x,q.y,q.w,q.h,p})
                case Layout: helper(p, q, font_size)
                }
            }
        case l.type == .T:
            part := l.parts[l.active]
            switch p in part {
            case Renderer: append(&CTX.layout_windows, Window{b.x,b.y,b.w,b.h, p})
            case Layout: helper(p, b, font_size)
            }
        }
    }
}

render :: proc(WIDTH, HEIGHT: i32, FONT_SIZE: f32) {
    expand_layout(WIDTH, HEIGHT, FONT_SIZE)
    // log.infof("\n%#v", CTX)
    for w in CTX.layout_windows {
        w.renderer(w.x, w.y, w.w, w.h)
    }
    clear(&CTX.layout_windows)
}

layout :: proc(ctx: ^Context, type: LayoutType, parts: ..Part, split := f32(0), active_tab := 0) -> Layout {
    _parts := make([]Part, len(parts), ctx.allocator)
    for p, i in parts do _parts[i] = p
    return { type, _parts, split, active_tab }
}
h :: proc(split: f32, top, bottom: Part) -> Layout { return layout(CTX, .H, top, bottom, split=split)      }
v :: proc(split: f32, left, right: Part) -> Layout { return layout(CTX, .V, left, right, split=split)      }
t :: proc(tabs: ..Part, active_tab := 0) -> Layout { return layout(CTX, .T, ..tabs, active_tab=active_tab) }
