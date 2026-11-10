// CodeVector · interview environment check (macOS)
//
// WHAT IT READS: windows that are hidden from screen sharing, running apps and processes,
// connected displays, and the names of installed browser and code-editor extensions.
// WHAT IT DOES NOT DO: change anything, read your documents, browsing history or passwords, or send
// anything anywhere (from browser settings it reads only the extension list).
// It saves a plain-text report in your home folder. Read it, then send it yourself.
//
// Run:  osascript -l JavaScript interview-check-mac.js <code your interviewer gives you>
//       (add --no-open to skip revealing the report in Finder)

ObjC.import('Foundation');
ObjC.import('AppKit');
ObjC.import('CoreGraphics');

// ---- Watch lists: whole-word, case-insensitive; "interview coder" also matches InterviewCoder --
// Sold specifically for getting AI help during live interviews. Any match is a red flag.
const INTERVIEW_TOOLS = ['cluely', 'interview coder', 'final round', 'lockedin', 'locked in',
  'parakeet', 'verve ai', 'verve copilot', 'sensei ai', 'sensei copilot', 'leetcode wizard',
  'interview solver', 'pluely', 'cheating daddy', 'interview hammer', 'beyz', 'linkjob',
  'shadecoder', 'interview copilot', 'pickle glass', 'interviews chat'];
// General AI assistants and AI coding tools: fine to own, not fine to have open in a closed-book round.
const AI_TOOLS = ['chatgpt', 'chat gpt', 'openai', 'codex', 'claude', 'anthropic', 'gemini',
  'copilot', 'perplexity', 'comet', 'grok', 'deepseek', 'mistral', 'le chat', 'poe', 'meta ai',
  'qwen', 'kimi', 'cursor', 'windsurf', 'codeium', 'tabnine', 'supermaven', 'cody', 'continue',
  'cline', 'roo code', 'roo cline', 'kilo code', 'amazon q', 'codewhisperer', 'qodo', 'blackbox',
  'bito', 'aider', 'opencode', 'goose', 'kiro', 'trae', 'antigravity', 'zed', 'warp', 'pearai',
  'ml-llm', 'junie', 'ollama', 'lm studio', 'gpt4all', 'msty', 'jan ai', 'monica', 'sider',
  'maxai', 'harpa', 'aiprm', 'granola', 'otter', 'fireflies', 'tldv', 'fathom', 'notta', 'krisp',
  'wispr', 'superwhisper', 'macwhisper', 'whisper', 'raycast', 'highlight', 'rewind', 'limitless',
  'screenpipe', 'dia', 'opera neon', 'phind', 'huggingchat', 'gpt', 'llm', 'ai'];
// Lets someone else see or control this computer.
const REMOTE_TOOLS = ['anydesk', 'teamviewer', 'rustdesk', 'parsec', 'splashtop', 'screenconnect',
  'jump desktop', 'realvnc', 'vnc', 'tightvnc', 'tigervnc', 'chrome remote desktop', 'remoting host',
  'chromoting', 'logmein', 'gotomypc', 'goto resolve', 'zoho assist', 'ultraviewer', 'supremo',
  'ammyy', 'aeroadmin', 'dwservice', 'remotepc', 'getscreen', 'nomachine', 'microsoft remote desktop',
  'windows app', 'screensharingd', 'ardagent'];
// Owners whose hidden windows are normally harmless (meeting-app share toolbars, password managers).
// Matched against the whole app name, so "Researcher" does not pass as "Arc".
const USUAL_HIDERS = /^(zoom\.us|zoom|microsoft teams|msteams|teams|webex|cisco webex meetings|slack|discord|skype|google chrome|microsoft edge|arc|brave browser|firefox|safari|opera|vivaldi|1password( \d+)?|bitwarden|keepassxc|dashlane|lastpass|signal)$/i;

// Apple system locations. Processes here are counted, not listed (interpreters are still listed).
const APPLE_PATH = /^\/(System|usr\/(libexec|sbin|bin)|bin|sbin|Library\/Apple|Library\/Developer)\//;
const INTERPRETER = /\/(python[\d.]*|ruby|perl[\d.]*|php|java|swift|osascript)$/;
const SHELL_NOISE = /^-?(zsh|bash|sh|fish|login|automountd|autofsd)$/;

