<#
    SSDownloader-GUI.ps1
    --------------------
    Downloads Minecraft screenshare forensic tools into C:\SSTools, with
    Short / Medium / Long presets, a scanner PIN box and a Cleanup button.
    Layout follows the Claude Design mockup.

    - Windows PowerShell 5.1, WinForms only, no external modules.
    - Safe to compile with:  Invoke-ps2exe .\SSDownloader-GUI.ps1 .\SSDownloader.exe -noConsole
    - Downloads run in a background runspace; a Timer on the UI thread reads
      progress from a synchronized hashtable, so the window never freezes.

    Tier meaning:  S = Short SS,  M = Medium SS,  L = Long SS
      Short  preset -> S
      Medium preset -> S + M
      Long   preset -> S + M + L
#>

# =============================================================================
#  TOOL LIST  (edit this to add / remove tools)
# -----------------------------------------------------------------------------
#  Name    : display name (also the sub-folder name inside C:\SSTools)
#  Tier    : S, M or L
#  Kind    : url    -> direct download, Urls = fallback mirrors tried in order
#            github -> latest release asset from Repo whose file name matches Pattern
#            page   -> no download, opens Url in the browser
# =============================================================================
$Tools = @(
    # ---- Tier S (Short SS) ----
    @{ Name = 'Echo (scanner)';         Tier = 'S'; Kind = 'page';   Url  = 'https://echo.ac' }
    @{ Name = 'Ocean (scanner)';        Tier = 'S'; Kind = 'page';   Url  = 'https://anticheat.ac' }
    @{ Name = 'System Informer';        Tier = 'S'; Kind = 'github'; Repo = 'winsiderss/si-builds';    Pattern = 'bin\.zip$' }
    @{ Name = 'WinPrefetchView';        Tier = 'S'; Kind = 'url';    Urls = @('https://www.nirsoft.net/utils/winprefetchview-x64.zip', 'https://www.nirsoft.net/utils/winprefetchview.zip') }
    @{ Name = 'PathsParser';            Tier = 'S'; Kind = 'github'; Repo = 'spokwn/PathsParser';      Pattern = '\.(exe|zip)$' }
    @{ Name = 'BAM Parser';             Tier = 'S'; Kind = 'github'; Repo = 'spokwn/BAM-parser';       Pattern = '\.(exe|zip)$' }
    @{ Name = 'Everything';             Tier = 'S'; Kind = 'url';    Urls = @('https://www.voidtools.com/Everything-1.4.1.1026.x64.zip') }

    # ---- Tier M (Medium SS) ----
    @{ Name = 'Registry Explorer';      Tier = 'M'; Kind = 'url';    Urls = @('https://download.ericzimmermanstools.com/net9/RegistryExplorer.zip', 'https://download.mikestammer.com/net6/RegistryExplorer.zip') }
    @{ Name = 'bstrings';               Tier = 'M'; Kind = 'url';    Urls = @('https://download.ericzimmermanstools.com/net9/bstrings.zip', 'https://download.mikestammer.com/net6/bstrings.zip') }
    @{ Name = 'JournalTrace';           Tier = 'M'; Kind = 'github'; Repo = 'spokwn/JournalTrace';     Pattern = '\.(exe|zip)$' }
    @{ Name = 'Prefetch Parser';        Tier = 'M'; Kind = 'github'; Repo = 'spokwn/prefetch-parser';  Pattern = '\.(exe|zip)$' }
    @{ Name = 'USBDeview';              Tier = 'M'; Kind = 'url';    Urls = @('https://www.nirsoft.net/utils/usbdeview-x64.zip', 'https://www.nirsoft.net/utils/usbdeview.zip') }
    @{ Name = 'Vigils Task Parser';     Tier = 'M'; Kind = 'github'; Repo = 'Inkenal/TaskParser';      Pattern = '\.(exe|zip)$' }
    @{ Name = 'Vigil Registry Scanner'; Tier = 'M'; Kind = 'github'; Repo = 'Inkenal/RegistryScanner'; Pattern = '\.(exe|zip)$' }
    @{ Name = 'FTK Imager';             Tier = 'M'; Kind = 'page';   Url  = 'https://www.exterro.com/digital-forensics-software/ftk-imager' }

    # ---- Tier L (Long SS) ----
    @{ Name = 'Timeline Explorer';      Tier = 'L'; Kind = 'url';    Urls = @('https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip', 'https://download.mikestammer.com/net6/TimelineExplorer.zip') }
    @{ Name = 'WxTCmd';                 Tier = 'L'; Kind = 'url';    Urls = @('https://download.ericzimmermanstools.com/net9/WxTCmd.zip', 'https://download.mikestammer.com/net6/WxTCmd.zip') }
    @{ Name = 'AmcacheParser';          Tier = 'L'; Kind = 'url';    Urls = @('https://download.ericzimmermanstools.com/net9/AmcacheParser.zip', 'https://download.mikestammer.com/net6/AmcacheParser.zip') }
    @{ Name = 'MFTECmd';                Tier = 'L'; Kind = 'url';    Urls = @('https://download.ericzimmermanstools.com/net9/MFTECmd.zip', 'https://download.mikestammer.com/net6/MFTECmd.zip') }
    @{ Name = 'PECmd';                  Tier = 'L'; Kind = 'url';    Urls = @('https://download.ericzimmermanstools.com/net9/PECmd.zip', 'https://download.mikestammer.com/net6/PECmd.zip') }
    @{ Name = 'Hayabusa';               Tier = 'L'; Kind = 'github'; Repo = 'Yamato-Security/hayabusa'; Pattern = 'win-x64.*\.zip$' }
    @{ Name = 'AlternateStreamView';    Tier = 'L'; Kind = 'url';    Urls = @('https://www.nirsoft.net/utils/alternatestreamview-x64.zip', 'https://www.nirsoft.net/utils/alternatestreamview.zip') }
    @{ Name = 'LastActivityView';       Tier = 'L'; Kind = 'url';    Urls = @('https://www.nirsoft.net/utils/lastactivityview.zip') }
    @{ Name = 'Process Parser';         Tier = 'L'; Kind = 'github'; Repo = 'spokwn/process-parser';   Pattern = '\.(exe|zip)$' }
    @{ Name = 'PcaSvc Executed';        Tier = 'L'; Kind = 'github'; Repo = 'spokwn/pcasvc-executed';  Pattern = '\.(exe|zip)$' }
    @{ Name = 'WinPmem (RAM dumper)';   Tier = 'L'; Kind = 'github'; Repo = 'Velocidex/WinPmem';       Pattern = 'winpmem_mini_x64.*\.exe$' }
    @{ Name = 'RAMPSParser';            Tier = 'L'; Kind = 'github'; Repo = 'aaa1243/ram-ps-parser';   Pattern = 'RAMPSParser\.exe$' }
    @{ Name = 'RAMDumpExplorer';        Tier = 'L'; Kind = 'github'; Repo = 'bacanoicua/RAMDumpExplorer'; Pattern = '\.(exe|zip)$' }
    @{ Name = 'PowerShell-Hunter';      Tier = 'L'; Kind = 'url';    Urls = @('https://github.com/MHaggis/PowerShell-Hunter/archive/refs/heads/main.zip') }
    @{ Name = 'Detect It Easy';         Tier = 'L'; Kind = 'github'; Repo = 'horsicq/DIE-engine';      Pattern = 'win64_portable.*\.zip$' }
    @{ Name = 'Recuva';                 Tier = 'L'; Kind = 'page';   Url  = 'https://www.ccleaner.com/recuva/download' }
    @{ Name = 'Stream Detector';        Tier = 'L'; Kind = 'page';   Url  = 'https://www.novirusthanks.org/products/stream-detector/' }
    @{ Name = 'detect.ac ++ tools';     Tier = 'L'; Kind = 'page';   Url  = 'https://detect.ac' }
)

