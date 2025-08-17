import 'dart:convert'; // برای کار با JSON
import 'package:http/http.dart' as http; // برای درخواست‌های HTTP
import 'package:crypto/crypto.dart'; // برای توابع هشینگ مثل MD5
import 'user.dart'; // مدل User را وارد می‌کند
import 'post.dart'; // مدل Post را وارد می‌کند

class ApiService {
  // آدرس پایه API شما
  static const String baseUrl = 'https://gtalk.ir/app/api.php';
  // presence از طریق همین api.php با اکشن heartbeat/logout مدیریت می‌شود

  // متد ورود کاربر
  static Future<User?> login(String username, String password) async {
    try {
      print('Attempting login for username: $username');
      print('API URL: $baseUrl');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login',
          'username': username,
          'password': password,
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      // بررسی پاسخ سرور
      if (response.statusCode != 200) {
        throw "خطای HTTP: ${response.statusCode} - ${response.reasonPhrase}";
      }

      if (response.body.isEmpty) {
        throw "پاسخ سرور خالی است";
      }

      final data = jsonDecode(response.body);
      print('Parsed response data: $data');

      // بررسی موفقیت‌آمیز بودن ورود و وجود توکن
      if (data['success'] == true && data['token'] != null) {
        print('Login successful, token received');
        // استفاده از factory constructor مخصوص ورود
        return User.fromLoginJson(data['user'], data['token']);
      } else {
        // نمایش پیام خطا در صورت ناموفق بودن ورود
        final errorMessage = data['message'] ?? data['error'] ?? 'خطا در ورود';
        print('Login failed: $errorMessage');
        throw errorMessage;
      }
    } catch (e) {
      print('Exception during login: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw "خطا در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.";
      } else if (e.toString().contains('TimeoutException')) {
        throw "زمان اتصال به پایان رسید. لطفاً دوباره تلاش کنید.";
      } else {
        throw e.toString();
      }
    }
  }

