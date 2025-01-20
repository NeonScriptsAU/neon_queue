-- Access the Queue from the main server context
local Queue = Queue or {} -- Reference the shared Queue table
local PlayerCount = PlayerCount or 0 -- Reference the shared PlayerCount

-- Register force_push command
RegisterCommand("force_push", function(source, args, rawCommand)
    -- Validate arguments
    if #args < 1 then
        print("^1Usage: force_push <position>^7")
        return
    end

    -- Parse the position argument
    local position = tonumber(args[1])
    if not position or position < 1 or position > #Queue then
        print(string.format("^1Invalid position provided. Make sure it's a valid queue position (1-%d). Current queue size: %d^7", #Queue, #Queue))
        return
    end

    -- Fetch the player at the specified position
    local player = Queue[position]
    if not player then
        print(string.format("^1No player found at position %d in the queue.^7", position))
        return
    end

    -- Remove the player from the queue
    table.remove(Queue, position)

    -- Allow the player to connect
    if player.deferrals then
        -- Display connecting message before allowing in
        player.deferrals.update(Config.ConnectingMessage)
        Wait(Config.ConnectMessageLength)

        player.deferrals.done()
        PlayerCount = PlayerCount + 1
        print(string.format("^2Force pushed player: %s (Source: %d) | Queue Position: %d into the server.^7", player.name, player.source, position))
    else
        print(string.format("^1Player at position %d had no deferrals.^7", position))
    end

    -- Update the queue positions
    UpdateQueuePositions()

    -- Debugging: Print the updated state of the queue
    print("^3Updated Queue: ^7", json.encode(Queue))
end, true) -- true means this command can only be used by the server console
