// live_brainwaves_screen.dart — SENTIO Live Brainwaves
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/sentio_provider.dart';
import '../models/sentio_state.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF020A14);
const _kCard   = Color(0xFF0B1520);
const _kBorder = Color(0xFF182030);
const _kCyan   = Color(0xFF00D9FF);
const _kMuted  = Color(0xFF9AA6B2);

// ── Band meta — [name, color] — colors extracted from screenshot
const _kBands = [
  ('Delta', Color(0xFF3A86FF)), // blue
  ('Theta', Color(0xFF00D9FF)), // cyan
  ('Alpha', Color(0xFF43F26B)), // green  — highest line in chart
  ('Beta',  Color(0xFF782CFF)), // purple
  ('Gamma', Color(0xFFFF44BB)), // pink   — lowest line in chart
];

// Demo Hz values shown when no live EEG signal is present
// TODO: replace with real peak-frequency computation from SentioProvider
const _kDemoHz   = [1.2,  4.7,  10.3, 20.1, 36.6];
const _kDemoPcts = [0.13, 0.22, 0.35, 0.20, 0.10];

TextStyle _pp({
  double size = 14,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.white,
  double? spacing,
}) => GoogleFonts.poppins(
  fontSize: size, fontWeight: weight,
  color: color, letterSpacing: spacing,
);

// ══════════════════════════════════════════════════════════════════════════════
// LiveBrainwavesScreen
// ══════════════════════════════════════════════════════════════════════════════
class LiveBrainwavesScreen extends StatefulWidget {
  const LiveBrainwavesScreen({super.key});

  @override
  State<LiveBrainwavesScreen> createState() => _LBState();
}

class _LBState extends State<LiveBrainwavesScreen> {
  int  _tab        = 1; // 0=Brain, 1=Signals
  HttpServer? _server;
  int  _brainPort  = 0;
  bool _serverReady = false;

  @override
  void initState() {
    super.initState();
    _startBrainServer();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _startBrainServer() async {
    try {
      final tmp  = await getTemporaryDirectory();
      final dir  = Directory('${tmp.path}/sentio_brain');
      await dir.create(recursive: true);
      final file = File('${dir.path}/brain.glb');
      if (!file.existsSync()) {
        try {
          final data = await rootBundle.load('assets/models/brain.glb');
          await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
        } catch (_) {} // falls back to procedural brain
      }
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _brainPort = _server!.port;
      _server!.listen((req) async {
        if (req.uri.path == '/brain.glb' && file.existsSync()) {
          req.response.headers
            ..set(HttpHeaders.contentTypeHeader, 'model/gltf-binary')
            ..set('Access-Control-Allow-Origin', '*');
          await req.response.addStream(file.openRead());
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        await req.response.close();
      });
    } catch (_) {
      _brainPort = 0;
    }
    if (mounted) setState(() => _serverReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final sentio  = context.watch<SentioProvider>();
    final data    = sentio.data;
    final hist    = sentio.history;
    final hasData = sentio.hasSignal;

    // Use live band values or demo fallback
    // TODO: compute real Hz peak-frequencies per band from FFT analysis
    final pcts = hasData
        ? [data.delta, data.theta, data.alpha, data.beta, data.gamma]
        : List<double>.from(_kDemoPcts);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(onBack: () => Navigator.pop(context)),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(children: [
                // ① Tab toggle
                SegmentedControl(
                  labels: const ['Brain', 'Signals'],
                  icons:  [PhosphorIcons.brain(), PhosphorIcons.waveform()],
                  selected: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 14),

                if (_tab == 0) ...[
                  // ② 3D brain viewer
                  BrainVisual(port: _brainPort, ready: _serverReady),
                  const SizedBox(height: 14),

                  // ③ EEG metric cards (5 compact cards)
                  _MetricRow(pcts: pcts),
                  const SizedBox(height: 14),

                  // ④ Brainwave activity chart
                  BrainwaveChart(history: hist, live: data),
                ] else ...[
                  // ② Signals data
                  _SignalsView(),
                  const SizedBox(height: 20),
                  const StatusBarWidget(),
                ],
                const SizedBox(height: 16),
              ]),
            ),
          ),

          // Bottom navigation
          const _BottomNav(),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Top bar — hamburger | title | info circle
// ══════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Icon(PhosphorIcons.list(), color: Colors.white, size: 26),
        ),
        Expanded(
          child: Text(
            'Live Brainwaves',
            textAlign: TextAlign.center,
            style: _pp(size: 18, weight: FontWeight.w700),
          ),
        ),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 1.5),
          ),
          child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SegmentedControl — "Brain | Signals" toggle
