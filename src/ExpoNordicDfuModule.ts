import { NativeModule, requireNativeModule } from 'expo'
import type { ExpoSettingsModuleEvents, StartDFUParams } from './ExpoNordicDfu.types'
import { Platform } from 'react-native'

declare class ExpoNordicDfuModule extends NativeModule<ExpoSettingsModuleEvents> {
  startAndroidDfu(
    deviceAddress: string,
    fileUri: string,
    deviceName?: string,
    keepBond?: boolean,
    numberOfRetries?: number,
    packetReceiptNotificationParameter?: number,
    prepareDataObjectDelay?: number,
    rebootTime?: number,
    restoreBond?: boolean
  ): Promise<void>
  abortAndroidDfu(): Promise<void>
  startIosDfu(
    deviceAddress: string,
    fileUri: string,
    connectionTimeout?: number,
    disableResume?: boolean,
    packetReceiptNotificationParameter?: number,
    prepareDataObjectDelay?: number
  ): Promise<void>
  abortIosDfu(): Promise<void>
}

const DfuModule = requireNativeModule<ExpoNordicDfuModule>('ExpoNordicDfuModule')

class CrossplatformWrapper {
  constructor(private dfuModule: ExpoNordicDfuModule) {}

  get module() {
    return this.dfuModule
  }

  async startDfu(params: StartDFUParams): Promise<void> {
    if (Platform.OS === 'ios') {
      return await this.dfuModule.startIosDfu(
        params.deviceAddress,
        params.fileUri,
        params.ios?.connectionTimeout,
        params.ios?.disableResume,
        params.packetReceiptNotificationParameter,
        params.prepareDataObjectDelay
      )
    } else {
      return await this.dfuModule.startAndroidDfu(
        params.deviceAddress,
        params.fileUri,
        params.android?.deviceName,
        params.android?.keepBond,
        params.android?.numberOfRetries,
        params.packetReceiptNotificationParameter,
        params.prepareDataObjectDelay
        // See android/src/main/java/com/getquip/nordic/ExpoNordicDfuModule.kt
        // params.android?.rebootTime,
        // params.android?.restoreBond,
      )
    }
  }

  async abortDfu(): Promise<void> {
    if (Platform.OS === 'ios') {
      return await this.dfuModule.abortIosDfu()
    } else {
      return await this.dfuModule.abortAndroidDfu()
    }
  }
}

export default new CrossplatformWrapper(DfuModule)
