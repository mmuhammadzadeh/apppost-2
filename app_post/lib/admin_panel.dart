import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user.dart';
import 'api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:file_picker/file_picker.dart';  // Temporarily disabled due to build issues
import 'package:crypto/crypto.dart';

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
  // --- کاور ---
  String? _coverUrl;
  bool _uploadingCover = false;
  List<String> _searchResults = [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _adminToken = widget.currentUser.token ?? '';
    _tabController = TabController(length: 2, vsync: this); // Changed length to 2
    _tabController.addListener(_handleTabSelection);
    _loadUsers();
    _fetchTemplates();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    // Ping immediately and then every 3 minutes
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _sendHeartbeat();
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

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await ApiService.getUsers(_adminToken);
      setState(() => _users = users);
    } catch (e) {
      _showErrorSnackBar('خطا در بارگذاری کاربران: ${e.toString()}');
      setState(() => _users = []);
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _fetchTemplates() async {
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
          setState(() {
            _templates = templates;
            if (_templates.isNotEmpty) {
              _selectedTemplateIndex = _templates[0]['index'];
            }
          });
        } else {
          setState(
            () => _templateError = data['msg'] ?? 'خطا در دریافت الگوها',
          );
        }
      } else {
        setState(
          () => _templateError = 'خطا در دریافت الگوها: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _templateError = e.toString());
    } finally {
      setState(() {
        _loadingTemplates = false;
      });
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
        content: Text('برای آپلود عکس، لطفاً از گزینه "آپلود از URL" استفاده کنید'),
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
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
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
                            fullName: fullNameController.text.trim(),
                            password: passwordController.text.trim(),
                            role: selectedRole,
                          );

                          HapticFeedback.mediumImpact();
                          if (mounted) Navigator.pop(context);
                          _showSuccessSnackBar('کاربر با موفقیت ایجاد شد');
                          await _loadUsers();
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
                          if (mounted) Navigator.pop(context);
                          _showSuccessSnackBar(
                            'پست با موفقیت به وردپرس ارسال شد',
                          );
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
              // Refresh only the users tab
              if (_tabController.index == 0) {
                _loadUsers();
              }
              _showSuccessSnackBar('اطلاعات بروزرسانی شد.');
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
            Tab(icon: Icon(Icons.people), text: 'کاربران'),
            Tab(icon: Icon(Icons.article), text: 'ارسال پست'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUsersTab(), _buildPostsTab()],
      ),
      floatingActionButton: _getFloatingActionButton(),
    );
  }

  Widget? _getFloatingActionButton() {
    // Show FAB only on the Users tab
    if (_currentTabIndex == 0) {
      return FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('افزودن کاربر'),
      );
    }
    return null;
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

  Widget _buildUsersTab() {
    if (_loadingUsers) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('در حال بارگذاری کاربران...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  title: 'کل کاربران',
                  value: '${_users.length}',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatsCard(
                  title: 'کاربران آنلاین',
                  value:
                      '${_users.where((user) => user.isOnline ?? false).length}',
                  icon: Icons.wifi,
                  color: Colors.green,
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
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'هیچ کاربری یافت نشد',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اولین کاربر را با استفاده از دکمه پایین اضافه کنید',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: user.role == 'admin'
                                ? Colors.red.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            child: Icon(
                              user.role == 'admin'
                                  ? Icons.admin_panel_settings
                                  : Icons.person,
                              color: user.role == 'admin' ? Colors.red : Colors.blue,
                            ),
                          ),
                          title: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  user.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (user.isActive == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'غیرفعال',
                                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                                  ),
                                ),
                              if (user.isActive == 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'فعال',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (user.fullName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(user.fullName),
                              ],
                              if (user.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(user.email, style: TextStyle(color: Colors.grey[600])),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: (user.isOnline ?? false)
                                          ? Colors.green
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (user.isOnline ?? false)
                                        ? 'آنلاین'
                                        : (user.lastSeen != null
                                            ? 'آخرین بازدید: ${_formatDate(user.lastSeen!)}'
                                            : 'آفلاین'),
                                    style: TextStyle(
                                      color: (user.isOnline ?? false)
                                          ? Colors.green[700]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: user.role == 'admin'
                                  ? Colors.red[50]
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: user.role == 'admin'
                                    ? Colors.red[200]!
                                    : Colors.blue[200]!,
                              ),
                            ),
                            child: Text(
                              user.role == 'admin' ? 'مدیر' : 'کاربر',
                              style: TextStyle(
                                color: user.role == 'admin'
                                    ? Colors.red[700]
                                    : Colors.blue[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_templateError != null) {
      return Center(
        child: Text(
          'خطا در دریافت الگوها: $_templateError',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: Colors.grey[900],
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.send, color: Colors.blue[200], size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        // Added Expanded to prevent overflow
                        child: Text(
                          'ارسال پست به وردپرس',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
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
                      prefixIcon: const Icon(Icons.layers),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: Colors.grey[900],
                    style: const TextStyle(color: Colors.white),
                    items: _templates.map((template) {
                      return DropdownMenuItem(
                        value: template['index'],
                        child: Text(
                          template['name'] ?? 'الگو ${template['index']}',
                          style: const TextStyle(color: Colors.white),
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
                  Text(
                    'کاور آهنگ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _uploadingCover ? null : _pickImageAndUpload,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('آپلود از سیستم'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _urlImageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'یا آدرس عکس را وارد کنید',
                            hintStyle: const TextStyle(color: Colors.white54),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.cloud_upload,
                                color: Colors.blue,
                              ),
                              onPressed: _uploadingCover
                                  ? null
                                  : () => _uploadFromUrl(
                                      _urlImageController.text,
                                    ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[900],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'نام خواننده برای جستجوی عکس',
                      hintStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        onPressed: () async {
                          await _searchImages(_artistController.text);
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) async {
                      await _searchImages(value);
                    },
                  ),
                  if (_searchResults.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _searchResults
                            .map(
                              (imgUrl) => GestureDetector(
                                onTap: () => _uploadFromUrl(imgUrl),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Image.network(
                                    imgUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (_coverUrl != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Image.network(_coverUrl!, height: 120),
                    ),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[700]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[200],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _sendPost,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text('ارسال پست'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
