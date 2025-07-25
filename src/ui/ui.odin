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

    layout_windows: []Window,
    layout_bars: []Bar,
}

free_context :: proc(ctx: ^Context) {
    free_layout(ctx.layout)
    delete(ctx.layout_windows)
    delete(ctx.layout_bars)
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
    CTX^ = { allocator=allocator }
    return CTX
}
set_layout :: proc(layout: Layout) {
    CTX.layout = layout

    layout_count := count(layout)
    CTX.layout_windows = make([]Window, layout_count.x)
    CTX.layout_bars = make([]Bar, layout_count.y)

    // .x == Window   .y == Bar
    count :: proc(l: Layout) -> (result: [2]int) {
        if l.type == .H || l.type == .V do result.y += 1
        for part in l.parts {
            switch p in part {
            case Layout: result += count(p)
            case Renderer: result.x += 1
            }
        }
        return
    }
}

update_mouse_position :: proc(x, y: i32) { CTX.mouse_x=x; CTX.mouse_y=y }
update_mouse_wheel :: proc(dx, dy: i32) { CTX.scroll_dx=dx; CTX.scroll_dy=dy }
update_mouse_button_state :: proc(button: MouseButton, state: MouseState) {
    CTX.mouse_state_changed = CTX.mouse_state[button] != state
    CTX.mouse_state[button] = state
}

expand_layout :: proc() {
    // finds all windows and splitting bars and inserts them into CTX

    l := CTX.layout
    Box :: struct { x, y, w, h: i32 }

    helper :: proc(l: Layout, b: Box) {
        @(static) window_index := 0
        if len(l.parts) > 0 {
            switch l.type {
            case .H, .V:
                
            case .T:
                part := l.parts[l.active]
                switch p in part {
                case Renderer: CTX.layout_windows[window_index] = {b.x,b.y,b.w,b.h, p}; window_index += 1
                case Layout: helper(p, b)
                }
            }
        }
    }
}

render :: proc(WIDTH, HEIGHT: i32, FONT_SIZE: f32) {
    expand_layout()
    for w in CTX.layout_windows {
        w.renderer(w.x, w.y, w.w, w.h)
    }
}

layout :: proc(ctx: ^Context, type: LayoutType, parts: ..Part, split := f32(0), active_tab := 0) -> Layout {
    _parts := make([]Part, len(parts), ctx.allocator)
    for p, i in parts do _parts[i] = p
    return { type, _parts, split, active_tab }
}
h :: proc(split: f32, top, bottom: Part) -> Layout { return layout(CTX, .H, top, bottom, split=split)      }
v :: proc(split: f32, left, right: Part) -> Layout { return layout(CTX, .V, left, right, split=split)      }
t :: proc(tabs: ..Part, active_tab := 0) -> Layout { return layout(CTX, .T, ..tabs, active_tab=active_tab) }
