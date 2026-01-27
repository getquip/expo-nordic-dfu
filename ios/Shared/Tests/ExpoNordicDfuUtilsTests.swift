import Testing
@testable import ExpoNordicDfuUtils

@Test
func normalizedFilePathStripsFileScheme() {
    let path = ExpoNordicDfuUtils.normalizedFilePath(from: "file:///tmp/firmware.zip")
    #expect(path == "/tmp/firmware.zip")
}

@Test
func normalizedFilePathDecodesPercentEncoding() {
    let path = ExpoNordicDfuUtils.normalizedFilePath(from: "file:///tmp/firmware%20file.zip")
    #expect(path == "/tmp/firmware file.zip")
}

@Test
func normalizedFilePathHandlesNonFileScheme() {
    let path = ExpoNordicDfuUtils.normalizedFilePath(from: "content:///tmp/firmware.zip")
    #expect(path == "content:///tmp/firmware.zip")
}

@Test
func dfuStateEventNames() {
    #expect(ExpoNordicDfuState.aborted.eventName == "DFU_ABORTED")
    #expect(ExpoNordicDfuState.completed.eventName == "DFU_COMPLETED")
    #expect(ExpoNordicDfuState.connecting.eventName == "CONNECTING")
    #expect(ExpoNordicDfuState.disconnecting.eventName == "DEVICE_DISCONNECTING")
    #expect(ExpoNordicDfuState.enablingDfuMode.eventName == "ENABLING_DFU_MODE")
    #expect(ExpoNordicDfuState.starting.eventName == "DFU_PROCESS_STARTING")
    #expect(ExpoNordicDfuState.uploading.eventName == "DFU_UPLOADING")
    #expect(ExpoNordicDfuState.validating.eventName == "FIRMWARE_VALIDATING")
    #expect(ExpoNordicDfuState.unknown.eventName == "UNKNOWN_STATE")
}
