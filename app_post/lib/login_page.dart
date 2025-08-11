import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'session_manager.dart';
import 'user.dart';
import 'app_theme.dart';

class LoginPage extends StatefulWidget {
  final void Function(User) onLogin;
  const LoginPage({required this.onLogin, super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // ارتعاش هپتیک برای بازخورد کاربر
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      // بازخورد موفقیت‌آمیز
      HapticFeedback.mediumImpact();
      if (user == null) {
        // نمایش پیام خطا یا مدیریت حالت لاگین ناموفق
      } else {
        await SessionManager.saveSession(user);
        widget.onLogin(user);
      }
    } catch (e) {
      // بازخورد خطا
      HapticFeedback.heavyImpact();
      setState(() => _error = _getErrorMessage(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _getErrorMessage(String error) {
    print('Error in _getErrorMessage: $error');

    if (error.contains('network') ||
        error.contains('SocketException') ||
        error.contains('Connection refused')) {
      return 'خطا در اتصال به شبکه. لطفاً اتصال اینترنت خود را بررسی کنید.';
    } else if (error.contains('401') || error.contains('unauthorized')) {
      return 'نام کاربری یا رمز عبور اشتباه است.';
    } else if (error.contains('timeout') ||
        error.contains('TimeoutException')) {
      return 'زمان اتصال به پایان رسید. دوباره تلاش کنید.';
    } else if (error.contains('خطای HTTP:')) {
      return error; // نمایش خطای HTTP دقیق
    } else if (error.contains('پاسخ سرور خالی')) {
      return 'سرور پاسخ خالی ارسال کرده است.';
    } else if (error.contains('خطا در ورود')) {
      return error; // نمایش پیام خطای سرور
    }

    // برای خطاهای دیگر، پیام کامل را نمایش دهید
    return 'خطا: $error';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? size.width * 0.25 : 24.0,
                vertical: 32.0,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 48),
                      _buildLoginCard(theme, isTablet),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppTheme.primaryShadow,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.1),
            ),
            child: Icon(
              Icons.admin_panel_settings,
              size: 60,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'خوش آمدید',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'برای ادامه وارد حساب کاربری خود شوید',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard(ThemeData theme, bool isTablet) {
    return Card(
      elevation: 16,
      shadowColor: AppTheme.primaryGold.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppTheme.surfaceGradient,
        ),
        width: isTablet ? 400 : double.infinity,
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUsernameField(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorMessage(),
            ],
            const SizedBox(height: 32),
            _buildLoginButton(theme),
            const SizedBox(height: 16),
            _buildForgotPasswordLink(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: 'نام کاربری',
        prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryGold),
        filled: true,
        fillColor: AppTheme.secondaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.redAccent),
        ),
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        hintStyle: TextStyle(color: AppTheme.textHint),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'لطفاً نام کاربری را وارد کنید';
        }
        if (value.trim().length < 3) {
          return 'نام کاربری باید حداقل ۳ کاراکتر باشد';
        }
        return null;
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      textDirection: TextDirection.rtl,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'رمز عبور',
        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryGold),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: AppTheme.primaryGold,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        filled: true,
        fillColor: AppTheme.secondaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.redAccent),
        ),
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        hintStyle: TextStyle(color: AppTheme.textHint),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'لطفاً رمز عبور را وارد کنید';
        }
        if (value.length < 6) {
          return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
        }
        return null;
      },
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _login(),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.redAccent.withOpacity(0.3)),
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
    );
  }

  Widget _buildLoginButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Text(
                'ورود',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(ThemeData theme) {
    return TextButton(
      onPressed: () {
        // اینجا می‌تونید صفحه فراموشی رمز عبور رو اضافه کنید
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('این قابلیت به زودی اضافه خواهد شد'),
            backgroundColor: AppTheme.surfaceDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      child: Text(
        'رمز عبور خود را فراموش کرده‌اید؟',
        style: TextStyle(
          color: AppTheme.primaryGold,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
