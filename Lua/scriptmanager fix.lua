script_name("LUA MANAGER")
script_author("imchaosvoid & ai")
script_version("4.0")
script_description("Script Manager")

local imgui = require 'mimgui'
local ffi = require 'ffi'

-- ========== CONFIG ==========
local inicfg = nil
local configFile = "scriptmanager.ini"
local ini = nil

function save()
    if ini and inicfg then inicfg.save(ini, configFile) end
end

-- ========== SETTINGS ==========
local WINDOW_SIZE = 430
local ITEM_HEIGHT = 40
local ITEM_SPACING = 4
local ITEM_ROUNDING = 6.0
local TOGGLE_W = 48.0
local TOGGLE_H = 26.0

-- ========== STATE ==========
local windowOpen = imgui.new.bool(false)
local scriptList = {}
local scriptStates = {}
local needRefresh = true
local screenW, screenH = 0, 0
local screenCached = false
local animStates = {}
local hoverAnim = {}
local clock = 0.0
local currentTab = 0
local selectedTheme = 1

-- ========== THEME DEFINITIONS ==========
local themes = {
    {
        name = "SILVER WAVE",
        desc = "Metallic gradient shimmer",
        grad1 = {0.25, 0.25, 0.30},
        grad2 = {0.45, 0.45, 0.52},
        grad3 = {0.32, 0.35, 0.40},
        accent = {0.50, 0.50, 0.58},
        toggleOn = {0.55, 0.55, 0.65},
        headerLine = {0.50, 0.50, 0.60, 0.6},
        windowBg = {0.07, 0.07, 0.10, 0.97},
        borderCol = {0.40, 0.40, 0.50, 0.35},
        rowColors = {
            {bg={0.22,0.22,0.28}, br={0.40,0.40,0.50}},
            {bg={0.18,0.20,0.26}, br={0.35,0.38,0.48}},
            {bg={0.25,0.25,0.30}, br={0.45,0.45,0.55}},
            {bg={0.20,0.22,0.28}, br={0.38,0.42,0.52}},
            {bg={0.16,0.18,0.24}, br={0.32,0.36,0.46}},
            {bg={0.24,0.24,0.30}, br={0.44,0.44,0.54}},
        },
    },
    {
        name = "NEON PURPLE",
        desc = "Deep violet energy",
        grad1 = {0.30, 0.15, 0.55},
        grad2 = {0.55, 0.25, 0.80},
        grad3 = {0.40, 0.18, 0.65},
        accent = {0.65, 0.35, 0.90},
        toggleOn = {0.58, 0.30, 0.85},
        headerLine = {0.55, 0.30, 0.80, 0.6},
        windowBg = {0.06, 0.04, 0.12, 0.97},
        borderCol = {0.45, 0.25, 0.65, 0.35},
        rowColors = {
            {bg={0.25,0.10,0.40}, br={0.50,0.25,0.70}},
            {bg={0.20,0.08,0.35}, br={0.45,0.20,0.65}},
            {bg={0.30,0.12,0.48}, br={0.55,0.28,0.75}},
            {bg={0.22,0.10,0.38}, br={0.48,0.22,0.68}},
            {bg={0.18,0.06,0.32}, br={0.42,0.18,0.60}},
            {bg={0.28,0.14,0.45}, br={0.52,0.30,0.72}},
        },
    },
    {
        name = "CRIMSON FIRE",
        desc = "Burning red glow",
        grad1 = {0.50, 0.12, 0.12},
        grad2 = {0.80, 0.20, 0.15},
        grad3 = {0.60, 0.15, 0.10},
        accent = {0.90, 0.30, 0.25},
        toggleOn = {0.85, 0.25, 0.20},
        headerLine = {0.80, 0.25, 0.20, 0.6},
        windowBg = {0.10, 0.04, 0.04, 0.97},
        borderCol = {0.60, 0.20, 0.18, 0.35},
        rowColors = {
            {bg={0.40,0.10,0.10}, br={0.70,0.20,0.18}},
            {bg={0.35,0.08,0.08}, br={0.65,0.18,0.15}},
            {bg={0.45,0.12,0.10}, br={0.75,0.22,0.20}},
            {bg={0.38,0.10,0.08}, br={0.68,0.20,0.16}},
            {bg={0.32,0.06,0.06}, br={0.60,0.15,0.12}},
            {bg={0.42,0.14,0.12}, br={0.72,0.25,0.22}},
        },
    },
    {
        name = "GOLDEN SUN",
        desc = "Warm amber radiance",
        grad1 = {0.55, 0.42, 0.10},
        grad2 = {0.80, 0.62, 0.15},
        grad3 = {0.65, 0.50, 0.12},
        accent = {0.90, 0.72, 0.20},
        toggleOn = {0.85, 0.68, 0.18},
        headerLine = {0.80, 0.65, 0.15, 0.6},
        windowBg = {0.09, 0.07, 0.03, 0.97},
        borderCol = {0.60, 0.48, 0.15, 0.35},
        rowColors = {
            {bg={0.40,0.30,0.08}, br={0.65,0.50,0.15}},
            {bg={0.35,0.26,0.06}, br={0.60,0.46,0.12}},
            {bg={0.45,0.34,0.10}, br={0.70,0.54,0.18}},
            {bg={0.38,0.28,0.07}, br={0.62,0.48,0.14}},
            {bg={0.32,0.24,0.05}, br={0.58,0.44,0.10}},
            {bg={0.42,0.32,0.09}, br={0.68,0.52,0.16}},
        },
    },
}

