# CodeVector - interview environment check (Windows)
#
# WHAT IT READS: windows that apps have hidden from screen sharing, the list of running apps and
# processes (names and file locations), connected displays, and the names of installed browser and
# code-editor extensions.
# WHAT IT DOES NOT DO: change or install anything, read your documents, browsing history, cookies or
# passwords, or upload anything about you. From browser settings it reads only the extension list.
# (To confirm who signed a hidden window's app it asks Windows to verify that app's signature, the
# same check Windows does whenever you launch a program.)
# It saves a plain-text report on your Desktop. Read it, then send it to your interviewer.
#
# Run in PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\interview-check-windows.ps1 <code>
#   (add --no-open to skip opening Explorer at the report)

$ErrorActionPreference = 'SilentlyContinue'

# ---- Watch lists: whole-word, case-insensitive; "interview coder" also matches InterviewCoder ----
# Sold specifically for getting AI help during live interviews. Any match is a red flag.
$InterviewTools = @('cluely', 'interview coder', 'final round', 'lockedin ai', 'locked in ai',
  'parakeet ai', 'verve ai', 'verve copilot', 'sensei ai', 'sensei copilot', 'leetcode wizard',
  'interview solver', 'pluely', 'cheating daddy', 'interview hammer', 'beyz', 'linkjob', 'shadecoder',
  'interview copilot', 'pickle glass', 'interviews chat', 'ultracode')
# General AI assistants and AI coding tools: fine to own, not fine to have open in a closed-book round.
$AiTools = @('chatgpt', 'chat gpt', 'openai', 'codex', 'claude', 'anthropic', 'gemini', 'copilot',
  'perplexity', 'comet', 'grok', 'deepseek', 'mistral', 'le chat', 'poe', 'meta ai', 'qwen', 'kimi',
  'cursor', 'windsurf', 'codeium', 'tabnine', 'supermaven', 'cody', 'continue', 'cline', 'roo code',
  'roo cline', 'kilo code', 'amazon q', 'codewhisperer', 'qodo', 'blackbox', 'bito', 'aider', 'opencode',
  'goose', 'kiro', 'trae', 'antigravity', 'pearai', 'augment', 'junie', 'ollama', 'lm studio', 'gpt4all',
  'msty', 'jan ai', 'monica', 'sider', 'maxai', 'harpa', 'aiprm', 'granola', 'otter ai', 'fireflies',
  'tldv', 'fathom', 'notta', 'krisp', 'wispr', 'superwhisper', 'screenpipe', 'opera neon', 'phind',
  'huggingchat', 'chatbox', 'openrouter', 'dia', 'zed')
# Lets someone else see or control this computer.
$RemoteTools = @('anydesk', 'teamviewer', 'rustdesk', 'parsec', 'splashtop', 'screenconnect',
  'jump desktop', 'realvnc', 'vncserver', 'vncviewer', 'tightvnc', 'tvnserver', 'tigervnc', 'ultravnc',
  'winvnc', 'chrome remote desktop', 'remoting host', 'chromoting', 'logmein', 'gotomypc', 'goto resolve',
  'zoho assist', 'ultraviewer', 'supremo', 'ammyy', 'aeroadmin', 'dwservice', 'remotepc', 'getscreen',
  'nomachine', 'quick assist', 'quickassist', 'msra', 'mstsc', 'msrdc', 'rdpclip')

