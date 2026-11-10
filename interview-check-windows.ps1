# CodeVector - interview environment check (Windows)
#
# WHAT IT READS: windows that are hidden from screen sharing, running apps and processes,
# connected displays, and the names of installed browser and code-editor extensions.
# WHAT IT DOES NOT DO: change anything, read your documents, browsing history or passwords, or send
# anything anywhere (from browser settings it reads only the extension list).
# It saves a plain-text report on your Desktop. Read it, then send it yourself.
#
# Run in PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\interview-check-windows.ps1 <code>
#   (add --no-open to skip opening Explorer at the report)

$ErrorActionPreference = 'SilentlyContinue'

# ---- Watch lists: whole-word, case-insensitive; "interview coder" also matches InterviewCoder ----
# Sold specifically for getting AI help during live interviews. Any match is a red flag.
$InterviewTools = @('cluely', 'interview coder', 'final round', 'lockedin', 'locked in', 'parakeet',
  'verve ai', 'verve copilot', 'sensei ai', 'sensei copilot', 'leetcode wizard', 'interview solver',
  'pluely', 'cheating daddy', 'interview hammer', 'beyz', 'linkjob', 'shadecoder', 'interview copilot',
  'pickle glass', 'interviews chat')
# General AI assistants and AI coding tools: fine to own, not fine to have open in a closed-book round.
$AiTools = @('chatgpt', 'chat gpt', 'openai', 'codex', 'claude', 'anthropic', 'gemini', 'copilot',
  'perplexity', 'comet', 'grok', 'deepseek', 'mistral', 'le chat', 'poe', 'meta ai', 'qwen', 'kimi',
  'cursor', 'windsurf', 'codeium', 'tabnine', 'supermaven', 'cody', 'continue', 'cline', 'roo code',
  'roo cline', 'kilo code', 'amazon q', 'codewhisperer', 'qodo', 'blackbox', 'bito', 'aider', 'opencode',
  'goose', 'kiro', 'trae', 'antigravity', 'zed', 'warp', 'pearai', 'ml-llm', 'junie', 'ollama',
  'lm studio', 'gpt4all', 'msty', 'jan ai', 'monica', 'sider', 'maxai', 'harpa', 'aiprm', 'granola',
  'otter', 'fireflies', 'tldv', 'fathom', 'notta', 'krisp', 'wispr', 'superwhisper', 'whisper',
  'raycast', 'highlight', 'rewind', 'limitless', 'screenpipe', 'dia', 'opera neon', 'phind',
  'huggingchat', 'gpt', 'llm', 'ai')
# Lets someone else see or control this computer.
$RemoteTools = @('anydesk', 'teamviewer', 'rustdesk', 'parsec', 'splashtop', 'screenconnect',
  'jump desktop', 'realvnc', 'vnc', 'vncserver', 'vncviewer', 'tightvnc', 'tvnserver', 'tigervnc',
  'ultravnc', 'winvnc', 'chrome remote desktop', 'remoting host', 'chromoting', 'logmein', 'gotomypc',
  'goto resolve', 'zoho assist', 'ultraviewer', 'supremo', 'ammyy', 'aeroadmin', 'dwservice',
  'remotepc', 'getscreen', 'nomachine', 'quick assist', 'quickassist', 'mstsc', 'msrdc', 'rdpclip')
# Owners whose hidden windows are normally harmless (meeting-app share toolbars, password managers).
# Matched against the whole process name, so "Researcher.exe" does not pass as "arc".
$UsualHiders = '^(zoom|ms-teams|teams|webex|ciscocollabhost|atmgr|slack|discord|skype|chrome|msedge|arc|brave|firefox|opera|vivaldi|1password|bitwarden|keepass|keepassxc|dashlane|lastpass|signal)(\.exe)?$'

