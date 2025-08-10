package com.example.apppost

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.appcompat.app.AppCompatActivity

class SplashActivity : AppCompatActivity() {

    private val SPLASH_TIME_OUT: Long = 2000 // 2 ثانیه (2 seconds)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash) // مطمئن شوید این فایل XML را دارید (Make sure you have this XML layout file)

        Handler(Looper.getMainLooper()).postDelayed({
            // پس از تایم اوت، به LoginActivity بروید (After timeout, go to LoginActivity)
            val intent = Intent(this, LoginActivity::class.java)
            startActivity(intent)
            finish() // فعالیت اسپلش را از پشته حذف کنید (Remove splash activity from stack)
        }, SPLASH_TIME_OUT)
    }
}