// ══════════════════════════════════════════════════════════════════════════════
class SegmentedControl extends StatelessWidget {
  final List<String>   labels;
  final List<IconData> icons;
  final int            selected;
  final ValueChanged<int> onTap;

  const SegmentedControl({
    super.key,
    required this.labels,
    required this.icons,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: List.generate(labels.length, (i) {
        final active = i == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: active ? _kCyan.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: active
                    ? Border.all(color: _kCyan.withValues(alpha: 0.50), width: 1.2)
                    : null,
                boxShadow: active
                    ? [BoxShadow(
                        color: _kCyan.withValues(alpha: 0.16),
                        blurRadius: 8, spreadRadius: 1)]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icons[i],
                    color: active ? _kCyan : _kMuted,
                    size: 16),
                  const SizedBox(width: 6),
                  Text(
                    labels[i],
                    style: _pp(
                      size: 14,
                      weight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active ? _kCyan : _kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      })),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BrainVisual — Three.js WebView, no card border (blends into background)
// ══════════════════════════════════════════════════════════════════════════════
class BrainVisual extends StatefulWidget {
  final int  port;
  final bool ready;
  const BrainVisual({super.key, required this.port, required this.ready});

  @override
  State<BrainVisual> createState() => _BrainVisualState();
}

class _BrainVisualState extends State<BrainVisual> {
  WebViewController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.ready) _build();
  }

  @override
  void didUpdateWidget(BrainVisual old) {
    super.didUpdateWidget(old);
    if (widget.ready && _ctrl == null) _build();
  }

  void _build() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_kBg)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (_) => NavigationDecision.navigate))
      ..loadHtmlString(_brainHtml(widget.port));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: _ctrl == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.brain(),
                      color: _kCyan.withValues(alpha: 0.4), size: 48),
                  const SizedBox(height: 12),
                  Text('Initialising brain model…',
                      style: _pp(size: 11, color: _kCyan)),
                ],
              ),
            )
          : WebViewWidget(controller: _ctrl!),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MetricRow — 5 EEG metric cards side-by-side
// ══════════════════════════════════════════════════════════════════════════════
class _MetricRow extends StatelessWidget {
  final List<double> pcts; // 0.0–1.0