function New-Matcher([string[]]$Words) {
  $parts = foreach ($w in $Words) { [regex]::Escape($w).Replace('\ ', '[\s._-]?') }
  return [regex]::new('(^|[^a-z0-9])(' + ($parts -join '|') + ')(?![a-z0-9])', 'IgnoreCase')
}
function Test-Match($Re, [string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) { return $false }
  if ($Re.IsMatch($Text)) { return $true }
  # Also try a camelCase-split copy so "ChromeRemoteDesktopHost" can match "chrome remote desktop".
  $split = [regex]::Replace($Text, '([a-z0-9])([A-Z])', '$1 $2')
  $split = [regex]::Replace($split, '([A-Z]+)([A-Z][a-z])', '$1 $2')
  return $Re.IsMatch($split)
}
$ReInterview = New-Matcher $InterviewTools
$ReAi = New-Matcher $AiTools
$ReRemote = New-Matcher $RemoteTools
function Test-Any($Re, [string[]]$Texts) { foreach ($t in $Texts) { if (Test-Match $Re $t) { return $true } }; return $false }

# ---- Small helpers -------------------------------------------------------------------------------
function Clean($s) { if ($null -eq $s) { return '' }; return ([string]$s -replace '[\u200e\u200f\u202a-\u202e\u2066-\u2069]', '').Trim() }
function Read-Text([string]$Path) {
  try {
    $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try { return (New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)).ReadToEnd() } finally { $fs.Dispose() }
  } catch { return $null }
}
$script:Jss = $null
function ConvertFrom-JsonText([string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) { return $null }
  $Text = $Text.TrimStart([char]0xFEFF)
  try {
    if ($PSVersionTable.PSVersion.Major -ge 6) { return , ($Text | ConvertFrom-Json -AsHashtable) }
    if (-not $script:Jss) {
      Add-Type -AssemblyName System.Web.Extensions
      $script:Jss = New-Object System.Web.Script.Serialization.JavaScriptSerializer
      $script:Jss.MaxJsonLength = [int]::MaxValue
      $script:Jss.RecursionLimit = 1000
    }
    return , $script:Jss.DeserializeObject($Text)
  } catch { return $null }
}
function Read-Json([string]$Path) { $t = Read-Text $Path; if ($null -eq $t) { return $null }; return , (ConvertFrom-JsonText $t) }
function Get-Val($Obj, [string[]]$Keys) {
  foreach ($k in $Keys) {
    if ($Obj -isnot [System.Collections.IDictionary]) { return $null }
    if (-not ($Obj.Keys -ccontains $k)) { return $null }
    $Obj = $Obj[$k]
  }
  return , $Obj
}
function Get-Started($d) {
  if ($d -isnot [datetime]) { return '' }
  if ($d.Date -eq (Get-Date).Date) { return 'today ' + $d.ToString('HH:mm') }
  return $d.ToString('d MMM HH:mm')
}

# ---- Code from the interviewer (proves the report was made now, not earlier) -----------------------
$NoOpen = $args -contains '--no-open'
$Code = @($args | Where-Object { "$_" -notlike '--*' })[0]
if (-not $Code) { $Code = Read-Host 'Type the code your interviewer gave you, then press Enter' }
$Code = ("$Code" -replace '[^A-Za-z0-9_-]', '')
if ($Code.Length -gt 32) { $Code = $Code.Substring(0, 32) }
if (-not $Code) { $Code = 'NONE' }

$Now = Get-Date
$Stamp = $Now.ToString('yyyy-MM-dd HH:mm:ss') + ' ' + $Now.ToString('zzz').Replace(':', '')
$OnWindows = $env:OS -eq 'Windows_NT'
$UserHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$OsText = ''; $Machine = ''; $IsVM = $false; $IsRemoteSession = $false
if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
  $os = Get-CimInstance Win32_OperatingSystem
  $cs = Get-CimInstance Win32_ComputerSystem
  $OsText = "$($os.Caption) $($os.Version)"
  $Machine = "$($cs.Manufacturer) $($cs.Model)"
  $IsVM = $Machine -match 'virtual|vmware|virtualbox|innotek|kvm|qemu|xen|parallels|bochs'
}
if (-not $OsText) { $OsText = [System.Environment]::OSVersion.VersionString }

