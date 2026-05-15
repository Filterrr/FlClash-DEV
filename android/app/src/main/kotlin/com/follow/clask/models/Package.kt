package com.follow.clask.models

data class Package(
    val packageName: String,
    val label: String,
    val isSystem: Boolean,
    val firstInstallTime: Long,
)
