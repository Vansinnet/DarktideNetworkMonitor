---@class DarktideNetworkMonitorMod
local mod = get_mod("DarktideNetworkMonitor")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local class = rawget(_G, "class")

local HudElementDarktideNetworkMonitor = class("HudElementDarktideNetworkMonitor", "HudElementBase")

local WIDTH = 780
local HEIGHT = 64
local COMPACT_HEIGHT = 38
local BASE_Y = 18
local STAT_COLUMN_WIDTH = 150
local COLORS = {
    measuring = { 190, 148, 180, 166 },
    good = { 255, 92, 220, 130 },
    warning = { 255, 240, 190, 75 },
    bad = { 255, 240, 91, 77 },
    neutral = { 255, 148, 205, 230 },
}
local STAT_LAYOUT = {
    { id = "ping", setting = "show_ping" },
    { id = "average", setting = "show_average" },
    { id = "jitter", setting = "show_jitter" },
    { id = "minimum", setting = "show_minimum" },
    { id = "maximum", setting = "show_maximum" },
    { id = "tick_rate", setting = "show_tick_rate" },
    { id = "send_buffer", setting = "show_send_buffer" },
}

local function stat_text_pass(value_id, x, width)
    return {
        pass_type = "text",
        value_id = value_id,
        value = "",
        style_id = value_id,
        visibility_function = function(content)
            return content[value_id .. "_visible"]
        end,
        style = {
            font_type = "machine_medium",
            font_size = 18,
            offset = { x, 7, 2 },
            size = { width, 27 },
            text_horizontal_alignment = "center",
            text_vertical_alignment = "center",
            text_color = { COLORS.measuring[1], COLORS.measuring[2], COLORS.measuring[3], COLORS.measuring[4] },
        },
    }
end

local function latency_color(value)
    if value <= 80 then
        return COLORS.good
    elseif value <= 140 then
        return COLORS.warning
    end

    return COLORS.bad
end

local function jitter_color(value)
    if value <= 5 then
        return COLORS.good
    elseif value <= 15 then
        return COLORS.warning
    end

    return COLORS.bad
end

local function send_buffer_color(value)
    if value < 8000 then
        return COLORS.bad
    elseif value < 16384 then
        return COLORS.warning
    end

    return COLORS.good
end

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    panel = {
        parent = "screen",
        vertical_alignment = "top",
        horizontal_alignment = "center",
        size = { WIDTH, HEIGHT },
        position = { 0, 18, 100 },
    },
}

local widget_definitions = {
    panel = UIWidget.create_definition({
        {
            pass_type = "rect",
            style_id = "accent",
            visibility_function = function(content)
                return content.accent_visible
            end,
            style = {
                vertical_alignment = "top",
                size = { WIDTH, 2 },
                offset = { 0, 0, 1 },
                color = { 230, 84, 170, 137 },
            },
        },
        stat_text_pass("ping", 15, STAT_COLUMN_WIDTH),
        stat_text_pass("average", 165, STAT_COLUMN_WIDTH),
        stat_text_pass("jitter", 315, STAT_COLUMN_WIDTH),
        stat_text_pass("minimum", 465, STAT_COLUMN_WIDTH),
        stat_text_pass("maximum", 615, STAT_COLUMN_WIDTH),
        stat_text_pass("tick_rate", 765, STAT_COLUMN_WIDTH),
        stat_text_pass("send_buffer", 915, STAT_COLUMN_WIDTH),
        {
            pass_type = "text",
            value_id = "endpoint",
            value = "",
            style_id = "endpoint",
            visibility_function = function(content)
                return content.endpoint_visible
            end,
            style = {
                font_type = "machine_medium",
                font_size = 14,
                offset = { 14, 34, 2 },
                size = { WIDTH - 28, 22 },
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                text_color = { 215, 148, 180, 166 },
            },
        },
    }, "panel"),
}

HudElementDarktideNetworkMonitor.init = function(self, parent, draw_layer, start_scale)
    HudElementDarktideNetworkMonitor.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    self._last_revision = -1
end

