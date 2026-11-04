# iPhone Mirror

A small Mac app that shows your iPhone's screen live in a window, **including the Camera app**.
Apple's built-in iPhone Mirroring turns the camera off. This app uses the cable connection instead
(the same path QuickTime uses to record an iPhone screen), so the camera, video, and everything else show normally.

## Build

Needs macOS 12+ and Apple's command line tools (`xcode-select --install`).

```bash
bash build.sh
open "iPhone Mirror.app"   # or move it to /Applications
```

## Use

1. Plug the iPhone into the Mac with a cable and unlock it. Tap **Trust** if asked.
2. Open iPhone Mirror and allow **Camera** access (macOS treats the iPhone feed as a camera).
3. The screen appears within a few seconds and the window follows the phone when it rotates.

The window has no frame: drag anywhere to move it, drag the edges to resize, and **right-click** for options.

| Shortcut | Action |
|---|---|
| ⌘T | Keep on top |
| ⌃⌘F | Full screen |
| ⇧⌘A | Play iPhone audio |
| ⇧⌘B | Show window buttons |
| ⌘R | Refresh devices |
| ⇧⌘R | Start/stop recording (experimental) |
| ⌘, | Settings (recording folder and options) |

**External display / HDMI:** drag the window onto the TV or monitor and press ⌃⌘F.

## Troubleshooting

- **"No iPhone found":** unlock the phone, try another cable or port, then press ⌘R. If you just tapped Trust, unplug and replug.
- **Black window:** close QuickTime or any other app using the iPhone feed. Only one app can use it at a time.
- **Camera denied:** System Settings › Privacy & Security › Camera › turn on iPhone Mirror.
- **"App can't be opened" warning:** right-click the app › Open (it's signed locally, not by Apple).

## Known limitations

- Needs a cable; there's no wireless mode.
- Recording is experimental: rotating the phone mid-recording may end the file early, and the live view may lose some quality while recording.
