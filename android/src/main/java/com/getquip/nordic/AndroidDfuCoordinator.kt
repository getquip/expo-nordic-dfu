package com.getquip.nordic

data class AndroidDfuConfig(
    val deviceAddress: String,
    val fileUri: String,
    val deviceName: String?,
    val keepBond: Boolean?,
    val numberOfRetries: Int?,
    val packetReceiptNotificationParameter: Int?,
    val prepareDataObjectDelay: Long?
)

interface AndroidDfuStarter {
    fun start(config: AndroidDfuConfig): DfuController
}

interface DfuController {
    fun abort()
    val isAborted: Boolean
}

interface PromiseSink {
    fun resolve(value: Any? = null)
    fun reject(code: String, message: String, throwable: Throwable? = null)
}

class AndroidDfuCoordinator {
    private var controller: DfuController? = null
    private var currentPromise: PromiseSink? = null

    fun start(config: AndroidDfuConfig, starter: AndroidDfuStarter, promise: PromiseSink) {
        currentPromise = promise
        if (controller != null) {
            currentPromise?.reject("dfu_in_progress", "A DFU process is already running", null)
            return
        }
        controller = starter.start(config)
    }

    fun abort(promise: PromiseSink) {
        controller?.let {
            it.abort()
            if (it.isAborted) {
                promise.resolve()
            } else {
                promise.reject("dfu_abort_failed", "Unable to abort DFU process", null)
            }
        } ?: run {
            promise.reject("no_running_dfu", "There is no DFU process currently running", null)
        }
    }

    fun onCompleted(deviceAddress: String) {
        currentPromise?.resolve(mapOf("deviceAddress" to deviceAddress))
        reset()
    }

    fun onAborted() {
        currentPromise?.resolve("DFU was aborted")
        reset()
    }

    fun onError(error: Int, errorType: Int, message: String) {
        val combinedMessage = "Error: $error, Error Type: $errorType, Message: $message"
        currentPromise?.reject(error.toString(), combinedMessage, null)
        reset()
    }

    fun isRunning(): Boolean = controller != null

    private fun reset() {
        currentPromise = null
        controller = null
    }
}
