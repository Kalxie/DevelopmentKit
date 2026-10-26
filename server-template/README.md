# FiveM server template

A ready-to-use FXServer folder layout that works out of the box with **Development Kit**. Copy this folder, add the FXServer artifacts and your license key, and you have a running development server.

It includes:

- **`static_backend`**: keeps resources running when one of their dependencies restarts, and powers Development Kit's Resources page and resmon.
- **`builder.bat` / `start.bat`**: build any stale NUI interfaces, then start FXServer.
- **`build-react-uis.ps1`**: finds every web UI in your resources and builds it.
- **Example resources** showing the correct structure for a core resource, a script with a dependency, a streamed map and a NUI interface.

---

## Folder layout

```
server-template/
├── server/                              FXServer artifacts (you download these)
│   ├── FXServer.exe
│   ├── run.cmd
│   └── citizen/ …
│
└── server-data/                         ← choose THIS folder in Development Kit
    ├── server.cfg                       server settings and the list of resources to start
    ├── secrets.example.cfg              copy to secrets.cfg and fill in your keys
    ├── secrets.cfg                      (you create this, never commit it)
    ├── builder.bat                      what Development Kit runs to start the server
    ├── start.bat                        builds stale UIs, then runs ..\server\run.cmd
    ├── .gitignore
    │
    └── resources/
        ├── build-react-uis.ps1          builds every resource's web UI
        ├── static_backend/              dependency-aware restarts + Development Kit link
        │
        ├── [core]/                      categories: [bracketed] folders group resources
        │   └── example_core/            shared code and exports other resources use
        ├── [maps]/
        │   └── example_map/
        │       └── stream/              .ydr .ytd .ymap … sent to players automatically
        └── [scripts]/
            ├── example_script/          depends on example_core
            └── example_ui/              React NUI interface built from web/ into web/dist/
```

## Quick start

### 1. Requirements

