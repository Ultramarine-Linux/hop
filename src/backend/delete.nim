import results
import std/[os, osproc, strutils, strformat, times, tables, options, sets, strtabs, sequtils, streams]
import pkgs
import ../hub

## Removing a desktop environment.
##
## The UI detects installed DEs via the `ultramarine-release-<de>` packages,
## but dnf5 only removes an environment group (`@ultramarine-<de>-product-environment`)
## if it is tracked as installed in its group database, which is often not the
## case (ISO installs, manual installs, ...). In that case dnf5 prints
## "Nothing to do." and exits with 0. So we build the removal transaction from
## everything that actually is installed:
##
## 1. the environment, if dnf5 tracks it;
## 2. the DE-specific groups (never shared with other editions) that dnf5 tracks;
## 3. the `ultramarine-release-<de>` package, so the UI's detection stays consistent;
## 4. a few core session packages of the DE, so the DE is really gone even if
##    its packages were installed without group tracking (or are kept alive by
##    user-installed extensions).
##
## Before storing the offline transaction, a dry run (`--assumeno`) is checked
## so that it never removes the current edition, the running desktop, the
## enabled display manager, or protected packages.

type DeRemoval = object
  envs: seq[string]    ## environment group ids (incl. legacy ones)
  groups: seq[string]  ## groups specific to this DE only
  pkgs: seq[string]    ## core session packages of this DE
  xdg: string          ## `$XDG_CURRENT_DESKTOP` component of this DE

const removals: Table[string, DeRemoval] = {
  "Budgie": DeRemoval(
    envs: @["ultramarine-budgie-product-environment", "ultramarine-flagship-product-environment"],
    groups: @["ultramarine-budgie-product", "ultramarine-flagship-product", "ultramarine-budgie-apps",
              "ultramarine-budgie-no-flatpak-apps", "budgie-desktop", "budgie-desktop-apps"],
    pkgs: @["budgie-desktop"],
    xdg: "budgie"),
  "GNOME": DeRemoval(
    envs: @["ultramarine-gnome-product-environment"],
    groups: @["ultramarine-gnome-product", "ultramarine-gnome-desktop",
              "ultramarine-gnome-no-flatpak-apps", "gnome-desktop", "critical-path-gnome"],
    pkgs: @["gnome-shell", "gdm"],
    xdg: "gnome"),
  "KDE Plasma": DeRemoval(
    envs: @["ultramarine-plasma-product-environment", "ultramarine-kde-product-environment"],
    groups: @["ultramarine-plasma-product", "ultramarine-kde-product",
              "ultramarine-plasma-no-flatpak-apps", "kde-desktop", "critical-path-kde"],
    pkgs: @["plasma-workspace", "sddm"],
    xdg: "kde"),
  "XFCE": DeRemoval(
    envs: @["ultramarine-xfce-product-environment"],
    groups: @["ultramarine-xfce-product", "ultramarine-xfce-no-flatpak-apps",
              "xfce-desktop", "xfce-extra-plugins", "critical-path-xfce"],
    pkgs: @["xfce4-session", "xfwm4"],
    xdg: "xfce"),
}.toTable

## Packages that must never be removed by this app.
const always_keep = ["ultramarine-release", "ultramarine-release-common",
                     "ultramarine-release-desktop", "dnf5", "rpm", "systemd"]

proc is_running_de(de: string): bool =
  ## Whether `de` is the desktop of the user's session (pkexec forwards the env).
  ## Only the first component counts (Budgie sets "Budgie:GNOME").
  let xdg = getEnv("XDG_CURRENT_DESKTOP").toLowerAscii.split(':')[0]
  if xdg == "" or de notin removals: return false
  xdg.startsWith removals[de].xdg # also matches "gnome-classic"

proc removal_blocker*(de: string, installed_identities: openArray[string]): string =
  ## Returns why `de` must not be removed, or "" if it can be removed.
  if de in identities and identities[de] in installed_identities:
    return fmt"{de} is your current edition and cannot be removed. Change to another edition first."
  if is_running_de(de):
    return fmt"{de} is the desktop you are currently using and cannot be removed. Log into another desktop first."
  ""

proc run_c(args: openArray[string]): string =
  ## Runs a command (no shell) in the C locale, returning stdout+stderr.
  var env = newStringTable()
  for k, v in envPairs(): env[k] = v
  env["LC_ALL"] = "C"
  let p = startProcess(args[0], args = args[1..^1], env = env, options = {poStdErrToStdOut, poUsePath})
  defer: p.close()
  result = p.outputStream.readAll
  discard p.waitForExit

proc installed_pkgs(names: openArray[string]): HashSet[string] =
  ## Exact names of the packages in `names` that are installed.
  if names.len == 0: return
  for l in run_c(@["rpm", "-q", "--qf", "%{NAME}\n"] & @names).splitLines:
    if l.strip in names: result.incl l.strip

proc dnf5_installed_ids(kind: string): HashSet[string] =
  ## Ids of the groups/environments dnf5 tracks as installed.
  var args = @["dnf5", "-q", kind, "list", "--installed"]
  if kind == "group": args.add "--hidden"
  for l in run_c(args).splitLines:
    let s = l.strip
    if s == "": continue
    let id = s.splitWhitespace[0]
    if id == "ID" or id.endsWith(':'): continue # header / summary line
    result.incl id

