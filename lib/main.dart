import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _appVersionName = '0.0.2';
const _appVersionLabel = 'v$_appVersionName';

void main() {
  runApp(const AutoSwiperApp());
}

class AutoSwiperApp extends StatelessWidget {
  const AutoSwiperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '随机滑屏',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: _AppColors.canvas,
        useMaterial3: true,
        fontFamilyFallback: const [
          'Inter',
          'Microsoft YaHei UI',
          'Segoe UI',
          'Roboto',
          'sans-serif',
        ],
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _AppColors.text,
          displayColor: _AppColors.text,
        ),
      ),
      home: const SwipeControlPage(),
    );
  }
}

class SwipeControlPage extends StatefulWidget {
  const SwipeControlPage({super.key});

  @override
  State<SwipeControlPage> createState() => _SwipeControlPageState();
}

class _SwipeControlPageState extends State<SwipeControlPage>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('auto_swiper/control');

  double _minInterval = 3;
  double _maxInterval = 8;
  double _randomStrength = 0.65;
  double _scatterRadiusPx = 10;
  int _multiTapCount = 3;
  double _multiTapIntervalMs = 100;
  SwipeDirection _direction = SwipeDirection.up;
  ActionPreset _actionPreset = ActionPreset.fling;
  LaunchStrategy _launchStrategy = LaunchStrategy.previousApp;
  List<TargetApp> _targetApps = const [];
  TargetApp? _selectedTargetApp;
  String? _rememberedTargetPackageName;
  bool _loadingTargetApps = false;
  bool _isRunning = false;
  bool _serviceEnabled = false;
  bool _debugLoggingEnabled = false;
  bool _controlOverlayEnabled = true;
  bool _tapAnchorVisible = false;
  bool _tapAnchorReady = false;
  bool _isBusy = false;
  double? _tapAnchorX;
  double? _tapAnchorY;
  Timer? _tapAnchorRefreshTimer;
  String _debugLogPath = '';
  String _statusText = '请先开启无障碍服务，再启动随机滑屏。';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLaunchPreferences();
    _refreshStatus();
    _loadTargetApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapAnchorRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final enabled =
        await _invoke<bool>('isServiceEnabled', fallback: false) ?? false;
    final running = await _invoke<bool>('isRunning', fallback: false) ?? false;
    final debugLogging =
        await _invoke<bool>('isDebugLoggingEnabled', fallback: false) ?? false;
    final controlOverlayEnabled =
        await _invoke<bool>('isControlOverlayEnabled', fallback: true) ?? true;
    final debugLogPath =
        await _invoke<String>('getDebugLogPath', fallback: '') ?? '';
    final tapAnchor = await _invoke<Map<dynamic, dynamic>>(
      'getTapAnchor',
      fallback: const {},
    );
    final tapAnchorX = (tapAnchor?['x'] as num?)?.toDouble();
    final tapAnchorY = (tapAnchor?['y'] as num?)?.toDouble();
    if (!mounted) {
      return;
    }
    setState(() {
      _serviceEnabled = enabled;
      _isRunning = running;
      _debugLoggingEnabled = debugLogging;
      _controlOverlayEnabled = controlOverlayEnabled;
      _debugLogPath = debugLogPath;
      _tapAnchorVisible = tapAnchor?['visible'] == true;
      _tapAnchorReady = tapAnchor?['hasPosition'] == true;
      _tapAnchorX = tapAnchorX;
      _tapAnchorY = tapAnchorY;
      _statusText = enabled
          ? (running ? '切到目标 App 后会按随机间隔执行，参数已锁定。' : '已就绪，启动后自动收起主界面并进入目标应用。')
          : '开启后才能在其他 App 中执行滑动、点击和连击。';
    });
    _syncTapAnchorRefreshTimer();
  }

  Future<T?> _invoke<T>(String method, {Object? arguments, T? fallback}) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return fallback;
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _statusText = error.message ?? '调用安卓服务失败：${error.code}';
        });
      }
      return fallback;
    }
  }

  Future<void> _openAccessibilitySettings() async {
    await _invoke<void>('openAccessibilitySettings');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refreshStatus();
  }

  Future<void> _setDebugLogging(bool value) async {
    setState(() {
      _debugLoggingEnabled = value;
    });
    await _invoke<void>('setDebugLoggingEnabled', arguments: value);
    await _refreshStatus();
  }

  Future<void> _clearDebugLog() async {
    await _invoke<void>('clearDebugLog');
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = '调试日志已清空。';
    });
  }

  Future<void> _copyDebugLogPath() async {
    final path = _debugLogPath.isEmpty ? '日志路径读取中...' : _debugLogPath;
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = '日志路径已复制。';
    });
  }

  Future<void> _moveToBack() async {
    await _invoke<void>('moveToBack');
  }

  Future<void> _loadLaunchPreferences() async {
    final preferences = await _invoke<Map<dynamic, dynamic>>(
      'getLaunchPreferences',
      fallback: const {},
    );
    if (!mounted) {
      return;
    }
    final targetPackageName = preferences?['targetPackageName']?.toString();
    setState(() {
      _launchStrategy = LaunchStrategy.fromName(
        preferences?['strategy']?.toString(),
      );
      _rememberedTargetPackageName =
          targetPackageName == null || targetPackageName.isEmpty
          ? null
          : targetPackageName;
      _selectedTargetApp = _targetAppForPackage(_rememberedTargetPackageName);
    });
  }

  Future<void> _saveLaunchPreferences() async {
    await _invoke<void>(
      'saveLaunchPreferences',
      arguments: <String, Object?>{
        'strategy': _launchStrategy.name,
        'targetPackageName': _rememberedTargetPackageName,
      },
    );
  }

  Future<void> _setControlOverlayEnabled(bool value) async {
    setState(() {
      _controlOverlayEnabled = value;
    });
    final applied =
        await _invoke<bool>('setControlOverlayEnabled', arguments: value) ??
        false;
    if (!mounted) {
      return;
    }
    if (!applied) {
      setState(() {
        _controlOverlayEnabled = !value;
        _statusText = '小窗口设置更新失败，请确认无障碍服务连接状态。';
      });
      return;
    }
    setState(() {
      _statusText = value ? '运行小窗口已启用。' : '运行小窗口已关闭。';
    });
    await _refreshStatus();
  }

  Future<void> _snapControlOverlay(String edge) async {
    final applied =
        await _invoke<bool>('snapControlOverlay', arguments: edge) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = applied
          ? '小窗口已设为靠${edge == 'left' ? '左' : '右'}显示。'
          : '小窗口位置保存失败，请确认无障碍服务状态。';
    });
  }

  Future<void> _loadTargetApps() async {
    if (_loadingTargetApps) {
      return;
    }
    setState(() {
      _loadingTargetApps = true;
    });
    final apps = await _invoke<List<dynamic>>(
      'listLaunchableApps',
      fallback: const [],
    );
    final targetApps = (apps ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(TargetApp.fromMap)
        .where((app) => app.packageName.isNotEmpty && app.label.isNotEmpty)
        .toList(growable: false);
    if (!mounted) {
      return;
    }
    setState(() {
      _targetApps = targetApps;
      _loadingTargetApps = false;
      if (_rememberedTargetPackageName != null) {
        _selectedTargetApp = _targetAppForPackage(_rememberedTargetPackageName);
      }
      if (_selectedTargetApp != null &&
          !targetApps.any(
            (app) => app.packageName == _selectedTargetApp!.packageName,
          )) {
        _selectedTargetApp = null;
      }
    });
  }

  Future<void> _openTargetAppPicker() async {
    if (_isRunning) {
      return;
    }

    setState(() {
      _launchStrategy = LaunchStrategy.selectedApp;
      _statusText = '正在读取可启动应用列表...';
    });

    if (_targetApps.isEmpty) {
      await _loadTargetApps();
    }
    if (!mounted) {
      return;
    }

    if (_targetApps.isEmpty) {
      setState(() {
        _statusText = '没有读取到可选择的目标 App。';
      });
      return;
    }

    final selected = await showModalBottomSheet<TargetApp>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final height = math.min(
          MediaQuery.sizeOf(context).height * 0.78,
          560.0,
        );
        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text(
                    '选择目标 App',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _AppColors.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _targetApps.length,
                    separatorBuilder: (_, index) =>
                        const Divider(height: 1, color: _AppColors.border),
                    itemBuilder: (context, index) {
                      final app = _targetApps[index];
                      final selected =
                          app.packageName == _selectedTargetApp?.packageName;
                      return ListTile(
                        title: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: _AppColors.success,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(app),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _selectedTargetApp = selected;
      _rememberedTargetPackageName = selected.packageName;
      _launchStrategy = LaunchStrategy.selectedApp;
      _statusText = '已选择目标 App：${selected.label}。';
    });
    await _saveLaunchPreferences();
  }

  Future<void> _showTapAnchor() async {
    final shown =
        await _invoke<bool>('showTapAnchor', fallback: false) ?? false;
    if (!shown) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = '点击标靶已显示。拖动标靶中心选择点击位置。';
    });
    await _refreshStatus();
  }

  Future<void> _hideTapAnchor() async {
    final hidden =
        await _invoke<bool>('hideTapAnchor', fallback: false) ?? false;
    if (!hidden) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = '点击锚点已隐藏，已保存的位置仍会继续用于点击。';
    });
    await _refreshStatus();
  }

  Future<void> _toggleTapAnchorVisibility(bool value) async {
    if (value) {
      await _showTapAnchor();
    } else {
      await _hideTapAnchor();
    }
  }

  Future<void> _refreshTapAnchor() async {
    final tapAnchor = await _invoke<Map<dynamic, dynamic>>(
      'getTapAnchor',
      fallback: const {},
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _tapAnchorVisible = tapAnchor?['visible'] == true;
      _tapAnchorReady = tapAnchor?['hasPosition'] == true;
      _tapAnchorX = (tapAnchor?['x'] as num?)?.toDouble();
      _tapAnchorY = (tapAnchor?['y'] as num?)?.toDouble();
    });
    _syncTapAnchorRefreshTimer();
  }

  void _syncTapAnchorRefreshTimer() {
    if (_tapAnchorVisible) {
      _tapAnchorRefreshTimer ??= Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _refreshTapAnchor(),
      );
      return;
    }

    _tapAnchorRefreshTimer?.cancel();
    _tapAnchorRefreshTimer = null;
  }

  Future<void> _toggleRunning() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });

    final enabled =
        await _invoke<bool>('isServiceEnabled', fallback: false) ?? false;
    if (!enabled) {
      if (mounted) {
        setState(() {
          _serviceEnabled = false;
          _isBusy = false;
          _statusText = '需要先开启无障碍服务，才能在其他 App 中执行滑动。';
        });
      }
      return;
    }

    if (!_isRunning &&
        _launchStrategy == LaunchStrategy.selectedApp &&
        _selectedTargetApp == null) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _statusText = '请先选择开始后要打开的目标 App。';
        });
      }
      return;
    }

    final wasRunning = _isRunning;
    final success = wasRunning
        ? (await _invoke<bool>('stop', fallback: false) ?? false)
        : (await _invoke<bool>(
                'startAndLaunch',
                arguments: <String, Object>{
                  'strategy': _launchStrategy.name,
                  if (_selectedTargetApp != null)
                    'targetPackageName': _selectedTargetApp!.packageName,
                  'config': <String, Object>{
                    'minIntervalMs': (_minInterval * 1000).round(),
                    'maxIntervalMs': (_maxInterval * 1000).round(),
                    'direction': _direction.name,
                    'actionPreset': _actionPreset.name,
                    'randomStrength': _randomStrength,
                    'scatterRadiusPx': _scatterRadiusPx,
                    'multiTapCount': _multiTapCount,
                    'multiTapIntervalMs': _multiTapIntervalMs.round(),
                  },
                },
                fallback: false,
              ) ??
              false);

    if (!mounted) {
      return;
    }
    setState(() {
      if (success) {
        _isRunning = !wasRunning;
        _statusText = wasRunning ? '随机动作已停止。' : '随机动作已启动。';
      }
      _isBusy = false;
    });
    await _refreshStatus();
  }

  void _setMinInterval(double value) {
    setState(() {
      _minInterval = _roundToTenth(value.clamp(1.0, 30.0).toDouble());
      if (_minInterval > _maxInterval) {
        _maxInterval = _minInterval;
      }
    });
  }

  void _setMaxInterval(double value) {
    setState(() {
      _maxInterval = _roundToTenth(value.clamp(1.0, 60.0).toDouble());
      if (_maxInterval < _minInterval) {
        _minInterval = _maxInterval;
      }
    });
  }

  void _commitMinInterval(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return;
    }
    _setMinInterval(parsed);
  }

  void _commitMaxInterval(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return;
    }
    _setMaxInterval(parsed);
  }

  void _setMultiTapCount(double value) {
    setState(() {
      _multiTapCount = value.round().clamp(2, 20);
    });
  }

  void _commitMultiTapCount(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return;
    }
    _setMultiTapCount(parsed.toDouble());
  }

  void _setMultiTapInterval(double value) {
    setState(() {
      _multiTapIntervalMs = value.round().clamp(50, 1000).toDouble();
    });
  }

  void _commitMultiTapInterval(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return;
    }
    _setMultiTapInterval(parsed.toDouble());
  }

  void _setScatterRadius(double value) {
    setState(() {
      _scatterRadiusPx = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 920) {
                return _buildPadLayout(context);
              }
              return _buildPhoneLayout(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _PageHeader(
          compact: true,
          onCollapse: _moveToBack,
          onRefresh: _refreshStatus,
        ),
        const SizedBox(height: 16),
        _StatusPanel(
          enabled: _serviceEnabled,
          running: _isRunning,
          title: _statusTitle,
          text: _statusText,
          onOpenSettings: _openAccessibilitySettings,
          onPrimaryAction: _isBusy ? null : _toggleRunning,
          primaryActionLabel: _isRunning ? '停止' : '启动',
          primaryActionIcon: _isRunning
              ? Icons.stop_rounded
              : Icons.play_arrow_rounded,
          showPrimaryAction: false,
        ),
        const SizedBox(height: 16),
        _RunCard(
          isRunning: _isRunning,
          isBusy: _isBusy,
          serviceEnabled: _serviceEnabled,
          onToggleRunning: _toggleRunning,
        ),
        const SizedBox(height: 16),
        _DestinationCard(
          launchStrategy: _launchStrategy,
          selectedTargetApp: _selectedTargetApp,
          loadingTargetApps: _loadingTargetApps,
          isRunning: _isRunning,
          onStrategyChanged: _setLaunchStrategy,
          onPickTargetApp: _openTargetAppPicker,
          onRefreshApps: _loadTargetApps,
        ),
        const SizedBox(height: 16),
        _AssistCard(
          controlOverlayEnabled: _controlOverlayEnabled,
          tapAnchorVisible: _tapAnchorVisible,
          tapAnchorReady: _tapAnchorReady,
          serviceEnabled: _serviceEnabled,
          coordinateText: _anchorCoordinateText,
          onControlOverlayChanged: _setControlOverlayEnabled,
          onShowTapAnchor: _showTapAnchor,
          onHideTapAnchor: _hideTapAnchor,
        ),
        const SizedBox(height: 16),
        _ActionCard(
          actionPreset: _actionPreset,
          direction: _direction,
          isRunning: _isRunning,
          serviceEnabled: _serviceEnabled,
          tapAnchorVisible: _tapAnchorVisible,
          tapAnchorReady: _tapAnchorReady,
          anchorText: _anchorStatusText,
          compact: true,
          onActionPresetChanged: _setActionPreset,
          onDirectionChanged: _setDirection,
          onTapAnchorChanged: _toggleTapAnchorVisibility,
          onShowTapAnchor: _showTapAnchor,
          onHideTapAnchor: _hideTapAnchor,
          showAnchorControls: false,
        ),
        const SizedBox(height: 16),
        _IntervalCard(
          minInterval: _minInterval,
          maxInterval: _maxInterval,
          isRunning: _isRunning,
          onMinMinus: () => _setMinInterval(_minInterval - 0.1),
          onMinPlus: () => _setMinInterval(_minInterval + 0.1),
          onMaxMinus: () => _setMaxInterval(_maxInterval - 0.1),
          onMaxPlus: () => _setMaxInterval(_maxInterval + 0.1),
          onMinCommitted: _commitMinInterval,
          onMaxCommitted: _commitMaxInterval,
        ),
        const SizedBox(height: 16),
        _MultiTapCard(
          count: _multiTapCount,
          intervalMs: _multiTapIntervalMs.round(),
          isRunning: _isRunning,
          isActive: _actionPreset == ActionPreset.multiTap,
          onCountMinus: () =>
              _setMultiTapCount((_multiTapCount - 1).toDouble()),
          onCountPlus: () => _setMultiTapCount((_multiTapCount + 1).toDouble()),
          onIntervalMinus: () => _setMultiTapInterval(_multiTapIntervalMs - 10),
          onIntervalPlus: () => _setMultiTapInterval(_multiTapIntervalMs + 10),
          onCountCommitted: _commitMultiTapCount,
          onIntervalCommitted: _commitMultiTapInterval,
        ),
        const SizedBox(height: 16),
        _RandomCard(
          randomStrength: _randomStrength,
          randomLabel: _randomLabel,
          scatterRadiusPx: _scatterRadiusPx,
          isRunning: _isRunning,
          onRandomStrengthChanged: (value) {
            setState(() {
              _randomStrength = value;
            });
          },
          onScatterChanged: _setScatterRadius,
        ),
        const SizedBox(height: 16),
        _DebugLogCard(
          debugLoggingEnabled: _debugLoggingEnabled,
          debugLogPath: _debugLogPath,
          compact: true,
          onToggle: _setDebugLogging,
          onClear: _clearDebugLog,
          onCopy: _copyDebugLogPath,
        ),
      ],
    );
  }

  Widget _buildPadLayout(BuildContext context) {
    const canvasWidth = 1366.0;
    const canvasHeight = 1024.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(1.0, constraints.maxWidth / canvasWidth);

        return SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: canvasWidth * scale,
              height: canvasHeight * scale,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topLeft,
                child: _buildPadDesignCanvas(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPadDesignCanvas() {
    final serviceTone = _serviceEnabled
        ? const _PadTone(
            background: _AppColors.successTint,
            border: Color(0xFFA9C8BA),
            foreground: _AppColors.success,
          )
        : const _PadTone(
            background: _AppColors.warningTint,
            border: _AppColors.warningBorder,
            foreground: _AppColors.warning,
          );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _AppColors.canvas),
        child: SizedBox(
          width: 1366,
          height: 1024,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 1366,
                height: 72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _AppColors.surfaceStrong,
                    border: Border(
                      bottom: BorderSide(color: _AppColors.border),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 28,
                top: 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '随机滑屏',
                      style: TextStyle(
                        color: _AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: 12),
                    Padding(
                      padding: EdgeInsets.only(bottom: 1),
                      child: _VersionBadge(label: _appVersionLabel),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 806,
                top: 26,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isRunning
                            ? _AppColors.success
                            : serviceTone.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _serviceEnabled ? '无障碍已开启' : '无障碍未开启',
                      style: TextStyle(
                        color: serviceTone.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PadBadge(
                      label: _serviceEnabled ? '已就绪' : '待授权',
                      tone: serviceTone,
                      dense: !_serviceEnabled,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 1052,
                top: 18,
                child: _PadButton(
                  label: '打开设置',
                  width: 96,
                  height: 36,
                  onPressed: _openAccessibilitySettings,
                ),
              ),
              Positioned(
                left: 1160,
                top: 18,
                child: _PadButton(
                  label: _isRunning ? '运行中' : '启动',
                  width: 78,
                  height: 36,
                  primary: true,
                  onPressed: _isBusy || _isRunning || !_serviceEnabled
                      ? null
                      : _toggleRunning,
                ),
              ),
              Positioned(
                left: 1250,
                top: 18,
                child: _PadButton(
                  label: '停止',
                  width: 72,
                  height: 36,
                  onPressed: _isRunning && !_isBusy ? _toggleRunning : null,
                ),
              ),
              Positioned(
                left: 24,
                top: 96,
                width: 300,
                height: 880,
                child: _buildPadRunPanel(serviceTone),
              ),
              Positioned(
                left: 348,
                top: 96,
                width: 620,
                height: 648,
                child: _buildPadParametersPanel(),
              ),
              Positioned(
                left: 992,
                top: 96,
                width: 350,
                height: 648,
                child: _buildPadAssistPanel(),
              ),
              Positioned(
                left: 348,
                top: 768,
                width: 994,
                height: 208,
                child: _buildPadLogPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPadRunPanel(_PadTone serviceTone) {
    return _PadPanel(
      title: '运行',
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 58,
            width: 252,
            child: _PadStatusCallout(
              title: _serviceEnabled ? '无障碍服务已开启' : '无障碍服务未开启',
              message: _serviceEnabled
                  ? (_isRunning ? '参数已锁定，正在按随机间隔执行。' : '已就绪，启动后自动收起主界面。')
                  : '需要先授权 AccessibilityService，启动后参数会锁定。',
              tone: serviceTone,
            ),
          ),
          const Positioned(left: 24, top: 176, child: _PadSectionLabel('动作类型')),
          Positioned(
            left: 24,
            top: 198,
            width: 252,
            child: _PadSegmented<ActionPreset>(
              selected: _actionPreset,
              enabled: !_isRunning,
              choices: const [
                _PadSegmentChoice(value: ActionPreset.fling, label: '滑动'),
                _PadSegmentChoice(value: ActionPreset.tap, label: '点击'),
                _PadSegmentChoice(value: ActionPreset.multiTap, label: '连击'),
              ],
              onChanged: _setActionPreset,
            ),
          ),
          const Positioned(left: 24, top: 270, child: _PadSectionLabel('滑动方向')),
          Positioned(
            left: 24,
            top: 292,
            child: _PadChoiceButton(
              label: '向上',
              selected: _direction == SwipeDirection.up,
              enabled: !_isRunning,
              width: 118,
              onPressed: () => _setDirection(SwipeDirection.up),
            ),
          ),
          Positioned(
            left: 158,
            top: 292,
            child: _PadChoiceButton(
              label: '向下',
              selected: _direction == SwipeDirection.down,
              enabled: !_isRunning,
              width: 118,
              onPressed: () => _setDirection(SwipeDirection.down),
            ),
          ),
          const Positioned(left: 24, top: 366, child: _PadSectionLabel('运行预览')),
          Positioned(
            left: 24,
            top: 388,
            width: 252,
            height: 156,
            child: _PadPreviewBox(lines: _padPreviewLines()),
          ),
          const Positioned(
            left: 24,
            top: 702,
            width: 220,
            child: Text(
              '启动后自动收起，保留悬浮控制条。',
              style: TextStyle(
                color: _AppColors.muted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 740,
            child: _PadButton(
              label: _isRunning ? '停止运行' : '启动并切到目标 App',
              width: 252,
              height: 44,
              primary: true,
              danger: _isRunning,
              onPressed: _isBusy || (!_serviceEnabled && !_isRunning)
                  ? null
                  : _toggleRunning,
            ),
          ),
          Positioned(
            left: 24,
            top: 800,
            child: _PadButton(
              label: '打开设置',
              width: 118,
              height: 38,
              onPressed: _openAccessibilitySettings,
            ),
          ),
          Positioned(
            left: 158,
            top: 800,
            child: _PadButton(
              label: '停止',
              width: 118,
              height: 38,
              onPressed: _isRunning && !_isBusy ? _toggleRunning : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadParametersPanel() {
    final multiEnabled = _actionPreset == ActionPreset.multiTap && !_isRunning;

    return _PadPanel(
      title: '参数',
      child: Stack(
        children: [
          const Positioned(left: 0, top: 64, child: _PadDivider(width: 620)),
          const Positioned(left: 0, top: 194, child: _PadDivider(width: 620)),
          const Positioned(left: 0, top: 324, child: _PadDivider(width: 620)),
          const Positioned(left: 0, top: 454, child: _PadDivider(width: 620)),
          const Positioned(left: 28, top: 92, child: _PadFieldLabel('最小间隔')),
          const Positioned(
            left: 28,
            top: 120,
            child: _PadHintText('每次动作后的最短等待时间'),
          ),
          Positioned(
            left: 368,
            top: 88,
            child: _PadStepper(
              value: _minInterval.toStringAsFixed(1),
              unit: '秒',
              enabled: !_isRunning,
              onMinus: () => _setMinInterval(_minInterval - 0.1),
              onPlus: () => _setMinInterval(_minInterval + 0.1),
              onSubmitted: _commitMinInterval,
            ),
          ),
          const Positioned(left: 28, top: 222, child: _PadFieldLabel('最大间隔')),
          const Positioned(
            left: 28,
            top: 250,
            child: _PadHintText('随机等待不会超过该值'),
          ),
          Positioned(
            left: 368,
            top: 218,
            child: _PadStepper(
              value: _maxInterval.toStringAsFixed(1),
              unit: '秒',
              enabled: !_isRunning,
              onMinus: () => _setMaxInterval(_maxInterval - 0.1),
              onPlus: () => _setMaxInterval(_maxInterval + 0.1),
              onSubmitted: _commitMaxInterval,
            ),
          ),
          Positioned(
            left: 28,
            top: 290,
            width: 524,
            height: 28,
            child: _PadRangeTrack(
              min: 1,
              max: 60,
              start: _minInterval,
              end: _maxInterval,
            ),
          ),
          const Positioned(left: 28, top: 352, child: _PadFieldLabel('随机强度')),
          const Positioned(
            left: 28,
            top: 380,
            child: _PadHintText('控制停顿和落点抖动，避免机械重复'),
          ),
          Positioned(
            left: 482,
            top: 352,
            child: Text(
              _randomLabel,
              style: const TextStyle(
                color: _AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 406,
            width: 544,
            child: _PadSlider(
              value: _randomStrength,
              enabled: !_isRunning,
              onChanged: (value) {
                setState(() {
                  _randomStrength = value;
                });
              },
            ),
          ),
          const Positioned(left: 28, top: 482, child: _PadFieldLabel('连击参数')),
          const Positioned(
            left: 28,
            top: 510,
            child: _PadHintText('仅在连击模式下启用'),
          ),
          const Positioned(left: 304, top: 482, child: _PadSectionLabel('次数')),
          Positioned(
            left: 360,
            top: 470,
            width: 74,
            height: 34,
            child: _PadInputBox(
              value: '$_multiTapCount',
              unit: '次',
              enabled: multiEnabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: _commitMultiTapCount,
            ),
          ),
          const Positioned(left: 304, top: 538, child: _PadSectionLabel('间隔')),
          Positioned(
            left: 360,
            top: 526,
            width: 88,
            height: 34,
            child: _PadInputBox(
              value: '${_multiTapIntervalMs.round()}',
              unit: 'ms',
              enabled: multiEnabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: _commitMultiTapInterval,
            ),
          ),
          const Positioned(left: 28, top: 586, child: _PadFieldLabel('点击锚点')),
          Positioned(
            left: 472,
            top: 578,
            child: _PadSwitch(
              value: _tapAnchorVisible,
              onChanged: _serviceEnabled ? _toggleTapAnchorVisibility : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadAssistPanel() {
    return _PadPanel(
      title: '辅助',
      child: Stack(
        children: [
          const Positioned(left: 0, top: 64, child: _PadDivider(width: 350)),
          const Positioned(left: 0, top: 198, child: _PadDivider(width: 350)),
          const Positioned(left: 0, top: 420, child: _PadDivider(width: 350)),
          const Positioned(left: 28, top: 92, child: _PadFieldLabel('去向')),
          Positioned(
            left: 28,
            top: 122,
            child: _PadChoiceButton(
              label: '上一个',
              width: 108,
              selected: _launchStrategy == LaunchStrategy.previousApp,
              enabled: !_isRunning,
              onPressed: () => _setLaunchStrategy(LaunchStrategy.previousApp),
            ),
          ),
          Positioned(
            left: 146,
            top: 122,
            child: _PadChoiceButton(
              label: _selectedTargetApp == null ? '指定 App' : '更换 App',
              width: 112,
              selected: _launchStrategy == LaunchStrategy.selectedApp,
              enabled: !_isRunning,
              onPressed: _openTargetAppPicker,
            ),
          ),
          Positioned(
            left: 28,
            top: 166,
            width: 268,
            child: Text(
              _launchDestinationDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppColors.muted,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Positioned(left: 28, top: 224, child: _PadFieldLabel('小窗口')),
          Positioned(
            left: 260,
            top: 222,
            child: _PadSwitch(
              value: _controlOverlayEnabled,
              onChanged: _setControlOverlayEnabled,
            ),
          ),
          Positioned(
            left: 28,
            top: 282,
            width: 292,
            height: 40,
            child: _PadInfoBox(
              text: _controlOverlayEnabled
                  ? '运行时悬浮：暂停 / 停止 / 收起'
                  : '小窗口已关闭，运行时不显示悬浮条',
            ),
          ),
          const Positioned(
            left: 236,
            top: 342,
            child: _PadFloatingControlPreview(),
          ),
          Positioned(
            left: 28,
            top: 344,
            child: _PadButton(
              label: '靠左',
              width: 92,
              height: 34,
              onPressed: _controlOverlayEnabled
                  ? () => _snapControlOverlay('left')
                  : null,
            ),
          ),
          Positioned(
            left: 132,
            top: 344,
            child: _PadButton(
              label: '靠右',
              width: 92,
              height: 34,
              onPressed: _controlOverlayEnabled
                  ? () => _snapControlOverlay('right')
                  : null,
            ),
          ),
          const Positioned(left: 28, top: 444, child: _PadFieldLabel('标靶')),
          Positioned(
            left: 188,
            top: 442,
            child: _PadCoordinateBadge(x: _tapAnchorX, y: _tapAnchorY),
          ),
          const Positioned(
            left: 28,
            top: 492,
            width: 292,
            height: 86,
            child: _PadTargetPreview(),
          ),
          Positioned(
            left: 28,
            top: 590,
            child: _PadButton(
              label: _tapAnchorVisible ? '显示标靶' : '显示标靶',
              width: 92,
              height: 34,
              onPressed: _serviceEnabled ? _showTapAnchor : null,
            ),
          ),
          Positioned(
            left: 132,
            top: 590,
            child: _PadButton(
              label: '校准位置',
              width: 116,
              height: 34,
              onPressed: _serviceEnabled ? _showTapAnchor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadLogPanel() {
    return _PadPanel(
      title: '调试日志',
      child: Stack(
        children: [
          const Positioned(left: 0, top: 64, child: _PadDivider(width: 994)),
          const Positioned(
            left: 134,
            top: 28,
            child: Text(
              '手动开启',
              style: TextStyle(
                color: _AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 204,
            top: 20,
            child: _PadSwitch(
              value: _debugLoggingEnabled,
              onChanged: _setDebugLogging,
            ),
          ),
          Positioned(
            left: 268,
            top: 23,
            child: _LogStateBadge(enabled: _debugLoggingEnabled),
          ),
          Positioned(
            left: 28,
            top: 88,
            width: 720,
            child: Text(
              '关闭时不写入日志，避免长期运行生成大文件。路径：${_debugLogPath.isEmpty ? '/data/user/0/.../debug.log' : _debugLogPath}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppColors.muted,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            left: 28,
            top: 118,
            width: 734,
            height: 64,
            child: _PadLogBox(debugLoggingEnabled: _debugLoggingEnabled),
          ),
          Positioned(
            left: 800,
            top: 118,
            child: _PadButton(
              label: '清空',
              width: 82,
              height: 36,
              onPressed: _clearDebugLog,
            ),
          ),
          Positioned(
            left: 894,
            top: 118,
            child: _PadButton(
              label: '复制',
              width: 82,
              height: 36,
              onPressed: _copyDebugLogPath,
            ),
          ),
        ],
      ),
    );
  }

  List<_PadPreviewLine> _padPreviewLines() {
    final actionText = switch (_actionPreset) {
      ActionPreset.fling =>
        _direction == SwipeDirection.up ? '动作：向上滑动' : '动作：向下滑动',
      ActionPreset.tap => '动作：点击',
      ActionPreset.multiTap => '动作：连击',
    };

    return [
      _PadPreviewLine(actionText),
      _PadPreviewLine(
        '间隔：${_minInterval.toStringAsFixed(1)} - ${_maxInterval.toStringAsFixed(1)} 秒',
      ),
      _PadPreviewLine('随机：$_randomLabel模式，散点 ${_scatterRadiusPx.round()} px'),
      _PadPreviewLine(
        '连击：$_multiTapCount 次，每次间隔 ${_multiTapIntervalMs.round()} ms',
        muted: _actionPreset != ActionPreset.multiTap,
      ),
    ];
  }

  void _setActionPreset(ActionPreset preset) {
    if (_isRunning) {
      return;
    }
    setState(() {
      _actionPreset = preset;
    });
  }

  void _setDirection(SwipeDirection direction) {
    if (_isRunning) {
      return;
    }
    setState(() {
      _direction = direction;
    });
  }

  void _setLaunchStrategy(LaunchStrategy strategy) {
    if (_isRunning) {
      return;
    }
    setState(() {
      _launchStrategy = strategy;
    });
    _saveLaunchPreferences();
    if (strategy == LaunchStrategy.selectedApp && _targetApps.isEmpty) {
      _loadTargetApps();
    }
  }

  String get _launchDestinationDescription {
    if (_launchStrategy == LaunchStrategy.selectedApp) {
      return _selectedTargetApp == null
          ? '指定 App 只在“去向”里选择，标靶只负责位置校准。'
          : '启动后打开：${_selectedTargetApp!.label}';
    }
    return _launchStrategy.description;
  }

  String get _statusTitle {
    if (_isRunning) {
      return '随机动作运行中';
    }
    if (_serviceEnabled) {
      return '无障碍服务已开启';
    }
    return '无障碍未开启';
  }

  String get _randomLabel {
    if (_randomStrength < 0.25) {
      return '轻微';
    }
    if (_randomStrength < 0.75) {
      return '像真人';
    }
    return '更随机';
  }

  String get _anchorStatusText {
    if (!_serviceEnabled) {
      return '开启无障碍服务后，可以显示并拖动锚点。';
    }
    if (_tapAnchorReady && _tapAnchorX != null && _tapAnchorY != null) {
      return '坐标 ${_tapAnchorX!.round()} · ${_tapAnchorY!.round()}，点击和连击优先使用这个位置。';
    }
    return '尚未选择坐标，点击和连击会使用屏幕安全区域。';
  }

  String get _anchorCoordinateText {
    if (_tapAnchorReady && _tapAnchorX != null && _tapAnchorY != null) {
      return 'x ${_tapAnchorX!.round()} · y ${_tapAnchorY!.round()}';
    }
    return 'x 512 · y 948';
  }

  TargetApp? _targetAppForPackage(String? packageName) {
    if (packageName == null) {
      return null;
    }
    for (final app in _targetApps) {
      if (app.packageName == packageName) {
        return app;
      }
    }
    return null;
  }
}

enum SwipeDirection { up, down }

enum LaunchStrategy {
  previousApp,
  selectedApp;

  static LaunchStrategy fromName(String? value) {
    for (final strategy in values) {
      if (strategy.name == value) {
        return strategy;
      }
    }
    return LaunchStrategy.previousApp;
  }

  String get description {
    switch (this) {
      case LaunchStrategy.previousApp:
        return '启动后收起主界面，回到刚才使用的应用或桌面。';
      case LaunchStrategy.selectedApp:
        return '启动后自动打开你选择的目标 App，再由无障碍服务执行随机动作。';
    }
  }
}

class TargetApp {
  const TargetApp({required this.label, required this.packageName});

  factory TargetApp.fromMap(Map<dynamic, dynamic> map) {
    return TargetApp(
      label: map['label']?.toString() ?? '',
      packageName: map['packageName']?.toString() ?? '',
    );
  }

  final String label;
  final String packageName;
}

enum ActionPreset {
  fling,
  tap,
  multiTap;

  String get description {
    switch (this) {
      case ActionPreset.fling:
        return '点住后快速划一下，靠惯性滚动，适合刷短视频。';
      case ActionPreset.tap:
        return '默认在安全区域点击一次，设置锚点后会点击指定位置。';
      case ActionPreset.multiTap:
        return '按设置的次数和间隔连续点击，设置锚点后会连击指定位置。';
    }
  }
}

class _AppColors {
  static const canvas = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFAFAFB);
  static const surfaceStrong = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF6F7F9);
  static const border = Color(0xFFD7DDE8);
  static const borderStrong = Color(0xFFC7D0DE);
  static const text = Color(0xFF171821);
  static const muted = Color(0xFF687083);
  static const faint = Color(0xFF8D96A8);
  static const primary = Color(0xFF405AA8);
  static const primaryTint = Color(0xFFEEF2FF);
  static const success = Color(0xFF2F5E4E);
  static const successTint = Color(0xFFEAF3EF);
  static const warning = Color(0xFFA14A22);
  static const warningTint = Color(0xFFFFF6ED);
  static const warningBorder = Color(0xFFEAD5C8);
  static const danger = Color(0xFFB42318);
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.compact,
    required this.onCollapse,
    required this.onRefresh,
  });

  final bool compact;
  final VoidCallback onCollapse;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final title = compact ? '随机滑屏' : '随机滑屏 · Pad 单页控制台';
    final subtitle = 'Pad 横屏采用双栏加侧栏：主要参数始终可见，命令按钮收进右上与状态区。';

    if (compact) {
      return SizedBox(
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _VersionBadge(label: _appVersionLabel, compact: true),
            ),
            const Spacer(),
            _HeaderTextButton(label: '收起', onPressed: onCollapse),
            const SizedBox(width: 2),
            _HeaderTextButton(label: '刷新', onPressed: onRefresh),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const _VersionBadge(label: _appVersionLabel),
            const SizedBox(width: 14),
            Text(
              subtitle,
              style: const TextStyle(
                color: _AppColors.faint,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 20 : 28,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        border: Border.all(color: _AppColors.borderStrong),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _AppColors.muted,
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _HeaderTextButton extends StatelessWidget {
  const _HeaderTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: _AppColors.muted,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.enabled,
    required this.running,
    required this.title,
    required this.text,
    required this.onOpenSettings,
    required this.onPrimaryAction,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    this.showPrimaryAction = true,
  });

  final bool enabled;
  final bool running;
  final String title;
  final String text;
  final VoidCallback onOpenSettings;
  final VoidCallback? onPrimaryAction;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final bool showPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final spec = _statusSpec(enabled: enabled, running: running);

    return _PanelSurface(
      fill: spec.fill,
      borderColor: spec.border,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final statusText = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(spec.icon, size: compact ? 18 : 34, color: spec.foreground),
              SizedBox(width: compact ? 10 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _AppColors.text,
                        fontSize: compact ? 14 : 27,
                        fontWeight: compact ? FontWeight.w700 : FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      text,
                      maxLines: compact ? 1 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                        color: _AppColors.muted,
                        fontSize: compact ? 11 : 17,
                        height: compact ? 1.35 : 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final buttons = Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _OutlineCommandButton(
                label: '设置',
                icon: Icons.settings_accessibility_rounded,
                onPressed: onOpenSettings,
                minWidth: compact ? 92 : 112,
              ),
              if (showPrimaryAction)
                _PrimaryCommandButton(
                  label: primaryActionLabel,
                  icon: primaryActionIcon,
                  onPressed: onPrimaryAction,
                  minWidth: compact ? 92 : 112,
                  danger: running,
                ),
            ],
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: statusText),
                const SizedBox(width: 10),
                _OutlineCommandButton(
                  label: '设置',
                  icon: Icons.settings_accessibility_rounded,
                  onPressed: onOpenSettings,
                  minWidth: 72,
                  compact: true,
                  iconOnlyOnCompact: true,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: statusText),
              const SizedBox(width: 24),
              buttons,
            ],
          );
        },
      ),
    );
  }

  _StatusVisualSpec _statusSpec({
    required bool enabled,
    required bool running,
  }) {
    if (running) {
      return const _StatusVisualSpec(
        fill: _AppColors.successTint,
        border: Color(0xFFA9C8BA),
        foreground: _AppColors.success,
        icon: Icons.play_circle_fill_rounded,
      );
    }
    if (enabled) {
      return const _StatusVisualSpec(
        fill: Color(0xFFF1F7FF),
        border: Color(0xFFC9D8F4),
        foreground: _AppColors.primary,
        icon: Icons.verified_rounded,
      );
    }
    return const _StatusVisualSpec(
      fill: _AppColors.warningTint,
      border: _AppColors.warningBorder,
      foreground: _AppColors.warning,
      icon: Icons.priority_high_rounded,
    );
  }
}

class _StatusVisualSpec {
  const _StatusVisualSpec({
    required this.fill,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color fill;
  final Color border;
  final Color foreground;
  final IconData icon;
}

class _PadTone {
  const _PadTone({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

class _PadPanel extends StatelessWidget {
  const _PadPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E3E8)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              left: 24,
              top: 28,
              child: Text(
                title,
                style: const TextStyle(
                  color: _AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PadDivider extends StatelessWidget {
  const _PadDivider({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 1,
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFFEEF0F3)),
      ),
    );
  }
}

class _PadBadge extends StatelessWidget {
  const _PadBadge({
    required this.label,
    required this.tone,
    this.dense = false,
  });

  final String label;
  final _PadTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tone.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone.foreground,
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _LogStateBadge extends StatelessWidget {
  const _LogStateBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? _AppColors.successTint : _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: enabled ? const Color(0xFFA9C8BA) : _AppColors.border,
        ),
      ),
      child: Text(
        enabled ? '已开启' : '默认关闭',
        style: TextStyle(
          color: enabled ? _AppColors.success : _AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.label,
    required this.width,
    required this.height,
    this.primary = false,
    this.danger = false,
    this.onPressed,
  });

  final String label;
  final double width;
  final double height;
  final bool primary;
  final bool danger;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fill = primary
        ? (danger ? _AppColors.danger : _AppColors.success)
        : _AppColors.surfaceStrong;
    final foreground = primary ? _AppColors.surfaceStrong : _AppColors.text;
    final border = primary ? fill : _AppColors.borderStrong;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? fill : _AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: enabled ? border : _AppColors.border),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enabled ? foreground : _AppColors.faint,
              fontSize: height <= 34 ? 13 : 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PadStatusCallout extends StatelessWidget {
  const _PadStatusCallout({
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String message;
  final _PadTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tone.foreground,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF74695E),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PadSectionLabel extends StatelessWidget {
  const _PadSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _PadFieldLabel extends StatelessWidget {
  const _PadFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF252B33),
        fontSize: 15,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _PadHintText extends StatelessWidget {
  const _PadHintText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF7A828C),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1,
      ),
    );
  }
}

class _PadSegmentChoice<T> {
  const _PadSegmentChoice({required this.value, required this.label});

  final T value;
  final String label;
}

class _PadSegmented<T> extends StatelessWidget {
  const _PadSegmented({
    required this.selected,
    required this.choices,
    required this.onChanged,
    this.enabled = true,
  });

  final T selected;
  final List<_PadSegmentChoice<T>> choices;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: choices.map((choice) {
          final active = choice.value == selected;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? () => onChanged(choice.value) : null,
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? _AppColors.surfaceStrong
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: active
                          ? Border.all(color: _AppColors.borderStrong)
                          : null,
                    ),
                    child: Text(
                      choice.label,
                      style: TextStyle(
                        color: active ? _AppColors.text : _AppColors.muted,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PadChoiceButton extends StatelessWidget {
  const _PadChoiceButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.width,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: width,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _AppColors.successTint : _AppColors.surfaceStrong,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? const Color(0xFF7AA392) : _AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF285B49)
                  : const Color(0xFF38414A),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PadPreviewLine {
  const _PadPreviewLine(this.text, {this.muted = false});

  final String text;
  final bool muted;
}

class _PadPreviewBox extends StatelessWidget {
  const _PadPreviewBox({required this.lines});

  final List<_PadPreviewLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E3E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) ...[
            Text(
              line.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: line.muted ? _AppColors.muted : _AppColors.text,
                fontSize: line.muted ? 12 : 13,
                fontWeight: line.muted ? FontWeight.w500 : FontWeight.w800,
                height: 1,
              ),
            ),
            if (line != lines.last) const SizedBox(height: 21),
          ],
        ],
      ),
    );
  }
}

class _PadStepper extends StatelessWidget {
  const _PadStepper({
    required this.value,
    required this.unit,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
    required this.onSubmitted,
  });

  final String value;
  final String unit;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PadStepButton(label: '-', enabled: enabled, onPressed: onMinus),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          height: 34,
          child: _PadInputBox(
            value: value,
            unit: unit,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [],
            onSubmitted: onSubmitted,
          ),
        ),
        const SizedBox(width: 12),
        _PadStepButton(label: '+', enabled: enabled, onPressed: onPlus),
      ],
    );
  }
}

class _PadStepButton extends StatelessWidget {
  const _PadStepButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? _AppColors.text : _AppColors.faint,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PadInputBox extends StatelessWidget {
  const _PadInputBox({
    required this.value,
    required this.unit,
    required this.enabled,
    required this.keyboardType,
    required this.inputFormatters,
    required this.onSubmitted,
  });

  final String value;
  final String unit;
  final bool enabled;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('pad-$unit-$value'),
      initialValue: value,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
      decoration: InputDecoration(
        suffixText: unit,
        suffixStyle: const TextStyle(
          color: _AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
        filled: true,
        fillColor: _AppColors.surfaceStrong,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: Color(0xFFB7C1CC)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _AppColors.border),
        ),
      ),
      onFieldSubmitted: onSubmitted,
    );
  }
}

class _PadRangeTrack extends StatelessWidget {
  const _PadRangeTrack({
    required this.min,
    required this.max,
    required this.start,
    required this.end,
  });

  final double min;
  final double max;
  final double start;
  final double end;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final startX = ((start - min) / (max - min)).clamp(0.0, 1.0) * width;
        final endX = ((end - min) / (max - min)).clamp(0.0, 1.0) * width;
        final activeStart = math.min(startX, endX);
        final activeWidth = (endX - startX).abs();

        return Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DDE5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: activeStart,
              width: activeWidth,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _AppColors.success,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(left: startX - 9, child: const _PadTrackKnob()),
            Positioned(left: endX - 9, child: const _PadTrackKnob()),
          ],
        );
      },
    );
  }
}

class _PadTrackKnob extends StatelessWidget {
  const _PadTrackKnob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        color: _AppColors.success,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PadSlider extends StatelessWidget {
  const _PadSlider({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: _AppColors.success,
        inactiveTrackColor: const Color(0xFFD8DDE5),
        thumbColor: _AppColors.success,
        overlayColor: _AppColors.success.withAlpha(18),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      child: Slider(
        value: value,
        min: 0,
        max: 1,
        divisions: 10,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _PadSwitch extends StatelessWidget {
  const _PadSwitch({required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.78,
      alignment: Alignment.center,
      child: Switch(
        value: value,
        activeThumbColor: _AppColors.surfaceStrong,
        activeTrackColor: _AppColors.success,
        inactiveThumbColor: _AppColors.surfaceStrong,
        inactiveTrackColor: const Color(0xFFDDE2EA),
        onChanged: onChanged,
      ),
    );
  }
}

class _PadInfoBox extends StatelessWidget {
  const _PadInfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _AppColors.border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

class _PadFloatingControlPreview extends StatelessWidget {
  const _PadFloatingControlPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: Container(
              width: 84,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF263238),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Text(
                '暂停   停止',
                style: TextStyle(
                  color: _AppColors.surfaceStrong,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF7AA392),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PadCoordinateBadge extends StatelessWidget {
  const _PadCoordinateBadge({required this.x, required this.y});

  final double? x;
  final double? y;

  @override
  Widget build(BuildContext context) {
    final text = x == null || y == null
        ? 'x 512 · y 948'
        : 'x ${x!.round()} · y ${y!.round()}';
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC9D8F4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF3B4B69),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _PadTargetPreview extends StatelessWidget {
  const _PadTargetPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 88, 16),
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E3E8)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Text(
            '用于选择点击点，或校准滑动起止位置。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _AppColors.muted,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          Positioned(
            right: -72,
            top: 8,
            child: CustomPaint(
              size: Size(52, 52),
              painter: _PadTargetPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PadTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _AppColors.success
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 16, paint..strokeWidth = 3);
    paint.strokeWidth = 2;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PadLogBox extends StatelessWidget {
  const _PadLogBox({required this.debugLoggingEnabled});

  final bool debugLoggingEnabled;

  @override
  Widget build(BuildContext context) {
    final firstLine = debugLoggingEnabled
        ? '2026-05-17 03:42:10  action=swipe  interval=3.4s  direction=up'
        : '日志未开启，打开小窗口日志后会显示最新事件';
    final secondLine = debugLoggingEnabled
        ? '2026-05-17 03:42:14  random=human  scatter=10px  result=sent'
        : '路径可复制到调试工具中查看';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE0E3E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF47515D),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            secondLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.actionPreset,
    required this.direction,
    required this.isRunning,
    required this.serviceEnabled,
    required this.tapAnchorVisible,
    required this.tapAnchorReady,
    required this.anchorText,
    required this.compact,
    required this.onActionPresetChanged,
    required this.onDirectionChanged,
    required this.onTapAnchorChanged,
    required this.onShowTapAnchor,
    required this.onHideTapAnchor,
    this.showAnchorControls = true,
  });

  final ActionPreset actionPreset;
  final SwipeDirection direction;
  final bool isRunning;
  final bool serviceEnabled;
  final bool tapAnchorVisible;
  final bool tapAnchorReady;
  final String anchorText;
  final bool compact;
  final ValueChanged<ActionPreset> onActionPresetChanged;
  final ValueChanged<SwipeDirection> onDirectionChanged;
  final ValueChanged<bool> onTapAnchorChanged;
  final VoidCallback onShowTapAnchor;
  final VoidCallback onHideTapAnchor;
  final bool showAnchorControls;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '动作',
      subtitle: '选择动作类型，运行后锁定。',
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChoicePillGroup<ActionPreset>(
            selected: actionPreset,
            enabled: !isRunning,
            choices: const [
              _ChoiceItem(
                value: ActionPreset.fling,
                label: '滑动',
                icon: Icons.swipe_vertical_rounded,
              ),
              _ChoiceItem(
                value: ActionPreset.tap,
                label: '点击',
                icon: Icons.touch_app_rounded,
              ),
              _ChoiceItem(
                value: ActionPreset.multiTap,
                label: '连击',
                icon: Icons.ads_click_rounded,
              ),
            ],
            onChanged: onActionPresetChanged,
          ),
          const SizedBox(height: 14),
          _DescriptionBox(text: actionPreset.description),
          const SizedBox(height: 16),
          _InlineControlRow(
            label: '方向',
            child: _ChoicePillGroup<SwipeDirection>(
              selected: direction,
              enabled: !isRunning,
              compact: true,
              choices: const [
                _ChoiceItem(
                  value: SwipeDirection.up,
                  label: '向上',
                  icon: Icons.arrow_upward_rounded,
                ),
                _ChoiceItem(
                  value: SwipeDirection.down,
                  label: '向下',
                  icon: Icons.arrow_downward_rounded,
                ),
              ],
              onChanged: onDirectionChanged,
            ),
          ),
          if (showAnchorControls) ...[
            const SizedBox(height: 14),
            _InlineControlRow(
              label: '锚点',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Switch(
                    value: tapAnchorVisible,
                    activeThumbColor: _AppColors.primary,
                    onChanged: serviceEnabled ? onTapAnchorChanged : null,
                  ),
                  if (!compact) ...[
                    _OutlineCommandButton(
                      label: tapAnchorVisible ? '刷新' : '显示',
                      icon: Icons.my_location_rounded,
                      onPressed: serviceEnabled ? onShowTapAnchor : null,
                      minWidth: 82,
                      compact: true,
                    ),
                    const SizedBox(width: 8),
                    _OutlineCommandButton(
                      label: '隐藏',
                      icon: Icons.visibility_off_rounded,
                      onPressed: tapAnchorVisible ? onHideTapAnchor : null,
                      minWidth: 82,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tapAnchorReady ? anchorText : anchorText,
              style: const TextStyle(
                color: _AppColors.muted,
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (compact) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _OutlineCommandButton(
                    label: tapAnchorVisible ? '刷新标靶' : '显示标靶',
                    icon: Icons.my_location_rounded,
                    onPressed: serviceEnabled ? onShowTapAnchor : null,
                    minWidth: 112,
                    compact: true,
                  ),
                  _OutlineCommandButton(
                    label: '隐藏',
                    icon: Icons.visibility_off_rounded,
                    onPressed: tapAnchorVisible ? onHideTapAnchor : null,
                    minWidth: 88,
                    compact: true,
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            Text(
              '方向',
              style: const TextStyle(
                color: _AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              direction == SwipeDirection.up ? '向上' : '向下',
              style: const TextStyle(
                color: _AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({
    required this.isRunning,
    required this.isBusy,
    required this.serviceEnabled,
    required this.onToggleRunning,
  });

  final bool isRunning;
  final bool isBusy;
  final bool serviceEnabled;
  final VoidCallback onToggleRunning;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '运行',
      subtitle: '启动后按“去向”进入目标应用',
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PrimaryCommandButton(
                  label: '启动',
                  icon: Icons.play_arrow_rounded,
                  onPressed: isBusy || isRunning || !serviceEnabled
                      ? null
                      : onToggleRunning,
                  minWidth: 148,
                  compact: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _OutlineCommandButton(
                  label: '停止',
                  icon: Icons.stop_rounded,
                  onPressed: isBusy || !isRunning ? null : onToggleRunning,
                  minWidth: 148,
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntervalCard extends StatelessWidget {
  const _IntervalCard({
    required this.minInterval,
    required this.maxInterval,
    required this.isRunning,
    required this.onMinMinus,
    required this.onMinPlus,
    required this.onMaxMinus,
    required this.onMaxPlus,
    required this.onMinCommitted,
    required this.onMaxCommitted,
  });

  final double minInterval;
  final double maxInterval;
  final bool isRunning;
  final VoidCallback onMinMinus;
  final VoidCallback onMinPlus;
  final VoidCallback onMaxMinus;
  final VoidCallback onMaxPlus;
  final ValueChanged<String> onMinCommitted;
  final ValueChanged<String> onMaxCommitted;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '间隔',
      subtitle: '可点数值输入，步进 0.1 秒。滑条只反馈当前范围。',
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ValueStepper(
            label: '最小间隔',
            value: minInterval.toStringAsFixed(1),
            unit: '秒',
            enabled: !isRunning,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [],
            onMinus: onMinMinus,
            onPlus: onMinPlus,
            onSubmitted: onMinCommitted,
          ),
          const SizedBox(height: 14),
          _ValueStepper(
            label: '最大间隔',
            value: maxInterval.toStringAsFixed(1),
            unit: '秒',
            enabled: !isRunning,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [],
            onMinus: onMaxMinus,
            onPlus: onMaxPlus,
            onSubmitted: onMaxCommitted,
          ),
          const SizedBox(height: 18),
          _RangeBar(min: 1, max: 60, start: minInterval, end: maxInterval),
          const SizedBox(height: 16),
          _ChoicePillGroup<String>(
            selected: _intervalPresetLabel(minInterval, maxInterval),
            enabled: false,
            compact: true,
            choices: const [
              _ChoiceItem(value: '快', label: '快'),
              _ChoiceItem(value: '像真人', label: '像真人'),
              _ChoiceItem(value: '慢', label: '慢'),
              _ChoiceItem(value: '自定义', label: '自定义'),
            ],
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }

  String _intervalPresetLabel(double minInterval, double maxInterval) {
    if (minInterval == 3 && maxInterval == 8) {
      return '像真人';
    }
    if (maxInterval <= 4) {
      return '快';
    }
    if (minInterval >= 8) {
      return '慢';
    }
    return '自定义';
  }
}

class _MultiTapCard extends StatelessWidget {
  const _MultiTapCard({
    required this.count,
    required this.intervalMs,
    required this.isRunning,
    required this.isActive,
    required this.onCountMinus,
    required this.onCountPlus,
    required this.onIntervalMinus,
    required this.onIntervalPlus,
    required this.onCountCommitted,
    required this.onIntervalCommitted,
  });

  final int count;
  final int intervalMs;
  final bool isRunning;
  final bool isActive;
  final VoidCallback onCountMinus;
  final VoidCallback onCountPlus;
  final VoidCallback onIntervalMinus;
  final VoidCallback onIntervalPlus;
  final ValueChanged<String> onCountCommitted;
  final ValueChanged<String> onIntervalCommitted;

  @override
  Widget build(BuildContext context) {
    final enabled = isActive && !isRunning;

    return _SectionCard(
      title: '连击参数',
      subtitle: '仅在“连击”模式生效',
      muted: !isActive,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ValueStepper(
            label: '次数',
            value: '$count',
            unit: '次',
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onMinus: onCountMinus,
            onPlus: onCountPlus,
            onSubmitted: onCountCommitted,
          ),
          const SizedBox(height: 14),
          _ValueStepper(
            label: '连击间隔',
            value: '$intervalMs',
            unit: 'ms',
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onMinus: onIntervalMinus,
            onPlus: onIntervalPlus,
            onSubmitted: onIntervalCommitted,
          ),
        ],
      ),
    );
  }
}

class _RandomCard extends StatelessWidget {
  const _RandomCard({
    required this.randomStrength,
    required this.randomLabel,
    required this.scatterRadiusPx,
    required this.isRunning,
    required this.onRandomStrengthChanged,
    required this.onScatterChanged,
  });

  final double randomStrength;
  final String randomLabel;
  final double scatterRadiusPx;
  final bool isRunning;
  final ValueChanged<double> onRandomStrengthChanged;
  final ValueChanged<double> onScatterChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '随机与落点',
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderHeader(title: '随机强度', value: randomLabel),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _AppColors.primary,
              inactiveTrackColor: const Color(0xFFE3E7EF),
              thumbColor: _AppColors.primary,
              overlayColor: _AppColors.primary.withAlpha(22),
            ),
            child: Slider(
              value: randomStrength,
              min: 0,
              max: 1,
              divisions: 10,
              label: randomLabel,
              onChanged: isRunning ? null : onRandomStrengthChanged,
            ),
          ),
          const SizedBox(height: 8),
          _SliderHeader(title: '散点半径', value: '${scatterRadiusPx.round()} px'),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _AppColors.primary,
              inactiveTrackColor: const Color(0xFFE3E7EF),
              thumbColor: _AppColors.primary,
              overlayColor: _AppColors.primary.withAlpha(22),
            ),
            child: Slider(
              value: scatterRadiusPx,
              min: 0,
              max: 50,
              divisions: 50,
              label: '${scatterRadiusPx.round()} px',
              onChanged: isRunning ? null : onScatterChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistCard extends StatelessWidget {
  const _AssistCard({
    required this.controlOverlayEnabled,
    required this.tapAnchorVisible,
    required this.tapAnchorReady,
    required this.serviceEnabled,
    required this.coordinateText,
    required this.onControlOverlayChanged,
    required this.onShowTapAnchor,
    required this.onHideTapAnchor,
  });

  final bool controlOverlayEnabled;
  final bool tapAnchorVisible;
  final bool tapAnchorReady;
  final bool serviceEnabled;
  final String coordinateText;
  final ValueChanged<bool> onControlOverlayChanged;
  final VoidCallback onShowTapAnchor;
  final VoidCallback onHideTapAnchor;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '运行辅助',
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 72, child: _ControlLabel('小窗口')),
              const Expanded(
                child: Text(
                  '暂停 / 停止 / 收起',
                  style: TextStyle(
                    color: _AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: controlOverlayEnabled,
                activeThumbColor: _AppColors.surfaceStrong,
                activeTrackColor: _AppColors.success,
                onChanged: onControlOverlayChanged,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 72, child: _ControlLabel('点击标靶')),
              const Expanded(
                child: Text(
                  '校准点击点和滑动起止点',
                  style: TextStyle(
                    color: _AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const _PadTargetMiniPreview(size: 42),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              _CoordinateChip(text: coordinateText, active: tapAnchorReady),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OutlineCommandButton(
                label: tapAnchorVisible ? '校准位置' : '显示标靶',
                icon: Icons.my_location_rounded,
                onPressed: serviceEnabled ? onShowTapAnchor : null,
                minWidth: 112,
                compact: true,
              ),
              _OutlineCommandButton(
                label: '隐藏',
                icon: Icons.visibility_off_rounded,
                onPressed: tapAnchorVisible ? onHideTapAnchor : null,
                minWidth: 86,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadTargetMiniPreview extends StatelessWidget {
  const _PadTargetMiniPreview({this.size = 54});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PadTargetPainter()),
    );
  }
}

class _CoordinateChip extends StatelessWidget {
  const _CoordinateChip({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF1F7FF) : _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active ? const Color(0xFFC9D8F4) : _AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF3B4B69),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _DebugLogCard extends StatelessWidget {
  const _DebugLogCard({
    required this.debugLoggingEnabled,
    required this.debugLogPath,
    required this.compact,
    required this.onToggle,
    required this.onClear,
    required this.onCopy,
  });

  final bool debugLoggingEnabled;
  final String debugLogPath;
  final bool compact;
  final ValueChanged<bool> onToggle;
  final VoidCallback onClear;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: compact ? '调试日志' : '完整调试区',
      subtitle: compact ? null : '保留日志开关、路径、清空与复制。Pad 上横向展开，手机上压缩到底部。',
      trailing: Switch(
        value: debugLoggingEnabled,
        activeThumbColor: _AppColors.primary,
        onChanged: onToggle,
      ),
      padding: compact
          ? const EdgeInsets.fromLTRB(20, 20, 20, 18)
          : const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PathBox(path: debugLogPath),
          const SizedBox(height: 12),
          if (!compact)
            _DescriptionBox(
              text:
                  '2026-05-17  action=${debugLoggingEnabled ? 'logging enabled' : 'logging paused'}  interval path ready',
            ),
          if (!compact) const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OutlineCommandButton(
                label: compact ? '清空' : '清空日志',
                icon: Icons.delete_sweep_rounded,
                onPressed: onClear,
                minWidth: compact ? 74 : 104,
                compact: true,
              ),
              _OutlineCommandButton(
                label: compact ? '复制' : '复制路径',
                icon: Icons.copy_rounded,
                onPressed: onCopy,
                minWidth: compact ? 74 : 104,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.launchStrategy,
    required this.selectedTargetApp,
    required this.loadingTargetApps,
    required this.isRunning,
    required this.onStrategyChanged,
    required this.onPickTargetApp,
    required this.onRefreshApps,
  });

  final LaunchStrategy launchStrategy;
  final TargetApp? selectedTargetApp;
  final bool loadingTargetApps;
  final bool isRunning;
  final ValueChanged<LaunchStrategy> onStrategyChanged;
  final VoidCallback onPickTargetApp;
  final VoidCallback onRefreshApps;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '启动后去向',
      subtitle: '决定主界面收起后回到哪里。',
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChoicePillGroup<LaunchStrategy>(
            selected: launchStrategy,
            enabled: !isRunning,
            compact: true,
            choices: const [
              _ChoiceItem(
                value: LaunchStrategy.previousApp,
                label: '上一个',
                icon: Icons.switch_access_shortcut_rounded,
              ),
              _ChoiceItem(
                value: LaunchStrategy.selectedApp,
                label: '指定 App',
                icon: Icons.apps_rounded,
              ),
            ],
            onChanged: onStrategyChanged,
          ),
          const SizedBox(height: 12),
          _TargetAppRow(
            label: selectedTargetApp == null
                ? '目标 App：未指定'
                : '目标 App：${selectedTargetApp!.label}',
            loading: loadingTargetApps,
            enabled: !isRunning,
            onPick: onPickTargetApp,
            onRefresh: onRefreshApps,
          ),
          const SizedBox(height: 6),
          Text(
            launchStrategy == LaunchStrategy.selectedApp
                ? '指定 App 只在“去向”里选择，标靶只负责位置校准。'
                : launchStrategy.description,
            style: const TextStyle(
              color: _AppColors.muted,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetAppRow extends StatelessWidget {
  const _TargetAppRow({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onPick,
    required this.onRefresh,
  });

  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              loading ? '正在读取应用列表...' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (loading)
            const SizedBox(
              width: 28,
              height: 28,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: enabled ? onPick : null,
              style: TextButton.styleFrom(
                foregroundColor: _AppColors.text,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('选择'),
            ),
          IconButton(
            tooltip: '刷新应用列表',
            onPressed: enabled && !loading ? onRefresh : null,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            color: _AppColors.muted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 30),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.muted = false,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool muted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.86 : 1,
      child: _PanelSurface(
        fill: muted ? _AppColors.surface : _AppColors.surfaceStrong,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.faint,
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({
    required this.child,
    this.fill = _AppColors.surfaceStrong,
    this.borderColor = _AppColors.border,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color fill;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _DescriptionBox extends StatelessWidget {
  const _DescriptionBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _AppColors.muted,
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InlineControlRow extends StatelessWidget {
  const _InlineControlRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_ControlLabel(label), const SizedBox(height: 10), child],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 76, child: _ControlLabel(label)),
            const SizedBox(width: 10),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ],
        );
      },
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _AppColors.text,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChoicePillGroup<T> extends StatelessWidget {
  const _ChoicePillGroup({
    required this.selected,
    required this.choices,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final T selected;
  final List<_ChoiceItem<T>> choices;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 6 : 12,
      runSpacing: 8,
      children: choices.map((choice) {
        final isSelected = choice.value == selected;
        return _ChoicePill<T>(
          choice: choice,
          selected: isSelected,
          enabled: enabled,
          compact: compact,
          onTap: () => onChanged(choice.value),
        );
      }).toList(),
    );
  }
}

class _ChoiceItem<T> {
  const _ChoiceItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class _ChoicePill<T> extends StatelessWidget {
  const _ChoicePill({
    required this.choice,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final _ChoiceItem<T> choice;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? _AppColors.primary : _AppColors.text;
    final background = selected
        ? _AppColors.primaryTint
        : _AppColors.surfaceStrong;
    final border = selected ? _AppColors.primary : _AppColors.border;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutQuart,
        constraints: BoxConstraints(minWidth: compact ? 76 : 96),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 20,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_rounded,
                size: compact ? 14 : 18,
                color: foreground,
              ),
              const SizedBox(width: 4),
            ] else if (choice.icon != null && !compact) ...[
              Icon(
                choice.icon,
                size: 18,
                color: enabled ? foreground : _AppColors.faint,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              choice.label,
              style: TextStyle(
                color: enabled ? foreground : _AppColors.faint,
                fontSize: compact ? 11 : 16,
                fontWeight: compact ? FontWeight.w700 : FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueStepper extends StatelessWidget {
  const _ValueStepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.enabled,
    required this.keyboardType,
    required this.inputFormatters,
    required this.onMinus,
    required this.onPlus,
    required this.onSubmitted,
  });

  final String label;
  final String value;
  final String unit;
  final bool enabled;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 350;
        final inputWidth = tight ? 82.0 : 86.0;

        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SquareIconButton(
              icon: Icons.remove_rounded,
              onPressed: enabled ? onMinus : null,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: inputWidth,
              height: 34,
              child: TextFormField(
                key: ValueKey('$label-$value'),
                initialValue: value,
                enabled: enabled,
                keyboardType: keyboardType,
                textAlign: TextAlign.center,
                inputFormatters: inputFormatters,
                style: const TextStyle(
                  color: _AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                decoration: InputDecoration(
                  suffixText: unit,
                  suffixStyle: const TextStyle(
                    color: _AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: _AppColors.surfaceStrong,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _AppColors.border),
                  ),
                ),
                onFieldSubmitted: onSubmitted,
              ),
            ),
            const SizedBox(width: 10),
            _SquareIconButton(
              icon: Icons.add_rounded,
              onPressed: enabled ? onPlus : null,
            ),
          ],
        );

        if (tight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ControlLabel(label),
              const SizedBox(height: 10),
              controls,
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 170, child: _ControlLabel(label)),
            const Spacer(),
            controls,
          ],
        );
      },
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: _AppColors.text,
          backgroundColor: _AppColors.surfaceMuted,
          side: const BorderSide(color: _AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.min,
    required this.max,
    required this.start,
    required this.end,
  });

  final double min;
  final double max;
  final double start;
  final double end;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final startX = _position(start, width);
          final endX = _position(end, width);
          final activeStart = math.min(startX, endX);
          final activeWidth = (endX - startX).abs();

          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: 0,
                right: 0,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E7EF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: activeStart,
                width: activeWidth,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(left: startX - 11, child: const _RangeKnob()),
              Positioned(left: endX - 11, child: const _RangeKnob()),
            ],
          );
        },
      ),
    );
  }

  double _position(double value, double width) {
    final percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return percent * width;
  }
}

class _RangeKnob extends StatelessWidget {
  const _RangeKnob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: _AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SliderHeader extends StatelessWidget {
  const _SliderHeader({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _AppColors.success,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PathBox extends StatelessWidget {
  const _PathBox({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _AppColors.border),
      ),
      child: Text(
        path.isEmpty ? '/data/user/0/.../debug.log' : path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _AppColors.faint,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PrimaryCommandButton extends StatelessWidget {
  const _PrimaryCommandButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.minWidth = 96,
    this.danger = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double minWidth;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? 17 : 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: Size(minWidth, compact ? 42 : 46),
        backgroundColor: danger ? _AppColors.danger : _AppColors.primary,
        foregroundColor: _AppColors.surfaceStrong,
        disabledBackgroundColor: _AppColors.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(
          fontSize: compact ? 14 : 16,
          fontWeight: compact ? FontWeight.w700 : FontWeight.w900,
        ),
      ),
    );
  }
}

class _OutlineCommandButton extends StatelessWidget {
  const _OutlineCommandButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.minWidth = 96,
    this.compact = false,
    this.iconOnlyOnCompact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double minWidth;
  final bool compact;
  final bool iconOnlyOnCompact;

  @override
  Widget build(BuildContext context) {
    if (compact && iconOnlyOnCompact) {
      return SizedBox(
        width: minWidth,
        height: 34,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: _AppColors.text,
            backgroundColor: _AppColors.surfaceStrong,
            disabledForegroundColor: _AppColors.faint,
            side: const BorderSide(color: _AppColors.borderStrong),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: compact ? 16 : 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(minWidth, compact ? 34 : 46),
        foregroundColor: _AppColors.text,
        backgroundColor: _AppColors.surfaceStrong,
        disabledForegroundColor: _AppColors.faint,
        side: const BorderSide(color: _AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(
          fontSize: compact ? 12 : 15,
          fontWeight: compact ? FontWeight.w700 : FontWeight.w900,
        ),
      ),
    );
  }
}

double _roundToTenth(double value) {
  return (value * 10).round() / 10;
}
