import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'api_service.dart';
import 'user.dart';
import 'app_theme.dart';

class UserPanel extends StatefulWidget {
  final User currentUser;
  final VoidCallback onLogout;
  const UserPanel({
    required this.currentUser,
    required this.onLogout,
    super.key,
  });

  @override
  State<UserPanel> createState() => _UserPanelState();
}

class _UserPanelState extends State<UserPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _heartbeatTimer;
  int _currentTabIndex = 0;

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _startHeartbeat();
    _fetchTemplates();
  }

  void _handleTabSelection() {
    setState(() {
      _currentTabIndex = _tabController.index;
    });
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
            if (templates.isNotEmpty) {
              _selectedTemplateIndex = templates.first['index'];
            }
          });
        } else {
          setState(() {
            _templateError = data['message'] ?? 'خطا در دریافت الگوها';
          });
        }
      } else {
        setState(() {
          _templateError = 'خطا در اتصال به سرور';
        });
      }
    } catch (e) {
      setState(() {
        _templateError = 'خطا: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loadingTemplates = false;
      });
    }
  }

  Future<void> _sendPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uriObj = Uri.parse('https://kingmusics.com');
      final host = uriObj.host.replaceFirst('www.', '');
      final hashString = '1234$host' + '6789';
      final hash = md5.convert(utf8.encode(hashString)).toString();

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
        url320: _url320Controller.text.trim(),
        url128: _url128Controller.text.trim(),
        urlTeaser: _urlTeaserController.text.trim(),
        urlImage: _urlImageController.text.trim(),
        lyric: _lyricController.text.trim(),
        sample: sampleValue,
        author: null,
      );

      if (mounted) {
        _showSuccessSnackBar('پست با موفقیت ارسال شد!');
        _clearForm();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickImageAndUpload() async {
    // File picker functionality temporarily disabled due to build issues
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

  void _clearForm() {
    _artistController.clear();
    _artistEnController.clear();
    _songController.clear();
    _songEnController.clear();
    _url320Controller.clear();
    _url128Controller.clear();
    _urlTeaserController.clear();
    _urlImageController.clear();
    _lyricController.clear();
    setState(() {
      _coverUrl = null;
      _searchResults.clear();
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خوش آمدید به پنل کاربری',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
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
                                color: Colors.grey[800],
                              ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            'نقش: کاربر عادی',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context).primaryColor,
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

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                _tabController.animateTo(1);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: Icon(Icons.send, color: Colors.blue, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ارسال پست جدید',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ارسال پست جدید به وردپرس',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: TextStyle(color: Colors.blue[200]),
      ),
      style: const TextStyle(color: Colors.white),
    );
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
      // Log error, but don't bother the user with a snackbar
      print('Heartbeat Error: $e');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('پنل کاربر: ${widget.currentUser.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                // Refresh dashboard
              } else if (_tabController.index == 1) {
                _fetchTemplates();
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
            Tab(icon: Icon(Icons.article), text: 'ارسال پست'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDashboardTab(), _buildPostsTab()],
      ),
    );
  }
}
