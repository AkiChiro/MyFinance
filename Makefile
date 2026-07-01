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
	$(FLUTTER) create --platforms=android --org $(ORG) --project-name myfinance --no-pub .
	python patch_android.py
	$(FLUTTER) pub get
	@echo "init done -> next: make apk"

get:
	$(FLUTTER) pub get

gen: get
	$(FLUTTER) pub run build_runner build --force-jit --delete-conflicting-outputs

apk: gen
	python patch_android.py
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
