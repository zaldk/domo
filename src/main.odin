package main

import "core:fmt"
import "core:mem"
import "core:log"
import rl "vendor:raylib"

DOMO_VERSION :: #config(DOMO_VERSION, "N/A")
DOMO_TYPE :: #config(DOMO_TYPE, "DEV")

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

DELTA :: 16 // number of pixels that is the unit measure for positioning
TARGET_FPS :: 60

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

    // {{{ Initial Variables
    TIME_START, ok := time.time_to_datetime(time.now())
    if !ok { log.error("Could not initialize TIME_START datetime object") }

    when DOMO_TYPE == "RELEASE" {
        rl.SetTraceLogLevel(.NONE)
    } else {
        rl.SetTraceLogLevel(.ALL)
    }

    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(1600, 900, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(TARGET_FPS * 2)
    when DOMO_TYPE == "RELEASE" {
        rl.MaximizeWindow()
        rl.SetExitKey(.KEY_NULL)
    }

    scale_global(0)
    defer { for i in 0..<NUM_SCALES { if FONTS[i] != {} { rl.UnloadFont(FONTS[i]) } } }

    TIME_ACCUMULATOR = make(map[TimeMod]f32)
    TIME_SWITCH = make(map[TimeMod]bool)
    defer delete(TIME_ACCUMULATOR)
    defer delete(TIME_SWITCH)
    for tm in TimeMod {
        TIME_ACCUMULATOR[tm] = 0
        TIME_SWITCH[tm] = false
    }

    CURRENT_TAB = .DEVICE
    PREVIOUS_TAB = .DEVICE
    // }}}

    // {{{ Game Loop
    for !(rl.WindowShouldClose() || DOMO_SHOULD_CLOSE) {
        for m in TimeMod {
            if TIME_ACCUMULATOR[m] > f32(TIME_MODS[m]) / 1000 {
                TIME_ACCUMULATOR[m] = math.mod(TIME_ACCUMULATOR[m], f32(TIME_MODS[m]) / 1000)
                TIME_SWITCH[m] = true
            } else {
                TIME_SWITCH[m] = false
            }
        }
        defer for m in TimeMod {
            TIME_ACCUMULATOR[m] += rl.GetFrameTime()
        }

        if rl.IsKeyPressed(.TAB) {
            CURRENT_TAB = Tab((int(CURRENT_TAB) + int(!rl.IsKeyDown(.LEFT_SHIFT))*2-1 + len(Tab)) % len(Tab))
        }
        if rl.IsKeyPressed(.EQUAL) { scale_global(+1) }
        if rl.IsKeyPressed(.MINUS) { scale_global(-1) }

        rl.BeginDrawing()
        rl.ClearBackground({0,0,0,255})

        WIDTH := f32(rl.GetScreenWidth())
        HEIGHT := f32(rl.GetScreenHeight())

        tabbar_gap, tabbar_border : f32 = 8*SCALE, 3*SCALE
        tabbar_aabb : rl.Rectangle = {0, 0, WIDTH, f32(FONT_SIZE*SCALE) + tabbar_gap*2}
        sidebar_aabb : rl.Rectangle = {0, tabbar_aabb.height, 0, HEIGHT - tabbar_aabb.height}

        PREVIOUS_TAB = CURRENT_TAB

        rl.BeginScissorMode(0, 0, i32(tabbar_aabb.width), i32(tabbar_aabb.height))
        draw_tabbar(tabbar_aabb, tabbar_gap, tabbar_border)
        when ODIN_OS != .Windows {
            draw_tabbar_close(tabbar_aabb)
        }
        rl.EndScissorMode()

        if SIDEBAR_OPEN {
            rl.BeginScissorMode(0, i32(sidebar_aabb.y), i32(WIDTH), i32(sidebar_aabb.height))
            sidebar_aabb = draw_sidebar(tabbar_aabb.height)
            rl.EndScissorMode()
        }

        workspace_aabb : rl.Rectangle = {
            sidebar_aabb.x + sidebar_aabb.width,
            sidebar_aabb.y,
            WIDTH - sidebar_aabb.width,
            HEIGHT - tabbar_aabb.height,
        }
        rl.BeginScissorMode(
            i32(workspace_aabb.x),
            i32(workspace_aabb.y),
            i32(workspace_aabb.width),
            i32(workspace_aabb.height)
        )
        draw_workspace(workspace_aabb)
        rl.EndScissorMode()

        // on top of the workspace
        draw_sidebar_toggle(sidebar_aabb)

        switch true {
        case _IS_HOVERING_OVER_BUTTONS: rl.SetMouseCursor(.POINTING_HAND)
        case _IS_HOVERING_OVER_INPUTS: rl.SetMouseCursor(.IBEAM)
        case: rl.SetMouseCursor(.DEFAULT)
        }
        _IS_HOVERING_OVER_BUTTONS = false
        _IS_HOVERING_OVER_INPUTS = false

        when DOMO_TYPE != "RELEASE" {
            rl.DrawFPS(i32(WIDTH)-300, 0)
        }
        rl.EndDrawing()
        defer free_all(context.temp_allocator)
    }
    // }}}
    // }}}
}
