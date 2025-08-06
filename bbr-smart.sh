#!/bin/bash
#
# Smart BBR Installation Script
# Automatically chooses the best BBR method based on system capabilities
#
# Usage:
#   ./bbr-smart.sh                  # Interactive menu
#   ./bbr-smart.sh install          # Direct installation with optional testing
#   ./bbr-smart.sh uninstall        # Direct uninstallation
#   ./bbr-smart.sh status           # Check BBR status
#   ./bbr-smart.sh info             # Show system information
#   ./bbr-smart.sh test-before      # Test network performance before BBR
#   ./bbr-smart.sh test-after       # Test network performance after BBR
#   ./bbr-smart.sh compare          # Compare performance results
#   ./bbr-smart.sh install-tools    # Install network testing tools
#   ./bbr-smart.sh show-log         # Show performance test log
#
# Features:
# - Automatic system detection (kernel, distro, architecture)
# - Smart method selection (modern vs legacy)
# - No reboot required
# - Comprehensive error handling
# - Performance optimizations
# - Virtualization compatibility check
# - Network performance testing and comparison
#
# System Required: Any Linux distribution with kernel 4.9+
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r\033[34m[PROGRESS]\033[0m %s [" "$message"
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "] %d%%" $percentage
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# Check BBR status
check_bbr_status() {
    local param=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ x"${param}" == x"bbr" ]]; then
        echo "BBR is active"
        return 0
    else
        echo "BBR is inactive"
        return 1
    fi
}

# Check if running as root
[[ $EUID -ne 0 ]] && error "This script must be run as root"

# Network testing functions
test_network_performance() {
    local test_type="$1"
    echo
    echo "=== Network Performance Test ($test_type) ==="
    
    # Test 1: Download speed test using curl
    show_progress 1 5 "Testing download speed..."
    local download_speed=$(curl -o /dev/null -s -w '%{speed_download}' http://cachefly.cachefly.net/100mb.test 2>/dev/null || echo "0")
    download_speed=$(echo "scale=2; $download_speed / 1024 / 1024" | bc 2>/dev/null || echo "N/A")
    echo "  Download Speed: ${download_speed} MB/s"
    
    # Test 2: Latency test
    show_progress 2 5 "Testing latency to Google DNS..."
    local latency=$(ping -c 4 8.8.8.8 2>/dev/null | tail -1 | awk -F '/' '{print $5}' 2>/dev/null || echo "N/A")
    echo "  Average Latency: ${latency} ms"
    
    # Test 3: TCP connection test
    show_progress 3 5 "Testing TCP connection performance..."
    local tcp_test=$(curl -o /dev/null -s -w '%{time_connect},%{time_total}' http://www.google.com 2>/dev/null || echo "N/A,N/A")
    local connect_time=$(echo $tcp_test | cut -d',' -f1)
    local total_time=$(echo $tcp_test | cut -d',' -f2)
    echo "  TCP Connect Time: ${connect_time}s"
    echo "  Total Request Time: ${total_time}s"
    
    # Test 4: Bandwidth test using iperf3 if available
    show_progress 4 5 "Testing bandwidth with iperf3..."
    if command -v iperf3 >/dev/null 2>&1; then
        local iperf_result=$(timeout 10 iperf3 -c iperf.he.net -t 5 -f M 2>/dev/null | grep 'sender' | awk '{print $7" "$8}' || echo "N/A")
        echo "  Bandwidth: ${iperf_result}"
    else
        warn "iperf3 not available for bandwidth testing"
    fi
    
    # Save results to file
    show_progress 5 5 "Saving test results..."
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $test_type - Download: ${download_speed}MB/s, Latency: ${latency}ms, Connect: ${connect_time}s" >> /tmp/bbr-performance.log
    
    echo
}

compare_performance() {
    echo
    echo "=== Performance Comparison ==="
    
    if [ -f "/tmp/bbr-performance.log" ]; then
        info "Performance test results:"
        cat /tmp/bbr-performance.log
        echo
        
        local before_line=$(grep "BEFORE" /tmp/bbr-performance.log | tail -1)
        local after_line=$(grep "AFTER" /tmp/bbr-performance.log | tail -1)
        
        if [ -n "$before_line" ] && [ -n "$after_line" ]; then
            log "✅ Performance comparison completed!"
            info "Check the results above to see BBR impact"
        else
            warn "Incomplete test data. Run both before and after tests."
        fi
    else
        warn "No performance test data found"
    fi
}

check_both_tests_exist() {
    if [ -f "/tmp/bbr-performance.log" ]; then
        local before_count=$(grep -c "BEFORE" /tmp/bbr-performance.log 2>/dev/null || echo "0")
        local after_count=$(grep -c "AFTER" /tmp/bbr-performance.log 2>/dev/null || echo "0")
        
        if [ "$before_count" -gt 0 ] && [ "$after_count" -gt 0 ]; then
            return 0  # Both tests exist
        else
            return 1  # Missing one or both tests
        fi
    else
        return 1  # No log file
    fi
}

show_performance_log() {
    echo
    echo "=== Performance Test Log ==="
    
    if [ -f "/tmp/bbr-performance.log" ]; then
        info "Complete performance test history:"
        echo
        cat /tmp/bbr-performance.log
        echo
        
        # Show file info
        local file_size=$(du -h /tmp/bbr-performance.log 2>/dev/null | cut -f1)
        local file_date=$(stat -c %y /tmp/bbr-performance.log 2>/dev/null || stat -f %Sm /tmp/bbr-performance.log 2>/dev/null)
        info "Log file: /tmp/bbr-performance.log (${file_size}, last modified: ${file_date})"
        
        # Count test entries
        local before_count=$(grep -c "BEFORE" /tmp/bbr-performance.log 2>/dev/null || echo "0")
        local after_count=$(grep -c "AFTER" /tmp/bbr-performance.log 2>/dev/null || echo "0")
        info "Test entries: ${before_count} BEFORE tests, ${after_count} AFTER tests"
    else
        warn "No performance log file found at /tmp/bbr-performance.log"
        info "Run performance tests first to generate log data"
    fi
}

check_tools_installed() {
    local all_installed=true
    
    # Check if curl is installed
    if ! command -v curl >/dev/null 2>&1; then
        all_installed=false
    fi
    
    # Check if bc is installed
    if ! command -v bc >/dev/null 2>&1; then
        all_installed=false
    fi
    
    # Check if iperf3 is installed (optional but preferred)
    if ! command -v iperf3 >/dev/null 2>&1; then
        all_installed=false
    fi
    
    if [ "$all_installed" = true ]; then
        return 0  # All tools installed
    else
        return 1  # Some tools missing
    fi
}

install_test_tools() {
    info "Checking and installing network testing tools..."
    
    # Check what's already installed
    local missing_tools=()
    
    show_progress 1 5 "Checking curl..."
    sleep 0.5
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    show_progress 2 5 "Checking bc..."
    sleep 0.5
    if ! command -v bc >/dev/null 2>&1; then
        missing_tools+=("bc")
    fi
    
    show_progress 3 5 "Checking iperf3..."
    sleep 0.5
    if ! command -v iperf3 >/dev/null 2>&1; then
        missing_tools+=("iperf3")
    fi
    
    show_progress 4 5 "Analyzing requirements..."
    sleep 0.5
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        show_progress 5 5 "All tools verified!"
        log "✅ All network testing tools are already installed!"
        info "Installed tools: curl, bc, iperf3"
        return 0
    fi
    
    info "Missing tools: ${missing_tools[*]}"
    info "Installing missing tools..."
    
    # Detect package manager and install missing tools
    local total_tools=${#missing_tools[@]}
    local current_tool=0
    
    if command -v apt-get >/dev/null 2>&1; then
        show_progress 0 $((total_tools + 1)) "Updating package list..."
        apt-get update >/dev/null 2>&1
        
        for tool in "${missing_tools[@]}"; do
            current_tool=$((current_tool + 1))
            show_progress $current_tool $((total_tools + 1)) "Installing $tool..."
            apt-get install -y "$tool" >/dev/null 2>&1
        done
    elif command -v yum >/dev/null 2>&1; then
        for tool in "${missing_tools[@]}"; do
            current_tool=$((current_tool + 1))
            show_progress $current_tool $total_tools "Installing $tool..."
            yum install -y "$tool" >/dev/null 2>&1
        done
    elif command -v dnf >/dev/null 2>&1; then
        for tool in "${missing_tools[@]}"; do
            current_tool=$((current_tool + 1))
            show_progress $current_tool $total_tools "Installing $tool..."
            dnf install -y "$tool" >/dev/null 2>&1
        done
    else
        warn "Package manager not detected. Please install manually: ${missing_tools[*]}"
        return 1
    fi
    
    show_progress 5 5 "Installation completed!"
    log "Network testing tools installed successfully!"
}

# System detection functions
get_kernel_version() {
    uname -r | cut -d- -f1
}

get_kernel_major() {
    get_kernel_version | cut -d. -f1
}

get_kernel_minor() {
    get_kernel_version | cut -d. -f2
}

check_bbr_support() {
    local kernel_version=$(get_kernel_version)
    local major=$(get_kernel_major)
    local minor=$(get_kernel_minor)
    
    if (( major > 4 || (major == 4 && minor >= 9) )); then
        return 0
    else
        return 1
    fi
}

check_modern_kernel() {
    local major=$(get_kernel_major)
    local minor=$(get_kernel_minor)
    
    if (( major > 5 || (major == 5 && minor >= 4) )); then
        return 0
    else
        return 1
    fi
}

check_bbr_active() {
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "none")
    [[ "$current_cc" == "bbr" ]]
}

get_os_info() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "$NAME $VERSION_ID"
    elif [ -f /etc/redhat-release ]; then
        cat /etc/redhat-release
    else
        echo "Unknown Linux"
    fi
}

check_virtualization() {
    local virt="none"
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt=$(systemd-detect-virt 2>/dev/null || echo "none")
    elif command -v virt-what >/dev/null 2>&1; then
        virt=$(virt-what 2>/dev/null | head -1 || echo "none")
    fi
    echo "$virt"
}

# BBR installation methods
install_bbr_modern() {
    info "Installing BBR with modern optimizations (BBRv2 method)..."
    
    # Load tcp_bbr module
    show_progress 1 5 "Loading BBR kernel module..."
    modprobe tcp_bbr 2>/dev/null || true
    
    # Ensure BBR module is loaded at boot
    show_progress 2 5 "Configuring module auto-load..."
    mkdir -p /etc/modules-load.d
    echo "tcp_bbr" > /etc/modules-load.d/bbr-smart.conf
    
    # Create optimized sysctl config
    show_progress 3 5 "Creating optimized configuration..."
    cat <<EOF > /etc/sysctl.d/99-bbr-smart.conf
# BBR TCP Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Advanced TCP Optimizations
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1

# Buffer sizes
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864

# Network performance
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
EOF
    
    # Apply settings
    show_progress 4 5 "Applying system settings..."
    sysctl --system >/dev/null 2>&1
    
    show_progress 5 5 "Installation completed!"
    log "BBR with modern optimizations installed successfully!"
}

install_bbr_legacy() {
    info "Installing BBR with legacy compatibility method..."
    
    # Basic BBR configuration for older systems
    show_progress 1 4 "Cleaning old configurations..."
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    
    show_progress 2 4 "Adding BBR configuration..."
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    
    # Apply settings
    show_progress 3 4 "Applying settings..."
    sysctl -p >/dev/null 2>&1
    
    show_progress 4 4 "Installation completed!"
    log "BBR with legacy method installed successfully!"
}

install_kernel_and_bbr() {
    error "Your kernel version is too old ($(get_kernel_version)). Please upgrade to kernel 4.9+ and run this script again."
}

# System analysis and decision making
analyze_system() {
    local kernel_version=$(get_kernel_version)
    local os_info=$(get_os_info)
    local virt=$(check_virtualization)
    
    echo
    echo "=== System Analysis ==="
    info "OS: $os_info"
    info "Kernel: $kernel_version"
    info "Architecture: $(uname -m)"
    info "Virtualization: $virt"
    echo
    
    # Check for unsupported virtualization
    if [[ "$virt" == "openvz" ]] || [[ "$virt" == "lxc" ]]; then
        error "Virtualization method '$virt' is not supported for BBR"
    fi
    
    # Decision logic
    if check_bbr_active; then
        log "BBR is already active on this system!"
        sysctl net.ipv4.tcp_congestion_control
        return 0
    fi
    
    if ! check_bbr_support; then
        warn "Kernel version $(get_kernel_version) is too old for BBR"
        install_kernel_and_bbr
        return 1
    fi
    
    if check_modern_kernel; then
        info "Modern kernel detected - using optimized BBR method"
        install_bbr_modern
    else
        info "Legacy kernel detected - using compatible BBR method"
        install_bbr_legacy
    fi
}

# Verification function
verify_bbr() {
    echo
    echo "=== BBR Verification ==="
    
    if check_bbr_active; then
        log "✅ BBR is ACTIVE!"
        info "Current congestion control: $(sysctl -n net.ipv4.tcp_congestion_control)"
        
        if lsmod | grep -q tcp_bbr; then
            log "✅ tcp_bbr module is loaded"
        else
            warn "⚠️ tcp_bbr module is not loaded"
        fi
        
        if check_modern_kernel; then
            info "💡 Modern kernel optimizations applied - no reboot needed"
        else
            info "💡 Legacy optimizations applied - no reboot needed"
        fi
    else
        warn "⚠️ BBR is not active"
        info "Current congestion control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'unknown')"
        
        if check_bbr_support; then
            info "💡 System supports BBR but it's not currently active"
        else
            warn "❌ System does not support BBR (kernel 4.9+ required)"
        fi
    fi
}

# Uninstall functions
uninstall_bbr_modern() {
    info "Removing BBR modern configuration..."
    
    # Remove sysctl config file
    show_progress 1 4 "Removing sysctl configuration..."
    if [ -f "/etc/sysctl.d/99-bbr-smart.conf" ]; then
        rm -f /etc/sysctl.d/99-bbr-smart.conf
        log "Removed modern BBR sysctl configuration"
    fi
    
    # Remove module loading config
    show_progress 2 4 "Removing module configuration..."
    if [ -f "/etc/modules-load.d/bbr-smart.conf" ]; then
        rm -f /etc/modules-load.d/bbr-smart.conf
        log "Removed BBR module loading configuration"
    fi
    
    # Reset to default congestion control
    show_progress 3 4 "Resetting to default settings..."
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=pfifo_fast >/dev/null 2>&1
    
    show_progress 4 4 "Uninstallation completed!"
    log "BBR modern configuration removed successfully!"
}

uninstall_bbr_legacy() {
    info "Removing BBR legacy configuration..."
    
    # Remove BBR settings from sysctl.conf
    show_progress 1 3 "Cleaning sysctl.conf..."
    sed -i '/net.core.default_qdisc = fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control = bbr/d' /etc/sysctl.conf
    
    # Reset to default congestion control
    show_progress 2 3 "Resetting to default settings..."
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=pfifo_fast >/dev/null 2>&1
    
    show_progress 3 3 "Uninstallation completed!"
    log "BBR legacy configuration removed successfully!"
}

detect_bbr_installation_type() {
    if [ -f "/etc/sysctl.d/99-bbr-smart.conf" ]; then
        echo "modern"
    elif grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf 2>/dev/null; then
        echo "legacy"
    else
        echo "none"
    fi
}

uninstall_bbr() {
    local install_type=$(detect_bbr_installation_type)
    
    if [ "$install_type" == "none" ]; then
        warn "No BBR installation detected"
        return 1
    fi
    
    echo
    echo "=== BBR Uninstallation ==="
    info "Detected installation type: $install_type"
    
    case "$install_type" in
        "modern")
            uninstall_bbr_modern
            ;;
        "legacy")
            uninstall_bbr_legacy
            ;;
    esac
    
    # Verify uninstallation
    if ! check_bbr_active; then
        log "✅ BBR has been successfully removed"
        info "Current congestion control: $(sysctl -n net.ipv4.tcp_congestion_control)"
    else
        warn "⚠️ BBR might still be active. Please reboot the system."
    fi
}

