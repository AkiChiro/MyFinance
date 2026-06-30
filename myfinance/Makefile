# MyFinance - build helpers. Run on a machine with Flutter + Android SDK.
FLUTTER ?= flutter
ORG ?= com.huy

.PHONY: help init get gen apk apk-debug install run clean

help:
	@echo "First time:   make init   (creates android/, sets minSdk 29)"
	@echo "Build APK:    make apk    (runs Drift codegen, then builds release)"
	@echo "Install:      make install (build + push to a connected phone)"
	@echo "Dev:          make run    (hot reload on a connected phone)"
	@echo "Clean:        make clean"
	@echo "APK output:   build/app/outputs/flutter-apk/app-release.apk"

init:
	cp pubspec.yaml pubspec.yaml.bak
	$(FLUTTER) create --platforms=android --org $(ORG) --project-name myfinance .
	mv -f pubspec.yaml.bak pubspec.yaml
	-sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 29/' android/app/build.gradle.kts 2>/dev/null
	-sed -i 's/minSdk flutter.minSdkVersion/minSdk 29/' android/app/build.gradle 2>/dev/null
	-sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 29/' android/app/build.gradle 2>/dev/null
	-sed -i 's/android:label="myfinance"/android:label="MyFinance"/' android/app/src/main/AndroidManifest.xml 2>/dev/null
	$(FLUTTER) pub get
	@echo "init done -> next: make apk"

get:
	$(FLUTTER) pub get

gen: get
	dart run build_runner build --delete-conflicting-outputs

apk: gen
	$(FLUTTER) build apk --release
	@echo "APK -> build/app/outputs/flutter-apk/app-release.apk"

apk-debug: gen
	$(FLUTTER) build apk --debug

install: gen
	$(FLUTTER) install

run: gen
	$(FLUTTER) run

clean:
	$(FLUTTER) clean