# ---- Windows that ask Windows to keep them out of screen sharing / recording ----------------------
# Overlay "interview copilots" call SetWindowDisplayAffinity so the interviewer cannot see them.
# This also catches windows that are currently tucked away with a hotkey.
$HiddenWindows = @()
$HiddenError = ''
if ($OnWindows) {
  try {
    if (-not ('IvCheck.Win' -as [type])) {
      Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
namespace IvCheck {
  public class HiddenWindow { public uint Pid; public uint Affinity; public bool Visible; public string Title; public int Width; public int Height; }
  public static class Win {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetWindowDisplayAffinity(IntPtr h, out uint a);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    public static List<HiddenWindow> Find() {
      List<HiddenWindow> found = new List<HiddenWindow>();
      EnumWindows(delegate (IntPtr h, IntPtr l) {
        uint a;
        if (GetWindowDisplayAffinity(h, out a) && a != 0) {
          uint pid; GetWindowThreadProcessId(h, out pid);
          StringBuilder sb = new StringBuilder(256); GetWindowText(h, sb, 256);
          RECT r; GetWindowRect(h, out r);
          HiddenWindow w = new HiddenWindow();
          w.Pid = pid; w.Affinity = a; w.Visible = IsWindowVisible(h); w.Title = sb.ToString();
          w.Width = r.R - r.L; w.Height = r.B - r.T;
          found.Add(w);
        }
        return true;
      }, IntPtr.Zero);
      return found;
    }
  }
}
'@
    }
    $HiddenWindows = @([IvCheck.Win]::Find())
  } catch { $HiddenError = $_.Exception.Message }
}

# ---- Processes -------------------------------------------------------------------------------------
$WinDir = if ($env:windir) { $env:windir.TrimEnd('\') + '\' } else { '/System/' }
$GP = @{}
foreach ($p in Get-Process) { $GP[[int]$p.Id] = $p }
$Procs = @()
if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
  $Procs = foreach ($w in Get-CimInstance Win32_Process) {
    $p = $GP[[int]$w.ProcessId]
    [pscustomobject]@{ Id = [int]$w.ProcessId; Name = [string]$w.Name; Path = [string]$w.ExecutablePath; Window = [bool]($p -and $p.MainWindowHandle -ne 0); Start = $w.CreationDate }
  }
} else {
  $Procs = foreach ($p in $GP.Values) {
    [pscustomobject]@{ Id = [int]$p.Id; Name = [string]$p.ProcessName; Path = [string]$p.Path; Window = [bool]($p.MainWindowHandle -ne 0); Start = $p.StartTime }
  }
}
$VerCache = @{}
function Get-FileInfo([string]$Path) {
  if (-not $Path) { return $null }
  if (-not $VerCache.ContainsKey($Path)) {
    $vi = $null
    try { $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path) } catch { }
    $VerCache[$Path] = $vi
  }
  return $VerCache[$Path]
}
$MyPid = $PID
$SystemCount = 0
$NoPathNames = @{}
$Groups = @{}   # key: path (or name) -> @{ Name; Path; Count; Desc; Company; Window; Start }
foreach ($p in $Procs) {
  if ($p.Id -eq $MyPid -or $p.Id -le 4) { continue }
  if (-not $p.Path) { $NoPathNames[$p.Name] = 1; continue }
  if ($p.Path.StartsWith($WinDir, [System.StringComparison]::OrdinalIgnoreCase)) { $SystemCount++; continue }
  $key = $p.Path.ToLowerInvariant()
  if (-not $Groups.ContainsKey($key)) {
    $vi = Get-FileInfo $p.Path
    $Groups[$key] = [pscustomobject]@{ Name = $p.Name; Path = $p.Path; Count = 0; Desc = (Clean $vi.FileDescription); Company = (Clean $vi.CompanyName); Window = $false; Start = $null }
  }
  $g = $Groups[$key]
  $g.Count++
  if ($p.Window) { $g.Window = $true }
  if ($p.Start -is [datetime] -and (($null -eq $g.Start) -or ($p.Start -lt $g.Start))) { $g.Start = $p.Start }
}
$GroupList = @($Groups.Values | Sort-Object Name)
$WindowApps = @($GroupList | Where-Object { $_.Window })
$Background = @($GroupList | Where-Object { -not $_.Window })
$PidToProc = @{}
foreach ($p in $Procs) { $PidToProc[$p.Id] = $p }
$HiddenWindows = @(foreach ($h in $HiddenWindows) {
    $p = $PidToProc[[int]$h.Pid]
    $owner = if ($p) { $p.Name } else { "pid $($h.Pid)" }
    $ownerPath = if ($p) { [string]$p.Path } else { '' }
    $vi = Get-FileInfo $ownerPath
    $usual = ($owner -match $UsualHiders) -or ($ownerPath -and $ownerPath.StartsWith($WinDir, [System.StringComparison]::OrdinalIgnoreCase))
    [pscustomobject]@{ Pid = [int]$h.Pid; Affinity = [int]$h.Affinity; Visible = [bool]$h.Visible; Title = [string]$h.Title; Width = [int]$h.Width; Height = [int]$h.Height
      Owner = $owner; OwnerPath = $ownerPath; OwnerDesc = (Clean $(if ($vi) { $vi.FileDescription } else { '' })); Usual = [bool]$usual }
  })

