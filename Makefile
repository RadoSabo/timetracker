APP = dist/Timetracker.app
SIGN ?= $(shell security find-identity -p codesigning 2>/dev/null | grep -q '"Timetracker Dev"' && echo "Timetracker Dev" || echo -)

.PHONY: build app run test clean icons cert install

install: app
	-pkill -x Timetracker
	rm -rf /Applications/Timetracker.app
	cp -R $(APP) /Applications/
	rm -rf dist
	open /Applications/Timetracker.app

cert:
	scripts/make-cert.sh

build:
	swift build -c release

icons:
	mkdir -p .build/icons
	swift scripts/icon.swift .build/icons
	iconutil -c icns .build/icons/AppIcon.iconset -o .build/icons/AppIcon.icns

app: build icons
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/Timetracker $(APP)/Contents/MacOS/
	cp Info.plist $(APP)/Contents/
	cp .build/icons/AppIcon.icns .build/icons/MenuIcon.png .build/icons/MenuIcon@2x.png $(APP)/Contents/Resources/
	codesign --force --sign "$(SIGN)" --identifier sk.rado.timetracker $(APP)

run: app
	open $(APP)

test:
	swift test

clean:
	rm -rf .build dist
