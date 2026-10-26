<a id="top"></a>

<p align="center">
  <img src="assets/app_icon.png" alt="Development Kit" height="72" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/fivem_logo.svg" />
    <img src="assets/fivem_logo_dark.svg" alt="FiveM" height="56" />
  </picture>
</p>

<h1 align="center">Development Kit</h1>

<p align="center">
  <b>A desktop control centre for FiveM server development.</b><br />
  Run your FXServer, watch its console, profile resources, edit code and manage your database — all from one window.<br />
  <sub>Created by <a href="https://github.com/Kalxie"><b>Kalxie</b></a></sub>
</p>

<p align="center">
  <a href="https://github.com/Kalxie/DevelopmentKit/releases/latest"><img alt="Version" src="https://img.shields.io/github/v/release/Kalxie/DevelopmentKit?label=version&color=2563eb" /></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6?logo=windows" />
  <a href="https://www.virustotal.com/gui/file/d9e51f99b75cbfde9313165d725ce79af878d6ce154ed174cab69671fed541e5"><img alt="VirusTotal 0/66" src="https://img.shields.io/badge/VirusTotal-0%2F66%20clean-success?logo=virustotal&logoColor=white" /></a>
  <a href="server-template/"><img alt="Server template" src="https://img.shields.io/badge/server%20template-included-8b5cf6" /></a>
</p>

<p align="center">
  <a href="https://github.com/Kalxie/DevelopmentKit/releases/latest/download/Development-Kit-Setup.exe">
    <img alt="Download for Windows" src="https://img.shields.io/badge/Download%20for%20Windows-Development--Kit--Setup.exe-2563eb?style=for-the-badge&logo=windows&logoColor=white" />
  </a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#screenshots">Screenshots</a> ·
  <a href="#getting-started">Getting started</a> ·
  <a href="#server-template">Server template</a> ·
  <a href="#folder-reference">Folder reference</a> ·
  <a href="#safety">Is it safe?</a> ·
  <a href="#about">About</a> ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

<p align="center">
  <img src="docs/screenshots/overview.png" alt="Development Kit overview" width="900" />
</p>

---

