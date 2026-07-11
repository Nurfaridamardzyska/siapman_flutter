import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final nip = _nipController.text.trim();
    final password = _passwordController.text; // Jangan di-trim karena spasi mungkin bagian dari password

    if (nip.isEmpty || password.isEmpty) {
      _showPopup('Data Kosong', 'NIP dan Kata Sandi tidak boleh kosong!', false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.login(nip: nip, password: password);

      final token = result['token'] as String?;
      final user = result['user'] as Map<String, dynamic>?;

      if (token == null || token.isEmpty) {
        throw Exception('Token login tidak ditemukan');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('name', user?['name']?.toString() ?? '');
      await prefs.setString('nip', user?['nip']?.toString() ?? '');
      await prefs.setString('email', user?['email']?.toString() ?? '');
      await prefs.setString('username', user?['username']?.toString() ?? '');
      await prefs.setString('role', user?['role']?.toString() ?? '');
      await prefs.setString(
        'unit_kerja',
        user?['unit_kerja']?.toString() ?? '',
      );
      await prefs.setString('status', user?['status']?.toString() ?? '');
      await prefs.setInt(
        'tpp_allowance',
        (user?['tpp_allowance'] as num?)?.toInt() ?? 0,
      );

      if (!mounted) return;

      _showPopup(
        'Login Berhasil',
        'Selamat datang kembali, ${user?['name'] ?? ''}!',
        true,
        onConfirm: () {
          if (!mounted) return;
          // Transisi instan dan super halus menimpa seluruh layar (termasuk dialog)
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
            (route) => false,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      
      // Rapikan pesan error yang terlalu panjang (misal timeout)
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('SocketException') || errorMsg.contains('Connection timed out')) {
        errorMsg = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda atau pastikan server aktif.';
      }
      
      _showPopup('Login Gagal', errorMsg, false);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPopup(String title, String message, bool isSuccess, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final color = isSuccess ? Colors.teal : Colors.redAccent;
        final icon = isSuccess ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Eksekusi seketika tanpa jeda
                    if (onConfirm != null) onConfirm();
                    else Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('MENGERTI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nipController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (Dynamic)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0), const Color(0xFFF8FAFC)],
              ),
            ),
          ),
          // Animated Decorative Circles for depth
          Positioned(
            top: -100,
            right: -50,
            child: _buildDecorativeCircle(
              (isDark ? const Color(0xFF3B82F6) : const Color(0xFF1A365D)).withOpacity(0.1), 
              250
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildDecorativeCircle(
              (isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD)).withOpacity(0.1), 
              200
            ),
          ),
          // Batik Watermark
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.04 : 0.15,
              child: Image.asset(
                'assets/images/batik_pattern.png',
                fit: BoxFit.cover,
                color: isDark ? null : Colors.blueGrey.withOpacity(0.12),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      _buildHeader(isDark),
                      const SizedBox(height: 48),
                      _buildLoginGlassCard(isDark),
                      const SizedBox(height: 32),
                      _buildFooter(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark 
                  ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                  : [const Color(0xFF075985), const Color(0xFF1E3A8A), const Color(0xFF172554)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.5) : const Color(0xFF2563EB).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: const Icon(Icons.fingerprint_rounded, size: 52, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          'SIAPMAN',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 2,
          ),
        ),
        Text(
          'SISTEM ABSENSI PEGAWAI MANDIRI',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withOpacity(0.6) : Colors.black45,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginGlassCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selamat Datang',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Silakan masuk ke akun Anda',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          _buildModernField(
            label: 'NIP PEGAWAI',
            controller: _nipController,
            icon: Icons.badge_outlined,
            hint: 'Masukkan NIP',
            isDark: isDark,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          _buildModernField(
            label: 'KATA SANDI',
            controller: _passwordController,
            icon: Icons.lock_open_rounded,
            hint: '••••••••',
            obscureText: _obscurePassword,
            isPassword: true,
            isDark: isDark,
            keyboardType: TextInputType.visiblePassword,
          ),
          const SizedBox(height: 48),
          _buildLoginButton(isDark),
        ],
      ),
    );
  }

  Widget _buildModernField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isDark,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A), 
            fontSize: 15, 
            fontWeight: FontWeight.w500
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF94A3B8), fontSize: 15),
            prefixIcon: Icon(icon, color: isDark ? Colors.white54 : const Color(0xFF94A3B8), size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF075985), const Color(0xFF1E3A8A), const Color(0xFF172554)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.5) : const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : const Text(
                'MASUK SEKARANG',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Text(
          'SIAPMAN LAMONGAN v1.0.0',
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black26,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: (isDark ? Colors.cyanAccent : const Color(0xFF2563EB)).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}