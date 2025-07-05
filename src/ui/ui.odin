package ui

import "core:log"
import "core:math"
import rl "vendor:raylib"

SplitID :: distinct i32

// H is a Horizontal line
// V is a Vertical line
// T is Tabs
LayoutType :: enum { H, V, T }
Layout :: struct {
    type: LayoutType,

    // H|V
    split: f32,
    parts: []SplitPart,

    // T
    active_tab: int,
    tabs: []string,
}

AABB :: struct { x, y, w, h: i32 }

SplitPart :: union { Layout, string } // strings are leaf nodes
Context :: struct {
    renderers: map[string]WindowRenderer,
    layout: Layout,
    aabb: AABB,
    font_size: f32,
}

WindowRenderer :: #type proc(title: string, font_size: f32, x, y, w, h: i32)
DEFAULT_RENDERER :: proc(title: string, font_size: f32, x, y, w, h: i32) {
    tw := i32(math.ceil(MEASURE_TEXT_WIDTH(title, font_size)))
    th := i32(math.ceil(MEASURE_TEXT_HEIGHT(title, font_size)))

    DRAW_RECT({x,y,w,h}, {1,0,0,.25})
    DRAW_RECT_LINES({x+1,y+1,w-1,h-1}, {1,0,0,1})

    DRAW_RECT({x + w/2 - tw/2, y + h/2 - th/2, tw, th}, {0,1,0,.25})
    DRAW_RECT_LINES({x + w/2 - tw/2 + 1, y + h/2 - th/2 + 1, tw-1, th-1}, {0,1,0,1})

    DRAW_TEXT(title, {x + w/2 - tw/2, y + h/2 - th/2}, font_size, {1,1,1,1})
}
set_renderer :: proc(ctx: ^Context, title: string, renderer: WindowRenderer) {
    ctx.renderers[title] = renderer
}

DrawRect :: #type proc(aabb: [4]i32, color: [4]f32)
DRAW_RECT : DrawRect
set_draw_rect :: proc(fn: DrawRect) { DRAW_RECT = fn }

DrawRectLines :: #type proc(aabb: [4]i32, color: [4]f32)
DRAW_RECT_LINES : DrawRectLines
set_draw_rect_lines :: proc(fn: DrawRectLines) { DRAW_RECT_LINES = fn }

DrawText :: #type proc(text: string, pos: [2]i32, size: f32, color: [4]f32)
DRAW_TEXT : DrawText
set_draw_text :: proc(fn: DrawText) { DRAW_TEXT = fn }

MeasureTextWidth :: #type proc(text: string, size: f32) -> f32
MEASURE_TEXT_WIDTH : MeasureTextWidth
set_measure_text_width :: proc(fn: MeasureTextWidth)  { MEASURE_TEXT_WIDTH = fn }

MeasureTextHeight :: #type proc(text: string, size: f32) -> f32
MEASURE_TEXT_HEIGHT : MeasureTextHeight
set_measure_text_height :: proc(fn: MeasureTextHeight) { MEASURE_TEXT_HEIGHT = fn }

BeginScissorMode :: #type proc(x, y, w, h: i32)
BEGIN_SCISSOR_MODE : BeginScissorMode
set_begin_scissor_mode :: proc(fn: BeginScissorMode)  { BEGIN_SCISSOR_MODE = fn }

EndScissorMode :: #type proc()
END_SCISSOR_MODE : EndScissorMode
set_end_scissor_mode :: proc(fn: EndScissorMode)  { END_SCISSOR_MODE = fn }

init :: proc(x, y, width, height: i32, font_size: f32) -> Context {
    renderers := make(map[string]WindowRenderer)
    return {
        aabb = {x, y, width, height},
        renderers = renderers,
        layout = {},
        font_size = font_size,
    }
}

destroy :: proc(ctx: ^Context) {
    delete(ctx.renderers)
    destroy_layout(&ctx.layout)
}

destroy_layout :: proc(layout: ^Layout) {
    for tab in layout.parts {
        if t, ok := tab.(Layout); ok {
            destroy_layout(&t)
        }
    }
    delete(layout.parts)
}

h :: proc(ctx: ^Context, split: f32, top: SplitPart, bottom: SplitPart, allocator := context.allocator) -> Layout {
    sps := make([]SplitPart, 2, allocator)
    sps[0] = top
    sps[1] = bottom
    return { type = .H, split = split, parts = sps }
}

v :: proc(ctx: ^Context, split: f32, left: SplitPart, right: SplitPart, allocator := context.allocator) -> Layout {
    sps := make([]SplitPart, 2, allocator)
    sps[0] = left
    sps[1] = right
    return { type = .V, split = split, parts = sps }
}

