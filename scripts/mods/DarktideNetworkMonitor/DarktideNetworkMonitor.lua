local mod = get_mod("DarktideNetworkMonitor")

local SAMPLE_INTERVAL = 1
local JITTER_SAMPLE_COUNT = 30
local HUD_ELEMENT_PATH = "DarktideNetworkMonitor/scripts/mods/DarktideNetworkMonitor/DarktideNetworkMonitor_hud"
local Network = rawget(_G, "Network")
local runtime = mod:persistent_table("runtime")
local hud_settings = {}

local function refresh_settings()
    hud_settings.show_only_with_tactical_overlay = mod:get("show_only_with_tactical_overlay") == true
    hud_settings.show_ping = mod:get("show_ping") ~= false
    hud_settings.show_average = mod:get("show_average") ~= false
    hud_settings.show_jitter = mod:get("show_jitter") ~= false
    hud_settings.show_minimum = mod:get("show_minimum") ~= false
    hud_settings.show_maximum = mod:get("show_maximum") ~= false
    hud_settings.show_tick_rate = mod:get("show_tick_rate") == true
    hud_settings.show_send_buffer = mod:get("show_send_buffer") == true
    hud_settings.show_endpoint = mod:get("show_endpoint") == true
    hud_settings.show_region = mod:get("show_region") ~= false
    hud_settings.show_accent_line = mod:get("show_accent_line") == true
    hud_settings.x_offset = mod:get("x_offset") or 0
    hud_settings.y_offset = mod:get("y_offset") or 0
end

refresh_settings()

local function clear_measurements()
    runtime.current_ping = nil
    runtime.average_ping = nil
    runtime.minimum_ping = nil
    runtime.maximum_ping = nil
    runtime.tick_rate = nil
    runtime.send_buffer = nil
    runtime.jitter = 0
    runtime.sample_total = 0
    runtime.sample_count = 0
    runtime.samples = {}
    runtime.sample_timer = 0
    runtime.revision = (runtime.revision or 0) + 1
end

local function clear_endpoint()
    runtime.endpoint_ip = nil
    runtime.endpoint_port = nil
    runtime.endpoint_accelerated = nil
    runtime.endpoint_context = nil
    runtime.endpoint_session_id = nil
end

local function leave_server()
    runtime.connected = false
    runtime.context = nil
    runtime.session_id = nil
    clear_measurements()
end

local function remote_server_context()
    local presence = Managers.presence
    if not presence or presence._current_game_state_name ~= "StateGameplay" then
        return nil
    end

    local game_mode = Managers.state and Managers.state.game_mode
    local connection = Managers.connection

    if not game_mode or not connection or not connection:is_client() then
        return nil
    end

    return game_mode:game_mode_name() == "hub" and "hub" or "mission"
end

local function begin_session(connection, context)
    local session_id = connection:session_id()

    if runtime.connected and runtime.context == context and runtime.session_id == session_id then
        return
    end

    runtime.connected = true
    runtime.context = context
    runtime.session_id = session_id
    clear_measurements()
    runtime.tick_rate = connection:tick_rate()

    if runtime.endpoint_context ~= context or runtime.endpoint_session_id ~= session_id then
        clear_endpoint()
    end
end

local function add_sample(ping_ms)
    local ping = math.floor(ping_ms + 0.5)
    local samples = runtime.samples

    samples[#samples + 1] = ping
    if #samples > JITTER_SAMPLE_COUNT then
        table.remove(samples, 1)
    end

    local total_difference = 0
    for i = 2, #samples do
        total_difference = total_difference + math.abs(samples[i] - samples[i - 1])
    end

    runtime.current_ping = ping
    runtime.sample_total = (runtime.sample_total or 0) + ping
    runtime.sample_count = (runtime.sample_count or 0) + 1
    runtime.average_ping = math.floor(runtime.sample_total / runtime.sample_count + 0.5)
    runtime.minimum_ping = runtime.minimum_ping and math.min(runtime.minimum_ping, ping) or ping
    runtime.maximum_ping = runtime.maximum_ping and math.max(runtime.maximum_ping, ping) or ping
    runtime.jitter = #samples > 1 and math.floor(total_difference / (#samples - 1) + 0.5) or 0
    runtime.revision = (runtime.revision or 0) + 1
end

local function endpoint_address()
    local ip = runtime.endpoint_ip
    if not ip then
        return nil
    end

    local port = runtime.endpoint_port
    if not port then
        return ip
    end

    if string.find(ip, ":", 1, true) then
        return string.format("[%s]:%s", ip, tostring(port))
    end

    return string.format("%s:%s", ip, tostring(port))
end

function mod.server_stats()
    return runtime
end

function mod.server_endpoint()
    return endpoint_address()
end

function mod.hud_settings()
    return hud_settings
end

local function capture_endpoint(self, context)
    local ip = self._server_ip
    if type(ip) ~= "string" or ip == "" then
        return
    end

    runtime.endpoint_ip = ip
    runtime.endpoint_port = self._server_port
    runtime.endpoint_accelerated = self._accelerated == true
    runtime.endpoint_context = context
    runtime.endpoint_session_id = self._connection_client and self._connection_client:session_id() or nil
    runtime.revision = (runtime.revision or 0) + 1
end

mod:hook_safe("PartyImmateriumMissionSessionBoot", "_create_connection", function(self)
    capture_endpoint(self, "mission")
end)

mod:hook_safe("PartyImmateriumHubSessionBoot", "_create_connection", function(self)
    capture_endpoint(self, "hub")
end)

function mod.update(dt)
    if not mod:is_enabled() then
        return
    end

    local context = remote_server_context()
    if not context then
        if runtime.connected then
            leave_server()
        end

        return
    end

    local connection = Managers.connection
    begin_session(connection, context)

    runtime.sample_timer = (runtime.sample_timer or 0) + dt
    if runtime.sample_timer < SAMPLE_INTERVAL then
        return
    end

    runtime.sample_timer = runtime.sample_timer - SAMPLE_INTERVAL

    local host_peer_id = connection:host()
    if not host_peer_id then
        return
    end

    local ping_seconds = Network.ping(host_peer_id)
    local send_buffer = Network.reliable_send_buffer_left(host_peer_id)
    if type(send_buffer) == "number" and send_buffer >= 0 then
        runtime.send_buffer = send_buffer
    end

    if type(ping_seconds) == "number" and ping_seconds >= 0 then
        add_sample(ping_seconds * 1000)
    end
end

function mod.on_all_mods_loaded()
    if not mod:register_hud_element({
        class_name = "HudElementDarktideNetworkMonitor",
        filename = HUD_ELEMENT_PATH,
        use_hud_scale = true,
        visibility_groups = {
            "communication_wheel",
            "emote_wheel",
            "tactical_overlay",
            "player_in_danger_zone",
            "alive",
            "dead",
        },
    }) then
        mod:error("Failed to register the Darktide Network Monitor HUD element.")
    end
end

function mod.on_setting_changed()
    refresh_settings()
    runtime.revision = (runtime.revision or 0) + 1
end

function mod.on_disabled()
    leave_server()
end

function mod.on_unload()
    leave_server()
end
