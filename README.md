<p align="center">
  <img src="assets/app_icon.png" alt="StaticDevKit" width="96" />
</p>

<h1 align="center">StaticDevKit</h1>

<p align="center">
  <b>A desktop control centre for FiveM server development.</b><br />
  Run your FXServer, watch its console, profile resources, edit code and manage your database — all from one window.
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-0.3.0-blue" />
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6?logo=windows" />
  <img alt="Installer" src="https://img.shields.io/badge/installer-NSIS-success" />
</p>

<p align="center">
  <a href="https://github.com/Kalxie/StaticDevKit/releases/latest/download/StaticDevKit-Setup.exe">
    <img alt="Download for Windows" src="https://img.shields.io/badge/Download%20for%20Windows-StaticDevKit--Setup.exe-2563eb?style=for-the-badge&logo=windows&logoColor=white" />
  </a>
</p>

<p align="center">
  <img src="docs/screenshots/overview.png" alt="StaticDevKit overview" width="900" />
</p>

---

## What is it?

**StaticDevKit** is a Windows desktop app by **Static Development** that brings the everyday tools of FiveM development together. Instead of juggling a terminal running FXServer, a HeidiSQL window, VS Code and the FiveM client, you point the kit at your `server-data` folder and drive everything from one place.

## Features

- 🖥️ **Server control** — start, stop and restart FXServer from a real embedded terminal
- 📜 **Live console** — filter output by errors and warnings, save commands you use often
- 📦 **Resources** — browse every resource in your workspace and jump straight into the code
- 📈 **Resmon** — per-resource and per-thread timings from FXServer's profiler
- 🗄️ **HeidiSQL, docked** — your database tool runs inside its own tab
- ✏️ **VS Code** — open a resource or a file at a specific line in one click
- 🎮 **Launch FiveM** — connect your local client to the dev server instantly
- 🔍 **Auto-discovery** — finds FiveM, HeidiSQL and VS Code on your machine
- ⌨️ **Keyboard shortcuts** — `Alt+S` server, `Alt+V` VS Code, `Alt+F` FiveM, `Alt+H` HeidiSQL

## Screenshots

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

## Installation

1. **[Download `StaticDevKit-Setup.exe`](https://github.com/Kalxie/StaticDevKit/releases/latest/download/StaticDevKit-Setup.exe)**
2. Run the installer. Windows SmartScreen may warn that the app is unrecognised because it isn't code-signed yet — choose **More info → Run anyway**.
3. Sign in, pick your `server-data` folder, and you're set.

To update, download the latest installer and run it over your existing install.

## Is it safe?

Yes. StaticDevKit is a local developer tool: it launches programs you already have (FXServer, FiveM, HeidiSQL, VS Code) and reads your `server-data` folder. It doesn't collect telemetry, and your sign-in details are stored only on your PC.

Because the installer isn't code-signed yet, Windows and some antivirus tools may flag it as "unrecognised". You can check it yourself:

- **VirusTotal scan:** [view the report](https://www.virustotal.com/gui/file/d9e51f99b75cbfde9313165d725ce79af878d6ce154ed174cab69671fed541e5), which checks the file against 70+ antivirus engines.
- **Checksum:** confirm your download matches the official build. In PowerShell:

  ```powershell
  Get-FileHash .\StaticDevKit-Setup.exe -Algorithm SHA256
  ```

  The hash for each version is listed in its [release notes](https://github.com/Kalxie/StaticDevKit/releases).

## Requirements

- Windows 10 or 11 (64-bit)
- An FXServer `server-data` folder
- Optional: [FiveM](https://fivem.net/), [HeidiSQL](https://www.heidisql.com/), [VS Code](https://code.visualstudio.com/)

## License

© Static Development. All rights reserved.
