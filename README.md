# CodeVector interview environment check

Some CodeVector interviews have a closed-book part. Before it, your interviewer may ask you to
share your **entire screen** and run this check. It lists what is running on your computer, so you
can both see that no AI assistant is helping in the background.

## What it looks at

- Windows that apps have asked to keep **out of screen shares**. This is how "invisible" interview
  overlays hide. For any it finds, it asks your OS who signed that app — a normal signed app (your
  meeting app's share bar, a password manager) is shown as a "glance", an unsigned/unknown one as a
  flag.
- Running apps and processes: names, and file locations for programs it can verify.
- How many displays are connected, and whether it is running inside a virtual machine.
- Names of installed **browser extensions** (with on/off state) and **code-editor extensions**.

## What it does not do

- It does not change or install anything on your computer.
- It does not read your documents, browsing history, cookies or passwords. From browser settings it
  reads only the extension list.
- It does not upload your files, your activity, or anything about you. It saves a plain-text report;
  you read it, then send it to your interviewer yourself. (On Windows, to confirm who signed a
  hidden window's app, it asks Windows to check that app's signature — the same thing Windows does
  whenever you open a program. No personal data leaves your machine.)

Please read the code before running it. Each check is a single file:
[`interview-check-mac.js`](interview-check-mac.js) ·
[`interview-check-windows.ps1`](interview-check-windows.ps1) ·
[`interview-check-linux.py`](interview-check-linux.py)

## How to run

Your interviewer will give you a short code during the call. Put it where it says `CODE`.

**macOS**: open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/codevector-labs/interview-check/main/interview-check-mac.js | osascript -l JavaScript - CODE
```

**Windows**: open PowerShell (Start menu → type "PowerShell") and paste:

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; iwr -UseBasicParsing https://raw.githubusercontent.com/codevector-labs/interview-check/main/interview-check-windows.ps1 -OutFile $env:TEMP\ivcheck.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\ivcheck.ps1 CODE
```

(`-ExecutionPolicy Bypass` applies to this one run only; it does not change your settings.)

**Linux / Ubuntu**: open a terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/codevector-labs/interview-check/main/interview-check-linux.py | python3 - CODE
```

(On Linux there's no per-window "hide from screen capture" flag, so a shared screen already shows
every window — the check focuses on running AI/remote tools and your extensions.)

It takes a few seconds, prints a summary, and saves the report:

- **macOS**: `interview-check-CODE-<time>.txt` in your home folder (shown in Finder)
- **Windows**: `interview-check-CODE-<time>.txt` on your Desktop (shown in File Explorer)
- **Linux**: `interview-check-CODE-<time>.txt` in your home folder

Send that file to your interviewer.

## Prefer not to run a script?

Tell your interviewer. You can show the same things on screen share instead: Activity Monitor
(Mac), Task Manager → Details (Windows) or System Monitor (Linux), plus your browser's extensions
page (`chrome://extensions`, `edge://extensions` or `about:addons`).

## Requirements

macOS 12+ (built-in `osascript`), Windows 10/11 (built-in Windows PowerShell), or Ubuntu/Linux with
`python3` (ships by default). Nothing to install.
