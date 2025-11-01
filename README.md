Scripts to repack a Meta Ray-Ban Display firmware to boot in Android Emulator (on an Apple Silicon Mac)

This doesn't work yet. It gets to the "There's an internal problem with your device." screen that always shows when vendor and system doesn't match, then blank screens because `com.oculus.arwireless` fails to start. It's possible to work around this state by installing a custom launcher such as Lawnchair.

You need:

- a Meta Ray-Ban Display firmware (extracted with https://github.com/tobyxdd/android-ota-payload-extractor)
- a Mac with Android Studio, "Android 14 - Google APIs ARM 64 v8a System Image" installed
  (`https://dl.google.com/android/repository/sys-img/google_apis/arm64-v8a-34_r14.zip`), and an AVD created
- https://github.com/LonelyFool/lpunpack_and_lpmake
  (You may need https://github.com/LonelyFool/lpunpack_and_lpmake/pull/24 to fix the build)
- a Linux computer/VM to repack the system image

In Linux:

- build `lpunpack_and_lpmake`
- in fb/, put `system.img`, `system_ext.img`, and `product.img` from the extracted Meta Ray-Ban firmware
- in avd/, put `system.img` from the Android Emulator image (`~/Library/Android/sdk/system-images/android-34/google_apis/arm64-v8a`)
- `make`
- make a copy of the emulator image
- take `out/output/system.img` and replace `system.img` with it
- start the emulator with the copy of the emulator image:

`~/Library/Android/sdk/emulator/emulator -avd Greatwhite -show-kernel -sysdir greatwhite_sim -selinux permissive -accel on`

For working around blank screen:

1) set property to use the newer Nexus stack so ArWireless freezes instead of crashing
2) install a custom launcher such as Lawnchair: https://github.com/LawnchairLauncher/lawnchair/releases/tag/nightly

```
adb root
adb shell setprop persist.vendor.meta.atc.enable_nexus true
adb shell stop
adb shell start
adb install Lawnchair.Debug.15-dev.Nightly-CI_2909-67b9051.apk
adb shell
am start app.lawnchair.nightly
```

(tap the power button if nothing shows up)
