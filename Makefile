PROJECT := MarkdownPreview.xcodeproj
SCHEME := MarkdownPreview
CONFIGURATION := Debug
DESTINATION := platform=macOS
DERIVED_DATA := ./.build/SignedDerivedData
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

.PHONY: assets build install uninstall rebuild refresh clean paths

build: assets
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) clean build

assets: $(LOGO_PNG) $(APP_ICON_PNG) \
	$(APPICONSET_DIR)/appicon-16.png \
	$(APPICONSET_DIR)/appicon-16@2x.png \
	$(APPICONSET_DIR)/appicon-32.png \
	$(APPICONSET_DIR)/appicon-32@2x.png \
	$(APPICONSET_DIR)/appicon-128.png \
	$(APPICONSET_DIR)/appicon-128@2x.png \
	$(APPICONSET_DIR)/appicon-256.png \
	$(APPICONSET_DIR)/appicon-256@2x.png \
	$(APPICONSET_DIR)/appicon-512.png \
	$(APPICONSET_DIR)/appicon-512@2x.png

$(LOGO_PNG): $(LOGO_SVG) $(SVG_RENDERER)
	mkdir -p $(BRAND_BUILD_DIR)
	swift $(SVG_RENDERER) $(LOGO_SVG) $(LOGO_PNG) 1200 320

$(APP_ICON_PNG): $(APP_ICON_SVG) $(SVG_RENDERER)
	mkdir -p $(BRAND_BUILD_DIR)
	swift $(SVG_RENDERER) $(APP_ICON_SVG) $(APP_ICON_PNG) 1024 1024

$(APPICONSET_DIR)/appicon-16.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 16 16 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-16@2x.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 32 32 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-32.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 32 32 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-32@2x.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 64 64 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-128.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 128 128 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-128@2x.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 256 256 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-256.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 256 256 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-256@2x.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 512 512 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-512.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	sips -z 512 512 $(APP_ICON_PNG) --out $@ >/dev/null

$(APPICONSET_DIR)/appicon-512@2x.png: $(APP_ICON_PNG)
	mkdir -p $(APPICONSET_DIR)
	cp $(APP_ICON_PNG) $@

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
	rm -f $(APPICONSET_DIR)/appicon-*.png
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) clean

paths:
	@echo "Built app: $(BUILD_APP)"
	@echo "Installed app: $(INSTALL_APP)"
	@echo "Extension bundle ID: $(EXTENSION_BUNDLE_ID)"
	@echo "Logo PNG: $(LOGO_PNG)"
	@echo "App icon PNG: $(APP_ICON_PNG)"
