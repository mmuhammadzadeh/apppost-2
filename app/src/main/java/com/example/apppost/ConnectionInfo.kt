package com.example.apppost

// کلاس داده‌ای برای مدل‌سازی اطلاعات اتصال کاربر به وب‌سایت (Data class for user website connection information)
data class ConnectionInfo(
    val connectionId: Int,
    val username: String,
    val fullName: String?, // نام کامل ممکن است null باشد (Full name can be null)
    val websiteUrl: String,
    val connectedAt: String
)