# Menu system
show_menu() {
    clear
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    BBR Smart Installation                    ║"
    echo "║                     Management Script                        ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Current Status:                                             ║"
    if check_bbr_active; then
        echo "║  BBR Status: ACTIVE                                          ║"
        local install_type=$(detect_bbr_installation_type)
        echo "║  Installation Type: $(printf '%-35s' "$install_type")║"
        
        # Display appropriate congestion control based on installation type
        local cc_display
        if [ "$install_type" = "modern" ]; then
            cc_display="BBRv2"
        else
            cc_display="BBR"
        fi
        echo "║  Congestion Control: $(printf '%-32s' "$cc_display")║"
    else
        echo "║  BBR Status: INACTIVE                                        ║"
    fi
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  1) Install/Activate BBR                                     ║"
    echo "║  2) Uninstall/Deactivate BBR                                 ║"
    echo "║  3) Show System Information                                  ║"
    echo "║  4) Verify BBR Status                                        ║"
    
    local option_num=5
    
    # Show test options based on BBR status
    local bbr_status=$(check_bbr_status)
    if [ "$bbr_status" = "BBR is active" ]; then
        echo "║  ${option_num}) Test Network Performance                                 ║"
        option_num=$((option_num + 1))
    else
        echo "║  ${option_num}) Test Network Performance (Before BBR)                    ║"
        option_num=$((option_num + 1))
        echo "║  ${option_num}) Test Network Performance (After BBR)                     ║"
        option_num=$((option_num + 1))
    fi
    
    # Show compare option only if both tests exist
    if check_both_tests_exist; then
        echo "║  ${option_num}) Compare Performance Results                              ║"
        option_num=$((option_num + 1))
    fi
    
    # Show install tools option only if some tools are missing
    if ! check_tools_installed; then
        echo "║  ${option_num}) Install Testing Tools                                    ║"
        option_num=$((option_num + 1))
    fi
    
    # Show log option only if log file exists
    if [ -f "/tmp/bbr-performance.log" ]; then
        echo "║  ${option_num}) Show Performance Log                                     ║"
        option_num=$((option_num + 1))
    fi
    
    local max_option=$((option_num - 1))
    echo "║  0) Exit                                                     ║"
    
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    
    # Store max option for validation
    export MENU_MAX_OPTION=$max_option
}

