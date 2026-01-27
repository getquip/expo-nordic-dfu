package com.getquip.nordic

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import no.nordicsemi.android.dfu.*
import androidx.core.net.toUri
import no.nordicsemi.android.dfu.DfuServiceInitiator.createDfuNotificationChannel

class ExpoNordicDfuModule : Module() {
    private var controller: DfuServiceController? = null
    private var currentPromise: Promise? = null
    private lateinit var context: Context

    @RequiresApi(Build.VERSION_CODES.O)
    override fun definition() = ModuleDefinition {
        Name("ExpoNordicDfuModule")

        Events("DFUStateChanged", "DFUProgress")

        OnStartObserving {
            DfuServiceListenerHelper.registerProgressListener(
                requireNotNull(appContext.reactContext),
                dfuProgressListener
            )
        }

        OnStopObserving {
            DfuServiceListenerHelper.unregisterProgressListener(
                requireNotNull(appContext.reactContext),
                dfuProgressListener
            )
        }

        AsyncFunction("startAndroidDfu") {
            deviceAddress: String,
            fileUri: String,
            deviceName: String?,
            keepBond: Boolean?,
            numberOfRetries: Int?,
            packetReceiptNotificationParameter: Int?,
            prepareDataObjectDelay: Long?,
            // ---------------------
            // AsyncFunction only supports a max of 7 custom args + a promise!
            // TODO: Consider passing a JSON string and then unpacking
            // ---------------------
            // rebootTime: Long?,
            // restoreBond: Boolean?,
            promise: Promise ->

            currentPromise = promise
            if (controller !== null) {
                currentPromise?.reject("dfu_in_progress", "A DFU process is already running", null)
            } else {
                context = requireNotNull(appContext.reactContext)
                val starter = DfuServiceInitiator(deviceAddress).apply {
                    setZip(fileUri.toUri())
                    createDfuNotificationChannel(context)
                    // The device name is not required
                    deviceName?.let { setDeviceName(it) }
                    // Sets whether the bond information should be preserver after flashing new application.
                    keepBond?.let { setKeepBond(keepBond) }
                    // The number of packets of firmware data to be received by the DFU target before sending a new Packet Receipt Notification.
                    // Disabling PRNs increases upload speed but may cause failures on devices with slow flash memory.
                    packetReceiptNotificationParameter?.let {
                        if (it > 0) {
                            setPacketsReceiptNotificationsEnabled(true)
                            setPacketsReceiptNotificationsValue(it)
                        } else {
                            setPacketsReceiptNotificationsEnabled(false)
                        }
                    }
                    // For DFU bootloaders from SDK 15 and 16 it may be required to add a delay before sending each
                    // data packet. This delay gives the DFU target more time to prepare flash memory, causing less
                    // packets being dropped and more reliable transfer. Detection of packets being lost would cause
                    // automatic switch to PRN = 1, making the DFU very slow (but reliable).
                    prepareDataObjectDelay?.let { setPrepareDataObjectDelay(it) }
                    // Sets the time required by the device to reboot.
                    // rebootTime?.let { setRebootTime(it) }
                    // Sets whether a new bond should be created after the DFU is complete.
                    // The old bond information will be removed before.
                    // restoreBond?.let { setRestoreBond(it) }
                    numberOfRetries?.let { setNumberOfRetries(it) }
                }
                controller = starter.start(context, DfuService::class.java)
            }
        }

        AsyncFunction("abortAndroidDfu") { promise: Promise ->
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
    }

    private val dfuProgressListener = object : DfuProgressListenerAdapter() {
        override fun onDeviceConnecting(deviceAddress: String) =
            emitState("CONNECTING", deviceAddress)

        override fun onDeviceConnected(deviceAddress: String) =
            emitState("CONNECTED", deviceAddress)

        override fun onDfuProcessStarting(deviceAddress: String) =
            emitState("DFU_PROCESS_STARTING", deviceAddress)

        override fun onDfuProcessStarted(deviceAddress: String) =
            emitState("DFU_PROCESS_STARTED", deviceAddress)

        override fun onEnablingDfuMode(deviceAddress: String) =
            emitState("ENABLING_DFU_MODE", deviceAddress)

        override fun onProgressChanged(
            deviceAddress: String,
            percent: Int,
            speed: Float,
            avgSpeed: Float,
            currentPart: Int,
            partsTotal: Int
        ) {
            sendEvent(
                "DFUProgress",
                mapOf(
                    "deviceAddress" to deviceAddress,
                    "percent" to percent,
                    "speed" to speed,
                    "avgSpeed" to avgSpeed,
                    "currentPart" to currentPart,
                    "totalParts" to partsTotal
                )
            )
        }

        override fun onFirmwareValidating(deviceAddress: String) =
            emitState("FIRMWARE_VALIDATING", deviceAddress)

        override fun onDeviceDisconnecting(deviceAddress: String) =
            emitState("DEVICE_DISCONNECTING", deviceAddress)

        override fun onDeviceDisconnected(deviceAddress: String) =
            emitState("DEVICE_DISCONNECTED", deviceAddress)

        override fun onDfuCompleted(deviceAddress: String) {
            emitState("DFU_COMPLETED", deviceAddress)
            currentPromise?.resolve(mapOf("deviceAddress" to deviceAddress))
            resetState()
        }

        override fun onDfuAborted(deviceAddress: String) {
            emitState("DFU_ABORTED", deviceAddress)
            currentPromise?.resolve("DFU was aborted")
            resetState()

        }

        override fun onError(
                deviceAddress: String,
                error: Int,
                errorType: Int,
                message: String
        ) {
            emitState("DFU_FAILED", deviceAddress)
            val combinedMessage = "Error: $error, Error Type: $errorType, Message: $message"
            currentPromise?.reject(error.toString(), combinedMessage, null)
            resetState()
        }
    }

    private fun resetState() {
        currentPromise = null
        controller = null
        cleanUpNotifications()
    }

    private fun cleanUpNotifications() {
        Handler(Looper.getMainLooper()).postDelayed({
            // Cancel any existing DFU notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(DfuBaseService.NOTIFICATION_ID)
        }, 500) // 0.5 second delay
    }

    private fun emitState(state: String, deviceAddress: String) {
        Log.d("NordicDfu", "State: $state")
        sendEvent("DFUStateChanged", mapOf("state" to state, "deviceAddress" to deviceAddress))
    }
}