# ---- Displays and remote sessions ------------------------------------------------------------------
$Screens = @()
try {
  Add-Type -AssemblyName System.Windows.Forms
  $IsRemoteSession = [System.Windows.Forms.SystemInformation]::TerminalServerSession
  $Screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
      $_.DeviceName.TrimStart('\', '.') + ' ' + $_.Bounds.Width + 'x' + $_.Bounds.Height + $(if ($_.Primary) { ' (main)' } else { '' }) })
} catch { }

# ---- Browser extensions ----------------------------------------------------------------------------
$Local = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $UserHome 'AppData/Local' }
$Roam = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $UserHome 'AppData/Roaming' }

function Get-ManifestName([string]$Dir) {
  if (-not $Dir) { return $null }
  $txt = Read-Text (Join-Path $Dir 'manifest.json')
  if ($null -eq $txt) { return $null }
  $m = ConvertFrom-JsonText $txt
  $name = $null; $loc = $null
  if ($m -is [System.Collections.IDictionary]) { $name = Get-Val $m 'name'; $loc = Get-Val $m 'default_locale' }
  elseif ($txt -match '"name"\s*:\s*"([^"]*)"') { $name = $Matches[1] }
  if ("$name" -match '^__MSG_(.+)__$') {
    $key = $Matches[1]
    foreach ($l in @($loc, 'en', 'en_US', 'en_GB')) {
      if (-not $l) { continue }
      $msgs = Read-Json (Join-Path (Join-Path (Join-Path $Dir '_locales') $l) 'messages.json')
      if ($msgs -isnot [System.Collections.IDictionary]) { continue }
      foreach ($k in @($msgs.Keys)) {
        if ($k -eq $key) { $msg = Get-Val ($msgs[$k]) 'message'; if ($msg) { return (Clean $msg) } }
      }
    }
  }
  if ($name) { return (Clean $name) }
  return $null
}
function Test-ExtOn($s) {
  $state = $s['state']
  if ($null -ne $state -and "$state" -eq '0') { return $false } # older browsers
  if (-not $s.ContainsKey('disable_reasons')) { return $true }   # newer browsers: [] or absent = on
  $dr = $s['disable_reasons']
  if ($null -eq $dr) { return $true }
  if ($dr -is [System.Collections.IEnumerable] -and $dr -isnot [string]) { return (@($dr).Count -eq 0) }
  return ("$dr" -eq '0')
}
function Get-ChromiumProfile([string]$ProfileDir, [string]$Label) {
  $settings = @{}
  foreach ($f in 'Preferences', 'Secure Preferences') {
    $s = Get-Val (Read-Json (Join-Path $ProfileDir $f)) 'extensions', 'settings'
    if ($s -isnot [System.Collections.IDictionary]) { continue }
    foreach ($id in @($s.Keys)) {
      if (-not $settings.ContainsKey($id)) { $settings[$id] = @{} }
      $e = $s[$id]
      if ($e -is [System.Collections.IDictionary]) { foreach ($k in @($e.Keys)) { $settings[$id][$k] = $e[$k] } }
    }
  }
  $exts = New-Object System.Collections.ArrayList
  $builtinAi = New-Object System.Collections.ArrayList
  $seen = @{}
  foreach ($id in @($settings.Keys)) {
    $s = $settings[$id]
    $rel = [string]$s['path']
    $dir = $null
    if ($rel) { if ([System.IO.Path]::IsPathRooted($rel)) { $dir = $rel } else { $dir = Join-Path (Join-Path $ProfileDir 'Extensions') $rel } }
    $name = Get-Val $s 'manifest', 'name'
    if (-not $name -or "$name" -like '__MSG_*') { $n2 = Get-ManifestName $dir; if ($n2) { $name = $n2 } }
    if (-not $name) { continue } # leftover entry for an uninstalled extension
    $name = Clean $name
    if ("$($s['location'])" -eq '5') { if (Test-Match $ReAi $name) { [void]$builtinAi.Add($name) }; continue } # part of the browser
    $seen[$id] = 1
    $note = if ("$($s['location'])" -eq '4') { 'loaded unpacked from ' + $dir } else { '' }
    [void]$exts.Add([pscustomobject]@{ Name = $name; Id = $id; On = (Test-ExtOn $s); Note = $note })
  }
  foreach ($d in @(Get-ChildItem -LiteralPath (Join-Path $ProfileDir 'Extensions') -Directory)) {
    if ($d.Name -cnotmatch '^[a-p]{32}$' -or $seen.ContainsKey($d.Name)) { continue }
    $ver = @(Get-ChildItem -LiteralPath $d.FullName -Directory | Sort-Object Name) | Select-Object -Last 1
    $name = if ($ver) { Get-ManifestName $ver.FullName } else { $null }
    if ($name) { [void]$exts.Add([pscustomobject]@{ Name = $name; Id = $d.Name; On = $null; Note = '' }) }
  }
  return [pscustomobject]@{ Label = $Label; Exts = @($exts); BuiltinAi = @($builtinAi) }
}

