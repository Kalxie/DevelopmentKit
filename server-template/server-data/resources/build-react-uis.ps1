[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]] $Resource,

    [switch] $ListOnly,
    [switch] $SkipInstall,
    [switch] $StopOnError,

    # Only build UIs whose output is missing or whose sources changed since the last successful build.
    [switch] $OnlyStale,

    # After building anything, ask whether to delete node_modules (defaults to No after a timeout).
    [switch] $AskCleanup,
    [int] $CleanupTimeout = 15
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$ignoredDirectories = @(
    'node_modules', '.pnpm-store', '.yarn', '.cache',
    '.git', '.idea', '.vscode',
    'dist', 'build', 'nui', 'html', 'coverage'
)

function Write-Step {
    param(
        [string] $Message,
        [ConsoleColor] $Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
}

function Find-PackageFiles {
    param(
        [string] $Directory,
        [int] $Depth = 0,
        [int] $MaximumDepth = 5
    )

    $packageFile = Join-Path $Directory 'package.json'
    if (Test-Path -LiteralPath $packageFile -PathType Leaf) {
        $packageFile
    }

    if ($Depth -ge $MaximumDepth) {
        return
    }

    foreach ($child in (Get-ChildItem -LiteralPath $Directory -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($ignoredDirectories -contains $child.Name) {
            continue
        }

        Find-PackageFiles -Directory $child.FullName -Depth ($Depth + 1) -MaximumDepth $MaximumDepth
    }
}

function Get-DependencyNames {
    param([object] $Package)

    $names = @()
    foreach ($sectionName in @('dependencies', 'devDependencies', 'peerDependencies')) {
        $section = $Package.$sectionName
        if ($null -ne $section) {
            $names += @($section.PSObject.Properties.Name)
        }
    }

    $names
}

function Get-RelativePath {
    param([string] $Path)

    $rootUri = [Uri]::new(($root.TrimEnd('\') + '\'))
    $pathUri = [Uri]::new($Path)
    [Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

function Get-ResourceDirectory {
    param([string] $ProjectDirectory)

    $directory = $ProjectDirectory
    while ($directory -and $directory -ne $root) {
        if ((Test-Path -LiteralPath (Join-Path $directory 'fxmanifest.lua') -PathType Leaf) -or
            (Test-Path -LiteralPath (Join-Path $directory '__resource.lua') -PathType Leaf)) {
            return $directory
        }
        $directory = Split-Path -Parent $directory
    }

    Split-Path -Parent $ProjectDirectory
}

function Matches-ResourceFilter {
    param(
        [object] $Project,
        [string[]] $Filters
    )

    if (-not $Filters -or $Filters.Count -eq 0) {
        return $true
    }

    foreach ($filter in $Filters) {
        if ([string]::IsNullOrWhiteSpace($filter)) {
            continue
        }

        $needle = $filter.Trim().ToLowerInvariant()
        if ($Project.Name.ToLowerInvariant().Contains($needle) -or
            $Project.ResourceName.ToLowerInvariant().Contains($needle) -or
            $Project.RelativePath.ToLowerInvariant().Contains($needle)) {
            return $true
        }
    }

    return $false
}

function Find-NpmCommand {
    $command = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command 'npm' -ErrorAction SilentlyContinue
    }

    $command
}

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = @($machinePath, $userPath) -join ';'
}

function Find-ToolCommand {
    param([string] $Name)

    $command = Get-Command "$Name.cmd" -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command $Name -ErrorAction SilentlyContinue
    }

    $command
}

function Get-ProjectPackageManager {
    param(
        [object] $Package,
        [string] $Directory,
        [bool] $HasNpmLock,
        [bool] $HasPnpmLock,
        [bool] $HasYarnLock
    )

    $declaredManager = [string] $Package.packageManager
    if ($declaredManager -match '^(npm|pnpm|yarn)@') {
        return $Matches[1]
    }

    # A package-lock is the clearest signal for the npm projects in this
    # workspace, even when an old pnpm virtual-store folder is still present.
    if ($HasNpmLock) { return 'npm' }
    if ($HasPnpmLock) { return 'pnpm' }
    if ($HasYarnLock) { return 'yarn' }

    $nodeModules = Join-Path $Directory 'node_modules'
    if (Test-Path -LiteralPath (Join-Path $nodeModules '.pnpm') -PathType Container) {
        return 'pnpm'
    }

    if (Test-Path -LiteralPath (Join-Path $nodeModules '.yarn-integrity') -PathType Leaf) {
        return 'yarn'
    }

    return 'npm'
}

function Ensure-PackageManager {
    param([ValidateSet('npm', 'pnpm', 'yarn')][string] $Name)

    $command = Find-ToolCommand -Name $Name
    if ($command -or $Name -eq 'npm' -or $SkipInstall) {
        return $command
    }

    Write-Step "$Name is missing. Installing it automatically..." Yellow
    & $npmCommand.Source install --global "$Name@latest" --no-audit --no-fund | Out-Host
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $globalPrefix = (& $npmCommand.Source prefix --global 2>$null | Select-Object -First 1)
    if ($globalPrefix -and -not (($env:Path -split ';') -contains $globalPrefix)) {
        $env:Path = "$globalPrefix;$env:Path"
    }

    Find-ToolCommand -Name $Name
}

$preservedAssetExtensions = @(
    '.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg', '.bmp',
    '.woff', '.woff2', '.ttf', '.otf', '.eot',
    '.mp3', '.wav', '.ogg', '.mp4', '.webm'
)

$packageCacheRoot = Join-Path ([IO.Path]::GetTempPath()) 'static-react-ui-cache'

function Get-ProjectOutputDirectories {
    param([object] $Project)

    $directories = @(
        (Join-Path $Project.Directory 'build'),
        (Join-Path $Project.Directory 'dist'),
        (Join-Path $Project.ResourceDirectory 'dist'),
        (Join-Path $Project.ResourceDirectory 'nui')
    )

    $configFiles = Get-ChildItem -LiteralPath $Project.Directory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'vite.config.*' -or $_.Name -like 'vite.build.*' }

    foreach ($configFile in $configFiles) {
        $configSource = Get-Content -LiteralPath $configFile.FullName -Raw
        foreach ($match in [regex]::Matches($configSource, 'outDir\s*:\s*[''"]([^''"]+)[''"]')) {
            $directories += [IO.Path]::GetFullPath((Join-Path $Project.Directory $match.Groups[1].Value))
        }
        foreach ($match in [regex]::Matches($configSource, 'outDir\s*:\s*resolve\([^,]+,\s*[''"]([^''"]+)[''"]\s*\)')) {
            $directories += [IO.Path]::GetFullPath((Join-Path $Project.Directory $match.Groups[1].Value))
        }
    }

    $directories | Select-Object -Unique
}

function Test-SafeOutputDirectory {
    param(
        [object] $Project,
        [string] $Path
    )

    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $leaf = Split-Path $fullPath -Leaf
    if ($leaf -notin @('build', 'dist', 'nui', 'html')) {
        return $false
    }

    foreach ($allowedRoot in @($Project.Directory, $Project.ResourceDirectory)) {
        $fullRoot = [IO.Path]::GetFullPath($allowedRoot).TrimEnd('\') + '\'
        if ($fullPath.StartsWith($fullRoot, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Copy-DirectoryContents {
    param(
        [string] $Source,
        [string] $Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($entry in (Get-ChildItem -LiteralPath $Source -Force -ErrorAction SilentlyContinue)) {
        Copy-Item -LiteralPath $entry.FullName -Destination $Destination -Recurse -Force
    }
}

function New-OutputSnapshot {
    param([object] $Project)

    $snapshotRoot = Join-Path ([IO.Path]::GetTempPath()) ("static-ui-build-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $snapshotRoot -Force | Out-Null
    $entries = @()
    $index = 0

    foreach ($outputDirectory in (Get-ProjectOutputDirectories -Project $Project)) {
        if (-not (Test-SafeOutputDirectory -Project $Project -Path $outputDirectory)) {
            throw "Refusing to snapshot an unsafe output path: $outputDirectory"
        }

        $backupDirectory = Join-Path $snapshotRoot ([string] $index)
        $existed = Test-Path -LiteralPath $outputDirectory -PathType Container
        if ($existed) {
            Copy-DirectoryContents -Source $outputDirectory -Destination $backupDirectory
        }

        $entries += [PSCustomObject]@{
            Target = $outputDirectory
            Backup = $backupDirectory
            Existed = $existed
        }
        $index++
    }

    [PSCustomObject]@{
        Root = $snapshotRoot
        Entries = $entries
    }
}

function Restore-PreservedAssets {
    param([object] $Snapshot)

    $restored = 0
    foreach ($entry in $Snapshot.Entries) {
        if (-not $entry.Existed) {
            continue
        }

        foreach ($asset in (Get-ChildItem -LiteralPath $entry.Backup -File -Recurse -ErrorAction SilentlyContinue)) {
            if ($preservedAssetExtensions -notcontains $asset.Extension.ToLowerInvariant()) {
                continue
            }

            $relativePath = $asset.FullName.Substring($entry.Backup.Length).TrimStart('\')
            $targetPath = Join-Path $entry.Target $relativePath
            if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
                continue
            }

            $targetParent = Split-Path -Parent $targetPath
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            Copy-Item -LiteralPath $asset.FullName -Destination $targetPath -Force
            $restored++
        }
    }

    $restored
}

function Test-GeneratedOutput {
    param([object] $Project)

    foreach ($outputDirectory in (Get-ProjectOutputDirectories -Project $Project)) {
        if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
            continue
        }

        if (Get-ChildItem -LiteralPath $outputDirectory -Filter '*.html' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1) {
            return $true
        }
    }

    return $false
}

function Remove-OutputSnapshot {
    param([object] $Snapshot)

    if ($Snapshot -and $Snapshot.Root -and
        (Split-Path $Snapshot.Root -Leaf).StartsWith('static-ui-build-') -and
        (Test-Path -LiteralPath $Snapshot.Root)) {
        Remove-Item -LiteralPath $Snapshot.Root -Recurse -Force
    }
}

$stampRoot = Join-Path $root '.build-cache'

function Get-StringHash {
    param([string] $Text)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SourceFiles {
    param([string] $Directory)

    foreach ($entry in (Get-ChildItem -LiteralPath $Directory -Force -ErrorAction SilentlyContinue)) {
        if ($entry.PSIsContainer) {
            if ($ignoredDirectories -notcontains $entry.Name) {
                Get-SourceFiles -Directory $entry.FullName
            }
        }
        # Files the build itself writes next to the sources would make every start look stale.
        elseif ($entry.Name -notlike '*.tsbuildinfo' -and $entry.Name -notlike '*.timestamp-*') {
            $entry
        }
    }
}

function Get-SourceFingerprint {
    param([string] $Directory)

    # The config/ layout (static_inventory, static_emotemenu) keeps only tooling next to package.json and
    # the sources in the resource's src/, so edits there have to make the project stale as well.
    $roots = @($Directory)
    $siblingSource = Join-Path (Split-Path -Parent $Directory) 'src'
    if ((Split-Path $Directory -Leaf) -eq 'config' -and (Test-Path -LiteralPath $siblingSource -PathType Container)) {
        $roots += $siblingSource
    }

    $resourceRoot = Split-Path -Parent $Directory
    $lines = foreach ($sourceRoot in $roots) {
        foreach ($file in (Get-SourceFiles -Directory $sourceRoot)) {
            '{0}|{1}|{2}' -f $file.FullName.Substring($resourceRoot.Length), $file.Length, $file.LastWriteTimeUtc.Ticks
        }
    }
    Get-StringHash -Text (($lines | Sort-Object) -join "`n")
}

function Get-DependencyFingerprint {
    param([string] $Directory)

    $parts = foreach ($name in @('package.json', 'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock')) {
        $path = Join-Path $Directory $name
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            "$name|$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
        }
    }
    Get-StringHash -Text ($parts -join "`n")
}

function Get-StampPath {
    param([object] $Project)

    Join-Path $stampRoot (($Project.RelativePath -replace '[^A-Za-z0-9]+', '_').Trim('_') + '.txt')
}

function Read-BuildStamp {
    param([object] $Project)

    $path = Get-StampPath -Project $Project
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $null
    }

    $lines = @(Get-Content -LiteralPath $path)
    [PSCustomObject]@{
        Source = $lines[0]
        Dependencies = if ($lines.Count -gt 1) { $lines[1] } else { '' }
    }
}

function Write-BuildStamp {
    param([object] $Project)

    New-Item -ItemType Directory -Path $stampRoot -Force | Out-Null
    Set-Content -LiteralPath (Get-StampPath -Project $Project) -Encoding ascii -Value @(
        $Project.SourceFingerprint,
        $Project.DependencyFingerprint
    )
}

function Get-StaleReason {
    param([object] $Project)

    if (-not (Test-GeneratedOutput -Project $Project)) { return 'no build output' }
    if (-not $Project.Stamp) { return 'never built by this script' }
    if ($Project.Stamp.Dependencies -ne $Project.DependencyFingerprint) { return 'dependencies changed' }
    if ($Project.Stamp.Source -ne $Project.SourceFingerprint) { return 'sources changed' }
    return $null
}

$npmCommand = Find-NpmCommand
if (-not $npmCommand -and -not $SkipInstall -and -not $ListOnly) {
    $wingetCommand = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    if ($wingetCommand) {
        Write-Step 'Node.js/npm is missing. Installing the Node.js LTS prerequisite...' Yellow
        & $wingetCommand.Source install --id OpenJS.NodeJS.LTS --exact --silent --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            Update-ProcessPath
            $npmCommand = Find-NpmCommand
        }
    }
}

if (-not $npmCommand -and -not $ListOnly) {
    Write-Step 'Node.js/npm is required and could not be installed automatically. Install Node.js LTS, then run this file again.' Red
    exit 1
}

$projects = @()
foreach ($packagePath in (Find-PackageFiles -Directory $root)) {
    try {
        $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Step "Skipping invalid package file: $(Get-RelativePath -Path $packagePath)" Yellow
        continue
    }

    $dependencies = Get-DependencyNames -Package $package
    $isReact = $dependencies -contains 'react' -or $dependencies -contains 'react-dom'
    $buildCommand = if ($package.scripts) { [string] $package.scripts.build } else { '' }

    if (-not $isReact -or [string]::IsNullOrWhiteSpace($buildCommand)) {
        continue
    }

    $projectDirectory = Split-Path -Parent $packagePath
    $resourceDirectory = Get-ResourceDirectory -ProjectDirectory $projectDirectory
    $relativePath = Get-RelativePath -Path $projectDirectory
    $hasNpmLock = Test-Path -LiteralPath (Join-Path $projectDirectory 'package-lock.json') -PathType Leaf
    $hasPnpmLock = Test-Path -LiteralPath (Join-Path $projectDirectory 'pnpm-lock.yaml') -PathType Leaf
    $hasYarnLock = Test-Path -LiteralPath (Join-Path $projectDirectory 'yarn.lock') -PathType Leaf
    $project = [PSCustomObject]@{
        Name = if ($package.name) { [string] $package.name } else { Split-Path $projectDirectory -Leaf }
        ResourceName = Split-Path $resourceDirectory -Leaf
        ResourceDirectory = $resourceDirectory
        Directory = $projectDirectory
        RelativePath = $relativePath
        BuildCommand = $buildCommand
        UsesBundledNode = $dependencies -contains 'node'
        PackageManager = Get-ProjectPackageManager -Package $package -Directory $projectDirectory -HasNpmLock $hasNpmLock -HasPnpmLock $hasPnpmLock -HasYarnLock $hasYarnLock
        HasNpmLock = $hasNpmLock
        HasPnpmLock = $hasPnpmLock
        HasYarnLock = $hasYarnLock
        HasNodeModules = Test-Path -LiteralPath (Join-Path $projectDirectory 'node_modules') -PathType Container
        SourceFingerprint = Get-SourceFingerprint -Directory $projectDirectory
        DependencyFingerprint = Get-DependencyFingerprint -Directory $projectDirectory
        Stamp = $null
        StaleReason = $null
    }
    $project.Stamp = Read-BuildStamp -Project $project

    if (Matches-ResourceFilter -Project $project -Filters $Resource) {
        $projects += $project
    }
}

$projects = @($projects | Sort-Object RelativePath)

if ($projects.Count -eq 0) {
    Write-Step 'No matching React UIs with a build script were found.' Yellow
    exit 0
}

$allProjects = $projects

if ($OnlyStale) {
    foreach ($project in $projects) {
        $project.StaleReason = Get-StaleReason -Project $project
    }
    $projects = @($projects | Where-Object { $_.StaleReason })

    if ($projects.Count -eq 0) {
        Write-Step 'All UIs are up to date.' Green
        exit 0
    }
}

Write-Step ''
Write-Step "found $($projects.Count) project(s):" Cyan
foreach ($project in $projects) {
    $dependencyState = if ($SkipInstall) {
        if ($project.HasNodeModules) { 'dependency install skipped' } else { 'dependencies missing' }
    }
    else { "$($project.PackageManager) install" }
    if ($project.StaleReason) {
        $dependencyState = "$($project.StaleReason), $dependencyState"
    }
    Write-Step "  - $($project.ResourceName)  [$($project.RelativePath)]  ($dependencyState)" DarkGray
}

if ($ListOnly) {
    exit 0
}

$startedAt = Get-Date
$results = @()

for ($index = 0; $index -lt $projects.Count; $index++) {
    $project = $projects[$index]
    $number = $index + 1
    $projectStartedAt = Get-Date
    $success = $true
    $stage = 'build'
    $previousNodeOptions = $env:NODE_OPTIONS
    $changedNodeOptions = $false

    Write-Step ''
    Write-Step ('=' * 78) DarkGray
    Write-Step "[$number/$($projects.Count)] Building $($project.ResourceName)" Cyan
    Write-Step "Path: $($project.RelativePath)" DarkGray
    Write-Step "Package manager: $($project.PackageManager)" DarkGray
    Write-Step "Command: $($project.PackageManager) run build" DarkGray

    $snapshot = $null
    $locationPushed = $false
    try {
        $stage = 'snapshot'
        $snapshot = New-OutputSnapshot -Project $project

        Push-Location -LiteralPath $project.Directory
        $locationPushed = $true

        $packageManagerCommand = Ensure-PackageManager -Name $project.PackageManager
        if (-not $packageManagerCommand) {
            Write-Step "The $($project.PackageManager) package manager is unavailable." Red
            $success = $false
            $stage = 'toolchain'
        }

        $dependenciesUnchanged = $OnlyStale -and $project.HasNodeModules -and $project.Stamp -and
            $project.Stamp.Dependencies -eq $project.DependencyFingerprint

        if ($success -and $dependenciesUnchanged -and -not $SkipInstall) {
            Write-Step 'Dependencies unchanged since the last build; skipping install.' DarkGray
        }
        elseif ($SkipInstall) {
            if ($success -and -not $project.HasNodeModules) {
                Write-Step 'Dependencies are missing and -SkipInstall was supplied.' Red
                $success = $false
                $stage = 'dependencies'
            }
        }
        elseif ($success) {
            $stage = 'dependencies'
            New-Item -ItemType Directory -Path $packageCacheRoot -Force | Out-Null
            $installArguments = switch ($project.PackageManager) {
                'pnpm' {
                    $cachePath = Join-Path $packageCacheRoot 'pnpm'
                    if ($project.HasPnpmLock) { @('install', '--frozen-lockfile', '--store-dir', $cachePath) }
                    else { @('install', '--store-dir', $cachePath) }
                }
                'yarn' {
                    $cachePath = Join-Path $packageCacheRoot 'yarn'
                    if ($project.HasYarnLock) { @('install', '--frozen-lockfile', '--non-interactive', '--cache-folder', $cachePath) }
                    else { @('install', '--non-interactive', '--cache-folder', $cachePath) }
                }
                default {
                    $cachePath = Join-Path $packageCacheRoot 'npm'
                    @('install', '--no-audit', '--no-fund', '--legacy-peer-deps', '--cache', $cachePath)
                }
            }

            Write-Step "Installing dependencies with $($project.PackageManager) $($installArguments[0])..." Yellow
            & $packageManagerCommand.Source @installArguments
            if ($LASTEXITCODE -ne 0) {
                $success = $false
            }
        }

        if ($success) {
            $stage = 'build'
            if (-not $project.UsesBundledNode -and
                $project.BuildCommand -match '(^|\s)(craco|react-scripts)(\s|$)' -and
                $env:NODE_OPTIONS -notmatch '(^|\s)--openssl-legacy-provider(\s|$)') {
                $env:NODE_OPTIONS = (@($env:NODE_OPTIONS, '--openssl-legacy-provider') |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' '
                $changedNodeOptions = $true
                Write-Step 'Enabled the legacy OpenSSL provider required by this older React build.' DarkGray
            }
            & $packageManagerCommand.Source run build
            if ($LASTEXITCODE -ne 0) {
                $success = $false
            }
        }

        if ($success) {
            $stage = 'validation'
            if (-not (Test-GeneratedOutput -Project $project)) {
                Write-Step 'The build command finished but produced no HTML output.' Red
                $success = $false
            }
        }

        if ($success) {
            # Re-read after the build: npm install can rewrite the lockfile and package.json.
            $project.SourceFingerprint = Get-SourceFingerprint -Directory $project.Directory
            $project.DependencyFingerprint = Get-DependencyFingerprint -Directory $project.Directory
            Write-BuildStamp -Project $project
        }
    }
    catch {
        Write-Step $_.Exception.Message Red
        $success = $false
    }
    finally {
        if ($changedNodeOptions) {
            $env:NODE_OPTIONS = $previousNodeOptions
        }
        if ($locationPushed) {
            Pop-Location
        }
    }

    if ($snapshot) {
        try {
            if ($success) {
                $restoredAssets = Restore-PreservedAssets -Snapshot $snapshot
                if ($restoredAssets -gt 0) {
                    Write-Step "Preserved $restoredAssets existing background/font/media asset(s)." DarkGray
                }
            }
            else {
                Write-Step 'Skipped; its existing output was left as is.' Yellow
            }
        }
        catch {
            Write-Step "Output recovery failed: $($_.Exception.Message)" Red
            $success = $false
            $stage = 'recovery'
        }
        finally {
            Remove-OutputSnapshot -Snapshot $snapshot
        }
    }

    $elapsed = (Get-Date) - $projectStartedAt
    $results += [PSCustomObject]@{
        Resource = $project.ResourceName
        Path = $project.RelativePath
        Success = $success
        Stage = $stage
        Seconds = [math]::Round($elapsed.TotalSeconds, 1)
    }

    if ($success) {
        Write-Step "Completed $($project.ResourceName) in $([math]::Round($elapsed.TotalSeconds, 1))s." Green
    }
    else {
        Write-Step "Failed $($project.ResourceName) during $stage." Red
        if ($StopOnError) {
            break
        }
    }
}

$totalElapsed = (Get-Date) - $startedAt
$passed = @($results | Where-Object Success).Count
$failed = @($results | Where-Object { -not $_.Success }).Count

Write-Step ''
Write-Step ('=' * 78) DarkGray
Write-Step 'Build summary' Cyan
foreach ($result in $results) {
    $marker = if ($result.Success) { '[OK]' } else { '[FAILED]' }
    $color = if ($result.Success) { [ConsoleColor]::Green } else { [ConsoleColor]::Red }
    Write-Step ("{0,-9} {1,-32} {2,7}s  {3}" -f $marker, $result.Resource, $result.Seconds, $result.Path) $color
}

Write-Step ''
Write-Step "Finished in $([math]::Round($totalElapsed.TotalSeconds, 1))s: $passed passed, $failed failed." $(if ($failed -eq 0) { 'Green' } else { 'Red' })

if ($AskCleanup -and $passed -gt 0) {
    $moduleDirectories = @($allProjects |
        ForEach-Object { Join-Path $_.Directory 'node_modules' } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Container })

    if ($moduleDirectories.Count -gt 0) {
        Write-Step ''
        Write-Step "The built UIs don't need node_modules to run ($($moduleDirectories.Count) folder(s))." Cyan
        Write-Step 'Deleting them saves disk space; the next UI rebuild reinstalls them (slower).' DarkGray
        & choice.exe /c YN /t $CleanupTimeout /d N /m "Delete node_modules now? Defaults to No in $CleanupTimeout s"

        if ($LASTEXITCODE -eq 1) {
            foreach ($directory in $moduleDirectories) {
                # rmdir copes with node_modules paths that are too long for Remove-Item.
                & cmd.exe /c rmdir /s /q "`"$directory`""
                if (Test-Path -LiteralPath $directory) {
                    Write-Step "Could not fully delete $(Get-RelativePath -Path $directory)" Yellow
                }
            }
            Write-Step 'node_modules deleted.' Green
        }
        else {
            Write-Step 'Keeping node_modules.' DarkGray
        }
    }
}

if ($failed -gt 0) {
    exit 1
}

exit 0
