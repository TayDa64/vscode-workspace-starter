#!/usr/bin/env bash

# vscode-workspace-starter: Setup script
# Installs extensions, merges settings, copies config files.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Find the directory where the script resides to locate config files
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
CONFIG_DIR="${SCRIPT_DIR}/config"
EXTENSIONS_FILE="${CONFIG_DIR}/extensions.list"
VSCODE_TEMPLATE_DIR="${CONFIG_DIR}/vscode"
TEMPLATE_SETTINGS_FILE="${CONFIG_DIR}/vscode/settings.json"
TEMPLATE_TASKS_FILE="${CONFIG_DIR}/vscode/tasks.json"
TEMPLATE_LAUNCH_FILE="${CONFIG_DIR}/vscode/launch.json"
TEMPLATE_KB_FILE="${CONFIG_DIR}/knowledgeBase.md"
TEMPLATE_EDITORCONFIG_FILE="${CONFIG_DIR}/.editorconfig"
TEMPLATE_ENV_EXAMPLE_FILE="${CONFIG_DIR}/.env.example"

# Target directory assumes running from the root of the target workspace
TARGET_VSCODE_DIR=".vscode"
TARGET_SETTINGS_FILE="${TARGET_VSCODE_DIR}/settings.json"
TARGET_TASKS_FILE="${TARGET_VSCODE_DIR}/tasks.json"
TARGET_LAUNCH_FILE="${TARGET_VSCODE_DIR}/launch.json"
TARGET_KB_FILE="knowledgeBase.md"
TARGET_EDITORCONFIG_FILE=".editorconfig"
TARGET_ENV_EXAMPLE_FILE=".env.example"

# --- Helper Functions ---
log_info() {
  echo -e "\033[0;34m[INFO] $1\033[0m"
}
log_success() {
  echo -e "\033[0;32m[SUCCESS] $1\033[0m"
}
log_warning() {
  echo -e "\033[0;33m[WARNING] $1\033[0m"
}
log_error() {
  echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}
command_exists() {
  command -v "$1" &> /dev/null
}

# --- Prerequisite Checks ---
log_info "Checking prerequisites..."
# Check for 'code' command
if ! command_exists code; then
  log_error "VS Code 'code' command not found in PATH. Please install it and ensure it's in your PATH."
  echo "See official VS Code documentation for command line setup on your OS."
  exit 1
fi
# Check for 'jq' command (needed for merging settings)
if ! command_exists jq; then
  log_error "'jq' command not found. Please install it (e.g., 'sudo apt install jq', 'brew install jq', 'choco install jq')."
  log_error "'jq' is required for merging workspace settings."
  exit 1
fi
log_success "Prerequisites met."

# --- Install Extensions ---
log_info "Checking and installing VS Code extensions from ${EXTENSIONS_FILE}..."
if [[ ! -f "$EXTENSIONS_FILE" ]]; then
  log_error "Extensions list file not found: ${EXTENSIONS_FILE}"
  exit 1
fi

# Get list of currently installed extensions ONCE for efficiency
installed_extensions=$(code --list-extensions) || {
    log_error "Failed to list installed VS Code extensions. Is 'code' command working correctly?"
    exit 1
}

