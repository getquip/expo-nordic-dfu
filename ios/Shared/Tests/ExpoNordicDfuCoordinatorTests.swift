import Foundation
import Testing
@testable import ExpoNordicDfuUtils

@Test
func startRejectsWhenAlreadyRunning() {
    let coordinator = IosDfuCoordinator()
    let starter = FakeStarter()
    let promise1 = TestPromise()
    let promise2 = TestPromise()
    let config = defaultConfig()

    coordinator.start(config: config, starter: starter, promise: promise1)
    coordinator.start(config: config, starter: starter, promise: promise2)

    #expect(promise2.rejectedCode == "dfu_in_progress")
    #expect(starter.startCalls == 1)
}

@Test
func startRejectsInvalidDeviceAddress() {
    let coordinator = IosDfuCoordinator()
    let starter = FakeStarter()
    let promise = TestPromise()
    let config = IosDfuConfig(
        deviceAddress: "not-a-uuid",
        fileUri: "file:///tmp/fw.zip",
        connectionTimeout: nil,
        disableResume: nil,
        packetReceiptNotificationParameter: nil,
        prepareDataObjectDelay: nil
    )

    coordinator.start(config: config, starter: starter, promise: promise)

    #expect(promise.rejectedCode == "invalid_device_address")
    #expect(starter.startCalls == 0)
}

@Test
func startPassesNormalizedPathAndOptions() throws {
    let coordinator = IosDfuCoordinator()
    let starter = FakeStarter()
    let promise = TestPromise()
    let uuid = UUID().uuidString
    let config = IosDfuConfig(
        deviceAddress: uuid,
        fileUri: "file:///tmp/fw%20file.zip",
        connectionTimeout: 15,
        disableResume: true,
        packetReceiptNotificationParameter: 12,
        prepareDataObjectDelay: 0.4
    )

    coordinator.start(config: config, starter: starter, promise: promise)

    #expect(starter.startCalls == 1)
    let options = try #require(starter.lastOptions)
    #expect(options.uuid.uuidString == uuid)
    #expect(options.filePath == "/tmp/fw file.zip")
    #expect(options.connectionTimeout == 15)
    #expect(options.disableResume == true)
    #expect(options.packetReceiptNotificationParameter == 12)
    #expect(options.prepareDataObjectDelay == 0.4)
}

@Test
func startRejectsWhenStarterThrows() {
    let coordinator = IosDfuCoordinator()
    let starter = FakeStarter()
    starter.error = TestError()
    let promise = TestPromise()

    coordinator.start(config: defaultConfig(), starter: starter, promise: promise)

    #expect(promise.rejectedCode == "dfu_start_failed")
}

@Test
func abortRejectsWhenNoController() {
    let coordinator = IosDfuCoordinator()
    let promise = TestPromise()

    coordinator.abort(promise: promise)

    #expect(promise.rejectedCode == "no_running_dfu")
}

@Test
func abortRejectsWhenControllerFails() {
    let coordinator = IosDfuCoordinator()
    let starter = FakeStarter(controller: FakeController(abortResult: false))
    coordinator.start(config: defaultConfig(), starter: starter, promise: TestPromise())

    let promise = TestPromise()
    coordinator.abort(promise: promise)

    #expect(promise.rejectedCode == "dfu_abort_failed")
}

@Test
func abortResolvesWhenControllerAborts() {
    let coordinator = IosDfuCoordinator()
    let starter = FakeStarter(controller: FakeController(abortResult: true))
    coordinator.start(config: defaultConfig(), starter: starter, promise: TestPromise())

    let promise = TestPromise()
    coordinator.abort(promise: promise)

    #expect(promise.rejectedCode == nil)
}

@Test
func resolveCompletedResetsState() {
    let coordinator = IosDfuCoordinator()
    let promise = TestPromise()
    let config = defaultConfig()
    coordinator.start(config: config, starter: FakeStarter(), promise: promise)

    coordinator.resolveCompleted()

    #expect((promise.resolvedValue as? [String: String]) == ["deviceAddress": config.deviceAddress])
    #expect(coordinator.currentDeviceAddress == nil)
}

@Test
func resolveAbortedResetsState() {
    let coordinator = IosDfuCoordinator()
    let promise = TestPromise()
    coordinator.start(config: defaultConfig(), starter: FakeStarter(), promise: promise)

    coordinator.resolveAborted()

    #expect((promise.resolvedValue as? String) == "DFU was aborted")
    #expect(coordinator.currentDeviceAddress == nil)
}

@Test
func rejectErrorResetsState() {
    let coordinator = IosDfuCoordinator()
    let promise = TestPromise()
    coordinator.start(config: defaultConfig(), starter: FakeStarter(), promise: promise)

    coordinator.rejectError(code: "123", message: "Boom")

    #expect(promise.rejectedCode == "123")
    #expect(coordinator.currentDeviceAddress == nil)
}

private func defaultConfig() -> IosDfuConfig {
    return IosDfuConfig(
        deviceAddress: UUID().uuidString,
        fileUri: "file:///tmp/fw.zip",
        connectionTimeout: nil,
        disableResume: nil,
        packetReceiptNotificationParameter: nil,
        prepareDataObjectDelay: nil
    )
}

private final class FakeStarter: IosDfuStarter {
    var startCalls = 0
    var lastOptions: IosDfuStartOptions?
    var error: Error?
    private let controller: IosDfuController

    init(controller: IosDfuController = FakeController()) {
        self.controller = controller
    }

    func start(with options: IosDfuStartOptions) throws -> IosDfuController {
        startCalls += 1
        lastOptions = options
        if let error = error {
            throw error
        }
        return controller
    }
}

private final class FakeController: IosDfuController {
    private let abortResult: Bool

    init(abortResult: Bool = true) {
        self.abortResult = abortResult
    }

    func abort() -> Bool {
        return abortResult
    }
}

private final class TestPromise: DfuPromiseSink {
    var resolvedValue: Any?
    var rejectedCode: String?
    var rejectedMessage: String?

    func resolve(_ value: Any?) {
        resolvedValue = value
    }

    func reject(_ code: String, _ message: String) {
        rejectedCode = code
        rejectedMessage = message
    }
}

private struct TestError: Error {}
