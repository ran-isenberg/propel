APP_NAME = Propel
BUNDLE_ID = com.ranisenberg.propel
BUILD_DIR = .build
DEBUG_DIR = $(BUILD_DIR)/debug
RELEASE_DIR = $(BUILD_DIR)/release
DEBUG_APP = $(DEBUG_DIR)/$(APP_NAME).app
APP_BUNDLE = $(RELEASE_DIR)/$(APP_NAME).app
DMG_NAME = $(APP_NAME).dmg
INSTALL_DIR = /Applications
ICON_SRC = Sources/Propel/Resources/AppIcon.icns
ENTITLEMENTS = Sources/Propel/Resources/Propel.entitlements
BIN_PATH = $(shell swift build -c release --show-bin-path 2>/dev/null)

.PHONY: build build-release run test clean install uninstall dmg app-bundle check-tools generate-icon help lint format check

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

check-tools: ## Verify Xcode is installed
	@xcodebuild -version > /dev/null 2>&1 || { echo "Error: Xcode is required. Install from App Store, then run:"; echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; exit 1; }
	@echo "Xcode toolchain: OK"

lint: ## Run SwiftLint (requires: brew install swiftlint)
	@command -v swiftlint > /dev/null 2>&1 || { echo "Error: SwiftLint not found. Install with: brew install swiftlint"; exit 1; }
	@echo "Running SwiftLint..."
	@swiftlint lint --strict Sources/ Tests/

format: ## Auto-format code with SwiftFormat (requires: brew install swiftformat)
	@command -v swiftformat > /dev/null 2>&1 || { echo "Error: SwiftFormat not found. Install with: brew install swiftformat"; exit 1; }
	@echo "Running SwiftFormat..."
	@swiftformat Sources/ Tests/

format-check: ## Check formatting without modifying files
	@command -v swiftformat > /dev/null 2>&1 || { echo "Error: SwiftFormat not found. Install with: brew install swiftformat"; exit 1; }
	@echo "Checking format..."
	@swiftformat --lint Sources/ Tests/

build: check-tools lint ## Build in debug mode (runs linter first)
	swift build

build-release: check-tools lint ## Build in release mode (runs linter first)
	swift build -c release

check: lint format-check test ## Run all checks (lint + format check + tests)
	@echo "All checks passed!"

run: build ## Build and run the app
	@mkdir -p "$(DEBUG_APP)/Contents/MacOS"
	@mkdir -p "$(DEBUG_APP)/Contents/Resources"
	@cp "$$(swift build --show-bin-path)/$(APP_NAME)" "$(DEBUG_APP)/Contents/MacOS/$(APP_NAME)"
	@cp "$(ICON_SRC)" "$(DEBUG_APP)/Contents/Resources/AppIcon.icns"
	@/usr/libexec/PlistBuddy -c "Clear dict" "$(DEBUG_APP)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy \
		-c "Add :CFBundleDevelopmentRegion string en" \
		-c "Add :CFBundleExecutable string $(APP_NAME)" \
		-c "Add :CFBundleIdentifier string $(BUNDLE_ID)" \
		-c "Add :CFBundleIconFile string AppIcon" \
		-c "Add :CFBundleName string $(APP_NAME)" \
		-c "Add :CFBundlePackageType string APPL" \
		-c "Add :CFBundleShortVersionString string 1.0.0" \
		-c "Add :CFBundleVersion string 1" \
		-c "Add :LSMinimumSystemVersion string 14.0" \
		-c "Add :NSHighResolutionCapable bool true" \
		"$(DEBUG_APP)/Contents/Info.plist"
	@codesign --force --sign - --entitlements "$(ENTITLEMENTS)" "$(DEBUG_APP)"
	@open "$(DEBUG_APP)"

test: check-tools ## Run tests
	swift test

app-bundle: build-release ## Create Propel.app bundle
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$$(swift build -c release --show-bin-path)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "$(ICON_SRC)" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@/usr/libexec/PlistBuddy -c "Clear dict" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy \
		-c "Add :CFBundleDevelopmentRegion string en" \
		-c "Add :CFBundleExecutable string $(APP_NAME)" \
		-c "Add :CFBundleIdentifier string $(BUNDLE_ID)" \
		-c "Add :CFBundleIconFile string AppIcon" \
		-c "Add :CFBundleName string $(APP_NAME)" \
		-c "Add :CFBundlePackageType string APPL" \
		-c "Add :CFBundleShortVersionString string 1.0.0" \
		-c "Add :CFBundleVersion string 1" \
		-c "Add :LSMinimumSystemVersion string 14.0" \
		-c "Add :NSHighResolutionCapable bool true" \
		-c "Add :NSSupportsAutomaticTermination bool true" \
		"$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --sign - --entitlements "$(ENTITLEMENTS)" "$(APP_BUNDLE)"
	@echo "Created $(APP_BUNDLE)"

dmg: app-bundle ## Create .dmg installer
	@rm -f "$(RELEASE_DIR)/$(DMG_NAME)"
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(APP_BUNDLE)" \
		-ov -format UDZO \
		"$(RELEASE_DIR)/$(DMG_NAME)"
	@echo "Created $(RELEASE_DIR)/$(DMG_NAME)"

install: app-bundle ## Install to /Applications
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed $(APP_NAME) to $(INSTALL_DIR)"

uninstall: ## Remove from /Applications (keeps data)
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Removed $(APP_NAME) from $(INSTALL_DIR)"
	@echo "Data is at: ~/Library/Application Support/Propel/"
	@echo "To delete data: rm -rf ~/Library/Application\\ Support/Propel/"

generate-icon: ## Regenerate app icon
	swift scripts/generate-icon.swift $(ICON_SRC)
	@echo "Generated $(ICON_SRC)"

clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR)
	@echo "Cleaned"