-- ========== GET CURRENT THEME ==========
local function getTheme()
    return themes[selectedTheme] or themes[1]
end

-- ========== ANIMATED GRADIENT LERP ==========
local function gradientLerp(t, c1, c2, c3)
    local phase = t % 3.0
    local r, g, b
    if phase < 1.0 then
        local f = phase
        r = c1[1] + (c2[1] - c1[1]) * f
        g = c1[2] + (c2[2] - c1[2]) * f
        b = c1[3] + (c2[3] - c1[3]) * f
    elseif phase < 2.0 then
        local f = phase - 1.0
        r = c2[1] + (c3[1] - c2[1]) * f
        g = c2[2] + (c3[2] - c2[2]) * f
        b = c2[3] + (c3[3] - c2[3]) * f
    else
        local f = phase - 2.0
        r = c3[1] + (c1[1] - c3[1]) * f
        g = c3[2] + (c1[2] - c3[2]) * f
        b = c3[3] + (c1[3] - c3[3]) * f
    end
    return r, g, b
end

-- ========== GET ROW COLOR ==========
local function getRowColor(index)
    local theme = getTheme()
    local rc = theme.rowColors
    local ci = ((index - 1) % #rc) + 1
    local row = rc[ci]

    local t = clock * 0.6 + index * 0.4
    local shimmer = math.sin(t) * 0.04

    local bg = row.bg
    local r = math.max(0, math.min(1, bg[1] + shimmer))
    local g = math.max(0, math.min(1, bg[2] + shimmer))
    local b = math.max(0, math.min(1, bg[3] + shimmer))

    return imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, 0.88)),
           imgui.GetColorU32Vec4(imgui.ImVec4(row.br[1], row.br[2], row.br[3], 1.0))
end