# Where everything gets installed
$InstallDir = 'C:\SSTools'

# =============================================================================
#  SCANNER PIN LINKS
# -----------------------------------------------------------------------------
#  The PIN box in the header opens a scanner's download for that PIN.
#  Put {0} where the PIN goes. To find the format, make a PIN in the scanner's
#  dashboard and look at the download link it gives you.
#  If a link has no {0}, the site opens and the PIN is copied to the clipboard.
# =============================================================================
$ScannerLinks = [ordered]@{
    'Ocean' = 'https://anticheat.ac'     # e.g. change to 'https://anticheat.ac/<path>/{0}'
    'Echo'  = 'https://echo.ac'          # e.g. change to 'https://echo.ac/<path>/{0}'
}


# =============================================================================
#  SETUP
# =============================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Native helpers: dark title bar + placeholder text in the PIN box (optional, skipped if unavailable)
$script:HasNative = $false
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SSNative {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
}
"@ -ErrorAction Stop
    $script:HasNative = $true
} catch { }

function Set-DarkTitleBar {
    param($Window)
    if (-not $script:HasNative) { return }
    try {
        $on = 1
        [void][SSNative]::DwmSetWindowAttribute($Window.Handle, 20, [ref]$on, 4)   # Win10 2004+ / Win11
        [void][SSNative]::DwmSetWindowAttribute($Window.Handle, 19, [ref]$on, 4)   # older Win10 builds
    } catch { }
}

# --- Colours (from the Claude Design mockup) ---------------------------------
function C([string]$hex) { return [System.Drawing.ColorTranslator]::FromHtml($hex) }
$ColWindow    = C '#1B1C1F'
$ColPanel     = C '#232529'
$ColPanelHead = C '#2A2C31'
$ColGroupRow  = C '#1F2124'
$ColLogBack   = C '#141518'
$ColBorder    = C '#34373D'
$ColBorder2   = C '#3E4248'
$ColRowLine   = C '#292C30'
$ColText      = C '#E6E7EA'
$ColTitle     = C '#F2F3F5'
$ColSub       = C '#C9CCD1'
$ColDim       = C '#9AA0A8'
$ColMuted     = C '#8E939B'
$ColPre       = C '#7D838C'
$ColAccent    = C '#B3263A'
$ColAccentSub = C '#F6D9DD'
$ColOK        = C '#4CC38A'
$ColOKBar     = C '#3FA977'
$ColErr       = C '#FF6B6E'
$ColDanger    = C '#E5484D'
$ColDangerBtn = C '#C62F3B'
$ColRunRow    = [System.Drawing.Color]::FromArgb(58, 37, 44)
$ColBannerBg  = C '#1E2A24'
$ColBannerBd  = C '#2D4A3A'

$FontUI       = New-Object System.Drawing.Font('Segoe UI', 9.75)
$FontSmall    = New-Object System.Drawing.Font('Segoe UI', 8.5)
$FontSmallB   = New-Object System.Drawing.Font('Segoe UI', 8.25, [System.Drawing.FontStyle]::Bold)
$FontBold     = New-Object System.Drawing.Font('Segoe UI Semibold', 10.5)
$FontTitle    = New-Object System.Drawing.Font('Segoe UI Semibold', 14.25)
$FontMono     = New-Object System.Drawing.Font('Consolas', 9)
$FontPin      = New-Object System.Drawing.Font('Consolas', 10.5)

$TierName = @{ 'S' = 'Short'; 'M' = 'Medium'; 'L' = 'Long' }
$TierRank = @{ 'S' = 1; 'M' = 2; 'L' = 3 }

# Shared state
$script:Job          = $null    # running download (PS / Runspace / Handle / Sync)
$script:Suppress     = $false   # ignore checkbox events while changing them in code
$script:ActivePreset = ''       # 'S', 'M', 'L' or '' (custom)
$script:LastFailed   = @()      # names that failed in the last run (for Retry failed)
$script:RunTotal     = 0


