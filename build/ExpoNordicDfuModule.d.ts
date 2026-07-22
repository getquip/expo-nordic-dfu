import { NativeModule } from 'expo';
import type { ExpoSettingsModuleEvents, StartDFUParams } from './ExpoNordicDfu.types';
declare class ExpoNordicDfuModule extends NativeModule<ExpoSettingsModuleEvents> {
    startAndroidDfu(deviceAddress: string, fileUri: string, deviceName?: string, keepBond?: boolean, numberOfRetries?: number, packetReceiptNotificationParameter?: number, prepareDataObjectDelay?: number, rebootTime?: number, restoreBond?: boolean): Promise<void>;
    abortAndroidDfu(): Promise<void>;
    startIosDfu(deviceAddress: string, fileUri: string, connectionTimeout?: number, disableResume?: boolean, packetReceiptNotificationParameter?: number, prepareDataObjectDelay?: number): Promise<void>;
    abortIosDfu(): Promise<void>;
}
declare class CrossplatformWrapper {
    private dfuModule;
    constructor(dfuModule: ExpoNordicDfuModule);
    get module(): ExpoNordicDfuModule;
    startDfu(params: StartDFUParams): Promise<void>;
    abortDfu(): Promise<void>;
}
declare const _default: CrossplatformWrapper;
export default _default;
//# sourceMappingURL=ExpoNordicDfuModule.d.ts.map