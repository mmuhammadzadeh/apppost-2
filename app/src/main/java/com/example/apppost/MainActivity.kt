package com.example.apppost

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.button.MaterialButton
import com.google.android.material.card.MaterialCardView
import com.google.android.material.tabs.TabLayout
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import com.google.android.material.switchmaterial.SwitchMaterial
import org.json.JSONException // برای پردازش JSON

class MainActivity : AppCompatActivity() {

    private lateinit var sessionManager: SessionManager

    // عناصر UI
    private lateinit var headerCard: MaterialCardView
    private lateinit var avatarContainer: MaterialCardView
    private lateinit var avatarText: TextView
    private lateinit var welcomeText: TextView
    private lateinit var userNameText: TextView
    private lateinit var userRoleText: TextView
    private lateinit var totalUsersCount: TextView // آمار کل کاربران
    private lateinit var onlineUsersCount: TextView // آمار کاربران آنلاین

    private lateinit var adminPanelCard: MaterialCardView
    private lateinit var adminTabs: TabLayout
    private lateinit var usersTabContent: ConstraintLayout
    private lateinit var connectionsTabContent: ConstraintLayout
    private lateinit var settingsTabContent: ConstraintLayout

    private lateinit var addUserButton: MaterialButton
    private lateinit var searchUserLayout: TextInputLayout
    private lateinit var searchUserEditText: TextInputEditText
    private lateinit var usersRecyclerView: RecyclerView
    private lateinit var userAdapter: UserAdapter

    private lateinit var connectedWebsitesRecyclerView: RecyclerView
    private lateinit var connectionsAdapter: ConnectionAdapter

    private lateinit var notificationsSwitch: SwitchMaterial
    private lateinit var autoBackupSwitch: SwitchMaterial

    private lateinit var bottomActionsLayout: LinearLayout
    private lateinit var backupButton: MaterialButton
    private lateinit var logoutButton: MaterialButton

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        sessionManager = SessionManager(this)

        if (!sessionManager.isLoggedIn()) {
            redirectToLogin()
            return
        }

