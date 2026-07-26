PROJECT := MarkdownPreview.xcodeproj
SCHEME := MarkdownPreview
CONFIGURATION := Debug
PACKAGE_CONFIGURATION := Release
DESTINATION := platform=macOS
DERIVED_DATA := ./.build/DerivedData
DEVELOPER_ID_IDENTITY ?= Developer ID Application
DEVELOPER_ID_TEAM ?= $(shell awk -F= '/^DEVELOPMENT_TEAM[[:space:]]*=/{gsub(/[[:space:]]/,"",$$2); print $$2; exit}' Config/LocalSigning.xcconfig 2>/dev/null)
NOTARY_PROFILE ?= sojoodi-macapp-notary
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination '$(DESTINATION)'
SWIFT_MODULE_CACHE := ./.build/ModuleCache
SWIFT := swift -module-cache-path $(SWIFT_MODULE_CACHE)
SWIFTC := swiftc -module-cache-path $(SWIFT_MODULE_CACHE)
APP_BUNDLE_ID := com.sojoodi.MarkdownPreview
APP_NAME := MarkdownPreview.app
BUILD_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME)
INSTALL_APP := /Applications/$(APP_NAME)
EXTENSION_BUNDLE_ID := com.sojoodi.MarkdownPreview.MarkdownPreviewExtension
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
MARKDOWN_CONTENT_TYPES := com.sojoodi.markdown public.markdown net.daringfireball.markdown net.multimarkdown.text com.unknown.md
BRAND_DIR := Brand
BRAND_BUILD_DIR := ./.build/BrandAssets
SVG_RENDERER := scripts/render_svg.swift
DMG_BACKGROUND_RENDERER := scripts/render_dmg_background.swift
LOGO_SVG := $(BRAND_DIR)/markdownpreview-logo.svg
APP_ICON_SVG := $(BRAND_DIR)/markdownpreview-app-icon.svg
LOGO_PNG := $(BRAND_BUILD_DIR)/markdownpreview-logo.png
APP_ICON_PNG := $(BRAND_BUILD_DIR)/markdownpreview-app-icon.png
DMG_BACKGROUND_PNG := $(BRAND_BUILD_DIR)/dmg-background.png
ASSETCATALOG_DIR := App/Assets.xcassets
APPICONSET_DIR := $(ASSETCATALOG_DIR)/AppIcon.appiconset
APP_ICON_FILES := $(APPICONSET_DIR)/appicon-*.png
APP_ICON_SPECS := \
	16.png:16 \
	16@2x.png:32 \
	32.png:32 \
	32@2x.png:64 \
	128.png:128 \
	128@2x.png:256 \
	256.png:256 \
	256@2x.png:512 \
	512.png:512 \
	512@2x.png:1024
DIST_DIR := ./.build/Dist
DMG_VOLUME_NAME := Markdown Preview
DMG := $(DIST_DIR)/MarkdownPreview.dmg
RELEASE_ARCHIVE := $(DIST_DIR)/MarkdownPreview.xcarchive
RELEASE_APP := $(RELEASE_ARCHIVE)/Products/Applications/$(APP_NAME)
RELEASE_APP_ZIP := $(DIST_DIR)/MarkdownPreview-app-notary.zip
DMG_SCRIPT := scripts/create_dmg.sh
FILE_HANDLER_SCRIPT := scripts/set_markdown_file_handlers.swift

.PHONY: assets build release check-release-config install uninstall rebuild refresh fix-file-handlers test clean paths

define run_build
$(XCODEBUILD) -derivedDataPath $(DERIVED_DATA) clean build $(1)
endef

build: assets
	$(call run_build,)

test:
	mkdir -p .build/TestBinaries .build/TestFixtures $(SWIFT_MODULE_CACHE)
	$(SWIFTC) Extension/MarkdownToHTMLRenderer.swift scripts/test_renderer.swift -o .build/TestBinaries/renderer-tests
	.build/TestBinaries/renderer-tests

release: check-release-config assets
	rm -rf "$(RELEASE_ARCHIVE)" "$(RELEASE_APP_ZIP)" "$(DMG)"
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(PACKAGE_CONFIGURATION) -destination 'generic/platform=macOS' -archivePath "$(RELEASE_ARCHIVE)" clean archive CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(DEVELOPER_ID_IDENTITY)" DEVELOPMENT_TEAM="$(DEVELOPER_ID_TEAM)" ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="--timestamp"
	codesign --verify --deep --strict --verbose=2 "$(RELEASE_APP)"
	mkdir -p "$(DIST_DIR)"
	ditto -c -k --keepParent "$(RELEASE_APP)" "$(RELEASE_APP_ZIP)"
	xcrun notarytool submit "$(RELEASE_APP_ZIP)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(RELEASE_APP)"
	xcrun stapler validate "$(RELEASE_APP)"
	$(DMG_SCRIPT) "$(RELEASE_APP)" "$(DMG)" "$(DMG_VOLUME_NAME)" "$(DMG_BACKGROUND_PNG)" "$(DIST_DIR)"
	codesign --force --sign "$(DEVELOPER_ID_IDENTITY)" --timestamp "$(DMG)"
	codesign --verify --strict --verbose=2 "$(DMG)"
	xcrun notarytool submit "$(DMG)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DMG)"
	xcrun stapler validate "$(DMG)"
	spctl --assess --type execute --verbose=2 "$(RELEASE_APP)"
	spctl --assess --type open --context context:primary-signature --verbose=2 "$(DMG)"
	@echo "Release DMG: $(DMG)"

