local Config = Config or {}

function tableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if tostring(v) == tostring(val) then
            return true
        end
    end
    return false
end

CreateThread(function()
    local endpoint = string.format("https://discord.com/api/guilds/%s", Config.Discord.GuildId)
    local headers = {
        ["Authorization"] = "Bot " .. Config.Discord.BotToken,
        ["Content-Type"] = "application/json"
    }

    PerformHttpRequest(endpoint, function(statusCode, response, _)
        if statusCode == 200 then
            local guildData = json.decode(response)
            if guildData and guildData.name then
                print(string.format("^2Connected to: %s | Guild ID: %s^7", guildData.name, Config.Discord.GuildId))
            else
                print("^1Error: Could not fetch guild information.^7")
            end
        else
            print("^1Error: Failed to connect to Discord API. Check your BotToken and GuildId.^7")
        end
    end, "GET", "", headers)
end)

function GetPlayerDiscordRoles(src, callback)
    if type(callback) ~= "function" then
        print("^1Error: Callback is not a valid function for GetPlayerDiscordRoles^7")
        return
    end

    local identifier = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.find(id, "discord:") then
            identifier = string.sub(id, 9)
            break
        end
    end

    if not identifier then
        print("^1No Discord identifier found for player: ^7", src)
        callback({})
        return
    end

    local endpoint = string.format(
        "https://discord.com/api/guilds/%s/members/%s",
        Config.Discord.GuildId,
        identifier
    )

    local headers = {
        ["Authorization"] = "Bot " .. Config.Discord.BotToken,
        ["Content-Type"] = "application/json"
    }

    PerformHttpRequest(endpoint, function(statusCode, response, _)
        if statusCode == 200 then
            local memberData = json.decode(response)
            if memberData and memberData.roles then
                callback(memberData.roles)
            else
                print("^1Failed to fetch roles for player: ^7", src)
                callback({})
            end
        else
            print("^1Discord API Error: ^7", statusCode, response)
            callback({})
        end
    end, "GET", "", headers)
end

function GetPlayerQueueRank(src, callback)
    if type(callback) ~= "function" then
        print("^1Error: Callback is not a valid function for GetPlayerQueueRank^7")
        return
    end

    GetPlayerDiscordRoles(src, function(roles)
        local highestPower = nil

        for rankName, rankData in pairs(Config.QueueRanks) do
            if roles and tableContains(roles, rankData.id) then
                if not highestPower or rankData.power < highestPower.power then
                    highestPower = rankData
                end
            end
        end

        callback(highestPower)
    end)
end