package com.example.apppost

import org.json.JSONObject

// یک کلاس عمومی‌تر برای پاسخ‌های API
data class ApiResponse(
    val success: Boolean,
    val message: String,
    val data: JSONObject // کل JSON Object پاسخ سرور را نگهداری می‌کند
)
