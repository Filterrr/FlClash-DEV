package com.follow.clask


import com.follow.clask.models.VpnOptions

interface BaseServiceInterface {
    fun start(options: VpnOptions): Int
    fun stop()
    fun startForeground(title: String, content: String)
}