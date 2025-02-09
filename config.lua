Config = {}

Config.AmazingScripts = true
Config.VersionChecker = true

-- Maximum number of players allowed before queueing starts
Config.MaxSlots = 1

-- Number of reserved slots for high-priority players
Config.ReservedSlots = 10

-- Queue message shown to players
Config.QueueMessage = "⏳ You are %d/%d in the queue | Time waited: %dm %02ds"

-- Message shown to the next player in the queue
Config.NextPersonMessage = "🥇 You are %d/%d in the queue | Time waited: %dm %02ds"

-- Message displayed when the player is connecting
Config.ConnectingMessage = "🎉 You are Connecting! Get ready..."
Config.ConnectMessageLength = 2000

-- Grace period for disconnected players to rejoin the queue (in milliseconds)
Config.GracePeriod = 60000 -- 1 minute

Config.DiscordInvite = "https://discord.gg/invitecode" -- Set your Discord invite here

-- Role-based prioritization
Config.QueueRanks = {
    ["owner"] = {
        id = "123123123123", -- Discord Role ID
        power = 1, -- Higher priority (lower number = higher priority)
        reserved = true, -- Can bypass the queue if reserved slots are available
        require = false -- True means they will require this role to join the server 
    },
    ["support"] = {
        id = "1231231231234",
        power = 2,
        reserved = false,
        require = false
    },
    ["user"] = {
        id = "1231231231235",
        power = 3,
        reserved = false,
        require = true
    }
}