  const _MetricRow({required this.pcts});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 0; i < _kBands.length; i++) ...[
        Expanded(
          child: EEGMetricCard(
            label:  _kBands[i].$1,
            color:  _kBands[i].$2,
            hz:     _kDemoHz[i],   // TODO: compute from FFT of live EEG bands
            pct:    pcts[i].clamp(0.0, 1.0),
          ),
        ),
        if (i < _kBands.length - 1) const SizedBox(width: 6),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EEGMetricCard — compact card: wave icon + Hz + % + progress bar
// ══════════════════════════════════════════════════════════════════════════════
class EEGMetricCard extends StatelessWidget {
  final String label;
  final Color  color;
  final double hz;
  final double pct; // 0.0–1.0

  const EEGMetricCard({
    super.key,
    required this.label,
    required this.color,
    required this.hz,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wave icon + band label in band color
          Row(children: [
            SizedBox(
              width: 14, height: 10,
              child: CustomPaint(painter: _MiniWavePainter(color: color)),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: _pp(size: 10, color: color, weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 5),

          // Frequency value
          Text(
            '${hz.toStringAsFixed(1)} Hz',
            style: _pp(size: 14, weight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),

          // Percentage
          Text(
            '${(pct * 100).round()}%',
            style: _pp(size: 11, color: _kMuted),
          ),
          const SizedBox(height: 7),

          // Colored progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BrainwaveChart — activity card with dropdown, Y-axis labels, bottom legend
// ══════════════════════════════════════════════════════════════════════════════
class BrainwaveChart extends StatelessWidget {
  final List<BandHistory> history;
  final SentioState       live;

  const BrainwaveChart({
    super.key,
    required this.history,
    required this.live,
  });

  // Build chart spots for one band (0=delta … 4=gamma)
  // TODO: replace with real rolling buffer from SentioProvider when live
  List<FlSpot> _spots(int band) {
    if (history.length > 2) {
      final n = history.length;
      return List.generate(n, (i) {
        final t = (i / (n - 1)) * 60.0;
        final v = _bandVal(history[i], band) * 90 + 5;
        return FlSpot(t, v.clamp(2.0, 98.0));
      });
    }
    // Simulated EEG waves with levels matching the screenshot visual
    final rng  = math.Random(band * 13 + 7);
    final freq = [0.30, 0.45, 0.60, 1.20, 2.40][band];
    final amp  = [14.0, 12.0,  9.0,  9.0,  7.0][band];
    final base = [55.0, 64.0, 77.0, 38.0, 18.0][band];
    return List.generate(120, (i) {
      final t = i * 0.5;
      final v = base
          + amp * math.sin(t * freq + band)
          + amp * 0.35 * math.sin(t * freq * 2.3 + 1.0)
          + amp * 0.18 * math.sin(t * freq * 3.7 + 2.0)
          + (rng.nextDouble() - 0.5) * 7;
      return FlSpot(t, v.clamp(2.0, 98.0));
    });
  }

  static double _bandVal(BandHistory h, int b) => switch (b) {
    0 => h.delta,
    1 => h.theta,
    2 => h.alpha,
    3 => h.beta,
    4 => h.gamma,
    _ => 0.0,
  };

  LineChartBarData _line(int band) {
    final color = _kBands[band].$2;
    return LineChartBarData(
      spots:           _spots(band),
      isCurved:        true,
      curveSmoothness: 0.28,
      color:           color,
      barWidth:        1.8,
      isStrokeCapRound: true,
      dotData:         const FlDotData(show: false),
      belowBarData:    BarAreaData(show: false),
      shadow:          Shadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: 5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartData = LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: Color(0x15FFFFFF),
          strokeWidth: 0.8,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: 25,
            getTitlesWidget: (v, _) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${v.toInt()}',
                style: _pp(size: 10, color: _kMuted),
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: 15,
            getTitlesWidget: (v, _) {
              final secs = (v - 60).toInt();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${secs}s',
                  style: _pp(size: 10, color: _kMuted),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0, maxX: 60,
      minY: 0, maxY: 100,
      lineBarsData: List.generate(5, _line),
      clipData: const FlClipData.all(),
    );

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + dropdown
          Row(children: [
            Text('Brainwave Activity',
                style: _pp(size: 15, weight: FontWeight.w600)),
            const Spacer(),
            _TimeDropdown(),
          ]),
          const SizedBox(height: 14),

          // Chart
          SizedBox(
            height: 220,
            child: LineChart(chartData,
                duration: const Duration(milliseconds: 300)),
          ),
          const SizedBox(height: 12),

          // Legend
          const ChartLegend(),
        ],
      ),
    );
  }
}

// ── Dropdown button (static, no real selection needed yet) ─────────────────────
class _TimeDropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Last 60 Seconds',
            style: _pp(size: 11, color: _kMuted)),
        const SizedBox(width: 4),
        const Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted, size: 16),
      ]),
    );
  }
}

// ── Chart legend — colored dots + band names ───────────────────────────────────
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(_kBands.length, (i) {
        final (label, color) = _kBands[i];
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(label, style: _pp(size: 11, color: _kMuted)),
        ]);
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Signal band model and UI helpers for the Signals tab
// ══════════════════════════════════════════════════════════════════════════════
class SignalBand {
  final String name;
  final String range;
  final double frequency;
  final int powerPct;
  final Color color;
  final List<double> samples;

  const SignalBand({
    required this.name,
    required this.range,
    required this.frequency,
    required this.powerPct,
    required this.color,
    required this.samples,
  });

