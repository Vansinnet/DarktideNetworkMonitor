---@class DarktideNetworkMonitorMod
local mod = get_mod("DarktideNetworkMonitor")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "show_only_with_tactical_overlay",
                type = "checkbox",
                default_value = false,
                tooltip = "show_only_with_tactical_overlay_tooltip",
            },
            {
                setting_id = "ui_group",
                type = "group",
                tooltip = "ui_group_tooltip",
                sub_widgets = {
                    { setting_id = "show_accent_line", type = "checkbox", default_value = false,
                        tooltip = "show_accent_line_tooltip" },
                    {
                        setting_id = "x_offset",
                        type = "numeric",
                        default_value = 0,
                        tooltip = "x_offset_tooltip",
                        range = { -1000, 1000 },
                    },
                    {
                        setting_id = "y_offset",
                        type = "numeric",
                        default_value = 0,
                        tooltip = "y_offset_tooltip",
                        range = { -1000, 1000 },
                    },
                },
            },
            {
                setting_id = "statistics_group",
                type = "group",
                tooltip = "statistics_group_tooltip",
                sub_widgets = {
                    { setting_id = "show_ping", type = "checkbox", default_value = true,
                        tooltip = "show_ping_tooltip" },
                    { setting_id = "show_average", type = "checkbox", default_value = true,
                        tooltip = "show_average_tooltip" },
                    { setting_id = "show_jitter", type = "checkbox", default_value = true,
                        tooltip = "show_jitter_tooltip" },
                    { setting_id = "show_minimum", type = "checkbox", default_value = true,
                        tooltip = "show_minimum_tooltip" },
                    { setting_id = "show_maximum", type = "checkbox", default_value = true,
                        tooltip = "show_maximum_tooltip" },
                    { setting_id = "show_tick_rate", type = "checkbox", default_value = false,
                        tooltip = "show_tick_rate_tooltip" },
                    { setting_id = "show_send_buffer", type = "checkbox", default_value = false,
                        tooltip = "show_send_buffer_tooltip" },
                    { setting_id = "show_endpoint", type = "checkbox", default_value = false,
                        tooltip = "show_endpoint_tooltip" },
                    { setting_id = "show_region", type = "checkbox", default_value = true,
                        tooltip = "show_region_tooltip" },
                },
            },
        },
    },
}
