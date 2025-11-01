Scripts to repack a Meta Ray-Ban Display firmware to boot in Android Emulator (on an Apple Silicon Mac)

This doesn't quite work yet. It gets to the "There's an internal problem with your device." screen that always shows when vendor and system doesn't match, then blank screens because the initial setup app crashes.

You can force the homescreen to start by `adb shell am start com.meta.smartglass.app.systemui`.

## Running

You need:

- an Apple Silicon Mac with Android Studio, "Android 14 - Google APIs ARM 64 v8a System Image" installed
  (`https://dl.google.com/android/repository/sys-img/google_apis/arm64-v8a-34_r14.zip`), and an AVD created

On macOS:

- in Android Studio's Device Manager, create a virtual device for Android 14, Google APIs
- extract the repacked firmware
- start the emulator with the copy of the emulator image:

`~/Library/Android/sdk/emulator/emulator -avd Greatwhite -show-kernel -sysdir greatwhite_sim -selinux permissive -accel on -prop qemu.sf.lcd_density=160 -skin 600x600`

Once you get to the "There's an internal problem with your device." screen, start the glasses' launcher manually by

`adb shell am start com.meta.smartglass.app.systemui`

For more information, see https://notnow.dev/zhuowei

## Building

You need:

- a Meta Ray-Ban Display firmware (extracted with https://github.com/tobyxdd/android-ota-payload-extractor)
- a Mac with Android Studio, "Android 14 - Google APIs ARM 64 v8a System Image" installed
  (`https://dl.google.com/android/repository/sys-img/google_apis/arm64-v8a-34_r14.zip`), and an AVD created
- https://github.com/LonelyFool/lpunpack_and_lpmake
  (You may need https://github.com/LonelyFool/lpunpack_and_lpmake/pull/24 to fix the build)
- a Linux computer/VM to repack the system image. (I use Ubuntu 25.04 in a VMWare Fusion virual machine)

In Linux:

- build `lpunpack_and_lpmake`
- in fb/, put `system.img`, `system_ext.img`, and `product.img` from the extracted Meta Ray-Ban firmware
- in avd/, put `system.img` from the Android Emulator image (`~/Library/Android/sdk/system-images/android-34/google_apis/arm64-v8a`)
- `make`
- make a copy of the emulator image
- take `out/output/system.img` and replace `system.img` with it
- transfer the emulator image back to macOS

## Tips

Once you get to the blank screen, start the glasses' launcher manually by

`adb shell am start com.meta.smartglass.app.systemui`

You may also want to install a custom launcher such as Lawnchair: https://github.com/LawnchairLauncher/lawnchair/releases/tag/nightly

```
adb install Lawnchair.Debug.15-dev.Nightly-CI_2909-67b9051.apk
adb shell
am start app.lawnchair.nightly
```

Tap the power button if nothing shows up.

Tapping "Launcher" in Lawnchair to bring up the glasses' actual launcher.