  List<FlSpot> get spots => List.generate(
        samples.length,
        (index) => FlSpot(index * 3, samples[index]),
      );
}

final _kSignalBands = [
  SignalBand(
    name: 'Delta', range: '1 - 4 Hz', frequency: 1.2, powerPct: 13,
    color: _kBands[0].$2,
    samples: [0, 24, -18, 30, -10, 22, -8, 28, -16, 14, -6, 18, -12, 10, -4, 8, -2, 10, -6, 0],
  ),
  SignalBand(
    name: 'Theta', range: '4 - 8 Hz', frequency: 4.7, powerPct: 22,
    color: _kBands[1].$2,
    samples: [0, 20, -20, 34, -20, 22, -18, 28, -22, 18, -12, 24, -16, 16, -10, 20, -8, 12, -6, 0],
  ),
  SignalBand(
    name: 'Alpha', range: '8 - 12 Hz', frequency: 10.3, powerPct: 35,
    color: _kBands[2].$2,
    samples: [0, 42, -25, 55, -35, 48, -30, 50, -38, 40, -22, 46, -32, 30, -24, 38, -18, 24, -12, 0],
  ),
  SignalBand(
    name: 'Beta', range: '12 - 30 Hz', frequency: 20.1, powerPct: 20,
    color: _kBands[3].$2,
    samples: [0, 22, -18, 32, -22, 30, -20, 28, -24, 24, -16, 26, -20, 22, -14, 24, -12, 18, -10, 0],
  ),
  SignalBand(
    name: 'Gamma', range: '30 - 50 Hz', frequency: 36.6, powerPct: 10,
    color: _kBands[4].$2,
    samples: [0, 18, -12, 20, -16, 22, -14, 18, -12, 16, -10, 14, -8, 12, -6, 10, -4, 8, -2, 0],
  ),
];

