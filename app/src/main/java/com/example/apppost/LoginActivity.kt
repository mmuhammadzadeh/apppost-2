package com.example.apppost

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText

class LoginActivity : AppCompatActivity() {
    private lateinit var usernameEditText: TextInputEditText
    private lateinit var passwordEditText: TextInputEditText
    private lateinit var loginButton: MaterialButton
    private lateinit var sessionManager: SessionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)

        sessionManager = SessionManager(this)

        if (sessionManager.isLoggedIn()) {
            redirectToMain()
            return
        }

        initViews()
        setupClickListeners()
    }

    private fun initViews() {
        usernameEditText = findViewById(R.id.username_edit_text)
        passwordEditText = findViewById(R.id.password_edit_text)
        loginButton = findViewById(R.id.login_button)
    }

    private fun setupClickListeners() {
        loginButton.setOnClickListener { performLogin() }
    }

    private fun performLogin() {
        val username = usernameEditText.text.toString().trim()
        val password = passwordEditText.text.toString().trim()

        if (username.isEmpty()) {
            usernameEditText.error = "نام کاربری را وارد کنید"
            usernameEditText.requestFocus()
            return
        }

        if (password.isEmpty()) {
            passwordEditText.error = "رمز عبور را وارد کنید"
            passwordEditText.requestFocus()
            return
        }

        loginButton.isEnabled = false
        loginButton.text = "در حال ورود..."

        // استفاده از متد login جدید در ApiService
        ApiService.getInstance().login(username, password, object : ApiService.LoginCallback {
            override fun onResult(response: LoginResponse) { // هنوز LoginResponse را اینجا دریافت می‌کنید
                runOnUiThread {
                    loginButton.isEnabled = true
                    loginButton.text = "ورود"

                    if (response.success) {
                        response.token?.let { token ->
                            response.user?.let { user ->
                                sessionManager.saveUserSession(token, user)
                            }
                        }

                        val welcomeMessage = "به عنوان ${response.user?.getRoleDisplayName()} وارد شدید"
                        Toast.makeText(this@LoginActivity, welcomeMessage, Toast.LENGTH_LONG).show()

                        redirectToMain()
                    } else {
                        Toast.makeText(this@LoginActivity, response.message, Toast.LENGTH_LONG).show()
                    }
                }
            }
        })
    }

    private fun redirectToMain() {
        val intent = Intent(this, MainActivity::class.java)
        startActivity(intent)
        finish()
    }
}
