package com.example.apppost

// کلاس داده‌ای برای مدل‌سازی اطلاعات کاربر
data class User(
    val id: Int,
    val username: String,
    val email: String,
    val fullName: String,
    val role: String
) {
    // بررسی اینکه آیا کاربر ادمین است
    fun isAdmin(): Boolean {
        return "admin" == role
    }

    // دریافت نام نمایشی نقش کاربر
    fun getRoleDisplayName(): String {
        return if (isAdmin()) "مدیر" else "کاربر"
    }
}
