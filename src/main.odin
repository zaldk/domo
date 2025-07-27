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
    ui.set_draw_rect(proc(x,y,w,h: i32, color: [4]u8) { rl.DrawRectangle(x,y,w,h, rl.Color(color)) })
    ui.set_draw_text(proc(text: string, x,y: i32, font_size: f32, color: [4]u8) {
        cstr := strings.clone_to_cstring(text)
        defer delete(cstr)
        rl.DrawText(cstr, x,y, i32(font_size), rl.Color(color))
    })
    ui.set_begin_scissor(proc(x,y,w,h: i32) { rl.BeginScissorMode(x,y,w,h) })
    ui.set_end_scissor(proc() { rl.EndScissorMode() })
    ui.set_measure_text_w(proc(text: string, font_size: f32) -> f32 {
        cstr := strings.clone_to_cstring(text)
        defer delete(cstr)
        return rl.MeasureTextEx(rl.GetFontDefault(), cstr, font_size, 1.0).x
    })
    ui.set_measure_text_h(proc(text: string, font_size: f32) -> f32 {
        cstr := strings.clone_to_cstring(text)
        defer delete(cstr)
        return rl.MeasureTextEx(rl.GetFontDefault(), cstr, font_size, 1.0).x
    })

    ui.set_layout(
        ui.v(.5,
            ui.h(.25, "A", "B"),
            ui.h(.5, "1", "2")))
    // ui.set_layout(
    //     ui.t("a",
    //         "A",
    //         ui.t("b",
    //             "1",
    //             "2",
    //             "3"),
    //         "B"))
    // ui.set_layout(
    //     ui.h(.25,
    //         ui.v(.75,
    //             "Source",
    //             "Console"),
    //         ui.v(.50,
    //             ui.t("A", "Breakpoints", "Commands", "Struct", "Exe"),
    //             ui.t("B", "Stack", "Files", "Registers", "Data", "Thread"))))



    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(WIDTH, HEIGHT, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(144)
    scale_global(0)
    defer { for i in 0..<NUM_SCALES { if FONTS[i] != {} { rl.UnloadFont(FONTS[i]) } } }

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground({255,0,255,255}) // pink for debug purposes, should not see anyway

        WIDTH  = rl.GetScreenWidth()
        HEIGHT = rl.GetScreenHeight()

        ui.update_mouse_position(i32(rl.GetMousePosition().x), i32(rl.GetMousePosition().y))
        ui.update_mouse_button_state(.LEFT, rl.IsMouseButtonDown(.LEFT) ? .DOWN : .UP)
        ui.update_mouse_wheel(i32(rl.GetMouseWheelMoveV().x), i32(rl.GetMouseWheelMoveV().y))

        ui.render(WIDTH, HEIGHT, FONT_SIZE)
        for c in ui.CTX.commands {
            rl.DrawRectangle(c.x,c.y,c.w,c.h, COLOR_BG)
            t := rl.MeasureText(strings.unsafe_string_to_cstring(c.title), i32(FONT_SIZE))
            rl.DrawText(strings.unsafe_string_to_cstring(c.title), c.x+c.w/2-t/2, c.y+c.h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
        }

        rl.DrawFPS(0, 0)
        rl.EndDrawing()
        defer free_all(context.temp_allocator)

        // break
    }
}

COLOR_BG :: rl.Color { 20, 20, 20, 255 }
COLOR_FG :: rl.Color { 200, 200, 200, 255 }

// get_renderer :: proc(title: string) -> ui.Renderer {
//     return {
//         title = title,
//         fn = proc(title: string, x,y,w,h: i32) {
//             rl.DrawRectangle(x,y,w,h, COLOR_BG)
//             t := rl.MeasureText(strings.unsafe_string_to_cstring(title), i32(FONT_SIZE))
//             rl.DrawText(strings.unsafe_string_to_cstring(title), x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//         }
//     }
// }

// Source :: ui.Renderer{
//     title = "Source",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Source", i32(FONT_SIZE))
//         rl.DrawText("Source", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Console :: ui.Renderer{
//     title = "Console",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Console", i32(FONT_SIZE))
//         rl.DrawText("Console", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Breakpoints :: ui.Renderer{
//     title = "Breakpoints",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Breakpoints", i32(FONT_SIZE))
//         rl.DrawText("Breakpoints", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Commands :: ui.Renderer{
//     title = "Commands",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Commands", i32(FONT_SIZE))
//         rl.DrawText("Commands", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Struct :: ui.Renderer{
//     title = "Struct",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Struct", i32(FONT_SIZE))
//         rl.DrawText("Struct", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Exe :: ui.Renderer{
//     title = "Exe",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Exe", i32(FONT_SIZE))
//         rl.DrawText("Exe", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Stack :: ui.Renderer{
//     title = "Stack",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Stack", i32(FONT_SIZE))
//         rl.DrawText("Stack", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Files :: ui.Renderer{
//     title = "Files",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Files", i32(FONT_SIZE))
//         rl.DrawText("Files", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Registers :: ui.Renderer{
//     title = "Registers",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Registers", i32(FONT_SIZE))
//         rl.DrawText("Registers", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Data :: ui.Renderer{
//     title = "Data",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Data", i32(FONT_SIZE))
//         rl.DrawText("Data", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
// Thread :: ui.Renderer{
//     title = "Thread",
//     fn = proc(x,y,w,h: i32) {
//         rl.DrawRectangle(x,y,w,h, COLOR_BG)
//         t := rl.MeasureText("Thread", i32(FONT_SIZE))
//         rl.DrawText("Thread", x+w/2-t/2, y+h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
//     }
// }
