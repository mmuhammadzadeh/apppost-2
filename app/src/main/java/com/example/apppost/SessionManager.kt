package com.example.apppost

import android.content.Context
import android.content.SharedPreferences

class SessionManager(context: Context) {

    private val PREF_NAME = "UserSession"
    private val KEY_TOKEN = "token"
    private val KEY_USER_ID = "user_id"
    private val KEY_USERNAME = "username"
    private val KEY_EMAIL = "email"
    private val KEY_FULL_NAME = "full_name"
    private val KEY_ROLE = "role"
    private val KEY_IS_LOGGED_IN = "is_logged_in"

    private val pref: SharedPreferences = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    private val editor: SharedPreferences.Editor = pref.edit()

    // ذخیره اطلاعات کاربر در سشن
    fun saveUserSession(token: String, user: User) {
        editor.putString(KEY_TOKEN, token)
        editor.putInt(KEY_USER_ID, user.id)
        editor.putString(KEY_USERNAME, user.username)
        editor.putString(KEY_EMAIL, user.email)
        editor.putString(KEY_FULL_NAME, user.fullName)
        editor.putString(KEY_ROLE, user.role)
        editor.putBoolean(KEY_IS_LOGGED_IN, true)
        editor.apply()
    }

    // بررسی وضعیت ورود کاربر
    fun isLoggedIn(): Boolean {
        return pref.getBoolean(KEY_IS_LOGGED_IN, false)
    }

    // دریافت اطلاعات کاربر فعلی
    fun getCurrentUser(): User? {
        if (!isLoggedIn()) return null
        return User(
            pref.getInt(KEY_USER_ID, 0),
            pref.getString(KEY_USERNAME, "") ?: "",
            pref.getString(KEY_EMAIL, "") ?: "",
            pref.getString(KEY_FULL_NAME, "") ?: "",
            pref.getString(KEY_ROLE, "user") ?: "user"
        )
    }

    // دریافت توکن کاربر
    fun getToken(): String? {
        return pref.getString(KEY_TOKEN, "")
    }

    // خروج کاربر از سشن
    fun logout() {
        editor.clear()
        editor.apply()
    }
}
