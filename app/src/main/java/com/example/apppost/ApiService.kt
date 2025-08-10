package com.example.apppost

import android.os.AsyncTask
import org.json.JSONObject
import java.io.*
import java.net.HttpURLConnection
import java.net.URL

class ApiService {


    private val BASE_URL = "https://gtalk.ir/app/api.php"

    companion object {
        @Volatile
        private var instance: ApiService? = null

        fun getInstance() =
            instance ?: synchronized(this) {
                instance ?: ApiService().also { instance = it }
            }
    }

    // تابع ورود کاربر
    fun login(username: String, password: String, callback: LoginCallback) {
        makeApiCall(
            action = "login",
            params = mapOf("username" to username, "password" to password),
            token = null,
            callback = object : GenericApiCallback {
                override fun onResult(apiResponse: ApiResponse) {
                    val loginResponse = LoginResponse(
                        success = apiResponse.success,
                        message = apiResponse.message,
                        token = null,
                        user = null
                    )

                    if (apiResponse.success) {
                        apiResponse.data.optString("token").let { token ->
                            if (token.isNotEmpty()) {
                                loginResponse.token = token
                            }
                        }
                        apiResponse.data.optJSONObject("user")?.let { userObj ->
                            loginResponse.user = User(
                                id = userObj.optInt("id"),
                                username = userObj.optString("username"),
                                email = userObj.optString("email"),
                                fullName = userObj.optString("full_name", userObj.optString("username")),
                                role = userObj.optString("role")
                            )
                        }
                    }
                    callback.onResult(loginResponse)
                }

                override fun onResult(response: ApiResponse, totalUsersTextView: Any) {
                    TODO("Not yet implemented")
                }
            }
        )
    }

    // تابع عمومی برای ارسال درخواست‌های API
    fun makeApiCall(
        action: String,
        params: Map<String, Any> = emptyMap(),
        token: String? = null,
        callback: GenericApiCallback
    ) {
        GenericTask(action, params, token, callback).execute()
    }

    // کلاس داخلی برای انجام عملیات شبکه در پس‌زمینه
    private inner class GenericTask(
        private val action: String,
        private val params: Map<String, Any>,
        private val token: String?,
        private val callback: GenericApiCallback
    ) : AsyncTask<Void, Void, ApiResponse>() {

        override fun doInBackground(vararg voids: Void): ApiResponse {
            try {
                val url = URL(BASE_URL)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                connection.setRequestProperty("Accept", "application/json")
                if (token != null) {
                    connection.setRequestProperty("Authorization", "Bearer $token")
                }
                connection.doOutput = true
                connection.setConnectTimeout(10000)
                connection.setReadTimeout(10000)

                val requestJson = JSONObject(params).apply {
                    put("action", action)
                }

                connection.outputStream.use { os ->
                    OutputStreamWriter(os, "UTF-8").use { osw ->
                        osw.write(requestJson.toString())
                        osw.flush()
                    }
                }

                val responseCode = connection.responseCode
                val inputStream = if (responseCode >= 200 && responseCode < 300) {
                    connection.inputStream
                } else {
                    connection.errorStream
                }

                val response = StringBuilder()
                BufferedReader(InputStreamReader(inputStream, "UTF-8")).use { reader ->
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        response.append(line)
                    }
                }
                connection.disconnect()

                val jsonResponse = JSONObject(response.toString())
                return ApiResponse(
                    success = jsonResponse.optBoolean("success", false),
                    message = jsonResponse.optString("message", "Unknown error"),
                    data = jsonResponse
                )

            } catch (e: Exception) {
                return ApiResponse(
                    success = false,
                    message = "Connection error: ${e.message}",
                    data = JSONObject()
                )
            }
        }

        override fun onPostExecute(response: ApiResponse) {
            callback.onResult(response) // مطمئن شوید این خط دقیقاً همین است و TODO ندارد
        }
    }

    // رابط کاربری برای بازگشت نتیجه ورود
    interface LoginCallback {
        fun onResult(response: LoginResponse)
    }

    // رابط کاربری عمومی برای بازگشت نتایج API
    interface GenericApiCallback {
        fun onResult(response: ApiResponse)
        fun onResult(response: ApiResponse, totalUsersTextView: Any)
    }
}
