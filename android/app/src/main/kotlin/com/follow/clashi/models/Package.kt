package com.follow.clashi.models

data class Package(
    val packageName: String,
    val label: String,
    val isSystem: Boolean,
    val firstInstallTime: Long,
)
