package com.example.crm_caller_nxtgen.overlay.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Produces a live call duration StateFlow.
 *
 * The Compose UI observes [durationSeconds] and formats it for display.
 * The service calls [start] on OFFHOOK and [stop] on IDLE.
 */
class SessionTimerManager(private val scope: CoroutineScope) {

    private val _durationSeconds = MutableStateFlow(0L)
    val durationSeconds: StateFlow<Long> = _durationSeconds.asStateFlow()

    private var timerJob: Job? = null
    private var startedAt: Long = 0L

    fun start() {
        if (timerJob?.isActive == true) return
        startedAt = System.currentTimeMillis()
        timerJob = scope.launch {
            while (true) {
                _durationSeconds.value = (System.currentTimeMillis() - startedAt) / 1000L
                delay(1_000)
            }
        }
    }

    fun stop() {
        timerJob?.cancel()
        timerJob = null
        // Keep the final value so PostCall state can display it
    }

    fun reset() {
        stop()
        _durationSeconds.value = 0L
    }

    /** Format seconds as M:SS or H:MM:SS */
    companion object {
        fun formatDuration(seconds: Long): String {
            val h = seconds / 3600
            val m = (seconds % 3600) / 60
            val s = seconds % 60
            return if (h > 0) {
                "%d:%02d:%02d".format(h, m, s)
            } else {
                "%d:%02d".format(m, s)
            }
        }
    }
}
