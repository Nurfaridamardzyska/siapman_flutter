import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final ApiService _apiService = ApiService();
  bool isLoading = true;
  String errorMessage = '';
  List<dynamic> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final result = await _apiService.getNotifications();
      if (!mounted) return;
      setState(() {
        notifications = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : notifications.isEmpty
                  ? const Center(child: Text('Belum ada notifikasi'))
                  : RefreshIndicator(
                      onRefresh: loadNotifications,
                      child: ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          final data = notif['data'] ?? {};
                          return ListTile(
                            leading: Icon(Icons.notifications, color: colorScheme.primary),
                            title: Text(
                              data['type'] ?? 'Notifikasi',
                              style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data['description'] != null)
                                  Text(data['description'], style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                if (data['incident_date'] != null)
                                  Text('Tanggal: ${data['incident_date']}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                if (data['status'] != null)
                                  Text('Status: ${data['status']}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                            trailing: notif['read_at'] == null
                                ? Icon(Icons.circle, color: colorScheme.primary, size: 12)
                                : null,
                          );
                        },
                      ),
                    ),
    );
  }
}
