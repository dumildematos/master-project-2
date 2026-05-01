import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/theme.dart';
import '../services/sentio_api.dart' as api;

class PatternsScreen extends StatefulWidget {
  const PatternsScreen({super.key});

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  double  _intensity       = 0.74;
  double  _brightness      = 0.92;
  bool    _loading         = true;
  String? _selectedPattern;   // null = AUTO (AI-driven)

  WebViewController? _webCtrl;
  HttpServer?        _server;
  int                _port = 0;

  static const _patterns = [
    ('fluid',      'FLUID WAVES',  Icons.waves),
    ('breathing',  'BREATHING',    Icons.air),
    ('geometric',  'GEOMETRIC',    Icons.hexagon_outlined),
    ('fireworks',  'FIREWORKS',    Icons.auto_awesome),
    ('stress',     'CHAOTIC',      Icons.electric_bolt),
    ('pulse',      'PULSE',        Icons.radio_button_checked),
    ('stars',      'STAR FIELD',   Icons.star_border),
  ];

  @override
  void initState() {
    super.initState();
    _initViewer();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _initViewer() async {
    // ── 1. Extract GLB to cache dir ─────────────────────────────────────────
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/sentio_models');
    await dir.create(recursive: true);

    final glbFile = File('${dir.path}/oversized_t-shirt.glb');
    if (!glbFile.existsSync()) {
      final data = await rootBundle.load('assets/models/oversized_t-shirt.glb');
      await glbFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }

    // ── 2. Spin up a local HTTP server to serve the GLB ─────────────────────
    // Android WebView blocks file:// XHR cross-origin requests, so we serve
    // the model over localhost instead — no extra packages needed.
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port   = _server!.port;

    _server!.listen((req) async {
      if (req.uri.path == '/model.glb') {
        req.response.headers
          ..set(HttpHeaders.contentTypeHeader, 'model/gltf-binary')
          ..set('Access-Control-Allow-Origin', '*');
        await req.response.addStream(glbFile.openRead());
      } else {
        req.response.statusCode = HttpStatus.notFound;
      }
      await req.response.close();
    });

    // ── 3. Build WebViewController ──────────────────────────────────────────
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kBg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadHtmlString(_buildHtml(_intensity, _brightness, _port));

    if (mounted) setState(() => _webCtrl = ctrl);
  }

  void _update() {
    _webCtrl?.runJavaScript(
      'updatePattern(${_intensity.toStringAsFixed(3)}, ${_brightness.toStringAsFixed(3)});',
    );
  }

  void _recalibrate() {
    _webCtrl?.runJavaScript(
      'recalibrate(${_intensity.toStringAsFixed(3)}, ${_brightness.toStringAsFixed(3)});',
    );
  }

  Future<void> _selectPattern(String? pattern) async {
    try {
      await api.selectPattern(pattern);
      if (mounted) setState(() => _selectedPattern = pattern);
    } catch (_) {
      // Non-fatal — backend may not be reachable
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewH = MediaQuery.of(context).size.height * 0.46;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Live sync badge ─────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: kMd, bottom: kSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: kMd, vertical: 7),
                decoration: BoxDecoration(
                  color: kBg2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kCyan.withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                      color: kCyan, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('LIVE SYNC ACTIVE',
                    style: TextStyle(
                      fontFamily: 'monospace', fontSize: 11,
                      fontWeight: FontWeight.bold, color: kCyan, letterSpacing: 2,
                    )),
                ]),
              ),
            ),
          ),

          // ── 3D WebGL viewer ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kMd),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: viewH,
                child: Stack(
                  children: [
                    if (_webCtrl != null)
                      WebViewWidget(controller: _webCtrl!),
                    if (_loading)
                      Container(
                        color: kBg2,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: kCyan, strokeWidth: 2,
                              ),
                              const SizedBox(height: kMd),
                              Text(
                                _webCtrl == null
                                    ? 'EXTRACTING MODEL…'
                                    : 'LOADING 3D VIEWER…',
                                style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11,
                                  color: kCyan, letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: kMd),

          // ── Pattern Intensity ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kMd),
            child: _SliderCard(
              label:      'PATTERN INTENSITY',
              value:      _intensity,
              displayPct: '${(_intensity * 100).round()}%',
              leftLabel:  'MINIMAL',
              rightLabel: 'HYPER-DRIVE',
              onChanged: (v) {
                setState(() => _intensity = v);
                _update();
              },
            ),
          ),

          const SizedBox(height: kMd),

          // ── Glow Brightness ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kMd),
            child: _SliderCard(
              label:      'GLOW BRIGHTNESS',
              value:      _brightness,
              displayPct: '${(_brightness * 100).round()}%',
              leftLabel:  'DIM',
              rightLabel: 'MAXIMUM',
              onChanged: (v) {
                setState(() => _brightness = v);
                _update();
              },
            ),
          ),

          const SizedBox(height: kMd),

          // ── Pattern Selection ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kMd),
            child: _PatternSelector(
              selected:  _selectedPattern,
              patterns:  _patterns,
              onSelect:  _selectPattern,
            ),
          ),

          const SizedBox(height: kMd),

          // ── Adaptive Response card ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(kMd, 0, kMd, kXl),
            child: Container(
              padding: const EdgeInsets.all(kMd),
              decoration: BoxDecoration(
                color: kBg2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: kCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kCyan.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.auto_awesome, color: kCyan, size: 22),
                ),
                const SizedBox(width: kMd),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adaptive Response',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: kText,
                        )),
                      SizedBox(height: 4),
                      Text(
                        'Visuals are currently reacting to your real-time cognitive focus metrics.',
                        style: TextStyle(fontSize: 12, color: kMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSm),
                OutlinedButton(
                  onPressed: _recalibrate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kText,
                    side: const BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: kMd, vertical: kSm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 1,
                    ),
                  ),
                  child: const Text('RECALIBRATE'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slider card ────────────────────────────────────────────────────────────────
class _SliderCard extends StatelessWidget {
  final String label, displayPct, leftLabel, rightLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderCard({
    required this.label,      required this.value,
    required this.displayPct, required this.leftLabel,
    required this.rightLabel, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, kSm),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 11,
                  fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 1.5,
                )),
              Text(displayPct,
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 15,
                  fontWeight: FontWeight.bold, color: kCyan,
                )),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor:   kCyan,
              inactiveTrackColor: kBorder,
              thumbColor:         kCyan,
              overlayColor:       kCyan.withOpacity(0.12),
              trackHeight:        4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(leftLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 9,
                    color: kMuted, letterSpacing: 1,
                  )),
                Text(rightLabel,
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 9,
                    color: kMuted, letterSpacing: 1,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pattern Selector ───────────────────────────────────────────────────────────
class _PatternSelector extends StatelessWidget {
  final String?                                      selected;
  final List<(String, String, IconData)>             patterns;
  final void Function(String?)                       onSelect;

  const _PatternSelector({
    required this.selected,
    required this.patterns,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kMd, kMd, kMd, kSm),
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PATTERN OVERRIDE',
                style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11,
                  fontWeight: FontWeight.bold, color: kMuted, letterSpacing: 1.5,
                ),
              ),
              Text(
                selected == null ? 'AUTO' : selected!.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13,
                  fontWeight: FontWeight.bold, color: kCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSm),
          // AUTO chip
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PatternChip(
                label: 'AUTO',
                icon:  Icons.auto_fix_high,
                active: selected == null,
                onTap: () => onSelect(null),
              ),
              for (final (id, label, icon) in patterns)
                _PatternChip(
                  label:  label,
                  icon:   icon,
                  active: selected == id,
                  onTap:  () => onSelect(id),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'AUTO lets the AI choose based on your emotion.',
            style: TextStyle(
              fontFamily: 'monospace', fontSize: 9,
              color: kMuted, letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     active;
  final VoidCallback onTap;

  const _PatternChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kCyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? kCyan : kBorder,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: active ? kCyan : kMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? kCyan : kMuted,
              letterSpacing: 1,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Three.js HTML (GLB served from localhost) ──────────────────────────────────
String _buildHtml(double intensity, double brightness, int port) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { background:#080C10; overflow:hidden; width:100vw; height:100vh; }
    #status {
      position:absolute; top:50%; left:50%;
      transform:translate(-50%,-50%);
      color:#29D9C8; font-family:monospace; font-size:12px;
      letter-spacing:2px; text-align:center; pointer-events:none;
    }
  </style>
</head>
<body>
<div id="status">LOADING MODEL…</div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
<script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
<script>
  let intensity  = ${intensity.toStringAsFixed(3)};
  let brightness = ${brightness.toStringAsFixed(3)};
  let model = null;
  let tex   = null;

  // ── Renderer ───────────────────────────────────────────────────────────────
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x080C10);
  scene.fog = new THREE.FogExp2(0x080C10, 0.04);

  const camera = new THREE.PerspectiveCamera(
    45, window.innerWidth / window.innerHeight, 0.1, 100
  );
  camera.position.set(0, 0.3, 4.5);

  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  document.body.appendChild(renderer.domElement);

  // ── Controls ───────────────────────────────────────────────────────────────
  const controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.enableDamping   = true;
  controls.dampingFactor   = 0.06;
  controls.minDistance     = 1.5;
  controls.maxDistance     = 10;
  controls.autoRotate      = true;
  controls.autoRotateSpeed = 0.5;
  controls.target.set(0, 0, 0);

  // ── Circuit-board canvas texture ───────────────────────────────────────────
  function makeTexture(ity, brt) {
    const sz  = 1024;
    const cvs = document.createElement('canvas');
    cvs.width = sz; cvs.height = sz;
    const ctx = cvs.getContext('2d');

    ctx.fillStyle = '#050810';
    ctx.fillRect(0, 0, sz, sz);

    const pal  = ['#29D9C8','#29D9C8','#C45AEC','#F5A623','#3A86FF','#FF006E','#52B788'];
    const step = 28;

    for (let x = step; x < sz; x += step) {
      for (let y = step; y < sz; y += step) {
        if (Math.random() < ity * 0.88) {
          const col = pal[Math.floor(Math.random() * pal.length)];
          ctx.strokeStyle = col;
          ctx.lineWidth   = 1.4;
          ctx.globalAlpha = 0.10 + brt * 0.35;
          ctx.beginPath();
          const r = Math.random();
          if      (r < 0.35) { ctx.moveTo(x - step, y); ctx.lineTo(x, y); }
          else if (r < 0.70) { ctx.moveTo(x, y - step); ctx.lineTo(x, y); }
          else { ctx.moveTo(x, y); ctx.lineTo(x + step, y);
                 ctx.moveTo(x + step, y); ctx.lineTo(x + step, y + step); }
          ctx.stroke();
        }
        if (Math.random() < 0.18 * ity) {
          const col  = pal[Math.floor(Math.random() * pal.length)];
          const base = brt * 0.55;
          const g    = ctx.createRadialGradient(x, y, 0, x, y, 10);
          g.addColorStop(0, col); g.addColorStop(1, 'rgba(0,0,0,0)');
          ctx.globalAlpha = base * 0.5;
          ctx.fillStyle   = g;
          ctx.beginPath(); ctx.arc(x, y, 10, 0, Math.PI * 2); ctx.fill();
          ctx.globalAlpha = 0.55 + base;
          ctx.fillStyle   = col;
          ctx.beginPath(); ctx.arc(x, y, 2, 0, Math.PI * 2); ctx.fill();
        }
      }
    }
    ctx.globalAlpha = 1;
    const t = new THREE.CanvasTexture(cvs);
    t.anisotropy = renderer.capabilities.getMaxAnisotropy();
    return t;
  }

  function applyTexture(ity, brt) {
    if (tex) tex.dispose();
    tex = makeTexture(ity, brt);
    if (!model) return;
    model.traverse(function(child) {
      if (!child.isMesh) return;
      child.material.map              = tex;
      child.material.emissiveMap      = tex;
      child.material.emissiveIntensity = brt * 0.5;
      child.material.needsUpdate      = true;
    });
  }

  // ── Lights ─────────────────────────────────────────────────────────────────
  scene.add(new THREE.AmbientLight(0xffffff, 0.3));
  const lC = new THREE.PointLight(0x29D9C8, 2.5, 12); lC.position.set( 2,  1.5, 4); scene.add(lC);
  const lM = new THREE.PointLight(0xC45AEC, 1.8, 12); lM.position.set(-2, -0.5, 3); scene.add(lM);
  const lA = new THREE.PointLight(0xF5A623, 1.2, 12); lA.position.set( 0,   -2, 3); scene.add(lA);
  const lB = new THREE.DirectionalLight(0xffffff, 0.4); lB.position.set(0, 5, -4); scene.add(lB);

  // ── Load GLB from local HTTP server ────────────────────────────────────────
  const loader = new THREE.GLTFLoader();
  loader.load(
    'http://localhost:$port/model.glb',
    function(gltf) {
      model = gltf.scene;

      // Auto-scale & centre
      const box    = new THREE.Box3().setFromObject(model);
      const center = box.getCenter(new THREE.Vector3());
      const size   = box.getSize(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.y, size.z);
      const scale  = 3.2 / maxDim;
      model.scale.setScalar(scale);
      model.position.copy(center).negate().multiplyScalar(scale);

      // Replace all mesh materials with circuit-board material
      tex = makeTexture(intensity, brightness);
      model.traverse(function(child) {
        if (!child.isMesh) return;
        child.castShadow    = true;
        child.receiveShadow = true;
        child.material = new THREE.MeshStandardMaterial({
          map:               tex,
          roughness:         0.65,
          metalness:         0.2,
          emissiveMap:       tex,
          emissive:          new THREE.Color(1, 1, 1),
          emissiveIntensity: brightness * 0.5,
        });
      });

      scene.add(model);
      document.getElementById('status').style.display = 'none';
    },
    function(xhr) {
      if (xhr.total > 0) {
        const pct = Math.round(xhr.loaded / xhr.total * 100);
        const el  = document.getElementById('status');
        if (el) el.textContent = 'LOADING MODEL… ' + pct + '%';
      }
    },
    function(err) {
      const el = document.getElementById('status');
      if (el) el.textContent = 'ERROR: ' + err.message;
    }
  );

  // ── Flutter JS interface ───────────────────────────────────────────────────
  function updatePattern(ity, brt) {
    intensity  = ity;
    brightness = brt;
    if (!model) return;
    model.traverse(function(child) {
      if (child.isMesh) child.material.emissiveIntensity = brt * 0.5;
    });
  }

  function recalibrate(ity, brt) {
    intensity  = ity;
    brightness = brt;
    applyTexture(ity, brt);
  }

  // ── Resize ─────────────────────────────────────────────────────────────────
  window.addEventListener('resize', function() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  });

  // ── Render loop ────────────────────────────────────────────────────────────
  (function loop() {
    requestAnimationFrame(loop);
    controls.update();
    const t = Date.now() * 0.001;
    lC.intensity = 2.2 + Math.sin(t * 1.1) * 0.5;
    lM.intensity = 1.5 + Math.sin(t * 0.7 + 1.2) * 0.4;
    renderer.render(scene, camera);
  })();
</script>
</body>
</html>
''';
