# BBR Smart Installation Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)
[![Kernel](https://img.shields.io/badge/Kernel-4.9%2B-orange.svg)](https://www.kernel.org/)

<div align="right" dir="rtl">

> >**[🇮🇷 برای مطالعه راهنمای فارسی اینجا کلیک کنید](README-FA.md)**
</div>

<div align="center">
  <img src="https://raw.githubusercontent.com/vUnkname/BBR-Smart/main/screenshot.png" alt="BBR Smart Script Screenshot" width="529">
</div>


A smart, automated BBR (Bottleneck Bandwidth and Round-trip propagation time) TCP congestion control installation and management script for Linux systems. This script automatically detects your system capabilities and chooses the best BBR implementation method.

## 🚀 Features

- **🔍 Automatic System Detection**: Detects kernel version, distribution, and architecture
- **🧠 Smart Method Selection**: Chooses between modern (BBRv2) and legacy BBR methods
- **⚡ No Reboot Required**: Applies changes immediately without system restart
- **🛡️ Comprehensive Error Handling**: Robust error checking and user feedback
- **📊 Performance Testing**: Built-in network performance testing and comparison
- **🔧 Performance Optimizations**: Advanced TCP optimizations for maximum performance
- **💻 Virtualization Support**: Compatible with most virtualization platforms
- **📋 Interactive Menu**: User-friendly menu system for easy management
- **🔄 Easy Uninstallation**: Complete removal of BBR configurations

## 📋 System Requirements

- **Operating System**: Any Linux distribution
- **Kernel Version**: 4.9 or higher
- **Architecture**: x86_64, ARM64, or other supported architectures
- **Privileges**: Root access required
- **Virtualization**: Compatible with KVM, VMware, Xen (not OpenVZ/LXC)

## 🛠️ Installation

### Quick Installation (Recommended)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/vUnkname/BBR-Smart/main/bbr-smart.sh)
```

### Manual Installation

```bash
# Download the script
wget https://raw.githubusercontent.com/vUnkname/BBR-Smart/main/bbr-smart.sh

# Make it executable
chmod +x bbr-smart.sh

# Run with root privileges
sudo ./bbr-smart.sh
```

## 📖 Usage

### Interactive Mode

Run the script without arguments to access the interactive menu:

```bash
sudo ./bbr-smart.sh
```

### Command Line Mode

The script supports various command-line arguments for automation:

```bash
# Install BBR with optional performance testing
sudo ./bbr-smart.sh install

# Uninstall BBR completely
sudo ./bbr-smart.sh uninstall

# Check BBR status
sudo ./bbr-smart.sh status

# Show system information
sudo ./bbr-smart.sh info

# Test network performance before BBR
sudo ./bbr-smart.sh test-before

# Test network performance after BBR
sudo ./bbr-smart.sh test-after

# Compare performance results
sudo ./bbr-smart.sh compare

# Install network testing tools
sudo ./bbr-smart.sh install-tools

# Show performance test log
sudo ./bbr-smart.sh show-log
```

## 🔧 What BBR Does

BBR (Bottleneck Bandwidth and Round-trip propagation time) is a congestion control algorithm developed by Google that:

- **Improves Network Performance**: Significantly increases throughput and reduces latency
- **Optimizes Bandwidth Usage**: Better utilizes available network bandwidth
- **Reduces Bufferbloat**: Minimizes excessive buffering in network equipment
- **Works Globally**: Effective across various network conditions and topologies

### Performance Improvements

Typical improvements with BBR:
- **2-25x higher throughput** on long-distance connections
- **Reduced latency** by 25-40%
- **Better performance** on high-loss networks
- **Improved fairness** between competing flows

## 📊 Performance Testing

The script includes comprehensive network performance testing:

### Test Metrics
- **Download Speed**: Measures actual download throughput
- **Latency**: Tests round-trip time to Google DNS (8.8.8.8)
- **TCP Connection Time**: Measures connection establishment speed
- **Bandwidth**: Uses iperf3 for detailed bandwidth analysis

### Testing Workflow
1. Run performance test before BBR installation
2. Install and configure BBR
3. Run performance test after BBR installation
4. Compare results to see improvements

## 🏗️ Technical Details

### Modern Method (Kernel 5.4+)
- Uses BBRv2 with advanced optimizations
- Configures optimal buffer sizes
- Enables TCP Fast Open and MTU probing
- Applies modern TCP optimizations

### Legacy Method (Kernel 4.9-5.3)
- Uses standard BBR implementation
- Basic configuration for compatibility
- Maintains stability on older systems

### Configuration Files
- **Modern**: `/etc/sysctl.d/99-bbr-smart.conf`
- **Legacy**: Modifies `/etc/sysctl.conf`
- **Module Loading**: `/etc/modules-load.d/bbr-smart.conf`

## 🔍 Verification

After installation, verify BBR is working:

```bash
# Check congestion control algorithm
sysctl net.ipv4.tcp_congestion_control

# Verify BBR module is loaded
lsmod | grep tcp_bbr

# Use the script's verification
sudo ./bbr-smart.sh status
```

## 🚫 Uninstallation

To completely remove BBR and restore default settings:

```bash
sudo ./bbr-smart.sh uninstall
```

This will:
- Remove all BBR configuration files
- Reset to default congestion control (cubic)
- Clean up module loading configurations

## 🐛 Troubleshooting

### Common Issues

**BBR not activating after installation:**
- Ensure kernel version is 4.9 or higher
- Check if running in supported virtualization environment
- Verify tcp_bbr module is available

**Performance tests failing:**
- Install required tools: `sudo ./bbr-smart.sh install-tools`
- Check internet connectivity
- Ensure firewall allows outbound connections

**Script permission errors:**
- Run with sudo: `sudo ./bbr-smart.sh`
- Ensure script is executable: `chmod +x bbr-smart.sh`

### Supported Platforms

✅ **Supported:**
- Ubuntu 18.04+
- Debian 9+
- CentOS 7+
- RHEL 7+
- Fedora 28+
- Amazon Linux 2
- KVM, VMware, Xen virtualization

❌ **Not Supported:**
- OpenVZ containers
- LXC containers
- Kernels older than 4.9

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

### Development

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Google for developing the BBR algorithm
- Linux kernel developers for BBR implementation
- Community contributors and testers

## 📞 Support

If you encounter issues or have questions:

1. Check the [troubleshooting section](#-troubleshooting)
2. Search [existing issues](https://github.com/vUnkname/BBR-Smart/issues)
3. Create a [new issue](https://github.com/vUnkname/BBR-Smart/issues/new) with detailed information

## ⭐ Star History

If this project helped you, please consider giving it a star! ⭐

---

**Made with ❤️ for the community**