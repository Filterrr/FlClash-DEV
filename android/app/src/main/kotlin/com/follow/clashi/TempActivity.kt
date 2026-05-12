package com.follow.clashi

import android.app.Activity
import android.os.Bundle
import com.follow.clashi.extensions.wrapAction

class TempActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            wrapAction("START") -> {
                GlobalState.handleStart(applicationContext)
            }

            wrapAction("STOP") -> {
                GlobalState.handleStop()
            }

            wrapAction("CHANGE") -> {
                GlobalState.handleToggle(applicationContext)
            }
        }
        finishAndRemoveTask()
    }
}