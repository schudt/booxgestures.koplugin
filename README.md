# booxgestures.koplugin — BOOX controls for KOReader

Android-only plugin for BOOX gesture controls and silent brightness/warmth
adjustments. All settings are under **Settings → Device → BOOX controls**.
The plugin uses KOReader's native Android/JNI bridge; normal use requires
neither root, ADB, nor a companion application.

## BOOX gestures

Three persistent toggles control BOOX's system swipe gestures independently:

- **Disable BOOX top gestures in KOReader**
- **Disable BOOX bottom gestures in KOReader**
- **Disable BOOX side gestures in KOReader**

Enabled toggles disable the corresponding gestures while KOReader is active,
restore them when KOReader goes into the background, and disable them again
when KOReader resumes.

Top and bottom controls were tested on a BOOX Go 7. The side control still
needs device testing.

### Install

Download `booxgestures.koplugin.zip` from the
[latest release](https://github.com/schudt/booxgestures.koplugin/releases/latest)
and extract it into KOReader's `plugins` directory. The ZIP contains the
required `booxgestures.koplugin` directory. Restart KOReader.

Alternatively, clone the repository into KOReader's `plugins` directory:

```sh
cd /path/to/koreader/plugins
git clone https://github.com/schudt/booxgestures.koplugin.git
```

### Gesture broadcasts and recovery

The plugin sends BOOX's runtime broadcasts with boolean extra `args_enable`:

```text
com.onyx.action.TOP_GESTURE_ENABLE
com.onyx.action.BOTTOM_GESTURE_ENABLE
com.onyx.action.SIDE_GESTURE_ENABLE
```

Android does not deliver a pause event when KOReader is force-stopped or
crashes. If gestures remain disabled afterward, restore them with:

```sh
adb shell am broadcast -a com.onyx.action.TOP_GESTURE_ENABLE --ez args_enable true
adb shell am broadcast -a com.onyx.action.BOTTOM_GESTURE_ENABLE --ez args_enable true
adb shell am broadcast -a com.onyx.action.SIDE_GESTURE_ENABLE --ez args_enable true
```

## Brightness and warmth

On BOOX CTM devices, the plugin also corrects KOReader's warmth readback after
startup. Sliders show the native hardware value instead of an inflated value
(for example, `26` instead of `266` on Go 7). This correction applies even when
popup suppression is off and does not change the hardware light level.

Enable **Suppress BOOX light popup in KOReader** to adjust brightness and
warmth without BOOX's SystemUI slider taking focus. This option is off by
default and applies to KOReader's light controls, including ZenOS sliders.

On BOOX CTM devices, the plugin calls `DeviceController.setLightValue` with
flag `0`. Existing scaling and getters remain unchanged. Turning the option
off restores normal light calls immediately. If the silent API fails, the
option turns off and the original light call handles the requested change.

The silent API was verified through ADB, and the plugin's brightness/warmth
controls were confirmed working on Go 7 firmware
`2026-04-21_13-50_4.2-rel_0421_19324b3ea`. Other firmware may differ.

### Enable Android light controls

On BOOX devices running Android 11 or newer, KOReader's light driver may need
access to Android's hidden APIs. Enable USB debugging, connect the device to
your computer, and authorize the ADB connection. Note the current policy
before changing it:

```sh
adb devices
adb shell settings get global hidden_api_policy
adb shell settings put global hidden_api_policy 1
```

Close and reopen KOReader, then test brightness and warmth. This is a global
Android setting, not a permission limited to KOReader. Root is not required.

See KOReader's [Onyx light-driver setup](https://github.com/koreader/koreader/wiki/Android-tips-and-tricks#onyx-devices)
for the upstream instructions.

### Undo Android setup

Restore the policy value you noted earlier. If the original value was `null`
(unset), remove the override:

```sh
adb shell settings delete global hidden_api_policy
```

Close and reopen KOReader after restoring the policy.