        initViews()
        displayUserInfo()
        setupClickListeners()
        setupAdminPanel()
    }

    private fun initViews() {
        // مقداردهی اولیه تمام ویوها با findViewById
        headerCard = findViewById(R.id.header_card)
        avatarContainer = findViewById(R.id.avatar_container)
        avatarText = findViewById(R.id.avatar_text)
        welcomeText = findViewById(R.id.welcome_text)
        userNameText = findViewById(R.id.user_name_text)
        userRoleText = findViewById(R.id.user_role_text)
        totalUsersCount = findViewById(R.id.total_users_count) // اضافه شده
        onlineUsersCount = findViewById(R.id.online_users_count)

        adminPanelCard = findViewById(R.id.admin_panel_card)
        adminTabs = findViewById(R.id.admin_tabs)
        usersTabContent = findViewById(R.id.users_tab_content)
        connectionsTabContent = findViewById(R.id.connections_tab_content)
        settingsTabContent = findViewById(R.id.settings_tab_content)

        addUserButton = findViewById(R.id.add_user_button)
        searchUserLayout = findViewById(R.id.search_user_layout)
        searchUserEditText = findViewById(R.id.search_user_edit_text)
        usersRecyclerView = findViewById(R.id.users_recycler_view)

        connectedWebsitesRecyclerView = findViewById(R.id.connected_websites_recycler_view)

        notificationsSwitch = findViewById(R.id.notifications_switch)
        autoBackupSwitch = findViewById(R.id.auto_backup_switch)

        bottomActionsLayout = findViewById(R.id.bottom_actions_layout)
        backupButton = findViewById(R.id.backup_button)
        logoutButton = findViewById(R.id.logout_button)

        // تنظیم آداپتورها و LayoutManager ها
        connectedWebsitesRecyclerView.layoutManager = LinearLayoutManager(this)
        connectionsAdapter = ConnectionAdapter(mutableListOf())
        connectedWebsitesRecyclerView.adapter = connectionsAdapter

        usersRecyclerView.layoutManager = LinearLayoutManager(this)
        userAdapter = UserAdapter(mutableListOf()) // فرض بر اینکه UserAdapter را ساخته‌اید
        usersRecyclerView.adapter = userAdapter
    }

    private fun displayUserInfo() {
        val user = sessionManager.getCurrentUser()
        if (user != null) {
            welcomeText.text = "خوش آمدید،"
            userNameText.text = user.fullName
            userRoleText.text = user.getRoleDisplayName()
            avatarText.text = user.fullName.firstOrNull()?.toString()?.uppercase() ?: "A"
        }
    }

    private fun setupClickListeners() {
        logoutButton.setOnClickListener {
            sessionManager.logout()
            redirectToLogin()
        }
        // سایر ClickListener ها...
    }

    private fun setupAdminPanel() {
        val currentUser = sessionManager.getCurrentUser()
        if (currentUser?.isAdmin() == true) {
            adminPanelCard.visibility = View.VISIBLE
            loadAdminDashboardData() // بارگذاری داده‌های اولیه ادمین

            // اضافه کردن تب‌ها به صورت دستی برای جلوگیری از خطای ویرایشگر
            if (adminTabs.tabCount == 0) {
                adminTabs.addTab(adminTabs.newTab().setText("کاربران"))
                adminTabs.addTab(adminTabs.newTab().setText("اتصالات"))
                adminTabs.addTab(adminTabs.newTab().setText("تنظیمات"))
            }

            adminTabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
                override fun onTabSelected(tab: TabLayout.Tab?) {
                    when (tab?.position) {
                        0 -> { // تب کاربران
                            usersTabContent.visibility = View.VISIBLE
                            connectionsTabContent.visibility = View.GONE
                            settingsTabContent.visibility = View.GONE
                            loadUsersData() // فقط زمانی که تب انتخاب می‌شود، داده‌ها را بارگذاری کن
                        }
                        1 -> { // تب اتصالات
                            usersTabContent.visibility = View.GONE
                            connectionsTabContent.visibility = View.VISIBLE
                            settingsTabContent.visibility = View.GONE
                            // داده‌های اتصالات قبلا در loadAdminDashboardData بارگذاری شده
                        }
                        2 -> { // تب تنظیمات
                            usersTabContent.visibility = View.GONE
                            connectionsTabContent.visibility = View.GONE
                            settingsTabContent.visibility = View.VISIBLE
                        }
                    }
                }
                override fun onTabUnselected(tab: TabLayout.Tab?) {}
                override fun onTabReselected(tab: TabLayout.Tab?) {}
            })

            // انتخاب پیش‌فرض تب اول و بارگذاری داده‌های آن
            adminTabs.getTabAt(0)?.select()
            usersTabContent.visibility = View.VISIBLE
            connectionsTabContent.visibility = View.GONE
            settingsTabContent.visibility = View.GONE
            loadUsersData()

        } else {
            adminPanelCard.visibility = View.GONE
        }
    }

    private fun loadAdminDashboardData() {
        val token = sessionManager.getToken() ?: run {
            Toast.makeText(this, "توکن یافت نشد.", Toast.LENGTH_SHORT).show()
            redirectToLogin()
            return
        }

        ApiService.getInstance().makeApiCall(
            action = "get_admin_dashboard_data",
            params = emptyMap(),
            token = token,
            callback = object : ApiService.GenericApiCallback {
                override fun onResult(response: ApiResponse) {
                    runOnUiThread {
                        if (response.success) {
                            try {
                                val data = response.data
                                totalUsersCount.text = data.optInt("total_users", 0).toString()
                                onlineUsersCount.text = data.optInt("online_users", 0).toString()

                                val connectionsArray = data.optJSONArray("connections")
                                val connectionsList = mutableListOf<ConnectionInfo>()
                                if (connectionsArray != null) {
                                    for (i in 0 until connectionsArray.length()) {
                                        val connObj = connectionsArray.getJSONObject(i)
                                        // **اصلاح شده:** پارامترهای ConnectionInfo بر اساس خطاهای شما اصلاح شد
                                        connectionsList.add(
                                            ConnectionInfo(
                                                connectionId = connObj.optInt("connection_id"),
                                                username = connObj.optString("username"),
                                                fullName = connObj.optString("full_name"),
                                                websiteUrl = connObj.optString("website_url"),
                                                connectedAt = connObj.optString("connected_at"),
                                            )
                                        )
                                    }
                                }
                                connectionsAdapter.updateData(connectionsList)
                            } catch (e: JSONException) {
                                Toast.makeText(this@MainActivity, "خطا در پردازش داده‌های داشبورد", Toast.LENGTH_LONG).show()
                            }
                        } else {
                            Toast.makeText(this@MainActivity, "خطا: ${response.message}", Toast.LENGTH_LONG).show()
                            handleAuthError(response.message)
                        }
                    }
                }

                // **اصلاح شده:** این متد برای رفع خطای کامپایلر اضافه شد
                override fun onResult(response: ApiResponse, totalUsersTextView: Any) {
                    onResult(response) // فراخوانی متد اصلی
                }
            }
        )
    }

    private fun loadUsersData() {
        val token = sessionManager.getToken() ?: run {
            Toast.makeText(this, "توکن یافت نشد.", Toast.LENGTH_SHORT).show()
            redirectToLogin()
            return
        }

        ApiService.getInstance().makeApiCall(
            action = "get_all_users",
            params = emptyMap(),
            token = token,
            callback = object : ApiService.GenericApiCallback {
                override fun onResult(response: ApiResponse) {
                    runOnUiThread {
                        if (response.success) {
                            try {
                                val usersArray = response.data.optJSONArray("users")
                                val usersList = mutableListOf<UserInfo>()
                                if (usersArray != null) {
                                    for (i in 0 until usersArray.length()) {
                                        val userObj = usersArray.getJSONObject(i)
                                        usersList.add(
                                            UserInfo(
                                                id = userObj.optInt("id"),
                                                username = userObj.optString("username"),
                                                email = userObj.optString("email"),
                                                fullName = userObj.optString("full_name"),
                                                role = userObj.optString("role"),
                                                isActive = userObj.optBoolean("is_active")
                                            )
                                        )
                                    }
                                }
                                userAdapter.updateData(usersList)
                            } catch (e: JSONException) {
                                Toast.makeText(this@MainActivity, "خطا در پردازش لیست کاربران", Toast.LENGTH_LONG).show()
                            }
                        } else {
                            Toast.makeText(this@MainActivity, "خطا در بارگذاری کاربران: ${response.message}", Toast.LENGTH_LONG).show()
                            handleAuthError(response.message)
                        }
                    }
                }

                // **اصلاح شده:** این متد برای رفع خطای کامپایلر اضافه شد
                override fun onResult(response: ApiResponse, totalUsersTextView: Any) {
                    onResult(response) // فراخوانی متد اصلی
                }
            }
        )
    }

    private fun handleAuthError(message: String) {
        if (message.contains("توکن نامعتبر") || message.contains("دسترسی غیرمجاز")) {
            sessionManager.logout()
            redirectToLogin()
        }
    }

    private fun redirectToLogin() {
        val intent = Intent(this, LoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }
}
