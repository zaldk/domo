# domo

A _very_ minimal UI library, currently in Odin, planned to be rewritten in C.

`src/ui` is the library, `src/main.odin` is an example usage with the following layout:

```c
// taken from github:nakst/gf
h(75, v(75, Source, Console), v(50, t(Breakpoints, Commands, Struct, Exe), t(Stack, Files, Registers, Data, Thread)))

// Actual layout:
v(.75,
    h(.80,
        "Source",
        v(.50,
            t("Exe", "Breakpoints", "Commands", "Struct"),
            t("Stack", "Files", "Thread", "CmdSearch"))),
    h(.65,
        "Console",
        t("Watch", "Locals", "Registers", "Data"))))
```

The Horizontal and Vertical splits are resizeable.

## Building

To run the project:

```sh
odin run build               # same as `-- run`
odin run build -- run        # build and run with debug info
odin run build -- build      # only build, do not run
odin run build -- release    # build in release mode
```

(tested only on Linux, other platforms may not work, but in that case just copy the command built
in `build/build.odin` main procedure into your shell)

## Dependencies

- Odin compiler.
