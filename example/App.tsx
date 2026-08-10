import ExpoNordicDfu, { DFUProgressPayload } from 'expo-nordic-dfu';
import { useEffect, useState } from 'react';
import { Alert, KeyboardAvoidingView, PermissionsAndroid, Platform,  ScrollView, TouchableOpacity, View, ViewStyle } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context'
import BleManager, { Peripheral } from 'react-native-ble-manager'
import { Text, Button } from 'react-native-paper'
import * as DocumentPicker from 'expo-document-picker';
import { File } from 'expo-file-system';

const SERVICE_UUIDS = process.env.EXPO_PUBLIC_BLUETOOTH_SERVICE_UUIDS.split(',').map((uuid: string) => uuid.trim())
const ANDROID_BONDING_ENABLED = process.env.EXPO_PUBLIC_ANDROID_BONDING_ENABLED === 'true'
const SELECTION_COLORS = {
  none: '#ffffff',
  disabled: '#e0e0e0',
  connected: '#8ec781',
  connecting: '#ede598',
  error: '#ff0000',
}

let bleInitialized = false
const bleManagerInitialize = async () => {
  if (bleInitialized) {
    return true
  }

  const initializing = (async () => {
    try {
      await BleManager.start({ showAlert: true })
      bleInitialized = true
      console.info('BleManager started')
      return true
    } catch (error) {
      console.error('Unexpected error starting BleManager', error)
      return false
    }
  })()

  return await initializing
}

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms))
}

type FirmwareFileType = {
  uri: string
  name: string
}

type ProgressType = {
  state?: string
  progress: DFUProgressPayload | undefined
}

