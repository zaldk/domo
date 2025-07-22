package build

import "core:c/libc"
import "core:fmt"
import "core:log"
import "core:os"
import "core:time"
import "core:strings"
import "core:path/filepath"
import dt "core:time/datetime"

NAME :: "DOMO"
BUILD_DIR :: "./.build"
GITIGNORE_PATH :: "./.build/.gitignore"

main :: proc() {
    context.logger = log.create_console_logger(.Info, {.Level, .Terminal_Color})
    context.allocator = context.temp_allocator
    version, verr := get_version()
    assert(verr == nil)
    serr := setup_build_dir()
    assert(serr == nil)

    _cmd := [?]string{
        "odin run ./src",
        fmt.tprintf("-out:%v.%v.dev", filepath.join({BUILD_DIR, NAME}) or_else "", version),
        "-collection:src=src",
        "-o:minimal",
        "-target:linux_amd64",
        fmt.tprintf("-define:%v_VERSION=%v", NAME, version),
    }
    cmd := strings.join(
        _cmd[:], " ")
    ok := exec(strings.clone_to_cstring(cmd))
    assert(ok)
}

setup_build_dir :: proc() -> os.Error {
    info, builddir_err := os.stat(BUILD_DIR)
    switch builddir_err {
    case .Not_Exist, .ENOENT:
        log.info("Creating directory", "path", BUILD_DIR)
        if make_err := os.make_directory(BUILD_DIR, 0o755); make_err != nil {
            log.errorf("Failed to create directory '%v': %v", BUILD_DIR, make_err)
            return builddir_err
        }
    case nil:
        if !info.is_dir {
            log.errorf("Path '%v' exists but is not a directory.", BUILD_DIR)
            return builddir_err
        }
    case:
        log.errorf("Failed to check directory '%v': %v", BUILD_DIR, builddir_err)
        return builddir_err
    }

    _, gitignore_err := os.stat(GITIGNORE_PATH)
    switch gitignore_err {
    case .Not_Exist, .ENOENT:
        log.info("Creating file", "path", GITIGNORE_PATH)
        if !os.write_entire_file(GITIGNORE_PATH, {'*'}) {
            log.errorf("Failed to create and write to '%v'.", GITIGNORE_PATH)
            return gitignore_err
        }
    case nil: // File already exists, do nothing.
    case:
        log.errorf("Failed to check file '%v': %v", GITIGNORE_PATH, gitignore_err)
        return gitignore_err
    }

    return nil
}

exec :: proc(command: cstring) -> bool {
    log.infof("Running: `%v`", command)
    res := libc.system(command)

    when ODIN_OS == .Windows {
        switch {
        case res == -1:
            log.errorf("error spawning command %q", command)
            return false
        case res == 0:
            return true
        case:
            log.warnf("command %q exited with non-zero code", command)
            return false
        }
    } else {
        _WSTATUS    :: proc(x: i32) -> i32  { return x & 0177 }
        WIFEXITED   :: proc(x: i32) -> bool { return _WSTATUS(x) == 0 }
        WEXITSTATUS :: proc(x: i32) -> i32  { return (x >> 8) & 0x000000ff }

        switch {
        case res == -1:
            log.errorf("error spawning command %q", command)
            return false
        case WIFEXITED(res) && WEXITSTATUS(res) == 0:
            return true
        case WIFEXITED(res):
            log.warnf("command %q exited with non-zero code %v", command, WEXITSTATUS(res))
            return false
        case:
            log.errorf("command %q caused an unknown error: %v", command, res)
            return false
        }
    }
}

get_version :: proc(revision := "a") -> (version: string, err: dt.Error) {
    year, month, day_of_month := time.date(time.now())
    date := dt.components_to_date(year, month, day_of_month) or_return
    day := dt.day_number(date) or_return

    first_day_of_year := dt.new_year(year) or_return
    first_day_of_year_ordinal := dt.date_to_ordinal(first_day_of_year) or_return
    first_weekday_of_year := dt.day_of_week(first_day_of_year_ordinal)
    first_week_delta := (int(first_weekday_of_year) - 1 + 7) % 7 // shift day so Monday is 0 and Sunday is 6

    this_day_of_year_ordinal := dt.date_to_ordinal(date) or_return
    this_weekday_of_year := dt.day_of_week(this_day_of_year_ordinal)
    this_week_delta := 1 + (int(this_weekday_of_year) - 1 + 7) % 7 // shift day so Monday is 0 and Sunday is 6

    // week 1 is the week of January 1st of the current year
    // first_week_delta : prepends days to full first week
    // 7-this_week_delta is negative : appends remaining days to full week
    week := (int(day) + first_week_delta + 7-this_week_delta) / 7
    // format: y YEAR w WEEK REVISION
    version = fmt.tprintf("y%vw%v%v", year%100, week, revision)
    return
}