# =============================================================================
#  BACKGROUND WORKER  (runs in its own runspace, never touches the UI)
#  Writes to $sync:
#     $sync.Log     -> queue of log entries @{ Kind; Pre; Name; Msg; Tone }
#     $sync.Status  -> tool name -> 'queued' | 'run' | 'done' | 'opened' | 'fail'
#     $sync.Current -> name of the tool being downloaded
#     $sync.Done    -> number finished
#     $sync.Failed  -> list of @{ Name; Reason }
#     $sync.Cancel  -> set by the UI when the window closes mid-download
# =============================================================================
$Worker = {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference    = 'SilentlyContinue'
    $UserAgent             = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) SSDownloader'
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $total = @($Jobs).Count

    function Log-Info([string]$Msg, [string]$Tone = 'muted') {
        $sync.Log.Enqueue(@{ Kind = 'info'; Msg = $Msg; Tone = $Tone })
    }
    function Log-Tool([int]$I, [string]$Name, [string]$Msg, [string]$Tone) {
        $sync.Log.Enqueue(@{ Kind = 'tool'; Pre = ('[{0}/{1}]' -f $I, $total); Name = $Name; Msg = $Msg; Tone = $Tone })
    }
    function Get-ErrorText($ErrorRecord) {
        $ex = $ErrorRecord.Exception
        while ($ex.InnerException) { $ex = $ex.InnerException }
        return $ex.Message
    }
    function Get-SafeName([string]$Name) { return ($Name -replace '[\\/:*?"<>|]', '_').Trim() }

    function Save-Url([string]$Url, [string]$Folder, [string]$FallbackName) {
        $fileName = [System.IO.Path]::GetFileName(([Uri]$Url).AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = "$FallbackName.exe" }
        $dest = Join-Path $Folder $fileName
        $wc = New-Object System.Net.WebClient
        try {
            $wc.Headers.Add('User-Agent', $UserAgent)
            $wc.DownloadFile($Url, $dest)
        }
        catch {
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue }
            throw
        }
        finally { $wc.Dispose() }
        return $dest
    }

    # Extract a zip safely (blocks entries that try to escape the folder)
    function Expand-Zip([string]$ZipPath, [string]$Destination) {
        $root = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
        $zip  = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        try {
            foreach ($entry in $zip.Entries) {
                $target = [System.IO.Path]::GetFullPath((Join-Path $Destination $entry.FullName))
                if (-not $target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                if ([string]::IsNullOrEmpty($entry.Name)) {
                    if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                    continue
                }
                $dir = Split-Path $target -Parent
                if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            }
        }
        finally { $zip.Dispose() }
    }

    function Complete-Download([string]$File, [string]$Folder) {
        if ([System.IO.Path]::GetExtension($File) -eq '.zip') {
            Expand-Zip -ZipPath $File -Destination $Folder
            Remove-Item -LiteralPath $File -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -LiteralPath $Folder -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
    }

    function Get-FromUrls($Tool, [string]$Folder) {
        $lastErr = 'no URLs listed'
        foreach ($u in @($Tool.Urls)) {
            if ([string]::IsNullOrWhiteSpace($u)) { continue }
            try { return (Save-Url -Url $u -Folder $Folder -FallbackName (Get-SafeName $Tool.Name)) }
            catch {
                $lastErr = Get-ErrorText $_
                Log-Info ("   {0}: mirror failed, trying next ({1})" -f $Tool.Name, $lastErr)
            }
        }
        throw "all links failed ($lastErr)"
    }

    function Get-FromGitHub($Tool, [string]$Folder) {
        $api     = "https://api.github.com/repos/$($Tool.Repo)/releases/latest"
        $headers = @{ 'User-Agent' = $UserAgent; 'Accept' = 'application/vnd.github+json' }
        try { $release = Invoke-RestMethod -Uri $api -Headers $headers -UseBasicParsing }
        catch {
            $code = $null
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            if ($code -eq 404) {
                Start-Process "https://github.com/$($Tool.Repo)"
                throw 'no release found (opened repo page)'
            }
            throw ("GitHub error: {0}" -f (Get-ErrorText $_))
        }
        $asset = @($release.assets) | Where-Object { $_.name -match $Tool.Pattern } | Select-Object -First 1
        if (-not $asset) {
            Start-Process "https://github.com/$($Tool.Repo)/releases/latest"
            throw 'no matching file in release (opened releases page)'
        }
        return (Save-Url -Url $asset.browser_download_url -Folder $Folder -FallbackName (Get-SafeName $Tool.Name))
    }

    Log-Info ("Downloading {0} tools to {1}" -f $total, $InstallDir) 'text'
    $okCount = 0
    $index   = 0
    foreach ($tool in @($Jobs)) {
        if ($sync.Cancel) { Log-Info 'Cancelled.' 'err'; break }
        $index++
        $name   = [string]$tool.Name
        $folder = Join-Path $InstallDir (Get-SafeName $name)
        $sync.Current       = $name
        $sync.Status[$name] = 'run'

        try {
            $kind = ([string]$tool.Kind).ToLower()
            if ($kind -eq 'page') {
                Start-Process $tool.Url
                $sync.Status[$name] = 'opened'
                Log-Tool $index $name 'opened in browser' 'ok'
            }
            elseif ($kind -eq 'url' -or $kind -eq 'github') {
                Log-Tool $index $name 'downloading...' 'text'
                if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
                if ($kind -eq 'url') { $file = Get-FromUrls -Tool $tool -Folder $folder }
                else                 { $file = Get-FromGitHub -Tool $tool -Folder $folder }
                Complete-Download -File $file -Folder $folder
                $sync.Status[$name] = 'done'
                Log-Tool $index $name 'done' 'ok'
            }
            else { throw "unknown Kind '$($tool.Kind)'" }
            $okCount++
        }
        catch {
            $reason = Get-ErrorText $_
            # Remove an empty folder left behind by a failed download
            if ((Test-Path -LiteralPath $folder) -and -not (Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $folder -Force -ErrorAction SilentlyContinue
            }
            $sync.Status[$name] = 'fail'
            [void]$sync.Failed.Add(@{ Name = $name; Reason = $reason })
            Log-Tool $index $name ("FAILED: $reason") 'err'
        }
        $sync.Done = $index
    }

    Log-Info ("Finished: {0} done, {1} failed" -f $okCount, $sync.Failed.Count) 'text'
    foreach ($f in $sync.Failed) { Log-Info ("Failed: {0} ({1})" -f $f.Name, $f.Reason) 'err' }
    $sync.OkCount = $okCount
}


# =============================================================================
#  UI HELPERS
# =============================================================================
function New-Label {
    param([string]$Text, [int]$X, [int]$Y, $Font, $Color)
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $Text
    $l.Location  = New-Object System.Drawing.Point($X, $Y)
    $l.AutoSize  = $true
    $l.Font      = $Font
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}

function New-FlatButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H, $Back, $Fore, $Border)
    $b = New-Object System.Windows.Forms.Button
    $b.Text      = $Text
    $b.Location  = New-Object System.Drawing.Point($X, $Y)
    $b.Size      = New-Object System.Drawing.Size($W, $H)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderColor = $Border
    $b.FlatAppearance.BorderSize  = 1
    $b.BackColor = $Back
    $b.ForeColor = $Fore
    $b.Font      = $FontUI
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.UseVisualStyleBackColor = $false
    return $b
}

function New-LinkButton {
    param([string]$Text, [int]$X, [int]$Y)
    $l = New-Object System.Windows.Forms.LinkLabel
    $l.Text             = $Text
    $l.Location         = New-Object System.Drawing.Point($X, $Y)
    $l.AutoSize         = $true
    $l.Font             = $FontUI
    $l.LinkColor        = $ColText
    $l.ActiveLinkColor  = $ColTitle
    $l.VisitedLinkColor = $ColText
    $l.DisabledLinkColor = $ColMuted
    $l.LinkBehavior     = [System.Windows.Forms.LinkBehavior]::AlwaysUnderline
    $l.BackColor        = [System.Drawing.Color]::Transparent
    return $l
}

# Coloured log line in the RichTextBox
function Add-LogText([string]$Text, $Color) {
    $LogBox.SelectionStart  = $LogBox.TextLength
    $LogBox.SelectionLength = 0
    $LogBox.SelectionColor  = $Color
    $LogBox.AppendText($Text)
}
function Get-ToneColor([string]$Tone) {
    switch ($Tone) { 'ok' { return $ColOK } 'err' { return $ColErr } 'text' { return $ColText } default { return $ColMuted } }
}
function Write-LogInfo([string]$Msg, [string]$Tone = 'muted') {
    Add-LogText ($Msg + "`n") (Get-ToneColor $Tone)
    $LogBox.ScrollToCaret()
}
function Write-LogEntry($Entry) {
    if ($Entry.Kind -eq 'tool') {
        Add-LogText ([string]$Entry.Pre + ' ') $ColPre
        Add-LogText ([string]$Entry.Name + '  ') $ColText
        Add-LogText ([string]$Entry.Msg + "`n") (Get-ToneColor $Entry.Tone)
    }
    else { Add-LogText ([string]$Entry.Msg + "`n") (Get-ToneColor $Entry.Tone) }
    $LogBox.ScrollToCaret()
}