proc protected_pkgs(): HashSet[string] =
  for f in walkFiles("/etc/dnf/protected.d/*.conf"):
    try:
      for l in readFile(f).splitLines:
        let s = l.split('#')[0].strip
        if s != "": result.incl s
    except IOError: discard

proc display_manager_pkg(): string =
  ## Package owning the enabled display-manager.service (e.g. greetd, sddm, gdm).
  let link = "/etc/systemd/system/display-manager.service"
  if not symlinkExists(link): return ""
  let target = try: expandSymlink(link) except OSError: ""
  if target == "": return ""
  let path = if target.isAbsolute: target else: link.parentDir / target
  let o = run_c(["rpm", "-qf", "--qf", "%{NAME}\n", path]).strip
  if o.contains(' ') or o == "": "" else: o

proc forbidden_pkgs(): Table[string, string] =
  ## package -> reason why it must not be removed.
  for p in always_keep: result[p] = "it is a core system package"
  for p in protected_pkgs(): result[p] = "it is protected by dnf"
  let dm = display_manager_pkg()
  if dm != "": result[dm] = "it provides your login screen (display manager)"
  let ids = installed_pkgs(identities.values.toSeq)
  for name, r in removals:
    let current = identities[name] in ids
    if not (current or is_running_de(name)): continue
    let why = if current: fmt"it belongs to your current edition ({name})"
              else: fmt"it belongs to the desktop you are using ({name})"
    result[editions[name]] = why
    result[identities[name]] = why
    for p in r.pkgs: result[p] = why

proc removed_pkgs(output: string): seq[string] =
  ## Package names in the "Removing…" sections of dnf5's transaction table.
  var inside = false
  for l in output.splitLines:
    if l.len == 0: continue
    if l[0] != ' ':
      inside = l.startsWith("Removing") and "groups" notin l
      continue
    if inside and l.len > 1 and l[1] != ' ':
      result.add l.splitWhitespace[0]

proc plan_removal*(de: string): Result[seq[string], string] =
  ## Computes the dnf5 arguments to remove `de` and checks them with a dry run.
  if de notin removals: return err fmt"Unknown desktop environment: {de}"
  let blocker = removal_blocker(de, installed_pkgs(identities.values.toSeq).toSeq)
  if blocker != "": return err blocker
  let r = removals[de]
  let forbidden = forbidden_pkgs()

  var targets: seq[string]
  let envs = dnf5_installed_ids("environment")
  let groups = dnf5_installed_ids("group")
  echo fmt"├═ Installed environments: {envs}"
  echo fmt"├═ Installed groups: {groups}"
  for e in r.envs:
    if e in envs: targets.add "@" & e
  for g in r.groups:
    if g in groups: targets.add "@" & g
  for p in installed_pkgs(@[editions[de]] & r.pkgs):
    if p notin forbidden: targets.add p
  if targets.len == 0:
    return err fmt"{de} does not seem to be installed: dnf5 does not track its environment or groups, and none of its packages are installed."
  echo "├═ Targets: " & targets.join(" ")

  # Dry run: see what dnf5 would really remove before storing anything.
  let output = run_c(@["dnf5", "rm", "--assumeno", "--offline"] & targets)
  for l in output.splitLines: echo "┊ " & l
  if "Transaction Summary:" notin output:
    var why = output.strip
    for l in output.splitLines:
      if l.startsWith("Problem"): why = l.strip
    if output.contains("Nothing to do."): why = "dnf5 reported nothing to do."
    return err fmt"Cannot remove {de}: {why}"
  var bad: seq[string]
  for p in removed_pkgs(output):
    if p in forbidden: bad.add fmt"{p} ({forbidden[p]})"
    elif p.startsWith("ultramarine-release-identity"): bad.add fmt"{p} (it is an edition identity)"
  if bad.len > 0:
    return err fmt"Refusing to remove {de}, as it would also remove:" & "\n" & bad.join("\n")
  ok targets

proc remove_de_offline*(hub: ref Hub, de: string): Result[void, string] {.thread.} =
  ?ensure_dnf5()
  echo "Removing packages..."
  hub.toMain.send UpdateState.init("Checking what to remove...")
  echo fmt"┌──── BEGIN: Remove DE Offline ─────"
  let pkgs = ?plan_removal(de)
  hub.toMain.send UpdateState.init("Running dnf5...")
  echo "├═ Pkgs: "&pkgs.join(" ")
  stdout.write "┊ "
  let time = now()
  var args = @["rm", "-y", "--offline"]
  args &= pkgs
  let since = getTime()
  let process = start_dnf5(args) # C locale: ensure_dnf5_did_something() parses English output
  let output = track_dnf5_download_progress(process, none(ref Hub))
  ?end_proc(process, time, "Remove DE Offline", "arrange offline DE remove")
  ?ensure_dnf5_did_something(output, "remove " & de)
  ?ensure_offline_transaction(pkgs, since)
  ?reboot_apply_offline hub
  ok()
