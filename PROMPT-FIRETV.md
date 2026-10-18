# Fire TV prompt (Insignia NS-55F301NA22, Fire OS)

Run Claude Code from the repo root, then paste the block below.

---

You are in the tv-vibehack repo, adapted for my Insignia NS-55F301NA22 (Fire TV Edition, Fire OS). The TV is at 192.168.50.92 with ADB debugging on. Reuse `tools/` and `launcher/`; don't rewrite them. Work on the real device, verify with screenshots, and ask me before anything that depends on my preferences. Everything must be reversible.

Connect
- `export TV_HOST=192.168.50.92`. Setup: `python3 -m venv tools/venv && tools/venv/bin/pip install -r tools/requirements.txt`. Use `tools/venv/bin/python tools/tv.py --probe`.
- If the connection fails with "No route to host" while the port is open, macOS Local Network privacy is blocking it. Tell me to allow my terminal under System Settings → Privacy & Security → Local Network, then retry. Don't debug further.
- Tell me when the "Allow USB debugging?" prompt appears on the TV. Tick "Always allow".

Back up first
- Save `pm list packages -f`, `pm list packages -d`, `getprop` and settings (system/secure/global) to `backup/`. Make `tools/restore.sh` work from that backup.

Fire OS rules (different from Android TV)
- NEVER disable `com.amazon.tv.launcher` (stock Home). The Home button is hard-wired to it. Do not run `set-home-activity` and do not use STOCK_LAUNCHER. Install the launcher with `FIRE_TV=1 launcher/build-and-install.sh`.
- Never disable settings, provisioning, input/HDMI, Bluetooth/remote, keyboard, Play/Appstore, or `com.amazon.device.*` / `com.amazon.dcp` / `com.amazon.imp` without checking with `dumpsys package` and asking me.
- Start from `examples/insignia-ns-55f301na22-fire-tv/debloat.txt`, but it is unverified. Compare each line to `pm list packages` on this TV, drop packages that aren't installed, and look for further ad, recommendation and telemetry packages (com.amazon.*, partner packages). Show me the final list grouped by category before applying.
- Ask me with a checklist which streaming apps, Alexa/voice, and updates to keep.
- Run `pm` commands one per shell call. Apply with `tools/disable.sh <list>`; reboot the TV once afterwards and confirm Home and Inputs still work.

Launcher
- Build it per `launcher/` (needs JDK 17 and Android SDK; if missing, install `openjdk@17` and Android command-line tools via Homebrew and tell me first). Edit `launcher/app/src/main/res/values/config.xml`: ask me which 4 apps go in the dock and their order, confirm package names on the TV (Fire TV YouTube is `com.amazon.firetv.youtube`), and set `live_tv_package`/`hidden_apps` from what is installed.
- Fire OS has no default-home setting. After install, launch it with `am start -n com.gathin.tvhome/.MainActivity`, screenshot it, and test D-pad navigation with `input keyevent`.
- Make the Home button open it: research options that work on Fire OS 7 without root (e.g. a launcher-redirect/Home-button remap app such as "Launcher Manager"/"Wolf Launcher", or an AccessibilityService in our launcher that intercepts Home). Present the options and tradeoffs, and let me pick before installing anything. If none works, tell me honestly and document how to start it from the apps row.
- Remote may lack a Settings key: keep the Settings pill working by launching `com.amazon.tv.settings.v2` or whichever Settings activity resolves on this TV.
- Set the Clock dream only if Fire OS accepts `settings put secure screensaver_components`; otherwise skip.

Verify and hand over
- After each step, send key events, pull a screenshot (`screencap -p`; press Home first, it is blank over HDMI) and look at it. Fix what you see.
- Finish with: restore script tested for dry-run, updated README section for Fire TV, and the list of packages actually disabled saved to `examples/insignia-ns-55f301na22-fire-tv/debloat.txt`.
