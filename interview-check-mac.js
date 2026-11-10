// CodeVector · interview environment check (macOS)
//
// WHAT IT READS: windows that apps have hidden from screen sharing, the list of running apps and
// processes (names, and real locations for programs it can verify), connected displays, and the
// names of installed browser and code-editor extensions.
// WHAT IT DOES NOT DO: change anything, read your documents, browsing history, cookies or passwords,
// or send anything anywhere. From browser settings it reads only the extension list.
// It saves a plain-text report in your home folder. Read it, then send it to your interviewer.
//
// Run:  osascript -l JavaScript interview-check-mac.js <code your interviewer gives you>
//       (add --no-open to skip revealing the report in Finder)

ObjC.import('Foundation');
ObjC.import('AppKit');
ObjC.import('CoreGraphics');

// ---- Watch lists: whole-word, case-insensitive; "interview coder" also matches InterviewCoder --
// Sold specifically for getting AI help during live interviews. Any match is a red flag.
const INTERVIEW_TOOLS = ['cluely', 'interview coder', 'final round', 'lockedin ai', 'locked in ai',
  'parakeet ai', 'verve ai', 'verve copilot', 'sensei ai', 'sensei copilot', 'leetcode wizard',
  'interview solver', 'pluely', 'cheating daddy', 'interview hammer', 'beyz', 'linkjob',
  'shadecoder', 'interview copilot', 'pickle glass', 'interviews chat', 'ultracode'];
// General AI assistants and AI coding tools: fine to own, not fine to have open in a closed-book round.
const AI_TOOLS = ['chatgpt', 'chat gpt', 'openai', 'codex', 'claude', 'anthropic', 'gemini',
  'copilot', 'perplexity', 'comet', 'grok', 'deepseek', 'mistral', 'le chat', 'poe', 'meta ai',
  'qwen', 'kimi', 'cursor', 'windsurf', 'codeium', 'tabnine', 'supermaven', 'cody', 'continue',
  'cline', 'roo code', 'roo cline', 'kilo code', 'amazon q', 'codewhisperer', 'qodo', 'blackbox',
  'bito', 'aider', 'opencode', 'goose', 'kiro', 'trae', 'antigravity', 'pearai', 'augment',
  'junie', 'ollama', 'lm studio', 'gpt4all', 'msty', 'jan ai', 'monica', 'sider',
  'maxai', 'harpa', 'aiprm', 'granola', 'otter ai', 'fireflies', 'tldv', 'fathom', 'notta', 'krisp',
  'wispr', 'superwhisper', 'macwhisper', 'raycast', 'rewind ai', 'limitless',
  'screenpipe', 'opera neon', 'phind', 'huggingchat', 'chatbox', 'openrouter', 'comet', 'grok', 'dia', 'zed'];
// Lets someone else see or control this computer.
const REMOTE_TOOLS = ['anydesk', 'teamviewer', 'rustdesk', 'parsec', 'splashtop', 'screenconnect',
  'jump desktop', 'realvnc', 'tightvnc', 'tigervnc', 'chrome remote desktop', 'remoting host',
  'chromoting', 'logmein', 'gotomypc', 'goto resolve', 'zoho assist', 'ultraviewer', 'supremo',
  'ammyy', 'aeroadmin', 'dwservice', 'remotepc', 'getscreen', 'nomachine', 'microsoft remote desktop',
  'screensharingd', 'ardagent'];

