# CodeVector interview environment check

Some CodeVector interviews have a closed-book part. Before it, your interviewer may ask you to
share your **entire screen** and run this check. It lists what is running on your computer, so you
can both see that no AI assistant is helping in the background.

## What it looks at

- Windows that apps have asked to keep **out of screen shares**. This is how "invisible" interview
  overlays hide.
- Running apps and processes: names and locations only.
- How many displays are connected, and whether it is running inside a virtual machine.
- Names of installed **browser extensions** (with on/off state) and **code-editor extensions**.

## What it does not do

- It does not change or install anything on your computer.
- It does not read your documents, browsing history, cookies or passwords. From browser settings it
  reads only the extension list.
- It does not send anything anywhere. It saves a plain-text report; you read it, then send it to
  your interviewer yourself.

Please read the code before running it. Each check is a single file:
[`interview-check-mac.js`](interview-check-mac.js) ·
[`interview-check-windows.ps1`](interview-check-windows.ps1)

## How to run

Your interviewer will give you a short code during the call. Put it where it says `CODE`.

**macOS**: open Terminal and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/siddharthshah3030/interview-check/main/interview-check-mac.js | osascript -l JavaScript - CODE
```

**Windows**: open PowerShell (Start menu → type "PowerShell") and paste:

```powershell
[Net.ServicePointManager]::SecurityProtocol='Tls12'; iwr -UseBasicParsing https://raw.githubusercontent.com/siddharthshah3030/interview-check/main/interview-check-windows.ps1 -OutFile $env:TEMP\ivcheck.ps1; powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\ivcheck.ps1 CODE
```

(`-ExecutionPolicy Bypass` applies to this one run only; it does not change your settings.)

It takes a few seconds, prints a summary, and saves the report:

- **macOS**: `interview-check-CODE-<time>.txt` in your home folder (shown in Finder)
- **Windows**: `interview-check-CODE-<time>.txt` on your Desktop (shown in File Explorer)

Send that file to your interviewer.

## Prefer not to run a script, or on Linux?

Tell your interviewer. You can show the same things on screen share instead: Activity Monitor
(Mac), Task Manager → Details (Windows) or System Monitor (Linux), plus your browser's extensions
page (`chrome://extensions`, `edge://extensions` or `about:addons`).

## Requirements

macOS 12 or later, or Windows 10/11 with the built-in Windows PowerShell. Nothing to install.
