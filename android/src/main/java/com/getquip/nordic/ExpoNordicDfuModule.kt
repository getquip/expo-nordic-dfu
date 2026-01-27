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
    private val coordinator = AndroidDfuCoordinator()
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

            context = requireNotNull(appContext.reactContext)
            val config = AndroidDfuConfig(
                deviceAddress = deviceAddress,
                fileUri = fileUri,
                deviceName = deviceName,
                keepBond = keepBond,
                numberOfRetries = numberOfRetries,
                packetReceiptNotificationParameter = packetReceiptNotificationParameter,
                prepareDataObjectDelay = prepareDataObjectDelay
            )
            val promiseSink = ExpoPromiseSink(promise)
            val starter = NordicAndroidDfuStarter(context)
            coordinator.start(config, starter, promiseSink)
        }

        AsyncFunction("abortAndroidDfu") { promise: Promise ->
            coordinator.abort(ExpoPromiseSink(promise))
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
                DfuEventPayloads.progressPayload(
                    deviceAddress = deviceAddress,
                    percent = percent,
                    speed = speed,
                    avgSpeed = avgSpeed,
                    currentPart = currentPart,
                    totalParts = partsTotal
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
            coordinator.onCompleted(deviceAddress)
            cleanUpNotifications()
        }

        override fun onDfuAborted(deviceAddress: String) {
            emitState("DFU_ABORTED", deviceAddress)
            coordinator.onAborted()
            cleanUpNotifications()

        }

        override fun onError(
                deviceAddress: String,
                error: Int,
                errorType: Int,
                message: String
        ) {
            emitState("DFU_FAILED", deviceAddress)
            coordinator.onError(error, errorType, message)
            cleanUpNotifications()
        }
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
        sendEvent("DFUStateChanged", DfuEventPayloads.statePayload(state, deviceAddress))
    }
}

private class ExpoPromiseSink(private val promise: Promise) : PromiseSink {
    override fun resolve(value: Any?) {
        promise.resolve(value)
    }

    override fun reject(code: String, message: String, throwable: Throwable?) {
        promise.reject(code, message, throwable)
    }
}

private class NordicAndroidDfuStarter(private val context: Context) : AndroidDfuStarter {
    override fun start(config: AndroidDfuConfig): DfuController {
        val starter = DfuServiceInitiator(config.deviceAddress).apply {
            setZip(config.fileUri.toUri())
            createDfuNotificationChannel(context)
            config.deviceName?.let { setDeviceName(it) }
            config.keepBond?.let { setKeepBond(it) }
            config.packetReceiptNotificationParameter?.let {
                if (it > 0) {
                    setPacketsReceiptNotificationsEnabled(true)
                    setPacketsReceiptNotificationsValue(it)
                } else {
                    setPacketsReceiptNotificationsEnabled(false)
                }
            }
            config.prepareDataObjectDelay?.let { setPrepareDataObjectDelay(it) }
            config.numberOfRetries?.let { setNumberOfRetries(it) }
        }
        return NordicDfuController(starter.start(context, DfuService::class.java))
    }
}

private class NordicDfuController(private val controller: DfuServiceController) : DfuController {
    override fun abort() {
        controller.abort()
    }

    override val isAborted: Boolean
        get() = controller.isAborted
}