check-release-config:
	@if [ -z "$(strip $(DEVELOPER_ID_TEAM))" ]; then \
		echo "DEVELOPER_ID_TEAM is not set. Set it directly or add DEVELOPMENT_TEAM to Config/LocalSigning.xcconfig." >&2; \
		exit 2; \
	fi
	@if ! security find-identity -v -p codesigning | grep -F "$(DEVELOPER_ID_IDENTITY)" >/dev/null; then \
		echo "Developer ID signing identity not found: $(DEVELOPER_ID_IDENTITY)" >&2; \
		echo "Override with: make release DEVELOPER_ID_IDENTITY='Developer ID Application: Your Name ($(DEVELOPER_ID_TEAM))'" >&2; \
		exit 2; \
	fi
	@xcrun notarytool history --keychain-profile "$(NOTARY_PROFILE)" >/dev/null || { \
		echo "Notary keychain profile is not usable: $(NOTARY_PROFILE)" >&2; \
		echo "Create it with: xcrun notarytool store-credentials \"$(NOTARY_PROFILE)\" --team-id \"$(DEVELOPER_ID_TEAM)\" --apple-id YOUR_APPLE_ID --password APP_SPECIFIC_PASSWORD" >&2; \
		exit 2; \
	}

assets: $(LOGO_PNG) $(APP_ICON_PNG) $(DMG_BACKGROUND_PNG)
	mkdir -p $(APPICONSET_DIR)
	for spec in $(APP_ICON_SPECS); do \
		name=$${spec%:*}; \
		size=$${spec#*:}; \
		sips -z $$size $$size $(APP_ICON_PNG) --out $(APPICONSET_DIR)/appicon-$$name >/dev/null; \
	done

$(LOGO_PNG): $(LOGO_SVG) $(SVG_RENDERER)
	mkdir -p $(BRAND_BUILD_DIR)
	$(SWIFT) $(SVG_RENDERER) $(LOGO_SVG) $(LOGO_PNG) 1200 320

$(APP_ICON_PNG): $(APP_ICON_SVG) $(SVG_RENDERER)
	mkdir -p $(BRAND_BUILD_DIR)
	$(SWIFT) $(SVG_RENDERER) $(APP_ICON_SVG) $(APP_ICON_PNG) 1024 1024

$(DMG_BACKGROUND_PNG): $(DMG_BACKGROUND_RENDERER)
	mkdir -p $(BRAND_BUILD_DIR)
	$(SWIFT) $(DMG_BACKGROUND_RENDERER) $(DMG_BACKGROUND_PNG)

install:
	rm -rf $(INSTALL_APP)
	cp -R $(BUILD_APP) /Applications/

uninstall:
	-pluginkit -e ignore -i $(EXTENSION_BUNDLE_ID)
	rm -rf $(INSTALL_APP)
	qlmanage -r
	qlmanage -r cache
	killall Finder

rebuild: build install

refresh:
	qlmanage -r
	qlmanage -r cache
	killall Finder

fix-file-handlers:
	@if [ ! -d "$(INSTALL_APP)" ]; then \
		echo "$(INSTALL_APP) is not installed. Run: make rebuild" >&2; \
		exit 2; \
	fi
	@for root in "$(HOME)/Library/Developer/Xcode/Archives" "$(DERIVED_DATA)" "$(DIST_DIR)"; do \
		if [ -d "$$root" ]; then \
			find "$$root" -path "*/$(APP_NAME)" -type d -print 2>/dev/null | while IFS= read -r app; do \
				if [ "$$app" != "$(INSTALL_APP)" ]; then \
					echo "Unregistering stale app: $$app"; \
					"$(LSREGISTER)" -u "$$app" >/dev/null 2>&1 || true; \
				fi; \
			done; \
		fi; \
	done
	"$(LSREGISTER)" -f "$(INSTALL_APP)"
	mkdir -p $(SWIFT_MODULE_CACHE)
	$(SWIFT) $(FILE_HANDLER_SCRIPT) "$(APP_BUNDLE_ID)" "$(INSTALL_APP)" $(MARKDOWN_CONTENT_TYPES)
	qlmanage -r
	qlmanage -r cache
	killall cfprefsd || true
	killall Finder || true

clean:
	rm -rf $(BRAND_BUILD_DIR)
	rm -rf $(DERIVED_DATA)
	rm -rf $(DIST_DIR)
	rm -f $(APP_ICON_FILES)

paths:
	@echo "Built app: $(BUILD_APP)"
	@echo "DMG: $(DMG)"
	@echo "Installed app: $(INSTALL_APP)"
	@echo "App bundle ID: $(APP_BUNDLE_ID)"
	@echo "Extension bundle ID: $(EXTENSION_BUNDLE_ID)"
	@echo "Logo PNG: $(LOGO_PNG)"
	@echo "App icon PNG: $(APP_ICON_PNG)"