export default function App() {
  const [peripherals, setPeripherals] = useState<Peripheral[]>([])
  const [peripheral, setPeripheral] = useState<Peripheral>()
  const [firmwareFile, setFirmwareFile] = useState<FirmwareFileType | false>()
  const [selectedColor, setSelectedColor] = useState<string>(SELECTION_COLORS.none)
  const [firmwareProgress, setFirmwareProgress] = useState<ProgressType | undefined>(undefined)
  const [isScanning, setIsScanning] = useState<boolean | undefined>(undefined)

  const processScanning = (peripheral: Peripheral) => {
    setPeripherals((peripherals) => {
      return !peripherals.find((p) => p.id === peripheral.id) ? [...peripherals, peripheral] : peripherals
    })
  }

  useEffect(() => {
    void bleManagerInitialize()
    const discoverListener = BleManager.onDiscoverPeripheral(processScanning)
    const onStopScanListener = BleManager.onStopScan(() => setIsScanning(false))

    return () => {
      discoverListener.remove();
      onStopScanListener.remove();
    };
  }, [])

  // Keep these for the whole component life. Removing them when startDfu()
  // resolves drops the final DFU_COMPLETED event.
  useEffect(() => {
    const progressListener = ExpoNordicDfu.module.addListener('DFUProgress', (progress) => {
      console.info('DFUProgress:', progress)
      setFirmwareProgress({ progress, state: 'Updating...' })
    })
    const stateListener = ExpoNordicDfu.module.addListener('DFUStateChanged', ({ state }) => {
      console.info('DFUStateChanged:', state)
      // Updater form, so we don't read stale state.
      setFirmwareProgress((previous) => ({ state, progress: previous?.progress }))
    })

    return () => {
      progressListener.remove()
      stateListener.remove()
    }
  }, [])

  useEffect(() => {
    if(peripheral && selectedColor === SELECTION_COLORS.connecting) {
      void connect()
    }
  }, [selectedColor, peripheral])

  // Ask for Bluetooth permissions once, on mount. Doing this in the component
  // body instead would re-run the request on every render.
  useEffect(() => {
    if (Platform.OS !== 'android') {
      return
    }

    PermissionsAndroid.requestMultiple([
      PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
      PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
      PermissionsAndroid.PERMISSIONS.BLUETOOTH_ADVERTISE,
    ])
      .then((result) => {
        // requestMultiple resolves to { [permission]: 'granted' | 'denied' | ... },
        // so the object is always truthy. Check each status instead.
        const denied = Object.entries(result)
          .filter(([, status]) => status !== PermissionsAndroid.RESULTS.GRANTED)
          .map(([permission]) => permission)

        if (denied.length === 0) {
          console.debug('User accepts Bluetooth permissions')
          return
        }

        console.error('User refuses Bluetooth permissions', denied)
        Alert.alert(
          'Accept Permissions',
          'You have to accept Bluetooth permissions to use this app',
        )
      })
      .catch((error) => {
        console.error('Bluetooth permission request failed', error)
      })
  }, [])

  const firmwareDisableButtons = firmwareProgress !== undefined && firmwareProgress.state !== 'DEVICE_DISCONNECTED' && firmwareProgress.state !== 'DFU_FAILED' && firmwareProgress.state !== 'DFU_COMPLETED' && firmwareProgress.state !== 'DFU_ABORTED'

  const backgroundColor = (selected: Peripheral) => {
    const isSelected = selected.id === peripheral?.id
    const isConnecting = selectedColor === SELECTION_COLORS.connecting
    if (isConnecting && !isSelected) {
      return SELECTION_COLORS.disabled
    } else if (isSelected) {
      return selectedColor
    } else {
      return SELECTION_COLORS.none
    }
  }

  const reset = async (peripheral: Peripheral | undefined) => {
    if (peripheral) {
      try {
        await BleManager.disconnect(peripheral.id)
      } catch (error) {
        // The device may already be gone. Clear our own state either way.
        console.warn('Failed to disconnect', error)
      }
    }
    setPeripherals([])
    setPeripheral(undefined)
    setFirmwareProgress(undefined)
    setFirmwareFile(undefined)
    setIsScanning(undefined)
  }

  const scan = async () => {
    await reset(peripheral)
    try {
      await BleManager.scan(SERVICE_UUIDS, 5, false)
      setIsScanning(true)
    } catch (error) {
      // Handle it here. Throwing from an onPress handler just becomes an
      // unhandled rejection and the user sees nothing.
      console.error('Scan failed', error)
      setIsScanning(false)
      await BleManager.stopScan().catch(() => undefined)
      Alert.alert('Scan Failed', 'Could not start scanning for devices')
    }
  }

  const handleConnect = (peripheral: Peripheral) => {
    setSelectedColor(SELECTION_COLORS.connecting)
    setPeripheral(peripheral)
  }

  const connect = async () => {
    if (!peripheral) {
      console.error('No peripheral selected')
      return
    }
    try {
      await BleManager.connect(peripheral.id)

      if (Platform.OS === 'android' && ANDROID_BONDING_ENABLED) {
        console.debug(`${peripheral.id}] createBond`)
        try {
          await BleManager.createBond(peripheral.id)
          console.debug(`${peripheral.id}] createBond success or there is already an existing one`)
        } catch (e) {
          console.warn(`${peripheral.id}] createBond failed:`, e)
        }
      }
      // before retrieving services, it is often a good idea to let bonding & connection finish properly
      // See https://github.com/innoveit/react-native-ble-manager/blob/d7613a48ff201914f4a91d7167f35d615ce0d24a/example/components/ScanDevicesScreen.tsx#L276 for context
      await sleep(900)

      await BleManager.retrieveServices(peripheral.id)
      setPeripheral(peripheral)
      setSelectedColor(SELECTION_COLORS.connected)
      console.debug(`${peripheral.id}] Connected to ${peripheral.name}`)
    } catch (error) {
      // Already reported to the user via the error colour. Re-throwing would
      // only produce an unhandled rejection in the effect that calls this.
      console.error('Connection error', error)
      setSelectedColor(SELECTION_COLORS.error)
      setPeripheral(undefined)
    }
  }

  const handleFileSelect = async (): Promise<void> => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: [
          'binary/octet-stream',
          'application/octet-stream',
          'application/zip',
          'application/x-zip-compressed',
        ],
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        const file = result.assets[0];

        if (!file.name.toLowerCase().endsWith('.zip')) {
          Alert.alert(
            'Invalid File',
            'Please select a valid firmware (.zip) file',
          );
          return;
        }

        const fileInfo = new File(file.uri).info()
        
        if (!fileInfo.exists) {
          throw new Error('File does not exist');
        }

        console.debug('File selected:', file);
        setFirmwareFile({
          uri: file.uri,
          name: file.name,
        });
      }
    } catch (err) {
      console.error('File select error', err);
      Alert.alert('Error', 'Check your file and try again');
    }
  };

  const startDFU = async (peripheral: Peripheral, firmwareFile: FirmwareFileType) => {
    try {
      await ExpoNordicDfu.startDfu({
        deviceAddress: peripheral.id,
        fileUri: firmwareFile.uri,
        // These optional values are set to useful values for quip.
        // Change them to your needs.
        packetReceiptNotificationParameter: 1,
        android: {
          deviceName: peripheral.name,
        },
      })
    } catch (error) {
      console.error(error)
    }
  }

  const abortDFU = async () => {
    try {
      await ExpoNordicDfu.abortDfu()
    } catch (error) {
      console.error(error)
    }
  }

  return (
    <SafeAreaView style={styles.container} >
      <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
        <ScrollView contentContainerStyle={{ minHeight: '100%', width: '100%' }}>
          <View style={styles.view}>
            <Text variant="headlineLarge">Nordic DFU Example App</Text>
            <Button disabled={firmwareDisableButtons || isScanning} mode="contained" onPress={scan}>
              Scan for Devices
            </Button>
            {isScanning === false && peripherals.length === 0 && <Text>No devices found</Text>}
            {peripherals.length > 0 && <Text>Click one of the following devices to connect and pair:</Text>}
            {[...peripherals].map((peripheral) => (
              <TouchableOpacity
                disabled={selectedColor === SELECTION_COLORS.connecting || firmwareDisableButtons}
                style={{ ...styles.touchable, backgroundColor: backgroundColor(peripheral) }}
                key={peripheral.id}
                onPress={() => handleConnect(peripheral)}
              >
                <Text>ID: {peripheral.id}</Text>
                {peripheral.name &&  (<Text>Name: {peripheral.name}</Text>)}
                <Text>RSSI: {peripheral.rssi}</Text>
                <Text>Advertising Data: {JSON.stringify({
                      isConnectable: peripheral.advertising.isConnectable,
                      localName: peripheral.advertising.localName,
                      serviceData: peripheral.advertising.serviceData,
                      serviceUUIDs: peripheral.advertising.serviceUUIDs,
                      txPowerLevel: peripheral.advertising.txPowerLevel,
                })}</Text>
                <Text>Manufacturing Data: {JSON.stringify(peripheral.advertising.manufacturerData)}</Text>
              </TouchableOpacity>
            ))}
            {peripheral && selectedColor === SELECTION_COLORS.connected && (
              <Button disabled={firmwareDisableButtons} mode="contained" onPress={handleFileSelect}>
                Select Firmware File
              </Button>
            )}
            {firmwareProgress && (
              <View>
                <Text>DFU State: {firmwareProgress.state}</Text>
                <Text>DFU Percent Done: {firmwareProgress.progress?.percent}</Text>
                <Text>DFU Current Part: {firmwareProgress.progress?.currentPart}</Text>
                <Text>DFU Total Parts: {firmwareProgress.progress?.totalParts}</Text>
                <Text>DFU Current Speed: {firmwareProgress.progress?.speed}</Text>
                <Text>DFU Average Speed: {firmwareProgress.progress?.avgSpeed}</Text>
              </View>)}
            {peripheral && selectedColor === SELECTION_COLORS.connected && firmwareFile && !firmwareDisableButtons && (
              <Button
                mode="contained"
                onPress={() => {
                  startDFU(peripheral, firmwareFile)
                }}
              >
                Start DFU
              </Button>
            )}
            {firmwareDisableButtons && (
              <Button
                mode="contained-tonal"
                onPress={() => {
                  abortDFU()
                }}
              >
                Abort DFU
              </Button>
          )}
            {peripheral && selectedColor === SELECTION_COLORS.connected && (
              <Button
                disabled={firmwareDisableButtons}
                mode="contained-tonal"
                onPress={() => {
                  void reset(peripheral)
                }}
              >
                Disconnect
              </Button>
            )}
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles: { [key: string]: ViewStyle } = {
  container: {
    backgroundColor: '#eee',
    flex: 1,
    height: '100%',
    width: '100%',
  },
  touchable: {
    borderColor: '#000',
    borderRadius: 5,
    borderWidth: 1,
    flex: 1,
    flexDirection: 'column',
    flexGrow: 0,
    gap: 2,
    justifyContent: 'center',
    padding: 10,
  },
  view: {
    flex: 1,
    flexDirection: 'column',
    gap: 20,
    height: '100%',
    justifyContent: 'center',
    marginBottom: 200,
    padding: 20,
    width: '100%',
  },
};