while IFS= read -r extension_id || [[ -n "$extension_id" ]]; do
  # Trim whitespace
  extension_id=$(echo "$extension_id" | xargs)
  # Skip empty lines and comments
  if [[ -z "$extension_id" ]] || [[ "$extension_id" =~ ^# ]]; then
    continue
  fi

  # Check if extension is already installed (case-insensitive)
  if echo "${installed_extensions}" | grep -qi "^${extension_id}$"; then
    log_info "Extension already installed: ${extension_id}"
  else
    log_info "Installing extension: ${extension_id}..."
    if code --install-extension "$extension_id"; then
      log_success "Installed ${extension_id}"
    else
      log_warning "Failed to install ${extension_id}. It might be invalid, deprecated, or require manual installation."
      # Decide if you want to exit on failure: # exit 1
    fi
  fi
done < "$EXTENSIONS_FILE"
log_success "Extension check complete."

# --- Configure Workspace Settings ---
log_info "Configuring workspace settings (.vscode)..."
# Create target .vscode directory if it doesn't exist
mkdir -p "$TARGET_VSCODE_DIR" || { log_error "Failed to create directory ${TARGET_VSCODE_DIR}"; exit 1; }

# Process settings.json (Merge)
if [[ ! -f "$TEMPLATE_SETTINGS_FILE" ]]; then
    log_warning "Template settings file not found: ${TEMPLATE_SETTINGS_FILE}. Skipping settings configuration."
else
    log_info "Processing workspace settings: ${TARGET_SETTINGS_FILE}"
    if [[ -f "$TARGET_SETTINGS_FILE" ]]; then
        log_info "Existing settings file found. Merging template settings (user settings take precedence)..."
        MERGED_SETTINGS_TMP=$(mktemp) || { log_error "Failed to create temporary file."; exit 1; }
        # Merge: Existing * Template = Existing wins conflicts
        if jq -s '.[0] * .[1]' "$TARGET_SETTINGS_FILE" "$TEMPLATE_SETTINGS_FILE" > "$MERGED_SETTINGS_TMP"; then
            if jq empty "$MERGED_SETTINGS_TMP" &> /dev/null; then
                mv "$MERGED_SETTINGS_TMP" "$TARGET_SETTINGS_FILE" || { log_error "Failed to move merged settings to ${TARGET_SETTINGS_FILE}"; rm -f "$MERGED_SETTINGS_TMP"; exit 1; }
                log_success "Merged settings into ${TARGET_SETTINGS_FILE}"
            else
                 log_error "jq merge resulted in invalid JSON. Original file untouched."
                 rm -f "$MERGED_SETTINGS_TMP"
                 exit 1
            fi
        else
            jq_exit_code=$?
            log_error "Failed to merge settings using jq (exit code: ${jq_exit_code})."
            log_error "Please ensure both '${TARGET_SETTINGS_FILE}' and '${TEMPLATE_SETTINGS_FILE}' contain valid JSON."
            rm -f "$MERGED_SETTINGS_TMP"
            exit 1
        fi
    else
        log_info "No existing settings file found. Copying template settings..."
        if cp "$TEMPLATE_SETTINGS_FILE" "$TARGET_SETTINGS_FILE"; then
            log_success "Copied template settings to ${TARGET_SETTINGS_FILE}"
        else
            log_error "Failed to copy template settings to ${TARGET_SETTINGS_FILE}."
            exit 1
        fi
    fi
fi

# Process tasks.json (Copy/Overwrite)
if [[ -f "$TEMPLATE_TASKS_FILE" ]]; then
    if [[ -f "$TARGET_TASKS_FILE" ]]; then
        log_warning "Overwriting existing ${TARGET_TASKS_FILE} with template version."
    fi
    if cp "$TEMPLATE_TASKS_FILE" "$TARGET_TASKS_FILE"; then
        log_success "Copied/Updated ${TARGET_TASKS_FILE}"
    else
        log_error "Failed to copy ${TEMPLATE_TASKS_FILE} to ${TARGET_TASKS_FILE}."
        # exit 1 # Decide if critical
    fi
else
    log_info "Template tasks.json not found, skipping."
fi

# Process launch.json (Copy/Overwrite)
if [[ -f "$TEMPLATE_LAUNCH_FILE" ]]; then
    if [[ -f "$TARGET_LAUNCH_FILE" ]]; then
        log_warning "Overwriting existing ${TARGET_LAUNCH_FILE} with template version."
    fi
    if cp "$TEMPLATE_LAUNCH_FILE" "$TARGET_LAUNCH_FILE"; then
        log_success "Copied/Updated ${TARGET_LAUNCH_FILE}"
    else
         log_error "Failed to copy ${TEMPLATE_LAUNCH_FILE} to ${TARGET_LAUNCH_FILE}."
         # exit 1 # Decide if critical
    fi
else
    log_info "Template launch.json not found, skipping."
fi

# --- Copy Root Configuration Files ---

# Copy knowledgeBase.md (Skip if exists)
log_info "Processing knowledge base file..."
if [[ -f "$TEMPLATE_KB_FILE" ]]; then
    if [[ -f "$TARGET_KB_FILE" ]]; then
        log_warning "Existing ${TARGET_KB_FILE} found. Skipping copy of template."
        log_info "Consider manually merging content from ${TEMPLATE_KB_FILE} if needed."
    else
        if cp "$TEMPLATE_KB_FILE" "$TARGET_KB_FILE"; then
            log_success "Copied template ${TEMPLATE_KB_FILE} to ${TARGET_KB_FILE}"
        else
            log_error "Failed to copy template ${TEMPLATE_KB_FILE}."
            # exit 1 # Decide if critical
        fi
    fi
else
    log_warning "Template knowledge base file not found: ${TEMPLATE_KB_FILE}"
fi

# Copy .editorconfig (Skip if exists)
log_info "Processing .editorconfig file..."
if [[ -f "$TEMPLATE_EDITORCONFIG_FILE" ]]; then
    if [[ -f "$TARGET_EDITORCONFIG_FILE" ]]; then
        log_warning "Existing ${TARGET_EDITORCONFIG_FILE} found. Skipping copy of template."
    else
        if cp "$TEMPLATE_EDITORCONFIG_FILE" "$TARGET_EDITORCONFIG_FILE"; then
            log_success "Copied template ${TEMPLATE_EDITORCONFIG_FILE} to ${TARGET_EDITORCONFIG_FILE}"
        else
            log_error "Failed to copy template ${TEMPLATE_EDITORCONFIG_FILE}."
            # exit 1 # Decide if critical
        fi
    fi
else
    log_warning "Template .editorconfig file not found: ${TEMPLATE_EDITORCONFIG_FILE}"
fi

# Copy .env.example (Skip if exists)
log_info "Processing .env.example file..."
if [[ -f "$TEMPLATE_ENV_EXAMPLE_FILE" ]]; then
    if [[ -f "$TARGET_ENV_EXAMPLE_FILE" ]]; then
        log_warning "Existing ${TARGET_ENV_EXAMPLE_FILE} found. Skipping copy of template."
    else
        if cp "$TEMPLATE_ENV_EXAMPLE_FILE" "$TARGET_ENV_EXAMPLE_FILE"; then
            log_success "Copied template ${TEMPLATE_ENV_EXAMPLE_FILE} to ${TARGET_ENV_EXAMPLE_FILE}"
            log_info "ACTION REQUIRED: Rename ${TARGET_ENV_EXAMPLE_FILE} to .env and add your secrets."
            log_info "--> Ensure .env is listed in your project's .gitignore file! <--"
        else
            log_error "Failed to copy template ${TEMPLATE_ENV_EXAMPLE_FILE}."
            # exit 1 # Decide if critical
        fi
    fi
else
    log_warning "Template .env.example file not found: ${TEMPLATE_ENV_EXAMPLE_FILE}"
fi


# --- Final Message ---
log_success "VS Code workspace setup finished!"
log_info "You may need to reload the VS Code window ('Developer: Reload Window') for all changes to take effect."

exit 0
