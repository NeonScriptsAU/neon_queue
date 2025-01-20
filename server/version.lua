local resourceName = 'neon_reports'
local currentVersion = GetResourceMetadata(resourceName, 'version', 0)
local currentName = GetCurrentResourceName()

if currentName == resourceName .. '-main' then
    print("^1[Warning]: Incorrect resource folder name detected.^0")
    print("^1[Hint]: Rename the folder to '^3" .. resourceName .. "^1' for proper functionality.^0")
    CreateThread(function()
        while true do
            Wait(60000)
            print("^1[Reminder]: Rename the folder to '^3" .. resourceName .. "^1'.^0")
        end
    end)
end

local function checkVersion()
    if not currentVersion then
        print("^1[Error]: Unable to determine the current version of the resource '^3" .. resourceName .. "^1'.^0")
        return
    end
    SetTimeout(1000, function()
        local token = "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"
        PerformHttpRequest(
            'https://api.github.com/repos/NeonScriptsAU/' .. resourceName .. '/releases/latest',
            function(status, response)
                if status ~= 200 then
                    print("^1[Error]: Unable to check for updates. Status code: ^3" .. status .. "^0")
                    return
                end
                response = json.decode(response)
                local latestVersion = response.tag_name
                if not latestVersion or latestVersion == currentVersion then return end
                if latestVersion ~= currentVersion then
                    print("^3[Update Available]: A new version of '^2" .. resourceName .. "^3' is now available!^0")
                    print("^3Your Version: ^1" .. currentVersion .. "^0 | Latest Version: ^2" .. latestVersion .. "^0")
                    print("^3Download it now from: ^5https://keymaster.fivem.net/asset-grants")
                    print("^3For more details, join our community Discord: ^5https://discord.gg/neonscripts^0")
                end
            end,
            'GET',
            '',
            {
                ['Authorization'] = 'token ' .. token
            }
        )
    end)
end

local function showAmazingMessage()
    SetTimeout(1500, function()
        print(' ')
        print('^5███╗   ██╗███████╗ ██████╗ ███╗   ██╗^0')
        print('^5████╗  ██║██╔════╝██╔═══██╗████╗  ██║^0')
        print('^5██╔██╗ ██║█████╗  ██║   ██║██╔██╗ ██║^0')
        print('^5██║╚██╗██║██╔══╝  ██║   ██║██║╚██╗██║^0')
        print('^5██║ ╚████║███████╗╚██████╔╝██║ ╚████║^0')
        print('^5╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝^0')
        print(' ')
        print('^5Congratulations! You’ve unlocked our amazing scripts.^0')
    end)
end

if Config.VersionChecker then
    checkVersion()
end

if Config.AmazingScripts then
    showAmazingMessage()
end