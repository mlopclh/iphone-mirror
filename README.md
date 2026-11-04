# Phone Mirror

A small Mac app that shows your phone's screen live on your Mac. It works with both **iPhone** and **Android**.

- **iPhone:** the Camera app shows too. Apple's built-in iPhone Mirroring turns the camera off; this app uses the cable connection instead (the same path QuickTime uses to record an iPhone screen).
- **Android:** the app runs [scrcpy](https://github.com/Genymobile/scrcpy) behind the scenes and shows the phone in its own window. You can control the phone with your mouse and keyboard.

## Build

Needs macOS 12+ and Apple's command line tools (`xcode-select --install`).

```bash
bash build.sh
open "Phone Mirror.app"   # or move it to /Applications
```

### Android setup (one time)

1. Install scrcpy and adb with [Homebrew](https://brew.sh):
   ```bash
   brew install scrcpy
   brew install --cask android-platform-tools
   ```
2. On the phone, turn on Developer options (Settings › About phone › tap **Build number** 7 times), then turn on **USB debugging** in Settings › Developer options.
3. The first time you plug in, tap **Allow** on the phone.

Company-managed phones may block USB debugging. If so, IT needs to allow it.

## Use

1. Plug the phone into the Mac with a cable and unlock it.
   - iPhone: tap **Trust** if asked.
   - Android: tap **Allow** if asked.
2. Open Phone Mirror. For iPhone, allow **Camera** access (macOS treats the iPhone feed as a camera).
3. The first phone it finds shows up automatically. With more than one phone plugged in, switch between them in the **Device** menu.

**iPhone window:** it has no frame. Drag anywhere to move it, drag the edges to resize, and **right-click** for options.

**Android window:** clicks and typing go to the phone, so move the window by its title bar. In that window, ⌘F toggles full screen.

| Shortcut | Action |
|---|---|
| ⌘T | Keep on top |
| ⌃⌘F | Full screen (iPhone) |
| ⇧⌘A | Play phone audio |
| ⇧⌘B | Show window buttons (iPhone) |
| ⌘R | Refresh devices |
| ⇧⌘R | Start/stop recording (iPhone, experimental) |
| ⌘, | Settings (recording folder and options) |

**External display / HDMI:** drag the window onto the TV or monitor and go full screen. Plug the phone straight into the Mac, not through the same hub as the HDMI.

## Troubleshooting

- **No phone found:** unlock the phone, try another cable or port, then press ⌘R.
- **iPhone shows a black window:** close QuickTime or any other app using the iPhone feed. Only one app can use it at a time.
- **iPhone camera access denied:** System Settings › Privacy & Security › Camera › turn on Phone Mirror.
- **Android listed as "tap Allow on the phone":** unlock the phone and accept the USB debugging prompt.
- **"Android: install scrcpy" in the Device menu:** see Android setup above.
- **"App can't be opened" warning:** right-click the app › Open (it's signed locally, not by Apple).

## Known limitations

- Needs a cable; there's no wireless mode.
- Android shows in its own window rather than inside the Phone Mirror window.
- Recording is iPhone-only and experimental: rotating the phone mid-recording may end the file early, and the live view may lose some quality while recording.
