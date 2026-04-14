local arz = require "arizona-events"

function arz.onArizonaDisplay(packet)
    if string.find(packet.text, "event.player.updateMoney") then
        print("##MONEY", packet.text)
        local money = decodeJson(string.match(packet.text, '`(.*)`'))[1]
        --printStringNow(data,1000)
        if money < 2000000000 then
            givePlayerMoney(PLAYER_HANDLE,money - getPlayerMoney(PLAYER_HANDLE))
        else
            money = -1 * (money / 1000)
            givePlayerMoney(PLAYER_HANDLE,money - getPlayerMoney(PLAYER_HANDLE))
        end
        --int money = getPlayerMoney(Player player)
    end
end

function main()
    wait(-1)    
end