-- ========== APPLY THEME STYLE ==========
local function applyThemeStyle()
    local theme = getTheme()
    local style = imgui.GetStyle()
    style.WindowRounding = 8.0
    style.FrameRounding = 6.0
    style.GrabRounding = 6.0
    style.ChildRounding = 6.0
    style.PopupRounding = 6.0
    style.ScrollbarRounding = 6.0
    style.TabRounding = 4.0
    style.WindowBorderSize = 1.0
    style.FrameBorderSize = 0.0
    style.WindowPadding = imgui.ImVec2(16, 16)
    style.FramePadding = imgui.ImVec2(10, 7)
    style.ItemSpacing = imgui.ImVec2(8, 4)
    style.ItemInnerSpacing = imgui.ImVec2(6, 4)
    style.ScrollbarSize = 4.0
    style.GrabMinSize = 8.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.Alpha = 0.99

    local wb = theme.windowBg
    local bc = theme.borderCol
    local ac = theme.accent

    local c = style.Colors
    c[imgui.Col.WindowBg]             = imgui.ImVec4(wb[1], wb[2], wb[3], wb[4])
    c[imgui.Col.ChildBg]              = imgui.ImVec4(0, 0, 0, 0)
    c[imgui.Col.PopupBg]              = imgui.ImVec4(wb[1]+0.04, wb[2]+0.04, wb[3]+0.05, 0.98)
    c[imgui.Col.Border]               = imgui.ImVec4(bc[1], bc[2], bc[3], bc[4])
    c[imgui.Col.FrameBg]              = imgui.ImVec4(wb[1]+0.06, wb[2]+0.06, wb[3]+0.08, 1.0)
    c[imgui.Col.FrameBgHovered]       = imgui.ImVec4(wb[1]+0.10, wb[2]+0.10, wb[3]+0.14, 1.0)
    c[imgui.Col.FrameBgActive]        = imgui.ImVec4(wb[1]+0.14, wb[2]+0.14, wb[3]+0.20, 1.0)
    c[imgui.Col.TitleBg]              = imgui.ImVec4(wb[1]-0.01, wb[2]-0.01, wb[3]-0.01, 1.0)
    c[imgui.Col.TitleBgActive]        = imgui.ImVec4(wb[1]+0.02, wb[2]+0.01, wb[3]+0.04, 1.0)
    c[imgui.Col.TitleBgCollapsed]     = imgui.ImVec4(wb[1], wb[2], wb[3], 0.70)
    c[imgui.Col.ScrollbarBg]          = imgui.ImVec4(wb[1]-0.02, wb[2]-0.02, wb[3]-0.02, 0.3)
    c[imgui.Col.ScrollbarGrab]        = imgui.ImVec4(ac[1]*0.6, ac[2]*0.6, ac[3]*0.6, 0.8)
    c[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(ac[1]*0.8, ac[2]*0.8, ac[3]*0.8, 1.0)
    c[imgui.Col.ScrollbarGrabActive]  = imgui.ImVec4(ac[1]*0.7, ac[2]*0.7, ac[3]*0.7, 1.0)
    c[imgui.Col.CheckMark]            = imgui.ImVec4(ac[1], ac[2], ac[3], 1.0)
    c[imgui.Col.Button]               = imgui.ImVec4(ac[1]*0.20, ac[2]*0.20, ac[3]*0.20, 1.0)
    c[imgui.Col.ButtonHovered]        = imgui.ImVec4(ac[1]*0.35, ac[2]*0.35, ac[3]*0.35, 1.0)
    c[imgui.Col.ButtonActive]         = imgui.ImVec4(ac[1]*0.50, ac[2]*0.50, ac[3]*0.50, 1.0)
    c[imgui.Col.Header]               = imgui.ImVec4(ac[1]*0.20, ac[2]*0.20, ac[3]*0.20, 1.0)
    c[imgui.Col.HeaderHovered]        = imgui.ImVec4(ac[1]*0.30, ac[2]*0.30, ac[3]*0.30, 1.0)
    c[imgui.Col.HeaderActive]         = imgui.ImVec4(ac[1]*0.45, ac[2]*0.45, ac[3]*0.45, 1.0)
    c[imgui.Col.Separator]            = imgui.ImVec4(bc[1], bc[2], bc[3], 0.40)
    c[imgui.Col.Text]                 = imgui.ImVec4(0.94, 0.94, 0.98, 1.0)
    c[imgui.Col.TextDisabled]         = imgui.ImVec4(0.45, 0.45, 0.55, 1.0)
    c[imgui.Col.Tab]                  = imgui.ImVec4(ac[1]*0.18, ac[2]*0.18, ac[3]*0.18, 1.0)
    c[imgui.Col.TabHovered]           = imgui.ImVec4(ac[1]*0.40, ac[2]*0.40, ac[3]*0.40, 1.0)
    c[imgui.Col.TabActive]            = imgui.ImVec4(ac[1]*0.30, ac[2]*0.30, ac[3]*0.30, 1.0)
end

-- ========== SCAN SCRIPTS ==========
local function scanScripts()
    scriptList = {}
    scriptStates = {}
    animStates = {}
    hoverAnim = {}
    local moonDir = getWorkingDirectory()
    local thisName = script.this.filename

    local handle, firstFile = findFirstFile(moonDir .. "\\*.lua")
    if handle then
        local fileName = firstFile
        while fileName do
            if fileName ~= thisName then
                table.insert(scriptList, {
                    name = fileName:gsub("%.lua$", ""),
                    filename = fileName,
                    fullpath = moonDir .. "\\" .. fileName,
                })
            end
            fileName = findNextFile(handle)
        end
        findClose(handle)
    end

    table.sort(scriptList, function(a, b) return a.name:lower() < b.name:lower() end)

    local loaded = script.list()
    for i, scr in ipairs(scriptList) do
        local running = false
        for _, s in ipairs(loaded) do
            if s.path == scr.fullpath then running = true; break end
        end
        scriptStates[i] = imgui.new.bool(running)
        animStates[i] = running and 1.0 or 0.0
        hoverAnim[i] = 0.0
    end
end

-- ========== FIND & TOGGLE ==========
local function findScriptByPath(path)
    for _, s in ipairs(script.list()) do
        if s.path == path then return s end
    end
    return nil
end

local function toggleScript(index, enable)
    local scr = scriptList[index]
    if enable then
        local ok, err = pcall(script.load, scr.fullpath)
        if not ok then
            print('[LUA MANAGER] Failed to load "' .. scr.name .. '": ' .. tostring(err))
            if isSampAvailable() then
                sampAddChatMessage('{FF4444}[LUA MANAGER] {FFFFFF}Error loading: ' .. scr.name, -1)
            end
            scriptStates[index][0] = false
        end
    else
        local luaScr = findScriptByPath(scr.fullpath)
        if luaScr then luaScr:unload() end
    end
end

-- ========== DRAW TOGGLE ==========
local function drawToggle(dl, pos, animT)
    local W, H = TOGGLE_W, TOGGLE_H
    local R = H * 0.5
    local theme = getTheme()
    local ton = theme.toggleOn

    local offR, offG, offB = 0.25, 0.25, 0.30
    local tr = offR + (ton[1] - offR) * animT
    local tg = offG + (ton[2] - offG) * animT
    local tb = offB + (ton[3] - offB) * animT
    local trackCol = imgui.GetColorU32Vec4(imgui.ImVec4(tr, tg, tb, 1.0))

    if animT > 0.1 then
        dl:AddRectFilled(
            imgui.ImVec2(pos.x - 2, pos.y - 2),
            imgui.ImVec2(pos.x + W + 2, pos.y + H + 2),
            imgui.GetColorU32Vec4(imgui.ImVec4(ton[1], ton[2], ton[3], 0.15 * animT)),
            R + 2, 15)
    end

    dl:AddRectFilled(pos, imgui.ImVec2(pos.x + W, pos.y + H), trackCol, R, 15)
    dl:AddRect(pos, imgui.ImVec2(pos.x + W, pos.y + H),
        imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 0.12 + 0.10 * animT)), R, 15, 1.0)

    local knobR = H * 0.34 + 0.04 * animT * H
    local knobX = pos.x + R + (W - H) * animT
    local knobY = pos.y + R

    dl:AddCircleFilled(imgui.ImVec2(knobX + 1, knobY + 2), knobR + 1,
        imgui.GetColorU32Vec4(imgui.ImVec4(0, 0, 0, 0.40)), 48)
    dl:AddCircleFilled(imgui.ImVec2(knobX, knobY), knobR,
        imgui.GetColorU32Vec4(imgui.ImVec4(0.98, 0.98, 1.0, 1.0)), 48)
    dl:AddCircleFilled(imgui.ImVec2(knobX - 1, knobY - 1), knobR * 0.45,
        imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 0.18)), 48)
