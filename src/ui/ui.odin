package ui

SplitID :: distinct int

LayoutType :: enum { H, V, T }
Layout :: struct {
    type: LayoutType,
    split: f32,
    tabs: []SplitPart
}

// strings are leaf nodes
SplitPart :: union { Layout, string }

RENDERER_MAP : map[string]WindowRenderer

init :: proc(allocator := context.allocator) {
    RENDERER_MAP = make(map[string]WindowRenderer, allocator)
}
destroy :: proc() {
    delete(RENDERER_MAP)
}
destroy_layout :: proc(layout: ^Layout) {
    for tab in layout.tabs {
        if t, ok := tab.(Layout); ok {
            destroy_layout(&t)
        }
    }
    delete(layout.tabs)
}

h :: proc(split: f32, left: SplitPart, right: SplitPart, allocator := context.allocator) -> Layout {
    sps := make([]SplitPart, 2, allocator)
    sps[0] = left
    sps[1] = right
    return { type = .H, split = split, tabs = sps }
}

v :: proc(split: f32, top: SplitPart, bottom: SplitPart, allocator := context.allocator) -> Layout {
    sps := make([]SplitPart, 2, allocator)
    sps[0] = top
    sps[1] = bottom
    return { type = .V, split = split, tabs = sps }
}

t :: proc(tabs: ..string, allocator := context.allocator) -> Layout {
    sps := make([]SplitPart, len(tabs), allocator)
    for t, i in tabs do sps[i] = t
    return { type = .T, tabs = sps }
}

WindowRenderer :: #type proc(title: string, width, height: f32)
set_renderer :: proc(title: string, renderer: WindowRenderer) {
    RENDERER_MAP[title] = renderer
}

/*
These operate on the following unit screen:

(0,1) (1,1)
(0,0) (1,0)

*/

DrawRect :: #type proc(aabb: [4]f32, color: [4]f32)
draw_rect : proc(aabb: [4]f32, color: [4]f32)
set_draw_rect :: proc(fn: DrawRect) { draw_rect = fn }

DrawText :: #type proc(pos: [2]f32, size: f32, color: [4]f32)
draw_text : proc(pos: [2]f32, size: f32, color: [4]f32)
set_draw_text :: proc(fn: DrawText) { draw_text = fn }

render :: proc(layout: Layout) {

}
