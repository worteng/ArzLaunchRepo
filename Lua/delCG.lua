local sampev = require 'lib.samp.events'

-- “аблица соответстви€: Ђкривойї текст -> пон€тное сообщение в чате
local messages = {
    ["ЛС ЛOОЗЕ Л~n~ЙEHПP ВEППO"] = "{FFD700}[√етто] {FFFFFF}¬ы вошли в центр гетто",
    ["ЛС МOKЕHYЗЕ~n~ЙEHПP ВEППO"] = "{FFD700}[√етто] {FFFFFF}¬ы покинули центр гетто"
}

function main()
    -- ∆дем загрузки SAMP
    while not isSampAvailable() do wait(100) end
    wait(-1)
end

-- ‘ункци€ дл€ мгновенной очистки визуального мусора с экрана
function clearVisualText()
    -- »спользуем стандартную функцию MoonLoader, чтобы "перебить" текущий текст пустой строкой
    printString(" ", 1) 
end

function sampev.onDisplayGameText(style, time, text)
    -- ѕровер€ем, есть ли вход€щий текст в нашем списке
    if messages[text] then
        -- 1. —тираем текст с экрана (чтобы не висел и не мешал)
        clearVisualText()
        
        -- 2. ѕишем красивое сообщение в чат
        sampAddChatMessage(messages[text], -1)
        
        -- 3. Ѕлокируем оригинальный GameText (чтобы не было иероглифов на экране)
        return false 
    end
end