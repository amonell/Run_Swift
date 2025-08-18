# Virtual Running Companion

An iOS app that enables runners to coordinate and run together remotely by synchronizing their pace and location data in real-time.

## Project Structure

```
VirtualRunningCompanion/
├── VirtualRunningCompanion.xcodeproj/     # Xcode project file
├── VirtualRunningCompanion/               # Main app source code
│   ├── Views/                            # SwiftUI views
│   ├── ViewModels/                       # MVVM ViewModels
│   ├── Services/                         # Business logic services
│   ├── Models/                           # Data models
│   ├── Assets.xcassets/                  # App assets and icons
│   ├── Preview Content/                  # SwiftUI preview assets
│   ├── VirtualRunningCompanionApp.swift  # App entry point
│   ├── VirtualRunningCompanion.entitlements # App capabilities
│   └── Info.plist                       # App configuration
├── Package.swift                         # Swift Package Manager
└── README.md                            # This file
```

## Features

- Real-time synchronized running with friends
- GPS tracking with pace and distance measurement
- Friend management and social features
- Run history and replay functionality
- HealthKit integration
- CloudKit data synchronization

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

## Capabilities Configured

- **Core Location**: GPS tracking and location services
- **HealthKit**: Health data integration
- **CloudKit**: Cloud data synchronization
- **Background Modes**: Location tracking, background processing, and background fetch

## Dependencies

- **SocketIO**: Real-time WebSocket communication for synchronized running sessions

## Getting Started

1. Open `VirtualRunningCompanion.xcodeproj` in Xcode
2. Configure your development team and bundle identifier
3. Build and run the project on a physical device (required for location services)

## Privacy Permissions

The app requests the following permissions:
- Location access (always and when in use) for run tracking
- HealthKit access for reading and writing health data

## Architecture

The app follows the MVVM (Model-View-ViewModel) pattern with:
- **Views**: SwiftUI-based user interface
- **ViewModels**: Business logic and state management using Combine
- **Services**: Location tracking, networking, and data persistence
- **Models**: Data structures and enums