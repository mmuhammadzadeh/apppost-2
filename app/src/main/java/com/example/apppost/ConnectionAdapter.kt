package com.example.apppost

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class ConnectionAdapter(private val connections: MutableList<ConnectionInfo>) :
    RecyclerView.Adapter<ConnectionAdapter.ConnectionViewHolder>() {

    // View Holder: نگهداری ارجاع به ویوهای هر آیتم در لیست (Holds references to views for each item in the list)
    class ConnectionViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val usernameTextView: TextView = itemView.findViewById(R.id.username_text_view)
        val websiteUrlTextView: TextView = itemView.findViewById(R.id.website_url_text_view)
        val connectedAtTextView: TextView = itemView.findViewById(R.id.connected_at_text_view)
    }

    // ساخت View Holder جدید در صورت نیاز (Creates new View Holders as needed)
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ConnectionViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_connection, parent, false) // استفاده از layout جدید (Uses the new item_connection layout)
        return ConnectionViewHolder(view)
    }

    // اتصال داده‌ها به ویوهای هر آیتم (Binds data to the views of each item)
    override fun onBindViewHolder(holder: ConnectionViewHolder, position: Int) {
        val connection = connections[position]
        holder.usernameTextView.text = "کاربر: ${connection.fullName ?: connection.username}" // نمایش نام کامل یا نام کاربری (Display full name or username)
        holder.websiteUrlTextView.text = "وب‌سایت: ${connection.websiteUrl}"
        holder.connectedAtTextView.text = "زمان اتصال: ${connection.connectedAt}"
    }

    // دریافت تعداد آیتم‌های موجود در لیست (Gets the total number of items in the list)
    override fun getItemCount(): Int = connections.size

    // تابع برای بروزرسانی داده‌های آداپتور (Function to update the adapter's data)
    fun updateData(newConnections: List<ConnectionInfo>) {
        connections.clear()
        connections.addAll(newConnections)
        notifyDataSetChanged() // به RecyclerView اطلاع می‌دهد که داده‌ها تغییر کرده‌اند (Notifies RecyclerView that data has changed)
    }
}
