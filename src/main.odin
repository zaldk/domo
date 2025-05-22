package main

import "core:fmt"
import "core:mem"
import "core:log"
import rl "vendor:raylib"

DOMO_VERSION :: #config(DOMO_VERSION, "N/A")

NUM_SCALES :: len(SCALES)
SCALES := [?]f32{0.25, 0.33, 0.5, 0.67, 0.75, 1.0, 1.25, 1.33, 1.5, 1.75, 2.0}
SCALE : f32 = 1.0
SCALE_INDEX := 5
SCALE_DELTA := 0

FONT_RAW := #load("./resources/iosevka.ttf", string)
FONT_SIZE : f32 : 30
FONT : rl.Font
FONTS : [NUM_SCALES]rl.Font

Theme :: enum{DARK=0, LIGHT}
THEME : Theme = .DARK

TARGET_FPS :: 60
DOMO_SHOULD_CLOSE := false

main :: proc() {
    // {{{
    // {{{ Tracking + Temp. Allocator
    // track my faulty programming
    // taken from youtube.com/watch?v=dg6qogN8kIE
    tracking_allocator : mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
        for key, value in tracking_allocator.allocation_map {
            fmt.printf("[%v] %v leaked %v bytes\n", key, value.location, value.size)
        }
        for value in tracking_allocator.bad_free_array {
            fmt.printf("[%v] %v double free detected\n", value.memory, value.location)
        }
        //logfln("%#v", tracking_allocator)
        mem.tracking_allocator_clear(&tracking_allocator)
    }
    defer free_all(context.temp_allocator)
    context.logger = log.create_console_logger(opt = {.Level, .Time, .Short_File_Path, .Line, .Terminal_Color, .Procedure})
    defer log.destroy_console_logger(context.logger)
    // }}}

    parse()
    // tokens := tokenize_layout(LAYOUT)
    // defer delete(tokens)
    // parse_layout(tokens[:])

    // {{{ Initial Variables
    // rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    // rl.InitWindow(1600, 900, "FLOAT")
    // defer rl.CloseWindow()
    // rl.SetTargetFPS(TARGET_FPS * 2)

    // scale_global(0)
    // defer { for i in 0..<NUM_SCALES { if FONTS[i] != {} { rl.UnloadFont(FONTS[i]) } } }
    // }}}

    // {{{ Game Loop
    // for !(rl.WindowShouldClose() || DOMO_SHOULD_CLOSE) {
    //     if rl.IsKeyPressed(.EQUAL) { scale_global(+1) }
    //     if rl.IsKeyPressed(.MINUS) { scale_global(-1) }
    //
    //     rl.BeginDrawing()
    //     rl.ClearBackground({0,0,0,255})
    //
    //     WIDTH := f32(rl.GetScreenWidth())
    //     HEIGHT := f32(rl.GetScreenHeight())
    //
    //     tabbar_gap, tabbar_border : f32 = 8*SCALE, 3*SCALE
    //     tabbar_aabb : rl.Rectangle = {0, 0, WIDTH, f32(FONT_SIZE*SCALE) + tabbar_gap*2}
    //     sidebar_aabb : rl.Rectangle = {0, tabbar_aabb.height, 0, HEIGHT - tabbar_aabb.height}
    //
    //     switch {
    //     case _IS_HOVERING_OVER_BUTTONS: rl.SetMouseCursor(.POINTING_HAND)
    //     case: rl.SetMouseCursor(.DEFAULT)
    //     }
    //     _IS_HOVERING_OVER_BUTTONS = false
    //
    //     rl.DrawFPS(0, 0)
    //     rl.EndDrawing()
    //     defer free_all(context.temp_allocator)
    // }
    // }}}
    // }}}
}
