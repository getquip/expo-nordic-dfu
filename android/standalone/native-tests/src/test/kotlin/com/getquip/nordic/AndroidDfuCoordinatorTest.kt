package com.getquip.nordic

import org.junit.Assert.*
import org.junit.Test

class AndroidDfuCoordinatorTest {
    @Test
    fun startRejectsWhenAlreadyRunning() {
        val coordinator = AndroidDfuCoordinator()
        val starter = FakeStarter()
        val promise1 = TestPromise()
        val promise2 = TestPromise()
        val config = defaultConfig()

        coordinator.start(config, starter, promise1)
        coordinator.start(config, starter, promise2)

        assertEquals("dfu_in_progress", promise2.rejectedCode)
        assertEquals(1, starter.startCalls)
    }

    @Test
    fun startPassesConfigToStarter() {
        val coordinator = AndroidDfuCoordinator()
        val starter = FakeStarter()
        val promise = TestPromise()
        val config = AndroidDfuConfig(
            deviceAddress = "AA:BB",
            fileUri = "file:///tmp/fw.zip",
            deviceName = "Test",
            keepBond = true,
            numberOfRetries = 3,
            packetReceiptNotificationParameter = 12,
            prepareDataObjectDelay = 500L
        )

        coordinator.start(config, starter, promise)

        assertEquals(1, starter.startCalls)
        assertEquals(config, starter.lastConfig)
        assertTrue(coordinator.isRunning())
        assertNull(promise.resolvedValue)
        assertNull(promise.rejectedCode)
    }

    @Test
    fun abortRejectsWhenNoController() {
        val coordinator = AndroidDfuCoordinator()
        val promise = TestPromise()

        coordinator.abort(promise)

        assertEquals("no_running_dfu", promise.rejectedCode)
    }

    @Test
    fun abortResolvesWhenControllerAborted() {
        val coordinator = AndroidDfuCoordinator()
        val controller = FakeController(aborted = true)
        val starter = FakeStarter(controller)
        coordinator.start(defaultConfig(), starter, TestPromise())

        val promise = TestPromise()
        coordinator.abort(promise)

        assertNull(promise.rejectedCode)
        assertNull(promise.rejectedCode)
    }

    @Test
    fun abortRejectsWhenControllerNotAborted() {
        val coordinator = AndroidDfuCoordinator()
        val controller = FakeController(aborted = false)
        val starter = FakeStarter(controller)
        coordinator.start(defaultConfig(), starter, TestPromise())

        val promise = TestPromise()
        coordinator.abort(promise)

        assertEquals("dfu_abort_failed", promise.rejectedCode)
    }

    @Test
    fun onCompletedResolvesAndResets() {
        val coordinator = AndroidDfuCoordinator()
        val promise = TestPromise()
        coordinator.start(defaultConfig(), FakeStarter(), promise)

        coordinator.onCompleted("11:22")

        assertEquals(mapOf("deviceAddress" to "11:22"), promise.resolvedValue)
        assertFalse(coordinator.isRunning())
    }

    @Test
    fun onAbortedResolvesAndResets() {
        val coordinator = AndroidDfuCoordinator()
        val promise = TestPromise()
        coordinator.start(defaultConfig(), FakeStarter(), promise)

        coordinator.onAborted()

        assertEquals("DFU was aborted", promise.resolvedValue)
        assertFalse(coordinator.isRunning())
    }

    @Test
    fun onErrorRejectsAndResets() {
        val coordinator = AndroidDfuCoordinator()
        val promise = TestPromise()
        coordinator.start(defaultConfig(), FakeStarter(), promise)

        coordinator.onError(1, 2, "boom")

        assertEquals("1", promise.rejectedCode)
        assertTrue(promise.rejectedMessage?.contains("Error: 1, Error Type: 2, Message: boom") == true)
        assertFalse(coordinator.isRunning())
    }

    private fun defaultConfig() = AndroidDfuConfig(
        deviceAddress = "AA:BB",
        fileUri = "file:///tmp/fw.zip",
        deviceName = null,
        keepBond = null,
        numberOfRetries = null,
        packetReceiptNotificationParameter = null,
        prepareDataObjectDelay = null
    )

    private class FakeStarter(private val controller: DfuController = FakeController()) : AndroidDfuStarter {
        var startCalls = 0
        var lastConfig: AndroidDfuConfig? = null

        override fun start(config: AndroidDfuConfig): DfuController {
            startCalls += 1
            lastConfig = config
            return controller
        }
    }

    private class FakeController(private val aborted: Boolean = true) : DfuController {
        override fun abort() = Unit
        override val isAborted: Boolean
            get() = aborted
    }

    private class TestPromise : PromiseSink {
        var resolvedValue: Any? = null
        var rejectedCode: String? = null
        var rejectedMessage: String? = null

        override fun resolve(value: Any?) {
            resolvedValue = value
        }

        override fun reject(code: String, message: String, throwable: Throwable?) {
            rejectedCode = code
            rejectedMessage = message
        }
    }
}
