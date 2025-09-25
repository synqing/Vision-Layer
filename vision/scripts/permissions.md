Screen Recording Permission (macOS)

1) Open System Settings → Privacy & Security → Screen Recording.
2) Ensure the built Swift app (VisionDaemon via swift run) has permission:
   - Launch visiond once via scripts/run_all.sh.
   - When prompted, grant access. If not prompted, add Terminal/iTerm and Xcode to the list.
3) If permissions change, fully quit the app and relaunch.

Notes
- ScreenCaptureKit/CGWindow snapshots require Screen Recording permission for 3rd‑party apps.
- If capture fails with black images, recheck permissions and disable “Low Power Mode”.

