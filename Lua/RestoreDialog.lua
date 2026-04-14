script_name('RestoreDialog')
script_author('quesada / https://t.me/quesada_self')

require('lib.moonloader')
local ffi = require('ffi')

ffi.cdef[[
    void* LoadLibraryA(const char* lpLibFileName);
    void* GetProcAddress(void* hModule, const char* lpProcName);
    int   FreeLibrary(void* hModule);
]]

local kernel32 = ffi.load('kernel32')

function loadDll()
    local hDll = kernel32.LoadLibraryA('vorbisFile.dll')
    if hDll == nil or hDll == ffi.cast('void*', 0) then
        print('error in LoadLibraryA')
        return nil, nil
    end
    local fnToggle = kernel32.GetProcAddress(hDll, 'ToggleCefDialogs')
    local fnAreEnabled = kernel32.GetProcAddress(hDll, 'AreCefDialogsEnabled')
    if fnToggle == nil or fnToggle == ffi.cast('void*', 0) then
        print('ToggleCefDialogs not found')
        return nil, nil
    end
    if fnAreEnabled == nil or fnAreEnabled == ffi.cast('void*', 0) then
        print('AreCefDialogsEnabled not found')
        return nil, nil
    end
    return ffi.cast('void(__cdecl*)(int)', fnToggle),
           ffi.cast('int(__cdecl*)(void)', fnAreEnabled)
end

function main()
    while not isSampAvailable() do wait(100) end

    toggleFn, areEnabledFn = loadDll()
    if not toggleFn then
        return print('error load dll!')
    end

    local ok, err = pcall(function() toggleFn(0) end)
    if ok then
        print('CEF Dialogs disabled!')
    else
        print('error call ToggleCefDialogs: ' .. tostring(err))
        return
    end

    while true do wait(2000)
        local ok2, result = pcall(areEnabledFn)
        if ok2 and result ~= 0 then
            pcall(function() toggleFn(0) end)
        end
    end
end