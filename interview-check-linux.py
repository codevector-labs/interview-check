#!/usr/bin/env python3
# CodeVector - interview environment check (Linux / Ubuntu)
#
# WHAT IT READS: the list of running apps and processes (names and real binary paths), connected
# displays, whether it is a VM or a remote session, and the names of installed browser and
# code-editor extensions.
# WHAT IT DOES NOT DO: change or install anything, read your documents, browsing history, cookies or
# passwords, or upload anything about you. From browser settings it reads only the extension list.
# It saves a plain-text report in your home folder. Read it, then send it to your interviewer.
#
# NOTE: unlike macOS/Windows, Linux has no per-window "hide from screen capture" flag, so a shared
# screen already shows every window. This check focuses on what IS a signal on Linux: AI / remote
# tools running, and browser / editor extensions.
#
# Run:  curl -fsSL <url> | python3 - <code your interviewer gives you>
#       (add --no-open to skip opening the report's folder)

import os, sys, re, json, glob, subprocess, datetime, pwd

# ---- Watch lists: whole-word, case-insensitive; "interview coder" also matches InterviewCoder ----
INTERVIEW_TOOLS = ['cluely', 'interview coder', 'final round', 'lockedin ai', 'locked in ai',
    'parakeet ai', 'verve ai', 'verve copilot', 'sensei ai', 'sensei copilot', 'leetcode wizard',
    'interview solver', 'pluely', 'cheating daddy', 'interview hammer', 'beyz', 'linkjob',
    'shadecoder', 'interview copilot', 'pickle glass', 'interviews chat', 'ultracode']
AI_TOOLS = ['chatgpt', 'chat gpt', 'openai', 'codex', 'claude', 'anthropic', 'gemini', 'copilot',
    'perplexity', 'comet', 'grok', 'deepseek', 'mistral', 'le chat', 'poe', 'meta ai', 'qwen', 'kimi',
    'cursor', 'windsurf', 'codeium', 'tabnine', 'supermaven', 'cody', 'continue', 'cline', 'roo code',
    'roo cline', 'kilo code', 'amazon q', 'codewhisperer', 'qodo', 'blackbox', 'bito', 'aider',
    'opencode', 'goose', 'kiro', 'trae', 'antigravity', 'pearai', 'augment', 'junie', 'ollama',
    'lm studio', 'gpt4all', 'msty', 'jan ai', 'monica', 'sider', 'maxai', 'harpa', 'aiprm', 'granola',
    'otter ai', 'fireflies', 'tldv', 'fathom', 'notta', 'krisp', 'wispr', 'superwhisper', 'screenpipe',
    'opera neon', 'phind', 'huggingchat', 'chatbox', 'openrouter', 'dia', 'zed']
REMOTE_TOOLS = ['anydesk', 'teamviewer', 'rustdesk', 'parsec', 'splashtop', 'screenconnect',
    'jump desktop', 'realvnc', 'tightvnc', 'tigervnc', 'x11vnc', 'wayvnc', 'vino', 'krfb', 'vinagre',
    'remmina', 'xrdp', 'gnome remote desktop', 'grd', 'chrome remote desktop', 'chromoting', 'logmein',
    'gotomypc', 'zoho assist', 'ultraviewer', 'dwservice', 'remotepc', 'getscreen', 'nomachine',
    'dayon', 'anyviewer']

# Binaries living here are distro/system; counted, not listed (interpreters stay so AI tools show).
SYSTEM_PREFIXES = ('/usr/lib', '/usr/libexec', '/lib', '/lib64', '/sbin', '/usr/sbin',
                   '/snap/snapd', '/snap/core', '/snap/gnome', '/snap/gtk', '/snap/bare')
INTERPRETER = re.compile(r'/(python[\d.]*|ruby|perl[\d.]*|php|node|deno|bun|java|electron)$', re.I)
SHELL_NOISE = re.compile(r'^(bash|zsh|sh|fish|dash|login|systemd|\(sd-pam\)|init)$')


def matcher(words):
    parts = [re.escape(w).replace(r'\ ', r'[\s._-]?') for w in words]
    rx = re.compile(r'(^|[^a-z0-9])(' + '|'.join(parts) + r')(?![a-z0-9])', re.I)

    def split(s):
        s = re.sub(r'([a-z0-9])([A-Z])', r'\1 \2', s)
        return re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1 \2', s)

    def test(s):
        return bool(s) and (rx.search(s) is not None or rx.search(split(s)) is not None)
    return test


