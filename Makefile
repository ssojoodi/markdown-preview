PROJECT := MarkdownPreview.xcodeproj
SCHEME := MarkdownPreview
CONFIGURATION := Debug
PACKAGE_CONFIGURATION := Release
DESTINATION := platform=macOS
DERIVED_DATA := ./.build/DerivedData
LOCAL_SIGNING_FLAGS := CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination '$(DESTINATION)'
SWIFT_MODULE_CACHE := ./.build/ModuleCache
SWIFT := swift -module-cache-path $(SWIFT_MODULE_CACHE)
APP_NAME := MarkdownPreview.app
BUILD_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME)
INSTALL_APP := /Applications/$(APP_NAME)
EXTENSION_BUNDLE_ID := com.sojoodi.MarkdownPreview.MarkdownPreviewExtension
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
DMG_SCRIPT := scripts/create_dmg.sh

.PHONY: assets build buildlocal dmg package package-local install uninstall rebuild refresh clean paths

define run_build
$(XCODEBUILD) -derivedDataPath $(DERIVED_DATA) clean build $(1)
endef

build: assets
	$(call run_build,)

buildlocal: assets
	$(call run_build,$(LOCAL_SIGNING_FLAGS))

package:
	$(MAKE) build CONFIGURATION=$(PACKAGE_CONFIGURATION)
	$(MAKE) dmg CONFIGURATION=$(PACKAGE_CONFIGURATION)

package-local:
	$(MAKE) buildlocal CONFIGURATION=$(PACKAGE_CONFIGURATION)
	$(MAKE) dmg CONFIGURATION=$(PACKAGE_CONFIGURATION)

dmg: $(DMG_BACKGROUND_PNG)
	$(DMG_SCRIPT) "$(BUILD_APP)" "$(DMG)" "$(DMG_VOLUME_NAME)" "$(DMG_BACKGROUND_PNG)" "$(DIST_DIR)"

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

clean:
	rm -rf $(BRAND_BUILD_DIR)
	rm -rf $(DERIVED_DATA)
	rm -rf $(DIST_DIR)
	rm -f $(APP_ICON_FILES)

paths:
	@echo "Built app: $(BUILD_APP)"
	@echo "DMG: $(DMG)"
	@echo "Installed app: $(INSTALL_APP)"
	@echo "Extension bundle ID: $(EXTENSION_BUNDLE_ID)"
	@echo "Logo PNG: $(LOGO_PNG)"
	@echo "App icon PNG: $(APP_ICON_PNG)"
