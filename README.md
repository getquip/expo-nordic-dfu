# Expo Nordic DFU

This project was highly inspired by the original React Native project at [Pilloxa/react-native-nordic-dfu](https://github.com/Pilloxa/react-native-nordic-dfu). We continued the work so it functions with modern [Expo](http://expo.dev/) projects that use [Expo Modules](https://docs.expo.dev/modules/overview/).

This module allows you to perform a Secure Device Firmware Update (DFU) for Nordic Semiconductors on Expo React Native bridgeless projects. It wraps the official libraries at [NordicSemiconductor/Android-DFU-Library](https://github.com/NordicSemiconductor/Android-DFU-Library) and [NordicSemiconductor/IOS-DFU-Library](https://github.com/NordicSemiconductor/IOS-DFU-Library). This will not support Legacy DFU out of the box!

Our intention is to maintain this code for modern Expo projects only. We will not officially support old Expo SDKs or old Nordic SDKs. Please keep in mind the our availability to maintain is limited and is based on our project needs.

This project does not provide an interface for scanning/connecting devices via BLE. Check the example app for libraries that can do that.

## Requirements

- Nordic zip firmware file
- Android 14+
- iOS 17+
- Expo SDK 55
- React Native Bridgeless (new architecture) enabled (this is mandatory as of Expo 55)

## Setup

### Install

```bash
// NPM projects
npm install @getquip/expo-nordic-dfu --save
// Yarn projects
yarn add @getquip/expo-nordic-dfu
```

### Bluetooth permissions

You need the various Bluetooth permissions enabled on your Expo project. If you use a Bluetooth management library like [react-native-ble-manager](https://github.com/innoveit/react-native-ble-manager), this might be done for you. For android, you also need Foreground Services enabled for the DFU process.

```typescript
// Expo app.json

// Android
expo.android.permissions: [
  // Specifically for DFU
  "android.permission.FOREGROUND_SERVICE",
  "android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE",
  // Needed for Bluetooth operations
  "android.permission.BLUETOOTH",
  "android.permission.BLUETOOTH_SCAN", // You might need to set "neverForLocation"
  "android.permission.BLUETOOTH_ADMIN",
  "android.permission.BLUETOOTH_CONNECT"
]

// iOS
expo.ios.infoPlist: [
  // Needed for Bluetooth operations
  "NSBluetoothAlwaysUsageDescription": "Uses Bluetooth to connect to Bluetooth enabled device.",
  "NSBluetoothPeripheralUsageDescription": "Uses Bluetooth to connect to Bluetooth enabled device.",
]
```

## Usage

Please see the [example app](example)!

### Listeners

The listeners work mostly the same as the original @ [Pilloxa/react-native-nordic-dfu](https://github.com/Pilloxa/react-native-nordic-dfu)

- `DFUProgress`: Reports back progress and extra values like upload speed
- `DFUStateChanged`: Reports back when major DFU flow milestones happen. It will also tell you if the DFU finished, failed or was aborted

```typescript
// See the type file src/ExpoNordicDfu.types.ts for schema
ExpoNordicDfu.module.addListener('DFUProgress', (progress) => {
  console.info('DFUProgress:', progress)
})
ExpoNordicDfu.module.addListener('DFUStateChanged', ({ state }) => {
  console.info('DFUStateChanged:', state)
})
```

**Do not remove the listeners as soon as `startDfu()` resolves.** That promise
settles in the same native callback that sends the final `DFU_COMPLETED` event,
so removing them at that moment can drop it.

`DFUStateChanged` ends with `DFU_COMPLETED`, `DFU_FAILED` or `DFU_ABORTED`. Both
platforms send all three, so check for those.

Android also sends `DEVICE_DISCONNECTED`, but it arrives just before
`DFU_COMPLETED`, and iOS never sends it. Don't use it to detect the end of a DFU.

### DFU

Starting a DFU operation is simple. Setup your listeners (see above) then call

```typescript
await ExpoNordicDfu.startDfu({
  deviceAddress,
  fileUri,
  // There are many optional parameters and some are OS-specific
  // The values we support are listed in src/ExpoNordicDfu.types.ts
  // ...,
  // android: {
  //   ...
  // },
  // ios: {
  //   ...
  // },
})
```

Refer to the base Nordic DFU library to understand how the optional parameters works

[IOS-DFU-Library documentation](https://nordicsemiconductor.github.io/IOS-DFU-Library/documentation/nordicdfu/dfuserviceinitiator)

[Android-DFU-Library documentation](https://nordicsemiconductor.github.io/Android-DFU-Library/html/lib/dfu/no.nordicsemi.android.dfu/-dfu-service-initiator/index.html)

### Example App

[Example App](example)

```bash
npm install
cd example
cp .env.example .env
# Fill in your .env as needed
npm install
npx expo prebuild --clean # Run this on first setup and whenever you change native files
# Android
npx expo run:android --device
# iOS
npx expo run:ios --device
```

## Contributing

Before we can accept a pull request from you, you'll need to read and agree to our [Contributor License Agreement (CLA)](https://github.com/getquip/expo-nordic-dfu/blob/main/CONTRIBUTING.md).

After changing anything in `src/`, run `npm run build` and commit the updated `build/` directory. It is the published entry point, and CI fails if it is out of date.