class _SignalsView extends StatelessWidget {
  const _SignalsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final band in _kSignalBands) ...[
          SignalCard(band: band),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class SignalCard extends StatelessWidget {
  final SignalBand band;
  const SignalCard({Key? key, required this.band}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: band.color.withValues(alpha: 0.17),
            blurRadius: 26,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(band.name, style: _pp(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(band.range, style: _pp(size: 12, color: _kMuted)),
                  ],
                ),
              ),
              Container(width: 1, height: 44, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${band.frequency.toStringAsFixed(1)} Hz',
                      style: _pp(size: 16, weight: FontWeight.w700, color: band.color)),
                  const SizedBox(height: 4),
                  Text('Amplitude', style: _pp(size: 11, color: _kMuted)),
                  const SizedBox(height: 12),
                  Text('${band.powerPct}%',
                      style: _pp(size: 16, weight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Power', style: _pp(size: 11, color: _kMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          WaveChart(spots: band.spots, color: band.color),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: band.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Live', style: _pp(size: 12, color: _kMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class WaveChart extends StatelessWidget {
  final List<FlSpot> spots;
  final Color color;
  const WaveChart({Key? key, required this.spots, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 100,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.07),
              strokeWidth: value == 0 ? 1.2 : 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 100,
                getTitlesWidget: (value, meta) {
                  if (value == 100 || value == 0 || value == -100) {
                    return Text(value.toInt().toString(),
                        style: _pp(size: 10, color: _kMuted));
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: -100,
          maxY: 100,
          minX: 0,
          maxX: (spots.length - 1) * 3,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.14),
              ),
              shadow: const Shadow(
                blurRadius: 18,
                color: Colors.white24,
                offset: Offset(0, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBarWidget extends StatelessWidget {
  const StatusBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          StatusItem(
            icon: PhosphorIcons.waveform(),
            label: 'Signal Quality',
            value: 'Good',
            accent: _kCyan,
          ),
          StatusItem(
            icon: PhosphorIcons.wifiHigh(),
            label: 'Connection',
            value: 'Excellent',
            accent: Color(0xFF43F26B),
          ),
          StatusItem(
            icon: PhosphorIcons.clock(),
            label: 'Live',
            value: '00:01:24',
            accent: _kBands[3].$2,
          ),
        ],
      ),
    );
  }
}

class StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const StatusItem({Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label, style: _pp(size: 11, color: _kMuted)),
          const SizedBox(height: 4),
          Text(value, style: _pp(size: 14, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bottom navigation
// ══════════════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon:     PhosphorIcons.house(),
              label:    'Home',
              active:   true,
              onTap:    () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
            _NavItem(
              icon:     PhosphorIcons.clockCounterClockwise(),
              label:    'History',
              active:   false,
              onTap:    () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
            _NavItem(
              icon:     PhosphorIcons.user(),
              label:    'Profile',
              active:   false,
              onTap:    () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = active ? _kCyan : _kMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: col, size: 22),
            const SizedBox(height: 2),
            Text(label,
              style: GoogleFonts.poppins(
                fontSize: 10, color: col,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
            if (active) ...[
              const SizedBox(height: 2),
              Container(width: 20, height: 2.5,
                decoration: BoxDecoration(
                  color: _kCyan, borderRadius: BorderRadius.circular(2))),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom painters
// ══════════════════════════════════════════════════════════════════════════════

// ── Mini wave icon for EEG metric card header ──────────────────────────────────
class _MiniWavePainter extends CustomPainter {
  final Color color;
  const _MiniWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const steps = 20;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final y = size.height / 2 + size.height * 0.38 * math.sin(t * math.pi * 2.5);
      if (i == 0) { path.moveTo(x, y); }
      else         { path.lineTo(x, y); }
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_MiniWavePainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// Three.js brain HTML (unchanged — procedural fallback + GLB loader)
// ══════════════════════════════════════════════════════════════════════════════
String _brainHtml(int port) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { background:#020A14; overflow:hidden; width:100vw; height:100vh; }
    #status {
      position:absolute; top:50%; left:50%;
      transform:translate(-50%,-50%);
      color:#00D9FF; font-family:monospace; font-size:11px;
      letter-spacing:2px; text-align:center; pointer-events:none;
    }
  </style>
</head>
<body>
<div id="status">LOADING BRAIN MODEL…</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script>
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x020A14);
const camera = new THREE.PerspectiveCamera(42, window.innerWidth/window.innerHeight, 0.1, 100);
camera.position.set(0, 0.15, 3.2);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
document.body.appendChild(renderer.domElement);
const controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.enableDamping = true; controls.dampingFactor = 0.07;
controls.autoRotate = true; controls.autoRotateSpeed = 0.9;
controls.enablePan = false; controls.minDistance = 1.5; controls.maxDistance = 7.0;
controls.target.set(0, 0.05, 0);
scene.add(new THREE.AmbientLight(0x080818, 0.6));
const lCyan = new THREE.PointLight(0x00D9FF, 5.0, 10);
lCyan.position.set(1.8, 0.6, 2.2); scene.add(lCyan);
const lPurple = new THREE.PointLight(0x8A2CFF, 4.5, 10);
lPurple.position.set(-2.0, 0.2, 0.8); scene.add(lPurple);
const lRim = new THREE.PointLight(0x0033BB, 2.5, 8);
lRim.position.set(0.0, -2.0, -2.0); scene.add(lRim);
const lTop = new THREE.DirectionalLight(0x88AAFF, 0.5);
lTop.position.set(0, 4, 1); scene.add(lTop);
const port = $port;
function hideStatus() { const el=document.getElementById('status'); if(el) el.style.display='none'; }
function setStatus(msg) { const el=document.getElementById('status'); if(el) el.textContent=msg; }
if (port > 0) {
  const loader = new THREE.GLTFLoader();
  loader.load('http://localhost:' + port + '/brain.glb',
    function(gltf) {
      const model = gltf.scene;
      const box = new THREE.Box3().setFromObject(model);
      const ctr = box.getCenter(new THREE.Vector3());
      const sz  = box.getSize(new THREE.Vector3());
      const sc  = 2.4 / Math.max(sz.x, sz.y, sz.z);
      model.scale.setScalar(sc);
      model.position.copy(ctr).negate().multiplyScalar(sc);
      model.traverse(function(ch) {
        if (!ch.isMesh) return;
        ch.material = new THREE.MeshPhongMaterial({
          color: 0x07051E, emissive: 0x080030,
          emissiveIntensity: 0.35, shininess: 90,
          specular: new THREE.Color(0x3355FF),
        });
        ch.castShadow = ch.receiveShadow = true;
      });
      scene.add(model); hideStatus();
    },
    function(p) { if(p.total>0) setStatus('LOADING '+Math.round(p.loaded/p.total*100)+'%'); },
    function(_err) { buildProcedural(); }
  );
} else { buildProcedural(); }
function buildProcedural() {
  const g = new THREE.Group();
  function noiseFn(x,y,z) {
    return Math.sin(x*7.1+y*3.9)*0.33+Math.sin(y*5.5+z*3.1)*0.33+Math.sin(z*6.3+x*2.7)*0.34;
  }
  function displace(geo, scale, yScale) {
    const pos = geo.attributes.position;
    for (let i=0;i<pos.count;i++) {
      const x=pos.getX(i),y=pos.getY(i),z=pos.getZ(i);
      const n=noiseFn(x*2.2,y*2.2,z*2.2); const s=1.0+n*scale;
      pos.setXYZ(i,x*s,y*s*(yScale||1),z*s);
    }
    geo.computeVertexNormals(); return geo;
  }
  const lMat = new THREE.MeshPhongMaterial({color:0x10082A,emissive:0x280058,emissiveIntensity:0.55,shininess:65,specular:0x9933FF});
  const lH = new THREE.Mesh(displace(new THREE.SphereGeometry(0.82,56,42),0.13,0.88),lMat);
  lH.position.set(-0.24,0.02,0); g.add(lH);
  const rMat = new THREE.MeshPhongMaterial({color:0x060E22,emissive:0x003355,emissiveIntensity:0.55,shininess:65,specular:0x0088FF});
  const rH = new THREE.Mesh(displace(new THREE.SphereGeometry(0.80,56,42),0.13,0.88),rMat);
  rH.position.set(0.24,0.02,0); g.add(rH);
  const cbGeo = displace(new THREE.SphereGeometry(0.30,24,18),0.09);
  g.add(new THREE.Mesh(cbGeo,lMat)); g.children[g.children.length-1].position.set(0,-0.56,-0.62);
  const stemGeo = new THREE.CylinderGeometry(0.09,0.11,0.48,14);
  const stem = new THREE.Mesh(stemGeo,lMat);
  stem.position.set(0,-0.88,-0.28); stem.rotation.x=0.28; g.add(stem);
  const pGeo = new THREE.BufferGeometry();
  const N=350, pts=new Float32Array(N*3);
  for(let i=0;i<N;i++){
    const th=Math.random()*Math.PI*2, ph=Math.acos(2*Math.random()-1);
    const r=0.82+Math.random()*0.12;
    pts[i*3]=r*Math.sin(ph)*Math.cos(th); pts[i*3+1]=r*Math.sin(ph)*Math.sin(th)*0.86; pts[i*3+2]=r*Math.cos(ph);
  }
  pGeo.setAttribute('position',new THREE.BufferAttribute(pts,3));
  g.add(new THREE.Points(pGeo,new THREE.PointsMaterial({color:0x00D9FF,size:0.016,transparent:true,opacity:0.8})));
  const wGeo = new THREE.SphereGeometry(0.86,18,14);
  g.add(new THREE.Mesh(wGeo,new THREE.MeshBasicMaterial({color:0x00AAFF,wireframe:true,transparent:true,opacity:0.045})));
  scene.add(g); hideStatus();
}
let t=0;
(function animate(){
  requestAnimationFrame(animate); t+=0.016;
  lCyan.intensity=4.5+Math.sin(t*1.4)*1.5;
  lPurple.intensity=4.0+Math.sin(t*0.9+1.5)*1.2;
  controls.update(); renderer.render(scene,camera);
})();
window.addEventListener('resize',function(){
  camera.aspect=window.innerWidth/window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth,window.innerHeight);
});
</script>
</body>
</html>
''';