# Tool rows in the grid (skips group header rows)
function Get-ToolRows {
    $rows = @()
    foreach ($r in $Grid.Rows) { if ($r.Tag -is [hashtable]) { $rows += $r } }
    return $rows
}
function Get-CheckedTools {
    $sel = @()
    foreach ($r in (Get-ToolRows)) { if ([bool]$r.Cells[0].Value) { $sel += $r.Tag } }
    return $sel
}

# Status column for one row
function Set-RowStatus($Row, [string]$Status) {
    $cell = $Row.Cells[4]
    $back = $ColPanel
    switch ($Status) {
        'queued' { $cell.Value = 'queued';      $cell.Style.ForeColor = $ColMuted }
        'run'    { $cell.Value = 'downloading'; $cell.Style.ForeColor = $ColTitle; $back = $ColRunRow }
        'done'   { $cell.Value = ([string][char]0x2713 + ' done');   $cell.Style.ForeColor = $ColOK }
        'opened' { $cell.Value = ([string][char]0x2713 + ' opened'); $cell.Style.ForeColor = $ColOK }
        'fail'   { $cell.Value = ([string][char]0x2715 + ' failed'); $cell.Style.ForeColor = $ColErr }
        default  { $cell.Value = '' }
    }
    $cell.Tag = $Status
    $Row.DefaultCellStyle.BackColor          = $back
    $Row.DefaultCellStyle.SelectionBackColor = $back
}
function Clear-Statuses { foreach ($r in (Get-ToolRows)) { Set-RowStatus $r '' } }

# Selected count, download button text, preset highlight
function Update-Selection {
    $n     = @(Get-CheckedTools).Count
    $total = @(Get-ToolRows).Count
    $SelectedLabel.Text = ('{0} of {1} selected' -f $n, $total)
    if (-not $script:Job) {
        $DownloadButton.Text = ('Download selected ({0})' -f $n)
        if (-not $script:RunTotal) { $ProgCount.Text = ('0 of {0}' -f $n) }
    }
    foreach ($b in $PresetButtons) { $b.Invalidate() }
}

function Set-Preset([string]$Tier) {
    $script:Suppress = $true
    foreach ($r in (Get-ToolRows)) {
        $on = $false
        if ($Tier -eq 'ALL') { $on = $true }
        elseif ($Tier) { $on = ($TierRank[$r.Tag.Tier] -le $TierRank[$Tier]) }
        $r.Cells[0].Value = $on
    }
    $script:Suppress = $false
    if ($Tier -eq 'ALL' -or -not $Tier) { $script:ActivePreset = '' } else { $script:ActivePreset = $Tier }
    Update-Selection
}

# Progress bar (custom so it can use the accent colour)
function Set-Progress([int]$Done, [int]$Total, [string]$Label, $Color) {
    $ProgLabel.Text = $Label
    $ProgCount.Text = ('{0} of {1}' -f $Done, $Total)
    $pct = 0
    if ($Total -gt 0) { $pct = [Math]::Min(1.0, $Done / $Total) }
    $ProgFill.Width     = [int](($ProgTrack.ClientSize.Width) * $pct)
    $ProgFill.BackColor = $Color
}

# Show / hide the banner row and resize the middle area around it
function Show-Banner([string]$Which) {
    $FinBanner.Visible   = ($Which -eq 'finished')
    $CleanBanner.Visible = ($Which -eq 'cleaned')
    $h = $MiddleFullHeight
    if ($Which) { $h = $MiddleFullHeight - 48 }
    $GridFrame.Height = $h
    $LogFrame.Height  = $h
}

function Set-Busy([bool]$Busy) {
    foreach ($b in $PresetButtons) { $b.Enabled = -not $Busy; $b.Invalidate() }
    $SelectAll.Enabled  = -not $Busy
    $SelectNone.Enabled = -not $Busy
    $Grid.Columns[0].ReadOnly = $Busy
    $CleanupButton.Enabled = -not $Busy
    if ($Busy) {
        $DownloadButton.Enabled   = $false
        $DownloadButton.BackColor = $ColPanelHead
        $DownloadButton.ForeColor = $ColMuted
        $DownloadButton.FlatAppearance.BorderColor = $ColBorder2
        $CleanupButton.ForeColor  = $ColMuted
        $CleanupButton.FlatAppearance.BorderColor = $ColBorder2
    }
    else {
        $DownloadButton.Enabled   = $true
        $DownloadButton.BackColor = $ColAccent
        $DownloadButton.ForeColor = [System.Drawing.Color]::White
        $DownloadButton.FlatAppearance.BorderColor = $ColAccent
        $CleanupButton.ForeColor  = $ColErr
        $CleanupButton.FlatAppearance.BorderColor = $ColDanger
        Update-Selection
    }
}

function Wait-Responsive([int]$Milliseconds) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $Milliseconds) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }
}

