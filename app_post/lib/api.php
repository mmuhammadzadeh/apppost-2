<?php
// تولید خروجی فقط JSON: خطاها در لاگ ذخیره شوند، نه در خروجی
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
ini_set('log_errors', 1);
// مسیر لاگ (قابل تغییر)
ini_set('error_log', __DIR__ . '/php_errors.log');
error_reporting(E_ALL);

// فعال‌سازی بافر خروجی تا از نشت HTML به خروجی جلوگیری شود
if (!ob_get_level()) {
  ob_start();
}

// اگر خروجی نهایی HTML بود، آن را به JSON خطا تبدیل کن
register_shutdown_function(function () {
  $out = ob_get_contents();
  if ($out === false) return;
  $trim = trim($out);
  if ($trim === '') return;
  // اگر خروجی با '<' شروع شد یعنی HTML است
  if (strlen($trim) > 0 && $trim[0] === '<') {
    @ob_clean();
    header('Content-Type: application/json; charset=utf-8');
    header('X-Content-Type-Options: nosniff');
    http_response_code(500);
    echo json_encode([
      'success' => false,
      'message' => 'Server returned HTML instead of JSON. Check server logs.',
    ]);
  }
});
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Max-Age: 86400');

// تنظیم timezone
date_default_timezone_set('UTC');

// اطلاعات دیتابیس
$host = 'localhost';
$dbname = 'gtalkir_appp';
$db_username = 'gtalkir_appp';
$db_password = '235689omidARYAN@#741';

define('JWT_SECRET_KEY', 'b0pW2yD8zK3xV6tL4jG1cR9sF7hA5eN0qU4mC7vB9dE2fX8gI1oP3zY5lJ6kM9nT8sQ7w');
// بازه زمانی آنلاین بودن بر اساس آخرین فعالیت (دقیقه)
define('ONLINE_WINDOW_MINUTES', 10);

// Debug: چاپ تاریخ سرور
error_log("Server current time: " . time() . " (" . date('Y-m-d H:i:s') . ")");
error_log("Server timezone: " . date_default_timezone_get());

// توابع JWT
function generateJwt($userId, $username, $role) {
  $currentTime = time();
  $expirationTime = $currentTime + (24 * 60 * 60); // 24 ساعت بعد
  
  $header = json_encode(['typ' => 'JWT', 'alg' => 'HS256']);
  $payload = json_encode([
      'user_id' => $userId,
      'username' => $username,
      'role' => $role,
      'iat' => $currentTime,
      'exp' => $expirationTime
  ]);
  
  // Debug: چاپ تاریخ‌ها
  error_log("JWT Generation - Current time: " . $currentTime . " (" . date('Y-m-d H:i:s', $currentTime) . ")");
  error_log("JWT Generation - Expiration time: " . $expirationTime . " (" . date('Y-m-d H:i:s', $expirationTime) . ")");
  
  $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
  $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));
  $signature = hash_hmac('sha256', $base64UrlHeader . "." . $base64UrlPayload, JWT_SECRET_KEY, true);
  $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));
  return $base64UrlHeader . "." . $base64UrlPayload . "." . $base64UrlSignature;
}

function validateJwt($jwt) {
  @list($header, $payload, $signature) = explode('.', $jwt);
  if (count(explode('.', $jwt)) !== 3) {
      error_log("JWT validation failed: Invalid format");
      return false;
  }
  
  $decodedHeader = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $header)), true);
  $decodedPayload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $payload)), true);
  
  if (!$decodedHeader || !$decodedPayload) {
      error_log("JWT validation failed: Invalid header or payload");
      return false;
  }
  
  $expectedSignature = hash_hmac('sha256', $header . "." . $payload, JWT_SECRET_KEY, true);
  $base64UrlExpectedSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($expectedSignature));
  
  if (!hash_equals($signature, $base64UrlExpectedSignature)) {
      error_log("JWT validation failed: Invalid signature");
      return false;
  }
  
  $currentTime = time();
  error_log("JWT Validation - Current time: " . $currentTime . " (" . date('Y-m-d H:i:s', $currentTime) . ")");
  error_log("JWT Validation - Token issued at: " . $decodedPayload['iat'] . " (" . date('Y-m-d H:i:s', $decodedPayload['iat']) . ")");
  error_log("JWT Validation - Token expires at: " . $decodedPayload['exp'] . " (" . date('Y-m-d H:i:s', $decodedPayload['exp']) . ")");
  
  if (isset($decodedPayload['exp']) && $decodedPayload['exp'] < $currentTime) {
      error_log("JWT validation failed: Token expired");
      return false;
  }
  
  // بررسی اینکه تاریخ صدور نباید در آینده باشد (با 60 ثانیه تلورانس)
  if (isset($decodedPayload['iat']) && $decodedPayload['iat'] > $currentTime + 60) {
      error_log("JWT validation failed: Token issued in future");
      return false;
  }
  
  error_log("JWT validation successful");
  return $decodedPayload;
}

