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
@(rodata) SCALES := [?]f32{0.25, 0.33, 0.5, 0.67, 0.75, 1.0, 1.25, 1.33, 1.5, 1.75, 2.0}
SCALE : f32 = 1.0
SCALE_INDEX := 5
SCALE_DELTA := 0

FONT_RAW := #load("./resources/iosevka.ttf", string)
FONT_SIZE : f32 : 30
FONT : rl.Font
FONTS : [NUM_SCALES]rl.Font

Theme :: enum{DARK=0, LIGHT}
THEME : Theme = .DARK

WIDTH  : i32 = 1000
HEIGHT : i32 = 1000

main :: proc() {
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



    ctx := ui.init_context()
    defer ui.free_context(ctx)
    ui.set_layout(
        ui.h(.75,
            ui.v(.75,
                Source,
                Console),
            ui.v(.50,
                ui.t(Breakpoints, Commands, Struct, Exe),
                ui.t(Stack, Files, Registers, Data, Thread))))

    // ui.render(WIDTH, HEIGHT, FONT_SIZE)
    //
    // if true do return


    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(WIDTH, HEIGHT, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(144)
    scale_global(0)
    defer { for i in 0..<NUM_SCALES { if FONTS[i] != {} { rl.UnloadFont(FONTS[i]) } } }

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground({0,0,0,255})

        WIDTH  = rl.GetScreenWidth()
        HEIGHT = rl.GetScreenHeight()

        ui.update_mouse_position(i32(rl.GetMousePosition().x), i32(rl.GetMousePosition().y))
        ui.update_mouse_button_state(.LEFT, rl.IsMouseButtonDown(.LEFT) ? .DOWN : .UP)
        ui.update_mouse_wheel(i32(rl.GetMouseWheelMoveV().x), i32(rl.GetMouseWheelMoveV().y))

        ui.render(WIDTH, HEIGHT, FONT_SIZE)

        rl.DrawFPS(0, 0)
        rl.EndDrawing()
        defer free_all(context.temp_allocator)
    }
}

Source      :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Source",      x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Console     :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Console",     x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Breakpoints :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Breakpoints", x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Commands    :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Commands",    x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Struct      :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Struct",      x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Exe         :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Exe",         x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Stack       :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Stack",       x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Files       :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Files",       x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Registers   :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Registers",   x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Data        :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Data",        x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
Thread      :: proc(x,y,w,h: i32) { rl.DrawRectangle(x,y,w,h, {50,50,50,255}); rl.DrawText("Thread",      x+w/2, y+h/2, i32(FONT_SIZE), {200,200,200,255}) }