**Development Kit** is a Windows desktop app created by **[Kalxie](https://github.com/Kalxie)** that brings the everyday tools of FiveM development together. Instead of juggling a terminal running FXServer, a HeidiSQL window, VS Code and the FiveM client, you point the kit at your `server-data` folder and drive everything from one place.

> Kalxie originally built it as the in-house dev tool for the **Static RP** server, then polished it into a standalone app for any FiveM developer.

<table>
  <tr>
    <td width="33%" valign="top">
      <h3>⬇️ Install the app</h3>
      Download the Windows installer and sign in.<br /><br />
      <a href="https://github.com/Kalxie/DevelopmentKit/releases/latest"><b>Latest release →</b></a>
    </td>
    <td width="33%" valign="top">
      <h3>📁 Set up a server</h3>
      Copy the ready-made template with the folder layout, start scripts and <code>static_backend</code>.<br /><br />
      <a href="server-template/"><b>Server template →</b></a>
    </td>
    <td width="33%" valign="top">
      <h3>🛡️ Verify it</h3>
      Scanned clean by 66 antivirus engines, with a checksum for every release.<br /><br />
      <a href="#safety"><b>Safety details →</b></a>
    </td>
  </tr>
</table>

<a id="features"></a>

## ✨ Features

| | |
|---|---|
| 🖥️ **Server control** | Start, stop and restart FXServer from a real embedded terminal |
| 📜 **Live console** | Filter output by errors and warnings, save commands you use often |
| 📦 **Resources** | Browse every resource in your workspace and jump straight into the code |
| 🔁 **Caught resources** | See resources `static_backend` is bringing back after a dependency restarts |
| 📈 **Resmon** | Per-resource and per-thread timings from FXServer's profiler |
| 🗄️ **HeidiSQL, docked** | Your database tool runs inside its own tab |
| ✏️ **VS Code** | Open a resource, or a file at a specific line, in one click |
| 🎮 **Launch FiveM** | Connect your local client to the dev server instantly |
| 🔍 **Auto-discovery** | Finds FiveM, HeidiSQL and VS Code on your machine |
| ⌨️ **Shortcuts** | `Alt+S` server · `Alt+V` VS Code · `Alt+F` FiveM · `Alt+H` HeidiSQL |

<p align="right"><a href="#top">Back to top ↑</a></p>

<a id="screenshots"></a>

## 📸 Screenshots

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/login.png" alt="Login screen" /><br /><sub><b>Secure sign-in</b></sub></td>
    <td align="center"><img src="docs/screenshots/overview.png" alt="Overview" /><br /><sub><b>Overview</b></sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/console.png" alt="Console" /><br /><sub><b>Server console</b></sub></td>
    <td align="center"><img src="docs/screenshots/resources.png" alt="Resources" /><br /><sub><b>Resource browser</b></sub></td>
  </tr>
</table>

<p align="right"><a href="#top">Back to top ↑</a></p>

<a id="getting-started"></a>

## 🚀 Getting started

**1. Install Development Kit**

[Download `Development-Kit-Setup.exe`](https://github.com/Kalxie/DevelopmentKit/releases/latest/download/Development-Kit-Setup.exe) and run it. Windows SmartScreen may warn that the app is unrecognised because it isn't code-signed yet: choose **More info → Run anyway**.

**2. Get a server folder**

- **New server?** Copy the [server template](server-template/), download the FXServer artifacts into its `server/` folder, and add your license key. The [template guide](server-template/README.md) walks through every step.
- **Existing server?** Make sure it matches the [folder reference](#folder-reference) below.

**3. Point the app at it**

Sign in, choose your **`server-data`** folder (the one with `server.cfg`), and press **Start server** (`Alt+S`).

> [!TIP]
> To update, download the latest installer and run it over your existing install.

<p align="right"><a href="#top">Back to top ↑</a></p>

<a id="server-template"></a>

## 📁 Server template

The [`server-template/`](server-template/) folder is a complete FXServer layout that works with Development Kit out of the box.

| Included | What it does |
|---|---|
| [`server-data/server.cfg`](server-template/server-data/server.cfg) | Settings first, then resources in dependency order |
| [`secrets.example.cfg`](server-template/server-data/secrets.example.cfg) | Template for your license key and database connection |
| [`builder.bat`](server-template/server-data/builder.bat) · [`start.bat`](server-template/server-data/start.bat) | Build stale UIs, then start FXServer |
| [`build-react-uis.ps1`](server-template/server-data/resources/build-react-uis.ps1) | Builds every React UI in your resources (the **Build all UIs** button) |
| [`static_backend`](server-template/server-data/resources/static_backend/) | Restarts resources that went down with a dependency, and links the server to the app |
| [Example resources](server-template/server-data/resources/) | A core resource, a dependent script, a streamed map and a React UI |
| [`server/README.md`](server-template/server/README.md) | Where to download and extract the FXServer artifacts |

**Download the FXServer artifacts:** [Windows (recommended / latest)](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/) · [Linux](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/) · [current build numbers](https://changelogs-live.fivem.net/api/changelog/versions/win32/server) · [license key](https://keymaster.fivem.net)

<p align="center"><a href="server-template/README.md"><b>Open the full template guide →</b></a></p>

<p align="right"><a href="#top">Back to top ↑</a></p>

<a id="folder-reference"></a>

## 🗂️ Server folder reference

Development Kit works with the standard FXServer layout. Choose the **`server-data`** folder as your workspace.

```
FXServer/
├── server/                     FXServer artifacts (FXServer.exe, run.cmd, citizen/…)
└── server-data/                ← choose this folder in Development Kit
    ├── server.cfg              required
    ├── builder.bat             optional: custom start script
    └── resources/              required
        ├── build-react-uis.ps1 optional: "Build all UIs" button
        ├── static_backend/     recommended: auto-restarts + app link
        ├── [category]/         [bracketed] folders group resources
        │   └── my_resource/
        │       ├── fxmanifest.lua
        │       └── stream/     streamed assets, shown in the Assets tab
        └── my_script/
            └── fxmanifest.lua
```

<details>
<summary><b>What Development Kit looks for</b></summary>
<br />

| Path | Required | Used for |
|---|---|---|
| `server-data/server.cfg` | ✅ | Identifies the folder as a server; FXServer starts with `+exec server.cfg` |
| `server-data/resources/` | ✅ | Every resource shown in the Resources tab |
| `server-data/builder.bat` | One of these two | A custom start script, run in place of FXServer.exe |
| `../server/FXServer.exe` | One of these two | Starts the server when there's no `builder.bat` |
| `resources/<name>/fxmanifest.lua` | ✅ per resource | Marks a folder as a resource and lists its dependencies (`__resource.lua` also works) |
| `resources/<name>/stream/` | Optional | Streamed assets listed in the Assets tab |
| `resources/build-*-uis.ps1` | Optional | PowerShell script run by the **Build all UIs** button |
| `resources/static_backend/` | Optional | Resources page states, Caught badges and Resmon |

</details>

<details>
<summary><b>Tips for resources and <code>server.cfg</code></b></summary>
<br />

- Group resources in `[category]` folders. They don't change resource names, so `ensure my_framework` still works.
- Keep `server/` and `server-data/` side by side so Development Kit finds `FXServer.exe` on its own.
- Every resource needs a manifest:

  ```lua
  fx_version 'cerulean'
  game 'gta5'

  client_script 'client.lua'
  server_script 'server.lua'
  ```

- Start resources with `ensure`, dependencies first, and `static_backend` before everything else:

  ```cfg
  ensure static_backend
  ensure my_framework
  ensure [maps]        # every resource in the category
  ```

</details>

<p align="right"><a href="#top">Back to top ↑</a></p>

<a id="safety"></a>

## 🛡️ Is it safe?

Yes. Development Kit is a local developer tool: it launches programs you already have (FXServer, FiveM, HeidiSQL, VS Code) and reads your `server-data` folder. It doesn't collect telemetry, and your sign-in details are stored only on your PC.

Because the installer isn't code-signed yet, Windows and some antivirus tools may call it "unrecognised". You can check it yourself:

- **VirusTotal:** [view the report](https://www.virustotal.com/gui/file/d9e51f99b75cbfde9313165d725ce79af878d6ce154ed174cab69671fed541e5), scanned clean by all 66 antivirus engines (0/66).
- **Checksum:** confirm your download matches the official build. In PowerShell:

  ```powershell
  Get-FileHash .\Development-Kit-Setup.exe -Algorithm SHA256
  ```

  The hash for each version is listed in its [release notes](https://github.com/Kalxie/DevelopmentKit/releases).

<p align="right"><a href="#top">Back to top ↑</a></p>

## 📋 Requirements

| | |
|---|---|
| **OS** | Windows 10 or 11 (64-bit) |
| **Server** | An FXServer `server-data` folder (or the [template](server-template/)) |
| **Optional** | [FiveM](https://fivem.net/) · [HeidiSQL](https://www.heidisql.com/) · [VS Code](https://code.visualstudio.com/) · [Node.js 18+](https://nodejs.org/) for React UIs |

## 🔗 Links

[Releases](https://github.com/Kalxie/DevelopmentKit/releases) · [Changelog](CHANGELOG.md) · [Server template](server-template/) · [FXServer artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/) · [FiveM docs](https://docs.fivem.net/docs/)

---

<a id="about"></a>

## 👤 About the creator

<table>
  <tr>
    <td width="96" valign="top"><a href="https://github.com/Kalxie"><img src="https://github.com/Kalxie.png" width="80" alt="Kalxie" /></a></td>
    <td valign="top">
      <b><a href="https://github.com/Kalxie">Kalxie</a></b>: FiveM developer and creator of Development Kit.<br />
      Development Kit started life as the internal tooling behind <b>Static RP</b>, built to stop juggling terminals, database tools and editors while developing the server. It grew into a full desktop app, now shared with the wider FiveM community.<br /><br />
      <a href="https://github.com/Kalxie">GitHub</a> · <a href="https://twitch.tv/kalxie">Twitch</a> · Discord: <b>kalxiee.</b>
    </td>
  </tr>
</table>

---

<p align="center"><sub>Made by <a href="https://github.com/Kalxie">Kalxie</a> · Originally built for Static RP · © Kalxie. All rights reserved.</sub></p>