install_bbr_menu() {
    echo
    echo "=== BBR Installation ==="
    
    if check_bbr_active; then
        log "BBR is already active on this system!"
        sysctl net.ipv4.tcp_congestion_control
        return 0
    fi
    
    # Ask user if they want performance testing
    echo
    read -p "Do you want to run performance tests before and after BBR installation? (y/n): " run_tests
    
    local perform_tests=false
    if [[ "$run_tests" =~ ^[Yy]$ ]]; then
        perform_tests=true
        info "Performance testing enabled. This will:"
        echo "  1. Test network performance before BBR installation"
        echo "  2. Install BBR"
        echo "  3. Test network performance after BBR installation"
        echo "  4. Compare and show results"
        echo
        read -p "Press Enter to continue..."
        
        # Install testing tools if needed
        info "Checking and installing required testing tools..."
        install_test_tools
        
        # Run before test
        info "Running performance test before BBR installation..."
        test_network_performance "BEFORE"
    fi
    
    analyze_system
    
    # Only verify if installation was successful
    if check_bbr_active; then
        verify_bbr
        echo
        log "BBR installation completed successfully!"
        
        if [ "$perform_tests" = true ]; then
            info "Running performance test after BBR installation..."
            test_network_performance "AFTER"
            echo
            info "Comparing performance results..."
            compare_performance
        fi
    else
        echo
        warn "BBR installation may have failed. Please check system compatibility."
        verify_bbr
    fi
}

