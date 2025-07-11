package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"
import "ui"
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

WIDTH  : i32 = 1000
HEIGHT : i32 = 1000

main :: proc() {
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
        mem.tracking_allocator_clear(&tracking_allocator)
    }
    defer free_all(context.temp_allocator)
    context.logger = log.create_console_logger(opt = {.Level, .Time, .Short_File_Path, .Line, .Terminal_Color, .Procedure})
    defer log.destroy_console_logger(context.logger)
    // }}}



    ctx: ui.Context
    ui.init(&ctx, WIDTH, HEIGHT, "DEMO", FONT_SIZE)
    defer ui.destroy(&ctx)

    ui.set_draw_rect(&ctx, proc(x,y,w,h: i32, r,g,b,a: f32) {
        rl.DrawRectangle(x, y, w, w, rl.ColorFromNormalized({r,g,b,a}))
    })
    ui.set_draw_text(&ctx, proc(text: string, x,y: i32, font_size: f32, r,g,b,a: f32) {
        cstr := strings.clone_to_cstring(text)
        defer delete(cstr)
        rl.DrawTextEx(FONT, cstr, {f32(x), f32(y)}, font_size, font_size/10, rl.ColorFromNormalized({r,g,b,a}))
    })
    ui.set_get_mouse_x(&ctx, proc() -> i32 { return rl.GetMouseX() })
    ui.set_get_mouse_y(&ctx, proc() -> i32 { return rl.GetMouseY() })
    ui.set_get_mouse_wheel_move_x(&ctx, proc() -> f32 { return rl.GetMouseWheelMoveV().x })
    ui.set_get_mouse_wheel_move_y(&ctx, proc() -> f32 { return rl.GetMouseWheelMoveV().y })
    ui.set_is_mouse_button_down(&ctx, proc(button: i32) -> bool { return rl.IsMouseButtonDown(rl.MouseButton(button)) })
    ui.set_is_mouse_button_pressed(&ctx, proc(button: i32) -> bool { return rl.IsMouseButtonPressed(rl.MouseButton(button)) })
    ui.set_measure_text_width(&ctx, proc(text: string, size: f32) -> f32 {
        cstr := strings.clone_to_cstring(text)
        defer delete(cstr)
        return rl.MeasureTextEx(FONT, cstr, size, size/10).x
    })
    ui.set_measure_text_height(&ctx, proc(text: string, size: f32) -> f32 {
        cstr := strings.clone_to_cstring(text)
        defer delete(cstr)
        return rl.MeasureTextEx(FONT, cstr, size, size/10).y
    })
    ui.set_begin_scissor_mode(&ctx, proc(x,y,w,h: i32) { rl.BeginScissorMode(x,y,w,h) })
    ui.set_end_scissor_mode(&ctx, proc() { rl.EndScissorMode() })

    // for window_id in ([?]string{"A","B","C","D", "1","2","3","4","5"}) {
    //     ui.set_renderer(&ctx, window_id, proc(ctx: ^ui.Context, id: string, x,y,w,h: i32, font_size: f32) {
    //         ctx.draw_rect(x,y,w,h, 0,0,0,1)
    //         ctx.draw_text(id, x+w/2, y+h/2, font_size, 1,1,1,1)
    //     })
    // }

    layout : ui.Layout = ui.v(&ctx, .60,
        ui.h(&ctx, .80,
            "A",
            ui.t(&ctx, "1", "2", "3", "4", "5"),
        ),
        ui.h(&ctx, .75,
            ui.h(&ctx, .50, "B", "C"),
            "D",
        ),
    )
    defer ui.destroy_layout(&layout)
    fmt.printf("\n%#v\n", layout)



    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(WIDTH, HEIGHT, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(TARGET_FPS * 2)
    scale_global(0)
    defer { for i in 0..<NUM_SCALES { if FONTS[i] != {} { rl.UnloadFont(FONTS[i]) } } }

    for !(rl.WindowShouldClose() || DOMO_SHOULD_CLOSE) {
        if rl.IsKeyPressed(.EQUAL) { scale_global(+1) }
        if rl.IsKeyPressed(.MINUS) { scale_global(-1) }

        rl.BeginDrawing()
        rl.ClearBackground({0,0,0,255})

        WIDTH  = rl.GetScreenWidth()
        HEIGHT = rl.GetScreenHeight()

        // tabbar_gap, tabbar_border : f32 = 8*SCALE, 3*SCALE
        // tabbar_aabb : rl.Rectangle = {0, 0, WIDTH, f32(FONT_SIZE*SCALE) + tabbar_gap*2}
        // sidebar_aabb : rl.Rectangle = {0, tabbar_aabb.height, 0, HEIGHT - tabbar_aabb.height}

        // switch {
        // case _IS_HOVERING_OVER_BUTTONS: rl.SetMouseCursor(.POINTING_HAND)
        // case: rl.SetMouseCursor(.DEFAULT)
        // }
        // _IS_HOVERING_OVER_BUTTONS = false

        // ui.update(&ctx, &layout)
        ui.render(&ctx, layout)
        // ui.render(&ctx,
        //     ui.t(&ctx,
        //         "AAA",
        //         "BBB",
        //         "CCC",
        //         "DDD",
        //         "EEE",
        //         "FFF",
        //     )
        // )
        // ui.render(&ctx,
        //     ui.h(&ctx, .75,
        //         ui.v(&ctx, .75,
        //             "Source",
        //             "Console",
        //         ),
        //         ui.v(&ctx, .50,
        //             ui.t(&ctx, "Breakpoints", "Commands", "Struct", "Exe"),
        //             ui.t(&ctx, "Stack", "Files", "Registers", "Data", "Thread"),
        //         )
        //     )
        // )

        // rl.DrawTextEx(FONT, strings.clone_to_cstring(fmt.tprintf("%v/%v", WIDTH, HEIGHT), context.temp_allocator), {0, 20}, 48, 0, rl.RAYWHITE)
        rl.DrawFPS(0, 0)
        rl.EndDrawing()
        defer free_all(context.temp_allocator)
        // break
    }
}

// window_renderer :: proc(title: string, width, height: int) {
//     rl.DrawText(strings.unsafe_string_to_cstring(title), i32(width/2), i32(height/2), 48, rl.RAYWHITE)
// }
