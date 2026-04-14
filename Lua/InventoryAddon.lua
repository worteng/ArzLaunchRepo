local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local json = require("carbJsonConfig")
local sampev = require('lib.samp.events')

local renderWindow = imgui.new.bool(false)

local settings = {
    colums = imgui.new.int(6),
    shop_colums = imgui.new.int(5),
    multiply = imgui.new.float(1.1),
    inv_pos = {},
    event_added = false,
    context_menu = imgui.new.bool(true),
}

json.load(getWorkingDirectory()..'\\config\\invaddon.json', settings)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    Theme()
end)

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 400, 230
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        if imgui.Begin('Inventory addon', renderWindow, imgui.WindowFlags.NoCollapse) then
            imgui.PushItemWidth(150)
            if imgui.InputInt("Количество колонок в инвентаре", settings.shop_colums, 1, 10) then save() end
            if imgui.InputInt("Количество колонок в магазине", settings.colums, 1, 10) then save() end
            if imgui.InputFloat("Размер инвентаря", settings.multiply, 0.1, 1.0, 'X%0.2f') then save() end
            if imgui.Button("Сохранить позицию инвентаря") then
                saveInvPosition()
            end
            if imgui.Checkbox("Передвинуть контекстное меню", settings.context_menu) then save() end
            imgui.End()
        end
    end
)

function save()
    json.save(getWorkingDirectory()..'\\config\\invaddon.json', settings)
end

function main()
    while not isSampAvailable() do wait(0) end
    sampRegisterChatCommand('invaddon', function()
        renderWindow[0] = not renderWindow[0]
    end)
    if sampGetGamestate() == 3 and sampIsLocalPlayerSpawned() and not settings.event_added and settings.context_menu[0] then
        setContextMenuEvent()
        settings.event_added = true
        save()
    end
    wait(-1)
end

function onReceivePacket(id, bs)
    if id == 220 then
        raknetBitStreamReadInt8(bs);
        if raknetBitStreamReadInt8(bs) == 17 then
            raknetBitStreamReadInt32(bs)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            if length > 0 then
                local text = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
                if text == [[window.executeEvent('event.setActiveView', `["Inventory"]`);]] then
                    lua_thread.create(function ()
                        wait(1)
                        setInvSize()
                        setInvPos()
                    end)
                end
                local event, data = text:match('window%.executeEvent%(\'(.+)\',%s*`(.+)`%);');
                if event == "event.inventory.playerInventory" then
                    lua_thread.create(function ()
                        wait(1)
                        setInvSize()
                        local t_data = decodeJson(data)[1]
                        if t_data.data.items then
                            if t_data.action == 0 and t_data.data.type == 28 then
                                setItemsBlackout()
                            end
                        end
                    end)
                end
            end
        end
    end
end

function onSendPacket(id, bs, priority, reliability, orderingChannel)
    if id == 220 then
        raknetBitStreamReadInt8(bs)
        if raknetBitStreamReadInt8(bs) == 18 then
            local strlen = raknetBitStreamReadInt16(bs)
            local str = raknetBitStreamReadString(bs, strlen)
            if str:find('updateCategory|%{"category":%d+%}') then
                lua_thread.create(function ()
                    wait(1)
                    setItemsBlackout()
                end)
            end
        end
    end
end

function sampev.onSendClientJoin(version, mod, nickname, challengeResponse, joinAuthKey, clientVer, challengeResponse2)
    if settings.context_menu[0] then
        lua_thread.create(function ()
            while not sampIsLocalPlayerSpawned() do wait(0) end
            setContextMenuEvent()
            settings.event_added = true
            save()
        end)
    end
end

function sampev.onPlayerQuit(playerId, reason)
    if playerId == select(2, sampGetPlayerIdByCharHandle(1)) then
        settings.event_added = false
        save()
    end
end

function setItemsBlackout()
    evalanon([[
const lavka_items = []
const shop_inv = document.querySelector(".shop__grid-wrapper > .inventory-grid > .inventory-grid__grid");
const el = document.querySelector(".inventory-main__grid > .inventory-grid");

if(shop_inv) {
    shop_inv.querySelectorAll(".inventory-item--hoverable").forEach((el) => {
        const img = el.querySelector("img")
        const item_id = parseInt(img.src.match(/https:\/\/cdn\.azresources\.cloud\/projects\/arizona-rp\/assets\/images\/donate\/(\d+)\.webp/)[1])
        lavka_items.push(item_id)
    })
}

if(el) {
    const inv = el.querySelector(".inventory-grid__grid");
    inv.querySelectorAll(".inventory-item--hoverable").forEach((el) => {
        const img = el.querySelector("img")
        const item_id = img.src.match(/https:\/\/cdn\.azresources\.cloud\/projects\/arizona-rp\/assets\/images\/donate\/(\d+)\.webp/)[1]
        el.classList.toggle("inventory-item--disabled", !lavka_items.includes(parseInt(item_id)))
    })
}
]])
end