function getAuthPayload() {
   $authHeader = null;
   
   // روش اول: استفاده از getallheaders
   if (function_exists('getallheaders')) {
       $headers = getallheaders();
       $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
   }
   
   // روش دوم: استفاده از $_SERVER
   if (empty($authHeader)) {
       $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
   }
   
   // روش سوم: بررسی REDIRECT_HTTP_AUTHORIZATION
   if (empty($authHeader)) {
       $authHeader = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
   }
   
   // روش چهارم: استفاده از apache_request_headers
   if (empty($authHeader) && function_exists('apache_request_headers')) {
       $headers = apache_request_headers();
       if (isset($headers['Authorization'])) {
           $authHeader = $headers['Authorization'];
       } elseif (isset($headers['authorization'])) {
           $authHeader = $headers['authorization'];
       }
   }
   
   // Debug: برای بررسی مقدار header
   error_log("getAuthPayload - Auth Header: " . $authHeader);
   error_log("getAuthPayload - POST token: " . ($_POST['token'] ?? 'NOT SET'));
   error_log("getAuthPayload - JSON input token: " . ($GLOBALS['input']['token'] ?? 'NOT SET'));
   
   // اگر هدر نبود، توکن را از پارامتر token (GET/POST JSON) هم قبول کن
   if (!$authHeader) {
       $fallbackToken = null;
       if (!empty($_GET['token'])) {
           $fallbackToken = trim($_GET['token']);
           error_log("getAuthPayload - Using GET token: " . $fallbackToken);
       } else if (!empty($_POST['token'])) {
           $fallbackToken = trim($_POST['token']);
           error_log("getAuthPayload - Using POST token: " . $fallbackToken);
       } else if (isset($GLOBALS['input']) && !empty($GLOBALS['input']['token'])) {
           $fallbackToken = trim($GLOBALS['input']['token']);
           error_log("getAuthPayload - Using JSON input token: " . $fallbackToken);
       }
       if ($fallbackToken) {
           $payload = validateJwt($fallbackToken);
           error_log("getAuthPayload - Fallback token validation result: " . json_encode($payload));
           if ($payload) return $payload;
       }
       error_log("getAuthPayload - No Authorization header found and no token param");
       return false;
   }
   
   if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
       $token = $matches[1];
       error_log("Token extracted: " . $token);
       
       $payload = validateJwt($token);
       error_log("Token validation result: " . json_encode($payload));
       
       return $payload;
   }
   
   error_log("No valid Bearer token found in: " . $authHeader);
   return false;
}

// اتصال به دیتابیس
try {
  $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $db_username, $db_password);
  $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
  error_log("Database connection failed: " . $e->getMessage());
  echo json_encode(['success' => false, 'message' => 'خطا در اتصال به سرور.']);
  exit();
}

// هندل preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
  http_response_code(200);
  exit();
}

// Debug: نمایش تمام headers و متغیرهای سرور
error_log("REQUEST_METHOD: " . $_SERVER['REQUEST_METHOD']);
error_log("All SERVER vars related to auth: " . json_encode([
   'HTTP_AUTHORIZATION' => $_SERVER['HTTP_AUTHORIZATION'] ?? 'NOT SET',
   'REDIRECT_HTTP_AUTHORIZATION' => $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? 'NOT SET'
]));

if (function_exists('getallheaders')) {
   error_log("All headers: " . json_encode(getallheaders()));
}

// خواندن ورودی JSON
$inputRaw = file_get_contents('php://input');
$input = json_decode($inputRaw, true);
if ($input === null && json_last_error() !== JSON_ERROR_NONE) {
  $input = [];
}
$GLOBALS['input'] = $input;

$action = $_GET['action'] ?? ($_POST['action'] ?? ($input['action'] ?? ''));
error_log("Action: " . $action);