function matcher(words) {
  const parts = words.map(w => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/ /g, '[\\s._-]?'));
  const re = new RegExp('(^|[^a-z0-9])(' + parts.join('|') + ')(?![a-z0-9])', 'i');
  // Also try a camelCase-split copy so "ChromeRemoteDesktopHost" can match "chrome remote desktop".
  const split = s => s.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2');
  return s => !!s && (re.test(s) || re.test(split(s)));
}
const isInterviewTool = matcher(INTERVIEW_TOOLS);
const isAiTool = matcher(AI_TOOLS);
const isRemoteTool = matcher(REMOTE_TOOLS);

function run(argv) {
  const HOME = ObjC.unwrap($.NSHomeDirectory());
  const AS = HOME + '/Library/Application Support';
  const MY_PID = Number($.NSProcessInfo.processInfo.processIdentifier);
  const fm = $.NSFileManager.defaultManager;
  const sys = Application.currentApplication();
  sys.includeStandardAdditions = true;

  const sh = cmd => { try { return sys.doShellScript(cmd, { alteringLineEndings: false }); } catch (e) { return ''; } };
  const q = s => "'" + String(s).replace(/'/g, "'\\''") + "'";
  const tilde = p => (p && p.indexOf(HOME) === 0 ? '~' + p.slice(HOME.length) : p || '');
  const clean = s => String(s == null ? '' : s).replace(/[\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, '').trim();
  const readText = p => { const s = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null)); return s === undefined ? null : s; };
  const parse = t => { try { return JSON.parse(t.replace(/^\uFEFF/, '')); } catch (e) { return null; } };
  const readJSON = p => { const t = readText(p); return t == null ? null : parse(t); };
  const ls = p => { const a = fm.contentsOfDirectoryAtPathError(p, null); return a.isNil() ? [] : ObjC.deepUnwrap(a); };
  const exists = p => fm.fileExistsAtPath(p);
  const pad = n => String(n).padStart(2, '0');
  const MONTHS = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split(' ');
  const started = d => !(d instanceof Date) ? '' : (d.toDateString() === new Date().toDateString() ? 'today ' : d.getDate() + ' ' + MONTHS[d.getMonth()] + ' ') + pad(d.getHours()) + ':' + pad(d.getMinutes());

  // ---- Code from the interviewer (proves the report was made now, not earlier) ---------------
  const args = argv || [];
  let code = args.filter(a => String(a).indexOf('--') !== 0)[0] || '';
  if (!code) {
    console.log('Type the code your interviewer gave you, then press Enter:');
    const data = $.NSFileHandle.fileHandleWithStandardInput.availableData;
    code = ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)) || '';
  }
  code = code.replace(/[^A-Za-z0-9_-]/g, '').slice(0, 32) || 'NONE';

  const now = new Date();
  const tz = -now.getTimezoneOffset();
  const stamp = now.getFullYear() + '-' + pad(now.getMonth() + 1) + '-' + pad(now.getDate()) + ' ' +
    pad(now.getHours()) + ':' + pad(now.getMinutes()) + ':' + pad(now.getSeconds()) + ' ' +
    (tz >= 0 ? '+' : '-') + pad(Math.floor(Math.abs(tz) / 60)) + pad(Math.abs(tz) % 60);
  const osv = ObjC.unwrap($.NSProcessInfo.processInfo.operatingSystemVersionString).replace(/^Version /, '');
  const model = sh('/usr/sbin/sysctl -n hw.model').trim();
  const isVM = sh('/usr/sbin/sysctl -n kern.hv_vmm_present 2>/dev/null').trim() === '1' || /virtual|vmware|parallels/i.test(model);

  // ---- Processes ------------------------------------------------------------------------------
  const pidPath = {};
  const procGroups = {};
  let appleCount = 0;
  sh('/bin/ps -axo pid=,comm=').split('\n').forEach(line => {
    const m = /^\s*(\d+)\s+(.+)$/.exec(line);
    if (!m) return;
    const pid = +m[1];
    const comm = m[2].trim();
    pidPath[pid] = comm;
    if (pid === MY_PID || comm === '/bin/ps' || comm === '/bin/sh') return;
    if ((APPLE_PATH.test(comm) && !INTERPRETER.test(comm)) || SHELL_NOISE.test(comm)) { appleCount++; return; }
    const app = /^(.*?\.app)(\/|$)/.exec(comm);
    const key = tilde(app ? app[1] : comm.length > 90 ? comm.slice(0, 90) + '…' : comm);
    procGroups[key] = (procGroups[key] || 0) + 1;
  });

  // ---- Apps (what Activity Monitor calls applications) ---------------------------------------
  const apps = ObjC.unwrap($.NSWorkspace.sharedWorkspace.runningApplications).map(a => {
    const url = a.bundleURL;
    return {
      name: clean(ObjC.unwrap(a.localizedName)),
      bid: ObjC.unwrap(a.bundleIdentifier) || '',
      path: url.isNil() ? '' : tilde(ObjC.unwrap(url.path)),
      pid: Number(a.processIdentifier),
      policy: Number(a.activationPolicy), // 0 = in the Dock, 1 = menu-bar/overlay (no Dock icon), 2 = background
      launched: ObjC.unwrap(a.launchDate),
    };
  });
  const dockApps = apps.filter(a => a.policy === 0);
  const accessoryApps = apps.filter(a => a.policy === 1 && a.bid.indexOf('com.apple.') !== 0);

  // ---- Windows that ask macOS to keep them out of screen sharing / recording -----------------
  // Overlay "interview copilots" set this so the interviewer cannot see them on a screen share.
  // kCGWindowListOptionAll includes windows that are currently tucked away with a hotkey.
  const windows = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0))) || [];
  const hiddenByPid = {};
  windows.filter(w => w.kCGWindowSharingState === 0).forEach(w => {
    const pid = w.kCGWindowOwnerPID;
    const h = hiddenByPid[pid] || (hiddenByPid[pid] = { owner: clean(w.kCGWindowOwnerName), pid, path: tilde(pidPath[pid] || ''), wins: [] });
    const b = w.kCGWindowBounds || {};
    h.wins.push((b.Width || 0) + 'x' + (b.Height || 0) + (w.kCGWindowIsOnscreen ? ' on screen' : ' off screen') +
      ', layer ' + w.kCGWindowLayer + (w.kCGWindowAlpha < 1 ? ', ' + Math.round(w.kCGWindowAlpha * 100) + '% opaque' : ''));
  });
  const hidden = Object.keys(hiddenByPid).map(k => hiddenByPid[k]);
  hidden.forEach(h => { h.usual = APPLE_PATH.test(pidPath[h.pid] || '') || USUAL_HIDERS.test(h.owner); });

  // ---- Displays ---------------------------------------------------------------------------------
  const screens = ObjC.unwrap($.NSScreen.screens).map(s =>
    clean(s.localizedName ? ObjC.unwrap(s.localizedName) : 'Display') + ' ' + Math.round(s.frame.size.width) + 'x' + Math.round(s.frame.size.height));

  // ---- Browser extensions -----------------------------------------------------------------------
  const PRUNE = "\\( -name 'com.apple.*' -o -name 'CallHistory*' -o -name AddressBook -o -name Knowledge -o -name MobileSync -o -name CloudDocs -o -name FileProvider \\) -prune";
  const found = kind => sh('/usr/bin/find ' + q(AS) + ' -maxdepth 5 ' + PRUNE + ' -o ' + kind + ' -print 2>/dev/null; true').split('\n').filter(Boolean);

  function manifestName(dir) {
    const txt = dir && readText(dir + '/manifest.json');
    if (txt == null) return null;
    const m = parse(txt);
    let name = m ? m.name : (/"name"\s*:\s*"([^"]*)"/.exec(txt) || [])[1];
    const msg = /^__MSG_(.+)__$/.exec(name || '');
    if (msg) {
      for (const loc of [m && m.default_locale, 'en', 'en_US', 'en_GB']) {
        const msgs = loc && readJSON(dir + '/_locales/' + loc + '/messages.json');
        const k = msgs && Object.keys(msgs).find(x => x.toLowerCase() === msg[1].toLowerCase());
        if (k && msgs[k].message) { name = msgs[k].message; break; }
      }
    }
    return name ? clean(name) : null;
  }
  const enabledFromPrefs = s => {
    if (s.state === 0) return false; // older browsers
    const dr = s.disable_reasons; // newer browsers: [] or absent = enabled
    if (Array.isArray(dr)) return dr.length === 0;
    if (typeof dr === 'number') return dr === 0;
    return true;
  };

  const browserProfiles = []; // { label, exts: [{ name, id, on, note }], builtinAi: [] }
  found('-type d -name Extensions').map(p => p.replace(/\/Extensions$/, ''))
    .filter(p => exists(p + '/Preferences') || exists(p + '/Secure Preferences'))
    .forEach(profile => {
      const settings = {};
      ['Preferences', 'Secure Preferences'].forEach(f => {
        const j = readJSON(profile + '/' + f);
        const s = j && j.extensions && j.extensions.settings;
        if (s) Object.keys(s).forEach(id => { settings[id] = Object.assign(settings[id] || {}, s[id]); });
      });
      const exts = [], builtinAi = [], seen = {};
      Object.keys(settings).forEach(id => {
        const s = settings[id];
        const dir = s.path ? (s.path[0] === '/' ? s.path : profile + '/Extensions/' + s.path) : null;
        let name = s.manifest && s.manifest.name;
        if (!name || /^__MSG_/.test(name)) name = manifestName(dir) || name;
        if (!name) return; // leftover entry for an uninstalled extension
        name = clean(name);
        if (s.location === 5) { if (isAiTool(name)) builtinAi.push(name); return; } // part of the browser
        seen[id] = true;
        exts.push({ name, id, on: enabledFromPrefs(s), note: s.location === 4 ? 'loaded unpacked from ' + tilde(dir) : '' });
      });
      ls(profile + '/Extensions').filter(id => /^[a-p]{32}$/.test(id) && !seen[id]).forEach(id => {
        const versions = ls(profile + '/Extensions/' + id).sort();
        const name = versions.length && manifestName(profile + '/Extensions/' + id + '/' + versions[versions.length - 1]);
        if (name) exts.push({ name, id, on: null, note: '' });
      });
      browserProfiles.push({ label: profile.slice(AS.length + 1).replace('/User Data', ''), exts, builtinAi });
    });
  found("-type f -name extensions.json -path '*/Profiles/*'").forEach(file => { // Firefox, Zen, LibreWolf…
    const j = readJSON(file);
    const exts = ((j && j.addons) || []).filter(a => a.type === 'extension' && !/^app-(builtin|system)/.test(a.location || ''))
      .map(a => ({ name: clean((a.defaultLocale && a.defaultLocale.name) || a.id), id: a.id, on: !!a.active && !a.userDisabled, note: '' }));
    browserProfiles.push({ label: file.slice(AS.length + 1).replace(/\/extensions\.json$/, ''), exts, builtinAi: [] });
  });
  const safari = [];
  let cur = null;
  sh('/usr/bin/pluginkit -mAvv -p com.apple.Safari.web-extension 2>/dev/null; /usr/bin/pluginkit -mAvv -p com.apple.Safari.extension 2>/dev/null')
    .split('\n').forEach(line => {
      const start = /^\s*[+\-=!]?\s+(\S+)\(.*\)\s*$/.exec(line);
      if (start) { cur = { name: start[1], parent: '' }; safari.push(cur); return; }
      const dn = /^\s*Display Name = (.*)$/.exec(line), pn = /^\s*Parent Name = (.*)$/.exec(line);
      if (cur && dn) cur.name = clean(dn[1]);
      if (cur && pn) cur.parent = clean(pn[1]);
    });
  if (safari.length) browserProfiles.push({ label: 'Safari (installed; on/off lives in Safari Settings)', exts: safari.map(s => ({ name: s.name + (s.parent ? ' (from ' + s.parent + ')' : ''), id: '', on: null, note: '' })), builtinAi: [] });

  // ---- Code-editor extensions -------------------------------------------------------------------
  const EDITOR_NAMES = { '.vscode': 'VS Code', '.vscode-insiders': 'VS Code Insiders', '.vscode-oss': 'VSCodium', '.cursor': 'Cursor', '.windsurf': 'Windsurf', '.kiro': 'Kiro', '.trae': 'Trae', '.antigravity': 'Antigravity', '.positron': 'Positron' };
  const editors = [];
  ls(HOME).filter(d => d[0] === '.' && exists(HOME + '/' + d + '/extensions/extensions.json')).forEach(d => {
    const list = readJSON(HOME + '/' + d + '/extensions/extensions.json') || [];
    const ids = list.map(e => e && e.identifier && e.identifier.id).filter(Boolean).sort();
    editors.push({ label: (EDITOR_NAMES[d] || d) + ' (~/' + d + ')', ids });
  });
  ls(AS + '/JetBrains').forEach(ide => {
    const ids = ls(AS + '/JetBrains/' + ide + '/plugins').filter(p => p[0] !== '.').sort();
    if (ids.length) editors.push({ label: 'JetBrains ' + ide + ' (plugins)', ids });
  });

  // ---- Flags --------------------------------------------------------------------------------------
  const flags = { interview: [], ai: [], aiExt: [], remote: [] };
  const add = (list, label) => { if (list.indexOf(label) < 0) list.push(label); };
  const thirdPartyApps = apps.filter(a => a.bid.indexOf('com.apple.') !== 0);
  thirdPartyApps.forEach(a => {
    const hay = [a.name, a.bid, a.path];
    if (hay.some(isInterviewTool)) add(flags.interview, a.name + ' (app)');
    else if (hay.some(isRemoteTool)) add(flags.remote, a.name);
    else if (hay.some(isAiTool)) add(flags.ai, a.name);
  });
  Object.keys(procGroups).forEach(k => {
    const base = k.replace(/^.*\//, '');
    if (thirdPartyApps.some(a => a.path && a.path === k)) return; // already judged as an app above
    if (isInterviewTool(k)) add(flags.interview, base + ' (process)');
    else if (isRemoteTool(k)) add(flags.remote, base);
    else if (isAiTool(base)) add(flags.ai, base);
  });
  Object.keys(pidPath).forEach(pid => { if (/\/(screensharingd|ARDAgent)$/.test(pidPath[pid])) add(flags.remote, 'macOS Screen Sharing / Remote Management (active)'); });
  hidden.forEach(h => { if (isInterviewTool(h.owner) || isInterviewTool(h.path)) add(flags.interview, h.owner + ' (hidden window)'); });
  browserProfiles.forEach(b => b.exts.forEach(e => {
    if (isInterviewTool(e.name)) add(flags.interview, e.name + ' [' + b.label + (e.on === false ? ', disabled' : '') + ']');
    else if (e.on !== false && isAiTool(e.name)) add(flags.aiExt, e.name + ' [' + b.label + ']');
  }));
  editors.forEach(ed => ed.ids.forEach(id => {
    if (isInterviewTool(id)) add(flags.interview, id + ' [' + ed.label + ']');
    else if (isAiTool(id)) add(flags.aiExt, id + ' [' + ed.label.replace(/ \(.*$/, '') + ']');
  }));
  const badHidden = hidden.filter(h => !h.usual);

  // ---- Report -------------------------------------------------------------------------------------
  const L = [];
  const yn = (bad, warn, text) => (bad ? '!! ' : warn ? '!  ' : 'ok ') + text;
  const list = a => (a.length ? a.join(', ') : 'none found');
  const summary = [
    yn(badHidden.length, hidden.length, 'Windows hidden from screen share : ' + (hidden.length ? hidden.map(h => h.owner + (h.usual ? ' (usually fine)' : '')).join(', ') : 'none found')),
    yn(flags.interview.length, 0, 'Interview-assist tools          : ' + list(flags.interview)),
    yn(0, flags.ai.length, 'AI apps / processes running     : ' + list(flags.ai)),
    yn(0, flags.aiExt.length, 'AI extensions (enabled)         : ' + list(flags.aiExt)),
    yn(0, flags.remote.length, 'Remote-access software running  : ' + list(flags.remote)),
    yn(isVM, 0, 'Running inside a virtual machine: ' + (isVM ? 'YES (' + model + ')' : 'no')),
    yn(0, screens.length > 1, 'Displays connected              : ' + screens.length + ' (' + screens.join('; ') + ')'),
  ];
  L.push('CODEVECTOR INTERVIEW CHECK · macOS', 'Code: ' + code + '    Time: ' + stamp, 'macOS ' + osv + ' · ' + model, '');
  L.push('SUMMARY   (!! = look now · ! = ask about it · ok = nothing found)');
  summary.forEach(s => L.push('  ' + s));
  L.push('', '1. WINDOWS HIDDEN FROM SCREEN SHARE');
  L.push('   Apps can ask macOS to leave a window out of screen shares. Meeting-app share toolbars and');
  L.push('   password managers sometimes do this; an overlay or unfamiliar app doing it is the red flag.');
  if (!hidden.length) L.push('   none');
  hidden.forEach(h => {
    L.push('   ' + h.owner + ' (pid ' + h.pid + ')' + (h.usual ? '  - usually fine' : '  <-- CHECK') + '  ' + h.path);
    h.wins.forEach(w => L.push('       window ' + w));
  });
  L.push('', '2. APPS OPEN IN THE DOCK                                    started');
  dockApps.forEach(a => L.push('   ' + (a.name + '  ' + a.bid).padEnd(58) + ' ' + started(a.launched)));
  L.push('', '3. MENU-BAR / OVERLAY APPS (no Dock icon, non-Apple)         started');
  if (!accessoryApps.length) L.push('   none');
  accessoryApps.forEach(a => L.push('   ' + (a.name + '  ' + a.bid).padEnd(58) + ' ' + started(a.launched)));
  L.push('', '4. OTHER RUNNING PROCESSES (non-Apple; helpers grouped under their app)');
  Object.keys(procGroups).sort((a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : 1)
    .forEach(k => L.push('   ' + k + (procGroups[k] > 1 ? '  (x' + procGroups[k] + ')' : '')));
  L.push('   + ' + appleCount + ' macOS system processes (not listed)');
  L.push('', '5. BROWSER EXTENSIONS   (on / off / ?)');
  if (!browserProfiles.length) L.push('   no browser profiles found');
  browserProfiles.forEach(b => {
    L.push('   ' + b.label);
    if (!b.exts.length) L.push('       (no extensions)');
    b.exts.sort((x, y) => (x.on === y.on ? (x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1) : x.on ? -1 : 1)).forEach(e => {
      const tag = isInterviewTool(e.name) ? '  <-- INTERVIEW TOOL' : isAiTool(e.name) ? '  <-- AI' : '';
      L.push('     ' + (e.on === true ? 'on ' : e.on === false ? 'off' : ' ? ') + ' ' + e.name + (e.id ? '  ' + e.id : '') + (e.note ? '  (' + e.note + ')' : '') + tag);
    });
    if (b.builtinAi.length) L.push('       built into this browser: ' + b.builtinAi.join(', '));
  });
  L.push('', '6. CODE-EDITOR EXTENSIONS / PLUGINS (installed; may be disabled)');
  if (!editors.length) L.push('   none found');
  editors.forEach(ed => {
    L.push('   ' + ed.label);
    ed.ids.forEach(id => L.push('     ' + id + (isInterviewTool(id) ? '  <-- INTERVIEW TOOL' : isAiTool(id) ? '  <-- AI' : '')));
  });
  L.push('', 'End of report · code ' + code + ' · ' + stamp);
  const report = L.join('\n') + '\n';

  const file = HOME + '/interview-check-' + code + '-' + pad(now.getHours()) + pad(now.getMinutes()) + pad(now.getSeconds()) + '.txt';
  $.NSString.alloc.initWithUTF8String(report).writeToFileAtomicallyEncodingError(file, true, $.NSUTF8StringEncoding, null);
  if (args.indexOf('--no-open') < 0) sh('/usr/bin/open -R ' + q(file));

  const color = s => (s.indexOf('!! ') === 0 ? '\x1b[1;31m' : s.indexOf('!  ') === 0 ? '\x1b[33m' : '\x1b[32m') + s + '\x1b[0m';
  return report + '\n' + '='.repeat(78) + '\nSaved: ' + tilde(file) + '  (now shown in Finder) - send this file to your interviewer.\n\n' +
    'SUMMARY · code ' + code + ' · ' + stamp + '\n' + summary.map(s => '  ' + color(s)).join('\n');
}
