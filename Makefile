PROJECT := MarkdownPreview.xcodeproj
SCHEME := MarkdownPreview
CONFIGURATION := Debug
DESTINATION := platform=macOS
DERIVED_DATA := ./.build/DerivedData
LOCAL_SIGNING_FLAGS := CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination '$(DESTINATION)'
APP_NAME := MarkdownPreview.app
BUILD_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME)
INSTALL_APP := /Applications/$(APP_NAME)
EXTENSION_BUNDLE_ID := com.sojoodi.MarkdownPreview.MarkdownPreviewExtension
BRAND_DIR := Brand
BRAND_BUILD_DIR := ./.build/BrandAssets
SVG_RENDERER := scripts/render_svg.swift
LOGO_SVG := $(BRAND_DIR)/markdownpreview-logo.svg
APP_ICON_SVG := $(BRAND_DIR)/markdownpreview-app-icon.svg
LOGO_PNG := $(BRAND_BUILD_DIR)/markdownpreview-logo.png
APP_ICON_PNG := $(BRAND_BUILD_DIR)/markdownpreview-app-icon.png
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
	512@2x.png:copy

.PHONY: assets build buildlocal install uninstall rebuild refresh clean paths

define run_build
$(XCODEBUILD) -derivedDataPath $(DERIVED_DATA) clean build $(1)
endef

build: assets
	$(call run_build,)

buildlocal: assets
	$(call run_build,$(LOCAL_SIGNING_FLAGS))

assets: $(LOGO_PNG) $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	for spec in $(APP_ICON_SPECS); do \
		name=$${spec%:*}; \
		size=$${spec#*:}; \
		if [ "$$size" = copy ]; then \
			cp $(APP_ICON_PNG) $(APPICONSET_DIR)/appicon-$$name; \
		else \
			sips -z $$size $$size $(APP_ICON_PNG) --out $(APPICONSET_DIR)/appicon-$$name >/dev/null; \
		fi; \
	done

$(LOGO_PNG): $(LOGO_SVG) $(SVG_RENDERER)
	mkdir -p $(BRAND_BUILD_DIR)
	swift $(SVG_RENDERER) $(LOGO_SVG) $(LOGO_PNG) 1200 320

$(APP_ICON_PNG): $(APP_ICON_SVG) $(SVG_RENDERER)
	mkdir -p $(BRAND_BUILD_DIR)
	swift $(SVG_RENDERER) $(APP_ICON_SVG) $(APP_ICON_PNG) 1024 1024

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
	rm -f $(APP_ICON_FILES)

paths:
	@echo "Built app: $(BUILD_APP)"
	@echo "Installed app: $(INSTALL_APP)"
	@echo "Extension bundle ID: $(EXTENSION_BUNDLE_ID)"
	@echo "Logo PNG: $(LOGO_PNG)"
	@echo "App icon PNG: $(APP_ICON_PNG)"
