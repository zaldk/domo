# doc OUTDATED!

```layout.json5
// taken from github:nakst/gf
// equivalent to h(75, v(75, Source, Console), v(50, t(Breakpoints, Commands, Struct, Exe), t(Stack, Files, Registers, Data, Thread)))
{
    type: "h",
    value: 75,
    tabs: [
        {
            type: "v",
            value: 75,
            tabs: ["Source", "Console"],
        },
        {
            type: "v",
            value: 50,
            tabs: [
                {
                    type: "t",
                    tabs: ["Breakpoints", "Commands", "Struct", "Exe"],
                },
                {
                    type: "t",
                    tabs: ["Stack", "Files", "Registers", "Data", "Thread"],
                },
            ]
        },
    ]
}
```

```odin

main :: proc() {
    ctx: ui.Context
    ui.init(&ctx, width, height, title, font_size, allocator)

    ui.define(&ctx, .DrawRect, proc(x,y,w,h: i32, r,g,b,a: f32) {})
    ui.define(&ctx, .DrawText, proc(text: string, x,y: i32, font_size: f32, r,g,b,a: f32) {})
    ui.define(&ctx, .GetMouseX, proc() -> i32 {})
    ui.define(&ctx, .GetMouseY, proc() -> i32 {})
    ui.define(&ctx, .GetMouseWheelMoveX, proc() -> f32 {})
    ui.define(&ctx, .GetMouseWheelMoveY, proc() -> f32 {})
    ui.define(&ctx, .IsMouseButtonDown, proc(button: i32) -> bool {})
    ui.define(&ctx, .IsMouseButtonPressed, proc(button: i32) -> bool {})

    for letter in ([?]string{"A","B","C","D"}) {
        ui.define(&ctx, .Renderer, letter, proc(id: string, x,y,w,h: i32, font_size: f32) {
            ui.draw_rect(x,y,w,h, 0,0,0,1)
            ui.draw_text(letter, x+w/2, y+h/2, 30, 1,1,1,1)
        })
    }
    for number in ([?]string{"1","2","3","4","5"}) {
        ui.define(&ctx, .Renderer, number, proc(id: string, x,y,w,h: i32, font_size: f32) {
            ui.draw_rect(x,y,w,h, 0,0,0,1)
            ui.draw_text(number, x+w/2, y+h/2, 30, 1,1,1,1)
        })
    }

    h := ui.h(&ctx) // top & bottom
    v := ui.v(&ctx) // left & right
    t := ui.t(&ctx) // tabs
    layout : ui.Layout = v(.60,
        h(.80,
            "A",
            t("1", "2", "3", "4", "5"),
        ),
        h(.75,
            h(.50, "B", "C"),
            "D",
        ),
    )

    // Main Render Loop
    for {
        ui.update(&ctx, &layout)
        ui.render(layout)
    }
}
```