HudElementDarktideNetworkMonitor.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local stats = mod.server_stats()
    local revision = stats.revision or 0

    if revision ~= self._last_revision then
        self._last_revision = revision

        local widget = self._widgets_by_name.panel
        local settings = mod.hud_settings()
        local endpoint = mod.server_endpoint() or mod:localize("unavailable")
        local region = Managers.connection and Managers.connection:region() or mod:localize("unknown")
        local content = widget.content
        local style = widget.style
        local visible_stat_count = 0
        for i = 1, #STAT_LAYOUT do
            local entry = STAT_LAYOUT[i]
            local visible = settings[entry.setting]
            content[entry.id .. "_visible"] = visible

            if visible then
                visible_stat_count = visible_stat_count + 1
            end
        end

        local show_endpoint_line = settings.show_endpoint or settings.show_region
        local stats_width = visible_stat_count > 0 and visible_stat_count * STAT_COLUMN_WIDTH + 30 or 0
        local panel_width = math.max(show_endpoint_line and WIDTH or 1, stats_width)
        local panel_height = show_endpoint_line and visible_stat_count > 0 and HEIGHT or COMPACT_HEIGHT
        local stat_x = (panel_width - visible_stat_count * STAT_COLUMN_WIDTH) * 0.5

        for i = 1, #STAT_LAYOUT do
            local entry = STAT_LAYOUT[i]
            if settings[entry.setting] then
                style[entry.id].offset[1] = stat_x
                stat_x = stat_x + STAT_COLUMN_WIDTH
            end
        end

        content.endpoint_visible = show_endpoint_line
        content.accent_visible = settings.show_accent_line
        self:_set_scenegraph_size("panel", panel_width, panel_height)
        self:set_scenegraph_position("panel", settings.x_offset, BASE_Y - settings.y_offset)
        style.accent.size[1] = panel_width
        style.endpoint.offset[2] = visible_stat_count > 0 and 34 or 7
        style.endpoint.size[1] = math.max(panel_width - 28, 1)

        if stats.current_ping then
            content.ping = mod:localize("hud_ping", mod:localize("milliseconds", stats.current_ping))
            content.average = mod:localize("hud_average", mod:localize("milliseconds", stats.average_ping))
            content.jitter = mod:localize("hud_jitter", mod:localize("milliseconds", stats.jitter))
            content.minimum = mod:localize("hud_minimum", mod:localize("milliseconds", stats.minimum_ping))
            content.maximum = mod:localize("hud_maximum", mod:localize("milliseconds", stats.maximum_ping))
            content.tick_rate = stats.tick_rate and mod:localize("hud_tick_rate", stats.tick_rate)
                or mod:localize("hud_tick_rate_measuring")
            content.send_buffer = stats.send_buffer and mod:localize("hud_send_buffer", stats.send_buffer / 1024)
                or mod:localize("hud_send_buffer_measuring")
            style.ping.text_color = latency_color(stats.current_ping)
            style.average.text_color = latency_color(stats.average_ping)
            style.jitter.text_color = jitter_color(stats.jitter)
            style.minimum.text_color = latency_color(stats.minimum_ping)
            style.maximum.text_color = latency_color(stats.maximum_ping)
            style.tick_rate.text_color = COLORS.neutral
            style.send_buffer.text_color = stats.send_buffer and send_buffer_color(stats.send_buffer) or COLORS.measuring
        else
            local measuring = mod:localize("measuring")
            content.ping = mod:localize("hud_ping", measuring)
            content.average = mod:localize("hud_average", measuring)
            content.jitter = mod:localize("hud_jitter", measuring)
            content.minimum = mod:localize("hud_minimum", measuring)
            content.maximum = mod:localize("hud_maximum", measuring)
            content.tick_rate = mod:localize("hud_tick_rate_measuring")
            content.send_buffer = mod:localize("hud_send_buffer_measuring")
            style.ping.text_color = COLORS.measuring
            style.average.text_color = COLORS.measuring
            style.jitter.text_color = COLORS.measuring
            style.minimum.text_color = COLORS.measuring
            style.maximum.text_color = COLORS.measuring
            style.tick_rate.text_color = COLORS.measuring
            style.send_buffer.text_color = COLORS.measuring
        end

        if settings.show_endpoint and settings.show_region then
            content.endpoint = mod:localize(stats.endpoint_accelerated
                and "hud_endpoint_accelerated" or "hud_endpoint", endpoint, region)
        elseif settings.show_endpoint then
            content.endpoint = mod:localize(stats.endpoint_accelerated
                and "hud_endpoint_only_accelerated" or "hud_endpoint_only", endpoint)
        elseif settings.show_region then
            content.endpoint = mod:localize("hud_region_only", region)
        else
            content.endpoint = ""
        end

        widget.dirty = true
    end

    HudElementDarktideNetworkMonitor.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudElementDarktideNetworkMonitor.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    local settings = mod.hud_settings()
    local has_visible_value = settings.show_ping or settings.show_average or settings.show_jitter or settings.show_minimum
        or settings.show_maximum or settings.show_tick_rate or settings.show_send_buffer
        or settings.show_endpoint or settings.show_region

    local tactical_overlay_visible = not settings.show_only_with_tactical_overlay
        or self._parent:tactical_overlay_active()

    if has_visible_value and tactical_overlay_visible and mod.server_stats().connected then
        HudElementDarktideNetworkMonitor.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
    end
end

return HudElementDarktideNetworkMonitor