function setInvSize()
    evalanon(string.format([[
const multiply = %s
const inv = document.querySelectorAll(".inventory-grid");

const comma_value = (n) => {
    const match = n.match(/^([^\d]*\d)(\d*)(.*)$/);
    if (!match) return n;
    
    const left = match[1];
    const num = match[2];
    const right = match[3];
    
    const formattedNum = num
        .split('').reverse().join('')
        .replace(/(\d{3})/g, '$1.')
        .split('').reverse().join('');
    
    return left + formattedNum + right;
}

inv.forEach((el) => {
    if(el) {
        if (el.parentElement.className == "inventory-main__grid") {
            el.style.setProperty("--columns-count", "%s")
        } else if (el.parentElement.className == "shop__grid-wrapper") {
            el.style.setProperty("--columns-count", "%s")
        }
        const inv = el.querySelector(".inventory-grid__grid");
        const setSize = (el, multiply) => {
            let p1 = 80 * multiply
            let p2 = 0.44 * multiply
            const size = `max(calc((var(--global-scale)*${p1}*var(--global-scale) - var(--global-scale)*${p1}*var(--global-scale)*${p2})/(var(--global-scale)*1920 - var(--global-scale)*800))*100vw + calc((var(--global-scale)*${p1}*var(--global-scale)*${p2} - (var(--global-scale)*${p1}*var(--global-scale) - var(--global-scale)*${p1}*var(--global-scale)*${p2})/(var(--global-scale)*1920 - var(--global-scale)*800)*800*var(--global-scale))*1px), 1px)`
            el.style.width = size
            el.style.height = size
        }
        const setElementsSize = (elements) => {
            elements.forEach((cl) => {
                inv.querySelectorAll(cl).forEach((el) => {
                    setSize(el, multiply)
                })
            })
        }
        setElementsSize([".inventory-item", ".inventory-item__background", ".inventory-item__hover-overlay"])
        inv.querySelectorAll(".inventory-item__amount").forEach((el) => {
            el.textContent = comma_value(el.textContent)
            let p2 = 0.44 * multiply
            let p3 = 12 * multiply
            const fsize = `max(calc((var(--global-scale)*${p3}*var(--global-scale) - var(--global-scale)*${p3}*var(--global-scale)*${p2})/(var(--global-scale)*1920 - var(--global-scale)*800))*100vw + calc((var(--global-scale)*${p3}*var(--global-scale)*${p2} - (var(--global-scale)*${p3}*var(--global-scale) - var(--global-scale)*${p3}*var(--global-scale)*${p2})/(var(--global-scale)*1920 - var(--global-scale)*800)*800*var(--global-scale))*1px), 1px)`
            el.style.fontSize = fsize
        })
    }
})
]], settings.multiply[0], settings.colums[0], settings.shop_colums[0]))
end

function setContextMenuEvent()
    evalanon([[document.addEventListener("mouseup", (e) => {
    if (e.button == 2) {
        setTimeout(() => {
            const context = document.querySelector('.inventory-item-context-menu-wrapper')
            if (context) {
                const w = context.querySelector('.inventory-window')
                let currentL = context.style.left
                let currentT = context.style.top
                const left = `calc(${currentL} - 2vw)`
                const top = `calc(${currentT} - 2vh)`
                context.style.left = left
                context.style.top = top
                w.style.left =  left
                w.style.top = top
            }
        }, 1);
    }
})]])
end

function saveInvPosition()
    local function clearCEFlog()
        local file = io.open(getGameDirectory()..'\\cef\\!CEFLOG.txt', 'w')
        if file then
            file:write("")
            file:close()
        end
    end
    lua_thread.create(function ()
        clearCEFlog()
        evalanon([[const windows = document.querySelectorAll(".inventory-window")
        windows.forEach((el) => {
            console.log(`inventory pos element: .${el.parentElement.className} > .inventory-window : ${el.style.left}|${el.style.top}`);
        })]])
        wait(100)
        for line in io.lines(getGameDirectory()..'\\cef\\!CEFLOG.txt') do
            if line:find('%[.+%] "inventory pos element: (.+) : (.+)|(.+)", source: .+') then
                local qsel, left, top = line:match('%[.+%] "inventory pos element: (.+) : (.+)|(.+)", source: .+')
                settings.inv_pos[qsel] = {left, top}
            end
        end
        save()
        clearCEFlog()
    end)
