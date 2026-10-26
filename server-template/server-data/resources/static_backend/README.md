# static_backend

Keeps your server's resources running when one of them restarts.

## The problem it solves

When FXServer stops a resource, it also stops every resource that declares it as a `dependency`. A plain `restart static_inventory` brings the inventory back but leaves everything that depended on it (shops, garage, crafting…) **stopped**. You'd have to `ensure` each one by hand, in the right order.

## What it does

static_backend watches every resource start and stop:

1. **Catch.** When a resource stops, it waits a moment (`settleMs`) and asks: *did one of its dependencies stop at about the same time?*
   - **Yes** → it went down *with* that dependency. It's **caught** and queued to come back.
   - **No** → you stopped it on purpose (`stop x`). It's left stopped.
2. **Restart in order.** As soon as the dependency is running again, every caught resource is started **dependencies first**, waiting for each one to fully start before the next.
3. **Sweep.** FXServer stops a restarted resource's dependents internally, and those stops don't always reach `onResourceStop`. So whenever any resource starts, and every `sweepMs` as a safety net, static_backend also checks every resource that *should* be running. Anything stopped that you didn't stop yourself gets caught too.
4. **Give up safely.** A resource that keeps failing to start is retried at most `maxAttempts` times per minute, then left alone with a console message. Nothing loops forever.

```
> restart static_inventory
[static_backend] [CATCH] static_shops stopped with static_inventory
[static_backend] [CATCH] static_crafting stopped with static_inventory
[static_backend] [CATCH] static_garage stopped with static_inventory
[static_backend] [DONE] Restarted 3: static_shops -> static_crafting -> static_garage
```

It also works across longer outages. `stop ox_lib` takes its dependents down with it; they wait (`[WAIT] … waiting for: ox_lib`) and all come back, in order, when you `start ox_lib`.

Dependencies are read from each resource's `fxmanifest.lua`: every `dependency` entry, plus `@resource/file.lua` script imports when `readScriptImports` is on. `provide` aliases are resolved to the running provider.

## Setup

Put it near the top of `server.cfg` so it sees every other resource start:

```cfg
ensure static_backend
```

## Console commands

| Command | What it does |
| --- | --- |
| `static_backend` / `static_backend status` | State, how many resources are watched, and what's currently caught |
| `static_backend pause` | Stop catching. Anything you stop while paused stays stopped (use for maintenance) |
| `static_backend resume` | Start catching again |
| `static_backend rescan` | Re-read every manifest's dependencies |
| `static_backend ignore <resource>` | Never touch this resource |
| `static_backend unignore <resource>` | Watch it again |
| `static_backend recover <resource>` | Start it (if stopped) and every stopped resource that depends on it, resetting retry limits |

## Configuration (`config.lua`)

| Option | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Start paused when `false` |
| `settleMs` | `1500` | Delay before acting, so restart/ensure commands finish first |
| `cascadeWindowMs` | `5000` | How close a dependent's stop must be to its dependency's stop to count as "went down with it" |
| `sweepMs` | `10000` | How often to re-check for resources that should be running but are stopped |
| `startTimeoutMs` | `15000` | Max wait for a resource to reach `started` |
| `readyDelayMs` | `300` | Pause after each start before the next |
| `maxAttempts` / `attemptWindowMs` | `3` / `60000` | Retry limit per resource |
| `readScriptImports` | `true` | Count `@resource/…` imports as dependencies |
| `ignored` | `{ monitor = true }` | Resources never touched |
| `providers` | `{}` | Pin which resource satisfies a `provide` alias |

## StaticDevKit link

When StaticDevKit starts the server it writes `devkit.json` (a local port and a per-session token) into this folder. static_backend checks that file every 3 seconds and, once it appears, posts resource states, dependencies and caught status every 5 seconds to `127.0.0.1:<port>` with that token. Nothing is typed into the server console. The file is deleted when the server stops. That link powers the DevKit's Resources page and its Caught badges; no port is opened on the server.

## Files

| File | Contents |
| --- | --- |
| `config.lua` | `BackendConfig` options above |
| `server.lua` | `StaticBackend` table (graph → catcher → devkit snapshot), then event handlers, commands and boot |

## Server resmon (StaticDevKit → Activity → Resmon)

When you press **Sample now** (or turn on **Live**) in the DevKit, the request rides back on the snapshot link. static_backend then runs FXServer's built-in profiler for ~100 server ticks and saves the trace to a temp file the DevKit reads. You get each resource's average and peak ms per tick plus the hottest script threads. FXServer prints three short `[cmd]` lines per sample (start, stop, save); that's FXServer itself, not static_backend.

FXServer checks each profiler subcommand separately, so `server.cfg` needs:

```cfg
add_ace resource.static_backend command.profiler allow
add_ace resource.static_backend command.record allow
add_ace resource.static_backend command.saveJSON allow
```
