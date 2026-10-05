# Apple Watch / Apple Health

Browser and PWA code cannot directly read HealthKit.

Production architecture:

Apple Watch
-> Apple Health
-> iOS HealthKit companion
-> Aura Edge/API
-> `aura.health_samples`
-> Aura analytics

Raw HealthKit samples stay in Aura.

Only a daily summary should be surfaced to Nestora if the profile owner chooses.

Files included:
- HealthKitManager.swift
- WebViewBridge.swift
- entitlements
- Info.plist permission text

You need Xcode/macOS for the iOS target.