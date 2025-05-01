import ExpoModulesCore
import NordicDFU
import os


protocol DFUServiceControllerProtocol {
    func abort() -> Bool
}

extension DFUServiceController: DFUServiceControllerProtocol {}

protocol DFUServiceInitiatorProtocol {
    func start(targetWithIdentifier identifier: UUID) -> DFUServiceControllerProtocol
    var logger: LoggerDelegate? { get set }
    var delegate: DFUServiceDelegate? { get set }
    var progressDelegate: DFUProgressDelegate? { get set }
    var alternativeAdvertisingNameEnabled: Bool { get set }
    var connectionTimeout: TimeInterval { get set }
    var disableResume: Bool { get set }
    var packetReceiptNotificationParameter: UInt16 { get set }
    var dataObjectPreparationDelay: TimeInterval { get set }
}

extension DFUServiceInitiator: DFUServiceInitiatorProtocol {
    func start(targetWithIdentifier identifier: UUID) -> any DFUServiceControllerProtocol {
        return self.start(targetWithIdentifier: identifier)
    }
}

protocol DFUFirmwareProtocol {}
struct DFUFirmwareWrapper: DFUFirmwareProtocol {
    let base: DFUFirmware

    init(urlToZipFile: URL) throws {
        self.base = try DFUFirmware(urlToZipFile: urlToZipFile)
    }
}

protocol PromiseProtocol {
    func resolve(_ value: Any?)
    func reject(_ code: String, _ message: String)
}
extension Promise: PromiseProtocol {}

public class ExpoNordicDfuModule: Module, DFUProgressDelegate, DFUServiceDelegate, LoggerDelegate {
    private static let logger = Logger(subsystem: "com.getquip.nordic", category: "DFU")

    internal var controller: DFUServiceControllerProtocol?
    internal var currentPromise: PromiseProtocol?
    internal var deviceAddress: String?
    
    internal var makeFirmware: (_ url: URL) throws -> DFUFirmwareWrapper = { try DFUFirmwareWrapper(urlToZipFile: $0) }
    internal var makeInitiator: (_ firmware: DFUFirmwareProtocol) -> DFUServiceInitiatorProtocol = {
        let initiator = DFUServiceInitiator().with(firmware: $0)
        return initiator as DFUServiceInitiatorProtocol
    }

    public func definition() -> ModuleDefinition {
        Name("ExpoNordicDfuModule")

        Events("DFUStateChanged", "DFUProgress")

        OnStartObserving {
          // This is called when the module starts observing events.
          // You can start listening to events here.
        }

        OnStopObserving {
          // This is called when the module stops observing events.
          // You can stop listening to events here.
        }

        AsyncFunction("startIosDfu") { (
            deviceAddress: String,
            fileUri: String,
            connectionTimeout: Int?,
            disableResume: Bool?,
            packetReceiptNotificationParameter: Int?,
            prepareDataObjectDelay: Double?,
            promise: Promise
        ) in
            try self._startDfu(
                deviceAddress: deviceAddress,
                fileUri: fileUri,
                connectionTimeout: connectionTimeout,
                disableResume: disableResume,
                packetReceiptNotificationParameter: packetReceiptNotificationParameter,
                prepareDataObjectDelay: prepareDataObjectDelay,
                promise: promise
            )
        }

        AsyncFunction("abortIosDfu") { (promise: Promise) in
            self._abortDfu(promise: promise)
        }
    }
    