$Browsers = New-Object System.Collections.ArrayList
$userData = @(Get-Item -Path (Join-Path $Local '*\User Data'), (Join-Path $Local '*\*\User Data'), (Join-Path $Roam '*\User Data'),
  (Join-Path $Local 'Packages\*\LocalCache\Local\*\User Data'), (Join-Path $Local 'Packages\*\LocalCache\Local\*\*\User Data') -Force)
foreach ($ud in $userData) {
  $base = Split-Path (Split-Path $ud.FullName -Parent) -Leaf
  $vendor = Split-Path $ud.FullName -Parent
  foreach ($prof in @(Get-ChildItem -LiteralPath $ud.FullName -Directory -Force)) {
    if (-not ((Test-Path -LiteralPath (Join-Path $prof.FullName 'Preferences')) -or (Test-Path -LiteralPath (Join-Path $prof.FullName 'Secure Preferences')))) { continue }
    $label = ($vendor.Substring([Math]::Max(0, [Math]::Min($vendor.Length, $Local.Length + 1))) -replace '^Packages[\\/][^\\/]+[\\/]LocalCache[\\/]Local[\\/]', '') + '\' + $prof.Name
    if ($vendor.StartsWith($Roam, [System.StringComparison]::OrdinalIgnoreCase)) { $label = $vendor.Substring($Roam.Length + 1) + '\' + $prof.Name }
    [void]$Browsers.Add((Get-ChromiumProfile $prof.FullName $label))
  }
}
foreach ($op in @(Get-ChildItem -Path (Join-Path $Roam 'Opera Software\*') -Directory -Force)) { # Opera keeps its profile one level up
  if (Test-Path -LiteralPath (Join-Path $op.FullName 'Preferences')) { [void]$Browsers.Add((Get-ChromiumProfile $op.FullName ('Opera Software\' + $op.Name))) }
}
foreach ($f in @(Get-ChildItem -Path (Join-Path $Roam '*\Profiles\*\extensions.json'), (Join-Path $Roam '*\*\Profiles\*\extensions.json') -File -Force)) {
  $exts = New-Object System.Collections.ArrayList # Firefox, Zen, LibreWolf, Waterfox...
  $addons = Get-Val (Read-Json $f.FullName) 'addons' # assign first: wrapping in @() would nest the array
  foreach ($a in $addons) {
    if ((Get-Val $a 'type') -ne 'extension') { continue }
    if ("$(Get-Val $a 'location')" -match '^app-(builtin|system)') { continue }
    $nm = Get-Val $a 'defaultLocale', 'name'
    if (-not $nm) { $nm = Get-Val $a 'id' }
    $on = ([bool](Get-Val $a 'active')) -and -not ([bool](Get-Val $a 'userDisabled'))
    [void]$exts.Add([pscustomobject]@{ Name = (Clean $nm); Id = [string](Get-Val $a 'id'); On = $on; Note = '' })
  }
  $label = $f.DirectoryName.Substring([Math]::Min($f.DirectoryName.Length, $Roam.Length + 1))
  [void]$Browsers.Add([pscustomobject]@{ Label = $label; Exts = @($exts); BuiltinAi = @() })
}

# ---- Code-editor extensions ------------------------------------------------------------------------
$EditorNames = @{ '.vscode' = 'VS Code'; '.vscode-insiders' = 'VS Code Insiders'; '.vscode-oss' = 'VSCodium'; '.cursor' = 'Cursor'; '.windsurf' = 'Windsurf'; '.kiro' = 'Kiro'; '.trae' = 'Trae'; '.antigravity' = 'Antigravity'; '.positron' = 'Positron' }
$Editors = New-Object System.Collections.ArrayList
foreach ($d in @(Get-ChildItem -LiteralPath $UserHome -Directory -Force | Where-Object { $_.Name -like '.*' })) {
  $file = Join-Path (Join-Path $d.FullName 'extensions') 'extensions.json'
  if (-not (Test-Path -LiteralPath $file)) { continue }
  $list = Read-Json $file
  $ids = @(foreach ($e in $list) { Get-Val $e 'identifier', 'id' }) | Where-Object { $_ } | Sort-Object -Unique
  $nm = if ($EditorNames.ContainsKey($d.Name)) { $EditorNames[$d.Name] } else { $d.Name }
  [void]$Editors.Add([pscustomobject]@{ Label = "$nm (~\$($d.Name))"; Short = $nm; Ids = @($ids) })
}
foreach ($ide in @(Get-ChildItem -LiteralPath (Join-Path $Roam 'JetBrains') -Directory)) {
  $ids = @(Get-ChildItem -LiteralPath (Join-Path $ide.FullName 'plugins') -Directory | ForEach-Object { $_.Name } | Sort-Object)
  if ($ids.Count) { [void]$Editors.Add([pscustomobject]@{ Label = "JetBrains $($ide.Name) (plugins)"; Short = "JetBrains $($ide.Name)"; Ids = $ids }) }
}

# ---- Flags -----------------------------------------------------------------------------------------
$FInterview = New-Object System.Collections.ArrayList
$FAi = New-Object System.Collections.ArrayList
$FAiExt = New-Object System.Collections.ArrayList
$FRemote = New-Object System.Collections.ArrayList
function Add-Flag($List, [string]$Label) { if (-not $List.Contains($Label)) { [void]$List.Add($Label) } }
foreach ($g in $GroupList) {
  $hay = @($g.Name, $g.Desc, $g.Company, $g.Path)
  $label = if ($g.Desc) { "$($g.Desc) ($($g.Name))" } else { $g.Name }
  if (Test-Any $ReInterview $hay) { Add-Flag $FInterview $label }
  elseif (Test-Any $ReRemote $hay) { Add-Flag $FRemote $label }
  elseif (Test-Any $ReAi @($g.Name, $g.Desc, $g.Company)) { Add-Flag $FAi $label }
}
foreach ($n in @($NoPathNames.Keys)) {
  if (Test-Match $ReInterview $n) { Add-Flag $FInterview $n }
  elseif (Test-Match $ReRemote $n) { Add-Flag $FRemote $n }
  elseif (Test-Match $ReAi $n) { Add-Flag $FAi $n }
}
if ($IsRemoteSession) { Add-Flag $FRemote 'This session is a Remote Desktop session' }
foreach ($h in $HiddenWindows) { if (Test-Any $ReInterview @($h.Owner, $h.OwnerDesc, $h.Title)) { Add-Flag $FInterview "$($h.Owner) (hidden window)" } }
foreach ($b in $Browsers) {
  foreach ($e in $b.Exts) {
    if (Test-Match $ReInterview $e.Name) { Add-Flag $FInterview ("$($e.Name) [$($b.Label)" + $(if ($e.On -eq $false) { ', disabled]' } else { ']' })) }
    elseif ($e.On -ne $false -and (Test-Match $ReAi $e.Name)) { Add-Flag $FAiExt "$($e.Name) [$($b.Label)]" }
  }
}
foreach ($ed in $Editors) {
  foreach ($id in $ed.Ids) {
    if (Test-Match $ReInterview $id) { Add-Flag $FInterview "$id [$($ed.Short)]" }
    elseif (Test-Match $ReAi $id) { Add-Flag $FAiExt "$id [$($ed.Short)]" }
  }
}
$BadHidden = @($HiddenWindows | Where-Object { -not $_.Usual })

# ---- Report ----------------------------------------------------------------------------------------
function Join-OrNone($a) { if (@($a).Count) { return (@($a) -join ', ') } else { return 'none found' } }
function Mark($bad, $warn) { if ($bad) { return '!! ' } elseif ($warn) { return '!  ' } else { return 'ok ' } }
$hiddenText = if (-not $OnWindows) { 'not checked (not Windows)' } elseif ($HiddenError) { 'CHECK FAILED: ' + $HiddenError } elseif ($HiddenWindows.Count) { (@($HiddenWindows | ForEach-Object { $_.Owner + $(if ($_.Usual) { ' (usually fine)' } else { '' }) }) | Sort-Object -Unique) -join ', ' } else { 'none found' }
$Summary = @(
  (Mark ($BadHidden.Count -or $HiddenError) $HiddenWindows.Count) + 'Windows hidden from screen share : ' + $hiddenText
  (Mark $FInterview.Count 0) + 'Interview-assist tools          : ' + (Join-OrNone $FInterview)
  (Mark 0 $FAi.Count) + 'AI apps / processes running     : ' + (Join-OrNone $FAi)
  (Mark 0 $FAiExt.Count) + 'AI extensions (enabled)         : ' + (Join-OrNone $FAiExt)
  (Mark 0 $FRemote.Count) + 'Remote-access software running  : ' + (Join-OrNone $FRemote)
  (Mark $IsVM 0) + 'Running inside a virtual machine: ' + $(if ($IsVM) { "YES ($Machine)" } else { 'no' })
  (Mark 0 ($Screens.Count -gt 1)) + 'Displays connected              : ' + $Screens.Count + ' (' + ($Screens -join '; ') + ')'
)
$L = New-Object System.Collections.Generic.List[string]
$L.Add('CODEVECTOR INTERVIEW CHECK - Windows'); $L.Add("Code: $Code    Time: $Stamp"); $L.Add("$OsText - $Machine"); $L.Add('')
$L.Add('SUMMARY   (!! = look now - ! = ask about it - ok = nothing found)')
foreach ($s in $Summary) { $L.Add('  ' + $s) }
$L.Add(''); $L.Add('1. WINDOWS HIDDEN FROM SCREEN SHARE')
$L.Add('   Apps can ask Windows to leave a window out of screen shares. Meeting-app share toolbars and')
$L.Add('   password managers sometimes do this; an overlay or unfamiliar app doing it is the red flag.')
if (-not $HiddenWindows.Count) { $L.Add('   ' + $hiddenText) }
foreach ($h in $HiddenWindows) {
  $mode = if ($h.Affinity -eq 17) { 'excluded from capture' } else { "affinity $($h.Affinity)" }
  $L.Add("   $($h.Owner) (pid $($h.Pid))" + $(if ($h.Usual) { '  - usually fine' } else { '  <-- CHECK' }) + "  $($h.OwnerDesc)  $($h.OwnerPath)")
  $L.Add("       window $($h.Width)x$($h.Height), " + $(if ($h.Visible) { 'visible' } else { 'not visible now' }) + ", $mode" + $(if ($h.Title) { ", title: " + (Clean $h.Title) } else { '' }))
}
$L.Add(''); $L.Add('2. APPS WITH OPEN WINDOWS                                             started')
foreach ($g in $WindowApps) { $L.Add('   ' + ("$($g.Name)  $($g.Desc)  $($g.Company)").PadRight(68) + ' ' + (Get-Started $g.Start)) }
$L.Add(''); $L.Add('3. BACKGROUND PROCESSES (not part of Windows; same program grouped)')
foreach ($g in $Background) { $L.Add('   ' + $g.Name + $(if ($g.Count -gt 1) { " (x$($g.Count))" } else { '' }) + "  $($g.Desc)  $($g.Company)  $($g.Path)") }
$L.Add("   + $SystemCount Windows system processes (not listed)")
if ($NoPathNames.Count) { $L.Add('   + could not read the location of (usually Windows services): ' + ((@($NoPathNames.Keys) | Sort-Object) -join ', ')) }
$L.Add(''); $L.Add('4. BROWSER EXTENSIONS   (on / off / ?)')
if (-not $Browsers.Count) { $L.Add('   no browser profiles found') }
foreach ($b in $Browsers) {
  $L.Add('   ' + $b.Label)
  if (-not $b.Exts.Count) { $L.Add('       (no extensions)') }
  foreach ($e in @($b.Exts | Sort-Object @{ Expression = { if ($_.On -eq $true) { 0 } elseif ($null -eq $_.On) { 1 } else { 2 } } }, Name)) {
    $state = if ($e.On -eq $true) { 'on ' } elseif ($e.On -eq $false) { 'off' } else { ' ? ' }
    $tag = if (Test-Match $ReInterview $e.Name) { '  <-- INTERVIEW TOOL' } elseif (Test-Match $ReAi $e.Name) { '  <-- AI' } else { '' }
    $L.Add("     $state $($e.Name)" + $(if ($e.Id) { "  $($e.Id)" } else { '' }) + $(if ($e.Note) { "  ($($e.Note))" } else { '' }) + $tag)
  }
  if ($b.BuiltinAi.Count) { $L.Add('       built into this browser: ' + ($b.BuiltinAi -join ', ')) }
}
$L.Add(''); $L.Add('5. CODE-EDITOR EXTENSIONS / PLUGINS (installed; may be disabled)')
if (-not $Editors.Count) { $L.Add('   none found') }
foreach ($ed in $Editors) {
  $L.Add('   ' + $ed.Label)
  foreach ($id in $ed.Ids) { $L.Add("     $id" + $(if (Test-Match $ReInterview $id) { '  <-- INTERVIEW TOOL' } elseif (Test-Match $ReAi $id) { '  <-- AI' } else { '' })) }
}
$L.Add(''); $L.Add("End of report - code $Code - $Stamp")
$Report = ($L -join "`r`n") + "`r`n"

$Desktop = [Environment]::GetFolderPath('Desktop')
if (-not $Desktop -or -not (Test-Path -LiteralPath $Desktop)) { $Desktop = $UserHome }
$OutFile = Join-Path $Desktop ("interview-check-$Code-" + $Now.ToString('HHmmss') + '.txt')
[System.IO.File]::WriteAllText($OutFile, $Report, [System.Text.Encoding]::UTF8)

Write-Host $Report
Write-Host ('=' * 78)
Write-Host "Saved: $OutFile - send this file to your interviewer."
Write-Host ''
Write-Host "SUMMARY - code $Code - $Stamp"
foreach ($s in $Summary) {
  $color = if ($s.StartsWith('!! ')) { 'Red' } elseif ($s.StartsWith('!  ')) { 'Yellow' } else { 'Green' }
  Write-Host ('  ' + $s) -ForegroundColor $color
}
if ($OnWindows -and -not $NoOpen) { Start-Process explorer.exe -ArgumentList "/select,`"$OutFile`"" }
