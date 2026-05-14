#!/usr/bin/env bash
# @script
# purpose: RKN Domains Integration Script
#

set -euo pipefail

# RKN Domains Integration Script
# Provides manual fallback and integration with existing systems

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/pretty.sh"

# Configuration
CONFIG_DIR="${HOME}/.config/rkn-domains-fetcher"
STATE_DIR="${HOME}/.local/state/rkn-domains-fetcher"
OUTPUT_FILE="${STATE_DIR}/rkn-domains.txt"
STATE_FILE="${STATE_DIR}/state.json"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

VPN_SPLIT_ROUTER_CONFIG="${HOME}/.config/vpn-split-router/config.yaml"
SINGBOX_CONFIG="${HOME}/.config/sing-box-tun/config-no-auto-route.json"

# Logging (delegates to pretty.sh)
log_info() { pretty::info "$*"; }
log_success() { pretty::ok "$*"; }
log_warning() { pretty::warn "$*"; }
log_error() { pretty::fail "$*"; }

# Ensure directories exist
ensure_directories() {
    mkdir -p "$CONFIG_DIR" "$STATE_DIR" "$(dirname "$VPN_SPLIT_ROUTER_CONFIG")"
}

# Generate default config if not exists
generate_default_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
settings:
  update_interval_hours: 24
  max_domains: 50000
  domain_validation: true
  exclude_patterns:
    - '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'  # IP addresses
    - '^[0-9]+$'                          # Just numbers
    - '\.(onion|i2p)$'                    # Tor/I2P domains
  include_patterns:
    - '\.(com|org|net|ru|info|biz|online|site|xyz|top|club|shop|store|app|dev|ai|io)$'
  fallback_enabled: true
  fallback_retry_count: 3
  fallback_retry_delay_seconds: 5

sources:
  primary: "https://raw.githubusercontent.com/EikeiDev/domains/main/domains.lst"
  backups:
    - "https://raw.githubusercontent.com/zapret-info/z-i/master/dump.csv"
    - "https://raw.githubusercontent.com/antifilter/filterlist/master/antifilter.list"

integration:
  vpn_split_router:
    enabled: true
    auto_mark_vpn: true
    categories:
      social_media: ["twitter", "facebook", "instagram", "tiktok", "whatsapp", "discord", "telegram"]
      ai_services: ["claude", "openai", "chatgpt", "anthropic", "openrouter"]
      video: ["youtube", "twitch", "reddit"]
      torrents: ["1337x", "piratebay", "rutracker", "rutor"]
      porn: ["pornhub", "xvideos", "xhamster", "onlyfans", "nhentai", "hentai"]
      drugs: ["weed", "cocaine", "drugs"]
      gambling: ["gambling", "casino", "bet"]
      vpn_proxy: ["vpn", "proxy"]

  singbox:
    enabled: true
    config_path: "~/.config/sing-box-tun/config-no-auto-route.json"
    rule_tag: "rkn-blocked-domains"
EOF
        log_success "Generated default config at $CONFIG_FILE"
    fi
}

# Manual fetch with wget2 (fastest)
manual_fetch_wget2() {
    local url="$1"
    local output_file="$2"
    
    log_info "Downloading from $url using wget2..."
    
    if ! command -v wget2 &> /dev/null; then
        log_error "wget2 not found. Install with: sudo pacman -S wget2"
        return 1
    fi
    
    if wget2 -q -O- "$url" > "$output_file.tmp"; then
        mv "$output_file.tmp" "$output_file"
        log_success "Downloaded to $output_file"
        return 0
    else
        rm -f "$output_file.tmp"
        log_error "Download failed"
        return 1
    fi
}

# Fallback fetch with curl
manual_fetch_curl() {
    local url="$1"
    local output_file="$2"
    
    log_info "Trying curl as fallback..."
    
    if curl -s -f -L "$url" > "$output_file.tmp"; then
        mv "$output_file.tmp" "$output_file"
        log_success "Downloaded with curl"
        return 0
    else
        rm -f "$output_file.tmp"
        log_error "Curl download failed"
        return 1
    fi
}

# Ultra fallback - use Python
manual_fetch_python() {
    local url="$1"
    local output_file="$2"
    
    log_info "Trying Python as ultra fallback..."
    
    python3 -c "
import urllib.request
import sys
try:
    with urllib.request.urlopen('$url', timeout=30) as response:
        data = response.read().decode('utf-8')
        with open('$output_file.tmp', 'w') as f:
            f.write(data)
        print('Downloaded with Python')
        sys.exit(0)
except Exception as e:
    print(f'Python download failed: {e}')
    sys.exit(1)
" && mv "$output_file.tmp" "$output_file"
}

# Process domains (filter and validate)
process_domains() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "Processing domains..."
    
    # Simple domain validation regex
    local domain_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'
    
    # Filter and sort
    grep -E "$domain_regex" "$input_file" | \
        grep -v -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
        grep -v '^[0-9]+$' | \
        sort -u > "$output_file.tmp"
    
    local count
    count=$(wc -l < "$output_file.tmp")
    mv "$output_file.tmp" "$output_file"
    
    log_success "Processed $count valid domains"
}

