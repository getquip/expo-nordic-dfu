import Foundation

enum ExpoNordicDfuState {
    case aborted
    case completed
    case connecting
    case disconnecting
    case enablingDfuMode
    case starting
    case uploading
    case validating
    case unknown

    var eventName: String {
        switch self {
        case .aborted: return "DFU_ABORTED"
        case .completed: return "DFU_COMPLETED"
        case .connecting: return "CONNECTING"
        case .disconnecting: return "DEVICE_DISCONNECTING"
        case .enablingDfuMode: return "ENABLING_DFU_MODE"
        case .starting: return "DFU_PROCESS_STARTING"
        case .uploading: return "DFU_UPLOADING"
        case .validating: return "FIRMWARE_VALIDATING"
        case .unknown: return "UNKNOWN_STATE"
        }
    }
}

enum ExpoNordicDfuUtils {
    static func normalizedFilePath(from fileUri: String) -> String {
        let withoutScheme = fileUri.replacingOccurrences(of: "file://", with: "")
        return withoutScheme.removingPercentEncoding ?? withoutScheme
    }
}
