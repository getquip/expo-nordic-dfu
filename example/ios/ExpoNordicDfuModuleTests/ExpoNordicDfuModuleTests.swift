import XCTest
@testable import ExpoNordicDfu
import ExpoModulesCore
import NordicDFU

final class ExpoNordicDfuModuleTests: XCTestCase {
    var appContext: AppContext!
    var module: ExpoNordicDfuModule!
    var mockPromise: FakePromise!

    override func setUp() {
        super.setUp()
        appContext = AppContext()
        module = ExpoNordicDfuModule(appContext: appContext)
        mockPromise = FakePromise()
    }

    func testStartInjectsMockInitiator() {
        let dummyFirmware = FakeDFUFirmware()
        let mockInitiator = FakeInitiator()

        module.makeFirmware = { _ in dummyFirmware }
        module.makeInitiator = { firmware in
            XCTAssertTrue(firmware === dummyFirmware)
            return mockInitiator
        }

        let uuid = UUID().uuidString

        XCTAssertNoThrow(try module._startDfu(
            deviceAddress: uuid,
            fileUri: "file://dummy.zip",
            connectionTimeout: 15,
            disableResume: true,
            packetReceiptNotificationParameter: 8,
            prepareDataObjectDelay: 0.35,
            promise: mockPromise
        ))

        XCTAssertTrue(mockInitiator.didCallStart)
        XCTAssertEqual(mockInitiator.lastStartedUUID?.uuidString, uuid)
    }

    func testAbortCallsMockControllerAbort() {
        let mockController = FakeServiceController()
        module.controller = mockController

        module._abortDfu(promise: mockPromise)

        XCTAssertTrue(mockController.didAbort)
        XCTAssertTrue(mockPromise.didResolve)
    }

    func testAbortFailsWhenNoController() {
        module.controller = nil
        module._abortDfu(promise: mockPromise)

        XCTAssertTrue(mockPromise.didReject)
        XCTAssertEqual(mockPromise.errorCode, "no_running_dfu")
    }

    func testStartRejectsIfAlreadyRunning() {
        module.controller = FakeServiceController()

        try? module._startDfu(
            deviceAddress: UUID().uuidString,
            fileUri: "file://dummy.zip",
            connectionTimeout: nil,
            disableResume: nil,
            packetReceiptNotificationParameter: nil,
            prepareDataObjectDelay: nil,
            promise: mockPromise
        )

        XCTAssertTrue(mockPromise.didReject)
        XCTAssertEqual(mockPromise.errorCode, "dfu_in_progress")
    }

    func testStartRejectsIfUUIDInvalid() {
        try? module._startDfu(
            deviceAddress: "not-a-uuid",
            fileUri: "file://dummy.zip",
            connectionTimeout: nil,
            disableResume: nil,
            packetReceiptNotificationParameter: nil,
            prepareDataObjectDelay: nil,
            promise: mockPromise
        )

        XCTAssertTrue(mockPromise.didReject)
        XCTAssertEqual(mockPromise.errorCode, "invalid_device_address")
    }
}

final class FakeDFUFirmware: DFUFirmwareProtocol {}

final class FakeServiceController: DFUServiceControllerProtocol {
    var didAbort = false
    var returnValue: Bool = true

    func abort() -> Bool {
        didAbort = true
        return returnValue
    }
}

class FakeInitiator: DFUServiceInitiatorProtocol {
  var didCallStart = false
  var lastStartedUUID: UUID?
  let fakeController = FakeServiceController()

  func start(targetWithIdentifier identifier: UUID) -> any ExpoNordicDfu.DFUServiceControllerProtocol {
    didCallStart = true
    lastStartedUUID = identifier
    return fakeController
  }
  
  var logger: (any NordicDFU.LoggerDelegate)?
  var delegate: (any NordicDFU.DFUServiceDelegate)?
  var progressDelegate: (any NordicDFU.DFUProgressDelegate)?
  var alternativeAdvertisingNameEnabled: Bool = false
  var connectionTimeout: TimeInterval = 0.0
  var disableResume: Bool = false
  var packetReceiptNotificationParameter: UInt16 = 0
  var dataObjectPreparationDelay: TimeInterval = 0.0
}

final class FakePromise: PromiseProtocol {
  var didResolve = false
  var didReject = false
  var resolvedValue: Any?
  var errorCode: String?
  var errorMessage: String?
  
  func resolve(_ value: Any? = nil) {
    didResolve = true
    resolvedValue = value
  }
  func reject(_ code: String, _ message: String) {
    didReject = true
    errorCode = code
    errorMessage = message
  }
}

