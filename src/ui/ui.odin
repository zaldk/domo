package ui

import "core:log"
import "core:math"
import "core:mem"

Color :: [4]u8 // rgba
COLOR_BLACK    :: Color{   0,   0,   0, 0xFF }
COLOR_WHITE    :: Color{ 255, 255, 255, 0xFF }
COLOR_FG       :: Color{ 200, 200, 200, 0xFF }
COLOR_BG_DARK  :: Color{  10,  10,  10, 0xFF }
COLOR_BG       :: Color{  20,  20,  20, 0xFF }
COLOR_BG_LIGHT :: Color{  40,  40,  40, 0xFF }
COLOR_BG_TAB   :: Color{  35,  35,  45, 0xFF }

Box :: struct { x, y, w, h: i32 }

CommandType :: enum { WINDOW, RECT, TEXT, SCISSOR_ON, SCISSOR_OFF }
Command :: struct {
    type: CommandType,
    using box: Box, // .xywh for WINDOW, RECT and SCISSOR, .xy for TEXT
    title: string,  // for WINDOW
    color: Color,   // for RECT and TEXT
    text: string,   // for TEXT
    font_size: f32, // for TEXT
}

// H => left, right
// V => top, bottom
// T => [..tabs]
Part :: union { Layout, string }
LayoutType :: enum { H, V, T }
Layout :: struct {
    id: i32,
    type: LayoutType,
    parts: []Part,
    split: f32,  // H|V
    active: int, // T
    using box: Box,
}

MouseButton :: enum { LEFT }
MouseState :: enum { UP, DOWN }

HoverType :: enum { NONE, BUTTON, DRAGBAR_H, DRAGBAR_V }

CTX : ^Context
Context :: struct {
    layout: Layout,
    allocator: mem.Allocator,

    measure_text_w: proc(text: string, font_size: f32) -> (f32),
    measure_text_h: proc(text: string, font_size: f32) -> (f32),

    mouse_x, mouse_y: i32,
    scroll_dx, scroll_dy: i32,
    mouse_state: [MouseButton]MouseState,
    mouse_state_changed: bool,

    hovering_over: HoverType,
    is_moving_dragbar: bool,
    dragbar_id: i32,

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
set_measure_text_w :: proc(fn: proc(text: string, font_size: f32) -> f32) { CTX.measure_text_w = fn }
set_measure_text_h :: proc(fn: proc(text: string, font_size: f32) -> f32) { CTX.measure_text_h = fn }

get_hover :: proc(try_to_reset := false) -> HoverType {
    defer if try_to_reset && should_reset_hover() do reset_hover()
    return CTX.hovering_over
}
should_reset_hover :: proc() -> bool { return !CTX.is_moving_dragbar }
reset_hover :: proc() { CTX.hovering_over = .NONE }

cmd :: proc(type: CommandType, command: Command) {
    command := command
    command.type = type
    append(&CTX.commands, command)
}

next_command :: proc() -> (Command, bool) {
    if len(CTX.commands) > 0 do return pop_front(&CTX.commands), true
    return {}, false
}

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
    bar_border := i32(1)
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
            new_split := dragbar(b, l.id, width, height)
            if new_split > 0.01 && new_split < 0.99 {
                l.split = new_split
                b = l.box
                if l.type == .H {
                    b.x += i32(f32(b.w) * l.split) - bar_width/2
                    b.w = bar_width
                } else {
                    b.y += i32(f32(b.h) * l.split) - bar_width/2
                    b.h = bar_width
                }
            }
            cmd(.RECT, { box=b, color=COLOR_BLACK})
            if l.type == .H {
                cmd(.RECT, { box=b, x=b.x+bar_border, w=b.w-2*bar_border, color=COLOR_BG_LIGHT})
            } else {
                cmd(.RECT, { box=b, y=b.y+bar_border, h=b.h-2*bar_border, color=COLOR_BG_LIGHT})
            }

            for &part, i in l.parts {
                q := l.box
                if l.type == .H {
                    if i == 0 {
                        q.w  = i32(f32(q.w)*l.split) - bar_width/2
                    } else {
                        q.x += i32(f32(q.w)*l.split) + bar_width/2
                        q.w  = i32(f32(q.w)*(1-l.split)) - bar_width/2 + 1
                    }
                }
                if l.type == .V {
                    if i == 0 {
                        q.h  = i32(f32(q.h)*l.split) - bar_width/2
                    } else {
                        q.y += i32(f32(q.h)*l.split) + bar_width/2
                        q.h  = i32(f32(q.h)*(1-l.split)) - bar_width/2 + 1
                    }
                }
                switch &p in part {
                case Layout: p.box = q; append(&queue, &p)
                case string:
                    cmd(.SCISSOR_ON, { box=q })
                    cmd(.WINDOW, { box=q, title=p })
                    cmd(.SCISSOR_OFF, {})
                }
            }
        } else {
            assert(len(l.parts) > 0)
            assert(l.active >= 0 && l.active < len(l.parts))

            delta := i32(font_size * 0.25)
            tabbar := Box{l.x, l.y, l.w, delta*5}
            window_box := Box{l.x, l.y+tabbar.h, l.w, l.h-tabbar.h}
            sum_width := delta

            cmd(.SCISSOR_ON, { box=tabbar })
            cmd(.RECT, { box=tabbar, color=COLOR_BLACK })
            cmd(.RECT, { box=tabbar, h=tabbar.h-1, color=COLOR_BG_TAB })

            for &part, i in l.parts {
                switch p in part {
                case Layout: log.error("Layout inside .T is not supported yet."); panic("")
                case string:
                    title_width  := i32(CTX.measure_text_w(p, font_size))
                    title_height := i32(CTX.measure_text_h(p, font_size))
                    tab_title_box := Box{
                        tabbar.x + sum_width,
                        tabbar.y + tabbar.h - title_height,
                        title_width+delta*2,
                        title_height,
                    }

                    state, action := button(tab_title_box)
                    if action do l.active = i

                    tab_title_box_inner := tab_title_box
                    tab_title_box_inner.x += 1
                    tab_title_box_inner.y += 1
                    tab_title_box_inner.w -= 2
                    tab_title_box_inner.h -= 2

                    cmd(.RECT, { box=tab_title_box, color=COLOR_BLACK})
                    cmd(.RECT, { box=tab_title_box_inner, color=l.active == i ? COLOR_BG : button_colors[state]})
                    cmd(.TEXT, { text=p, x=tab_title_box.x+delta, y=tab_title_box.y, font_size=font_size, color=COLOR_FG })

                    sum_width += tab_title_box.w + delta
                }
            }
            cmd(.SCISSOR_OFF, {})

            cmd(.SCISSOR_ON, { box=window_box })
            cmd(.WINDOW, { box=window_box, title=l.parts[l.active].(string) })
            cmd(.SCISSOR_OFF, {})
        }
    }
}

