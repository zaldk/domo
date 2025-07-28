package ui

import "core:log"
import "core:math"
import "core:mem"

Color :: [4]u8 // rgba
COLOR_BLACK    :: Color{   0,   0,   0, 255 }
COLOR_WHITE    :: Color{ 255, 255, 255, 255 }
COLOR_FG       :: Color{ 200, 200, 200, 255 }
COLOR_BG_DARK  :: Color{   5,   5,   5, 255 }
COLOR_BG       :: Color{  20,  20,  20, 255 }
COLOR_BG_LIGHT :: Color{  40,  40,  40, 255 }

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
    using box: Box,
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

    is_hovering_over_buttons: bool,
    is_hovering_over_dragbars: bool,
    is_moving_dragbar: bool,

    commands: [dynamic]Command,
}

free_context :: proc() {
    free_layout(CTX.layout)
    delete(CTX.commands)
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

init_context :: proc(allocator := context.allocator) {
    CTX = new_clone(Context{ allocator=allocator })
    CTX.commands = make([dynamic]Command, CTX.allocator)
}
set_layout :: proc(layout: Layout) { CTX.layout = layout }
set_draw_rect      :: proc(fn: proc(x,y,w,h: i32, color: [4]u8))                           { CTX.draw_rect      = fn }
set_draw_text      :: proc(fn: proc(text: string, x,y: i32, font_size: f32, color: [4]u8)) { CTX.draw_text      = fn }
set_begin_scissor  :: proc(fn: proc(x,y,w,h: i32))                                         { CTX.begin_scissor  = fn }
set_end_scissor    :: proc(fn: proc())                                                     { CTX.end_scissor    = fn }
set_measure_text_w :: proc(fn: proc(text: string, font_size: f32) -> f32)                  { CTX.measure_text_w = fn }
set_measure_text_h :: proc(fn: proc(text: string, font_size: f32) -> f32)                  { CTX.measure_text_h = fn }

update_mouse_position :: proc(x, y: i32) { CTX.mouse_x=x; CTX.mouse_y=y }
update_mouse_wheel :: proc(dx, dy: i32) { CTX.scroll_dx=dx; CTX.scroll_dy=dy }
update_mouse_button_state :: proc(button: MouseButton, state: MouseState) {
    CTX.mouse_state_changed = CTX.mouse_state[button] != state
    CTX.mouse_state[button] = state
}

render :: proc(width, height: i32, font_size: f32) {
    queue := make([dynamic]^Layout, CTX.allocator)
    defer delete(queue)
    CTX.layout.box = Box{0,0,width,height}
    append(&queue, &CTX.layout)

    bar_width := i32(font_size * 0.2)
    button_colors := [?]Color{COLOR_BG_LIGHT, COLOR_BG_DARK, COLOR_BG}

    for len(queue) > 0 {
        l := pop_front(&queue)

        if l.type == .H || l.type == .V {
            assert(len(l.parts) == 2)
            assert(l.split != 0)

            b := l.box
            if l.type == .H {
                b.x += i32(f32(b.w) * l.split) - bar_width/2
                b.w = bar_width
            } else {
                b.y += i32(f32(b.h) * l.split) - bar_width/2
                b.h = bar_width
            }
            new_split := dragbar(b, width, height)
            if new_split > 0 && new_split < 1 do l.split = new_split
            if l.type == .H {
                CTX.draw_rect(b.x, b.y, b.w, b.h, COLOR_BLACK)
                CTX.draw_rect(b.x+1, b.y, b.w-2, b.h, COLOR_BG_LIGHT)
            } else {
                CTX.draw_rect(b.x, b.y, b.w, b.h, COLOR_BLACK)
                CTX.draw_rect(b.x, b.y+1, b.w, b.h-2, COLOR_BG_LIGHT)
            }

            for &part, i in l.parts {
                q := l.box
                if l.type == .H {
                    if i == 0 {
                        q.w  = i32(f32(q.w)*l.split) - bar_width/2
                    } else {
                        q.x += i32(f32(q.w)*l.split) + bar_width/2
                        q.w  = i32(f32(q.w)*(1-l.split)) - bar_width/2
                    }
                }
                if l.type == .V {
                    if i == 0 {
                        q.h  = i32(f32(q.h)*l.split) - bar_width/2
                    } else {
                        q.y += i32(f32(q.h)*l.split) + bar_width/2
                        q.h  = i32(f32(q.h)*(1-l.split)) - bar_width/2
                    }
                }
                switch &p in part {
                case Layout: p.box = q; append(&queue, &p)
                case string: append(&CTX.commands, Command{ q, p })
                }
            }
        } else {
            assert(len(l.parts) > 0)
            assert(l.active >= 0 && l.active < len(l.parts))

            delta := i32(font_size * 0.25)
            tabbar := Box{l.x, l.y, l.w, delta*5}
            window := Box{l.x, l.y+tabbar.h, l.w, l.h-tabbar.h}
            sum_width := delta

            CTX.draw_rect(tabbar.x, tabbar.y, tabbar.w, tabbar.h, COLOR_BLACK)
            CTX.draw_rect(tabbar.x, tabbar.y, tabbar.w, tabbar.h-1, COLOR_BG_LIGHT)

            for &part, i in l.parts {
                switch p in part {
                case Layout: log.error("Layout inside .T is not supported yet."); panic("")
                case string:
                    title_width  := i32(CTX.measure_text_w(p, font_size))
                    title_height := i32(CTX.measure_text_h(p, font_size))
                    tab_title_box := Box{
                        tabbar.x + sum_width,
                        tabbar.y+tabbar.h-title_height,
                        title_width+delta*2,
                        title_height,
                    }

                    state, action := button(tab_title_box)
                    if action do l.active = i

                    CTX.draw_rect(tab_title_box.x, tab_title_box.y, tab_title_box.w, tab_title_box.h, COLOR_BLACK)
                    CTX.draw_rect(tab_title_box.x+1, tab_title_box.y+1, tab_title_box.w-2, tab_title_box.h-2,
                        l.active == i ? COLOR_BG : button_colors[state] )
                    CTX.draw_text(p, tab_title_box.x+delta, tab_title_box.y, font_size, COLOR_FG)
                    sum_width += tab_title_box.w + delta
                }
            }

            append(&CTX.commands, Command{ window, l.parts[l.active].(string) })
        }
    }
}

CheckCollisionPointRec :: proc(x,y: i32, box: Box) -> bool {
    return box.x <= x && x <= box.x+box.w && box.y <= y && y <= box.y+box.h
}

// 0=normal 1=hover 2=press
button :: proc(box: Box) -> (state: i32, action: bool) {
    if CheckCollisionPointRec(CTX.mouse_x, CTX.mouse_y, box) {
        CTX.is_hovering_over_buttons = true
        state = 1 + i32(CTX.mouse_state[.LEFT] == .DOWN)
        action = CTX.mouse_state_changed && CTX.mouse_state[.LEFT] == .DOWN
    } else { state = 0 }

    return
}

dragbar :: proc(box: Box, window_w, window_h: i32) -> (split: f32 = -1) {
    if CheckCollisionPointRec(CTX.mouse_x, CTX.mouse_y, box) {
        CTX.is_hovering_over_dragbars = true
        if CTX.mouse_state[.LEFT] == .DOWN {
            if box.w > box.h {
                split = f32(CTX.mouse_y) / f32(window_h)
            } else {
                split = f32(CTX.mouse_x) / f32(window_w)
            }
        }
    }

    return
}

layout :: proc(ctx: ^Context, type: LayoutType, parts: ..Part, split := f32(0), active_tab := 0) -> Layout {
    _parts := make([]Part, len(parts), ctx.allocator)
    for p, i in parts do _parts[i] = p
    return { type, _parts, split, active_tab, {} }
}
h :: proc(split: f32, top, bottom: Part) -> Layout { return layout(CTX, .H, top, bottom, split=split) }
v :: proc(split: f32, left, right: Part) -> Layout { return layout(CTX, .V, left, right, split=split) }
t :: proc(tabs: ..Part, active_tab := 0) -> Layout { return layout(CTX, .T, ..tabs, active_tab=active_tab) }
