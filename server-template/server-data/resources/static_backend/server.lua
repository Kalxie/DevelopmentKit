local C = BackendConfig
local selfName = GetCurrentResourceName()

local graph, reverse = {}, {} -- name -> { dependency = true } / name -> { dependent = true }
local desired = {}            -- resources that should be running
local caught = {}             -- name -> root that took it down; restarted once the root is back
local stopQueue = {}          -- name -> time; stops waiting to be classified
local lastStop = {}           -- name -> time of its most recent stop
local attempts = {}           -- name -> { start times }
local ignored = C.ignored
local paused, shuttingDown, busy, scheduled = not C.enabled, false, false, false
local lastWait                -- last [WAIT] message, so it's only printed when it changes
local profiling, profilerState = false, nil -- resmon: recording now / 'ready' or 'denied'

StaticBackend = {
    -- ------------------------------------------------------------------ helpers

    log = function(message)
        print(('^5[static_backend]^7 %s'):format(message))
    end,

    allowed = function(name)
        return name ~= selfName and not ignored[name]
    end,

    active = function()
        return not paused and not shuttingDown
    end,

    keys = function(set)
        local list = {}
        for key in pairs(set) do list[#list + 1] = key end
        table.sort(list)
        return list
    end,

    count = function(set)
        local n = 0
        for _ in pairs(set) do n = n + 1 end
        return n
    end,

    -- -------------------------------------------------------------------- graph

    --- Rebuilds the dependency graph from every resource manifest.
    refresh = function()
        local resources, providers = {}, {}
        for i = 0, GetNumResources() - 1 do
            local name = GetResourceByFindIndex(i)
            if name then resources[#resources + 1] = name end
        end
        for _, name in ipairs(resources) do
            for i = 0, GetNumResourceMetadata(name, 'provide') - 1 do
                local alias = GetResourceMetadata(name, 'provide', i)
                providers[alias] = providers[alias] or {}
                table.insert(providers[alias], name)
            end
        end

        graph, reverse = {}, {}
        for _, name in ipairs(resources) do
            local deps = {}
            local function add(value)
                if not value or value == '' or value:sub(1, 1) == '/' then return end
                local target, choices = C.providers[value], providers[value]
                if not target and choices then
                    for _, candidate in ipairs(choices) do
                        if GetResourceState(candidate) == 'started' then target = candidate break end
                    end
                    target = target or choices[1]
                end
                target = target or value
                if target ~= name then deps[target] = true end
            end
            -- `dependency 'x'` is stored as "dependency"; a `dependencies { ... }` block as
            -- "dependencie" (FXServer just drops the trailing s). FXServer reads both.
            for _, key in ipairs({ 'dependency', 'dependencie' }) do
                for i = 0, GetNumResourceMetadata(name, key) - 1 do
                    add(GetResourceMetadata(name, key, i))
                end
            end
            if C.readScriptImports then
                for _, kind in ipairs({ 'shared_script', 'server_script', 'client_script' }) do
                    for i = 0, GetNumResourceMetadata(name, kind) - 1 do
                        local path = GetResourceMetadata(name, kind, i)
                        add(path and path:match('^@([^/]+)/'))
                    end
                end
            end
            graph[name] = deps
            for dep in pairs(deps) do
                reverse[dep] = reverse[dep] or {}
                reverse[dep][name] = true
            end
        end
    end,

    --- Every resource that (transitively) depends on `name`.
    dependentsOf = function(name)
        local found, stack = {}, { name }
        while #stack > 0 do
            for dependent in pairs(reverse[table.remove(stack)] or {}) do
                if not found[dependent] then
                    found[dependent] = true
                    stack[#stack + 1] = dependent
                end
            end
        end
        return found
    end,

    --- The first (transitive) dependency of `name` that stopped close to `at`, if any.
    stoppedAncestor = function(name, at)
        local seen, stack = { [name] = true }, { name }
        while #stack > 0 do
            for dep in pairs(graph[table.remove(stack)] or {}) do
                if not seen[dep] then
                    seen[dep] = true
                    local stoppedAt = lastStop[dep]
                    if caught[dep] or (stoppedAt and math.abs(at - stoppedAt) <= C.cascadeWindowMs) then return dep end
                    stack[#stack + 1] = dep
                end
            end
        end
    end,

    --- Orders `set` so each resource comes after its dependencies. Cycles break alphabetically.
    order = function(set)
        local result, marked = {}, {}
        local function visit(name)
            if marked[name] then return end
            marked[name] = true
            for _, dep in ipairs(StaticBackend.keys(graph[name] or {})) do
                if set[dep] then visit(dep) end
            end
            result[#result + 1] = name
        end
        for _, name in ipairs(StaticBackend.keys(set)) do visit(name) end
        return result
    end,

    -- ------------------------------------------------------------------ catcher

    --- Sorts queued stops into caught (went down with a dependency) or intentional (left stopped).
    classify = function()
        -- Dependencies first, so a dependent inherits the original root (inventory, not shops).
        for _, name in ipairs(StaticBackend.order(stopQueue)) do
            local at = stopQueue[name]
            stopQueue[name] = nil
            local state = GetResourceState(name)
            if state ~= 'started' and state ~= 'starting' then
                local root = StaticBackend.stoppedAncestor(name, at)
                if root then
                    caught[name] = caught[root] or root
                    StaticBackend.log(('[CATCH] %s stopped with %s'):format(name, caught[name]))
                else
                    desired[name], caught[name] = nil, nil
                end
            end
        end
    end,

    --- Catches every resource that should be running but is stopped. FXServer stops a
    --- restarted resource's dependents internally, and those stops don't always reach
    --- onResourceStop, so this check doesn't rely on stop events at all.
    sweep = function()
        local down = {}
        for name in pairs(desired) do
            if not caught[name] and not stopQueue[name] and StaticBackend.allowed(name) and GetResourceState(name) == 'stopped' then
                down[name] = true
            end
        end
        -- Dependencies first, so a dependent inherits the original root.
        for _, name in ipairs(StaticBackend.order(down)) do
            local root = StaticBackend.stoppedAncestor(name, GetGameTimer())
            caught[name] = root and (caught[root] or root) or 'a dependency'
            StaticBackend.log(('[CATCH] %s stopped with %s'):format(name, caught[name]))
        end
    end,

    waitFor = function(name, wanted)
        local deadline = GetGameTimer() + C.startTimeoutMs
        while GetGameTimer() < deadline do
            if not StaticBackend.active() then return false, 'paused' end
            local state = GetResourceState(name)
            if state == wanted then return true end
            if state == 'missing' then return false, 'resource is missing' end
            if wanted == 'started' and state == 'stopped' then return false, 'failed to start (check the console above)' end
            Wait(100)
        end
        return false, 'timed out'
    end,

    underLimit = function(name)
        local now, recent = GetGameTimer(), {}
        for _, at in ipairs(attempts[name] or {}) do
            if now - at < C.attemptWindowMs then recent[#recent + 1] = at end
        end
        attempts[name] = recent
        if #recent >= C.maxAttempts then return false end
        recent[#recent + 1] = now
        return true
    end,

    start = function(name)
        local state = GetResourceState(name)
        if state == 'started' then return true end
        if state == 'stopping' then
            local ok, why = StaticBackend.waitFor(name, 'stopped')
            if not ok then return false, why end
        end
        if GetResourceState(name) ~= 'starting' then
            if not StaticBackend.underLimit(name) then return false, 'restart limit reached' end
            if not StartResource(name) then return false, 'start rejected' end
        end
        local ok, why = StaticBackend.waitFor(name, 'started')
        if not ok then return false, why end
        Wait(C.readyDelayMs)
        return GetResourceState(name) == 'started', 'stopped right after starting'
    end,

    --- Restarts every caught resource whose dependencies are up, in dependency order.
    recover = function()
        if not next(caught) then return end
        local blocked, started, waiting = {}, {}, {}

        for _, name in ipairs(StaticBackend.order(caught)) do
            if not StaticBackend.active() then return end
            if GetResourceState(name) == 'started' then
                caught[name] = nil
            else
                local ready = true
                for dep in pairs(graph[name] or {}) do
                    if blocked[dep] or GetResourceState(dep) ~= 'started' then
                        ready = false
                        if not blocked[dep] and not caught[dep] then waiting[dep] = true end
                    end
                end
                if not ready then
                    blocked[name] = true
                else
                    local ok, why = StaticBackend.start(name)
                    if ok then
                        caught[name] = nil
                        started[#started + 1] = name
                    else
                        blocked[name] = true
                        StaticBackend.log(('^1[FAIL]^7 %s: %s'):format(name, why))
                        if why == 'restart limit reached' then
                            -- Stop wanting it too, or the sweep would retry it forever.
                            caught[name], desired[name] = nil, nil
                            StaticBackend.log(('Gave up on %s. Fix it, then run: static_backend recover %s'):format(name, name))
                        end
                    end
                end
            end
        end

        if #started > 0 then
            StaticBackend.log(('^2[DONE]^7 Restarted %d: %s'):format(#started, table.concat(started, ' -> ')))
        end
        -- Only announce a wait when it changes, so the periodic sweep doesn't spam the console.
        local message = next(waiting) and ('[WAIT] %d caught resource(s) waiting for: %s'):format(StaticBackend.count(caught), table.concat(StaticBackend.keys(waiting), ', '))
        if message and message ~= lastWait then StaticBackend.log(message) end
        lastWait = message
    end,

    process = function()
        if busy or not StaticBackend.active() then return end
        busy = true
        local ok, err = pcall(function()
            StaticBackend.refresh()
            StaticBackend.classify()
            StaticBackend.sweep()
            StaticBackend.recover()
        end)
        busy = false
        if not ok then StaticBackend.log('^1Error:^7 ' .. tostring(err)) end
        -- Events that arrived while busy (including our own starts) are handled on the next pass.
        if next(stopQueue) then StaticBackend.schedule() end
    end,

    schedule = function(delay)
        if scheduled or not StaticBackend.active() then return end
        scheduled = true
        SetTimeout(delay or C.settleMs, function()
            scheduled = false
            if busy then return StaticBackend.schedule() end
            StaticBackend.process()
        end)
    end,

    --- Manual recovery: brings back `name` (if stopped) and every desired dependent that is down.
    forceRecover = function(name)
        StaticBackend.refresh()
        desired[name] = true
        if GetResourceState(name) ~= 'started' then caught[name] = name end
        for dependent in pairs(StaticBackend.dependentsOf(name)) do
            if StaticBackend.allowed(dependent) and GetResourceState(dependent) == 'stopped' then
                desired[dependent], caught[dependent] = true, name
            end
        end
        for resource in pairs(caught) do attempts[resource] = nil end
        StaticBackend.schedule(0)
    end,

    -- ------------------------------------------------------------ devkit bridge

    --- Records `frames` server ticks with FXServer's profiler and saves the trace to `path`
    --- for the DevKit's resmon. Needs these in server.cfg (FXServer checks each subcommand):
    ---   add_ace resource.static_backend command.profiler allow
    ---   add_ace resource.static_backend command.record allow
    ---   add_ace resource.static_backend command.saveJSON allow
    profile = function(frames, path)
        if profiling then return end
        frames = math.tointeger(frames)
        if not frames or frames < 10 or frames > 600 then return end
        if type(path) ~= 'string' or #path > 400 or not path:match('^[%w%s%._%-:/\\]+%.json$') then return end
        local principal = 'resource.' .. selfName
        if not (IsPrincipalAceAllowed(principal, 'command.profiler') and IsPrincipalAceAllowed(principal, 'command.record')
            and IsPrincipalAceAllowed(principal, 'command.saveJSON')) then
            profilerState = 'denied'
            return
        end
        profilerState, profiling = 'ready', true
        CreateThread(function()
            if not ProfilerIsRecording() then
                ExecuteCommand(('profiler record %d'):format(frames))
                local waited = 0
                repeat
                    Wait(200)
                    waited = waited + 200
                until not ProfilerIsRecording() or waited >= 30000
                ExecuteCommand(('profiler saveJSON "%s"'):format(path:gsub('\\', '/')))
            end
            profiling = false
        end)
    end,

    --- Live resource states for StaticDevKit (posted to its 127.0.0.1 port only).
    snapshot = function()
        local resources = {}
        for i = 0, GetNumResources() - 1 do
            local name = GetResourceByFindIndex(i)
            if name then
                resources[#resources + 1] = {
                    name = name,
                    state = GetResourceState(name),
                    dependencies = StaticBackend.keys(graph[name] or {}),
                    ignored = ignored[name] == true,
                    caught = caught[name] ~= nil,
                }
            end
        end
        return { resources = resources, paused = paused, recovering = busy, profiler = profilerState }
    end,
}

-- ---------------------------------------------------------------------- events

AddEventHandler('onResourceStop', function(name)
    if name == selfName then
        shuttingDown = true
        return
    end
    lastStop[name] = GetGameTimer()
    if not StaticBackend.allowed(name) then return end
    if not StaticBackend.active() then
        -- Stops made while paused are intentional.
        desired[name], caught[name] = nil, nil
        return
    end
    if desired[name] then
        stopQueue[name] = GetGameTimer()
        StaticBackend.schedule()
    end
end)

AddEventHandler('onResourceStart', function(name)
    if name == selfName then return end
    desired[name], caught[name], stopQueue[name] = true, nil, nil
    -- A restarted dependency may have caught dependents waiting for it.
    if StaticBackend.active() then StaticBackend.schedule() end
end)

-- -------------------------------------------------------------------- commands

RegisterCommand('static_backend', function(source, args)
    local action, name = args[1] or 'status', args[2]
    if action == 'pause' then
        paused, stopQueue, caught = true, {}, {}
        StaticBackend.log('Paused. Resources you stop now stay stopped. Use "static_backend resume" when done.')
    elseif action == 'resume' then
        paused = false
        StaticBackend.log('Resumed.')
    elseif action == 'rescan' then
        StaticBackend.refresh()
        StaticBackend.log(('Dependency graph refreshed (%d resources).'):format(StaticBackend.count(graph)))
    elseif action == 'ignore' and name then
        ignored[name], caught[name], stopQueue[name] = true, nil, nil
        StaticBackend.log('Ignoring ' .. name)
    elseif action == 'unignore' and name then
        ignored[name] = nil
        StaticBackend.log('Watching ' .. name)
    elseif action == 'recover' and name then
        if not StaticBackend.allowed(name) then return StaticBackend.log(name .. ' is ignored.') end
        if not StaticBackend.active() then return StaticBackend.log('Resume first: static_backend resume') end
        StaticBackend.log('Recovering ' .. name .. ' and its dependents...')
        StaticBackend.forceRecover(name)
    else
        StaticBackend.log(('State: %s | watching: %d | caught: %d%s'):format(
            shuttingDown and 'shutdown' or paused and 'paused' or busy and 'recovering' or 'active',
            StaticBackend.count(desired), StaticBackend.count(caught),
            next(caught) and (' (' .. table.concat(StaticBackend.keys(caught), ', ') .. ')') or ''))
        StaticBackend.log('Commands: status, pause, resume, rescan, ignore <resource>, unignore <resource>, recover <resource>')
    end
end, true)

-- StaticDevKit link. When the DevKit starts the server it writes devkit.json (port + token)
-- into this resource's folder; we poll it, so nothing is ever typed into the console.
local endpoint, token, linked, generation, failures, sending = nil, nil, nil, 0, 0, false

local function push()
    if not endpoint or sending then return end
    sending = true
    local current = generation
    PerformHttpRequest(endpoint, function(status, body)
        if current ~= generation then return end
        sending = false
        failures = (status == 200 or status == 204) and 0 or failures + 1
        -- The DevKit answers 200 with a request when its resmon wants a profile.
        if status == 200 and body then
            local ok, request = pcall(json.decode, body)
            if ok and type(request) == 'table' and type(request.profile) == 'table' then
                StaticBackend.profile(request.profile.frames, request.profile.path)
            end
        end
        if failures >= 3 then endpoint, token = nil, nil return end
        SetTimeout(5000, function() if current == generation then push() end end)
    end, 'POST', json.encode(StaticBackend.snapshot()),
        { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bearer ' .. token }, { followLocation = false })
end

CreateThread(function()
    while not shuttingDown do
        local raw = LoadResourceFile(selfName, 'devkit.json')
        if raw ~= linked then
            linked = raw
            local ok, link = pcall(json.decode, raw or '')
            local port, key = ok and type(link) == 'table' and tonumber(link.port), ok and type(link) == 'table' and link.token
            if port and port >= 1024 and port <= 65535 and port % 1 == 0 and type(key) == 'string' and key:match('^%x+$') and #key == 64 then
                endpoint, token = ('http://127.0.0.1:%d/snapshot'):format(port), key
                generation, failures, sending = generation + 1, 0, false
                push()
            end
        end
        Wait(3000)
    end
end)

-- ------------------------------------------------------------------------ boot

-- Everything already running when we start is desired.
StaticBackend.refresh()
for name in pairs(graph) do
    local state = GetResourceState(name)
    if StaticBackend.allowed(name) and (state == 'started' or state == 'starting') then desired[name] = true end
end
StaticBackend.log('[READY] Catching resources that stop with their dependencies.')

-- Safety net: re-check every few seconds in case a stop happened without an event.
CreateThread(function()
    while not shuttingDown do
        Wait(C.sweepMs)
        if StaticBackend.active() and not busy and not scheduled then StaticBackend.process() end
    end
end)
