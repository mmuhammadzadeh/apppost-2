package com.example.apppost

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class UserAdapter(private val users: MutableList<UserInfo>) :
    RecyclerView.Adapter<UserAdapter.UserViewHolder>() {

    class UserViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val usernameTextView: TextView = itemView.findViewById(R.id.user_item_username)
        val emailTextView: TextView = itemView.findViewById(R.id.user_item_email)
        val roleTextView: TextView = itemView.findViewById(R.id.user_item_role)
        val statusTextView: TextView = itemView.findViewById(R.id.user_item_status) // وضعیت فعال/غیرفعال
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): UserViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_user, parent, false) // layout جدید برای آیتم کاربر
        return UserViewHolder(view)
    }

    override fun onBindViewHolder(holder: UserViewHolder, position: Int) {
        val user = users[position]
        holder.usernameTextView.text = user.username
        holder.emailTextView.text = user.email
        holder.roleTextView.text = user.role
        holder.statusTextView.text = if (user.isActive) "فعال" else "غیرفعال" // نمایش وضعیت
        holder.statusTextView.setTextColor(if (user.isActive) android.graphics.Color.GREEN else android.graphics.Color.RED)
    }

    override fun getItemCount(): Int = users.size

    fun updateData(newUsers: List<UserInfo>) {
        users.clear()
        users.addAll(newUsers)
        notifyDataSetChanged()
    }
}
