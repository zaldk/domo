package main

import "core:os"
import "core:log"
import "core:encoding/json"

Node :: struct {
    type: string,
    value: f32,
    tabs: union { []Node, []string },
}

parse :: proc() {
    data, ok := os.read_entire_file_from_filename("./src/resources/layout.json5")
    if !ok {
        log.errorf("Failed to load the file.")
        return
    }
    defer delete(data)

    root: Node
    unmarshal_err := json.unmarshal(data, &root, allocator = context.temp_allocator)
    if unmarshal_err != nil {
        log.errorf("Failed to unmarshal the file.", unmarshal_err)
        return
    }
    log.infof("\n%#v\n", root)
    // delete_node(&root)
}

// delete_node :: proc(root: ^Node) {
//     switch v in root.tabs {
//     case []Node:
//         for i in 0..<len(root.tabs.([]Node)) {
//             delete_node(&root.tabs.([]Node)[i])
//         }
//
//     case []string:
//         for i in 0..<len(root.tabs.([]string)) {
//             delete(root.tabs.([]string)[i])
//         }
//     }
//     delete(root.type)
// }
