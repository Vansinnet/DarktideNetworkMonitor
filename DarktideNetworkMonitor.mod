return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`DarktideNetworkMonitor` failed loading DMF.")
        new_mod("DarktideNetworkMonitor", {
            mod_script = "DarktideNetworkMonitor/scripts/mods/DarktideNetworkMonitor/DarktideNetworkMonitor",
            mod_data = "DarktideNetworkMonitor/scripts/mods/DarktideNetworkMonitor/DarktideNetworkMonitor_data",
            mod_localization = "DarktideNetworkMonitor/scripts/mods/DarktideNetworkMonitor/DarktideNetworkMonitor_localization",
        })
    end,
    packages = {},
}
