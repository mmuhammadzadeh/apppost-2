import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user.dart';
import 'api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:file_picker/file_picker.dart';  // Temporarily disabled due to build issues
import 'package:crypto/crypto.dart';
import 'app_theme.dart';

// مدل Post
class Post {
  final int id;
  final String title;
  final String content;
  final String category;
  final String authorName;
  final String authorFullName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorName,
    required this.authorFullName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? '',
      authorName: json['author_name'] ?? '',
      authorFullName: json['author_full_name'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class AdminPanel extends StatefulWidget {
  final User currentUser;
  final VoidCallback onLogout;

  const AdminPanel({
    required this.currentUser,
    required this.onLogout,
    super.key,
  });

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _users = [];
  Timer? _heartbeatTimer;

  bool _loadingUsers = false;
  final bool _loadingPosts = false;
  bool _loadingDashboard = false;
  int _currentTabIndex = 0;
  late final String _adminToken;

  // --- فرم ارسال پست ---
  final _formKey = GlobalKey<FormState>();
  final _artistController = TextEditingController();
  final _artistEnController = TextEditingController();
  final _songController = TextEditingController();
  final _songEnController = TextEditingController();
  final _url320Controller = TextEditingController();
  final _url128Controller = TextEditingController();
  final _urlTeaserController = TextEditingController();
  final _urlImageController = TextEditingController();
  final _lyricController = TextEditingController();
  String? _error;
  bool _loading = false;
  // --- انتخاب الگو ---
  List<Map<String, dynamic>> _templates = [];
  dynamic _selectedTemplateIndex;
  bool _loadingTemplates = true;
  String? _templateError;

  // User activity data
  List<Map<String, dynamic>> _todayPosts = [];
  bool _loadingTodayPosts = false;
  String? _todayPostsError;

  // System activities tracking
  List<Map<String, dynamic>> _systemActivities = [];
  bool _loadingSystemActivities = false;
  String? _systemActivitiesError;

  // --- کاور ---
  String? _coverUrl;
  bool _uploadingCover = false;
  List<String> _searchResults = [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _adminToken = widget.currentUser.token ?? '';
    print(
      '🔑 Admin Panel Init - Token: ${_adminToken.isNotEmpty ? "Present (${_adminToken.length} chars)" : "Missing"}',
    );
    print(
      '👤 Current User: ${widget.currentUser.username}, Role: ${widget.currentUser.role}',
    );

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadUsers();
    _fetchTemplates();
    _startHeartbeat();
    _testApiConnectivity(); // Test API connectivity
  }

  void _startHeartbeat() {
    // Ping immediately and then every 3 minutes
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _sendHeartbeat();
    });

    // تایمر برای بروزرسانی وضعیت آنلاین کاربران (هر دقیقه)
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          // فقط UI را بروزرسانی می‌کنیم تا وضعیت آنلاین محاسبه شود
        });
      }
    });
  }

  void _sendHeartbeat() {
    if (widget.currentUser.token == null) return;
    ApiService.pingPresence(
      token: widget.currentUser.token!,
      userId: widget.currentUser.id,
    ).catchError((e) {
      // Log error but don't show a snackbar to avoid annoying the user
      print('Heartbeat Error: $e');
    });
  }

  void _handleTabSelection() {
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _artistController.dispose();
    _artistEnController.dispose();
    _songController.dispose();
    _songEnController.dispose();
    _url320Controller.dispose();
    _url128Controller.dispose();
    _urlTeaserController.dispose();
    _urlImageController.dispose();
    _lyricController.dispose();
    super.dispose();
  }

  // بررسی آنلاین بودن کاربر بر اساس آخرین فعالیت (10 دقیقه)
  bool _isUserOnline(User user) {
    if (user.lastSeen == null) return false;

    final now = DateTime.now();
    final lastSeen = user.lastSeen!;
    final difference = now.difference(lastSeen);

    // کاربر آنلاین است اگر در 10 دقیقه گذشته فعالیت داشته باشد
    return difference.inMinutes <= 10;
  }

  // بروزرسانی آخرین فعالیت کاربر فعلی
  void _updateCurrentUserActivity() {
    // این متد می‌تواند برای بروزرسانی lastSeen کاربر فعلی استفاده شود
    // در حال حاضر از heartbeat استفاده می‌کنیم
  }

  // بررسی فعالیت اخیر کاربر (1 ساعت گذشته)
  bool _isUserRecentlyActive(User user) {
    if (user.lastSeen == null) return false;

    final now = DateTime.now();
    final lastSeen = user.lastSeen!;
    final difference = now.difference(lastSeen);

    // کاربر اخیراً فعال است اگر در 1 ساعت گذشته فعالیت داشته باشد
    return difference.inHours <= 1;
  }

  // کارت جزئیات فعالیت
  Widget _buildActivityDetailCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedActivityDetailCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      curve: AppTheme.primaryCurve,
      child: Card(
        elevation: 8,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AppTheme.surfaceGradient,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _loadingUsers = true);
    try {
      final users = await ApiService.getUsers(_adminToken);
      if (mounted) {
        setState(() => _users = users);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('خطا در بارگذاری کاربران: ${e.toString()}');
        setState(() => _users = []);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  Future<void> _refreshDashboard() async {
    if (!mounted) return;
    setState(() => _loadingDashboard = true);
    try {
      await Future.wait([
        _loadUsers(),
        _fetchTemplates(),
        _fetchTodayPosts(),
        _fetchSystemActivities(),
      ]);
      if (mounted) {
        _showSuccessSnackBar('داشبورد بروزرسانی شد');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('خطا در بروزرسانی داشبورد: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDashboard = false);
      }
    }
  }

  Future<void> _fetchTemplates() async {
    if (!mounted) return;
    setState(() {
      _loadingTemplates = true;
      _templateError = null;
    });
    try {
      final site = 'kingmusics.com'; // فقط host
      final hashString = '1234$site' + '6789';
      final hash = md5.convert(utf8.encode(hashString)).toString();

      final response = await http.get(
        Uri.parse(
          'https://kingmusics.com/wp-admin/admin-ajax.php?action=get_mep_templates&site=$site&hash=$hash',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final templates = List<Map<String, dynamic>>.from(
            data['templates'] ?? [],
          );
          if (mounted) {
            setState(() {
              _templates = templates;
              if (_templates.isNotEmpty) {
                _selectedTemplateIndex = _templates[0]['index'];
              }
            });
          }
        } else {
          if (mounted) {
            setState(
              () => _templateError = data['msg'] ?? 'خطا در دریافت الگوها',
            );
          }
        }
      } else {
        if (mounted) {
          setState(
            () =>
                _templateError = 'خطا در دریافت الگوها: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _templateError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTemplates = false;
        });
      }
    }
  }

  Future<void> _testApiConnectivity() async {
    print('🧪 Testing API connectivity...');
    try {
      final response = await http.get(
        Uri.parse('https://gtalk.ir/app/api.php'),
      );
      print('🧪 API Test Response Status: ${response.statusCode}');
      print(
        '🧪 API Test Response Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
      );
    } catch (e) {
      print('🧪 API Test Error: $e');
    }
  }

  Future<void> _fetchTodayPosts() async {
    if (!mounted) return;

    print('🔍 Starting _fetchTodayPosts...');
    print(
      '🔑 Admin Token: ${_adminToken.isNotEmpty ? "Present (${_adminToken.length} chars)" : "Missing"}',
    );

    setState(() {
      _loadingTodayPosts = true;
      _todayPostsError = null;
    });

    // Retry mechanism
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        print(
          '📡 Calling ApiService.getTodayPosts... (Attempt ${retryCount + 1})',
        );
        final data = await ApiService.getTodayPosts(
          adminToken: _adminToken,
          limit: 20,
        );

        print('✅ API Response received: ${data.toString()}');

        if (mounted) {
          setState(() {
            _todayPosts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
          });
          print('📊 Today posts count: ${_todayPosts.length}');

          // If no posts found, show a helpful message
          if (_todayPosts.isEmpty) {
            print('ℹ️ No posts found for today');
          }
        }
        break; // Success, exit retry loop
      } catch (e) {
        retryCount++;
        print('❌ Error in _fetchTodayPosts (Attempt $retryCount): $e');
        print('❌ Error type: ${e.runtimeType}');

        if (retryCount >= maxRetries) {
          print('❌ Max retries reached. Final error: $e');
          if (mounted) {
            setState(
              () =>
                  _todayPostsError = 'خطای دسترسی به دیتابیس: ${e.toString()}',
            );
          }
        } else {
          print('🔄 Retrying in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    if (mounted) {
      setState(() => _loadingTodayPosts = false);
    }
    print('🏁 _fetchTodayPosts completed');
  }

  Future<void> _fetchSystemActivities() async {
    if (!mounted) return;
    setState(() {
      _loadingSystemActivities = true;
      _systemActivitiesError = null;
    });
    try {
      // Generate system activities based on real data
      List<Map<String, Object>> activities = [];

      // Get recent user registrations
      final recentUsers = _users
          .where((user) {
            final createdAt = DateTime.tryParse(
              user.createdAt?.toString() ?? '',
            );
            return createdAt != null &&
                DateTime.now().difference(createdAt).inHours < 24;
          })
          .take(3)
          .toList();

      for (var user in recentUsers) {
        activities.add({
          'type': 'user_added',
          'title': 'کاربر جدید اضافه شد',
          'subtitle': 'کاربر جدید به سیستم اضافه شد',
          'details':
              'کاربر با نام کاربری "${user.username}" و نقش "${user.role == 'admin' ? 'مدیر' : 'کاربر عادی'}" اضافه شد. ایمیل: ${user.email}',
          'time': _getTimeAgo(
            DateTime.tryParse(user.createdAt?.toString() ?? '') ??
                DateTime.now(),
          ),
          'status': 'موفق',
          'icon': Icons.person_add,
          'color': Colors.green as Color,
        });
      }

      // Get recent posts
      for (var post in _todayPosts.take(2)) {
        activities.add({
          'type': 'post_created',
          'title': 'پست جدید ارسال شد',
          'subtitle': 'پست جدید به وردپرس ارسال شد',
          'details':
              'پست "${post['title'] ?? 'بدون عنوان'}" در دسته‌بندی "${post['category'] ?? 'عمومی'}" ارسال شد. نویسنده: ${post['author_name_short'] ?? post['author_name'] ?? 'نامشخص'}',
          'time': _getTimeAgo(
            DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now(),
          ),
          'status': 'در انتظار تأیید',
          'icon': Icons.send,
          'color': Colors.blue as Color,
        });
      }

      // Add system update activity
      activities.add({
        'type': 'system_update',
        'title': 'سیستم بروزرسانی شد',
        'subtitle': 'اطلاعات سیستم بروزرسانی شد',
        'details':
            'بروزرسانی اطلاعات کاربران و پست‌ها انجام شد. تعداد: ${_users.length} کاربر، ${_todayPosts.length} پست امروز',
        'time': '1 ساعت پیش',
        'status': 'تکمیل شده',
        'icon': Icons.refresh,
        'color': Colors.orange as Color,
      });

      if (mounted) {
        setState(() {
          _systemActivities = activities;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _systemActivitiesError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSystemActivities = false);
      }
    }
  }

  Future<void> _pickImageAndUpload() async {
    // File picker functionality temporarily disabled due to build issues
    // Original code preserved in comments below:
    /*
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => _uploadingCover = true);
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://image.musichan.ir/api_cover.php'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          result.files.single.bytes!,
          filename: result.files.single.name,
        ),
      );
      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      var data = jsonDecode(respStr);
      if (data['success'] == true) {
        setState(() => _coverUrl = data['url']);
        _urlImageController.text = data['url'];
      } else {
        setState(() => _error = data['msg'] ?? 'خطا در آپلود کاور');
      }
      setState(() => _uploadingCover = false);
    }
    */

    // Temporary alternative: Use URL upload
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'برای آپلود عکس، لطفاً از گزینه "آپلود از URL" استفاده کنید',
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _uploadFromUrl(String url) async {
    setState(() => _uploadingCover = true);
    var response = await http.post(
      Uri.parse('http://image.musichan.ir/api_cover.php'),
      body: {'url': url},
    );
    var data = jsonDecode(response.body);
    if (data['success'] == true) {
      setState(() => _coverUrl = data['url']);
      _urlImageController.text = data['url'];
    } else {
      setState(() => _error = data['msg'] ?? 'خطا در آپلود کاور');
    }
    setState(() => _uploadingCover = false);
  }

  Future<void> _searchImages(String query) async {
    setState(() {
      _searchResults = [];
      _searchError = null;
    });
    try {
      final apiKey = 'AIzaSyAmV0rkBS-N0MEmvPIp3zMr8tnvTIkDm0A';
      final cx =
          '176cf4baf2bf042e7'; // باید CX را از Google Custom Search Console بگیری
      final url =
          'https://www.googleapis.com/customsearch/v1?q=${Uri.encodeComponent(query)}&cx=$cx&searchType=image&key=$apiKey&num=10';
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);
      if (data['items'] != null) {
        setState(() {
          _searchResults = List<String>.from(
            data['items'].map((item) => item['link']),
          );
        });
      } else {
        setState(() => _searchError = 'نتیجه‌ای یافت نشد');
      }
    } catch (e) {
      setState(() => _searchError = 'خطا در جستجوی عکس');
    }
  }

  Future<String?> _getDownloadUrl(String url) async {
    if (url.trim().isEmpty) return '';
    try {
      final response = await http.post(
        Uri.parse('https://gtalk.ir/app/dl.php'),
        body: {'url': url},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['url'] ?? '';
      }
    } catch (e) {}
    return '';
  }

  Future<void> _sendPost() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uriObj = Uri.parse('https://kingmusics.com');
      final host = uriObj.host.replaceFirst('www.', ''); // kingmusics.ir
      final hashString = '1234$host' + '6789';
      final hash = md5.convert(utf8.encode(hashString)).toString();

      // لینک‌های جدید را از API دانلود بگیر
      final url320 = await _getDownloadUrl(_url320Controller.text.trim());
      final url128 = await _getDownloadUrl(_url128Controller.text.trim());
      final urlTeaser = await _getDownloadUrl(_urlTeaserController.text.trim());

      int? sampleValue;
      if (_selectedTemplateIndex != null) {
        final parsed = int.tryParse(_selectedTemplateIndex.toString());
        sampleValue = parsed;
      }

      await ApiService.sendPostToWordPressEasyPoster(
        siteUrl: 'https://kingmusics.com',
        artist: _artistController.text.trim(),
        song: _songController.text.trim(),
        artistEn: _artistEnController.text.trim(),
        songEn: _songEnController.text.trim(),
        url320: url320 ?? '',
        url128: url128 ?? '',
        urlTeaser: urlTeaser ?? '',
        urlImage: _urlImageController.text.trim(),
        lyric: _lyricController.text.trim(),
        sample: sampleValue, // فقط اگر عدد باشد ارسال می‌شود
        author: null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('پست با موفقیت ارسال شد!'),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        _formKey.currentState!.reset();
        setState(() => _coverUrl = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showUserDetailsDialog(User user) {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController(text: user.username);
    final emailController = TextEditingController(text: user.email);
    final nameController = TextEditingController(text: user.name);
    final fullNameController = TextEditingController(text: user.fullName);
    final newPasswordController = TextEditingController();
    String selectedRole = user.role;
    int selectedStatus = user.isActive;
    String? error;
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.edit, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text('ویرایش کاربر: ${user.username}'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        controller: usernameController,
                        label: 'نام کاربری',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'نام کاربری الزامی است';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: emailController,
                        label: 'ایمیل',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'فرمت ایمیل صحیح نیست';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: nameController,
                        label: 'نام',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: fullNameController,
                        label: 'نام کامل',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 16),
                      // فیلد تغییر رمز عبور
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_reset,
                                  color: Colors.orange[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'تغییر رمز عبور',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'برای تغییر رمز عبور کاربر، فیلد زیر را پر کنید. در غیر این صورت خالی بگذارید.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: newPasswordController,
                              decoration: InputDecoration(
                                labelText: 'رمز عبور جدید (اختیاری)',
                                prefixIcon: const Icon(Icons.lock_outline),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.orange[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.orange[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.orange[600]!,
                                    width: 2,
                                  ),
                                ),
                              ),
                              obscureText: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'نقش کاربر',
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('کاربر عادی'),
                          ),
                          DropdownMenuItem(value: 'admin', child: Text('مدیر')),
                        ],
                        onChanged: (value) {
                          if (value != null) selectedRole = value;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'وضعیت کاربر',
                          prefixIcon: const Icon(Icons.person_pin),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('فعال')),
                          DropdownMenuItem(value: 0, child: Text('غیرفعال')),
                        ],
                        onChanged: (value) {
                          if (value != null) selectedStatus = value;
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setState(() {
                          loading = true;
                          error = null;
                        });

                        try {
                          // ابتدا اطلاعات کاربر را بروزرسانی می‌کنیم
                          await ApiService.updateUser(
                            adminToken: _adminToken,
                            userId: user.id,
                            username: usernameController.text.trim(),
                            email: emailController.text.trim(),
                            name: nameController.text.trim(),
                            fullName: fullNameController.text.trim(),
                            role: selectedRole,
                            isActive: selectedStatus,
                          );

                          // اگر رمز عبور جدید وارد شده، آن را تغییر می‌دهیم
                          if (newPasswordController.text.trim().isNotEmpty) {
                            try {
                              await ApiService.changePassword(
                                usernameController.text.trim(),
                                newPasswordController.text.trim(),
                              );
                            } catch (passwordError) {
                              // اگر تغییر رمز عبور شکست خورد، فقط هشدار می‌دهیم
                              // We'll show this warning after the dialog closes
                            }
                          }

                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);

                          // Show success messages after dialog is closed
                          if (mounted) {
                            _showSuccessSnackBar('کاربر با موفقیت ویرایش شد');
                            if (newPasswordController.text.trim().isNotEmpty) {
                              _showSuccessSnackBar(
                                'رمز عبور کاربر نیز با موفقیت تغییر یافت',
                              );
                            }
                            await _loadUsers();
                          }
                        } catch (e) {
                          HapticFeedback.heavyImpact();
                          setState(() => error = e.toString());
                        } finally {
                          setState(() => loading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ویرایش'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('تأیید حذف'),
                            content: Text(
                              'آیا از حذف کاربر "${user.username}" اطمینان دارید؟ این عمل قابل بازگشت نیست.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('انصراف'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('حذف'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          setState(() {
                            loading = true;
                            error = null;
                          });

                          try {
                            await ApiService.deleteUser(
                              adminToken: _adminToken,
                              userId: user.id,
                            );

                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                            if (mounted) {
                              _showSuccessSnackBar('کاربر با موفقیت حذف شد');
                              await _loadUsers();
                            }
                          } catch (e) {
                            HapticFeedback.heavyImpact();
                            setState(() => error = e.toString());
                          } finally {
                            setState(() => loading = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final fullNameController = TextEditingController();
    String selectedRole = 'user';
    String? error;
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.person_add, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('افزودن کاربر جدید'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        controller: usernameController,
                        label: 'نام کاربری',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'نام کاربری الزامی است';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: emailController,
                        label: 'ایمیل',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'فرمت ایمیل صحیح نیست';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: nameController,
                        label: 'نام',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: fullNameController,
                        label: 'نام کامل',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: passwordController,
                        label: 'رمز عبور',
                        icon: Icons.lock,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'رمز عبور الزامی است';
                          }
                          if (value.length < 6) {
                            return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: 'نقش کاربر',
                          prefixIcon: const Icon(Icons.admin_panel_settings),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'user',
                            child: Text('کاربر عادی'),
                          ),
                          DropdownMenuItem(value: 'admin', child: Text('مدیر')),
                        ],
                        onChanged: (value) {
                          if (value != null) selectedRole = value;
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setState(() {
                          loading = true;
                          error = null;
                        });

                        try {
                          await ApiService.createUser(
                            adminToken: _adminToken,
                            username: usernameController.text.trim(),
                            email: emailController.text.trim(),
                            name: nameController.text.trim(),
                            fullName: fullNameController.text.trim(),
                            password: passwordController.text.trim(),
                            role: selectedRole,
                          );

                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          if (mounted) {
                            _showSuccessSnackBar('کاربر با موفقیت ایجاد شد');
                            await _loadUsers();
                          }
                        } catch (e) {
                          HapticFeedback.heavyImpact();
                          setState(() => error = e.toString());
                        } finally {
                          setState(() => loading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ایجاد کاربر'),
              ),
            ],
          ),
        );
      },
    );
  }

  // فرم ارسال پست به وردپرس آسان‌پوستر با انتخاب الگوی پویا
  void _showWordPressPostDialog() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> templates = [];
    String? errorMessage;

    try {
      templates = await ApiService.getWordPressTemplates(
        'https://kingmusics.com',
      );
    } catch (e) {
      errorMessage = e.toString();
    }

    if (mounted) Navigator.pop(context);

    if (errorMessage != null || templates.isEmpty) {
      if (mounted) {
        _showErrorSnackBar(errorMessage ?? 'هیچ الگویی یافت نشد');
      }
      return;
    }

    // --- نکته مهم: اگر index کلید عددی نیست (مثلا uuid است)، باید به صورت درست مقداردهی کنی
    // اگر index کلید رشته‌ای است، مقدار اولیه را اینگونه بردار:
    // final firstTemplateKey = templates[0]['index'];

    dynamic selectedTemplateIndex = templates[0]['index'];
    int? authorId;

    final formKey = GlobalKey<FormState>();
    final artistController = TextEditingController();
    final artistEnController = TextEditingController();
    final songController = TextEditingController();
    final songEnController = TextEditingController();
    final url320Controller = TextEditingController();
    final url128Controller = TextEditingController();
    final urlTeaserController = TextEditingController();
    final urlImageController = TextEditingController();
    final lyricController = TextEditingController();

    String? error;
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.send, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('ارسال پست به وردپرس'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField(
                        value: selectedTemplateIndex,
                        decoration: InputDecoration(
                          labelText: 'انتخاب الگو',
                          prefixIcon: const Icon(Icons.layers),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        items: templates.map((template) {
                          return DropdownMenuItem(
                            value: template['index'],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template['name'] ??
                                      'الگو ${template['index']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (template['description'] != null &&
                                    template['description'].isNotEmpty)
                                  Text(
                                    template['description'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedTemplateIndex = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: artistController,
                        label: 'نام خواننده (فارسی)',
                        icon: Icons.person,
                        validator: (v) => v == null || v.isEmpty
                            ? 'خواننده الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: artistEnController,
                        label: 'نام خواننده (انگلیسی)',
                        icon: Icons.person_outline,
                        validator: (v) => v == null || v.isEmpty
                            ? 'خواننده انگلیسی الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: songController,
                        label: 'نام آهنگ (فارسی)',
                        icon: Icons.music_note,
                        validator: (v) => v == null || v.isEmpty
                            ? 'نام آهنگ الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: songEnController,
                        label: 'نام آهنگ (انگلیسی)',
                        icon: Icons.music_video,
                        validator: (v) => v == null || v.isEmpty
                            ? 'نام آهنگ انگلیسی الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: url320Controller,
                        label: 'لینک فایل ۳۲۰',
                        icon: Icons.link,
                        validator: (v) => v == null || v.isEmpty
                            ? 'لینک ۳۲۰ الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: url128Controller,
                        label: 'لینک فایل ۱۲۸',
                        icon: Icons.link,
                        validator: (v) => v == null || v.isEmpty
                            ? 'لینک ۱۲۸ الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: urlTeaserController,
                        label: 'لینک تیزر تصویری',
                        icon: Icons.video_library,
                        validator: (v) => v == null || v.isEmpty
                            ? 'لینک تیزر الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: urlImageController,
                        label: 'لینک کاور',
                        icon: Icons.image,
                        validator: (v) => v == null || v.isEmpty
                            ? 'لینک کاور الزامی است'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: lyricController,
                        label: 'متن ترانه',
                        icon: Icons.lyrics,
                        validator: (v) => v == null || v.isEmpty
                            ? 'متن ترانه الزامی است'
                            : null,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'شناسه نویسنده (اختیاری)',
                          hintText: 'مثلاً 1',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          authorId = int.tryParse(value);
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setState(() {
                          loading = true;
                          error = null;
                        });

                        try {
                          await ApiService.sendPostToWordPressEasyPoster(
                            siteUrl: 'https://kingmusics.com',
                            artist: artistController.text.trim(),
                            song: songController.text.trim(),
                            artistEn: artistEnController.text.trim(),
                            songEn: songEnController.text.trim(),
                            url320: url320Controller.text.trim(),
                            url128: url128Controller.text.trim(),
                            urlTeaser: urlTeaserController.text.trim(),
                            urlImage: urlImageController.text.trim(),
                            lyric: lyricController.text.trim(),
                            sample: selectedTemplateIndex,
                            author: authorId,
                          );
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          if (mounted) {
                            _showSuccessSnackBar(
                              'پست با موفقیت به وردپرس ارسال شد',
                            );
                          }
                        } catch (e) {
                          HapticFeedback.heavyImpact();
                          setState(() => error = e.toString());
                        } finally {
                          setState(() => loading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ارسال پست'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.primaryColor.withAlpha(
                (0.1 * 255).toInt(),
              ),
              child: Icon(
                Icons.admin_panel_settings,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پنل مدیریت',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.currentUser.username,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh based on current tab
              if (_tabController.index == 0) {
                // Refresh dashboard data
                _refreshDashboard();
              } else if (_tabController.index == 1) {
                _loadUsers();
              }
            },
            tooltip: 'بروزرسانی',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'خروج',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'داشبورد'),
            Tab(icon: Icon(Icons.people), text: 'کاربران'),
            Tab(icon: Icon(Icons.article), text: 'ارسال پست'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDashboardTab(), _buildUsersTab(), _buildPostsTab()],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      curve: AppTheme.primaryCurve,
      child: Card(
        elevation: 8,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: AppTheme.surfaceGradient,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActivityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
    required String details,
    required String status,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              details,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.3,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
                Icon(
                  Icons.info_outline,
                  color: color.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.post_add, color: AppTheme.primaryGold, size: 28),
                const SizedBox(width: 12),
                Text(
                  'پست‌های امروز',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_loadingTodayPosts)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_todayPostsError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'خطا در بارگذاری پست‌های امروز',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _todayPostsError!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لطفاً دوباره تلاش کنید یا با مدیر سیستم تماس بگیرید.',
                      style: TextStyle(
                        color: Colors.red.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else if (_todayPosts.isEmpty && !_loadingTodayPosts)
              Container(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'هیچ پستی امروز ایجاد نشده است',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: _todayPosts.take(5).map((post) {
                  final authorName =
                      post['author_name_short'] ??
                      post['author_name'] ??
                      'نامشخص';
                  final authorFullName =
                      post['author_full_name'] ??
                      post['author_name'] ??
                      'نامشخص';
                  final category = post['category'] ?? 'عمومی';
                  final createdAt =
                      DateTime.tryParse(post['created_at'] ?? '') ??
                      DateTime.now();
                  final timeAgo = _getTimeAgo(createdAt);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryGold.withOpacity(
                                0.1,
                              ),
                              child: Text(
                                authorName.isNotEmpty
                                    ? authorName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: AppTheme.primaryGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post['title'] ?? 'بدون عنوان',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'نویسنده: $authorFullName',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(
                                  category,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getCategoryColor(
                                    category,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: _getCategoryColor(category),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post['content'] ?? 'بدون محتوا',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              timeAgo,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textHint),
                            ),
                            Icon(
                              Icons.access_time,
                              color: AppTheme.textHint,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            if (_todayPosts.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: Text(
                    'و ${_todayPosts.length - 5} پست دیگر...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else {
      return '${difference.inDays} روز پیش';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'music':
      case 'موسیقی':
        return Colors.purple;
      case 'news':
      case 'خبر':
        return Colors.blue;
      case 'article':
      case 'مقاله':
        return Colors.green;
      case 'review':
      case 'بررسی':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSystemInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    final persianMonths = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];

    final month = persianMonths[now.month - 1];
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return '${now.day} $month ${now.year} - $hour:$minute';
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
  }) {
    return AnimatedContainer(
      duration: AppTheme.fastAnimation,
      curve: AppTheme.primaryCurve,
      child: Card(
        elevation: 8,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_loadingDashboard) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppTheme.primaryShadow,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'در حال بروزرسانی داشبورد...',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section with enhanced styling
          AnimatedContainer(
            duration: AppTheme.normalAnimation,
            curve: AppTheme.primaryCurve,
            child: Card(
              elevation: 12,
              shadowColor: AppTheme.primaryGold.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: AppTheme.primaryGradient,
                ),
                padding: const EdgeInsets.all(32),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 48,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'خوش آمدید به پنل مدیریت',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.currentUser.fullName.isNotEmpty
                                ? widget.currentUser.fullName
                                : widget.currentUser.username,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              'نقش: مدیر سیستم',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Statistics Section
          Text(
            'آمار کلی سیستم',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Responsive Grid for Statistics
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Desktop/Tablet Layout
                return Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedStatsCard(
                        title: 'کل کاربران',
                        value: '${_users.length}',
                        icon: Icons.people,
                        color: AppTheme.blueAccent,
                        gradient: AppTheme.surfaceGradient,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildEnhancedStatsCard(
                        title: 'کاربران آنلاین',
                        value:
                            '${_users.where((user) => _isUserOnline(user)).length}',
                        icon: Icons.wifi,
                        color: AppTheme.greenAccent,
                        gradient: AppTheme.surfaceGradient,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildEnhancedStatsCard(
                        title: 'کاربران فعال',
                        value:
                            '${_users.where((user) => user.isActive == 1).length}',
                        icon: Icons.check_circle,
                        color: AppTheme.accentGold,
                        gradient: AppTheme.surfaceGradient,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildEnhancedStatsCard(
                        title: 'مدیران سیستم',
                        value:
                            '${_users.where((user) => user.role == 'admin').length}',
                        icon: Icons.admin_panel_settings,
                        color: AppTheme.redAccent,
                        gradient: AppTheme.surfaceGradient,
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile Layout - 2x2 Grid
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedStatsCard(
                            title: 'کل کاربران',
                            value: '${_users.length}',
                            icon: Icons.people,
                            color: AppTheme.blueAccent,
                            gradient: AppTheme.surfaceGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEnhancedStatsCard(
                            title: 'کاربران آنلاین',
                            value:
                                '${_users.where((user) => _isUserOnline(user)).length}',
                            icon: Icons.wifi,
                            color: AppTheme.greenAccent,
                            gradient: AppTheme.surfaceGradient,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedStatsCard(
                            title: 'کاربران فعال',
                            value:
                                '${_users.where((user) => user.isActive == 1).length}',
                            icon: Icons.check_circle,
                            color: AppTheme.accentGold,
                            gradient: AppTheme.surfaceGradient,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEnhancedStatsCard(
                            title: 'مدیران سیستم',
                            value:
                                '${_users.where((user) => user.role == 'admin').length}',
                            icon: Icons.admin_panel_settings,
                            color: AppTheme.redAccent,
                            gradient: AppTheme.surfaceGradient,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 32),

          // Quick Actions Section
          Text(
            'عملیات سریع',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Responsive Quick Actions - Small cards like system statistics
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Desktop/Tablet Layout - 3 columns
                return Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedQuickActionCard(
                        title: 'افزودن کاربر جدید',
                        subtitle: 'ایجاد حساب کاربری جدید',
                        icon: Icons.person_add,
                        color: AppTheme.blueAccent,
                        onTap: _showCreateUserDialog,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildEnhancedQuickActionCard(
                        title: 'مدیریت کاربران',
                        subtitle: 'مشاهده و ویرایش کاربران',
                        icon: Icons.people,
                        color: AppTheme.accentGold,
                        onTap: () {
                          _tabController.animateTo(1);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildEnhancedQuickActionCard(
                        title: 'ارسال پست',
                        subtitle: 'ارسال پست به وردپرس',
                        icon: Icons.send,
                        color: AppTheme.greenAccent,
                        onTap: _showWordPressPostDialog,
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile Layout - 2 columns
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedQuickActionCard(
                            title: 'افزودن کاربر جدید',
                            subtitle: 'ایجاد حساب کاربری جدید',
                            icon: Icons.person_add,
                            color: AppTheme.blueAccent,
                            onTap: _showCreateUserDialog,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEnhancedQuickActionCard(
                            title: 'مدیریت کاربران',
                            subtitle: 'مشاهده و ویرایش کاربران',
                            icon: Icons.people,
                            color: AppTheme.accentGold,
                            onTap: () {
                              _tabController.animateTo(1);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedQuickActionCard(
                            title: 'ارسال پست',
                            subtitle: 'ارسال پست به وردپرس',
                            icon: Icons.send,
                            color: AppTheme.greenAccent,
                            onTap: _showWordPressPostDialog,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(), // Empty space for balance
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 32),

          // User Activity Details Section
          Text(
            'جزئیات فعالیت کاربران',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Responsive Activity Details - 2 columns layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                // Desktop/Tablet Layout - 2 columns
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedActivityDetailCard(
                            title: 'کاربران آنلاین',
                            value:
                                '${_users.where((user) => _isUserOnline(user)).length}',
                            subtitle: 'فعال در 10 دقیقه گذشته',
                            icon: Icons.wifi,
                            color: AppTheme.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEnhancedActivityDetailCard(
                            title: 'کاربران اخیر',
                            value:
                                '${_users.where((user) => _isUserRecentlyActive(user)).length}',
                            subtitle: 'فعال در 1 ساعت گذشته',
                            icon: Icons.access_time,
                            color: AppTheme.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedActivityDetailCard(
                            title: 'کاربران آفلاین',
                            value:
                                '${_users.where((user) => !_isUserOnline(user) && !_isUserRecentlyActive(user)).length}',
                            subtitle: 'غیرفعال بیش از 1 ساعت',
                            icon: Icons.offline_bolt,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(), // Empty space for balance
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Mobile Layout - 2 columns
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedActivityDetailCard(
                            title: 'کاربران آنلاین',
                            value:
                                '${_users.where((user) => _isUserOnline(user)).length}',
                            subtitle: 'فعال در 10 دقیقه گذشته',
                            icon: Icons.wifi,
                            color: AppTheme.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEnhancedActivityDetailCard(
                            title: 'کاربران اخیر',
                            value:
                                '${_users.where((user) => _isUserRecentlyActive(user)).length}',
                            subtitle: 'فعال در 1 ساعت گذشته',
                            icon: Icons.access_time,
                            color: AppTheme.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEnhancedActivityDetailCard(
                            title: 'کاربران آفلاین',
                            value:
                                '${_users.where((user) => !_isUserOnline(user) && !_isUserRecentlyActive(user)).length}',
                            subtitle: 'غیرفعال بیش از 1 ساعت',
                            icon: Icons.offline_bolt,
                            color: AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(), // Empty space for balance
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 32),

          // User Activity Section
          Text(
            'فعالیت کاربران امروز',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // User Activity Card
          _buildUserActivityCard(),

          const SizedBox(height: 32),

          // Recent Activities Section
          Text(
            'فعالیت‌های اخیر',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Responsive Recent Activities Grid - Using real data
          LayoutBuilder(
            builder: (context, constraints) {
              if (_loadingSystemActivities) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (_systemActivitiesError != null) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'خطا در بارگذاری فعالیت‌ها: $_systemActivitiesError',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (_systemActivities.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'هیچ فعالیتی یافت نشد',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (constraints.maxWidth > 600) {
                // Desktop/Tablet Layout - 2 columns
                return Column(
                  children: [
                    for (int i = 0; i < _systemActivities.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildEnhancedActivityCard(
                                icon: _systemActivities[i]['icon'] as IconData,
                                title: _systemActivities[i]['title'] as String,
                                subtitle:
                                    _systemActivities[i]['subtitle'] as String,
                                time: _systemActivities[i]['time'] as String,
                                color: _systemActivities[i]['color'] as Color,
                                details:
                                    _systemActivities[i]['details'] as String,
                                status:
                                    _systemActivities[i]['status'] as String,
                              ),
                            ),
                            if (i + 1 < _systemActivities.length) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildEnhancedActivityCard(
                                  icon:
                                      _systemActivities[i + 1]['icon']
                                          as IconData,
                                  title:
                                      _systemActivities[i + 1]['title']
                                          as String,
                                  subtitle:
                                      _systemActivities[i + 1]['subtitle']
                                          as String,
                                  time:
                                      _systemActivities[i + 1]['time']
                                          as String,
                                  color:
                                      _systemActivities[i + 1]['color']
                                          as Color,
                                  details:
                                      _systemActivities[i + 1]['details']
                                          as String,
                                  status:
                                      _systemActivities[i + 1]['status']
                                          as String,
                                ),
                              ),
                            ] else
                              Expanded(child: Container()),
                          ],
                        ),
                      ),
                  ],
                );
              } else {
                // Mobile Layout - Stacked
                return Column(
                  children: [
                    for (var activity in _systemActivities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildEnhancedActivityCard(
                          icon: activity['icon'] as IconData,
                          title: activity['title'] as String,
                          subtitle: activity['subtitle'] as String,
                          time: activity['time'] as String,
                          color: activity['color'] as Color,
                          details: activity['details'] as String,
                          status: activity['status'] as String,
                        ),
                      ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 32),

          // System Info Section
          Text(
            'اطلاعات سیستم',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildSystemInfoRow('آخرین بروزرسانی', 'همین الان'),
                  const Divider(),
                  _buildSystemInfoRow('وضعیت اتصال', 'متصل'),
                  const Divider(),
                  _buildSystemInfoRow('تاریخ و زمان', _getCurrentDateTime()),
                  const Divider(),
                  _buildSystemInfoRow('نسخه سیستم', '1.0.0'),
                  const Divider(),
                  _buildSystemInfoRow('پشتیبانی', '24/7'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppTheme.primaryShadow,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'در حال بارگذاری کاربران...',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with user count
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.darkGradient,
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.primaryShadow,
                    ),
                    child: Icon(
                      Icons.people,
                      color: AppTheme.primaryGold,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لیست کاربران',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      Text(
                        '${_users.length} کاربر',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('افزودن کاربر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                  elevation: 8,
                  shadowColor: AppTheme.primaryGold.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.surfaceGradient,
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 80,
                          color: AppTheme.textHint,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'هیچ کاربری یافت نشد',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'اولین کاربر را با استفاده از دکمه بالا اضافه کنید',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return AnimatedContainer(
                        duration: AppTheme.fastAnimation,
                        curve: AppTheme.primaryCurve,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: 8,
                          shadowColor: AppTheme.primaryGold.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: InkWell(
                            onTap: () => _showUserDetailsDialog(user),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: AppTheme.surfaceGradient,
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // User Avatar
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: user.role == 'admin'
                                          ? AppTheme.redAccent.withOpacity(0.2)
                                          : AppTheme.blueAccent.withOpacity(
                                              0.2,
                                            ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (user.role == 'admin'
                                                      ? AppTheme.redAccent
                                                      : AppTheme.blueAccent)
                                                  .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      user.role == 'admin'
                                          ? Icons.admin_panel_settings
                                          : Icons.person,
                                      color: user.role == 'admin'
                                          ? AppTheme.redAccent
                                          : AppTheme.blueAccent,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // User Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              user.username,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                            ),
                                            const SizedBox(width: 12),
                                            if (user.isActive == 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.redAccent
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: AppTheme.redAccent
                                                        .withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Text(
                                                  'غیرفعال',
                                                  style: TextStyle(
                                                    color: AppTheme.redAccent,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            if (user.isActive == 1)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.greenAccent
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: AppTheme.greenAccent
                                                        .withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Text(
                                                  'فعال',
                                                  style: TextStyle(
                                                    color: AppTheme.greenAccent,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (user.fullName.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            user.fullName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  color: AppTheme.textSecondary,
                                                ),
                                          ),
                                        ],
                                        if (user.email.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            user.email,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.textHint,
                                                ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: _isUserOnline(user)
                                                    ? AppTheme.greenAccent
                                                    : AppTheme.textHint,
                                                shape: BoxShape.circle,
                                                boxShadow: _isUserOnline(user)
                                                    ? [
                                                        BoxShadow(
                                                          color: AppTheme
                                                              .greenAccent
                                                              .withOpacity(0.5),
                                                          blurRadius: 6,
                                                          spreadRadius: 1,
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isUserOnline(user)
                                                  ? 'آنلاین'
                                                  : (user.lastSeen != null
                                                        ? 'آخرین بازدید: ${_formatDate(user.lastSeen!)}'
                                                        : 'آفلاین'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: _isUserOnline(user)
                                                        ? AppTheme.greenAccent
                                                        : AppTheme
                                                              .textSecondary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Role Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.role == 'admin'
                                          ? AppTheme.redAccent.withOpacity(0.2)
                                          : AppTheme.blueAccent.withOpacity(
                                              0.2,
                                            ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: user.role == 'admin'
                                            ? AppTheme.redAccent.withOpacity(
                                                0.5,
                                              )
                                            : AppTheme.blueAccent.withOpacity(
                                                0.5,
                                              ),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (user.role == 'admin'
                                                      ? AppTheme.redAccent
                                                      : AppTheme.blueAccent)
                                                  .withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      user.role == 'admin' ? 'مدیر' : 'کاربر',
                                      style: TextStyle(
                                        color: user.role == 'admin'
                                            ? AppTheme.redAccent
                                            : AppTheme.blueAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  Widget _buildPostsTab() {
    final theme = Theme.of(context);
    if (_loadingTemplates) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppTheme.primaryShadow,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'در حال بارگذاری الگوها...',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    if (_templateError != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.redAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppTheme.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                'خطا در دریافت الگوها',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _templateError!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 16,
          shadowColor: AppTheme.primaryGold.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: AppTheme.surfaceGradient,
            ),
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.2),
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.primaryShadow,
                        ),
                        child: Icon(
                          Icons.send,
                          color: AppTheme.primaryGold,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'ارسال پست به وردپرس',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField(
                    value: _selectedTemplateIndex,
                    decoration: InputDecoration(
                      labelText: 'انتخاب الگو',
                      prefixIcon: Icon(
                        Icons.layers,
                        color: AppTheme.primaryGold,
                      ),
                      filled: true,
                      fillColor: AppTheme.lightBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                    dropdownColor: AppTheme.lightBlue,
                    style: TextStyle(color: AppTheme.textPrimary),
                    items: _templates.map((template) {
                      return DropdownMenuItem(
                        value: template['index'],
                        child: Text(
                          template['name'] ?? 'الگو ${template['index']}',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTemplateIndex = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryGold.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.image,
                              color: AppTheme.primaryGold,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'کاور آهنگ',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppTheme.primaryGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _uploadingCover
                                  ? null
                                  : _pickImageAndUpload,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('آپلود از سیستم'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.blueAccent,
                                foregroundColor: Colors.white,
                                elevation: 6,
                                shadowColor: AppTheme.blueAccent.withOpacity(
                                  0.4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _urlImageController,
                                style: TextStyle(color: AppTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'یا آدرس عکس را وارد کنید',
                                  hintStyle: TextStyle(
                                    color: AppTheme.textHint,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.cloud_upload,
                                      color: AppTheme.blueAccent,
                                    ),
                                    onPressed: _uploadingCover
                                        ? null
                                        : () => _uploadFromUrl(
                                            _urlImageController.text,
                                          ),
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.lightBlue,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryGold.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryGold.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.primaryGold,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'نام خواننده برای جستجوی عکس',
                      hintStyle: TextStyle(color: AppTheme.textHint),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.primaryGold,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search, color: AppTheme.blueAccent),
                        onPressed: () async {
                          await _searchImages(_artistController.text);
                        },
                      ),
                      filled: true,
                      fillColor: AppTheme.lightBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryGold,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (value) async {
                      await _searchImages(value);
                    },
                  ),
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryGold.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.image_search,
                                color: AppTheme.primaryGold,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'نتایج جستجو',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppTheme.primaryGold,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _searchResults
                                  .map(
                                    (imgUrl) => GestureDetector(
                                      onTap: () => _uploadFromUrl(imgUrl),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.primaryGold
                                                .withOpacity(0.3),
                                            width: 2,
                                          ),
                                          boxShadow: AppTheme.cardShadow,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.network(
                                            imgUrl,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_coverUrl != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.greenAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'کاور انتخاب شده',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppTheme.greenAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  _coverUrl!,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _artistController,
                    label: 'نام خواننده (فارسی)',
                    icon: Icons.person,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'خواننده الزامی است' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _artistEnController,
                    label: 'نام خواننده (انگلیسی)',
                    icon: Icons.person_outline,
                    validator: (v) => v == null || v.isEmpty
                        ? 'خواننده انگلیسی الزامی است'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _songController,
                    label: 'نام آهنگ (فارسی)',
                    icon: Icons.music_note,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'نام آهنگ الزامی است' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _songEnController,
                    label: 'نام آهنگ (انگلیسی)',
                    icon: Icons.music_video,
                    validator: (v) => v == null || v.isEmpty
                        ? 'نام آهنگ انگلیسی الزامی است'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _url320Controller,
                    label: 'لینک فایل ۳۲۰',
                    icon: Icons.link,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _url128Controller,
                    label: 'لینک فایل ۱۲۸',
                    icon: Icons.link,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _urlTeaserController,
                    label: 'لینک تیزر تصویری',
                    icon: Icons.video_library,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _lyricController,
                    label: 'متن ترانه',
                    icon: Icons.lyrics,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'متن ترانه الزامی است' : null,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.redAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.redAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline,
                              color: AppTheme.redAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppTheme.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _sendPost,
                      icon: _loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Icon(Icons.send, size: 24),
                      label: Text(
                        _loading ? 'در حال ارسال...' : 'ارسال پست',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
