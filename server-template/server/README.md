# server/

Extract the **FXServer artifacts** into this folder. When you're done it should contain `FXServer.exe`, `run.cmd`, the `citizen/` folder and a lot of `.dll` files.

## Download

| Build | Link | Use it when |
|---|---|---|
| **Recommended** | [Windows artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/) → the build marked **RECOMMENDED** | Almost always. Tested and stable. |
| **Latest** | [Windows artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/) → the build marked **LATEST** | You need a brand-new feature or game build. |
| Linux | [Linux artifacts](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/) | Hosting on Linux (Development Kit itself is Windows-only). |

Each build is a `server.zip` (Windows) or `fx.tar.xz` (Linux). Check the current recommended and latest build numbers on the [artifact changelog](https://changelogs-live.fivem.net/api/changelog/versions/win32/server).

## Install

1. Download `server.zip` for the recommended build.
2. Right-click it → **Extract All…** and extract into this `server/` folder.
3. Check that `server/FXServer.exe` and `server/run.cmd` exist (not `server/server/FXServer.exe`).

## Updating

Delete everything in this folder except this README, then extract the new `server.zip`. Your `server-data/` folder isn't affected.

> [!NOTE]
> Artifacts aren't committed to git: they're over 100 MB and you should always download them from the official site.
