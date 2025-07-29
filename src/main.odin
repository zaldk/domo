package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"
import "ui"
import rl "vendor:raylib"

DOMO_VERSION :: #config(DOMO_VERSION, "N/A")

FONT_RAW := #load("./resources/iosevka.ttf", string)
FONT_SIZE : f32 : 30
FONT : rl.Font

COLOR_BG :: rl.Color { 20, 20, 20, 255 }
COLOR_FG :: rl.Color { 200, 200, 200, 255 }

WIDTH  : i32 = 800
HEIGHT : i32 = 600

main :: proc() {
    when ODIN_DEBUG {
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
        context.logger = log.create_console_logger(opt = {.Level, .Time, .Short_File_Path, .Line, .Terminal_Color})
        defer log.destroy_console_logger(context.logger)
    }



    ui.init_context()
    defer ui.free_context()

    // Provide procedures for measuring text
    ui.set_measure_text_w(proc(text: string, font_size: f32) -> f32 {
        return rl.MeasureTextEx(FONT, strings.unsafe_string_to_cstring(text), font_size, 0).x
    })
    ui.set_measure_text_h(proc(text: string, font_size: f32) -> f32 {
        return rl.MeasureTextEx(FONT, strings.unsafe_string_to_cstring(text), font_size, 0).y
    })

    // Set the layout to render
    // h(SPLIT, LEFT, RIGHT) // SPLIT is 0.0 .. 1.0; LEFT, RIGHT are either `string` or h/v/t
    // v(SPLIT, TOP, BOTTOM) // SPLIT is 0.0 .. 1.0; LEFT, RIGHT are either `string` or h/v/t
    // t(TAB_1, TAB_2, ...)  // TABs can only be `string` - TODO: fix to allow h/v/t as well
    ui.set_layout(
        ui.v(.75,
            ui.h(.80,
                "Source",
                ui.v(.50,
                    ui.t("Exe", "Breakpoints", "Commands", "Struct"),
                    ui.t("Stack", "Files", "Thread", "CmdSearch"))),
            ui.h(.65,
                "Console",
                ui.t("Watch", "Locals", "Registers", "Data"))))



    // Raylib-specific
    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(WIDTH, HEIGHT, "FLOAT")
    defer rl.CloseWindow()
    rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
    { // load the iosevka font
        FONT = rl.LoadFontFromMemory(
            ".ttf",
            raw_data(FONT_RAW[:]),
            i32(len(FONT_RAW)),
            i32(FONT_SIZE),
            raw_data(CODEPOINTS[:]),
            len(CODEPOINTS),
        )
        rl.GenTextureMipmaps(&FONT.texture)
        rl.SetTextureFilter(FONT.texture, .BILINEAR)
    }
    defer rl.UnloadFont(FONT)

    for !rl.WindowShouldClose() {
        WIDTH  = rl.GetScreenWidth()
        HEIGHT = rl.GetScreenHeight()

        // Raylib-specific
        rl.BeginDrawing()
        defer rl.EndDrawing()
        when ODIN_DEBUG {
            rl.ClearBackground({255,0,255,255})
        } else {
            rl.ClearBackground({0,0,0,255})
        }

        // Change the cursor style
        switch ui.get_hover() {
        case .BUTTON: rl.SetMouseCursor(.POINTING_HAND)
        case .DRAGBAR_H: rl.SetMouseCursor(.RESIZE_EW)
        case .DRAGBAR_V: rl.SetMouseCursor(.RESIZE_NS)
        case .NONE: rl.SetMouseCursor(.DEFAULT)
        }
        if ui.should_reset_hover() do ui.reset_hover()

        // Update mouse info
        ui.update_mouse_position(i32(rl.GetMousePosition().x), i32(rl.GetMousePosition().y))
        ui.update_mouse_button_state(.LEFT, rl.IsMouseButtonDown(.LEFT) ? .DOWN : .UP)
        ui.update_mouse_wheel(i32(rl.GetMouseWheelMoveV().x), i32(rl.GetMouseWheelMoveV().y))

        // Render the layout
        ui.render(WIDTH, HEIGHT, FONT_SIZE)

        // Implement command calls however you wish
        for {
            // `c` contains the type and all possible inputs, but only some are guaranteed to be set
            c, ok := ui.next_command(); if !ok do break
            switch c.type {
            case .WINDOW:
                // Decide how to render each window yourself,
                // this draws the title in the center of the window
                rl.DrawRectangle(c.x,c.y,c.w,c.h, COLOR_BG)
                t := rl.MeasureText(strings.unsafe_string_to_cstring(c.title), i32(FONT_SIZE))
                rl.DrawText(strings.unsafe_string_to_cstring(c.title), c.x+c.w/2-t/2, c.y+c.h/2-i32(FONT_SIZE)/2, i32(FONT_SIZE), COLOR_FG)
            case .RECT: rl.DrawRectangle(c.x,c.y,c.w,c.h, rl.Color(c.color))
            case .TEXT: rl.DrawTextEx(FONT, strings.unsafe_string_to_cstring(c.text), {f32(c.x),f32(c.y)}, c.font_size, 0, rl.Color(c.color))
            case .SCISSOR_ON: rl.BeginScissorMode(c.x,c.y,c.w,c.h)
            case .SCISSOR_OFF: rl.EndScissorMode()
            }
        }

        rl.DrawFPS(0, 0)
    }
}
