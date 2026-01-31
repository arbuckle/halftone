# Halftone - macOS Metal Screen Effect App
# Makefile for building, installing, and managing the app

APP_NAME = Halftone
BUNDLE_ID = com.user.halftone
BUILD_DIR = build
INSTALL_DIR = /Applications
LAUNCH_AGENT_DIR = $(HOME)/Library/LaunchAgents
LAUNCH_AGENT = configs/com.user.halftone.plist

.PHONY: all build clean install uninstall debug run

# Default target
all: build

# Build the app in release mode
build:
	@echo "Building $(APP_NAME)..."
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo "Build complete: $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app"

# Build in debug mode
debug-build:
	@echo "Building $(APP_NAME) in debug mode..."
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build

# Run the debug build
debug: debug-build
	@echo "Running $(APP_NAME)..."
	open $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app

# Run the release build
run: build
	@echo "Running $(APP_NAME)..."
	open $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	xcodebuild -project $(APP_NAME).xcodeproj clean 2>/dev/null || true

# Install app to /Applications and set up LaunchAgent
install: build
	@echo "Installing $(APP_NAME)..."
	@# Stop running instance if any
	-launchctl unload $(LAUNCH_AGENT_DIR)/$(BUNDLE_ID).plist 2>/dev/null || true
	-pkill -x $(APP_NAME) 2>/dev/null || true
	@# Copy app bundle
	sudo rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	sudo cp -R $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app $(INSTALL_DIR)/
	@# Install LaunchAgent
	mkdir -p $(LAUNCH_AGENT_DIR)
	cp $(LAUNCH_AGENT) $(LAUNCH_AGENT_DIR)/$(BUNDLE_ID).plist
	@echo "Installation complete!"
	@echo ""
	@echo "To start automatically at login, run:"
	@echo "  launchctl load $(LAUNCH_AGENT_DIR)/$(BUNDLE_ID).plist"
	@echo ""
	@echo "To start now, run:"
	@echo "  open $(INSTALL_DIR)/$(APP_NAME).app"

# Uninstall app and LaunchAgent
uninstall:
	@echo "Uninstalling $(APP_NAME)..."
	@# Stop and unload LaunchAgent
	-launchctl unload $(LAUNCH_AGENT_DIR)/$(BUNDLE_ID).plist 2>/dev/null || true
	-pkill -x $(APP_NAME) 2>/dev/null || true
	@# Remove files
	rm -f $(LAUNCH_AGENT_DIR)/$(BUNDLE_ID).plist
	sudo rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Uninstallation complete!"

# Enable auto-start at login
enable-autostart:
	launchctl load $(LAUNCH_AGENT_DIR)/$(BUNDLE_ID).plist
	@echo "$(APP_NAME) will now start automatically at login"

# Disable auto-start at login
disable-autostart:
	-launchctl unload $(LAUNCH_AGENT_DIR)/$(BUNDLE_ID).plist 2>/dev/null || true
	@echo "$(APP_NAME) will no longer start automatically at login"

# Show help
help:
	@echo "Halftone - macOS Metal Screen Effect App"
	@echo ""
	@echo "Usage:"
	@echo "  make build          - Build release version"
	@echo "  make debug          - Build and run debug version"
	@echo "  make run            - Build and run release version"
	@echo "  make clean          - Remove build artifacts"
	@echo "  make install        - Install to /Applications"
	@echo "  make uninstall      - Remove from /Applications"
	@echo "  make enable-autostart  - Start at login"
	@echo "  make disable-autostart - Don't start at login"
	@echo ""
	@echo "Hotkey: Cmd+Shift+H to toggle effect"
