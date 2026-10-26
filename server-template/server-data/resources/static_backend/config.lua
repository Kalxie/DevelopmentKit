BackendConfig = {
    enabled = true,

    -- Wait this long after a stop/start before acting, so restart/ensure commands finish first.
    settleMs = 1500,
    -- A resource that stops within this window of one of its dependencies went down *with* it
    -- (it gets caught and restarted); otherwise the stop is treated as intentional.
    cascadeWindowMs = 5000,

    -- Also re-check this often for resources that should be running but are stopped.
    sweepMs = 10000,

    startTimeoutMs = 15000, -- Max wait for a resource to reach "started".
    readyDelayMs = 300,     -- Gap after each start before the next one.
    maxAttempts = 3,        -- Starts per resource within attemptWindowMs before giving up.
    attemptWindowMs = 60000,

    -- Treat `@resource/file.lua` script imports as dependencies, not just `dependency`.
    readScriptImports = true,

    -- Resources the catcher never touches.
    ignored = { monitor = true },
    -- Pin a provider when several resources `provide` the same name: { ['mysql-async'] = 'oxmysql' }
    providers = {},
}
