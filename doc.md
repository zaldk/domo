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
    if ui.h(75)({
        left  = ui.v(75)({
            top    = "Source",
            bottom = "Console",
        }),
        right = ui.v(50)({
            top    = ui.t()("Breakpoints", "Commands", "Struct", "Exe"),
            bottom = ui.t()("Stack", "Files", "Registers", "Data", "Thread"),
        }),
    })
}

ui.WindowRenderer :: #type proc(title: string, width, height: f32)

source_renderer :: proc(title: string, width, height: f32) {
    // implementation
}

ui.set_renderer :: proc(title: string, renderer: ui.WindowRenderer)
```
