# Expo Nordic DFU

This project was highly inspired by the original React Native project at [Pilloxa/react-native-nordic-dfu](https://github.com/Pilloxa/react-native-nordic-dfu). We continued the work so it functions with modern [Expo](http://expo.dev/) projects that use [Expo Modules](https://docs.expo.dev/modules/overview/).

This module allows you to perform a Secure Device Firmware Update (DFU) for Nordic Semiconductors on Expo React Native bridgeless projects. It wraps the official libraries at [NordicSemiconductor/Android-DFU-Library](https://github.com/NordicSemiconductor/Android-DFU-Library) and [NordicSemiconductor/IOS-DFU-Library](https://github.com/NordicSemiconductor/IOS-DFU-Library). This will not support Legacy DFU out of the box!

Our intention is to maintain this code for modern Expo projects only. We will not officially support old Expo SDKs or old Nordic SDKs. Please keep in mind the our availability to maintain is limited and is based on our project needs.

This project does not provide an interface for scanning/connecting devices via BLE. Check the example app for libraries that can do that.

## Requirements

- Nordic zip firmware file
- Android 14 or 15
- iOS 17 or 18
- Expo SDK 54
- React Native Bridgeless (new architecture) enabled

## Usage

Please checkout the [example app](example)!

### Bluetooth permissions

You need the various Bluetooth permission enabled on Expo project. If you use a Bluetooth management library like [react-native-ble-manager](https://github.com/innoveit/react-native-ble-manager), this might be done for you. For android, you also need Foreground services enabled for the DFU process.

```typescript
// Expo app.json

// Android
expo.android.permissions: [
  "android.permission.FOREGROUND_SERVICE",
  "android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE",
  "android.permission.BLUETOOTH",
  "android.permission.BLUETOOTH_SCAN", // You might need to set "neverForLocation"
  "android.permission.BLUETOOTH_ADMIN",
  "android.permission.BLUETOOTH_CONNECT"
]

// iOS
expo.ios.infoPlist: [
  "NSBluetoothAlwaysUsageDescription": "Uses Bluetooth to connect to Bluetooth enabled device.",
  "NSBluetoothPeripheralUsageDescription": "Uses Bluetooth to connect to Bluetooth enabled device.",
]
```

### Listeners

The listeners work mostly the same as the original @ [Pilloxa/react-native-nordic-dfu](https://github.com/Pilloxa/react-native-nordic-dfu)

- `DFUProgress`: Reports back progress and extra values like upload speed
- `DFUStateChanged`: Reports back when major DFU flow miletones happen. It will also tell you if the DFU finished, failed or was aborted

```typescript
ExpoNordicDfu.module.addListener('DFUProgress', (progress) => {
  console.info('DFUProgress:', progress)
})
ExpoNordicDfu.module.addListener('DFUStateChanged', ({ state }) => {
  console.info('DFUStateChanged:', state)
})
```

### DFU

Starting a DFU operation is simple. Setup your listeners (see above) then call

```typescript
await ExpoNordicDfu.startDfu({
  deviceAddress,
  fileUri,
  // There are many optional parameters and some are OS-specific
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