end

-- ========== DRAW STATUS DOT ==========
local function drawStatusDot(dl, x, y, animT)
    local theme = getTheme()
    local ton = theme.toggleOn
    local dotR = 4.0
    local dR = 0.4 + (ton[1] - 0.4) * animT
    local dG = 0.4 + (ton[2] - 0.4) * animT
    local dB = 0.4 + (ton[3] - 0.4) * animT
    if animT > 0.3 then
        dl:AddCircleFilled(imgui.ImVec2(x, y), dotR + 3,
            imgui.GetColorU32Vec4(imgui.ImVec4(ton[1], ton[2], ton[3], 0.20 * animT)), 32)
    end
    dl:AddCircleFilled(imgui.ImVec2(x, y), dotR,
        imgui.GetColorU32Vec4(imgui.ImVec4(dR, dG, dB, 1.0)), 32)
end

-- ========== DRAW GRADIENT PREVIEW RECT ==========
local function drawGradientPreview(dl, pos, w, h, themeIdx)
    local th = themes[themeIdx]
    local t = clock * 0.5
    local r1, g1, b1 = gradientLerp(t, th.grad1, th.grad2, th.grad3)
    local r2, g2, b2 = gradientLerp(t + 1.5, th.grad1, th.grad2, th.grad3)

    local colLeft = imgui.GetColorU32Vec4(imgui.ImVec4(r1, g1, b1, 1.0))
    local colRight = imgui.GetColorU32Vec4(imgui.ImVec4(r2, g2, b2, 1.0))

    local mid = pos.x + w * 0.5
    dl:AddRectFilledMultiColor(
        pos, imgui.ImVec2(mid, pos.y + h),
        colLeft, colRight, colRight, colLeft
    )
    dl:AddRectFilledMultiColor(
        imgui.ImVec2(mid, pos.y), imgui.ImVec2(pos.x + w, pos.y + h),
        colRight, colLeft, colLeft, colRight
    )

    local ac = th.accent
    dl:AddRect(pos, imgui.ImVec2(pos.x + w, pos.y + h),
        imgui.GetColorU32Vec4(imgui.ImVec4(ac[1], ac[2], ac[3], 0.6)), 6.0, 15, 1.5)

    if themeIdx == selectedTheme then
        dl:AddRect(pos, imgui.ImVec2(pos.x + w, pos.y + h),
            imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 0.7)), 6.0, 15, 2.0)
    end
