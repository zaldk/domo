# doc OUTDATED!

```c
// taken from github:nakst/gf
h(75, v(75, Source, Console), v(50, t(Breakpoints, Commands, Struct, Exe), t(Stack, Files, Registers, Data, Thread)))
```

```odin

ui.set_draw_rect(proc(x,y,w,h: i32, r,g,b,a: f32) {})
ui.set_draw_text(proc(text: string, x,y: i32, font_size: f32, r,g,b,a: f32) {})

Source      :: proc(x,y,w,h: i32) {}
Console     :: proc(x,y,w,h: i32) {}
Breakpoints :: proc(x,y,w,h: i32) {}
Commands    :: proc(x,y,w,h: i32) {}
Struct      :: proc(x,y,w,h: i32) {}
Exe         :: proc(x,y,w,h: i32) {}
Stack       :: proc(x,y,w,h: i32) {}
Files       :: proc(x,y,w,h: i32) {}
Registers   :: proc(x,y,w,h: i32) {}
Data        :: proc(x,y,w,h: i32) {}
Thread      :: proc(x,y,w,h: i32) {}

main :: proc() {
    ctx: ui.Context
    ui.begin_layout(&ctx)
    ui.h(.75,
        ui.v(.75,
            Source,
            Console),
        ui.v(.50,
            ui.t(Breakpoints, Commands, Struct, Exe),
            ui.t(Stack, Files, Registers, Data, Thread)))
    ui.end_layout()

    for {
        ui.update_mouse_position(&ctx, x,y)
        ui.update_mouse_button_state(&ctx, left|right, down|up)
        ui.update_mouse_wheel(&ctx, dx,dy)
        ui.render(&ctx, WIDTH, HEIGHT, FONT_SIZE)
    }
}
```

```odin
// ui.h(.75,
//     ui.v(.75,
//         "Source",
//         "Console"),
//     ui.v(.50,
//         ui.t("Breakpoints", "Commands", "Struct", "Exe"),
//         ui.t("Stack", "Files", "Registers", "Data", "Thread")))

// main :: proc() {
//     ui.init(width, height, title, font_size, allocator)
//     defer ui.free(&ctx)
//
//     ui.set_draw_rect(&ctx, proc(x,y,w,h: i32, r,g,b,a: f32) {})
//     ui.set_draw_text(&ctx, proc(text: string, x,y: i32, font_size: f32, r,g,b,a: f32) {})
//     ui.set_get_mouse_x(&ctx, proc() -> i32 {})
//     ui.set_get_mouse_y(&ctx, proc() -> i32 {})
//     ui.set_get_mouse_wheel_move_x(&ctx, proc() -> f32 {})
//     ui.set_get_mouse_wheel_move_y(&ctx, proc() -> f32 {})
//     ui.set_is_mouse_button_down(&ctx, proc(button: i32) -> bool {})
//     ui.set_is_mouse_button_pressed(&ctx, proc(button: i32) -> bool {})
//
//
//     for letter in ([?]string{"A","B","C","D"}) {
//         ui.set_renderer(&ctx, letter, proc(id: string, x,y,w,h: i32, font_size: f32) {
//             ui.draw_rect(x,y,w,h, 0,0,0,1)
//             ui.draw_text(letter, x+w/2, y+h/2, 30, 1,1,1,1)
//         })
//     }
//     for number in ([?]string{"1","2","3","4","5"}) {
//         ui.set_renderer(&ctx, number, proc(id: string, x,y,w,h: i32, font_size: f32) {
//             ui.draw_rect(x,y,w,h, 0,0,0,1)
//             ui.draw_text(number, x+w/2, y+h/2, 30, 1,1,1,1)
//         })
//     }
//
//     h := ui.h(&ctx) // top & bottom
//     v := ui.v(&ctx) // left & right
//     t := ui.t(&ctx) // tabs
//     layout : ui.Layout = v(.60,
//         h(.80,
//             "A",
//             t("1", "2", "3", "4", "5"),
//         ),
//         h(.75,
//             h(.50, "B", "C"),
//             "D",
//         ),
//     )
//
//     // Main Render Loop
//     for {
//         ui.update(&ctx, &layout)
//         ui.render(layout)
//     }
// }
```