    @discardableResult
    internal func _startDfu(
        deviceAddress: String,
        fileUri: String,
        connectionTimeout: Int?,
        disableResume: Bool?,
        packetReceiptNotificationParameter: Int?,
        prepareDataObjectDelay: Double?,
        promise: PromiseProtocol
    ) throws {
        guard self.controller == nil else {
            promise.reject("dfu_in_progress", "A DFU process is already running")
            return
        }

        self.currentPromise = promise
        self.deviceAddress = deviceAddress

        guard let uuid = UUID(uuidString: deviceAddress) else {
            self.currentPromise?.reject("invalid_device_address", "Device address is invalid")
            resetState()
            return
        }

        Self.logger.info("Starting DFU on device \(uuid)")

        let path = fileUri.replacingOccurrences(of: "file://", with: "")
        let url = URL(fileURLWithPath: path)
        let firmware = try makeFirmware(url)
        var initiator = makeInitiator(firmware)

        initiator.logger = self
        initiator.delegate = self
        initiator.progressDelegate = self
        initiator.alternativeAdvertisingNameEnabled = true
        initiator.connectionTimeout = TimeInterval(connectionTimeout ?? 10)
        // By default this is set to false. This property applies only to Secure DFU.
        disableResume.map { initiator.disableResume = $0 }
        // The number of packets of firmware data to be received by the DFU target before sending a new Packet Receipt Notification.
        // Disabling PRNs increases upload speed but may cause failures on devices with slow flash memory.
        packetReceiptNotificationParameter.map { initiator.packetReceiptNotificationParameter = UInt16($0) }
        // Duration of a delay, that the service will wait before sending each data object in Secure DFU.
        // The delay will be done after a data object is created, and before any data byte is sent.
        // The default value is 0, which disables this feature for the second and following data objects, but the first one will be delayed by 0.4 sec.
        // It has been found, that a delay of at least 0.3 sec reduces the risk of packet lose (the bootloader needs some time to prepare flash memory) on DFU bootloader from SDK 15, 16, and 17.
        // The delay does not have to be longer than 0.4 sec, as according to performed tests, such such delay is sufficient.
        // The recommended delay is from 0.3 to 0.4 second if your DFU bootloader is from SDK 15, 16 or 17. Older bootloaders do not need this delay.
        prepareDataObjectDelay.map { initiator.dataObjectPreparationDelay = TimeInterval($0) }

        self.controller = initiator.start(targetWithIdentifier: uuid)
    }

    internal func _abortDfu(promise: PromiseProtocol) {
        let wasAborted = controller?.abort()
        if wasAborted == nil {
            promise.reject("no_running_dfu", "There is no DFU process currently running")
        } else if wasAborted == false {
            promise.reject("dfu_abort_failed", "Unable to abort DFU process")
        } else {
            promise.resolve(nil)
        }
    }

    public func dfuStateDidChange(to state: NordicDFU.DFUState) {
        guard let deviceAddress = self.deviceAddress else { return }

        let stateName: String = {
            switch state {
            case .aborted: return "DFU_ABORTED"
            case .completed: return "DFU_COMPLETED"
            case .connecting: return "CONNECTING"
            case .disconnecting: return "DEVICE_DISCONNECTING"
            case .enablingDfuMode: return "ENABLING_DFU_MODE"
            case .starting: return "DFU_PROCESS_STARTING"
            case .uploading: return "DFU_UPLOADING"
            case .validating: return "FIRMWARE_VALIDATING"
            default: return "UNKNOWN_STATE"
            }
        }()

        sendEvent("DFUStateChanged", [
            "deviceAddress": deviceAddress,
            "state": stateName
        ])

        if state == .aborted {
            self.currentPromise?.resolve("DFU was aborted")
            resetState()
        }
        if state == .completed {
            self.currentPromise?.resolve(["deviceAddress": deviceAddress])
            resetState()
        }
    }

    public func dfuError(_ error: NordicDFU.DFUError, didOccurWithMessage message: String) {
        guard let deviceAddress = self.deviceAddress else { return }

        sendEvent("DFUStateChanged", [
            "deviceAddress": deviceAddress,
            "state": "DFU_FAILED"
        ])
        let combinedMessage = "Error: \(error.rawValue), Error Type: \(String(describing: error)), Message: \(message)"
        self.currentPromise?.reject("\(error.rawValue)", combinedMessage)
        resetState()
    }

    public func dfuProgressDidChange(
        for part: Int,
        outOf totalParts: Int,
        to progress: Int,
        currentSpeedBytesPerSecond: Double,
        avgSpeedBytesPerSecond: Double
    ) {
        guard let deviceAddress = self.deviceAddress else { return }

        sendEvent("DFUProgress", [
            "deviceAddress": deviceAddress,
            "percent": progress,
            "speed": currentSpeedBytesPerSecond,
            "avgSpeed": avgSpeedBytesPerSecond,
            "currentPart": part,
            "totalParts": totalParts,
        ])
    }

    public func logWith(_ level: LogLevel, message: String) {
        switch level {
        case .debug, .verbose:
            Self.logger.debug("\(message, privacy: .public)")
        case .info, .application:
            Self.logger.info("\(message, privacy: .public)")
        case .warning:
            Self.logger.warning("\(message, privacy: .public)")
        case .error:
            Self.logger.error("\(message, privacy: .public)")
        }
    }
    
    private func resetState() {
        self.currentPromise = nil
        self.controller = nil
    }
}