# Integrate with VPN split router
integrate_vpn_split_router() {
    local domains_file="$1"
    
    if [[ ! -f "$VPN_SPLIT_ROUTER_CONFIG" ]]; then
        log_warning "VPN split router config not found: $VPN_SPLIT_ROUTER_CONFIG"
        return 1
    fi
    
    log_info "Integrating with VPN split router..."
    
    # Extract important domains (AI services, social media)
    local important_domains=()
    while IFS= read -r domain; do
        domain_lower=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
        
        # Check if domain contains important keywords
        if [[ "$domain_lower" =~ (claude|openai|chatgpt|anthropic|twitter|facebook|instagram|tiktok|youtube|twitch|reddit) ]]; then
            important_domains+=("$domain")
        fi
    done < "$domains_file"
    
    if [[ ${#important_domains[@]} -eq 0 ]]; then
        log_warning "No important domains found for VPN split router"
        return 0
    fi
    
    # Load existing config
    if ! command -v yq &> /dev/null; then
        log_warning "yq not found, using simple text processing"
        
        # Simple YAML processing
        if grep -q "seed_domains:" "$VPN_SPLIT_ROUTER_CONFIG"; then
            # Append to existing seed_domains
            sed -i "/seed_domains:/a\\  - $domain" "$VPN_SPLIT_ROUTER_CONFIG" 2>/dev/null || true
        else
            # Add seed_domains section
            echo "seed_domains:" >> "$VPN_SPLIT_ROUTER_CONFIG"
            for domain in "${important_domains[@]}"; do
                echo "  - $domain" >> "$VPN_SPLIT_ROUTER_CONFIG"
            done
        fi
    else
        # Use yq for proper YAML manipulation
        local temp_file
        temp_file=$(mktemp)
        
        # Get current seed domains
        local current_seed=()
        if yq eval '.seed_domains[]' "$VPN_SPLIT_ROUTER_CONFIG" 2>/dev/null; then
            mapfile -t current_seed < <(yq eval '.seed_domains[]' "$VPN_SPLIT_ROUTER_CONFIG")
        fi
        
        # Merge and deduplicate
        local all_domains=("${current_seed[@]}" "${important_domains[@]}")
        local unique_domains=()
        mapfile -t unique_domains < <(printf "%s\n" "${all_domains[@]}" | sort -u)
        
        # Update config
        yq eval ".seed_domains = []" "$VPN_SPLIT_ROUTER_CONFIG" > "$temp_file"
        for domain in "${unique_domains[@]}"; do
            yq eval ".seed_domains += [\"$domain\"]" "$temp_file" > "${temp_file}.2"
            mv "${temp_file}.2" "$temp_file"
        done
        
        mv "$temp_file" "$VPN_SPLIT_ROUTER_CONFIG"
    fi
    
    log_success "Integrated ${#important_domains[@]} domains with VPN split router"
}

# Integrate with sing-box
integrate_singbox() {
    local domains_file="$1"
    
    if [[ ! -f "$SINGBOX_CONFIG" ]]; then
        log_warning "sing-box config not found: $SINGBOX_CONFIG"
        return 1
    fi
    
    log_info "Integrating with sing-box..."
    
    # Convert domains to sing-box rule format
    local domains_json="["
    first=true
    while IFS= read -r domain; do
        if [[ -n "$domain" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                domains_json+=","
            fi
            domains_json+="\"$domain\""
        fi
    done < <(head -1000 "$domains_file")  # Limit to 1000 domains
    
    domains_json+="]"
    
    # Create temporary config
    local temp_file
    temp_file=$(mktemp)
    jq --argjson domains "$domains_json" '
        .route.rules = [
            {
                "tag": "rkn-blocked-domains",
                "domain_suffix": $domains,
                "outbound": "proxy"
            }
        ] + (.route.rules // [])
    ' "$SINGBOX_CONFIG" > "$temp_file"
    
    if jq empty "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$SINGBOX_CONFIG"
        log_success "Integrated domains with sing-box"
    else
        rm -f "$temp_file"
        log_error "Failed to update sing-box config (invalid JSON)"
        return 1
    fi
}

# Create systemd timer for automatic updates
create_systemd_timer() {
    local service_name="rkn-domains-fetcher"
    local service_file="${HOME}/.config/systemd/user/${service_name}.service"
    local timer_file="${HOME}/.config/systemd/user/${service_name}.timer"
    
    log_info "Creating systemd timer..."
    
    # Create service file
    cat > "$service_file" << EOF
[Unit]
Description=RKN Blocked Domains Fetcher
After=network-online.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_DIR}/rkn-domains-fetcher.py fetch --integrate
Environment=PYTHONUNBUFFERED=1
WorkingDirectory=${SCRIPT_DIR}

[Install]
WantedBy=default.target
EOF
    
    # Create timer file
    cat > "$timer_file" << EOF
[Unit]
Description=Daily RKN domains update

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start
    systemctl --user daemon-reload
    systemctl --user enable --now "${service_name}.timer"
    
    log_success "Systemd timer created and enabled"
    log_info "Next run: $(systemctl --user list-timers "${service_name}.timer" --no-pager | grep "${service_name}.timer" | awk '{print $3 " " $4}')"
}

# Emergency fallback - use local cache or minimal list
emergency_fallback() {
    log_warning "Entering emergency fallback mode..."
    
    # Check for local cache
    if [[ -f "$OUTPUT_FILE" ]]; then
        local file_age=$(( $(date +%s) - $(stat -c %Y "$OUTPUT_FILE") ))
        local max_age=$(( 7 * 24 * 3600 ))  # 7 days
        
        if [[ $file_age -lt $max_age ]]; then
            log_info "Using cached domains file (age: $((file_age/3600)) hours)"
            return 0
        fi
    fi
    
    # Create minimal essential list
    log_info "Creating minimal essential domains list..."
    
    cat > "$OUTPUT_FILE" << 'EOF'
twitter.com
instagram.com
facebook.com
tiktok.com
whatsapp.com
discord.com
telegram.org
youtube.com
twitch.tv
reddit.com
claude.ai
openai.com
chatgpt.com
anthropic.com
1337x.to
piratebay.org
rutracker.org
pornhub.com
xvideos.com
xhamster.com
onlyfans.com
EOF
    
    log_success "Created minimal essential domains list"
}

# Main manual workflow
manual_workflow() {
    local url="${1:-https://raw.githubusercontent.com/EikeiDev/domains/main/domains.lst}"
    local temp_file
    temp_file=$(mktemp)
    
    log_info "Starting manual RKN domains update"
    log_info "Source: $url"
    
    # Try multiple download methods
    if ! manual_fetch_wget2 "$url" "$temp_file"; then
        if ! manual_fetch_curl "$url" "$temp_file"; then
            if ! manual_fetch_python "$url" "$temp_file"; then
                log_error "All download methods failed"
                emergency_fallback
                rm -f "$temp_file"
                return 1
            fi
        fi
    fi
    
    # Process domains
    process_domains "$temp_file" "$OUTPUT_FILE"
    
    # Integrate with systems
    integrate_vpn_split_router "$OUTPUT_FILE"
    
    if [[ -f "$SINGBOX_CONFIG" ]] && command -v jq &> /dev/null; then
        integrate_singbox "$OUTPUT_FILE"
    fi
    
    # Update state
    echo "{\"last_update\": \"$(date -Iseconds)\", \"source\": \"$url\"}" > "$STATE_FILE"
    
    log_success "Manual update completed successfully"
    rm -f "$temp_file"
}

# Show status
show_status() {
    log_info "RKN Domains Fetcher Status"
    echo "========================================"
    
    if [[ -f "$STATE_FILE" ]]; then
        echo "Last update: $(jq -r '.last_update // "Never"' "$STATE_FILE")"
        echo "Source: $(jq -r '.source // "Unknown"' "$STATE_FILE")"
    else
        echo "Last update: Never"
    fi
    
    if [[ -f "$OUTPUT_FILE" ]]; then
        local count
        count=$(wc -l < "$OUTPUT_FILE")
        echo "Domains in file: $count"
        echo "File: $OUTPUT_FILE"
        
        # Show sample
        echo -e "\nSample domains:"
        head -5 "$OUTPUT_FILE" | while read -r domain; do
            echo "  • $domain"
        done
    else
        echo "Domains file: Not found"
    fi
    
    # Check systemd timer
    if systemctl --user list-timers --no-pager | grep -q "rkn-domains-fetcher"; then
        echo -e "\nSystemd timer: Active"
    else
        echo -e "\nSystemd timer: Not configured"
    fi
}

# Print usage
print_usage() {
    cat << EOF
RKN Domains Integration Script

Usage: $0 [command]

Commands:
  manual [URL]    Manual update from URL (default: EikeiDev list)
  auto            Configure automatic updates (systemd timer)
  status          Show current status
  emergency       Create emergency fallback list
  integrate       Integrate current domains with systems
  help            Show this help

Examples:
  $0 manual                            # Update from default source
  $0 manual https://example.com/list   # Update from custom URL
  $0 auto                              # Enable automatic updates
  $0 status                            # Show current status
  $0 emergency                         # Create emergency fallback list

Integration:
  • Downloads RKN blocked domains list
  • Filters and validates domains
  • Integrates with VPN split router
  • Integrates with sing-box (if available)
  • Provides multiple fallback methods
  • Supports automatic updates via systemd

EOF
}

# Main function
main() {
    ensure_directories
    generate_default_config
    
    local command="${1:-help}"
    
    case "$command" in
        manual)
            manual_workflow "${2:-}"
            ;;
        auto)
            create_systemd_timer
            ;;
        status)
            show_status
            ;;
        emergency)
            emergency_fallback
            ;;
        integrate)
            if [[ -f "$OUTPUT_FILE" ]]; then
                integrate_vpn_split_router "$OUTPUT_FILE"
                integrate_singbox "$OUTPUT_FILE"
            else
                log_error "No domains file found. Run 'manual' first."
                exit 1
            fi
            ;;
        help|--help|-h)
            print_usage
            ;;
        *)
            log_error "Unknown command: $command"
            print_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