CheckCollisionPointRec :: proc(x,y: i32, box: Box) -> bool {
    return box.x <= x && x <= box.x+box.w && box.y <= y && y <= box.y+box.h
}

// 0=normal 1=hover 2=press
button :: proc(box: Box) -> (state: i32, action: bool) {
    if CheckCollisionPointRec(CTX.mouse_x, CTX.mouse_y, box) {
        CTX.hovering_over = .BUTTON
        state = 1 + i32(CTX.mouse_state[.LEFT] == .DOWN)
        action = CTX.mouse_state_changed && CTX.mouse_state[.LEFT] == .DOWN
    } else { state = 0 }

    return
}

dragbar :: proc(box: Box, id: i32, window_w, window_h: i32) -> (split: f32 = -1) {
    mouse_in_box := CheckCollisionPointRec(CTX.mouse_x, CTX.mouse_y, box)
    if mouse_in_box do CTX.hovering_over = box.w > box.h ? .DRAGBAR_V : .DRAGBAR_H

    if !CTX.is_moving_dragbar && mouse_in_box && CTX.mouse_state[.LEFT] == .DOWN {
        CTX.is_moving_dragbar = true
        CTX.dragbar_id = id
    }
    if CTX.is_moving_dragbar &&
        CTX.mouse_state[.LEFT] == .UP {
        CTX.is_moving_dragbar = false
    }

    if CTX.is_moving_dragbar && id == CTX.dragbar_id {
        if box.w > box.h {
            split = f32(CTX.mouse_y) / f32(window_h)
        } else {
            split = f32(CTX.mouse_x) / f32(window_w)
        }
    }

    return
}

layout :: proc(ctx: ^Context, type: LayoutType, parts: ..Part, split := f32(0), active_tab := 0) -> Layout {
    split := split
    if split < 0 || split > 1 {
        new_split := math.clamp(split, 0, 1)
        log.warnf("Splits must be in the range 0.0 to 1.0, got: %v, using: %v", split, new_split)
        split = new_split
    }
    _parts := make([]Part, len(parts), ctx.allocator)
    for p, i in parts do _parts[i] = p
    return { get_uid(), type, _parts, split, active_tab, {} }
}
h :: proc(split: f32, top, bottom: Part) -> Layout { return layout(CTX, .H, top, bottom, split=split) }
v :: proc(split: f32, left, right: Part) -> Layout { return layout(CTX, .V, left, right, split=split) }
t :: proc(tabs: ..Part, active_tab := 0) -> Layout { return layout(CTX, .T, ..tabs, active_tab=active_tab) }

UI__UID_COUNTER := i32(1)
get_uid :: proc() -> i32 {
    UI__UID_COUNTER += 1
    return UI__UID_COUNTER
}
