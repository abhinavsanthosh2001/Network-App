# Network Scanner + Wi-Fi Analyzer

A Flutter app for scanning local networks, analyzing Wi-Fi connections, and monitoring network devices.

## Features

### Phase 1 ✅ - Project Setup
- Dashboard with navigation
- All dependencies configured
- Platform permissions set up

### Phase 2 ✅- Get Network Info
- Current IP address
- Gateway & Subnet
- Wi-Fi SSID
- Signal strength

### Phase 3 - LAN Device Scanner
- Subnet sweep (ping IP range)
- Detect active hosts
- Device list with details

### Phase 4 - Device Detail Tools
- Ping test per device
- Latency graph
- Port check
- Device nicknames

### Phase 5 - Wi-Fi Analyzer
- Signal strength meter
- Channel info
- Signal history chart

### Phase 6 ✅ - Speed Test
- Download/upload test
- Latency measurement
- Result history

### Phase 7 - Interview Bonus
- Export network reports
- Background scanning
- Unknown device alerts
- Clean architecture
- Unit tests

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## Permissions

### Android
- INTERNET
- ACCESS_NETWORK_STATE
- ACCESS_WIFI_STATE
- ACCESS_FINE_LOCATION

### iOS
- NSLocationWhenInUseUsageDescription

## Tech Stack

- **State Management**: Riverpod
- **Networking**: http, dio, network_info_plus, connectivity_plus
- **Charts**: fl_chart
- **Permissions**: permission_handler
