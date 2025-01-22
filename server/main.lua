local Config = Config or {}
Queue = Queue or {}
PlayerCount = PlayerCount or 0
local GracePlayers = {}
local ReservedSlotsUsed = 0
local MinimumQueueWait = 3000
local IsProcessingQueue = false

local function CheckQueue()
    if IsProcessingQueue or #Queue == 0 then return end
    IsProcessingQueue = true

    local player = Queue[1]
    local elapsedTime = GetGameTimer() - player.startTime

    CreateThread(function()
        if elapsedTime < MinimumQueueWait then
            Wait(MinimumQueueWait - elapsedTime)
        end

        if player.rank.reserved or PlayerCount < Config.MaxSlots then
            table.remove(Queue, 1)
            player.deferrals.update(Config.ConnectingMessage)
            Wait(Config.ConnectMessageLength or 4000)
            player.deferrals.done()
            PlayerCount = PlayerCount + 1
            print(string.format("^2Player Connecting: %s | Discord Rank: %s^7", player.name, player.rank.id))
            UpdateQueuePositions()
        end

        IsProcessingQueue = false
        CheckQueue()
    end)
end

local function RemoveFromQueue(src)
    for i, player in ipairs(Queue) do
        if player.source == src then
            table.remove(Queue, i)
            return true
        end
    end
    return false
end

local function FormatWaitTime(startTime)
    local elapsedTime = GetGameTimer() - startTime
    local totalSeconds = math.floor(elapsedTime / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return minutes, seconds
end

local function GetPlayerDiscordIdentifier(source)
    local identifer = GetPlayerIdentifierByType(source,  "discord")
    
    return identifer and identifer:gsub("discord:", "")
end

CreateThread(function()
    while true do
        UpdateQueuePositions()
        Wait(1000)
    end
end)

function UpdateQueuePositions()
    for i, player in ipairs(Queue) do
        if GetPlayerName(player.source) then
            local position = i
            local message = Config.QueueMessage
            local minutes, seconds = FormatWaitTime(player.startTime)

            if position == 1 then
                message = Config.NextPersonMessage
            end

            player.deferrals.update(string.format(message, position, #Queue, minutes, seconds))
        else
            table.remove(Queue, i)
        end
    end
end

local function SortQueue()
    table.sort(Queue, function(a, b)
        return a.rank.power < b.rank.power
    end)
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update("Checking server slots...")

    PlayerCount = GetNumPlayerIndices()

    local discordID = GetPlayerDiscordIdentifier(src)

    if not discordID then
        deferrals.done("❌ You must have Discord linked to join this server.")
        return
    end

    GetPlayerQueueRank(src, function(playerRank)
        playerRank = playerRank or {power = math.huge, reserved = false}
        print(string.format("^3Player Attempting to Connect: %s | Discord Rank: %s^7", name, playerRank.id or "Unranked"))

        if playerRank.reserved then
            table.insert(Queue, 1, {
                source = src,
                name = name,
                deferrals = deferrals,
                startTime = GetGameTimer(),
                rank = playerRank,
                discordID = discordID
            })
            SortQueue()
            UpdateQueuePositions()
            CheckQueue()
            return
        end        

        if GracePlayers[discordID] then
            table.insert(Queue, 1, {
                source = src,
                name = name,
                deferrals = deferrals,
                startTime = GetGameTimer(),
                rank = playerRank,
                discordID = discordID
            })
            GracePlayers[discordID] = nil
            print(string.format("^2Player Reconnected: %s | Grace Period Active. Placed at the front of the queue.^7", name))
            UpdateQueuePositions()
            CheckQueue()
            return
        end

        table.insert(Queue, {
            source = src,
            name = name,
            deferrals = deferrals,
            startTime = GetGameTimer(),
            rank = playerRank,
            discordID = discordID
        })
        SortQueue()
        UpdateQueuePositions()

        while true do
            PlayerCount = GetNumPlayerIndices()
            if Queue[1] and Queue[1].source == src then
                CheckQueue()
                return
            end

            if not GetPlayerName(src) then
                RemoveFromQueue(src)
                UpdateQueuePositions()
                deferrals.done()
                return
            end

            Wait(1000)
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local discordID = GetPlayerDiscordIdentifier(src)
    
    if discordID then
        GracePlayers[discordID] = GetGameTimer() + Config.GracePeriod
        print(string.format("^1Player Disconnected: Discord ID: %s | Grace Period Started.^7", discordID))
    end

    PlayerCount = GetNumPlayerIndices()
    CheckQueue()
end)

CreateThread(function()
    while true do
        Wait(5000)
        for discordID, expiration in pairs(GracePlayers) do
            if GetGameTimer() >= expiration then
                GracePlayers[discordID] = nil
                print(string.format("^1Grace Period Expired: Discord ID: %s^7", discordID))
            end
        end
    end
end)
