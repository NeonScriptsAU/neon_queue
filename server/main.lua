local Config = Config or {}
Queue = Queue or {}
PlayerCount = PlayerCount or 0
local GracePlayers = {}
local MinimumQueueWait = 3000
local IsProcessingQueue = false
local LastQueueWarnings = {}
LastQueueMessages = LastQueueMessages or {}

local function RemoveFromQueue(src)
    for i = #Queue, 1, -1 do
        if Queue[i].source == src then
            print(string.format("^1Removing Player from Queue: %s | Position: %d/%d^7", Queue[i].name, i, #Queue))
            table.remove(Queue, i)
            UpdateQueuePositions()
            return true
        end
    end
    return false
end

local function CheckQueue()
    if IsProcessingQueue or #Queue == 0 then return end
    IsProcessingQueue = true

    UpdateQueuePositions()

    local player = Queue[1]
    if not player then
        IsProcessingQueue = false
        return
    end

    if not GetPlayerName(player.source) then
        print(string.format("^1[Queue] Player %s disconnected before processing | Removing from queue^7", player.name))
        RemoveFromQueue(player.source)
        IsProcessingQueue = false
        Wait(1000)
        return CheckQueue()
    end

    local elapsedTime = GetGameTimer() - player.startTime
    if elapsedTime < MinimumQueueWait then
        Wait(MinimumQueueWait - elapsedTime)
    end

    local maxClients = Config.MaxSlots
    local currentPlayerCount = GetNumPlayerIndices()

    if not player.rank.reserved and currentPlayerCount >= maxClients then
        if not LastQueueWarnings[player.source] then
            print(string.format("^1[Queue] Regular player %s blocked, server full^7", player.name))
            LastQueueWarnings[player.source] = true
        end
        IsProcessingQueue = false
        Wait(1000)
        return CheckQueue()
    else
        LastQueueWarnings[player.source] = nil
    end

    RemoveFromQueue(player.source)

    player.deferrals.update(Config.ConnectingMessage)
    Wait(Config.ConnectMessageLength)
    player.deferrals.done()

    print(string.format("^2[Queue] Player Connecting: %s | Discord Rank: %s | Reserved: %s^7", 
        player.name, player.rank.id, tostring(player.rank.reserved)))

    IsProcessingQueue = false
    Wait(1000)
    CheckQueue()
end

local function FormatWaitTime(startTime)
    local elapsedTime = GetGameTimer() - startTime
    local totalSeconds = math.floor(elapsedTime / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return minutes, seconds
end

CreateThread(function()
    while true do
        UpdateQueuePositions()
        Wait(1000)
    end
end)

function UpdateQueuePositions()
    local queueState = {}

    for i = #Queue, 1, -1 do
        local player = Queue[i]

        if not GetPlayerName(player.source) then
            print(string.format("^1[Queue] Removing Disconnected Player: %s (Discord ID: %s) from Queue^7", player.name, player.discordID))
            table.remove(Queue, i)
        else
            local position = i
            local minutes, seconds = FormatWaitTime(player.startTime)

            local message = Config.QueueMessage
            if position == 1 then
                message = Config.NextPersonMessage
            end

            player.deferrals.update(string.format(message, position, #Queue, minutes, seconds))

            table.insert(queueState, string.format("Position %d: %s | Power: %d", position, player.name, player.rank.power))
        end
    end

    local newQueueState = table.concat(queueState, "\n")
    if newQueueState ~= lastLoggedQueueState then
        print("^3[Queue] Updated Queue Order:^7")
        print(newQueueState)
        lastLoggedQueueState = newQueueState
    end
end

CreateThread(function()
    while true do
        Wait(5000)

        local removedPlayers = false
        for i = #Queue, 1, -1 do
            local player = Queue[i]
            if not GetPlayerName(player.source) then
                print(string.format("^1Removing Disconnected Player: %s (Discord ID: %s) from Queue^7", player.name, player.discordID))
                table.remove(Queue, i)
                removedPlayers = true
            end
        end

        if removedPlayers then
            UpdateQueuePositions()
            CheckQueue()
        end
    end
end)

local function SortQueue()
    table.sort(Queue, function(a, b)
        if a.rank.power ~= b.rank.power then
            return a.rank.power < b.rank.power
        else
            return a.startTime < b.startTime
        end
    end)
end

local function AddPlayerToQueue(player)
    local inserted = false

    for i, queuedPlayer in ipairs(Queue) do
        if player.rank.power < queuedPlayer.rank.power then
            table.insert(Queue, i, player)
            inserted = true
            break
        elseif player.rank.power == queuedPlayer.rank.power then
            local lastIndex = i
            while lastIndex < #Queue and Queue[lastIndex + 1].rank.power == player.rank.power do
                lastIndex = lastIndex + 1
            end
            table.insert(Queue, lastIndex + 1, player)
            inserted = true
            break
        end
    end

    if not inserted then
        table.insert(Queue, player)
    end

    SortQueue()
    UpdateQueuePositions()
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update("Checking your Discord roles...")

    local discordID = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.find(id, "discord:") then
            discordID = string.sub(id, 9)
            break
        end
    end

    if not discordID then
        local card = {
            type = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            version = "1.6",
            body = {
                {
                    type = "TextBlock",
                    text = "Discord Not Linked",
                    weight = "Bolder",
                    size = "Large",
                    horizontalAlignment = "center"
                },
                {
                    type = "TextBlock",
                    text = "You must have Discord linked to join this server. Please link your Discord account to your FiveM profile.",
                    wrap = true,
                    horizontalAlignment = "center"
                }
            },
            actions = {
                {
                    type = "Action.OpenUrl",
                    title = "Join Discord",
                    url = Config.DiscordInvite
                }
            }
        }
        deferrals.presentCard(card, function()
            deferrals.done("Please join our Discord to proceed.")
        end)
        return
    end

    GetPlayerDiscordRoles(src, function(roles)
        local playerRank = nil
        local hasRequiredRole = false

        for rankName, rankData in pairs(Config.QueueRanks) do
            if tableContains(roles, rankData.id) then
                if not playerRank or rankData.power < playerRank.power then
                    playerRank = rankData
                end

                if rankData.require then
                    hasRequiredRole = true
                end
            end
        end

        if not hasRequiredRole then
            local card = {
                type = "AdaptiveCard",
                ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
                version = "1.6",
                body = {
                    {
                        type = "TextBlock",
                        text = "Missing Required Role",
                        weight = "Bolder",
                        size = "Medium",
                        horizontalAlignment = "center"
                    },
                    {
                        type = "TextBlock",
                        text = "You do not have the required Discord role to join this server. Please join our Discord for assistance.",
                        wrap = true,
                        horizontalAlignment = "center"
                    },
                    {
                        type = "ColumnSet",
                        horizontalAlignment = "center",
                        columns = {
                            {
                                type = "Column",
                                width = "stretch",
                                horizontalAlignment = "center",
                                items = {
                                    {
                                        type = "ActionSet",
                                        horizontalAlignment = "center",
                                        actions = {
                                            {
                                                type = "Action.OpenUrl",
                                                title = "Join Discord",
                                                url = Config.DiscordInvite,
                                                style = "positive"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            deferrals.presentCard(card, function()
                deferrals.done("Please join our Discord to proceed.")
            end)
            return
        end

        local maxClients = Config.MaxSlots
        local playerCount = GetNumPlayerIndices()

        if playerCount < maxClients or (playerRank and playerRank.reserved == true) then
            deferrals.update(Config.ConnectingMessage)
            Wait(Config.ConnectMessageLength or 4000)
            deferrals.done()
            print(string.format("^2Player Connecting: %s | Power: %d | Reserved: %s^7", name, playerRank.power, tostring(playerRank.reserved)))
            return
        end

        if GracePlayers[discordID] then
            local graceIndex = 1
            for i, queuedPlayer in ipairs(Queue) do
                if not GracePlayers[queuedPlayer.discordID] then
                    break
                end
                graceIndex = i + 1
            end
            table.insert(Queue, graceIndex, {
                source = src,
                name = name,
                deferrals = deferrals,
                startTime = GetGameTimer(),
                rank = playerRank or {power = math.huge, reserved = false},
                discordID = discordID
            })
            GracePlayers[discordID] = nil
            UpdateQueuePositions()
            CheckQueue()
            return
        end

        local newPlayer = {
            source = src,
            name = name,
            deferrals = deferrals,
            startTime = GetGameTimer(),
            rank = playerRank or {power = math.huge, reserved = false},
            discordID = discordID
        }

        AddPlayerToQueue(newPlayer)
        SortQueue()

        UpdateQueuePositions()
        CheckQueue()
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local discordID = nil

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.find(id, "discord:") then
            discordID = string.sub(id, 9)
            break
        end
    end

    local removed = RemoveFromQueue(src)

    if discordID then
        GracePlayers[discordID] = GetGameTimer() + Config.GracePeriod
        print(string.format("^1[Queue] Player Disconnected: %s | Grace Period Started | Removed from Queue: %s^7", discordID, tostring(removed)))
    end

    PlayerCount = GetNumPlayerIndices()
    UpdateQueuePositions()

    if not IsProcessingQueue then
        CheckQueue()
    end
end)


CreateThread(function()
    while true do
        Wait(5000)
        for discordID, expiration in pairs(GracePlayers) do
            if GetGameTimer() >= expiration then
                GracePlayers[discordID] = nil
                print(string.format("^1[Queue] Grace Period Expired: Discord ID: %s^7", discordID))
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= "hardcap" then return end
    StopResource(resourceName)
end)

if GetResourceState('hardcap') == 'started' then
    StopResource('hardcap')
end