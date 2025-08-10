package com.example.apppost

// کلاس داده‌ای برای مدل‌سازی اطلاعات کاربر در لیست مدیریت
data class UserInfo(
    val id: Int,
    val username: String,
    val email: String,
    val fullName: String?,
    val role: String,
    val isActive: Boolean // اضافه کردن وضعیت فعال بودن
)