| What | Why | Get it |
|---|---|---|
| Windows 10/11 | FXServer + Development Kit | |
| FiveM license key | FXServer won't start without one | [keymaster.fivem.net](https://keymaster.fivem.net) (free) |
| Node.js 18+ | Only if you build web UIs | [nodejs.org](https://nodejs.org/) |
| MariaDB | Only if your resources use a database | [mariadb.org](https://mariadb.org/download/) · [install guide](https://www.mariadbtutorial.com/getting-started/install-mariadb/) |
| GTA V + FiveM client | To join your server | [fivem.net](https://fivem.net/) |

### 2. Download the FXServer artifacts

The artifacts are the server program itself. Download them from the official FiveM site:

| Build | Download | When to use it |
|---|---|---|
| ⭐ **Recommended** | [runtime.fivem.net → Windows](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/), pick the **RECOMMENDED** build | Default choice. Tested and stable. |
| 🧪 **Latest** | [runtime.fivem.net → Windows](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/), pick the **LATEST** build | Newest features and game builds; may have bugs. |
| 🐧 Linux | [runtime.fivem.net → Linux](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/) | Linux hosting only. |

The current recommended and latest build numbers, with direct `server.zip` links, are always listed in the [official artifact feed](https://changelogs-live.fivem.net/api/changelog/versions/win32/server).

Extract `server.zip` into `server/` so that `server/FXServer.exe` exists. See [`server/README.md`](server/README.md) for details.

### 3. Add your license key

1. Get a free key at [keymaster.fivem.net](https://keymaster.fivem.net) → **New server**.
2. In `server-data/`, copy `secrets.example.cfg` and rename the copy to `secrets.cfg`.
3. Open `secrets.cfg` and replace `cfxk_your_key_here` with your key. Set the database connection string here too if you use one.

> [!WARNING]
> `secrets.cfg` contains your license key. It's already in `.gitignore`. Never upload or share it.

### 4. Set up the database (optional)

Skip this if your resources don't use a database. Most frameworks (and `oxmysql`) need one.

**Install MariaDB.** Follow the step-by-step guide: [**How to install MariaDB on Windows**](https://www.mariadbtutorial.com/getting-started/install-mariadb/). Download the installer from [mariadb.org](https://mariadb.org/download/). While installing:

| Installer step | What to choose |
|---|---|
| Root password | Set one and remember it: it goes in `secrets.cfg` |
| Enable access from remote machines | Leave **unticked** for a local dev server |
| Use UTF8 as default character set | **Tick** it |
| Install as service | **Tick** it, so the database starts with Windows |
| Port | Keep **3306** unless something else uses it |

The Windows installer also includes **HeidiSQL**, which Development Kit finds automatically and docks in its HeidiSQL tab.

**Create your database.** Open HeidiSQL, connect to `127.0.0.1` as `root`, then right-click the connection → **Create new → Database**, and give it a name (for example `fivem_server`). To import an existing `.sql` file, select the database and use **File → Run SQL file…**.

**Connect the server.** In `secrets.cfg`, set the connection string to match:

```cfg
# no root password
set mysql_connection_string "mysql://root@localhost/fivem_server?charset=utf8mb4"

# with a root password
set mysql_connection_string "mysql://root:YourPassword@localhost/fivem_server?charset=utf8mb4"
```

### 5. Start it

**With Development Kit (recommended):** open Development Kit, choose the `server-data` folder, and press **Start server** (`Alt+S`).

**Without it:** double-click `server-data/builder.bat`.

Then open FiveM, press `F8` and type `connect localhost`.

## How the pieces fit together

### Start-up chain

```
Development Kit  ──►  builder.bat  ──►  start.bat  ──►  build-react-uis.ps1 -OnlyStale
                                                    └─►  ..\server\run.cmd +exec server.cfg
```

- Development Kit looks for `server-data/builder.bat` first. If there isn't one, it runs `../server/FXServer.exe +exec server.cfg` directly.
- `start.bat` rebuilds only the UIs whose source changed, then starts FXServer. If a UI fails to build, the server still starts.
- To keep the artifacts somewhere else, set the `FXSERVER_DIR` environment variable to that folder.

### `server.cfg`

Read top to bottom: settings first, then resources in dependency order.

| Section | What goes there |
|---|---|
| network | Port (default `30120`) |
| secrets | `exec secrets.cfg`: license key, database, API keys |
| server | Game build, OneSync, player slots, server name |
| permissions | Admin groups and the `static_backend` profiler permissions |
| resources | `ensure` lines, dependencies first |

`ensure [category]` starts every resource in that folder. Put `static_backend` first so it sees every other resource start.

### Resources

A resource is any folder inside `resources/` that has an `fxmanifest.lua`. The folder name is the resource name.

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

dependency 'example_core'      -- start after (and restart with) example_core

shared_script 'shared.lua'     -- runs on both sides
server_script 'server.lua'
client_script 'client.lua'
```

| Rule | Why |
|---|---|
| Resource names: lowercase, letters, numbers, `_` and `-` | Used in `ensure`, exports and events |
| `[bracketed]` folders are categories, not resources | Only for organising; they don't change resource names |
| Declare every `dependency` | FXServer starts dependencies first, and `static_backend` restarts dependents for you |
| Streamed files go in `stream/` | Sent to players automatically, no manifest entry needed |

### `static_backend`

When FXServer restarts a resource, it also stops everything that depends on it, and leaves those stopped. `static_backend` catches them and starts them again in the right order:

```
> restart example_core
[static_backend] [CATCH] example_script stopped with example_core
[static_backend] [DONE] Restarted 1: example_script
```

It also links the server to Development Kit (through a local `devkit.json` file and `127.0.0.1` only, no open ports), which powers the **Resources** page, **Caught** badges and **Resmon**. Full details in [`static_backend/README.md`](server-data/resources/static_backend/README.md).

### Web UIs (`build-react-uis.ps1`)

Any `package.json` inside a resource that uses **React** (`react` or `react-dom`) and has a `build` script is treated as a web UI. Other projects are ignored. The script:

1. finds every UI under `resources/`,
2. installs its packages (npm, pnpm or yarn, whichever the project uses),
3. runs `build`, and
4. with `-OnlyStale`, skips UIs that haven't changed since their last successful build.

Run it by hand from `server-data/resources`:

```powershell
.\build-react-uis.ps1                 # build every UI
.\build-react-uis.ps1 example_ui      # build one resource
.\build-react-uis.ps1 -ListOnly       # list UIs without building
.\build-react-uis.ps1 -OnlyStale      # only what changed
```

In Development Kit, the **Build all UIs** button runs the same script.

## Common problems

| Problem | Fix |
|---|---|
| `No builder.bat or sibling server/FXServer.exe was found` | Extract the artifacts into `server/`, next to `server-data/` |
| `Choose a server-data folder containing server.cfg` | Pick the `server-data` folder itself, not `server-template` |
| Server closes straight away mentioning a license key | Create `secrets.cfg` from the example and add your key |
| `Couldn't find resource example_x` | Check the folder name matches the `ensure` line and it has an `fxmanifest.lua` |
| A resource stays stopped after restarting its dependency | Make sure `ensure static_backend` is the first resource in `server.cfg` |
| Resmon says permission denied | Keep the three `add_ace resource.static_backend …` lines in `server.cfg` |
| UI build fails | Install Node.js 18+ and run `.\build-react-uis.ps1 <resource>` to see the error |

## Useful links

- [FXServer artifacts (Windows)](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/)
- [Current recommended & latest builds](https://changelogs-live.fivem.net/api/changelog/versions/win32/server)
- [License keys (Keymaster)](https://keymaster.fivem.net)
- [Official server setup guide](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/)
- [Resource manifest reference](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/)
- [Server commands reference](https://docs.fivem.net/docs/server-manual/server-commands/)