show_system_info() {
    local kernel_version=$(get_kernel_version)
    local os_info=$(get_os_info)
    local virt=$(check_virtualization)
    
    echo
    echo "=== System Information ==="
    info "OS: $os_info"
    info "Kernel: $kernel_version"
    info "Architecture: $(uname -m)"
    info "Virtualization: $virt"
    
    if check_bbr_support; then
        log "✅ System supports BBR"
    else
        warn "❌ System does not support BBR (kernel 4.9+ required)"
    fi
    
    if check_modern_kernel; then
        info "💡 Modern kernel detected - optimized method available"
    else
        info "💡 Legacy kernel detected - compatible method available"
    fi
}

# BBR installation function
install_bbr_actual() {
    if ! check_bbr_support; then
        warn "Kernel version $(get_kernel_version) is too old for BBR"
        install_kernel_and_bbr
        return 1
    fi
    
    if check_modern_kernel; then
        info "Modern kernel detected - using optimized BBR method"
        install_bbr_modern
    else
        info "Legacy kernel detected - using compatible BBR method"
        install_bbr_legacy
    fi
}

# Main execution
main() {
    # Check if script is run with arguments (non-interactive mode)
    if [ $# -gt 0 ]; then
        case "$1" in
            "install")
                install_bbr_menu
                ;;
            "uninstall")
                uninstall_bbr
                ;;
            "status")
                verify_bbr
                ;;
            "info")
                show_system_info
                ;;
            "test-before")
                test_network_performance "BEFORE"
                ;;
            "test-after")
                test_network_performance "AFTER"
                ;;
            "compare")
                compare_performance
                ;;
            "install-tools")
                install_test_tools
                ;;
            "show-log")
                show_performance_log
                ;;
            *)
                echo "Usage: $0 [install|uninstall|status|info|test-before|test-after|compare|install-tools|show-log]"
                exit 1
                ;;
        esac
        return
    fi
    
    # Interactive menu mode
    while true; do
        show_menu
        read -p "Please select an option [0-${MENU_MAX_OPTION:-8}]: " choice
        
        # Handle fixed options first
        case $choice in
            1)
                install_bbr_menu
                read -p "Press Enter to continue..."
                continue
                ;;
            2)
                uninstall_bbr
                read -p "Press Enter to continue..."
                continue
                ;;
            3)
                show_system_info
                read -p "Press Enter to continue..."
                continue
                ;;
            4)
                verify_bbr
                read -p "Press Enter to continue..."
                continue
                ;;
            0)
                echo
                log "Thank you for using Smart BBR Management Script!"
                exit 0
                ;;
        esac
        
        # Handle dynamic options
        local option_num=5
        local bbr_status=$(check_bbr_status)
        
        # Test options based on BBR status
        if [ "$bbr_status" = "BBR is active" ]; then
            if [ "$choice" = "$option_num" ]; then
                test_network_performance "CURRENT"
                read -p "Press Enter to continue..."
                continue
            fi
            option_num=$((option_num + 1))
        else
            if [ "$choice" = "$option_num" ]; then
                test_network_performance "BEFORE"
                read -p "Press Enter to continue..."
                continue
            fi
            option_num=$((option_num + 1))
            
            if [ "$choice" = "$option_num" ]; then
                 # Check if BEFORE test has been run
                 if [ -f "/tmp/bbr-performance.log" ] && grep -q "BEFORE" /tmp/bbr-performance.log 2>/dev/null; then
                     test_network_performance "AFTER"
                 else
                     echo
                     warn "⚠️  You must run 'Test Network Performance (Before BBR)' first!"
                     info "Please follow this order:"
                     echo "  1. Run 'Test Network Performance (Before BBR)'"
                     echo "  2. Install BBR (if not already installed)"
                     echo "  3. Run 'Test Network Performance (After BBR)'"
                     echo
                 fi
                 read -p "Press Enter to continue..."
                 continue
             fi
            option_num=$((option_num + 1))
        fi
        
        # Compare option
        if check_both_tests_exist; then
            if [ "$choice" = "$option_num" ]; then
                compare_performance
                read -p "Press Enter to continue..."
                continue
            fi
            option_num=$((option_num + 1))
        fi
        
        # Install tools option
        if ! check_tools_installed; then
            if [ "$choice" = "$option_num" ]; then
                install_test_tools
                read -p "Press Enter to continue..."
                continue
            fi
            option_num=$((option_num + 1))
        fi
        
        # Show log option
        if [ -f "/tmp/bbr-performance.log" ]; then
            if [ "$choice" = "$option_num" ]; then
                show_performance_log
                read -p "Press Enter to continue..."
                continue
            fi
            option_num=$((option_num + 1))
        fi
        
        # Invalid option
        warn "Invalid option. Please try again."
        sleep 2
    done
}

# Run main function
main "$@"