# Dark confirm dialog for cleanup. Returns $true if the user clicked "Delete everything".
function Show-CleanupConfirm {
    $d = New-Object System.Windows.Forms.Form
    $d.Text            = 'Confirm cleanup'
    $d.ClientSize      = New-Object System.Drawing.Size(440, 168)
    $d.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $d.MaximizeBox     = $false
    $d.MinimizeBox     = $false
    $d.ShowInTaskbar   = $false
    $d.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
    $d.BackColor       = $ColPanel
    $d.ForeColor       = $ColText
    $d.Font            = $FontUI
    $d.Add_HandleCreated({ Set-DarkTitleBar $this })

    # Red circle with "!"
    $icon = New-Object System.Windows.Forms.Panel
    $icon.Location = New-Object System.Drawing.Point(20, 20)
    $icon.Size     = New-Object System.Drawing.Size(36, 36)
    $icon.BackColor = $ColPanel
    $icon.Add_Paint({
            param($s, $e)
            $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $br = New-Object System.Drawing.SolidBrush((C '#3A1F23'))
            $e.Graphics.FillEllipse($br, 0, 0, 35, 35)
            $br.Dispose()
            $f = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
            [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, '!', $f, (New-Object System.Drawing.Rectangle(0, 0, 36, 36)), $ColErr,
                ([System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter))
            $f.Dispose()
        })

    $title = New-Label 'Delete everything?' 70 18 (New-Object System.Drawing.Font('Segoe UI Semibold', 12)) $ColTitle
    $body  = New-Object System.Windows.Forms.Label
    $body.Text      = "This deletes $InstallDir and everything in it. Tools still running will be closed."
    $body.Location  = New-Object System.Drawing.Point(70, 46)
    $body.Size      = New-Object System.Drawing.Size(350, 40)
    $body.ForeColor = $ColSub
    $body.Font      = $FontUI

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Location  = New-Object System.Drawing.Point(0, 106)
    $bar.Size      = New-Object System.Drawing.Size(440, 62)
    $bar.BackColor = $ColGroupRow

    $cancel = New-FlatButton 'Cancel' 196 14 90 34 $ColPanelHead $ColText $ColBorder2
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $del = New-FlatButton 'Delete everything' 296 14 126 34 $ColDangerBtn ([System.Drawing.Color]::White) $ColDangerBtn
    $del.Font = $FontBold
    $del.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $bar.Controls.AddRange(@($cancel, $del))

    $d.Controls.AddRange(@($icon, $title, $body, $bar))
    $d.CancelButton = $cancel
    $result = $d.ShowDialog($Form)
    $d.Dispose()
    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}


# =============================================================================
#  BUILD THE WINDOW  (900 x 588 client area, fixed size like the mockup)
# =============================================================================
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = 'SS Tools Downloader'
$Form.ClientSize      = New-Object System.Drawing.Size(900, 588)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.MaximizeBox     = $false
$Form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.BackColor       = $ColWindow
$Form.ForeColor       = $ColText
$Form.Font            = $FontUI
$Form.Add_HandleCreated({ Set-DarkTitleBar $Form })

# --- Header: title, install folder, PIN box, Open folder ---------------------
$TitleLabel  = New-Label 'SS Tools Downloader' 14 10 $FontTitle $ColTitle
$FolderLabel = New-Label "Install folder: $InstallDir" 17 40 $FontMono $ColDim

$ScannerBox = New-Object System.Windows.Forms.ComboBox
$ScannerBox.Location      = New-Object System.Drawing.Point(356, 19)
$ScannerBox.Size          = New-Object System.Drawing.Size(80, 26)
$ScannerBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$ScannerBox.FlatStyle     = [System.Windows.Forms.FlatStyle]::Flat
$ScannerBox.BackColor     = $ColPanelHead
$ScannerBox.ForeColor     = $ColText
foreach ($k in $ScannerLinks.Keys) { [void]$ScannerBox.Items.Add($k) }
$ScannerBox.SelectedIndex = 0

$PinBox = New-Object System.Windows.Forms.TextBox
$PinBox.Location    = New-Object System.Drawing.Point(442, 19)
$PinBox.Size        = New-Object System.Drawing.Size(150, 26)
$PinBox.BackColor   = $ColLogBack
$PinBox.ForeColor   = $ColText
$PinBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$PinBox.Font        = $FontPin
$PinBox.Add_HandleCreated({
        if ($script:HasNative) { try { [void][SSNative]::SendMessage($PinBox.Handle, 0x1501, [IntPtr]1, 'Scanner PIN') } catch { } }
    })

$OpenScanButton  = New-FlatButton 'Open scan' 598 16 92 32 $ColPanelHead $ColText $ColBorder2
$OpenFolderButton = New-FlatButton 'Open folder' 760 14 124 34 $ColPanelHead $ColText $ColBorder2

# --- Preset cards ------------------------------------------------------------
$PresetFrame = New-Object System.Windows.Forms.Panel
$PresetFrame.Location  = New-Object System.Drawing.Point(16, 66)
$PresetFrame.Size      = New-Object System.Drawing.Size(508, 56)
$PresetFrame.BackColor = $ColBorder2

$countS = @($Tools | Where-Object { $_.Tier -eq 'S' }).Count
$countM = $countS + @($Tools | Where-Object { $_.Tier -eq 'M' }).Count
$countL = @($Tools).Count
$PresetDefs = @(
    @{ Key = 'S'; Title = 'Short SS';  Hint = "$countS tools, quick check" }
    @{ Key = 'M'; Title = 'Medium SS'; Hint = "$countM tools, standard" }
    @{ Key = 'L'; Title = 'Long SS';   Hint = "All $countL tools" }
)
$PresetButtons = @()
$px = 1
foreach ($def in $PresetDefs) {
    $b = New-Object System.Windows.Forms.Button
    $b.Location  = New-Object System.Drawing.Point($px, 1)
    $b.Size      = New-Object System.Drawing.Size(168, 54)
    $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor = $ColPanelHead
    $b.FlatAppearance.MouseDownBackColor = $ColPanelHead
    $b.BackColor = $ColPanel
    $b.Text      = ''
    $b.Tag       = $def
    $b.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $b.Add_Paint({
            param($s, $e)
            $def    = $s.Tag
            $active = ($script:ActivePreset -eq $def.Key)
            $back = $ColPanel; $tc = $ColText; $hc = $ColDim
            if ($active) { $back = $ColAccent; $tc = [System.Drawing.Color]::White; $hc = $ColAccentSub }
            if (-not $s.Enabled) { $tc = $ColMuted; $hc = $ColMuted }
            $e.Graphics.Clear($back)
            $flags = [System.Windows.Forms.TextFormatFlags]::Left -bor [System.Windows.Forms.TextFormatFlags]::NoPadding
            [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $def.Title, $FontBold, (New-Object System.Drawing.Point(16, 8)), $tc, $flags)
            [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, $def.Hint, $FontSmall, (New-Object System.Drawing.Point(16, 30)), $hc, $flags)
        })
    $b.Add_Click({ param($s, $e) Set-Preset $s.Tag.Key })
    $PresetFrame.Controls.Add($b)
    $PresetButtons += $b
    $px += 169
}

$SelectedLabel = New-Label '' 600 86 $FontUI $ColDim
$SelectedLabel.AutoSize  = $false
$SelectedLabel.Size      = New-Object System.Drawing.Size(130, 20)
$SelectedLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$SelectedLabel.Location  = New-Object System.Drawing.Point(600, 85)
$SelectAll  = New-LinkButton 'Select all'  740 86
$SelectNone = New-LinkButton 'Select none' 808 86

# --- Tool table --------------------------------------------------------------
$MiddleTop        = 134
$MiddleFullHeight = 384     # shrinks by 48 when a banner shows

$GridFrame = New-Object System.Windows.Forms.Panel
$GridFrame.Location  = New-Object System.Drawing.Point(16, $MiddleTop)
$GridFrame.Size      = New-Object System.Drawing.Size(526, $MiddleFullHeight)
$GridFrame.BackColor = $ColBorder
$GridFrame.Padding   = New-Object System.Windows.Forms.Padding(1)

$Grid = New-Object System.Windows.Forms.DataGridView
$Grid.Dock                        = [System.Windows.Forms.DockStyle]::Fill
$Grid.BorderStyle                 = [System.Windows.Forms.BorderStyle]::None
$Grid.BackgroundColor             = $ColPanel
$Grid.GridColor                   = $ColRowLine
$Grid.CellBorderStyle             = [System.Windows.Forms.DataGridViewCellBorderStyle]::SingleHorizontal
$Grid.ColumnHeadersBorderStyle    = [System.Windows.Forms.DataGridViewHeaderBorderStyle]::None
$Grid.EnableHeadersVisualStyles   = $false
$Grid.RowHeadersVisible           = $false
$Grid.AllowUserToAddRows          = $false
$Grid.AllowUserToDeleteRows       = $false
$Grid.AllowUserToResizeRows       = $false
$Grid.AllowUserToResizeColumns    = $false
$Grid.AllowUserToOrderColumns     = $false
$Grid.MultiSelect                 = $false
$Grid.SelectionMode               = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$Grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
$Grid.ColumnHeadersHeight         = 26
$Grid.RowTemplate.Height          = 24
$Grid.ScrollBars                  = [System.Windows.Forms.ScrollBars]::Vertical
$Grid.ColumnHeadersDefaultCellStyle.BackColor          = $ColPanelHead
$Grid.ColumnHeadersDefaultCellStyle.ForeColor          = $ColDim
$Grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = $ColPanelHead
$Grid.ColumnHeadersDefaultCellStyle.Font               = $FontSmallB
$Grid.DefaultCellStyle.BackColor          = $ColPanel
$Grid.DefaultCellStyle.ForeColor          = $ColText
$Grid.DefaultCellStyle.SelectionBackColor = $ColPanel
$Grid.DefaultCellStyle.SelectionForeColor = $ColText
$Grid.DefaultCellStyle.Font               = $FontUI
$Grid.DefaultCellStyle.Padding            = New-Object System.Windows.Forms.Padding(4, 0, 0, 0)

$colChk = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colChk.HeaderText = ''
$colChk.Width      = 34
$colChk.FlatStyle  = [System.Windows.Forms.FlatStyle]::Flat
$colTool = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colTool.HeaderText   = 'TOOL'
$colTool.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
$colTool.ReadOnly     = $true
$colTier = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colTier.HeaderText = 'TIER'
$colTier.Width      = 66
$colTier.ReadOnly   = $true
$colTier.DefaultCellStyle.ForeColor = $ColSub
$colTier.DefaultCellStyle.Font      = $FontSmall
$colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colType.HeaderText = 'TYPE'
$colType.Width      = 112
$colType.ReadOnly   = $true
$colType.DefaultCellStyle.ForeColor = (C '#AEB2B9')
$colType.DefaultCellStyle.Font      = $FontSmall
$colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colStatus.HeaderText = 'STATUS'
$colStatus.Width      = 92
$colStatus.ReadOnly   = $true
$colStatus.DefaultCellStyle.Font = $FontSmall
[void]$Grid.Columns.AddRange(@($colChk, $colTool, $colTier, $colType, $colStatus))
foreach ($c in $Grid.Columns) { $c.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable }

# Fill: a group header row per tier, then its tools
foreach ($tier in @('S', 'M', 'L')) {
    $tierTools = @($Tools | Where-Object { ([string]$_.Tier).ToUpper() -eq $tier })
    if ($tierTools.Count -eq 0) { continue }
    $i = $Grid.Rows.Add($false, ('{0} SS     {1} tools' -f $TierName[$tier].ToUpper(), $tierTools.Count), '', '', '')
    $gr = $Grid.Rows[$i]
    $gr.Tag = 'group'
    $gr.ReadOnly = $true
    $gr.DefaultCellStyle.BackColor          = $ColGroupRow
    $gr.DefaultCellStyle.SelectionBackColor = $ColGroupRow
    $gr.DefaultCellStyle.ForeColor          = $ColSub
    $gr.DefaultCellStyle.SelectionForeColor = $ColSub
    $gr.DefaultCellStyle.Font               = $FontSmallB
    foreach ($t in $tierTools) {
        switch (([string]$t.Kind).ToLower()) {
            'github' { $typeText = 'GitHub' }
            'page'   { $typeText = 'Opens website ' + [char]0x2197 }
            default  { $typeText = 'Direct' }
        }
        $i = $Grid.Rows.Add($false, $t.Name, $TierName[$tier], $typeText, '')
        $Grid.Rows[$i].Tag = $t
    }
}

# Hide the checkbox on group header rows
$Grid.Add_CellPainting({
        param($s, $e)
        if ($e.RowIndex -ge 0 -and $e.ColumnIndex -eq 0 -and $s.Rows[$e.RowIndex].Tag -eq 'group') {
            $e.PaintBackground($e.CellBounds, $false)
            $e.Handled = $true
        }
    })
$GridFrame.Controls.Add($Grid)

# --- Log panel ---------------------------------------------------------------
$LogFrame = New-Object System.Windows.Forms.Panel
$LogFrame.Location  = New-Object System.Drawing.Point(554, $MiddleTop)
$LogFrame.Size      = New-Object System.Drawing.Size(330, $MiddleFullHeight)
$LogFrame.BackColor = $ColBorder
$LogFrame.Padding   = New-Object System.Windows.Forms.Padding(1)

$LogHead = New-Object System.Windows.Forms.Panel
$LogHead.Dock      = [System.Windows.Forms.DockStyle]::Top
$LogHead.Height    = 26
$LogHead.BackColor = $ColPanelHead
$LogTitle = New-Label 'LOG' 10 6 $FontSmallB $ColDim
$CopyLog  = New-LinkButton 'Copy' 280 5
$CopyLog.LinkBehavior = [System.Windows.Forms.LinkBehavior]::HoverUnderline
$CopyLog.LinkColor    = (C '#B4B8BF')
$CopyLog.Font         = $FontSmall
$LogHead.Controls.AddRange(@($LogTitle, $CopyLog))

$LogPad = New-Object System.Windows.Forms.Panel
$LogPad.Dock      = [System.Windows.Forms.DockStyle]::Fill
$LogPad.BackColor = $ColLogBack
$LogPad.Padding   = New-Object System.Windows.Forms.Padding(10, 8, 4, 4)

$LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.Dock        = [System.Windows.Forms.DockStyle]::Fill
$LogBox.ReadOnly    = $true
$LogBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$LogBox.BackColor   = $ColLogBack
$LogBox.ForeColor   = $ColMuted
$LogBox.Font        = $FontMono
$LogBox.WordWrap    = $true
$LogBox.DetectUrls  = $false
$LogBox.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$LogPad.Controls.Add($LogBox)
$LogFrame.Controls.Add($LogPad)
$LogFrame.Controls.Add($LogHead)

# --- Banners (finished / cleanup) --------------------------------------------
function New-Banner {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location  = New-Object System.Drawing.Point(16, ($MiddleTop + $MiddleFullHeight - 36))
    $p.Size      = New-Object System.Drawing.Size(868, 36)
    $p.BackColor = $ColBannerBg
    $p.Visible   = $false
    $p.Add_Paint({
            param($s, $e)
            $pen = New-Object System.Drawing.Pen($ColBannerBd)
            $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        })
    return $p
}
$FinBanner   = New-Banner
$FinTitle    = New-Label 'Finished' 14 9 $FontBold $ColTitle
$FinDone     = New-Label '' 90 9 $FontBold $ColOK
$FinFailed   = New-Label '' 180 9 $FontBold $ColErr
$FinReason   = New-Label '' 270 10 $FontUI $ColDim
$RetryLink   = New-LinkButton 'Retry failed' 780 9
$FinBanner.Controls.AddRange(@($FinTitle, $FinDone, $FinFailed, $FinReason, $RetryLink))

$CleanBanner = New-Banner
$CleanTitle  = New-Label ([string][char]0x2713 + ' Cleanup complete') 14 9 $FontBold $ColOK
$CleanText   = New-Label "$InstallDir and everything in it was deleted." 170 10 $FontUI $ColSub
$CleanBanner.Controls.AddRange(@($CleanTitle, $CleanText))

# --- Bottom bar: download, progress, cleanup ---------------------------------
$DownloadButton = New-FlatButton 'Download selected (0)' 16 530 290 44 $ColAccent ([System.Drawing.Color]::White) $ColAccent
$DownloadButton.Font = $FontBold

$ProgLabel = New-Label 'Ready' 320 531 $FontSmall $ColDim
$ProgCount = New-Label '0 of 0' 680 531 $FontSmall $ColText
$ProgCount.AutoSize  = $false
$ProgCount.Size      = New-Object System.Drawing.Size(70, 16)
$ProgCount.TextAlign = [System.Drawing.ContentAlignment]::TopRight
$ProgCount.Font      = $FontSmallB

$ProgTrack = New-Object System.Windows.Forms.Panel
$ProgTrack.Location    = New-Object System.Drawing.Point(320, 554)
$ProgTrack.Size        = New-Object System.Drawing.Size(430, 10)
$ProgTrack.BackColor   = $ColPanelHead
$ProgTrack.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$ProgFill = New-Object System.Windows.Forms.Panel
$ProgFill.Location  = New-Object System.Drawing.Point(0, 0)
$ProgFill.Size      = New-Object System.Drawing.Size(0, 8)
$ProgFill.BackColor = $ColAccent
$ProgTrack.Controls.Add($ProgFill)

$CleanupButton = New-FlatButton 'Cleanup' 764 530 120 44 $ColWindow $ColErr $ColDanger
$CleanupButton.Font = $FontBold
$CleanupButton.FlatAppearance.BorderSize = 2

$Form.Controls.AddRange(@(
        $TitleLabel, $FolderLabel, $ScannerBox, $PinBox, $OpenScanButton, $OpenFolderButton,
        $PresetFrame, $SelectedLabel, $SelectAll, $SelectNone,
        $GridFrame, $LogFrame, $FinBanner, $CleanBanner,
        $DownloadButton, $ProgLabel, $ProgCount, $ProgTrack, $CleanupButton
    ))

$PollTimer = New-Object System.Windows.Forms.Timer
$PollTimer.Interval = 150


# =============================================================================
#  EVENTS
# =============================================================================

# --- Checkbox changes --------------------------------------------------------
$Grid.Add_CurrentCellDirtyStateChanged({
        if ($Grid.IsCurrentCellDirty) { [void]$Grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
    })
$Grid.Add_CellValueChanged({
        param($s, $e)
        if ($script:Suppress -or $e.RowIndex -lt 0 -or $e.ColumnIndex -ne 0) { return }
        $script:ActivePreset = ''
        Update-Selection
    })
# Clicking anywhere on a tool row toggles it
$Grid.Add_CellClick({
        param($s, $e)
        if ($script:Job -or $e.RowIndex -lt 0 -or $e.ColumnIndex -eq 0) { return }
        $row = $Grid.Rows[$e.RowIndex]
        if ($row.Tag -isnot [hashtable]) { return }
        $row.Cells[0].Value = -not [bool]$row.Cells[0].Value
    })

$SelectAll.Add_LinkClicked({  Set-Preset 'ALL' })
$SelectNone.Add_LinkClicked({ Set-Preset '' })
$CopyLog.Add_LinkClicked({
        if ($LogBox.TextLength -gt 0) { [System.Windows.Forms.Clipboard]::SetText($LogBox.Text) }
    })

# --- Scanner PIN -------------------------------------------------------------
$OpenScan = {
    $pin = $PinBox.Text.Trim()
    if ($pin -notmatch '^[A-Za-z0-9_\-]{3,64}$') {
        Write-LogInfo 'Enter a valid PIN (letters, numbers, - or _).' 'err'
        return
    }
    $scanner  = [string]$ScannerBox.SelectedItem
    $template = [string]$ScannerLinks[$scanner]
    try {
        if ($template.Contains('{0}')) {
            Start-Process ($template -f [Uri]::EscapeDataString($pin))
            Write-LogInfo ("{0}: opened scan for PIN {1}" -f $scanner, $pin) 'ok'
        }
        else {
            [System.Windows.Forms.Clipboard]::SetText($pin)
            Start-Process $template
            Write-LogInfo ("{0}: opened site, PIN copied to clipboard" -f $scanner) 'ok'
        }
    }
    catch { Write-LogInfo ("{0}: couldn't open ({1})" -f $scanner, $_.Exception.Message) 'err' }
}
$OpenScanButton.Add_Click($OpenScan)
$PinBox.Add_KeyDown({
        param($s, $e)
        if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) { $e.SuppressKeyPress = $true; & $OpenScan }
    })

# --- Open folder -------------------------------------------------------------
$OpenFolderButton.Add_Click({
        try {
            if (-not (Test-Path -LiteralPath $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
            Start-Process explorer.exe -ArgumentList "`"$InstallDir`""
        }
        catch { Write-LogInfo ("Couldn't open {0}: {1}" -f $InstallDir, $_.Exception.Message) 'err' }
    })

# --- Download ----------------------------------------------------------------
function Start-Download($Selected) {
    if ($script:Job) { return }
    $Selected = @($Selected)
    if ($Selected.Count -eq 0) { Write-LogInfo 'Tick at least one tool first (or pick a preset).' 'err'; return }
    try {
        if (-not (Test-Path -LiteralPath $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
    }
    catch { Write-LogInfo ("Couldn't create {0}: {1}" -f $InstallDir, $_.Exception.Message) 'err'; return }

    $sync = [hashtable]::Synchronized(@{
            Log     = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
            Status  = [hashtable]::Synchronized(@{})
            Failed  = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
            Current = ''
            Done    = 0
            OkCount = 0
            Total   = $Selected.Count
            Cancel  = $false
        })

    # Statuses: selected = queued, others blank
    $names = @{}
    foreach ($t in $Selected) { $names[[string]$t.Name] = $true; $sync.Status[[string]$t.Name] = 'queued' }
    foreach ($r in (Get-ToolRows)) {
        if ($names.ContainsKey([string]$r.Tag.Name)) { Set-RowStatus $r 'queued' } else { Set-RowStatus $r '' }
    }

    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = [System.Threading.ApartmentState]::STA
    $runspace.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('sync', $sync)
    $runspace.SessionStateProxy.SetVariable('Jobs', $Selected)
    $runspace.SessionStateProxy.SetVariable('InstallDir', $InstallDir)
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $runspace
    [void]$ps.AddScript($Worker.ToString())

    Show-Banner ''
    $LogBox.Clear()
    $script:RunTotal = $Selected.Count
    Set-Progress 0 $Selected.Count 'Starting...' $ColAccent
    Set-Busy $true
    $DownloadButton.Text = ('Downloading 0 of {0}...' -f $Selected.Count)

    $handle = $ps.BeginInvoke()
    $script:Job = @{ PS = $ps; Runspace = $runspace; Handle = $handle; Sync = $sync }
    $PollTimer.Start()
}

$DownloadButton.Add_Click({ Start-Download (Get-CheckedTools) })
$RetryLink.Add_LinkClicked({
        $retry = @()
        foreach ($r in (Get-ToolRows)) { if ($script:LastFailed -contains [string]$r.Tag.Name) { $retry += $r.Tag } }
        Start-Download $retry
    })

# --- Poll the worker (UI thread) ---------------------------------------------
$PollTimer.Add_Tick({
        if (-not $script:Job) { $PollTimer.Stop(); return }
        $job       = $script:Job
        $sync      = $job.Sync
        $completed = $job.Handle.IsCompleted

        while ($sync.Log.Count -gt 0) { Write-LogEntry ($sync.Log.Dequeue()) }

        foreach ($r in (Get-ToolRows)) {
            $n = [string]$r.Tag.Name
            if ($sync.Status.ContainsKey($n)) {
                $st = [string]$sync.Status[$n]
                if ([string]$r.Cells[4].Tag -ne $st) {
                    Set-RowStatus $r $st
                    $r.Cells[4].Tag = $st
                    if ($st -eq 'run') { try { $Grid.FirstDisplayedScrollingRowIndex = [Math]::Max(0, $r.Index - 3) } catch { } }
                }
            }
        }

        $done = [int]$sync.Done
        if (-not $completed) {
            $cur = [string]$sync.Current
            $label = 'Starting...'
            if ($cur) { $label = "Downloading $cur" }
            Set-Progress $done $sync.Total $label $ColAccent
            $DownloadButton.Text = ('Downloading {0} of {1}...' -f ([Math]::Min($done + 1, $sync.Total)), $sync.Total)
            return
        }

        # Finished
        $PollTimer.Stop()
        try { [void]$job.PS.EndInvoke($job.Handle) }
        catch { Write-LogInfo ("Worker crashed: {0}" -f $_.Exception.Message) 'err' }
        foreach ($err in $job.PS.Streams.Error) { Write-LogInfo ("Worker error: {0}" -f $err.ToString()) 'err' }
        while ($sync.Log.Count -gt 0) { Write-LogEntry ($sync.Log.Dequeue()) }
        try { $job.PS.Dispose() } catch { }
        try { $job.Runspace.Close(); $job.Runspace.Dispose() } catch { }

        $failed = @($sync.Failed)
        $script:LastFailed = @($failed | ForEach-Object { [string]$_.Name })
        $script:Job = $null

        Set-Progress $sync.Total $sync.Total 'Complete' $ColOKBar
        $FinDone.Text   = ([string][char]0x2713 + (' {0} done' -f [int]$sync.OkCount))
        $FinFailed.Text = ([string][char]0x2715 + (' {0} failed' -f $failed.Count))
        $FinFailed.Visible = ($failed.Count -gt 0)
        $RetryLink.Visible = ($failed.Count -gt 0)
        $FinFailed.Left = $FinDone.Right + 14
        if ($failed.Count -gt 0) {
            $txt = ('{0}: {1}' -f $failed[0].Name, $failed[0].Reason)
            if ($failed.Count -gt 1) { $txt += (' (+{0} more, see log)' -f ($failed.Count - 1)) }
            if ($txt.Length -gt 70) { $txt = $txt.Substring(0, 67) + '...' }
            $FinReason.Text = $txt
            $FinReason.Left = $FinFailed.Right + 14
        }
        else { $FinReason.Text = '' }
        Show-Banner 'finished'
        Set-Busy $false
        $script:RunTotal = 0
        $ProgCount.Text = ('{0} of {1}' -f $sync.Total, $sync.Total)
    })

# --- Cleanup -----------------------------------------------------------------
$CleanupButton.Add_Click({
        if ($script:Job) { return }
        if (-not (Test-Path -LiteralPath $InstallDir)) {
            Write-LogInfo "$InstallDir doesn't exist, nothing to delete."
            return
        }
        if (-not (Show-CleanupConfirm)) { return }

        $CleanupButton.Enabled  = $false
        $DownloadButton.Enabled = $false
        $LogBox.Clear()
        Write-LogInfo 'Cleanup started' 'text'
        Write-LogInfo 'Closing tools still running...'

        $prefix = $InstallDir.TrimEnd('\') + '\'
        $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
                $p = $null
                try { $p = $_.Path } catch { }
                $p -and $p.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and $_.Id -ne $PID
            })
        $closed = @()
        foreach ($proc in $procs) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop; $closed += $proc.ProcessName }
            catch { Write-LogInfo ("Couldn't close {0}: {1}" -f $proc.ProcessName, $_.Exception.Message) 'err' }
        }
        if ($closed.Count) { Write-LogInfo ('Closed ' + (($closed | Select-Object -Unique) -join ', ')) 'text' }
        else { Write-LogInfo 'No tools were running.' }

        Wait-Responsive 2000
        Write-LogInfo "Deleting $InstallDir..."
        Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue

        if (-not (Test-Path -LiteralPath $InstallDir)) {
            Write-LogInfo "Deleted $InstallDir" 'ok'
            Write-LogInfo 'Cleanup complete. Folder no longer exists.' 'ok'
            Clear-Statuses
            Set-Progress 0 0 'Ready' $ColAccent
            $FolderLabel.Text = "Install folder: $InstallDir  (deleted)"
            Show-Banner 'cleaned'
        }
        else {
            $left = @(Get-ChildItem -LiteralPath $InstallDir -Recurse -File -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
            Write-LogInfo ("Cleanup incomplete: {0} file(s) still in use:" -f $left.Count) 'err'
            foreach ($f in ($left | Select-Object -First 15)) { Write-LogInfo "   $f" 'err' }
            Write-LogInfo 'Close them (or restart the PC if a driver is loaded) and run Cleanup again.'
        }
        $CleanupButton.Enabled  = $true
        $DownloadButton.Enabled = $true
        Update-Selection
    })

# --- Closing mid-download ----------------------------------------------------
$Form.Add_FormClosing({
        param($s, $e)
        if ($script:Job) {
            $answer = [System.Windows.Forms.MessageBox]::Show('A download is still running. Quit anyway?', 'SS Tools Downloader',
                [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { $e.Cancel = $true; return }
            $script:Job.Sync.Cancel = $true
            try { [void]$script:Job.PS.BeginStop($null, $null) } catch { }
        }
    })


# =============================================================================
#  START
# =============================================================================
Set-Preset 'M'
Write-LogInfo 'Ready.'
Write-LogInfo "Install folder: $InstallDir"
Write-LogInfo ('Preset: Medium SS ({0} tools selected)' -f @(Get-CheckedTools).Count) 'text'
$Form.Add_Shown({ $Grid.ClearSelection(); $Grid.CurrentCell = $null })

[void]$Form.ShowDialog()

if ($script:Job) { [System.Environment]::Exit(0) }