// Apple system locations. Processes verified to live here are counted, not listed (interpreters stay).
const APPLE_PATH = /^\/(System|usr\/(libexec|sbin|bin)|bin|sbin|Library\/Apple)\//;
const INTERPRETER = /\/(python[\d.]*|ruby|perl[\d.]*|php|java|node|deno|bun|swift|osascript|Electron)$/i;
const SHELL_NOISE = /^-?(zsh|bash|sh|fish|login|launchd|logind|WindowServer|loginwindow|automountd|autofsd)$/;

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
  const base = p => String(p || '').replace(/\/+$/, '').split('/').pop();
  const clean = s => String(s == null ? '' : s).replace(/[\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, '').trim();
  const readText = p => { const s = ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null)); return s === undefined ? null : s; };
  const parse = t => { try { return JSON.parse(t.replace(/^\uFEFF/, '')); } catch (e) { return null; } };
  const readJSON = p => { const t = readText(p); return t == null ? null : parse(t); };
  const ls = p => { const a = fm.contentsOfDirectoryAtPathError(p, null); return a.isNil() ? [] : ObjC.deepUnwrap(a); };
  const exists = p => fm.fileExistsAtPath(p);
  const pad = n => String(n).padStart(2, '0');
  const MONTHS = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split(' ');
  const started = d => !(d instanceof Date) ? '' : (d.toDateString() === new Date().toDateString() ? 'today ' : d.getDate() + ' ' + MONTHS[d.getMonth()] + ' ') + pad(d.getHours()) + ':' + pad(d.getMinutes());
  // Run a section; if it throws, record the failure instead of aborting the whole report.
  const fail = {};
  const guard = (key, fn, dflt) => { try { return fn(); } catch (e) { fail[key] = String(e && e.message || e); return dflt; } };

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

  const flags = { interview: [], ai: [], aiExt: [], remote: [], sideload: [] };
  const add = (lst, label) => { if (label && lst.indexOf(label) < 0) lst.push(label); };

  // ---- Real identity for a pid (kernel truth, not argv) ---------------------------------------
  // ps 'comm' is argv[0] and can be forged; ps 'ucomm' is the kernel's real short name. We trust a
  // full path only when its basename matches ucomm, so a process that rewrote its title (or faked an
  // Apple path) is shown by its real name instead, and its command line never reaches the report.
  const pidUcomm = {}, pidComm = {};
  guard('proc', () => {
    sh('/bin/ps -axo pid=,ucomm=').split('\n').forEach(l => { const m = /^\s*(\d+)\s+(.+)$/.exec(l); if (m) pidUcomm[+m[1]] = m[2].trim(); });
    sh('/bin/ps -axo pid=,comm=').split('\n').forEach(l => { const m = /^\s*(\d+)\s+(.+)$/.exec(l); if (m) pidComm[+m[1]] = m[2].trim(); });
    if (!Object.keys(pidUcomm).length) throw new Error('ps returned nothing');
  });
  const realName = pid => pidUcomm[pid] || base(pidComm[pid]) || '';
  const trustedPath = pid => { // full path only if it corroborates ucomm
    const comm = pidComm[pid] || '', uc = (pidUcomm[pid] || '').toLowerCase();
    return uc && base(comm).toLowerCase().indexOf(uc.slice(0, 15)) === 0 ? comm : '';
  };
  // codesign is offline: it reads the on-disk signature, makes no network call.
  const codesign = bundlePath => {
    if (!bundlePath) return { signed: false, apple: false, vendor: '' };
    const out = sh('/usr/bin/codesign -dvv ' + q(bundlePath) + ' 2>&1');
    const apple = /Authority=Software Signing/.test(out);
    const dev = /Authority=Developer ID Application: (.+?) \([A-Z0-9]+\)/.exec(out);
    const mas = /Authority=Apple Mac OS Application Signing/.test(out);
    const adhoc = /Signature=adhoc/.test(out) || /not signed at all/.test(out) || /no such file/i.test(out);
    return { signed: !adhoc && (apple || !!dev || mas), apple, vendor: dev ? clean(dev[1]) : (mas ? 'Mac App Store' : '') };
  };

  // ---- Processes ------------------------------------------------------------------------------
  // ---- Apps (what Activity Monitor calls applications) ---------------------------------------
  const apps = guard('apps', () => ObjC.unwrap($.NSWorkspace.sharedWorkspace.runningApplications).map(a => {
    const url = a.bundleURL;
    return {
      name: clean(ObjC.unwrap(a.localizedName)),
      bid: ObjC.unwrap(a.bundleIdentifier) || '',
      path: url.isNil() ? '' : tilde(ObjC.unwrap(url.path)),
      pid: Number(a.processIdentifier),
      policy: Number(a.activationPolicy), // 0 = in the Dock, 1 = menu-bar/overlay (no Dock icon), 2 = background
      launched: ObjC.unwrap(a.launchDate),
    };
  }), []);
  const dockApps = apps.filter(a => a.policy === 0);
  const accessoryApps = apps.filter(a => a.policy === 1 && a.bid.indexOf('com.apple.') !== 0);
  apps.filter(a => a.bid.indexOf('com.apple.') !== 0).forEach(a => {
    if (isInterviewTool(a.name) || isInterviewTool(a.bid)) add(flags.interview, a.name + ' (app)');
    else if (isRemoteTool(a.name) || isRemoteTool(a.bid)) add(flags.remote, a.name);
    else if (isAiTool(a.name) || isAiTool(a.bid)) add(flags.ai, a.name);
  });
  const appBundles = apps.map(a => a.path.replace(/^~/, HOME)).filter(Boolean); // helpers of these are judged above
  const inKnownApp = full => full && appBundles.some(p => full === p || full.indexOf(p.replace(/\/$/, '') + '/') === 0);

  // ---- Processes ------------------------------------------------------------------------------
  const procGroups = {};
  let appleCount = 0;
  guard('proc', () => {
    Object.keys(pidUcomm).map(Number).forEach(pid => {
      if (pid === MY_PID) return;
      const nm = realName(pid), full = trustedPath(pid);
      const isApple = (full && APPLE_PATH.test(full) && !INTERPRETER.test(full)) || SHELL_NOISE.test(nm);
      // Apple system processes are only checked for remote-control daemons, never AI (avoids e.g.
      // CursorUIViewService matching "cursor"); helper processes inside a listed app are skipped here.
      if (isApple) {
        if (isRemoteTool(nm) || (full && isRemoteTool(full))) add(flags.remote, nm);
        appleCount++; return;
      }
      if (!inKnownApp(full)) {
        if (isInterviewTool(nm)) add(flags.interview, nm + ' (process)');
        else if (isRemoteTool(nm) || isRemoteTool(full)) add(flags.remote, nm);
        else if (isAiTool(nm)) add(flags.ai, nm);
      }
      const app = full && /^(.*?\.app)(\/|$)/.exec(full);
      const key = app ? tilde(app[1]) : (full ? tilde(full) : nm);
      procGroups[key] = (procGroups[key] || 0) + 1;
    });
  });

  // ---- Windows that apps have hidden from screen sharing / recording --------------------------
  // Overlay "interview copilots" set this so the interviewer cannot see them on a screen share.
  // Self-test: we open our own hidden window first and confirm we can see it. If we can't, this
  // whole check is unreliable, so the report says so loudly instead of a false "none".
  let hidden = [], hiddenOk = false;
  guard('hidden', () => {
    const canary = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(-9999, -9999, 8, 8), 0, 2, false);
    canary.setSharingType(0);
    canary.orderBack(null);
    const windows = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0)));
    canary.orderOut(null);
    if (!windows || !windows.length) throw new Error('window list unavailable');
    hiddenOk = windows.some(w => w.kCGWindowOwnerPID === MY_PID && w.kCGWindowSharingState === 0);
    if (!hiddenOk) throw new Error('self-test window was not detected');
    const byPid = {};
    windows.filter(w => w.kCGWindowSharingState === 0 && w.kCGWindowOwnerPID !== MY_PID).forEach(w => {
      const pid = w.kCGWindowOwnerPID;
      const h = byPid[pid] || (byPid[pid] = { pid, winOwner: clean(w.kCGWindowOwnerName), wins: [] });
      const b = w.kCGWindowBounds || {};
      h.wins.push(Math.round(b.Width || 0) + 'x' + Math.round(b.Height || 0) + (w.kCGWindowIsOnscreen ? ', on screen' : ', off screen') + (w.kCGWindowAlpha < 0.95 ? ', ' + Math.round(w.kCGWindowAlpha * 100) + '% opaque' : ''));
    });
    hidden = Object.keys(byPid).map(k => byPid[k]);
    hidden.forEach(h => {
      const a = $.NSRunningApplication.runningApplicationWithProcessIdentifier(h.pid);
      let bundlePath = '', name = h.winOwner, bid = '';
      if (!a.isNil()) {
        name = clean(ObjC.unwrap(a.localizedName)) || name;
        bid = ObjC.unwrap(a.bundleIdentifier) || '';
        const bu = a.bundleURL, eu = a.executableURL;
        bundlePath = bu.isNil() ? '' : ObjC.unwrap(bu.path);
        h.path = eu.isNil() ? (bundlePath || trustedPath(h.pid)) : ObjC.unwrap(eu.path);
      } else {
        h.path = trustedPath(h.pid); // kernel app record missing: fall back to the verified path
      }
      h.owner = name; h.bid = bid;
      const sig = codesign(bundlePath);
      const watched = [name, bid, sig.vendor, base(h.path)];
      if (watched.some(isInterviewTool)) { h.tier = 'bad'; h.why = 'interview tool'; add(flags.interview, name + ' (hidden window)'); }
      else if (watched.some(isAiTool)) { h.tier = 'bad'; h.why = 'AI tool'; }
      else if (sig.apple && /^com\.apple\./.test(bid)) { h.tier = 'ok'; h.why = 'Apple system app'; }
      else if (sig.signed) { h.tier = 'warn'; h.why = 'signed: ' + (sig.vendor || bid || 'known vendor'); }
      else { h.tier = 'bad'; h.why = 'unsigned / unverified'; }
    });
  });

  // ---- Displays ---------------------------------------------------------------------------------
  const screens = guard('displays', () => ObjC.unwrap($.NSScreen.screens).map(s =>
    clean(s.localizedName ? ObjC.unwrap(s.localizedName) : 'Display') + ' ' + Math.round(s.frame.size.width) + 'x' + Math.round(s.frame.size.height)), []);

  // ---- Browser extensions -----------------------------------------------------------------------
  const PRUNE = "\\( -name 'com.apple.*' -o -name 'CallHistory*' -o -name AddressBook -o -name Knowledge -o -name MobileSync -o -name CloudDocs -o -name FileProvider \\) -prune";
  const found = kind => sh('/usr/bin/find ' + q(AS) + ' -maxdepth 5 ' + PRUNE + ' -o ' + kind + ' -print 2>/dev/null; true').split('\n').filter(Boolean);
  const FF_BUILTIN = { 'app-builtin': 1, 'app-system-defaults': 1, 'app-system-addons': 1 };

  function manifestName(dir) { // only called for dirs under Application Support (no TCC prompt)
    const txt = dir && readText(dir + '/manifest.json');
    if (txt == null) return null;
    const m = parse(txt);
    let name = m ? m.name : (/"name"\s*:\s*"([^"]*)"/.exec(txt) || [])[1];
    const msg = /^__MSG_(.+)__$/.exec(name || '');
    if (msg) {
      for (const loc of [m && m.default_locale, 'en', 'en_US', 'en_GB']) {
        const msgs = loc && readJSON(dir + '/_locales/' + loc + '/messages.json');
        const k = msgs && Object.keys(msgs).find(x => x.toLowerCase() === msg[1].toLowerCase());
        if (k && msgs[k] && msgs[k].message) { name = msgs[k].message; break; }
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

  const browserProfiles = guard('browsers', () => {
    const out = [];
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
          const abs = s.path && s.path[0] === '/';
          const dir = s.path ? (abs ? s.path : profile + '/Extensions/' + s.path) : null;
          const unpacked = s.location === 4 || s.location === 8; // "Load unpacked" (dev mode) or --load-extension
          const safeToRead = dir && dir.indexOf(AS + '/') === 0; // avoid a Documents/Desktop TCC prompt
          let name = s.manifest && s.manifest.name;
          if ((!name || /^__MSG_/.test(name)) && safeToRead) name = manifestName(dir) || name;
          if (s.location === 5) { if (name && isAiTool(clean(name))) builtinAi.push(clean(name)); return; } // part of the browser
          if (!name) { if (!s.path) return; name = '(name unreadable)'; } // keep installed entries; never drop silently
          name = clean(name);
          seen[id] = true;
          const note = unpacked ? 'side-loaded from ' + (dir ? tilde(dir) : 'a folder') : '';
          const e = { name, id, on: enabledFromPrefs(s), note };
          exts.push(e);
          if (unpacked && e.on !== false) add(flags.sideload, name + ' [' + profile.slice(AS.length + 1).replace('/User Data', '') + ']');
        });
        ls(profile + '/Extensions').filter(id => /^[a-p]{32}$/.test(id) && !seen[id]).forEach(id => {
          const versions = ls(profile + '/Extensions/' + id).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
          const name = versions.length && manifestName(profile + '/Extensions/' + id + '/' + versions[versions.length - 1]);
          if (name) exts.push({ name, id, on: null, note: '' });
        });
        out.push({ label: profile.slice(AS.length + 1).replace('/User Data', ''), exts, builtinAi });
      });
    found("-type f -name extensions.json -path '*/Profiles/*'").forEach(file => { // Firefox, Zen, LibreWolf…
      const j = readJSON(file);
      const exts = ((j && j.addons) || []).filter(a => a.type === 'extension' && !FF_BUILTIN[a.location || ''])
        .map(a => ({ name: clean((a.defaultLocale && a.defaultLocale.name) || a.id), id: a.id, on: !!a.active && !a.userDisabled, note: '' }));
      out.push({ label: file.slice(AS.length + 1).replace(/\/extensions\.json$/, ''), exts, builtinAi: [] });
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
    if (safari.length) out.push({ label: 'Safari (installed; on/off not shown — see Safari Settings)', exts: safari.map(s => ({ name: s.name + (s.parent ? ' (from ' + s.parent + ')' : ''), id: '', on: null, note: '' })), builtinAi: [] });
    return out;
  }, []);

  // ---- Code-editor extensions -------------------------------------------------------------------
  const EDITOR_NAMES = { '.vscode': 'VS Code', '.vscode-insiders': 'VS Code Insiders', '.vscode-oss': 'VSCodium', '.cursor': 'Cursor', '.windsurf': 'Windsurf', '.kiro': 'Kiro', '.trae': 'Trae', '.antigravity': 'Antigravity', '.positron': 'Positron' };
  const editors = guard('editors', () => {
    const out = [];
    ls(HOME).filter(d => d[0] === '.' && exists(HOME + '/' + d + '/extensions/extensions.json')).forEach(d => {
      const list = readJSON(HOME + '/' + d + '/extensions/extensions.json');
      const ids = (Array.isArray(list) ? list : []).map(e => e && e.identifier && e.identifier.id).filter(Boolean).sort();
      out.push({ label: (EDITOR_NAMES[d] || d) + ' (~/' + d + ')', short: EDITOR_NAMES[d] || d, ids });
    });
    ls(AS + '/JetBrains').forEach(ide => {
      const ids = ls(AS + '/JetBrains/' + ide + '/plugins').filter(p => p[0] !== '.').sort();
      if (ids.length) out.push({ label: 'JetBrains ' + ide + ' (plugins)', short: 'JetBrains ' + ide, ids });
    });
    return out;
  }, []);

  // ---- Flags from extensions --------------------------------------------------------------------
  browserProfiles.forEach(b => b.exts.forEach(e => {
    if (isInterviewTool(e.name)) add(flags.interview, e.name + ' [' + b.label + (e.on === false ? ', disabled' : '') + ']');
    else if (e.on !== false && isAiTool(e.name)) add(flags.aiExt, e.name + ' [' + b.label + ']');
  }));
  editors.forEach(ed => ed.ids.forEach(id => {
    if (isInterviewTool(id)) add(flags.interview, id + ' [' + ed.short + ']');
    else if (isAiTool(id)) add(flags.aiExt, id + ' [' + ed.short + ']');
  }));

  const badHidden = hidden.filter(h => h.tier === 'bad');
  const warnHidden = hidden.filter(h => h.tier === 'warn');

  // ---- Report -------------------------------------------------------------------------------------
  const L = [];
  const yn = (bad, warn, text) => (bad ? '!! ' : warn ? '!  ' : 'ok ') + text;
  const listOf = a => (a.length ? a.join(', ') : 'none found');
  let hiddenLine;
  if (fail.hidden) hiddenLine = yn(1, 0, 'Windows hidden from screen share : CHECK FAILED (' + fail.hidden + ') — do not trust this as clear');
  else hiddenLine = yn(badHidden.length, warnHidden.length, 'Windows hidden from screen share : ' +
    (hidden.length ? hidden.map(h => h.owner + (h.tier === 'ok' ? '' : h.tier === 'warn' ? ' (' + h.why + ')' : ' <-- CHECK')).join(', ') : 'none found'));
  const summary = [
    hiddenLine,
    yn(flags.interview.length, 0, 'Interview-assist tools          : ' + listOf(flags.interview)),
    yn(0, flags.ai.length, 'AI apps / processes running     : ' + (fail.proc && fail.apps ? 'CHECK FAILED' : listOf(flags.ai))),
    yn(0, flags.aiExt.length, 'AI extensions (enabled)         : ' + (fail.browsers ? 'CHECK FAILED' : listOf(flags.aiExt))),
    yn(0, flags.sideload.length, 'Side-loaded browser extensions  : ' + listOf(flags.sideload)),
    yn(0, flags.remote.length, 'Remote-access software running  : ' + listOf(flags.remote)),
    yn(isVM, 0, 'Running inside a virtual machine : ' + (isVM ? 'YES (' + model + ')' : 'no')),
    yn(fail.displays || screens.length === 0, screens.length > 1, 'Displays connected              : ' + (fail.displays || screens.length === 0 ? 'CHECK FAILED' : screens.length + ' (' + screens.join('; ') + ')')),
  ];
  L.push('CODEVECTOR INTERVIEW CHECK · macOS', 'Code: ' + code + '    Time: ' + stamp, 'macOS ' + osv + ' · ' + model, '');
  L.push('SUMMARY   (!! = look now · ! = ask about it · ok = nothing found)');
  summary.forEach(s => L.push('  ' + s));
  if (Object.keys(fail).length) L.push('', 'NOTE: a check failed and could not complete: ' + Object.keys(fail).map(k => k + ' (' + fail[k] + ')').join('; '));
  L.push('', '1. WINDOWS HIDDEN FROM SCREEN SHARE');
  L.push('   Apps can ask macOS to leave a window out of screen shares. A verified system app or a');
  L.push('   signed, recognised app doing it is usually benign; an unsigned or unknown one is the flag.');
  if (fail.hidden) L.push('   CHECK FAILED: ' + fail.hidden);
  else if (!hidden.length) L.push('   none (self-test passed: the detector is working)');
  hidden.forEach(h => {
    const mark = h.tier === 'ok' ? '  - ' + h.why : h.tier === 'warn' ? '  - ' + h.why + '  <-- glance' : '  <-- CHECK (' + h.why + ')';
    L.push('   ' + h.owner + ' (pid ' + h.pid + ')' + mark + '  ' + tilde(h.path || ''));
    h.wins.forEach(w => L.push('       window ' + w));
  });
  L.push('', '2. APPS OPEN IN THE DOCK                                    started');
  if (fail.apps) L.push('   CHECK FAILED: ' + fail.apps);
  dockApps.forEach(a => L.push('   ' + (a.name + '  ' + a.bid).padEnd(58) + ' ' + started(a.launched)));
  L.push('', '3. MENU-BAR / OVERLAY APPS (no Dock icon, non-Apple)         started');
  if (!fail.apps && !accessoryApps.length) L.push('   none');
  accessoryApps.forEach(a => L.push('   ' + (a.name + '  ' + a.bid).padEnd(58) + ' ' + started(a.launched)));
  L.push('', '4. OTHER RUNNING PROCESSES (non-Apple; helpers grouped under their app)');
  if (fail.proc) L.push('   CHECK FAILED: ' + fail.proc);
  Object.keys(procGroups).sort((a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : 1)
    .forEach(k => L.push('   ' + k + (procGroups[k] > 1 ? '  (x' + procGroups[k] + ')' : '')));
  if (!fail.proc) L.push('   + ' + appleCount + ' macOS system processes (not listed)');
  L.push('', '5. BROWSER EXTENSIONS   (on / off / ?)');
  if (fail.browsers) L.push('   CHECK FAILED: ' + fail.browsers);
  else if (!browserProfiles.length) L.push('   no browser profiles found');
  browserProfiles.forEach(b => {
    L.push('   ' + b.label);
    if (!b.exts.length) L.push('       (no extensions)');
    b.exts.sort((x, y) => (x.on === y.on ? (x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1) : x.on ? -1 : 1)).forEach(e => {
      const tag = isInterviewTool(e.name) ? '  <-- INTERVIEW TOOL' : isAiTool(e.name) ? '  <-- AI' : e.note ? '  <-- SIDE-LOADED' : '';
      L.push('     ' + (e.on === true ? 'on ' : e.on === false ? 'off' : ' ? ') + ' ' + e.name + (e.id ? '  ' + e.id : '') + (e.note ? '  (' + e.note + ')' : '') + tag);
    });
    if (b.builtinAi.length) L.push('       built into this browser: ' + b.builtinAi.join(', '));
  });
  L.push('', '6. CODE-EDITOR EXTENSIONS / PLUGINS (installed; may be disabled)');
  if (fail.editors) L.push('   CHECK FAILED: ' + fail.editors);
  else if (!editors.length) L.push('   none found');
  editors.forEach(ed => {
    L.push('   ' + ed.label);
    ed.ids.forEach(id => L.push('     ' + id + (isInterviewTool(id) ? '  <-- INTERVIEW TOOL' : isAiTool(id) ? '  <-- AI' : '')));
  });
  L.push('', 'End of report · code ' + code + ' · ' + stamp);
  const report = L.join('\n') + '\n';

  const file = HOME + '/interview-check-' + code + '-' + pad(now.getHours()) + pad(now.getMinutes()) + pad(now.getSeconds()) + '.txt';
  const saved = $.NSString.alloc.initWithUTF8String(report).writeToFileAtomicallyEncodingError(file, true, $.NSUTF8StringEncoding, null);
  const willOpen = saved && args.indexOf('--no-open') < 0;
  if (willOpen) sh('/usr/bin/open -R ' + q(file));

  const color = s => (s.indexOf('!! ') === 0 ? '\x1b[1;31m' : s.indexOf('!  ') === 0 ? '\x1b[33m' : '\x1b[32m') + s + '\x1b[0m';
  const tail = saved ? '\nSaved: ' + tilde(file) + (willOpen ? '  (now shown in Finder)' : '') + ' - send this file to your interviewer.'
    : '\nCOULD NOT SAVE the report to your home folder - copy the text above and send it to your interviewer.';
  return report + '\n' + '='.repeat(78) + tail + '\n\n' +
    'SUMMARY · code ' + code + ' · ' + stamp + '\n' + summary.map(s => '  ' + color(s)).join('\n');
}