function New-Matcher([string[]]$Words) {
  $parts = foreach ($w in $Words) { [regex]::Escape($w).Replace('\ ', '[\s._-]?') }
  return [regex]::new('(^|[^a-z0-9])(' + ($parts -join '|') + ')(?![a-z0-9])', ([System.Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'))
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
    $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite,Delete')
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
function Hide-Home([string]$p) { if ($p -and $UserHome -and $p.StartsWith($UserHome, [System.StringComparison]::OrdinalIgnoreCase)) { return '~' + $p.Substring($UserHome.Length) } return $p }
# Real Windows folder (not the spoofable $env:windir). Only System32 / SysWOW64 / WinSxS are exempted.
$SysRoot = [Environment]::GetFolderPath('Windows')
if (-not $SysRoot) { $SysRoot = if ($env:windir) { $env:windir } else { 'C:\Windows' } }
# Built by string join, not Join-Path, so the security-critical check never depends on a PSDrive.
$SysDirs = @('System32', 'SysWOW64', 'WinSxS') | ForEach-Object { $SysRoot.TrimEnd('\', '/') + '\' + $_ }
function Test-SystemPath([string]$p) { if (-not $p) { return $false }; foreach ($d in $SysDirs) { if ($p.StartsWith($d, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } } return $false }

$OsText = ''; $Machine = ''; $IsVM = $false; $IsRemoteSession = $false; $VmChecked = $false
if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
  $os = Get-CimInstance Win32_OperatingSystem
  $cs = Get-CimInstance Win32_ComputerSystem
  if ($os) { $OsText = "$($os.Caption) $($os.Version)" }
  if ($cs) { $Machine = "$($cs.Manufacturer) $($cs.Model)"; $VmChecked = $true; $IsVM = $Machine -match 'virtual|vmware|virtualbox|innotek|kvm|qemu|xen|parallels|bochs' }
}
if (-not $OsText) { $OsText = [System.Environment]::OSVersion.VersionString }

# ---- Signature identity (used to judge who really owns a hidden window) -----------------------------
# Get-AuthenticodeSignature verifies the file hash against the embedded certificate, so a renamed or
# relocated tool cannot borrow a trusted name. Status 'Valid' means Windows trusts the signature.
$SigCache = @{}
function Get-SignerInfo([string]$Path) {
  if (-not $Path) { return @{ Valid = $false; Vendor = ''; Microsoft = $false } }
  if ($SigCache.ContainsKey($Path)) { return $SigCache[$Path] }
  $res = @{ Valid = $false; Vendor = ''; Microsoft = $false }
  try {
    $sig = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    $res.Valid = ($sig.Status -eq 'Valid')
    if ($sig.SignerCertificate) {
      $subj = [string]$sig.SignerCertificate.Subject
      $o = ($subj -split ',(?=\s*[A-Za-z]+=)' | Where-Object { $_.Trim() -like 'O=*' } | Select-Object -First 1)
      $res.Vendor = if ($o) { ($o.Trim() -replace '^O=', '').Trim('"', ' ') } else { $subj }
      $res.Microsoft = $res.Valid -and ($res.Vendor -match 'Microsoft')
    }
  } catch { }
  $SigCache[$Path] = $res
  return $res
}

# ---- Windows that apps have hidden from screen sharing / recording ---------------------------------
# Overlay "interview copilots" call SetWindowDisplayAffinity so the interviewer cannot see them.
# Self-test: we create our own hidden window and confirm we can see it; if not, the check is
# unreliable and the report says so loudly instead of a false "none".
$HiddenRaw = @()
$HiddenError = ''
$SelfTestOk = $false
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
    [DllImport("user32.dll")] public static extern bool SetWindowDisplayAffinity(IntPtr h, uint a);
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
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $canary = New-Object System.Windows.Forms.Form
    $canary.ShowInTaskbar = $false; $canary.Opacity = 0; $canary.Width = 8; $canary.Height = 8; $canary.Left = -32000; $canary.Top = -32000
    $ch = $canary.Handle                     # forces the window to be created
    [void][IvCheck.Win]::SetWindowDisplayAffinity($ch, 1)
    $all = @([IvCheck.Win]::Find())
    $SelfTestOk = [bool]($all | Where-Object { $_.Pid -eq $PID })
    $canary.Dispose()
    if (-not $SelfTestOk) { throw 'self-test window was not detected' }
    $HiddenRaw = @($all | Where-Object { $_.Pid -ne $PID })
  } catch { $HiddenError = $_.Exception.Message }
}

# ---- Processes -------------------------------------------------------------------------------------
$GP = @{}
foreach ($p in Get-Process) { $GP[[int]$p.Id] = $p }
$Procs = @()
$ProcError = ''
if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
  $cim = @(Get-CimInstance Win32_Process)
  $Procs = foreach ($w in $cim) {
    $p = $GP[[int]$w.ProcessId]
    [pscustomobject]@{ Id = [int]$w.ProcessId; Name = [string]$w.Name; Path = [string]$w.ExecutablePath; Window = [bool]($p -and $p.MainWindowHandle -ne 0); Start = $w.CreationDate }
  }
}
if (-not $Procs.Count) {
  $Procs = foreach ($p in $GP.Values) {
    [pscustomobject]@{ Id = [int]$p.Id; Name = [string]$p.ProcessName; Path = [string]$p.Path; Window = [bool]($p.MainWindowHandle -ne 0); Start = $p.StartTime }
  }
}
if (-not $Procs.Count) { $ProcError = 'could not list running processes' }

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

# ---- Flags (filled as we walk processes, windows, extensions) --------------------------------------
$FInterview = New-Object System.Collections.ArrayList
$FAi = New-Object System.Collections.ArrayList
$FAiExt = New-Object System.Collections.ArrayList
$FRemote = New-Object System.Collections.ArrayList
$FSideload = New-Object System.Collections.ArrayList
function Add-Flag($List, [string]$Label) { if ($Label -and -not $List.Contains($Label)) { [void]$List.Add($Label) } }

$MyPid = $PID
$SystemCount = 0
$NoPathNames = @{}
$Groups = @{}
foreach ($p in $Procs) {
  if ($p.Id -eq $MyPid -or $p.Id -le 4) { continue }
  $nm = $p.Name; $path = $p.Path
  $vi = Get-FileInfo $path
  $desc = Clean $(if ($vi) { $vi.FileDescription } else { '' })
  $company = Clean $(if ($vi) { $vi.CompanyName } else { '' })
  $label = if ($desc) { "$desc ($nm)" } else { $nm }
  # Windows system processes are only checked for remote-control tools (Remote Desktop / Quick
  # Assist / msra / rdpclip live in System32), never AI, so a CamelCase system name cannot misfire.
  if ($path -and (Test-SystemPath $path)) {
    if (Test-Any $ReRemote (@($nm, $desc, $company, $path) | Where-Object { $_ })) { Add-Flag $FRemote $label }
    $SystemCount++; continue
  }
  $hay = @($nm, $desc, $company, $path) | Where-Object { $_ }
  if (Test-Any $ReInterview $hay) { Add-Flag $FInterview $label }
  elseif (Test-Any $ReRemote $hay) { Add-Flag $FRemote $label }
  elseif (Test-Any $ReAi @($nm, $desc, $company)) { Add-Flag $FAi $label }
  if (-not $path) { $NoPathNames[$nm] = 1; continue }
  $key = $path.ToLowerInvariant()
  if (-not $Groups.ContainsKey($key)) {
    $Groups[$key] = [pscustomobject]@{ Name = $nm; Path = $path; Count = 0; Desc = $desc; Company = $company; Window = $false; Start = $null }
  }
  $g = $Groups[$key]
  $g.Count++
  if ($p.Window) { $g.Window = $true }
  if ($p.Start -is [datetime] -and (($null -eq $g.Start) -or ($p.Start -lt $g.Start))) { $g.Start = $p.Start }
}
$GroupList = @($Groups.Values | Sort-Object Name)
$WindowApps = @($GroupList | Where-Object { $_.Window })
$Background = @($GroupList | Where-Object { -not $_.Window })

# ---- Resolve each hidden window's real owner and trust tier ----------------------------------------
$PidToProc = @{}
foreach ($p in $Procs) { if (-not $PidToProc.ContainsKey($p.Id)) { $PidToProc[$p.Id] = $p } }
$Hidden = @(foreach ($h in $HiddenRaw) {
    $p = $PidToProc[[int]$h.Pid]
    $owner = if ($p -and $p.Name) { $p.Name } else { "pid $($h.Pid)" }
    $ownerPath = if ($p) { [string]$p.Path } else { '' }
    $vi = Get-FileInfo $ownerPath
    $desc = Clean $(if ($vi) { $vi.FileDescription } else { '' })
    $si = Get-SignerInfo $ownerPath
    $watch = @($owner, $desc, $si.Vendor, $ownerPath) | Where-Object { $_ }
    $tier = 'bad'; $why = 'unsigned / unverified'
    if (Test-Any $ReInterview $watch) { $tier = 'bad'; $why = 'interview tool'; Add-Flag $FInterview "$owner (hidden window)" }
    elseif (Test-Any $ReAi @($owner, $desc, $si.Vendor)) { $tier = 'bad'; $why = 'AI tool' }
    elseif ($si.Microsoft -and (Test-SystemPath $ownerPath)) { $tier = 'ok'; $why = 'Windows system component' }
    elseif ($si.Valid) { $tier = 'warn'; $why = 'signed: ' + $si.Vendor }
    [pscustomobject]@{ Pid = [int]$h.Pid; Affinity = [int]$h.Affinity; Visible = [bool]$h.Visible; Title = [string]$h.Title
      Width = [int]$h.Width; Height = [int]$h.Height; Owner = $owner; OwnerDesc = $desc; OwnerPath = $ownerPath; Tier = $tier; Why = $why }
  })

# ---- Displays and remote sessions ------------------------------------------------------------------
$Screens = @()
$DisplayError = ''
try {
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
  $IsRemoteSession = [System.Windows.Forms.SystemInformation]::TerminalServerSession
  $Screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
      $_.DeviceName.TrimStart('\', '.') + ' ' + $_.Bounds.Width + 'x' + $_.Bounds.Height + $(if ($_.Primary) { ' (main)' } else { '' }) })
} catch { $DisplayError = $_.Exception.Message }
if ($IsRemoteSession) { Add-Flag $FRemote 'This session is a Remote Desktop session' }

# ---- Browser extensions ----------------------------------------------------------------------------
$Local = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $UserHome 'AppData/Local' }
$Roam = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $UserHome 'AppData/Roaming' }
$FfBuiltin = @{ 'app-builtin' = 1; 'app-system-defaults' = 1; 'app-system-addons' = 1 }

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
    $loc = "$($s['location'])"
    $unpacked = ($loc -eq '4') -or ($loc -eq '8')   # "Load unpacked" (dev mode) or --load-extension
    $name = Get-Val $s 'manifest', 'name'
    if (-not $name -or "$name" -like '__MSG_*') { $n2 = Get-ManifestName $dir; if ($n2) { $name = $n2 } }
    if ($loc -eq '5') { if ($name -and (Test-Match $ReAi (Clean $name))) { [void]$builtinAi.Add((Clean $name)) }; continue } # part of the browser
    if (-not $name) { if (-not $rel) { continue }; $name = '(name unreadable)' } # keep installed entries; never drop
    $name = Clean $name
    $seen[$id] = 1
    $note = if ($unpacked) { 'side-loaded from ' + (Hide-Home $dir) } else { '' }
    [void]$exts.Add([pscustomobject]@{ Name = $name; Id = $id; On = (Test-ExtOn $s); Note = $note })
    if ($unpacked -and (Test-ExtOn $s)) { Add-Flag $FSideload "$name [$Label]" }
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
$BrowserError = ''
try {
  $userData = @(Get-Item -Path (Join-Path $Local '*\User Data'), (Join-Path $Local '*\*\User Data'), (Join-Path $Roam '*\User Data'),
    (Join-Path $Local 'Packages\*\LocalCache\Local\*\User Data'), (Join-Path $Local 'Packages\*\LocalCache\Local\*\*\User Data') -Force)
  foreach ($ud in $userData) {
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
      if ($FfBuiltin.ContainsKey("$(Get-Val $a 'location')")) { continue }
      $nm = Get-Val $a 'defaultLocale', 'name'
      if (-not $nm) { $nm = Get-Val $a 'id' }
      $on = ([bool](Get-Val $a 'active')) -and -not ([bool](Get-Val $a 'userDisabled'))
      [void]$exts.Add([pscustomobject]@{ Name = (Clean $nm); Id = [string](Get-Val $a 'id'); On = $on; Note = '' })
    }
    $label = $f.DirectoryName.Substring([Math]::Min($f.DirectoryName.Length, $Roam.Length + 1))
    [void]$Browsers.Add([pscustomobject]@{ Label = $label; Exts = @($exts); BuiltinAi = @() })
  }
} catch { $BrowserError = $_.Exception.Message }

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

# ---- Report ----------------------------------------------------------------------------------------
$BadHidden = @($Hidden | Where-Object { $_.Tier -eq 'bad' })
$WarnHidden = @($Hidden | Where-Object { $_.Tier -eq 'warn' })
function Join-OrNone($a) { if (@($a).Count) { return (@($a) -join ', ') } else { return 'none found' } }
function Mark($bad, $warn) { if ($bad) { return '!! ' } elseif ($warn) { return '!  ' } else { return 'ok ' } }
if (-not $OnWindows) { $hiddenText = 'NOT CHECKED - run this on the Windows machine being interviewed'; $hiddenBad = $true; $hiddenWarn = $false }
elseif ($HiddenError) { $hiddenText = 'CHECK FAILED (' + $HiddenError + ') - do not trust this as clear'; $hiddenBad = $true; $hiddenWarn = $false }
elseif ($Hidden.Count) {
  $hiddenText = (@($Hidden | ForEach-Object { $_.Owner + $(if ($_.Tier -eq 'ok') { '' } elseif ($_.Tier -eq 'warn') { ' (' + $_.Why + ')' } else { ' <-- CHECK' }) }) | Select-Object -Unique) -join ', '
  $hiddenBad = [bool]$BadHidden.Count; $hiddenWarn = [bool]$WarnHidden.Count
}
else { $hiddenText = 'none (self-test passed: the detector is working)'; $hiddenBad = $false; $hiddenWarn = $false }

$Summary = @(
  (Mark $hiddenBad $hiddenWarn) + 'Windows hidden from screen share : ' + $hiddenText
  (Mark $FInterview.Count 0) + 'Interview-assist tools          : ' + (Join-OrNone $FInterview)
  (Mark 0 $FAi.Count) + 'AI apps / processes running     : ' + $(if ($ProcError) { 'CHECK FAILED' } else { Join-OrNone $FAi })
  (Mark 0 $FAiExt.Count) + 'AI extensions (enabled)         : ' + $(if ($BrowserError) { 'CHECK FAILED' } else { Join-OrNone $FAiExt })
  (Mark 0 $FSideload.Count) + 'Side-loaded browser extensions  : ' + (Join-OrNone $FSideload)
  (Mark 0 $FRemote.Count) + 'Remote-access software running  : ' + (Join-OrNone $FRemote)
  (Mark $IsVM 0) + 'Running inside a virtual machine : ' + $(if (-not $VmChecked) { 'could not check' } elseif ($IsVM) { "YES ($Machine)" } else { 'no' })
  (Mark ($DisplayError -or $Screens.Count -eq 0) ($Screens.Count -gt 1)) + 'Displays connected              : ' + $(if ($DisplayError -or $Screens.Count -eq 0) { 'CHECK FAILED' } else { "$($Screens.Count) (" + ($Screens -join '; ') + ')' })
)
$L = New-Object System.Collections.Generic.List[string]
$L.Add('CODEVECTOR INTERVIEW CHECK - Windows'); $L.Add("Code: $Code    Time: $Stamp"); $L.Add("$OsText - $Machine"); $L.Add('')
$L.Add('SUMMARY   (!! = look now - ! = ask about it - ok = nothing found)')
foreach ($s in $Summary) { $L.Add('  ' + $s) }
$L.Add(''); $L.Add('1. WINDOWS HIDDEN FROM SCREEN SHARE')
$L.Add('   Apps can ask Windows to leave a window out of screen shares. A verified Windows component')
$L.Add('   or a signed, recognised app doing it is usually benign; an unsigned or unknown one is the flag.')
if (-not $Hidden.Count) { $L.Add('   ' + $hiddenText) }
foreach ($h in $Hidden) {
  $mode = if ($h.Affinity -eq 17) { 'excluded from capture' } elseif ($h.Affinity -eq 1) { 'hidden from capture (monitor)' } else { "affinity $($h.Affinity)" }
  $mark = if ($h.Tier -eq 'ok') { '  - ' + $h.Why } elseif ($h.Tier -eq 'warn') { '  - ' + $h.Why + '  <-- glance' } else { '  <-- CHECK (' + $h.Why + ')' }
  $L.Add("   $($h.Owner) (pid $($h.Pid))" + $mark + "  $($h.OwnerDesc)  " + (Hide-Home $h.OwnerPath))
  $L.Add("       window $($h.Width)x$($h.Height), " + $(if ($h.Visible) { 'visible' } else { 'not visible now' }) + ", $mode" + $(if ($h.Title) { ", title: " + (Clean $h.Title) } else { '' }))
}
$L.Add(''); $L.Add('2. APPS WITH OPEN WINDOWS                                             started')
if ($ProcError) { $L.Add('   CHECK FAILED: ' + $ProcError) }
foreach ($g in $WindowApps) { $L.Add('   ' + ("$($g.Name)  $($g.Desc)  $($g.Company)").PadRight(68) + ' ' + (Get-Started $g.Start)) }
$L.Add(''); $L.Add('3. BACKGROUND PROCESSES (not part of Windows; same program grouped)')
foreach ($g in $Background) { $L.Add('   ' + $g.Name + $(if ($g.Count -gt 1) { " (x$($g.Count))" } else { '' }) + "  $($g.Desc)  $($g.Company)  " + (Hide-Home $g.Path)) }
$L.Add("   + $SystemCount Windows system processes (not listed)")
if ($NoPathNames.Count) { $L.Add('   + could not read the location of (usually Windows services): ' + ((@($NoPathNames.Keys) | Sort-Object) -join ', ')) }
$L.Add(''); $L.Add('4. BROWSER EXTENSIONS   (on / off / ?)')
if ($BrowserError) { $L.Add('   CHECK FAILED: ' + $BrowserError) }
elseif (-not $Browsers.Count) { $L.Add('   no browser profiles found') }
foreach ($b in $Browsers) {
  $L.Add('   ' + $b.Label)
  if (-not $b.Exts.Count) { $L.Add('       (no extensions)') }
  foreach ($e in @($b.Exts | Sort-Object @{ Expression = { if ($_.On -eq $true) { 0 } elseif ($null -eq $_.On) { 1 } else { 2 } } }, Name)) {
    $state = if ($e.On -eq $true) { 'on ' } elseif ($e.On -eq $false) { 'off' } else { ' ? ' }
    $tag = if (Test-Match $ReInterview $e.Name) { '  <-- INTERVIEW TOOL' } elseif (Test-Match $ReAi $e.Name) { '  <-- AI' } elseif ($e.Note) { '  <-- SIDE-LOADED' } else { '' }
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
$Saved = $false
try { [System.IO.File]::WriteAllText($OutFile, $Report, (New-Object System.Text.UTF8Encoding $false)); $Saved = $true } catch { }

Write-Host $Report
Write-Host ('=' * 78)
if ($Saved) { Write-Host "Saved: $OutFile - send this file to your interviewer." }
else { Write-Host 'COULD NOT SAVE the report - copy the text above and send it to your interviewer.' }
Write-Host ''
Write-Host "SUMMARY - code $Code - $Stamp"
foreach ($s in $Summary) {
  $color = if ($s.StartsWith('!! ')) { 'Red' } elseif ($s.StartsWith('!  ')) { 'Yellow' } else { 'Green' }
  Write-Host ('  ' + $s) -ForegroundColor $color
}
if ($OnWindows -and $Saved -and -not $NoOpen) { Start-Process explorer.exe -ArgumentList "/select,`"$OutFile`"" }
