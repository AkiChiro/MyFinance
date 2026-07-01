"""
Run once after `flutter create` to finish setting up the Android project.
Called by `make init`. Safe to re-run (idempotent).

Handles everything that would otherwise need Unix shell tools (sed, cp):
  1. Copy android_overlay/ → android/ (recursive, overwrite)
  2. Patch android/app/build.gradle.kts  — minSdk, core-library desugaring
  3. Patch android/gradle.properties     — disable Kotlin incremental (cross-drive bug)
  4. Patch AndroidManifest.xml          — app label, widget receiver, POST_NOTIFICATIONS
  5. Create res/values/strings.xml      — widget description string
"""
import os
import pathlib
import shutil

root = pathlib.Path(__file__).parent

# ---------------------------------------------------------------------------
# 1. Copy android_overlay/ → android/
# ---------------------------------------------------------------------------
overlay = root / "android_overlay"
android = root / "android"

for src in overlay.rglob("*"):
    if src.is_file():
        rel = src.relative_to(overlay)
        dst = android / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"[patch_android] copied {rel}")

# ---------------------------------------------------------------------------
# 2. Patch android/app/build.gradle.kts
#    • minSdk 29
#    • isCoreLibraryDesugaringEnabled = true
#    • desugar_jdk_libs dependency block
# ---------------------------------------------------------------------------
bgk = android / "app" / "build.gradle.kts"
if bgk.exists():
    t = bgk.read_text(encoding="utf-8")

    # minSdk
    if "flutter.minSdkVersion" in t:
        t = t.replace("minSdk = flutter.minSdkVersion", "minSdk = 29")
        print("[patch_android] build.gradle.kts: minSdk set to 29")

    # core library desugaring
    if "isCoreLibraryDesugaringEnabled" not in t:
        t = t.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
        )
        print("[patch_android] build.gradle.kts: isCoreLibraryDesugaringEnabled added")

    # desugar dependency block
    if "desugar_jdk_libs" not in t:
        t += "\ndependencies {\n    coreLibraryDesugaring(\"com.android.tools:desugar_jdk_libs:2.1.4\")\n}\n"
        print("[patch_android] build.gradle.kts: desugar_jdk_libs dependency added")

    bgk.write_text(t, encoding="utf-8")

# Fall back to .gradle (older flutter create template)
bg = android / "app" / "build.gradle"
if bg.exists():
    t = bg.read_text(encoding="utf-8")
    changed = False
    for old, new in [
        ("minSdk flutter.minSdkVersion", "minSdk 29"),
        ("minSdkVersion flutter.minSdkVersion", "minSdkVersion 29"),
    ]:
        if old in t:
            t = t.replace(old, new)
            changed = True
    if changed:
        bg.write_text(t, encoding="utf-8")
        print("[patch_android] build.gradle: minSdk set to 29")

# ---------------------------------------------------------------------------
# 3. Patch android/gradle.properties — disable Kotlin incremental compilation
#    (Kotlin daemon crashes when pub-cache (C:) and project (E:) live on
#    different Windows drive letters.)
# ---------------------------------------------------------------------------
gp = android / "gradle.properties"
if gp.exists():
    t = gp.read_text(encoding="utf-8")
    if "kotlin.incremental" not in t:
        t += "\n# Kotlin incremental caches crash when pub-cache and project are on different drives.\nkotlin.incremental=false\n"
        gp.write_text(t, encoding="utf-8")
        print("[patch_android] gradle.properties: kotlin.incremental=false added")

# ---------------------------------------------------------------------------
# 4. Patch AndroidManifest.xml
#    • app label "MyFinance"
#    • POST_NOTIFICATIONS permission
#    • WidgetProvider receiver
# ---------------------------------------------------------------------------
manifest = android / "app" / "src" / "main" / "AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")

if 'android:label="myfinance"' in text:
    text = text.replace('android:label="myfinance"', 'android:label="MyFinance"')
    print("[patch_android] AndroidManifest.xml: app label fixed")

if "POST_NOTIFICATIONS" not in text:
    text = text.replace(
        "    <application",
        '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <application',
        1,
    )
    print("[patch_android] AndroidManifest.xml: POST_NOTIFICATIONS added")

if "RECEIVE_BOOT_COMPLETED" not in text:
    text = text.replace(
        "    <application",
        '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n    <application',
        1,
    )
    print("[patch_android] AndroidManifest.xml: RECEIVE_BOOT_COMPLETED added")

widget_receiver = """\
        <receiver
            android:name=".WidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/myfinance_widget_info" />
        </receiver>"""

if ".WidgetProvider" not in text:
    text = text.replace("    </application>", widget_receiver + "\n    </application>")
    print("[patch_android] AndroidManifest.xml: WidgetProvider receiver added")

boot_receiver = """\
        <receiver
            android:name=".BootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>"""

if ".BootReceiver" not in text:
    text = text.replace("    </application>", boot_receiver + "\n    </application>")
    print("[patch_android] AndroidManifest.xml: BootReceiver added")

manifest.write_text(text, encoding="utf-8")

# ---------------------------------------------------------------------------
# 5. Create res/values/strings.xml
# ---------------------------------------------------------------------------
vals = android / "app" / "src" / "main" / "res" / "values"
vals.mkdir(parents=True, exist_ok=True)
strings = vals / "strings.xml"

if not strings.exists():
    strings.write_text(
        '<resources>\n    <string name="widget_description">MyFinance quick add</string>\n</resources>\n',
        encoding="utf-8",
    )
    print("[patch_android] strings.xml created")
else:
    s = strings.read_text(encoding="utf-8")
    if "widget_description" not in s:
        s = s.replace(
            "</resources>",
            '    <string name="widget_description">MyFinance quick add</string>\n</resources>',
        )
        strings.write_text(s, encoding="utf-8")
        print("[patch_android] strings.xml: widget_description added")

print("[patch_android] done")
