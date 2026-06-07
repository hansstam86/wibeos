APP = WibeOS
VERSION = 1.0.0
# Set these for signed releases (see GUMROAD.md):
#   export SIGN_ID="Developer ID Application: Your Name (TEAMID)"
#   export NOTARY_PROFILE="wibeos-notary"

.PHONY: run build universal icon app dmg release clean

run:
	swift run -c release

build:
	swift build -c release

universal:
	swift build -c release --arch arm64 --arch x86_64

icon:
	iconutil -c icns assets/icon.iconset -o assets/$(APP).icns

# local/dev app: native arch only (works with just Command Line Tools)
app: build icon
	rm -rf $(APP).app
	mkdir -p $(APP).app/Contents/MacOS $(APP).app/Contents/Resources
	cp .build/apple/Products/Release/$(APP) $(APP).app/Contents/MacOS/ 2>/dev/null || \
		cp .build/release/$(APP) $(APP).app/Contents/MacOS/
	cp -R .build/apple/Products/Release/WibeOS_WibeOS.bundle $(APP).app/Contents/Resources/ 2>/dev/null || \
		cp -R .build/release/WibeOS_WibeOS.bundle $(APP).app/Contents/Resources/
	cp assets/$(APP).icns $(APP).app/Contents/Resources/
	cp Info.plist $(APP).app/Contents/
	@echo "Built $(APP).app"

dmg: app
	rm -rf dist && mkdir -p dist/dmgroot
	cp -R $(APP).app dist/dmgroot/
	ln -s /Applications dist/dmgroot/Applications
	hdiutil create -volname "wibeOS" -srcfolder dist/dmgroot -ov -format UDZO \
		dist/wibeOS-$(VERSION).dmg
	@echo "dist/wibeOS-$(VERSION).dmg ready"

# release: universal binary — requires full Xcode (then: sudo xcode-select -s /Applications/Xcode.app)
# the app target's copy step prefers the universal artifacts when they exist
release: universal app
	@test -n "$(SIGN_ID)" || (echo "Set SIGN_ID first — see GUMROAD.md" && exit 1)
	codesign --force --deep --options runtime --sign "$(SIGN_ID)" $(APP).app
	$(MAKE) dmg
	codesign --force --sign "$(SIGN_ID)" dist/wibeOS-$(VERSION).dmg
	@test -n "$(NOTARY_PROFILE)" || (echo "Set NOTARY_PROFILE first — see GUMROAD.md" && exit 1)
	xcrun notarytool submit dist/wibeOS-$(VERSION).dmg --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple dist/wibeOS-$(VERSION).dmg
	@echo "Signed + notarized: dist/wibeOS-$(VERSION).dmg — upload this to Gumroad"

clean:
	rm -rf .build $(APP).app dist assets/$(APP).icns