is_interview = matcher(INTERVIEW_TOOLS)
is_ai = matcher(AI_TOOLS)
is_remote = matcher(REMOTE_TOOLS)

HOME = os.path.expanduser('~')
BIDI = re.compile('[‎‏‪-‮⁦-⁩]')


def clean(s):
    return BIDI.sub('', str(s if s is not None else '')).strip()


def tilde(p):
    return '~' + p[len(HOME):] if p and p.startswith(HOME) else (p or '')


def read_text(path):
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            return f.read()
    except Exception:
        return None


def read_json(path):
    t = read_text(path)
    if t is None:
        return None
    try:
        return json.loads(t.lstrip('﻿'))
    except Exception:
        return None


def run_cmd(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=12).stdout
    except Exception:
        return ''


def main():
    args = sys.argv[1:]
    no_open = '--no-open' in args
    code = next((a for a in args if not a.startswith('--')), '')
    if not code:
        try:
            code = input('Type the code your interviewer gave you, then press Enter: ')
        except EOFError:
            code = ''
    code = re.sub(r'[^A-Za-z0-9_-]', '', code)[:32] or 'NONE'

    now = datetime.datetime.now().astimezone()
    stamp = now.strftime('%Y-%m-%d %H:%M:%S %z')
    fail = {}
    flags = {'interview': [], 'ai': [], 'aiExt': [], 'remote': [], 'sideload': []}

    def add(key, label):
        if label and label not in flags[key]:
            flags[key].append(label)

    osrel = {}
    for line in (read_text('/etc/os-release') or '').splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            osrel[k] = v.strip().strip('"')
    distro = osrel.get('PRETTY_NAME') or 'Linux'
    kernel = run_cmd(['uname', '-r']).strip()

    # ---- VM / remote session -------------------------------------------------------------------
    virt = run_cmd(['systemd-detect-virt']).strip()
    is_vm = bool(virt) and virt != 'none'
    remote_session = bool(os.environ.get('SSH_CONNECTION') or os.environ.get('SSH_TTY'))
    if remote_session:
        add('remote', 'this shell is a remote SSH session')

    # ---- Processes (real binary via /proc/PID/exe, which argv cannot forge) ---------------------
    proc_groups = {}
    system_count = kernel_count = 0
    try:
        my_pid = os.getpid()
        for pid_s in os.listdir('/proc'):
            if not pid_s.isdigit():
                continue
            pid = int(pid_s)
            if pid == my_pid:
                continue
            comm = (read_text('/proc/%s/comm' % pid_s) or '').strip()
            try:
                exe = os.readlink('/proc/%s/exe' % pid_s)
            except OSError:
                exe = ''  # kernel thread, or not ours to read
            if exe.endswith(' (deleted)'):
                exe = exe[:-10]
            if not exe and not comm:
                continue
            name = comm or os.path.basename(exe)
            if not exe:  # kernel threads have no exe and a [bracketed] comm
                kernel_count += 1
                continue
            is_system = exe.startswith(SYSTEM_PREFIXES) and not INTERPRETER.search(exe)
            if is_system:
                if is_remote(name) or is_remote(exe):
                    add('remote', name)
                system_count += 1
                continue
            if SHELL_NOISE.match(name):
                system_count += 1
                continue
            if is_interview(name) or is_interview(exe):
                add('interview', name + ' (process)')
            elif is_remote(name) or is_remote(exe):
                add('remote', name)
            elif is_ai(name):
                add('ai', name)
            key = tilde(exe)
            proc_groups[key] = proc_groups.get(key, 0) + 1
    except Exception as e:
        fail['proc'] = str(e)

    # ---- Displays (works without X: kernel reports connected outputs) ---------------------------
    screens = []
    try:
        for st in sorted(glob.glob('/sys/class/drm/card*-*/status')):
            if (read_text(st) or '').strip() == 'connected':
                screens.append(os.path.basename(os.path.dirname(st)).split('-', 1)[-1])
        if not screens:  # fall back to xrandr if /sys was unhelpful (e.g. some VMs)
            for ln in run_cmd(['xrandr', '--listmonitors']).splitlines():
                m = re.search(r'\b(\S+)$', ln.strip())
                if ln.strip() and ln[0:1] == ' ' and m:
                    screens.append(m.group(1))
    except Exception as e:
        fail['displays'] = str(e)

    # ---- Browser extensions (Chromium family + Firefox; native, snap, flatpak) -----------------
    def enabled(s):
        if s.get('state') == 0:
            return False
        dr = s.get('disable_reasons')
        if isinstance(dr, list):
            return len(dr) == 0
        if isinstance(dr, (int, float)):
            return dr == 0
        return True

    def manifest_name(d):
        if not d:
            return None
        m = read_json(os.path.join(d, 'manifest.json'))
        if not isinstance(m, dict):
            return None
        name = m.get('name')
        mm = re.match(r'^__MSG_(.+)__$', name or '')
        if mm:
            for loc in [m.get('default_locale'), 'en', 'en_US', 'en_GB']:
                if not loc:
                    continue
                msgs = read_json(os.path.join(d, '_locales', loc, 'messages.json'))
                if isinstance(msgs, dict):
                    for k, v in msgs.items():
                        if k.lower() == mm.group(1).lower() and isinstance(v, dict) and v.get('message'):
                            return clean(v['message'])
        return clean(name) if name else None

    browser_profiles = []
    try:
        chromium_roots = []
        for base in [os.path.join(HOME, '.config'), os.path.join(HOME, '.var/app/*/config')] + \
                     glob.glob(os.path.join(HOME, 'snap/*/*/.config')) + glob.glob(os.path.join(HOME, 'snap/*/common/.config')):
            for pat in ['google-chrome*', 'chromium', 'microsoft-edge*', 'BraveSoftware/Brave-Browser*',
                        'opera*', 'vivaldi', 'Brave-Browser*']:
                chromium_roots += glob.glob(os.path.join(base, pat))
        seen_roots = set()
        for root in chromium_roots:
            if root in seen_roots or not os.path.isdir(root):
                continue
            seen_roots.add(root)
            # Chrome/Chromium keep Preferences in a profile subdir (Default/); Opera keeps it at root.
            for prefs in (glob.glob(os.path.join(root, 'Preferences')) + glob.glob(os.path.join(root, 'Secure Preferences')) +
                          glob.glob(os.path.join(root, '*', 'Preferences')) + glob.glob(os.path.join(root, '*', 'Secure Preferences'))):
                profile = os.path.dirname(prefs)
                label = tilde(profile).replace('/.config/', '/').replace('/.var/app/', 'flatpak:')
                settings = {}
                for f in ('Preferences', 'Secure Preferences'):
                    j = read_json(os.path.join(profile, f))
                    s = (j or {}).get('extensions', {}).get('settings') if isinstance(j, dict) else None
                    if isinstance(s, dict):
                        for i, v in s.items():
                            settings.setdefault(i, {}).update(v if isinstance(v, dict) else {})
                if not settings or any(b['label'] == label for b in browser_profiles):
                    continue
                exts, builtin_ai = [], []
                for i, s in settings.items():
                    path = s.get('path')
                    absolute = bool(path) and path.startswith('/')
                    d = path if absolute else (os.path.join(profile, 'Extensions', path) if path else None)
                    safe = d and (os.path.join(profile, 'Extensions') in d)
                    unpacked = s.get('location') in (4, 8)
                    name = (s.get('manifest') or {}).get('name')
                    if (not name or str(name).startswith('__MSG_')) and safe:
                        name = manifest_name(d) or name
                    if s.get('location') == 5:
                        if name and is_ai(clean(name)):
                            builtin_ai.append(clean(name))
                        continue
                    if not name:
                        if not path:
                            continue
                        name = '(name unreadable)'
                    name = clean(name)
                    note = ('side-loaded from ' + tilde(d)) if unpacked and d else ('side-loaded' if unpacked else '')
                    exts.append({'name': name, 'id': i, 'on': enabled(s), 'note': note})
                    if unpacked and enabled(s):
                        add('sideload', name + ' [' + label + ']')
                browser_profiles.append({'label': label, 'exts': exts, 'builtinAi': builtin_ai})
        # Firefox family
        for ejson in (glob.glob(os.path.join(HOME, '.mozilla/firefox/*/extensions.json')) +
                      glob.glob(os.path.join(HOME, 'snap/firefox/common/.mozilla/firefox/*/extensions.json')) +
                      glob.glob(os.path.join(HOME, '.var/app/org.mozilla.firefox/.mozilla/firefox/*/extensions.json'))):
            j = read_json(ejson)
            builtin = {'app-builtin', 'app-system-defaults', 'app-system-addons'}
            exts = []
            for a in (j or {}).get('addons', []) if isinstance(j, dict) else []:
                if a.get('type') != 'extension' or a.get('location') in builtin:
                    continue
                nm = (a.get('defaultLocale') or {}).get('name') or a.get('id')
                exts.append({'name': clean(nm), 'id': a.get('id', ''),
                             'on': bool(a.get('active')) and not a.get('userDisabled'), 'note': ''})
            browser_profiles.append({'label': tilde(os.path.dirname(ejson)), 'exts': exts, 'builtinAi': []})
    except Exception as e:
        fail['browsers'] = str(e)

    # ---- Code-editor extensions ----------------------------------------------------------------
    EDITORS = {'.vscode': 'VS Code', '.vscode-insiders': 'VS Code Insiders', '.vscode-oss': 'VSCodium',
               '.cursor': 'Cursor', '.windsurf': 'Windsurf', '.kiro': 'Kiro', '.trae': 'Trae',
               '.antigravity': 'Antigravity', '.positron': 'Positron'}
    editors = []
    try:
        for d, short in EDITORS.items():
            f = os.path.join(HOME, d, 'extensions', 'extensions.json')
            lst = read_json(f)
            if isinstance(lst, list):
                ids = sorted({e.get('identifier', {}).get('id') for e in lst if isinstance(e, dict) and e.get('identifier')} - {None})
                if os.path.exists(f):
                    editors.append({'label': '%s (~/%s)' % (short, d), 'short': short, 'ids': ids})
        for jb in glob.glob(os.path.join(HOME, '.local/share/JetBrains/*')):
            ids = sorted(os.path.basename(p) for p in glob.glob(os.path.join(jb, '*')) if os.path.isdir(p))
            if ids:
                editors.append({'label': 'JetBrains %s (plugins)' % os.path.basename(jb), 'short': 'JetBrains ' + os.path.basename(jb), 'ids': ids})
    except Exception as e:
        fail['editors'] = str(e)

    for b in browser_profiles:
        for e in b['exts']:
            if is_interview(e['name']):
                add('interview', e['name'] + ' [' + b['label'] + ('' if e['on'] else ', disabled') + ']')
            elif e['on'] and is_ai(e['name']):
                add('aiExt', e['name'] + ' [' + b['label'] + ']')
    for ed in editors:
        for i in ed['ids']:
            if is_interview(i):
                add('interview', i + ' [' + ed['short'] + ']')
            elif is_ai(i):
                add('aiExt', i + ' [' + ed['short'] + ']')

    # ---- Report --------------------------------------------------------------------------------
    def yn(bad, warn, text):
        return ('!! ' if bad else '!  ' if warn else 'ok ') + text

    def list_of(a):
        return ', '.join(a) if a else 'none found'

    summary = [
        yn(0, 0, 'Windows hidden from screen share : n/a on Linux - a shared screen shows every window'),
        yn(len(flags['interview']), 0, 'Interview-assist tools          : ' + list_of(flags['interview'])),
        yn(fail.get('proc'), len(flags['ai']), 'AI apps / processes running     : ' + ('CHECK FAILED' if fail.get('proc') else list_of(flags['ai']))),
        yn(fail.get('browsers'), len(flags['aiExt']), 'AI extensions (enabled)         : ' + ('CHECK FAILED' if fail.get('browsers') else list_of(flags['aiExt']))),
        yn(0, len(flags['sideload']), 'Side-loaded browser extensions  : ' + list_of(flags['sideload'])),
        yn(0, len(flags['remote']), 'Remote-access software running  : ' + list_of(flags['remote'])),
        yn(is_vm, 0, 'Running inside a virtual machine : ' + (('YES (%s)' % virt) if is_vm else ('no' if virt == 'none' else 'could not check'))),
        yn(fail.get('displays') or len(screens) == 0, len(screens) > 1, 'Displays connected              : ' + ('CHECK FAILED' if fail.get('displays') else '%d (%s)' % (len(screens), ', '.join(screens) or 'none detected'))),
    ]
    L = ['CODEVECTOR INTERVIEW CHECK - Linux', 'Code: %s    Time: %s' % (code, stamp), '%s - kernel %s' % (distro, kernel), '']
    L.append('SUMMARY   (!! = look now - ! = ask about it - ok = nothing found)')
    L += ['  ' + s for s in summary]
    if fail:
        L += ['', 'NOTE: a check failed and could not complete: ' + '; '.join('%s (%s)' % (k, v) for k, v in fail.items())]
    L += ['', '1. HIDDEN-FROM-CAPTURE WINDOWS',
          '   Linux has no per-window "exclude from screen capture" flag (the trick overlay tools use',
          '   on macOS/Windows), so a shared screen shows everything. The real signals here are the',
          '   running AI/remote tools and the browser/editor extensions below.']
    L += ['', '2. INTERVIEW / AI / REMOTE TOOLS RUNNING']
    L.append('   interview-assist : ' + list_of(flags['interview']))
    L.append('   AI               : ' + list_of(flags['ai']))
    L.append('   remote-access    : ' + list_of(flags['remote']))
    L += ['', '3. OTHER RUNNING PROCESSES (grouped by real binary path)']
    if fail.get('proc'):
        L.append('   CHECK FAILED: ' + fail['proc'])
    for k in sorted(proc_groups, key=str.lower):
        L.append('   ' + k + ('  (x%d)' % proc_groups[k] if proc_groups[k] > 1 else ''))
    if not fail.get('proc'):
        L.append('   + %d distro/system processes and %d kernel threads (not listed)' % (system_count, kernel_count))
    L += ['', '4. BROWSER EXTENSIONS   (on / off / ?)']
    if fail.get('browsers'):
        L.append('   CHECK FAILED: ' + fail['browsers'])
    elif not browser_profiles:
        L.append('   no browser profiles found')
    for b in browser_profiles:
        L.append('   ' + b['label'])
        if not b['exts']:
            L.append('       (no extensions)')
        for e in sorted(b['exts'], key=lambda x: (x['on'] is not True, x['name'].lower())):
            tag = '  <-- INTERVIEW TOOL' if is_interview(e['name']) else '  <-- AI' if is_ai(e['name']) else '  <-- SIDE-LOADED' if e['note'] else ''
            state = 'on ' if e['on'] is True else 'off' if e['on'] is False else ' ? '
            L.append('     %s %s%s%s%s' % (state, e['name'], '  ' + e['id'] if e['id'] else '', '  (%s)' % e['note'] if e['note'] else '', tag))
        if b['builtinAi']:
            L.append('       built into this browser: ' + ', '.join(b['builtinAi']))
    L += ['', '5. CODE-EDITOR EXTENSIONS / PLUGINS (installed; may be disabled)']
    if fail.get('editors'):
        L.append('   CHECK FAILED: ' + fail['editors'])
    elif not editors:
        L.append('   none found')
    for ed in editors:
        L.append('   ' + ed['label'])
        for i in ed['ids']:
            L.append('     ' + i + ('  <-- INTERVIEW TOOL' if is_interview(i) else '  <-- AI' if is_ai(i) else ''))
    L += ['', 'End of report - code %s - %s' % (code, stamp)]
    report = '\n'.join(L) + '\n'

    outfile = os.path.join(HOME, 'interview-check-%s-%s.txt' % (code, now.strftime('%H%M%S')))
    saved = True
    try:
        with open(outfile, 'w', encoding='utf-8') as f:
            f.write(report)
    except Exception:
        saved = False
    if saved and not no_open:
        try:
            subprocess.Popen(['xdg-open', os.path.dirname(outfile)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    def color(s):
        c = '\033[1;31m' if s.startswith('!! ') else '\033[33m' if s.startswith('!  ') else '\033[32m'
        return c + s + '\033[0m'

    tail = ('\nSaved: ' + tilde(outfile) + ' - send this file to your interviewer.') if saved else \
           '\nCOULD NOT SAVE the report - copy the text above and send it to your interviewer.'
    sys.stdout.write(report + '\n' + '=' * 78 + tail + '\n\nSUMMARY - code %s - %s\n' % (code, stamp) +
                     '\n'.join('  ' + color(s) for s in summary) + '\n')


if __name__ == '__main__':
    main()