end

function setInvPos()
    for k, v in pairs(settings.inv_pos) do
        evalanon(string.format([[const windows = document.querySelectorAll("%s")
        windows.forEach((el) => {
            el.style.left = "%s"
            el.style.top = "%s"
        })]], k, v[1], v[2]))
    end
end

function evalanon(code)
    evalcef(("(() => {%s})()"):format(code))
end

function evalcef(code, encoded)
    encoded = encoded or 0
    local bs = raknetNewBitStream();
    raknetBitStreamWriteInt8(bs, 17);
    raknetBitStreamWriteInt32(bs, 0);
    raknetBitStreamWriteInt16(bs, #code);
    raknetBitStreamWriteInt8(bs, encoded);
    raknetBitStreamWriteString(bs, code);
    raknetEmulPacketReceiveBitStream(220, bs);
    raknetDeleteBitStream(bs);
end

function myId()
    return select(2, sampGetPlayerIdByCharHandle(1))
end

function Theme()
    local style = imgui.GetStyle()
    local colors = style.Colors

    style.Alpha = 1.0
    style.WindowPadding = imgui.ImVec2(10.00, 10.00)
    style.WindowRounding = 0.0
    style.WindowBorderSize = 2.0
    style.WindowMinSize = imgui.ImVec2(50.00, 50.00)
    style.WindowTitleAlign = imgui.ImVec2(0.50, 0.50)
    style.ChildRounding = 8.0
    style.ChildBorderSize = 1.0
    style.PopupRounding = 8.0
    style.PopupBorderSize = 1.0
    style.FramePadding = imgui.ImVec2(12.00, 6.00)
    style.FrameRounding = 8.0
    style.FrameBorderSize = 1.0
    style.ItemSpacing = imgui.ImVec2(10.00, 8.00)
    style.ItemInnerSpacing = imgui.ImVec2(8.00, 6.00)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 16.0
    style.ScrollbarRounding = 12.0
    style.GrabMinSize = 14.0
    style.GrabRounding = 8.0
    style.TabRounding = 10.0

    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50)
    style.SelectableTextAlign = imgui.ImVec2(0.50, 0.50)
    colors[imgui.Col.Text] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.05, 0.05, 0.20, 0.95)
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.10, 0.10, 0.30, 0.50)
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.10, 0.10, 0.10, 1.00)
    colors[imgui.Col.Border] = imgui.ImVec4(0.30, 0.30, 1.00, 1.00)
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.20, 0.20, 0.60, 1.00)
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.25, 0.25, 0.80, 1.00)
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.30, 0.30, 0.90, 1.00)
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.10, 0.10, 0.20, 1.00)
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.20, 0.20, 0.40, 1.00)
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.20, 0.20, 0.40, 0.75)
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.15, 0.15, 0.35, 0.60)
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.30, 0.30, 0.90, 0.80)
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.40, 0.40, 1.00, 0.90)
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.50, 0.50, 1.00, 1.00)
    colors[imgui.Col.Button] = imgui.ImVec4(0.20, 0.20, 0.50, 1.00)
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.30, 0.30, 0.70, 1.00)
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.40, 0.40, 0.80, 1.00)
    colors[imgui.Col.Header] = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.70, 0.70, 0.70, 1.00)
    colors[imgui.Col.Tab] = imgui.ImVec4(0.35, 0.35, 0.35, 1.00)
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.55, 0.55, 0.55, 1.00)
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.75, 0.75, 0.75, 1.00)
    colors[imgui.Col.PlotLines] = imgui.ImVec4(0.85, 0.85, 0.85, 1.00)
    colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.85, 0.85, 0.85, 1.00)
    colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.60, 0.60, 0.60, 0.35)
    colors[imgui.Col.DragDropTarget] = imgui.ImVec4(0.85, 0.85, 0.50, 0.90)
    colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.85, 0.85, 0.85, 1.00)
    colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.20)
    colors[imgui.Col.CheckMark] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.35)
end