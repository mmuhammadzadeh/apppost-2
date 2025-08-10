package com.example.apppost

// این کلاس اکنون از ApiResponse گرفته می‌شود و پارامترهای خاص خود را دارد
data class LoginResponse(
    val success: Boolean,
    val message: String,
    var token: String? = null,
    var user: User? = null
)
