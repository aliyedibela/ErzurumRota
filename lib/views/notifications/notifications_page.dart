import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notificationSvc = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notes = await _notificationSvc.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Bildirimler",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1A237E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _notifications.isEmpty
                ? const Center(
                    child: Text("Bildirim bulunamadı",
                        style: TextStyle(color: Colors.white70)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 40, 16, 20),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, index) {
                      final note = _notifications[index];
                      return _buildNotificationCard(note);
                    },
                  ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: note.isRead ? 0.05 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: note.isRead
                    ? Colors.white10
                    : Colors.blueAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                note.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: note.isRead ? Colors.white38 : Colors.blueAccent,
              ),
            ),
            title: Text(
              note.title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: note.isRead ? FontWeight.normal : FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  note.body,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm').format(note.timestamp),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            onTap: () async {
              await _notificationSvc.markAsRead(note.id);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}