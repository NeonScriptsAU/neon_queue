local Config = Config or {}
Queue = Queue or {}
PlayerCount = PlayerCount or 0
local GracePlayers = {} -- Tracks players in the grace period by Discord ID
local ReservedSlotsUsed = 0 -- Tracks how many reserved slots are in use
local MinimumQueueWait = 3000 -- Minimum time (in ms) a player must wait in the queue
local IsProcessingQueue = false -- Prevents simultaneous queue processing

-- Function to check if the queue can move forward
local function CheckQueue()
    if IsProcessingQueue or #Queue == 0 then return end -- Prevent simultaneous processing
    IsProcessingQueue = true

    local player = Queue[1] -- Process the first player in the queue
    local elapsedTime = GetGameTimer() - player.startTime

    -- Process the player asynchronously
    CreateThread(function()
        if elapsedTime < MinimumQueueWait then
            Wait(MinimumQueueWait - elapsedTime) -- Enforce minimum wait
        end

        if player.rank.reserved or PlayerCount < Config.MaxSlots then
            table.remove(Queue, 1) -- Remove the player from the queue
            player.deferrals.update(Config.ConnectingMessage) -- Display connecting message
            Wait(Config.ConnectMessageLength or 4000) -- Allow time for the connecting message
            player.deferrals.done() -- Connect the player
            PlayerCount = PlayerCount + 1
            print(string.format("^2Player Connecting: %s | Discord Rank: %s^7", player.name, player.rank.id))
            UpdateQueuePositions()
        end

        IsProcessingQueue = false
        CheckQueue() -- Process the next player in the queue
    end)
end

-- Function to remove a player from the queue
local function RemoveFromQueue(src)
    for i, player in ipairs(Queue) do
        if player.source == src then
            table.remove(Queue, i)
            return true
        end
    end
    return false
end

-- Function to calculate time in Xm XXs format
local function FormatWaitTime(startTime)
    local elapsedTime = GetGameTimer() - startTime
    local totalSeconds = math.floor(elapsedTime / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return minutes, seconds
end

-- Function to update all queue positions continuously
CreateThread(function()
    while true do
        UpdateQueuePositions() -- Continuously update queue positions
        Wait(1000) -- Update every second
    end
end)

-- Function to update all queue positions
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

-- Function to sort the queue by priority (rank power)
local function SortQueue()
    table.sort(Queue, function(a, b)
        return a.rank.power < b.rank.power
    end)
end

-- Event to track player joins
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update("Checking server slots...")

    PlayerCount = GetNumPlayerIndices()
    local sv_maxclients = GetConvarInt('sv_maxclients', Config.MaxSlots)

    -- Fetch Discord ID
    local discordID = nil
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.find(id, "discord:") then
            discordID = string.sub(id, 9)
            break
        end
    end

    if not discordID then
        deferrals.done("❌ You must have Discord linked to join this server.")
        return
    end

    GetPlayerQueueRank(src, function(playerRank)
        playerRank = playerRank or {power = math.huge, reserved = false}
        print(string.format("^3Player Attempting to Connect: %s | Discord Rank: %s^7", name, playerRank.id or "Unranked"))

        -- Handle Reserved Slots
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
            CheckQueue() -- Process the queue
            return
        end

        -- Handle Grace Period
        if GracePlayers[discordID] then
            table.insert(Queue, 1, {
                source = src,
                name = name,
                deferrals = deferrals,
                startTime = GetGameTimer(),
                rank = playerRank,
                discordID = discordID
            })
            GracePlayers[discordID] = nil -- Remove from grace list
            print(string.format("^2Player Reconnected: %s | Grace Period Active. Placed at the front of the queue.^7", name))
            UpdateQueuePositions()
            CheckQueue() -- Process the queue
            return
        end

        -- Add the player to the queue regardless of available slots
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

        -- Wait for their turn in the queue
        while true do
            PlayerCount = GetNumPlayerIndices()
            if Queue[1] and Queue[1].source == src then
                CheckQueue()
                return
            end

            -- If the player disconnects while waiting
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

-- Event to track player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    local discordID = nil

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.find(id, "discord:") then
            discordID = string.sub(id, 9)
            break
        end
    end

    if discordID then
        GracePlayers[discordID] = GetGameTimer() + Config.GracePeriod
        print(string.format("^1Player Disconnected: Discord ID: %s | Grace Period Started.^7", discordID))
    end

    PlayerCount = GetNumPlayerIndices()
    CheckQueue()
end)

-- Clean up expired grace periods
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