# DnD Adventurers

A starter Android app for Android 6.0 and later. DnD Adventurers is distributed through [GitHub Releases](https://github.com/cosmerearchives-creator/dnd-adventurers/releases).

When the app opens, it checks the latest stable release and downloads a newer APK in the background. The app verifies the download and displays **Install update**. Android handles installation and may ask you to allow installation from this app. **Check for updates** repeats the check while the app is open.

## Build

Open the repository in Android Studio with JDK 17 and Android SDK Platform 36. Run the `app` configuration on a device or emulator. On Windows:

```powershell
.\gradlew.bat :app:assembleDebug :app:lintDebug :app:assembleRelease
```

Use `./gradlew` on macOS or Linux. The debug APK is for local development. For testing updates, install the release APK signed with your release key.

## Publish a release

1. Increase `versionCode` in `app/build.gradle` and set `versionName` to the version users should see. Keep the package ID `com.silverlight.dndadventurers`.
2. In Android Studio, use **Build → Generate Signed Bundle / APK → APK** and select the release build. Sign every release with the same key. Keep a backup of that key and its passwords outside this repository.
3. Prepare the two release assets using the signed APK and the Android SDK Build Tools directory.

   ```powershell
   .\scripts\Prepare-Release.ps1 -ApkPath 'C:\path\to\signed-release.apk' -BuildToolsPath 'C:\path\to\Android\Sdk\build-tools\35.0.0'
   ```

4. Create a GitHub release draft for the version tag, attach `dnd-adventurers.apk` and `update.json` from `release-assets\`, then publish it as the latest stable release once both files are attached.

[Publishing GitHub releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository) · [Android app signing](https://developer.android.com/studio/publish/app-signing)

## Test an update

Install the first signed APK on an Android device. Publish a second APK with a higher version code and the same signing key. Open the installed app, wait for **Install update**, and follow Android’s prompts. Reopen the app and confirm the new version on the home screen. Canceling the installer should leave the current version usable.