  // بروزرسانی حضور کاربر (heartbeat)
  static Future<void> pingPresence({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': 'heartbeat'}),
      );
      if (response.statusCode != 200) {
        throw 'heartbeat http ${response.statusCode}';
      }
    } catch (e) {
      // Log error but don't throw to avoid breaking the app
      print('pingPresence error: $e');
    }
  }

  // خروج کاربر و آفلاین کردن وضعیت
  static Future<void> logout({
    required String token,
    required int userId,
  }) async {
    try {
      await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'action': 'logout'}),
      );
    } catch (_) {}
  }

  // متد ایجاد کاربر جدید (فقط برای مدیران)
  static Future<String> createUser({
    required String adminToken,
    required String username,
    required String email,
    required String name,
    required String fullName,
    required String password,
    String role = 'user',
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer $adminToken', // ارسال توکن مدیر برای احراز هویت
      },
      body: jsonEncode({
        'action': 'create_user',
        'username': username,
        'email': email,
        'name': name,
        'full_name': fullName,
        'role': role,
        'password': password,
      }),
    );

    // بررسی پاسخ سرور
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw "پاسخ سرور معتبر نیست. لطفاً سرور را بررسی کنید.";
    }

    final data = jsonDecode(response.body);

    // بررسی موفقیت‌آمیز بودن ساخت کاربر
    if (data['success'] == true) {
      return "کاربر با موفقیت ساخته شد";
    } else {
      throw data['message'] ?? 'خطا در ساخت کاربر';
    }
  }

  // متد ویرایش کاربر (فقط برای مدیران)
  static Future<String> updateUser({
    required String adminToken,
    required int userId,
    required String username,
    required String email,
    required String name,
    required String fullName,
    required String role,
    required int isActive,
    String? password, // اضافه کردن فیلد رمز عبور اختیاری
  }) async {
    final Map<String, dynamic> requestBody = {
      'action': 'update_user',
      'user_id': userId,
      'username': username,
      'email': email,
      'name': name,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
    };

    // اضافه کردن رمز عبور به درخواست فقط اگر ارائه شده باشد
    if (password != null && password.isNotEmpty) {
      requestBody['password'] = password;
      print('Password will be updated: ${password.length} characters');
    } else {
      print('No password provided for update');
    }

    print('Update user request body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
      body: jsonEncode(requestBody),
    );

    // بررسی پاسخ سرور
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw "پاسخ سرور معتبر نیست. لطفاً سرور را بررسی کنید.";
    }

    final data = jsonDecode(response.body);
    print('Update user response: ${jsonEncode(data)}');

    // بررسی موفقیت‌آمیز بودن ویرایش کاربر
    if (data['success'] == true) {
      return "کاربر با موفقیت ویرایش شد";
    } else {
      throw data['message'] ?? 'خطا در ویرایش کاربر';
    }
  }

  // متد حذف کاربر (فقط برای مدیران)
  static Future<String> deleteUser({
    required String adminToken,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $adminToken',
      },
      body: jsonEncode({'action': 'delete_user', 'user_id': userId}),
    );

    // بررسی پاسخ سرور
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw "پاسخ سرور معتبر نیست. لطفاً سرور را بررسی کنید.";
    }

    final data = jsonDecode(response.body);

    // بررسی موفقیت‌آمیز بودن حذف کاربر
    if (data['success'] == true) {
      return "کاربر با موفقیت حذف شد";
    } else {
      throw data['message'] ?? 'خطا در حذف کاربر';
    }
  }

  // متد دریافت لیست کاربران
  static Future<List<User>> getUsers(String adminToken) async {
    final uri = Uri.parse('$baseUrl?action=get_users&token=$adminToken');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $adminToken'},
    );

    print('getUsers response.body:');
    print(response.body);

    // بررسی پاسخ سرور
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw "پاسخ سرور معتبر نیست.";
    }

    final data = json.decode(response.body);

    // بررسی موفقیت‌آمیز بودن دریافت لیست کاربران
    if (data['success']) {
      // استفاده از factory constructor مخصوص لیست کاربران
      return (data['users'] as List)
          .map((userJson) => User.fromListJson(userJson))
          .toList();
    } else {
      throw Exception(data['message']);
    }
  }

  // متد دریافت لیست پست‌ها
  static Future<List<Post>> getPosts() async {
    // این متد نیازی به توکن احراز هویت ندارد، اما اگر پست‌ها نیاز به لاگین برای نمایش دارند، باید توکن را اضافه کنید.
    final response = await http.get(Uri.parse('$baseUrl?action=get_posts'));

    print('getPosts response.body:');
    print(response.body);

    // بررسی پاسخ سرور
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw "پاسخ سرور معتبر نیست.";
    }

    final data = json.decode(response.body);

    // بررسی موفقیت‌آمیز بودن دریافت لیست پست‌ها
    if (data['success']) {
      return (data['posts'] as List)
          .map((post) => Post.fromJson(post))
          .toList();
    } else {
      throw Exception(data['message']);
    }
  }

  // متد ایجاد پست جدید (از پنل مدیریت فلاتر حذف شد اما در API باقی می‌ماند)
  static Future<Map<String, dynamic>> createPost({
    required String token,
    required String title,
    required String content,
    required String category,
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'action': 'create_post',
        'title': title,
        'content': content,
        'category': category,
      }),
    );

    // بررسی پاسخ سرور
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw "پاسخ سرور معتبر نیست.";
    }

    final data = json.decode(response.body);

    // بررسی موفقیت‌آمیز بودن ایجاد پست
    if (!data['success']) {
      throw Exception(data['message']);
    }

    return data;
  }

  // متد ویرایش پست
  static Future<void> updatePost({
    required String token,
    required int postId,
    required String title,
    required String content,
    required String category,
  }) async {
    final response = await http.put(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'action': 'update_post',
        'post_id': postId,
        'title': title,
        'content': content,
        'category': category,
      }),
    );

    // بررسی پاسخ سرور
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw "پاسخ سرور معتبر نیست.";
    }

    final data = json.decode(response.body);

    // بررسی موفقیت‌آمیز بودن به‌روزرسانی پست
    if (!data['success']) {
      throw Exception(data['message']);
    }
  }

  // متد دریافت لیست الگوهای آسان‌پوستر از وردپرس
  static Future<List<Map<String, dynamic>>> getWordPressTemplates(
    String siteUrl,
  ) async {
    try {
      final host = Uri.parse(siteUrl).host;
      // ساخت رشته هش برای احراز هویت با پلاگین وردپرس
      final hashString =
          '1234$host'
          '6789';
      final hash = md5.convert(utf8.encode(hashString)).toString();

      final uri = Uri.parse(
        '$siteUrl/wp-admin/admin-ajax.php?action=get_mep_templates&hash=$hash',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('خطا در دریافت لیست الگوها: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['templates'] ?? []);
      } else {
        throw Exception(data['message'] ?? 'دریافت الگوها ناموفق بود');
      }
    } catch (e) {
      throw Exception('خطا در دریافت الگوها: $e');
    }
  }

  // متد ارسال پست به وردپرس با انتخاب الگو (ویژه آسان‌پوستر)
  static Future<void> sendPostToWordPressEasyPoster({
    required String siteUrl,
    required String artist,
    required String song,
    required String artistEn,
    required String songEn,
    required String url320,
    required String url128,
    required String urlTeaser,
    required String urlImage,
    required String lyric,
    int? sample, // شناسه الگو
    int? author, // شناسه نویسنده
  }) async {
    final uri = Uri.parse('$siteUrl/wp-admin/admin-ajax.php?action=mep_api');
    final host = Uri.parse(siteUrl).host;
    // ساخت رشته هش برای احراز هویت با پلاگین وردپرس
    final hashString =
        '1234$host'
        '6789';
    final hash = md5.convert(utf8.encode(hashString)).toString();

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }, // نوع محتوا برای ارسال فرم URL-encoded
        body: {
          'hash': hash,
          'artist': artist,
          'song': song,
          'artist_en': artistEn,
          'song_en': songEn,
          'url_320': url320,
          'url_128': url128,
          'url_teaser': urlTeaser,
          'url_image': urlImage,
          'lyric': lyric,
          if (sample != null)
            'sample': sample.toString(), // افزودن شناسه الگو در صورت وجود
          if (author != null)
            'author': author.toString(), // افزودن شناسه نویسنده در صورت وجود
        },
      );

      if (response.statusCode != 200) {
        throw Exception('خطا در ارسال پست: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body);

      // بررسی موفقیت‌آمیز بودن ارسال پست وردپرس
      if (jsonResponse['success'] != true) {
        throw Exception(
          jsonResponse['data']?['text'] ??
              'خطای ناشناخته هنگام ارسال!', // نمایش پیام خطای خاص پلاگین
        );
      }
    } catch (e) {
      throw Exception('خطا در ارسال درخواست: $e');
    }
  }

  // متد بررسی وجود کاربر
  static Future<bool> checkUserExists(String username) async {
    try {
      print('Checking if user exists: $username');
      print('API URL: $baseUrl');

      // ابتدا با یک رمز عبور موقت تلاش می‌کنیم تا ببینیم کاربر وجود دارد یا نه
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'login',
          'username': username,
          'password': 'temp_check_password_123',
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw "خطای HTTP: ${response.statusCode} - ${response.reasonPhrase}";
      }

      if (response.body.isEmpty) {
        throw "پاسخ سرور خالی است";
      }

      final data = jsonDecode(response.body);
      print('Parsed response data: $data');

      // اگر سرور پیام "نام کاربری یا رمز عبور اشتباه است" بدهد، یعنی کاربر وجود دارد
      // اگر پیام "کاربری یافت نشد" بدهد، یعنی کاربر وجود ندارد
      if (data['success'] == false) {
        final message = data['message'] ?? data['error'] ?? '';
        if (message.contains('نام کاربری یا رمز عبور اشتباه') ||
            message.contains('unauthorized') ||
            message.contains('401')) {
          print('User exists but password is wrong');
          return true; // کاربر وجود دارد
        } else if (message.contains('کاربری یافت نشد') ||
            message.contains('user not found')) {
          print('User does not exist');
          return false; // کاربر وجود ندارد
        }
      }

      // اگر موفقیت‌آمیز باشد، یعنی کاربر و رمز عبور درست است
      if (data['success'] == true) {
        print('User exists and password is correct');
        return true;
      }

      // به طور پیش‌فرض فرض می‌کنیم کاربر وجود دارد
      print('Assuming user exists by default');
      return true;
    } catch (e) {
      print('Exception during checkUserExists: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw "خطا در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.";
      } else if (e.toString().contains('TimeoutException')) {
        throw "زمان اتصال به پایان رسید. لطفاً دوباره تلاش کنید.";
      } else {
        throw e.toString();
      }
    }
  }

  // متد تغییر رمز عبور
  static Future<void> changePassword(
    String username,
    String newPassword,
  ) async {
    try {
      print('Changing password for user: $username');
      print('API URL: $baseUrl');

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'change_password',
          'username': username,
          'new_password': newPassword,
        }),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw "خطای HTTP: ${response.statusCode} - ${response.reasonPhrase}";
      }

      if (response.body.isEmpty) {
        throw "پاسخ سرور خالی است";
      }

      final data = jsonDecode(response.body);
      print('Parsed response data: $data');

      if (data['success'] != true) {
        throw data['message'] ?? 'خطا در تغییر رمز عبور';
      }
    } catch (e) {
      print('Exception during changePassword: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw "خطا در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.";
      } else if (e.toString().contains('TimeoutException')) {
        throw "زمان اتصال به پایان رسید. لطفاً دوباره تلاش کنید.";
      } else {
        throw e.toString();
      }
    }
  }

  // متد درخواست تغییر رمز عبور
  static Future<void> requestPasswordReset(String username) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'request_password_reset',
          'username': username,
        }),
      );

      if (response.statusCode != 200) {
        throw "خطای HTTP: ${response.statusCode} - ${response.reasonPhrase}";
      }

      if (response.body.isEmpty) {
        throw "پاسخ سرور خالی است";
      }

      final data = jsonDecode(response.body);

      if (data['success'] != true) {
        throw data['message'] ?? 'خطا در ارسال درخواست تغییر رمز عبور';
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw "خطا در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.";
      } else if (e.toString().contains('TimeoutException')) {
        throw "زمان اتصال به پایان رسید. لطفاً دوباره تلاش کنید.";
      } else {
        throw e.toString();
      }
    }
  }

  // متد دریافت پست‌های کاربر
  static Future<Map<String, dynamic>> getUserPosts({
    required String token,
    required int userId,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl?action=get_user_posts&user_id=$userId&limit=$limit&offset=$offset',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw "خطای HTTP: ${response.statusCode} - ${response.reasonPhrase}";
      }

      if (response.body.isEmpty) {
        throw "پاسخ سرور خالی است";
      }

      final data = jsonDecode(response.body);

      if (data['success'] != true) {
        throw data['message'] ?? 'خطا در دریافت پست‌های کاربر';
      }

      return data;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw "خطا در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.";
      } else if (e.toString().contains('TimeoutException')) {
        throw "زمان اتصال به پایان رسید. لطفاً دوباره تلاش کنید.";
      } else {
        throw e.toString();
      }
    }
  }

  // متد دریافت پست‌های امروز (برای ادمین)
  static Future<Map<String, dynamic>> getTodayPosts({
    required String adminToken,
    int limit = 10,
    int offset = 0,
  }) async {
    print('🌐 getTodayPosts called with token: ${adminToken.isNotEmpty ? "Present" : "Missing"}');
    print('🌐 URL: $baseUrl?action=get_today_posts&limit=$limit&offset=$offset');
    
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl?action=get_today_posts&limit=$limit&offset=$offset',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $adminToken',
        },
      );

      print('📡 HTTP Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode != 200) {
        print('❌ HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        throw "خطای HTTP: ${response.statusCode} - ${response.reasonPhrase}";
      }

      if (response.body.isEmpty) {
        print('❌ Empty response body');
        throw "پاسخ سرور خالی است";
      }

      final data = jsonDecode(response.body);
      print('📊 Parsed data: $data');

      if (data['success'] != true) {
        print('❌ API Error: ${data['message']}');
        throw data['message'] ?? 'خطا در دریافت پست‌های امروز';
      }

      print('✅ API call successful');
      return data;
    } catch (e) {
      print('❌ Exception in getTodayPosts: $e');
      print('❌ Exception type: ${e.runtimeType}');
      
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw "خطا در اتصال به سرور. لطفاً اتصال اینترنت خود را بررسی کنید.";
      } else if (e.toString().contains('TimeoutException')) {
        throw "زمان اتصال به پایان رسید. لطفاً دوباره تلاش کنید.";
      } else {
        throw e.toString();
      }
    }
  }
}
