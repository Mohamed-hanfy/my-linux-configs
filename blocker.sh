#!/bin/bash


API_KEY="J1TDIsFNhpOGgJ_xhhQOpPqTJtDnNz-n"  

# Check for required dependencies
check_dependencies() {
    command -v curl >/dev/null 2>&1 || {
 echo "Error: curl is required but not installed. Please install curl."
 exit 1
 }
    command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed. Please install jq."
 exit 1
 }
}


if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

get_cdn_info() {
    local domain=$1
    local cdn_domains=()
    
    echo "Fetching CDN information for $domain..."
    
    
    local response=$(curl -s --request GET \
        --url "https://api.securitytrails.com/v1/domain/$domain/subdomains" \
        --header "APIKEY: $API_KEY" \
        --header 'Accept: application/json')
    
    # Parse response with jq
    if echo "$response" | jq -e '.subdomains' >/dev/null 2>&1; then
        # Extract CDN-related subdomains
        while IFS= read -r subdomain; do
            cdn_domains+=("$subdomain.$domain")
        done < <(echo "$response" | jq -r '.subdomains[]' | grep -iE '(cdn|static|assets|media|content|img|js|css|api)')
    else
        echo "Warning: Could not fetch CDN information for $domain"
    fi
    
    # Fetch CNAME records for potential CDN endpoints
    local cname_response=$(curl -s --request GET \
        --url "https://api.securitytrails.com/v1/domain/$domain/dns" \
        --header "APIKEY: $API_KEY" \
        --header 'Accept: application/json')
    
    # Parse CNAME records for CDN providers
    if echo "$cname_response" | jq -e '.current_dns.cname_record' >/dev/null 2>&1; then
        while IFS= read -r cname; do
            if echo "$cname" | grep -qiE '(cloudfront|akamai|fastly|cloudflare|cdn)'; then
                cdn_domains+=("$cname")
            fi
        done < <(echo "$cname_response" | jq -r '.current_dns.cname_record[].hostname')
    fi
    
    echo "${cdn_domains[@]}"
}

# Function to clear browser caches
clear_browser_caches() {
    echo "Clearing browser caches..."
    
    # Chrome/Chromium
    if [ -d ~/.cache/google-chrome ]; then
        rm -rf ~/.cache/google-chrome/*
        echo "Chrome cache cleared"
    fi
    if [ -d ~/.cache/chromium ]; then
        rm -rf ~/.cache/chromium/*
        echo "Chromium cache cleared"
    fi
    
    # Firefox
    if [ -d ~/.mozilla/firefox ]; then
        find ~/.mozilla/firefox -type d -name "cache2" -exec rm -rf {} +
        echo "Firefox cache cleared"
    fi
    
    # Opera
    if [ -d ~/.cache/opera ]; then
        rm -rf ~/.cache/opera/*
        echo "Opera cache cleared"
    fi
    
    # Safari (for macOS)
    if [ -d ~/Library/Caches/com.apple.Safari ]; then
        rm -rf ~/Library/Caches/com.apple.Safari/*
        echo "Safari cache cleared"
    fi
    
    echo "Browser caches cleared."
}

# Function to get all domain patterns for a website
get_domain_patterns() {
    local site=$1
    local base_domain=${site#www.}
    
    # Main domain patterns
    local patterns=(
        "$base_domain"
        "www.$base_domain"
        "web.$base_domain"
        "m.$base_domain"
        "login.$base_domain"
    )
    
    # Get CDN domains from API
    local cdn_domains=( $(get_cdn_info "$base_domain") )
    patterns+=("${cdn_domains[@]}")
    
    echo "${patterns[@]}"
}

# Function to block websites
block_sites() {
    local sites=("$@")
    for site in "${sites[@]}"; do
        echo "# Blocking $site and related domains"
        
        # Get domain patterns including CDN information
        local domains=( $(get_domain_patterns "$site") )
        
        for domain in "${domains[@]}"; do
            if grep -q "^127\.0\.0\.1 $domain\$" /etc/hosts; then
                echo "$domain is already blocked."
            else
                echo "127.0.0.1 $domain" >> /etc/hosts
                echo "Blocked: $domain"
            fi
        done
        echo "" >> /etc/hosts  # Add blank line for readability
    done
    
    # Flush DNS cache
    if command -v systemd-resolve >/dev/null 2>&1; then
        systemd-resolve --flush-caches
    elif command -v dscacheutil >/dev/null 2>&1; then
        dscacheutil -flushcache
    fi
    
    # Clear browser caches
    clear_browser_caches
}

# Function to unblock websites
unblock_sites() {
    local sites=("$@")
    for site in "${sites[@]}"; do
        # Get domain patterns including CDN information
        local domains=( $(get_domain_patterns "$site") )
        
        for domain in "${domains[@]}"; do
            if grep -q "^127\.0\.0\.1 $domain\$" /etc/hosts; then
                sed -i "/^127\.0\.0\.1 $domain\$/d" /etc/hosts
                echo "Unblocked: $domain"
            fi
        done
        # Remove any empty lines
        sed -i '/^$/N;/^\n$/D' /etc/hosts
    done
    
    # Flush DNS cache
    if command -v systemd-resolve >/dev/null 2>&1; then
        systemd-resolve --flush-caches
    elif command -v dscacheutil >/dev/null 2>&1; then
        dscacheutil -flushcache
    fi
    
    # Clear browser caches
    clear_browser_caches
}


check_dependencies

# Main menu
while true; do
    echo -e "\nWebsite Blocker Menu:"
    echo "1. Block websites"
    echo "2. Unblock websites"
    echo "3. Block websites with timer"
    echo "4. View blocked websites"
    echo "5. Clear browser caches only"
    echo "6. Exit"
    read -p "Enter your choice (1-6): " choice

    case $choice in
        1)
            echo "Enter websites to block (space-separated, e.g., facebook.com twitter.com):"
            read -a websites
            block_sites "${websites[@]}"
            ;;
        2)
            echo "Enter websites to unblock (space-separated, e.g., facebook.com twitter.com):"
            read -a websites
            unblock_sites "${websites[@]}"
            ;;
        3)
            echo "Enter websites to block (space-separated, e.g., facebook.com twitter.com):"
            read -a websites
            echo "Enter blocking duration in minutes:"
            read duration
            block_sites "${websites[@]}"
            echo "Sites will be unblocked in $duration minutes."
            (sleep $(($duration * 60)) && unblock_sites "${websites[@]}") &
            ;;
        4)
            echo -e "\nCurrently blocked websites:"
            grep "^127\.0\.0\.1" /etc/hosts
            ;;
        5)
            clear_browser_caches
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