switch ($action) {
  case 'login':
      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          echo json_encode(['success' => false, 'message' => 'Only POST method allowed']);
          exit();
      }

      $username = trim($input['username'] ?? '');
      $password = trim($input['password'] ?? '');

      if ($username === '' || $password === '') {
          echo json_encode(['success' => false, 'message' => 'نام کاربری و رمز عبور الزامی است.']);
          exit();
      }

      $stmt = $pdo->prepare("SELECT * FROM users WHERE username = ? AND is_active = 1 LIMIT 1");
      $stmt->execute([$username]);
      $user = $stmt->fetch(PDO::FETCH_ASSOC);

      if (!$user || !password_verify($password, $user['password'])) {
          echo json_encode(['success' => false, 'message' => 'نام کاربری یا رمز عبور اشتباه است.']);
          exit();
      }

      // Update user's last activity to now (mark as online)
      try {
          $update = $pdo->prepare("UPDATE users SET last_active = NOW() WHERE id = ?");
          $update->execute([$user['id']]);
      } catch (Exception $e) {
          error_log('Failed to update last_active on login: ' . $e->getMessage());
      }

      // Re-fetch user data to ensure the response has the latest `last_active` value
      $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
      $stmt->execute([$user['id']]);
      $user = $stmt->fetch(PDO::FETCH_ASSOC);

      $token = generateJwt($user['id'], $user['username'], $user['role']);
      error_log("Generated token for user " . $user['username'] . ": " . $token);

      echo json_encode([
          'success' => true,
          'user' => [
              'id' => $user['id'],
              'username' => $user['username'],
              'email' => $user['email'],
              'full_name' => $user['full_name'],
              'role' => $user['role'],
              'is_active' => $user['is_active'],
              'last_active' => $user['last_active'] ?? null,
              // Online if last_active within window
              'is_online' => isset($user['last_active']) ? (time() - strtotime($user['last_active']) < ONLINE_WINDOW_MINUTES * 60) : false,
          ],
          'token' => $token
      ]);
      break;

  case 'get_users':
      if (!in_array($_SERVER['REQUEST_METHOD'], ['GET','POST'])) {
          echo json_encode(['success' => false, 'message' => 'Only GET/POST method allowed']);
          exit();
      }
      // احراز هویت: ابتدا سعی در گرفتن توکن از GET/POST سپس fallback به هدر
      $tokenParam = $_GET['token'] ?? ($input['token'] ?? '');
      if (!empty($tokenParam)) {
          $payload = validateJwt($tokenParam);
      } else {
          $payload = getAuthPayload();
      }
      error_log("get_users - payload: " . json_encode($payload));

      if (!$payload) {
          error_log("get_users - Authentication failed: No valid payload");
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده - توکن یافت نشد']);
          exit();
      }

      if ($payload['role'] !== 'admin') {
          error_log("get_users - Authorization failed: User role is " . $payload['role'] . " but admin required");
          echo json_encode(['success' => false, 'message' => 'دسترسی غیرمجاز - فقط ادمین اجازه دارد']);
          exit();
      }

      error_log("get_users - User authorized successfully");

      $page = intval($_GET['page'] ?? ($input['page'] ?? 1));
      $limit = intval($_GET['limit'] ?? ($input['limit'] ?? 20));
      $offset = ($page - 1) * $limit;

      // اطمینان از اینکه limit و offset عدد صحیح هستند
      $limit = (int)$limit;
      $offset = (int)$offset;

      // اعداد صفحه‌بندی را امن و داخل کوئری قرار می‌دهیم تا مشکل placeholder در LIMIT/OFFSET پیش نیاید
      $limit = max(1, min(200, (int)$limit));
      $offset = max(0, (int)$offset);
      $window = (int)ONLINE_WINDOW_MINUTES;

      // بررسی وجود ستون‌ها برای سازگاری با اسکیمای متفاوت
      $hasCreatedAt = false;
      $hasLastActive = false;
      
      // ابتدا بررسی کنیم که آیا جدول users وجود دارد
      try {
          $tableExists = $pdo->query("SELECT 1 FROM users LIMIT 1");
          if ($tableExists) {
              try {
                  $cols = $pdo->query("SHOW COLUMNS FROM users");
                  foreach ($cols as $c) {
                      $f = strtolower($c['Field'] ?? '');
                      if ($f === 'created_at') $hasCreatedAt = true;
                      if ($f === 'last_active') $hasLastActive = true;
                  }
              } catch (Exception $e) {
                  error_log("Failed to check columns: " . $e->getMessage());
                  // پیش‌فرض: ستون‌ها وجود ندارند
              }
          }
      } catch (Exception $e) {
          error_log("Table users does not exist or not accessible: " . $e->getMessage());
          echo json_encode(['success' => false, 'message' => 'جدول کاربران یافت نشد']);
          exit();
      }

      $select = "id, username, email, full_name, role, is_active";
      $select .= $hasCreatedAt ? ", created_at" : ", NULL AS created_at";
      if ($hasLastActive) {
          $select .= ", last_active, IF(last_active IS NOT NULL AND TIMESTAMPDIFF(MINUTE, last_active, NOW()) < " . ONLINE_WINDOW_MINUTES . ", 1, 0) AS is_online";
      } else {
          $select .= ", NULL AS last_active, 0 AS is_online";
      }

      $order = $hasLastActive
        ? "ORDER BY is_online DESC, COALESCE(last_active, '1970-01-01 00:00:00') DESC"
        : "ORDER BY id DESC";

      try {
          // استفاده از کوئری کامل با محاسبه وضعیت آنلاین بودن
          $sql = "SELECT 
                      id, 
                      username, 
                      email, 
                      full_name, 
                      role, 
                      is_active,
                      last_active,
                      CASE 
                          WHEN last_active IS NOT NULL 
                          AND TIMESTAMPDIFF(MINUTE, last_active, NOW()) < $window 
                          THEN 1 
                          ELSE 0 
                      END AS is_online
                  FROM users 
                  ORDER BY 
                      CASE 
                          WHEN last_active IS NOT NULL 
                          AND TIMESTAMPDIFF(MINUTE, last_active, NOW()) < $window 
                          THEN 1 
                          ELSE 0 
                      END DESC,
                      COALESCE(last_active, '1970-01-01 00:00:00') DESC
                  LIMIT $limit OFFSET $offset";
          $stmt = $pdo->query($sql);
          $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
      } catch (Exception $e) {
          error_log('get_users query failed: ' . $e->getMessage());
          echo json_encode(['success' => false, 'message' => 'خطا در اجرای کوئری کاربران: ' . $e->getMessage()]);
          exit();
      }

      try {
          $countStmt = $pdo->query("SELECT COUNT(*) as total FROM users");
          $total = $countStmt->fetch()['total'];
      } catch (Exception $e) {
          error_log("Failed to count users: " . $e->getMessage());
          $total = 0;
      }

      error_log("get_users - Returning " . count($users) . " users");

      echo json_encode([
          'success' => true,
          'users' => $users,
          'total' => $total,
          'page' => $page,
          'limit' => $limit
      ]);
      break;

  case 'get_online_users':
      if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
          echo json_encode(['success' => false, 'message' => 'Only GET method allowed']);
          exit();
      }

      $sql = "SELECT
                id,
                username,
                email,
                full_name,
                role,
                is_active,
                created_at,
                last_active
              FROM users
              WHERE last_active IS NOT NULL
                AND TIMESTAMPDIFF(MINUTE, last_active, NOW()) < ?
              ORDER BY COALESCE(last_active, '1970-01-01 00:00:00') DESC";
      $stmt = $pdo->prepare($sql);
      $stmt->execute([ONLINE_WINDOW_MINUTES]);
      $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
      echo json_encode(['success' => true, 'users' => $users]);
      break;

  case 'get_user_status':
      if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
          echo json_encode(['success' => false, 'message' => 'Only GET method allowed']);
          exit();
      }
      $userId = intval($_GET['user_id'] ?? 0);
      if (!$userId) {
          echo json_encode(['success' => false, 'message' => 'user_id الزامی است']);
          exit();
      }
      $stmt = $pdo->prepare("SELECT last_active FROM users WHERE id = ? LIMIT 1");
      $stmt->execute([$userId]);
      $row = $stmt->fetch(PDO::FETCH_ASSOC);
      if (!$row) {
          echo json_encode(['success' => false, 'message' => 'کاربر یافت نشد']);
          exit();
      }
      $lastActive = $row['last_active'] ?? null;
      $isOnline = false;
      if ($lastActive) {
          $isOnline = (time() - strtotime($lastActive)) < ONLINE_WINDOW_MINUTES * 60;
      }
      echo json_encode([
          'success' => true,
          'user_id' => $userId,
          'last_active' => $lastActive,
          'is_online' => $isOnline,
          'window_minutes' => ONLINE_WINDOW_MINUTES,
      ]);
      break;

  case 'update_activity':
  case 'heartbeat':
      // Update the authenticated user's last_active timestamp
      if (!in_array($_SERVER['REQUEST_METHOD'], ['POST', 'GET'])) {
          echo json_encode(['success' => false, 'message' => 'Method not allowed']);
          exit();
      }

      error_log("heartbeat called - method: " . $_SERVER['REQUEST_METHOD']);
      error_log("heartbeat - input: " . json_encode($input));
      error_log("heartbeat - POST: " . json_encode($_POST));
      error_log("heartbeat - GET: " . json_encode($_GET));

      $payload = getAuthPayload();
      error_log("heartbeat - payload: " . json_encode($payload));

      if (!$payload || empty($payload['user_id'])) {
          error_log("heartbeat - Authentication failed");
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده']);
          exit();
      }

      try {
          $stmt = $pdo->prepare("UPDATE users SET last_active = NOW() WHERE id = ?");
          $stmt->execute([(int)$payload['user_id']]);

          $now = date('Y-m-d H:i:s');
          echo json_encode([
              'success' => true,
              'last_active' => $now,
              'is_online' => true,
          ]);
      } catch (Exception $e) {
          error_log('update_activity failed: ' . $e->getMessage());
          echo json_encode(['success' => false, 'message' => 'خطا در بروزرسانی وضعیت کاربر']);
      }
      break;

  case 'create_user':
      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          echo json_encode(['success' => false, 'message' => 'Only POST method allowed']);
          exit();
      }

      $payload = getAuthPayload();
      if (!$payload) {
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده']);
          exit();
      }

      if ($payload['role'] !== 'admin') {
          echo json_encode(['success' => false, 'message' => 'دسترسی غیرمجاز']);
          exit();
      }

      $username = trim($input['username'] ?? '');
      $email = trim($input['email'] ?? '');
      $full_name = trim($input['full_name'] ?? '');
      $role = trim($input['role'] ?? 'user');
      $password = trim($input['password'] ?? '');

      if ($username === '' || $password === '') {
          echo json_encode(['success' => false, 'message' => 'نام کاربری و رمز عبور الزامی است.']);
          exit();
      }

      // Use a try-catch block for the entire operation to handle any database errors.
      try {
        // Check if username or email already exists
        $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ? OR email = ?");
        $stmt->execute([$username, $email]);
        if ($stmt->fetch()) {
            echo json_encode(['success' => false, 'message' => 'این نام کاربری یا ایمیل قبلاً ثبت شده است.']);
            exit();
        }

        // Hash the password
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);
        if ($passwordHash === false) {
            error_log("create_user: password_hash() failed for user $username.");
            echo json_encode(['success' => false, 'message' => 'خطای سیستمی در پردازش رمز عبور.']);
            exit();
        }

        // Correct INSERT statement with 5 placeholders for 5 values
        $stmt = $pdo->prepare("INSERT INTO users (username, email, password, full_name, role, is_active, created_at) VALUES (?, ?, ?, ?, ?, 1, NOW())");

        if ($stmt->execute([$username, $email, $passwordHash, $full_name, $role])) {
            echo json_encode(['success' => true, 'message' => 'کاربر جدید با موفقیت ایجاد شد.']);
        } else {
            // This part is less likely to be reached if PDO is in exception mode
            error_log("create_user: stmt->execute() returned false for user $username.");
            echo json_encode(['success' => false, 'message' => 'خطا در ساخت کاربر.']);
        }
      } catch (PDOException $e) {
          error_log("create_user: A database error occurred for user $username: " . $e->getMessage());
          echo json_encode(['success' => false, 'message' => 'خطای دسترسی به دیتابیس هنگام ساخت کاربر.']);
      }
      break;

  case 'create_post':
      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          echo json_encode(['success' => false, 'message' => 'Only POST method allowed']);
          exit();
      }

      $payload = getAuthPayload();
      if (!$payload) {
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده']);
          exit();
      }

      $title = trim($input['title'] ?? '');
      $content = trim($input['content'] ?? '');
      $category = trim($input['category'] ?? 'general');

      if ($title === '' || $content === '') {
          echo json_encode(['success' => false, 'message' => 'عنوان و محتوا الزامی است.']);
          exit();
      }

      $stmt = $pdo->prepare("INSERT INTO posts (title, content, category, author_id, created_at, updated_at) VALUES (?, ?, ?, ?, NOW(), NOW())");

      if ($stmt->execute([$title, $content, $category, $payload['user_id']])) {
          echo json_encode(['success' => true, 'message' => 'پست با موفقیت ایجاد شد.', 'post_id' => $pdo->lastInsertId()]);
      } else {
          echo json_encode(['success' => false, 'message' => 'خطا در ایجاد پست.']);
      }
      break;

  case 'get_posts':
      if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
          echo json_encode(['success' => false, 'message' => 'Only GET method allowed']);
          exit();
      }

      $page = intval($_GET['page'] ?? 1);
      $limit = intval($_GET['limit'] ?? 10);
      $offset = ($page - 1) * $limit;
      $category = $_GET['category'] ?? '';

      // اطمینان از اینکه limit و offset عدد صحیح هستند
      $limit = (int)$limit;
      $offset = (int)$offset;

      if ($category) {
          $sql = sprintf(
              "SELECT p.*, u.username as author_name, u.full_name as author_full_name
               FROM posts p
               JOIN users u ON p.author_id = u.id
               WHERE p.category = '%s'
               ORDER BY p.created_at DESC
               LIMIT %d OFFSET %d",
              $pdo->quote($category),
              $limit,
              $offset
          );
      } else {
          $sql = sprintf(
              "SELECT p.*, u.username as author_name, u.full_name as author_full_name
               FROM posts p
               JOIN users u ON p.author_id = u.id
               ORDER BY p.created_at DESC
               LIMIT %d OFFSET %d",
              $limit,
              $offset
          );
      }

      $stmt = $pdo->prepare($sql);
      $stmt->execute();
      $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);

      echo json_encode([
          'success' => true,
          'posts' => $posts
      ]);
      break;

  case 'logout':
      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          echo json_encode(['success' => false, 'message' => 'Only POST method allowed']);
          exit();
      }

      $payload = getAuthPayload();
      if (!$payload || empty($payload['user_id'])) {
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده']);
          exit();
      }

      try {
          // با خروج، کاربر را عملاً آفلاین در نظر می‌گیریم
          // با پاک‌کردن last_active (یا گذاشتن زمان خیلی قدیمی)
          $stmt = $pdo->prepare("UPDATE users SET last_active = NULL WHERE id = ?");
          $stmt->execute([(int)$payload['user_id']]);
          echo json_encode(['success' => true]);
      } catch (Exception $e) {
          error_log('logout failed: ' . $e->getMessage());
          echo json_encode(['success' => false, 'message' => 'خطا در خروج کاربر']);
      }
      break;

  case 'update_user':
      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          echo json_encode(['success' => false, 'message' => 'Only POST method allowed']);
          exit();
      }

      $payload = getAuthPayload();
      if (!$payload) {
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده']);
          exit();
      }

      if ($payload['role'] !== 'admin') {
          echo json_encode(['success' => false, 'message' => 'دسترسی غیرمجاز - فقط ادمین اجازه دارد']);
          exit();
      }

      $user_id = intval($input['user_id'] ?? 0);
      $username = trim($input['username'] ?? '');
      $email = trim($input['email'] ?? '');
      $full_name = trim($input['full_name'] ?? '');
      $role = trim($input['role'] ?? 'user');
      $is_active = intval($input['is_active'] ?? 1);

      if (!$user_id || $username === '') {
          echo json_encode(['success' => false, 'message' => 'شناسه کاربر و نام کاربری الزامی است.']);
          exit();
      }

      try {
          // Check if username already exists for other users
          $stmt = $pdo->prepare("SELECT id FROM users WHERE username = ? AND id != ?");
          $stmt->execute([$username, $user_id]);
          if ($stmt->fetch()) {
              echo json_encode(['success' => false, 'message' => 'این نام کاربری قبلاً توسط کاربر دیگری استفاده شده است.']);
              exit();
          }

          // Check if email already exists for other users
          if (!empty($email)) {
              $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ? AND id != ?");
              $stmt->execute([$email, $user_id]);
              if ($stmt->fetch()) {
                  echo json_encode(['success' => false, 'message' => 'این ایمیل قبلاً توسط کاربر دیگری استفاده شده است.']);
                  exit();
              }
          }

          // Update user
          $stmt = $pdo->prepare("UPDATE users SET username = ?, email = ?, full_name = ?, role = ?, is_active = ? WHERE id = ?");
          
          if ($stmt->execute([$username, $email, $full_name, $role, $is_active, $user_id])) {
              echo json_encode(['success' => true, 'message' => 'کاربر با موفقیت به‌روزرسانی شد.']);
          } else {
              echo json_encode(['success' => false, 'message' => 'خطا در به‌روزرسانی کاربر.']);
          }
      } catch (PDOException $e) {
          error_log("update_user: Database error: " . $e->getMessage());
          echo json_encode(['success' => false, 'message' => 'خطای دسترسی به دیتابیس هنگام به‌روزرسانی کاربر.']);
      }
      break;

  case 'delete_user':
      if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
          echo json_encode(['success' => false, 'message' => 'Only POST method allowed']);
          exit();
      }

      $payload = getAuthPayload();
      if (!$payload) {
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده']);
          exit();
      }

      if ($payload['role'] !== 'admin') {
          echo json_encode(['success' => false, 'message' => 'دسترسی غیرمجاز - فقط ادمین اجازه دارد']);
          exit();
      }

      $user_id = intval($input['user_id'] ?? 0);
      
      if (!$user_id) {
          echo json_encode(['success' => false, 'message' => 'شناسه کاربر الزامی است.']);
          exit();
      }

      // Prevent admin from deleting themselves
      if ($user_id == $payload['user_id']) {
          echo json_encode(['success' => false, 'message' => 'شما نمی‌توانید حساب کاربری خود را حذف کنید.']);
          exit();
      }

      try {
          // Check if user exists
          $stmt = $pdo->prepare("SELECT username FROM users WHERE id = ?");
          $stmt->execute([$user_id]);
          $user = $stmt->fetch();
          
          if (!$user) {
              echo json_encode(['success' => false, 'message' => 'کاربر یافت نشد.']);
              exit();
          }

          // Delete user
          $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
          
          if ($stmt->execute([$user_id])) {
              echo json_encode(['success' => true, 'message' => 'کاربر با موفقیت حذف شد.']);
          } else {
              echo json_encode(['success' => false, 'message' => 'خطا در حذف کاربر.']);
          }
      } catch (PDOException $e) {
          error_log("delete_user: Database error: " . $e->getMessage());
          echo json_encode(['success' => false, 'message' => 'خطای دسترسی به دیتابیس هنگام حذف کاربر.']);
      }
      break;

  case 'update_post':
      if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
          echo json_encode(['success' => false, 'message' => 'Only PUT method allowed']);
          exit();
      }

      $payload = getAuthPayload();
      if (!$payload) {
          echo json_encode(['success' => false, 'message' => 'احراز هویت نشده']);
          exit();
      }

      $post_id = intval($input['post_id'] ?? 0);
      $title = trim($input['title'] ?? '');
      $content = trim($input['content'] ?? '');
      $category = trim($input['category'] ?? 'general');

      if (!$post_id || $title === '' || $content === '') {
          echo json_encode(['success' => false, 'message' => 'پارامترهای الزامی وارد نشده.']);
          exit();
      }

      // بررسی مالکیت پست
      $stmt = $pdo->prepare("SELECT author_id FROM posts WHERE id = ?");
      $stmt->execute([$post_id]);
      $post = $stmt->fetch();

      if (!$post || ($post['author_id'] != $payload['user_id'] && $payload['role'] !== 'admin')) {
          echo json_encode(['success' => false, 'message' => 'شما مجاز به ویرایش این پست نیستید.']);
          exit();
      }

      $stmt = $pdo->prepare("UPDATE posts SET title = ?, content = ?, category = ?, updated_at = NOW() WHERE id = ?");

      if ($stmt->execute([$title, $content, $category, $post_id])) {
          echo json_encode(['success' => true, 'message' => 'پست با موفقیت به‌روزرسانی شد.']);
      } else {
          echo json_encode(['success' => false, 'message' => 'خطا در به‌روزرسانی پست.']);
      }
      break;

  default:
      echo json_encode(['success' => false, 'message' => 'اکشن یافت نشد.']);
      break;
}
?>