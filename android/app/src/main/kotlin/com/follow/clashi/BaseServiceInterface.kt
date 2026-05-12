package com.follow.clashi


import com.follow.clashi.models.VpnOptions

interface BaseServiceInterface {
    fun start(options: VpnOptions): Int
    fun stop()
    fun startForeground(title: String, content: String)
}