end

-- ========== INIT ==========
imgui.OnInitialize(function()
    applyThemeStyle()
end)

-- ========== RENDER ==========
local frame = imgui.OnFrame(
    function() return windowOpen[0] end,
    function()
        if not screenCached then
            screenW, screenH = getScreenResolution()
            screenCached = true
        end
        clock = clock + 0.016

        if needRefresh then
            scanScripts()
            needRefresh = false
        end

        applyThemeStyle()

        local theme = getTheme()
        local gr, gg, gb = gradientLerp(clock * 0.3, theme.grad1, theme.grad2, theme.grad3)
        local wb = theme.windowBg
        local style = imgui.GetStyle()
        style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(
            wb[1] + gr * 0.05,
            wb[2] + gg * 0.05,
            wb[3] + gb * 0.05,
            wb[4]
        )

        imgui.SetNextWindowPos(
            imgui.ImVec2(screenW - WINDOW_SIZE - 20, (screenH - WINDOW_SIZE) / 2),
            imgui.Cond.FirstUseEver
        )
        imgui.SetNextWindowSize(
            imgui.ImVec2(WINDOW_SIZE, WINDOW_SIZE),
            imgui.Cond.FirstUseEver
        )
        imgui.SetNextWindowSizeConstraints(imgui.ImVec2(350, 350), imgui.ImVec2(600, 600))

        imgui.Begin("LUA MANAGER", windowOpen, imgui.WindowFlags.NoCollapse)
        local dl = imgui.GetWindowDrawList()
        local winPos = imgui.GetWindowPos()
        local winSize = imgui.GetWindowSize()

        -- ===== ANIMATED HEADER LINE =====
        local hlR, hlG, hlB = gradientLerp(clock * 0.8, theme.grad1, theme.grad2, theme.grad3)
        local headerY = winPos.y + 32
        dl:AddLine(
            imgui.ImVec2(winPos.x + 12, headerY),
            imgui.ImVec2(winPos.x + winSize.x - 12, headerY),
            imgui.GetColorU32Vec4(imgui.ImVec4(hlR, hlG, hlB, 0.55)), 1.5)

        imgui.Spacing()

        -- ===== TAB BUTTONS =====
        local tabW = (imgui.GetContentRegionAvail().x - 8) * 0.5
        local ac = theme.accent

        if currentTab == 0 then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ac[1]*0.35, ac[2]*0.35, ac[3]*0.35, 1.0))
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ac[1]*0.12, ac[2]*0.12, ac[3]*0.12, 1.0))
        end
        if imgui.Button("SCRIPTS", imgui.ImVec2(tabW, 28)) then
            currentTab = 0
        end
        imgui.PopStyleColor()

        imgui.SameLine(0, 8)

        if currentTab == 1 then
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ac[1]*0.35, ac[2]*0.35, ac[3]*0.35, 1.0))
        else
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(ac[1]*0.12, ac[2]*0.12, ac[3]*0.12, 1.0))
        end
        if imgui.Button("THEMES", imgui.ImVec2(tabW, 28)) then
            currentTab = 1
        end
        imgui.PopStyleColor()

        imgui.Spacing()

        local tabLineY = imgui.GetCursorScreenPos().y - 2
        local tabStartX = winPos.x + 16
        if currentTab == 0 then
            dl:AddRectFilled(
                imgui.ImVec2(tabStartX, tabLineY),
                imgui.ImVec2(tabStartX + tabW, tabLineY + 2),
                imgui.GetColorU32Vec4(imgui.ImVec4(ac[1], ac[2], ac[3], 0.8)), 1.0)
        else
            dl:AddRectFilled(
                imgui.ImVec2(tabStartX + tabW + 8, tabLineY),
                imgui.ImVec2(tabStartX + tabW * 2 + 8, tabLineY + 2),
                imgui.GetColorU32Vec4(imgui.ImVec4(ac[1], ac[2], ac[3], 0.8)), 1.0)
        end

        imgui.Spacing()

        -- ================================================================
        -- TAB 0: SCRIPTS
        -- ================================================================
        if currentTab == 0 then
            local loaded = 0
            for i = 1, #scriptList do
                if scriptStates[i] and scriptStates[i][0] then loaded = loaded + 1 end
            end
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(ac[1], ac[2], ac[3], 1.0))
            imgui.Text("//")
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.Text("Active")
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(ac[1], ac[2], ac[3], 1.0))
            imgui.Text(tostring(loaded))
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.45, 0.45, 0.55, 1.0))
            imgui.Text("/ " .. tostring(#scriptList))
            imgui.PopStyleColor()

            imgui.Spacing()

            local avail = imgui.GetContentRegionAvail()
            imgui.BeginChild("##list", imgui.ImVec2(avail.x, avail.y - 42), false)
            local dlList = imgui.GetWindowDrawList()

            local contentW = imgui.GetContentRegionAvail().x
            local whiteCol = imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 1))

            for i, scr in ipairs(scriptList) do
                local cur = imgui.GetCursorScreenPos()
                local bgCol, brCol = getRowColor(i)

                local mp = imgui.GetMousePos()
                local isHover = mp.x >= cur.x and mp.x <= cur.x + contentW and
                                mp.y >= cur.y and mp.y <= cur.y + ITEM_HEIGHT
                local ht = isHover and 1.0 or 0.0
                if hoverAnim[i] < ht then hoverAnim[i] = math.min(hoverAnim[i] + 0.12, 1.0)
                elseif hoverAnim[i] > ht then hoverAnim[i] = math.max(hoverAnim[i] - 0.08, 0.0) end

                local rowMin = imgui.ImVec2(cur.x, cur.y)
                local rowMax = imgui.ImVec2(cur.x + contentW, cur.y + ITEM_HEIGHT)

                dlList:AddRectFilled(rowMin, rowMax, bgCol, ITEM_ROUNDING, 15)

                if hoverAnim[i] > 0.01 then
                    dlList:AddRectFilled(rowMin, rowMax,
                        imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 0.05 * hoverAnim[i])),
                        ITEM_ROUNDING, 15)
                end

                dlList:AddRectFilled(
                    imgui.ImVec2(cur.x, cur.y + 4),
                    imgui.ImVec2(cur.x + 3, cur.y + ITEM_HEIGHT - 4),
                    brCol, 2.0, 15)

                dlList:AddLine(
                    imgui.ImVec2(cur.x + 4, cur.y + ITEM_HEIGHT),
                    imgui.ImVec2(cur.x + contentW - 4, cur.y + ITEM_HEIGHT),
                    imgui.GetColorU32Vec4(imgui.ImVec4(0, 0, 0, 0.25)), 1.0)

                local isOn = scriptStates[i][0]
                drawStatusDot(dlList, cur.x + 14, cur.y + ITEM_HEIGHT * 0.5, animStates[i])

                local textY = cur.y + (ITEM_HEIGHT - imgui.GetTextLineHeight()) / 2
                dlList:AddText(imgui.ImVec2(cur.x + 26, textY), whiteCol, scr.name)

                local toggleX = cur.x + contentW - TOGGLE_W - 8
                local toggleY = cur.y + (ITEM_HEIGHT - TOGGLE_H) / 2
                local togglePos = imgui.ImVec2(toggleX, toggleY)

                local target = isOn and 1.0 or 0.0
                if animStates[i] < target then animStates[i] = math.min(animStates[i] + 0.08, 1.0)
                elseif animStates[i] > target then animStates[i] = math.max(animStates[i] - 0.08, 0.0) end

                drawToggle(dlList, togglePos, animStates[i])

                imgui.SetCursorScreenPos(togglePos)
                imgui.PushIDInt(i)
                if imgui.InvisibleButton("##t", imgui.ImVec2(TOGGLE_W, TOGGLE_H)) then
                    local wasOn = scriptStates[i][0]
                    if wasOn then
                        scriptStates[i][0] = false
                        toggleScript(i, false)
                    else
                        scriptStates[i][0] = true
                        toggleScript(i, true)
                    end
                end
                imgui.PopID()

                imgui.SetCursorScreenPos(imgui.ImVec2(cur.x, cur.y + ITEM_HEIGHT + ITEM_SPACING))
            end

            imgui.EndChild()

            imgui.Spacing()

            local bw = imgui.GetContentRegionAvail().x
            imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(0, 8))
            if imgui.Button("REFRESH", imgui.ImVec2(bw, 34)) then
                needRefresh = true
            end
            imgui.PopStyleVar()

        -- ================================================================
        -- TAB 1: THEMES
        -- ================================================================
        elseif currentTab == 1 then
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(ac[1], ac[2], ac[3], 1.0))
            imgui.Text("//")
            imgui.PopStyleColor()
            imgui.SameLine()
            imgui.Text("Select Theme")
            imgui.Spacing()
            imgui.Spacing()

            local avail = imgui.GetContentRegionAvail()
            imgui.BeginChild("##themes", imgui.ImVec2(avail.x, avail.y), false)
            local dlThemes = imgui.GetWindowDrawList()

            local cw = imgui.GetContentRegionAvail().x

            for ti = 1, #themes do
                local th = themes[ti]
                local cur = imgui.GetCursorScreenPos()

                local cardH = 80
                local cardMin = imgui.ImVec2(cur.x, cur.y)
                local cardMax = imgui.ImVec2(cur.x + cw, cur.y + cardH)

                local cardBgA = (ti == selectedTheme) and 0.30 or 0.15
                dlThemes:AddRectFilled(cardMin, cardMax,
                    imgui.GetColorU32Vec4(imgui.ImVec4(th.accent[1]*0.2, th.accent[2]*0.2, th.accent[3]*0.2, cardBgA)),
                    8.0, 15)

                if ti == selectedTheme then
                    dlThemes:AddRect(cardMin, cardMax,
                        imgui.GetColorU32Vec4(imgui.ImVec4(th.accent[1], th.accent[2], th.accent[3], 0.7)),
                        8.0, 15, 2.0)
                end

                local previewX = cur.x + 12
                local previewY = cur.y + 10
                local previewW = cw * 0.35
                local previewH = 60
                drawGradientPreview(dlThemes, imgui.ImVec2(previewX, previewY), previewW, previewH, ti)

                local nameX = previewX + previewW + 16
                local nameY = cur.y + 16
                dlThemes:AddText(imgui.ImVec2(nameX, nameY),
                    imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 0.95)), th.name)

                dlThemes:AddText(imgui.ImVec2(nameX, nameY + 20),
                    imgui.GetColorU32Vec4(imgui.ImVec4(0.6, 0.6, 0.7, 0.8)), th.desc)

                if ti == selectedTheme then
                    dlThemes:AddText(imgui.ImVec2(nameX, nameY + 42),
                        imgui.GetColorU32Vec4(imgui.ImVec4(th.accent[1], th.accent[2], th.accent[3], 1.0)),
                        "> ACTIVE")
                end

                imgui.SetCursorScreenPos(cardMin)
                imgui.PushIDInt(100 + ti)
                if imgui.InvisibleButton("##theme", imgui.ImVec2(cw, cardH)) then
                    selectedTheme = ti
                    applyThemeStyle()
                    if ini then
                        ini.config.theme = selectedTheme
                        save()
                    end
                end
                imgui.PopID()

                imgui.SetCursorScreenPos(imgui.ImVec2(cur.x, cur.y + cardH + 8))
            end

            imgui.EndChild()
        end

        imgui.End()
    end
)
frame.HideCursor = false
frame.LockPlayer = false

-- ========== MAIN ==========
function main()
    while not isSampAvailable() do wait(100) end

    inicfg = require 'inicfg'
    ini = inicfg.load({ config = { theme = 1 } }, configFile)
    inicfg.save(ini, configFile)
    selectedTheme = tonumber(ini.config.theme) or 1

    sampRegisterChatCommand("sm", function()
        windowOpen[0] = not windowOpen[0]
    end)
    sampRegisterChatCommand("scriptmanager", function()
        windowOpen[0] = not windowOpen[0]
    end)

    sampAddChatMessage("{8E24AA}[LUA MANAGER] {FFFFFF}Loaded. Command: /sm", -1)

    while true do
        wait(0)
    end
end
