import Foundation

struct IosDfuConfig {
    let deviceAddress: String
    let fileUri: String
    let connectionTimeout: Int?
    let disableResume: Bool?
    let packetReceiptNotificationParameter: Int?
    let prepareDataObjectDelay: Double?
}

struct IosDfuStartOptions: Equatable {
    let uuid: UUID
    let filePath: String
    let connectionTimeout: TimeInterval
    let disableResume: Bool?
    let packetReceiptNotificationParameter: Int?
    let prepareDataObjectDelay: TimeInterval?
}

protocol IosDfuController {
    func abort() -> Bool
}

protocol IosDfuStarter {
    func start(with options: IosDfuStartOptions) throws -> IosDfuController
}

protocol DfuPromiseSink {
    func resolve(_ value: Any?)
    func reject(_ code: String, _ message: String)
}

final class IosDfuCoordinator {
    private var controller: IosDfuController?
    private var currentPromise: DfuPromiseSink?
    private var deviceAddress: String?

    func start(config: IosDfuConfig, starter: IosDfuStarter, promise: DfuPromiseSink) {
        guard controller == nil else {
            promise.reject("dfu_in_progress", "A DFU process is already running")
            return
        }

        currentPromise = promise
        deviceAddress = config.deviceAddress

        guard let uuid = UUID(uuidString: config.deviceAddress) else {
            currentPromise?.reject("invalid_device_address", "Device address is invalid")
            resetState()
            return
        }

        let filePath = ExpoNordicDfuUtils.normalizedFilePath(from: config.fileUri)
        let options = IosDfuStartOptions(
            uuid: uuid,
            filePath: filePath,
            connectionTimeout: TimeInterval(config.connectionTimeout ?? 10),
            disableResume: config.disableResume,
            packetReceiptNotificationParameter: config.packetReceiptNotificationParameter,
            prepareDataObjectDelay: config.prepareDataObjectDelay.map { TimeInterval($0) }
        )

        do {
            controller = try starter.start(with: options)
        } catch {
            currentPromise?.reject("dfu_start_failed", "Unable to start DFU: \(error.localizedDescription)")
            resetState()
        }
    }

    func abort(promise: DfuPromiseSink) {
        guard let controller = controller else {
            promise.reject("no_running_dfu", "There is no DFU process currently running")
            return
        }

        if controller.abort() {
            promise.resolve(nil)
        } else {
            promise.reject("dfu_abort_failed", "Unable to abort DFU process")
        }
    }

    func resolveCompleted() {
        if let deviceAddress = deviceAddress {
            currentPromise?.resolve(["deviceAddress": deviceAddress])
        }
        resetState()
    }

    func resolveAborted() {
        currentPromise?.resolve("DFU was aborted")
        resetState()
    }

    func rejectError(code: String, message: String) {
        currentPromise?.reject(code, message)
        resetState()
    }

    private func resetState() {
        currentPromise = nil
        controller = nil
        deviceAddress = nil
    }

    var currentDeviceAddress: String? {
        return deviceAddress
    }
}
