import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../models/ai_models.dart';
import '../providers/ai_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/sentio_provider.dart';

// ── Design tokens (match session_screen palette) ──────────────────────────────
const _kBgTop      = Color(0xFF02080D);
const _kBgBottom   = Color(0xFF07131B);
const _kCardBg     = Color(0xFF101820);
const _kCardBorder = Color(0xFF1E2A33);
const _kAccentCyan = Color(0xFF00D9FF);
const _kAccentGrn  = Color(0xFF00C48C);
const _kAccentYell = Color(0xFFFFC107);
const _kTextPri    = Color(0xFFFFFFFF);
const _kTextSec    = Color(0xFF9AA6B2);

// ── Step definition ───────────────────────────────────────────────────────────
class _Step {
  final String id;           // "neutral" | "focus" | "relax"
  final String title;
  final String instruction;
  final IconData icon;
  final Color color;
  final int durationSeconds;

  const _Step({
    required this.id,
    required this.title,
    required this.instruction,
    required this.icon,
    required this.color,
    required this.durationSeconds,
  });
}

const _kSteps = [
  _Step(
    id:              'neutral',
    title:           'Baseline',
    instruction:     'Sit comfortably. Clear your mind and breathe normally. Look straight ahead.',
    icon:            PhosphorIconsRegular.minus,
    color:           _kAccentCyan,
    durationSeconds: 30,
  ),
  _Step(
    id:              'focus',
    title:           'Focus',
    instruction:     'Concentrate on a single mental task — count backwards from 300 by 3s.',
    icon:            PhosphorIconsRegular.crosshair,
    color:           _kAccentGrn,
    durationSeconds: 30,
  ),
  _Step(
    id:              'relax',
    title:           'Relax',
    instruction:     'Close your eyes. Take slow, deep breaths. Let your thoughts drift away.',
    icon:            PhosphorIconsRegular.flowerLotus,
    color:           _kAccentYell,
    durationSeconds: 30,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  int _secondsLeft = _kSteps[0].durationSeconds;
  bool _running = false;
  bool _done = false;

  // Accumulated band averages per step
  final List<_StepBands> _collected = [];
  // Running sums for current step
  double _sumAlpha = 0, _sumBeta = 0, _sumTheta = 0,
         _sumGamma = 0, _sumDelta = 0;
  int _sampleCount = 0;

  Timer? _timer;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Sampling ──────────────────────────────────────────────────────────────

  void _startStep() {
    final step = _kSteps[_stepIndex];
    setState(() {
      _running     = true;
      _secondsLeft = step.durationSeconds;
      _sumAlpha    = _sumBeta = _sumTheta = _sumGamma = _sumDelta = 0;
      _sampleCount = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Sample current band powers from either Muse BLE or WebSocket
      _sample();

      if (!mounted) return;
      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _finishStep();
      }
    });
  }

  void _sample() {
    final sentio = context.read<SentioProvider>();
    final ble    = context.read<BleProvider>();
    final d      = sentio.data;

    // Prefer WebSocket bands; fall back to BLE band powers
    double a = d.alpha, b = d.beta, t = d.theta, g = d.gamma, dl = d.delta;

    // If WebSocket has no meaningful data yet, try BLE bands
    if (a == 0 && b == 0) {
      final bp = ble.bandPowers;
      if (bp != null) {
        a = bp.alpha; b = bp.beta; t = bp.theta;
        g = bp.gamma; dl = bp.delta;
      }
    }

    _sumAlpha += a; _sumBeta += b; _sumTheta += t;
    _sumGamma += g; _sumDelta += dl;
    _sampleCount++;
  }

  void _finishStep() {
    final step = _kSteps[_stepIndex];
    final n    = _sampleCount > 0 ? _sampleCount : 1;
    _collected.add(_StepBands(
      step:             step.id,
      alpha:            _sumAlpha / n,
      beta:             _sumBeta  / n,
      theta:            _sumTheta / n,
      gamma:            _sumGamma / n,
      delta:            _sumDelta / n,
      durationSeconds:  step.durationSeconds,
    ));

    if (_stepIndex < _kSteps.length - 1) {
      setState(() {
        _running   = false;
        _stepIndex = _stepIndex + 1;
      });
    } else {
      _submitCalibration();
    }
  }

  Future<void> _submitCalibration() async {
    setState(() { _running = false; _done = true; });

    final steps = _collected.map((b) => CalibrationStep(
      step:            b.step,
      alpha:           b.alpha,
      beta:            b.beta,
      theta:           b.theta,
      gamma:           b.gamma,
      delta:           b.delta,
      durationSeconds: b.durationSeconds,
    )).toList();

    final result = await context.read<AiProvider>().submitCalibration(steps);

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Calibration Complete',
            style: GoogleFonts.poppins(
                color: _kTextPri, fontSize: 17, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Icon(PhosphorIcons.checkCircle(),
                color: _kAccentGrn, size: 48),
            const SizedBox(height: 16),
            Text(
              result?.message ??
                  'Your brain baseline has been saved. The AI will use it to personalise emotion detection.',
              style: GoogleFonts.poppins(color: _kTextSec, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Done',
                style: GoogleFonts.poppins(
                    color: _kAccentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBgTop, _kBgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _done
                    ? _buildDoneState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          children: [
                            _buildStepIndicator(),
                            const SizedBox(height: 24),
                            _buildActiveStep(),
                            const SizedBox(height: 24),
                            _buildUpcomingSteps(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(PhosphorIcons.arrowLeft(), color: _kTextPri, size: 22),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              'Brain Calibration',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: _kTextPri,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kSteps.length, (i) {
        final done    = i < _stepIndex;
        final active  = i == _stepIndex;
        final step    = _kSteps[i];
        final color   = done ? _kAccentGrn : (active ? step.color : _kCardBorder);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.title,
                  style: GoogleFonts.poppins(
                    color: active ? _kTextPri : _kTextSec,
                    fontSize: 11,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActiveStep() {
    final step     = _kSteps[_stepIndex];
    final progress = _running
        ? (_secondsLeft / step.durationSeconds)
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: [
          // Animated pulse ring around the icon
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              final scale = _running
                  ? 1.0 + _pulseCtrl.value * 0.12
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step.color.withValues(alpha: 0.12),
                border: Border.all(
                    color: step.color.withValues(alpha: 0.5), width: 2),
              ),
              child: Icon(step.icon, color: step.color, size: 36),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            step.title,
            style: GoogleFonts.poppins(
                color: _kTextPri, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            step.instruction,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: _kTextSec, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          // Countdown circle
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _running ? progress : 0,
                  strokeWidth: 6,
                  backgroundColor: _kCardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(step.color),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _running ? '$_secondsLeft' : step.durationSeconds.toString(),
                      style: GoogleFonts.poppins(
                          color: _kTextPri,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    ),
                    Text('sec',
                        style: GoogleFonts.poppins(
                            color: _kTextSec, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (!_running)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: step.color,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _stepIndex == 0 ? 'Start Calibration' : 'Start ${step.title}',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSteps() {
    final upcoming = _kSteps.sublist(_stepIndex + 1);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Up Next',
            style: GoogleFonts.poppins(
                color: _kTextSec, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        ...upcoming.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kCardBorder),
                ),
                child: Row(
                  children: [
                    Icon(s.icon, color: _kTextSec, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.title,
                          style: GoogleFonts.poppins(
                              color: _kTextSec, fontSize: 13)),
                    ),
                    Text('${s.durationSeconds}s',
                        style: GoogleFonts.poppins(
                            color: _kTextSec, fontSize: 12)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildDoneState() {
    return const Center(
      child: CircularProgressIndicator(color: _kAccentCyan, strokeWidth: 2.5),
    );
  }
}

// ── Internal data holder ──────────────────────────────────────────────────────
class _StepBands {
  final String step;
  final double alpha, beta, theta, gamma, delta;
  final int durationSeconds;

  const _StepBands({
    required this.step,
    required this.alpha,
    required this.beta,
    required this.theta,
    required this.gamma,
    required this.delta,
    required this.durationSeconds,
  });
}
