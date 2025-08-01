package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"
import "ui"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

DOMO_VERSION :: #config(DOMO_VERSION, "N/A")

FONT_RAW := #load("./resources/iosevka.ttf", string)
FONT_SIZE : f32 : 30
FONT : ^ttf.Font

COLOR_BG :: sdl.Color { 20, 20, 20, 255 }
COLOR_FG :: sdl.Color { 200, 200, 200, 255 }

WIDTH  : i32 = 800
HEIGHT : i32 = 600

DONE := false

measure_text :: proc(text: string, font_size: f32) -> f32 {
    // old_fs := ttf.GetFontSize(FONT)
    // defer { ok := ttf.SetFontSize(FONT, old_fs) }
    // ok := ttf.SetFontSize(FONT, font_size)
    // measured_width : i32 = 0
    // measured_length : uint = 0
    // ok := ttf.MeasureString(FONT,
    //     strings.clone_to_cstring(text), len(text),
    //     0, // unbounded width
    //     &measured_width,
    //     &measured_length
    // )
    // return f32(measured_width)
    return f32(len(text)) * font_size
}

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
    ui.set_measure_text_w(proc(text: string, font_size: f32) -> f32 { return measure_text(text, font_size) })
    ui.set_measure_text_h(proc(text: string, font_size: f32) -> f32 { return FONT_SIZE })

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


    // SDL3-specific
    assert(sdl.Init(sdl.INIT_VIDEO))
    window := sdl.CreateWindow("FLOAT", 640, 480, { .RESIZABLE })
    assert(window != nil)
    surface := sdl.GetWindowSurface(window)
    assert(surface != nil)
    renderer := sdl.CreateSoftwareRenderer(surface)
    assert(renderer != nil)

    { // Fonts...
        assert(ttf.Init())
        stream := sdl.IOFromMem(raw_data(FONT_RAW), len(FONT_RAW))
        assert(stream != nil)
        FONT := ttf.OpenFontIO(stream, true, FONT_SIZE)
        assert(FONT != nil)
        // FONT := ttf.OpenFont("iosevka", FONT_SIZE)
        // if FONT == nil do log.error(sdl.GetError())
        // assert(FONT != nil)
    }

    for !DONE {
        e : sdl.Event
        for sdl.PollEvent(&e) {
            #partial switch e.type {
            case .QUIT: DONE = true
            case .KEY_DOWN: if e.key.key == sdl.K_ESCAPE do DONE = true
            case .WINDOW_RESIZED:
                sdl.DestroySurface(surface)
                surface = sdl.GetWindowSurface(window)
                sdl.DestroyRenderer(renderer)
                renderer = sdl.CreateSoftwareRenderer(surface)
            case .MOUSE_WHEEL: ui.update_mouse_wheel(i32(e.wheel.x), i32(e.wheel.y))
            case .MOUSE_MOTION: ui.update_mouse_position(i32(e.motion.x), i32(e.motion.y))
            case .MOUSE_BUTTON_DOWN: if e.button.which == 0 do ui.update_mouse_button_state(.LEFT, .DOWN)
            case .MOUSE_BUTTON_UP:   if e.button.which == 0 do ui.update_mouse_button_state(.LEFT, .UP)
            }
        }

        vp : sdl.Rect
        sdl.GetRenderViewport(renderer, &vp)
        WIDTH, HEIGHT = vp.w, vp.h

        when ODIN_DEBUG {
            sdl.SetRenderDrawColor(renderer, 0xFF, 0x0, 0xFF, 0xFF)
        } else {
            sdl.SetRenderDrawColor(renderer, 0, 0, 0, 0xFF)
        }
        sdl.RenderClear(renderer)

        // Change the cursor style
        switch ui.get_hover(true) {
        case .BUTTON:    assert(sdl.SetCursor(sdl.CreateSystemCursor(.POINTER)))
        case .DRAGBAR_H: assert(sdl.SetCursor(sdl.CreateSystemCursor(.EW_RESIZE)))
        case .DRAGBAR_V: assert(sdl.SetCursor(sdl.CreateSystemCursor(.NS_RESIZE)))
        case .NONE:      assert(sdl.SetCursor(sdl.CreateSystemCursor(.DEFAULT)))
        }

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
                sdl.SetRenderDrawColor(renderer, COLOR_BG.r,COLOR_BG.g,COLOR_BG.b,COLOR_BG.a)
                sdl.RenderFillRect(renderer, &sdl.FRect{ f32(c.x), f32(c.y), f32(c.w), f32(c.h) })

                t := measure_text(c.title, FONT_SIZE)
                sdl.SetRenderDrawColor(renderer, COLOR_FG.r,COLOR_FG.g,COLOR_FG.b,COLOR_FG.a)
                cstr := strings.clone_to_cstring(c.title); defer delete(cstr)
                sdl.RenderDebugText(renderer, f32(c.x+c.w/2)-t/2, f32(c.y+c.h/2)-FONT_SIZE/2, cstr)
            case .RECT:
                sdl.SetRenderDrawColor(renderer, c.color.r,c.color.g,c.color.b,c.color.a)
                sdl.RenderFillRect(renderer, &sdl.FRect{ f32(c.x), f32(c.y), f32(c.w), f32(c.h) })
            case .TEXT:
                sdl.SetRenderDrawColor(renderer, c.color.r,c.color.g,c.color.b,c.color.a)
                cstr := strings.clone_to_cstring(c.text); defer delete(cstr)
                sdl.RenderDebugText(renderer, f32(c.x), f32(c.y), cstr)
            case .SCISSOR_ON: sdl.SetRenderClipRect(renderer, &sdl.Rect{c.x,c.y,c.w,c.h})
            case .SCISSOR_OFF: sdl.SetRenderClipRect(renderer, &sdl.Rect{0,0,1<<16,1<<16})
            }
            sdl.RenderPresent(renderer)
        }
        sdl.UpdateWindowSurface(window)
    }

    sdl.Quit()

    // defer rl.CloseWindow()
    // rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
    // { // load the iosevka font
    //     FONT = rl.LoadFontFromMemory(
    //         ".ttf",
    //         raw_data(FONT_RAW[:]),
    //         i32(len(FONT_RAW)),
    //         i32(FONT_SIZE),
    //         raw_data(CODEPOINTS[:]),
    //         len(CODEPOINTS),
    //     )
    //     rl.GenTextureMipmaps(&FONT.texture)
    //     rl.SetTextureFilter(FONT.texture, .BILINEAR)
    // }
}