t :: proc(ctx: ^Context, tabs: ..string, allocator := context.allocator) -> Layout {
    return { type = .T, tabs = tabs }
}

render :: proc(ctx: ^Context, layout: Layout) {
    ctx.layout = layout
    l := ctx.layout
    separator_girth := i32(8)

    if l.type == .H || l.type == .V {
        if len(l.parts) != 2 do return
        for t, i in l.parts {
            part_ctx := ctx^
            if l.type == .H {
                if i == 0 { // top
                    part_ctx.aabb.h = i32(f32(part_ctx.aabb.h) * l.split)
                }
                if i == 1 { // bottom
                    part_ctx.aabb.y+= i32(f32(part_ctx.aabb.h) * l.split)
                    part_ctx.aabb.h = i32(f32(part_ctx.aabb.h) * (1-l.split))
                    part_ctx.aabb.y += separator_girth/2
                }
                part_ctx.aabb.h -= separator_girth/2
            }
            if l.type == .V {
                if i == 0 { // left
                    part_ctx.aabb.w = i32(f32(part_ctx.aabb.w) * l.split)
                }
                if i == 1 { // right
                    part_ctx.aabb.x+= i32(f32(part_ctx.aabb.w) * l.split)
                    part_ctx.aabb.w = i32(f32(part_ctx.aabb.w) * (1-l.split))
                    part_ctx.aabb.x += separator_girth/2
                }
                part_ctx.aabb.w -= separator_girth/2
            }

            switch t in l.parts[i] {
            case string:
                renderer, ok := part_ctx.renderers[t]
                if !ok do renderer = DEFAULT_RENDERER
                BEGIN_SCISSOR_MODE(part_ctx.aabb.x, part_ctx.aabb.y, part_ctx.aabb.w, part_ctx.aabb.h)
                renderer(t, part_ctx.font_size, part_ctx.aabb.x, part_ctx.aabb.y, part_ctx.aabb.w, part_ctx.aabb.h)
                END_SCISSOR_MODE()

            case Layout:
                render(&part_ctx, t)
            }
            if i == 1 {
                ab := part_ctx.aabb
                s := separator_girth
                if l.type == .H {
                    DRAW_RECT({ ab.x, ab.y-s, ab.w, s, }, {.3,.3,.3,1})
                    DRAW_RECT_LINES({ ab.x+1, ab.y-s+1, ab.w-1, s-1, }, {1,1,1,1})
                }
                if l.type == .V {
                    DRAW_RECT({ ab.x-s, ab.y, s, ab.h, }, {.3,.3,.3,1})
                    DRAW_RECT_LINES({ ab.x-s+1, ab.y+1, s-1, ab.h-1, }, {1,1,1,1})
                }
            }
        }
        return
    }

    // l.type == .T
    if len(l.tabs) == 0 do return

    tabbar_font_size := f32(18)
    tabbar_height := i32(tabbar_font_size * 1.25)
    tabbar_aabb := AABB{ctx.aabb.x, ctx.aabb.y, ctx.aabb.w, tabbar_height}

    DRAW_RECT({tabbar_aabb.x,tabbar_aabb.y,tabbar_aabb.w,tabbar_aabb.h}, {0,0,1,.25})
    DRAW_RECT_LINES({tabbar_aabb.x,tabbar_aabb.y,tabbar_aabb.w,tabbar_aabb.h}, {0,0,1,1})
    total_width : f32 = tabbar_font_size/2
    BEGIN_SCISSOR_MODE(tabbar_aabb.x,tabbar_aabb.y,tabbar_aabb.w,tabbar_aabb.h)
    for t in l.tabs {
        DRAW_TEXT(t, { ctx.aabb.x + i32(total_width), ctx.aabb.y + tabbar_height-i32(tabbar_font_size) }, tabbar_font_size, {1,1,1,1})
        tw := MEASURE_TEXT_WIDTH(t, tabbar_font_size)
        total_width += tw + tabbar_font_size
    }
    END_SCISSOR_MODE()

    tab_ctx := ctx^
    tab_ctx.aabb.h -= tabbar_height
    tab_ctx.aabb.y += tabbar_height

    _delta := int(rl.GetTime())
    t := l.tabs[(l.active_tab + _delta) % len(l.tabs)]
    renderer, ok := tab_ctx.renderers[t]
    if !ok do renderer = DEFAULT_RENDERER
    BEGIN_SCISSOR_MODE(tab_ctx.aabb.x, tab_ctx.aabb.y, tab_ctx.aabb.w, tab_ctx.aabb.h)
    renderer(t, tab_ctx.font_size, tab_ctx.aabb.x, tab_ctx.aabb.y, tab_ctx.aabb.w, tab_ctx.aabb.h)
    END_SCISSOR_MODE()
}
