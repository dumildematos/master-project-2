// login_screen.dart — SENTIO Login Screen
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/auth_provider.dart';
import '../theme/theme.dart' show SentioColors;
import 'main_shell.dart';
import 'package:provider/provider.dart';

// ── Palette (matches design spec exactly) ─────────────────────────────────────
const _kBg     = Color(0xFF02080D);
const _kCyan   = Color(0xFF00D9FF); // spec: #00D9FF
const _kBlue   = Color(0xFF2979FF);
const _kPurple = Color(0xFF782CFF); // spec: #782CFF
const _kDark   = Color(0xFF111A22); // input / social button background
const _kBorder = Color(0x22FFFFFF); // very subtle border

// Gradient used on button, logo, text
const _kGrad = LinearGradient(
  colors: [_kCyan, _kBlue, _kPurple],
  stops: [0.0, 0.42, 1.0],
);

// ══════════════════════════════════════════════════════════════════════════════
// LoginScreen
// ══════════════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('Please enter your email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().login(email: email, password: password);
      if (mounted) _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _register() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('Please enter your email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(email: email, password: password);
      if (mounted) _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      final user = await context.read<AuthProvider>().loginWithGoogle();
      if (!mounted) return;
      if (user == null) { setState(() => _loading = false); return; }
      _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _goHome() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const MainShell()));

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: SentioColors.red,
      duration: const Duration(seconds: 3),
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(children: [
        // Particle wave background (static, no rebuild cost)
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _WavePainter()),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 36),

                // ── Logo ────────────────────────────────────────────────
                Center(
                  child: SizedBox(
                    width: 104, height: 104,
                    child: CustomPaint(painter: _LogoPainter()),
                  ),
                ),
                const SizedBox(height: 14),

                // ── "SENTIO" gradient wordmark ───────────────────────────
                _GradText(
                  'SENTIO',
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 10,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 18),

                // ── "Welcome back!" ──────────────────────────────────────
                Text(
                  'Welcome back!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),

                // ── "Log in to continue" ─────────────────────────────────
                Text(
                  'Log in to continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9AA6B2),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 34),

                // ── Email / Username field ───────────────────────────────
                InputField(
                  controller: _emailCtrl,
                  hint: 'Email or Username',
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                // ── Password field ───────────────────────────────────────
                InputField(
                  controller: _passwordCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: _kCyan.withValues(alpha: 0.65),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    padding: const EdgeInsets.only(right: 8),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Forgot Password ──────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {},
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.poppins(
                          color: _kCyan,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Log In button ────────────────────────────────────────
                GradientButton(
                  label: 'Log In',
                  loading: _loading,
                  onTap: _login,
                ),
                const SizedBox(height: 32),

                // ── "or continue with" divider ───────────────────────────
                const DividerWithText(text: 'or continue with'),
                const SizedBox(height: 24),

                // ── Social buttons ───────────────────────────────────────
                SocialLoginButton(
                  icon: const _GoogleIcon(),
                  label: 'Continue with Google',
                  onTap: _googleLogin,
                ),
                const SizedBox(height: 12),
                SocialLoginButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.apple,
                    color: Colors.white,
                    size: 22,
                  ),
                  label: 'Continue with Apple',
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                SocialLoginButton(
                  icon: const _FacebookIcon(),
                  label: 'Continue with Facebook',
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                SocialLoginButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.twitter,
                    color: Color(0xFF1DA1F2),
                    size: 20,
                  ),
                  label: 'Continue with Twitter',
                  onTap: () {},
                ),
                const SizedBox(height: 40),

                // ── "Don't have an account? Sign Up" ────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _register,
                    behavior: HitTestBehavior.opaque,
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF9AA6B2),
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Sign Up',
                            style: GoogleFonts.poppins(
                              color: _kCyan,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // iOS home indicator
                Center(
                  child: Container(
                    width: 134, height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable widgets (public — can be imported across other screens)
// ══════════════════════════════════════════════════════════════════════════════

// ── Gradient shimmer text (SENTIO wordmark) ────────────────────────────────────
class _GradText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _GradText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (b) =>
        _kGrad.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: style.copyWith(color: Colors.white),
    ),
  );
}

// ── InputField ─────────────────────────────────────────────────────────────────
class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType keyboardType;

  const InputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Row(children: [
        const SizedBox(width: 18),
        Icon(icon, color: const Color(0xFF9AA6B2), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFF9AA6B2),
                fontSize: 15,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (suffix != null) suffix!,
        if (suffix == null) const SizedBox(width: 16),
      ]),
    );
  }
}

