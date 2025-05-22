#!/usr/bin/env lua

-- Helper function to check if a directory exists
-- Uses 'test -d' via os.execute for simplicity and similarity to bash
local function directory_exists(path)
    -- os.execute returns true if command exits with 0, nil + status otherwise.
    -- 'test -d path' exits 0 if path is a directory.
    return os.execute("test -d " .. path)
end

-- Helper function to check if a file exists
local function file_exists(path)
    -- 'test -f path' exits 0 if path is a regular file.
    return os.execute("test -f " .. path)
end

-- Helper function to execute a command and exit on failure
local function run_command(cmd_str)
    print("Executing: " .. cmd_str)
    local ok, _, code = os.execute(cmd_str)
    if not ok then
        io.stderr:write("Error: Command failed with exit code " .. tostring(code or 1) .. "\n")
        io.stderr:write("Command: " .. cmd_str .. "\n")
        os.exit(code or 1)
    end
    return true
end


-- 1. Get build type from argument, default to "dev"
local type = arg[1] or "dev"

-- 2. Validate build type
local allowed_types = {
    release = true,
    debug = true,
    dev = true
}
if not allowed_types[type] then
    io.stderr:write("Error: Invalid type '" .. type .. "'. Allowed values are 'release', 'debug', 'dev' (default).\n")
    os.exit(1)
end
print("Build type: " .. type)

-- 3. Handle build directory
local build_dir = "./.build"
if not directory_exists(build_dir) then
    print("Creating build directory: " .. build_dir)
    -- Use os.execute for mkdir -p as Lua has no built-in recursive mkdir
    local mkdir_ok, _, mkdir_code = os.execute("mkdir -p " .. build_dir)
    if not mkdir_ok then
        io.stderr:write("Error: Failed to create directory " .. build_dir .. " (code: " .. tostring(mkdir_code or 1) .. ")\n")
        os.exit(1)
    end
end

-- 4. Handle .gitignore file
local gitignore_file = build_dir .. "/.gitignore"
if not file_exists(gitignore_file) then
    print("Creating gitignore: " .. gitignore_file)
    local file, err = io.open(gitignore_file, "w")
    if not file then
        io.stderr:write("Error: Could not create " .. gitignore_file .. ": " .. tostring(err) .. "\n")
        os.exit(1)
    end
    file:write("*\n")
    file:close()
end

-- 5. Determine version
-- %V is the ISO 8601 week number (week starts at Monday), same as 'date +%V'
local year_number = os.date("%y")
local week_number = os.date("%V")
local version = year_number .. "w" .. week_number .. "a"
print("Version: " .. version)

-- 6. Build based on type
local build_cmd_tbl = {
    release = table.concat({
        'odin build ./src',
        '-out:' .. build_dir .. '/domo.' .. version,
        '-collection:src=src -o:speed -build-mode:exe',
        '-target:linux_amd64',
        '-define:DOMO_TYPE=RELEASE',
        '-define:DOMO_VERSION=' .. version
    }, ' '),
    debug = table.concat({
        'odin build ./src',
        '-out:' .. build_dir .. '/domo.' .. version .. '.debug',
        '-collection:src=src -o:none -debug',
        '-build-mode:exe -target:linux_amd64',
        '-define:DOMO_TYPE=DEBUG',
        '-define:DOMO_VERSION=' .. version
    }, ' '),
    dev = table.concat({
        'odin run ./src',
        '-out:' .. build_dir .. '/domo.' .. version .. '.dev',
        '-collection:src=src -o:minimal',
        '-target:linux_amd64',
        '-define:DOMO_TYPE=DEV',
        '-define:DOMO_VERSION=' .. version
    }, ' '),
}

local odin_cmd = build_cmd_tbl[type]
if odin_cmd then
    run_command(odin_cmd)
else
    -- This case should not be reached due to prior type validation
    io.stderr:write("Error: Internal script error, unknown type for odin command.\n")
    os.exit(1)
end

print("Build successful.")
os.exit(0)
