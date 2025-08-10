package com.example.apppost

// رابط کاربری عمومی برای بازگشت نتایج API
interface GenericApiCallback {
    fun onResult(response: ApiResponse)
}