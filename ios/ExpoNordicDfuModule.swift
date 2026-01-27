import ExpoModulesCore
import NordicDFU
import os

public class ExpoNordicDfuModule: Module, DFUProgressDelegate, DFUServiceDelegate, LoggerDelegate {
    private static let logger = Logger(subsystem: "com.getquip.nordic", category: "DFU")

    private let coordinator = IosDfuCoordinator()

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
            let config = IosDfuConfig(
                deviceAddress: deviceAddress,
                fileUri: fileUri,
                connectionTimeout: connectionTimeout,
                disableResume: disableResume,
                packetReceiptNotificationParameter: packetReceiptNotificationParameter,
                prepareDataObjectDelay: prepareDataObjectDelay
            )
            let starter = NordicIosDfuStarter(
                logger: self,
                delegate: self,
                progressDelegate: self
            )
            coordinator.start(config: config, starter: starter, promise: ExpoPromiseSink(promise))
        }

        AsyncFunction("abortIosDfu") { (promise: Promise) in
            coordinator.abort(promise: ExpoPromiseSink(promise))
        }
    }

    public func dfuStateDidChange(to state: NordicDFU.DFUState) {
        guard let deviceAddress = coordinator.currentDeviceAddress else { return }

        let stateName = ExpoNordicDfuState(
            nordicState: state
        ).eventName

        sendEvent("DFUStateChanged", [
            "deviceAddress": deviceAddress,
            "state": stateName
        ])

        if state == .aborted {
            coordinator.resolveAborted()
        }
        if state == .completed {
            coordinator.resolveCompleted()
        }
    }

    public func dfuError(_ error: NordicDFU.DFUError, didOccurWithMessage message: String) {
        guard let deviceAddress = coordinator.currentDeviceAddress else { return }

        sendEvent("DFUStateChanged", [
            "deviceAddress": deviceAddress,
            "state": "DFU_FAILED"
        ])
        let combinedMessage = "Error: \(error.rawValue), Error Type: \(String(describing: error)), Message: \(message)"
        coordinator.rejectError(code: "\(error.rawValue)", message: combinedMessage)
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

}

private extension ExpoNordicDfuState {
    init(nordicState: NordicDFU.DFUState) {
        switch nordicState {
        case .aborted: self = .aborted
        case .completed: self = .completed
        case .connecting: self = .connecting
        case .disconnecting: self = .disconnecting
        case .enablingDfuMode: self = .enablingDfuMode
        case .starting: self = .starting
        case .uploading: self = .uploading
        case .validating: self = .validating
        default: self = .unknown
        }
    }
}

private struct ExpoPromiseSink: DfuPromiseSink {
    private let promise: Promise

    init(_ promise: Promise) {
        self.promise = promise
    }

    func resolve(_ value: Any?) {
        promise.resolve(value)
    }

    func reject(_ code: String, _ message: String) {
        promise.reject(code, message)
    }
}

private final class NordicIosDfuController: IosDfuController {
    private let controller: DFUServiceController

    init(_ controller: DFUServiceController) {
        self.controller = controller
    }

    func abort() -> Bool {
        return controller.abort()
    }
}

private final class NordicIosDfuStarter: IosDfuStarter {
    private weak var logger: LoggerDelegate?
    private weak var delegate: DFUServiceDelegate?
    private weak var progressDelegate: DFUProgressDelegate?

    init(logger: LoggerDelegate, delegate: DFUServiceDelegate, progressDelegate: DFUProgressDelegate) {
        self.logger = logger
        self.delegate = delegate
        self.progressDelegate = progressDelegate
    }

    func start(with options: IosDfuStartOptions) throws -> IosDfuController {
        let url = URL(fileURLWithPath: options.filePath)
        let firmware = try DFUFirmware(urlToZipFile: url)
        let initiator = DFUServiceInitiator().with(firmware: firmware)
        initiator.logger = logger
        initiator.delegate = delegate
        initiator.progressDelegate = progressDelegate
        initiator.alternativeAdvertisingNameEnabled = true
        initiator.connectionTimeout = options.connectionTimeout
        if let disableResume = options.disableResume {
            initiator.disableResume = disableResume
        }
        if let prn = options.packetReceiptNotificationParameter {
            initiator.packetReceiptNotificationParameter = UInt16(prn)
        }
        if let delay = options.prepareDataObjectDelay {
            initiator.dataObjectPreparationDelay = delay
        }
        let controller = initiator.start(targetWithIdentifier: options.uuid)
        return NordicIosDfuController(controller)
    }
}