// ── GradientButton ─────────────────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const GradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: _kGrad,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _kCyan.withValues(alpha: 0.22),
                blurRadius: 22,
                spreadRadius: -4,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: _kPurple.withValues(alpha: 0.18),
                blurRadius: 30,
                spreadRadius: -6,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── DividerWithText ────────────────────────────────────────────────────────────
class DividerWithText extends StatelessWidget {
  final String text;
  const DividerWithText({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: Divider(
        color: Colors.white.withValues(alpha: 0.12),
        thickness: 1,
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: const Color(0xFF9AA6B2),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    ),
    Expanded(
      child: Divider(
        color: Colors.white.withValues(alpha: 0.12),
        thickness: 1,
      ),
    ),
  ]);
}

// ── SocialLoginButton ──────────────────────────────────────────────────────────
class SocialLoginButton extends StatefulWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const SocialLoginButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<SocialLoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: ()  => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.72 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: _kDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Stack(alignment: Alignment.center, children: [
            // Icon pinned 20 px from left edge
            Positioned(left: 20, child: widget.icon),
            // Label perfectly centred
            Text(
              widget.label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── LogoWidget  ────────────────────────────────────────────────────────────────
class LogoWidget extends StatelessWidget {
  final double size;
  const LogoWidget({super.key, this.size = 104});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: CustomPaint(painter: _LogoPainter()),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom painters
// ══════════════════════════════════════════════════════════════════════════════

// ── Concentric segmented ring logo (cyan → purple sweep gradient + glow) ───────
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c    = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2 * 0.96;

    for (final (frac, sw, glowSW) in [
      (0.28, 3.2, 6.0),
      (0.56, 2.6, 5.0),
      (0.86, 2.2, 4.0),
    ]) {
      final r = maxR * frac;

      // Subtle glow ring
      canvas.drawCircle(c, r, Paint()
        ..color = _kCyan.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowSW
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

      // Arc segments with sweep gradient
      final shader = const SweepGradient(
        startAngle: -pi / 2,
        endAngle:    3 * pi / 2,
        colors: [_kCyan, _kBlue, _kPurple, _kCyan],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));

      const gapRad  = 13.0 * pi / 180;
      const arcSpan = pi / 2 - gapRad;

      for (int i = 0; i < 4; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -pi / 2 + i * pi / 2 + gapRad / 2,
          arcSpan, false,
          Paint()
            ..shader      = shader
            ..style       = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap   = StrokeCap.round,
        );
      }
    }

    // Centre dot with gradient + soft glow
    canvas.drawCircle(c, 4.5, Paint()
      ..shader = const RadialGradient(colors: [_kCyan, _kPurple])
          .createShader(Rect.fromCircle(center: c, radius: 4.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Particle wave background (static, drawn once) ──────────────────────────────
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(31415);
    final w = size.width, h = size.height;

    // Left diagonal wave — cyan (lower-left → upper-center)
    _stream(canvas, rand, w, h,
      x0: 0.02, y0: 0.96, x1: 0.46, y1: 0.08,
      col: _kCyan, count: 160, spread: 0.17);

    // Right diagonal wave — purple (upper-right → lower-right)
    _stream(canvas, rand, w, h,
      x0: 0.54, y0: 0.04, x1: 0.98, y1: 0.90,
      col: _kPurple, count: 130, spread: 0.17);

    // Faint blue mid-scatter for depth
    _stream(canvas, rand, w, h,
      x0: 0.18, y0: 0.28, x1: 0.82, y1: 0.68,
      col: _kBlue, count: 35, spread: 0.28);
  }

  void _stream(
    Canvas canvas, Random rand, double w, double h, {
    required double x0, required double y0,
    required double x1, required double y1,
    required Color col,
    required int count,
    required double spread,
  }) {
    final dx  = x1 - x0;
    final dy  = y1 - y0;
    final len = sqrt(dx * dx + dy * dy) + 1e-9;
    final nx  = -dy / len;
    final ny  =  dx / len;

    for (int i = 0; i < count; i++) {
      final t    = rand.nextDouble();
      final bx   = (x0 + t * dx) * w;
      final by   = (y0 + t * dy) * h;
      final off  = (rand.nextDouble() - 0.5) * spread;
      final px   = bx + nx * off * w;
      final py   = by + ny * off * h;
      final prox = (1.0 - off.abs() / (spread * 0.5)).clamp(0.35, 1.0);
      final dotR = 0.5 + rand.nextDouble() * 2.2 * prox;
      final opa  = (0.10 + rand.nextDouble() * 0.55 * prox).clamp(0.0, 1.0);

      canvas.drawCircle(Offset(px, py), dotR * 2.4, Paint()
        ..color = col.withValues(alpha: opa * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

      canvas.drawCircle(Offset(px, py), dotR,
        Paint()..color = col.withValues(alpha: opa));
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Google multicolor G icon (Canvas, no SVG needed) ──────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 26, height: 26, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    final c  = Offset(size.width / 2, size.height / 2);
    final ro = size.width / 2;
    final ri = ro * 0.50;

    void seg(Color col, double startDeg, double endDeg) {
      final s = startDeg * pi / 180;
      final e = endDeg   * pi / 180;
      final path = Path()
        ..moveTo(c.dx + ro * cos(s), c.dy + ro * sin(s))
        ..arcTo(Rect.fromCircle(center: c, radius: ro), s, e - s, false)
        ..lineTo(c.dx + ri * cos(e), c.dy + ri * sin(e))
        ..arcTo(Rect.fromCircle(center: c, radius: ri), e, s - e, false)
        ..close();
      canvas.drawPath(path, Paint()..color = col);
    }

    seg(const Color(0xFF4285F4), -90,   -4);  // blue
    seg(const Color(0xFFEA4335),   8,   97);  // red
    seg(const Color(0xFFFBBC05),  97,  188);  // yellow
    seg(const Color(0xFF34A853), 188,  270);  // green

    // Erase the inner circle to create the "G" ring
    canvas.drawCircle(c, ri,
        Paint()..blendMode = BlendMode.clear);

    canvas.restore();

    // Blue horizontal arm — drawn after restore so it sits above the ring
    final armH = ri * 0.70;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 0.5, c.dy - armH / 2, ro + 0.5, armH),
        Radius.circular(armH / 2),
      ),
      Paint()..color = const Color(0xFF4285F4),
    );

    // Erase the arm portion inside the inner hole
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(c, ri - 0.5, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Facebook blue circle + white f ─────────────────────────────────────────────
class _FacebookIcon extends StatelessWidget {
  const _FacebookIcon();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 26, height: 26, child: CustomPaint(painter: _FbPainter()));
}

class _FbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c  = Offset(size.width / 2, size.height / 2);
    final r  = size.width / 2;
    final w  = size.width;
    final h  = size.height;
    final wp = Paint()..color = Colors.white;

    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1877F2));

    // f stem
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.52, h * 0.27, w * 0.15, h * 0.58),
        const Radius.circular(3),
      ),
      wp,
    );

    // f arch
    canvas.drawArc(
      Rect.fromLTWH(w * 0.30, h * 0.12, w * 0.38, h * 0.30),
      pi, pi, false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.145
        ..strokeCap = StrokeCap.round,
    );

    // f crossbar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.33, h * 0.46, w * 0.34, h * 0.12),
        const Radius.circular(2),
      ),
      wp,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
