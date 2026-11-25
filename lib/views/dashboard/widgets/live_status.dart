import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/prism_ui.dart';

import 'live_status_deck.dart';

sealed class LiveStatus {
  const LiveStatus({this.preview});
  final String? preview;
  Object get key => preview ?? runtimeType;
}

final class CoreLiveStatus extends LiveStatus {
  const CoreLiveStatus(this.phase, {super.preview});
  final CoreStatus phase;
}

final class UpdateStatus extends LiveStatus {
  const UpdateStatus(this.download, {super.preview});
  final UpdateDownload download;
}

final class MitmConsentStatus extends LiveStatus {
  const MitmConsentStatus(this.names, {super.preview});
  final List<String> names;
}

bool _isRunningCore(LiveStatus status) =>
    status is CoreLiveStatus && status.phase == CoreStatus.connected;

List<LiveStatus> watchLiveStatuses(WidgetRef ref, {required bool separateCore}) {
  final core = ref.watch(heldCoreStatusProvider);
  final download = ref.watch(updateDownloadStateProvider);
  final awaitingConsent = ref.watch(mitmModulesToAgreeProvider);
  return [
    if (core == CoreStatus.disconnected || separateCore && core == CoreStatus.connecting)
      CoreLiveStatus(core),
    if (download is UpdateReady) UpdateStatus(download),
    if (download is UpdateDownloading) UpdateStatus(download),
    if (awaitingConsent.isNotEmpty)
      MitmConsentStatus([for (final module in awaitingConsent) module.name]),
    if (separateCore && core == CoreStatus.connected)
      const CoreLiveStatus(CoreStatus.connected),
  ];
}

void showLiveStatusPreview(BuildContext context) {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final top = MediaQuery.paddingOf(context).top;
  final anchor = Rect.fromLTWH(overlay.size.width - 60, top + 8, 44, 44);
  const tag = 'v9.9.9';
  const mb = 1024 * 1024;
  unawaited(
    navigator.push(
      LiveStatusRoute(
        anchor: anchor,
        separateCore: true,
        barrierColor: context.colorScheme.alertScrim,
        barrierLabel: context.appLocalizations.close,
        statuses: const [
          CoreLiveStatus(CoreStatus.disconnected, preview: 'stopped'),
          CoreLiveStatus(CoreStatus.connecting, preview: 'starting'),
          UpdateStatus(UpdateReady(tag, ''), preview: 'ready'),
          UpdateStatus(UpdateDownloading(tag, received: 18 * mb, total: 43 * mb), preview: 'downloading'),
          MitmConsentStatus(['Ads', 'Scripts'], preview: 'consent'),
          CoreLiveStatus(CoreStatus.connected, preview: 'running'),
        ],
      ),
    ),
  );
}

class LiveStatusButton extends ConsumerWidget {
  const LiveStatusButton({super.key, this.separateCore});
  final bool? separateCore;
  bool get _separateCore => separateCore ?? coreLib == null;

  void _open(BuildContext context) {
    final navigator = Navigator.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    unawaited(
      navigator.push(
        LiveStatusRoute(
          anchor: anchor,
          separateCore: _separateCore,
          barrierColor: context.colorScheme.alertScrim,
          barrierLabel: context.appLocalizations.close,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = watchLiveStatuses(ref, separateCore: _separateCore);
    final top = statuses.firstOrNull;
    return AnimatedSwitcher(
      duration: Motion.medium2,
      switchInCurve: Motion.emphasizedDecelerate,
      switchOutCurve: Motion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.82, end: 1.0).animate(animation),
            alignment: Alignment.centerRight,
            child: child,
          ),
        );
      },
      child: switch (top) {
        null => const SizedBox.shrink(),
        _ when _isRunningCore(top) => _RunningCoreButton(
          key: const ValueKey(CoreStatus.connected),
          onPressed: () => _open(context),
        ),
        _ => _LiveStatusPill(
          key: ValueKey(_pillKindOf(top)),
          status: top,
          count: statuses.where((it) => !_isRunningCore(it)).length,
          onPressed: () => _open(context),
        ),
      },
    );
  }
}

Object _pillKindOf(LiveStatus status) => switch (status) {
  UpdateStatus(download: UpdateReady()) => UpdateReady,
  CoreLiveStatus(:final phase) => phase,
  _ => status.key,
};

class _RunningCoreButton extends StatelessWidget {
  const _RunningCoreButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final fill = colorScheme.successContainer;
    final pane = TonalButtonTheme.glassOf(context)
        ? LiquidGlassStyle.tinted(colorScheme, fill)
        : null;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration: Motion.medium4,
      curve: Motion.emphasizedDecelerate,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: IconButton.filled(
        tooltip: context.appLocalizations.liveStatus,
        style: ButtonStyle.from(
          backgroundColor: pane == null ? fill : Colors.transparent,
          foregroundColor: colorScheme.onSuccessContainer,
          backgroundBuilder: pane == null ? null : LiquidGlass.buttonBackground((_) => pane),
          pressLook: PressLook.none,
        ),
        onPressed: onPressed,
        icon: const GlyphIcon(AppGlyphs.check, fill: 1),
      ),
    );
  }
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({super.key, required this.status, required this.count, required this.onPressed});
  final LiveStatus status;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final isConnecting = status is CoreLiveStatus && (status as CoreLiveStatus).phase == CoreStatus.connecting;

    final (fill, content) = switch (status) {
      CoreLiveStatus(phase: CoreStatus.disconnected) => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      CoreLiveStatus(phase: CoreStatus.connecting) => (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      UpdateStatus(download: UpdateReady()) => (colorScheme.successContainer, colorScheme.onSuccessContainer),
      MitmConsentStatus() => (colorScheme.warningContainer, colorScheme.onWarningContainer),
      _ => (null, null),
    };

    final label = switch (status) {
      CoreLiveStatus(phase: CoreStatus.disconnected) => appLocalizations.coreStopped,
      CoreLiveStatus() => appLocalizations.connecting,
      UpdateStatus(download: UpdateReady()) => appLocalizations.updateReady,
      UpdateStatus() => appLocalizations.downloadingUpdate,
      MitmConsentStatus() => appLocalizations.mitmModulesTurnedOff,
    };

    final iconSize = globalState.measure.textHeight(AppTextStyle.subheadline);
    final icon = SizedBox.square(
      dimension: iconSize,
      child: switch (status) {
        CoreLiveStatus(phase: CoreStatus.disconnected) => const GlyphIcon(AppGlyphs.error, fill: 1),
        CoreLiveStatus(phase: CoreStatus.connecting) => _M3PulseIndicator(color: content ?? colorScheme.primary),
        CoreLiveStatus() => Builder(builder: (context) => ActivityIndicator(color: IconTheme.of(context).color)),
        UpdateStatus(download: UpdateReady()) => const GlyphIcon(AppGlyphs.checkCircle, fill: 1),
        UpdateStatus(download: UpdateDownloading(:final received, :final total)) =>
          _PillProgressRing(value: total > 0 ? received / total : null),
        MitmConsentStatus() => const GlyphIcon(AppGlyphs.puzzle, fill: 1),
      },
    );

    final shown = switch (status) {
      UpdateStatus(download: UpdateReady()) => '100%',
      UpdateStatus(download: UpdateDownloading(:final received, :final total)) =>
        total > 0 ? '${received * 100 ~/ total}%' : received.traffic.show,
      _ when count > 1 => '$count',
      _ => null,
    };

    final pane = TonalButtonTheme.glassOf(context) && fill != null
        ? LiquidGlassStyle.tinted(colorScheme, fill)
        : null;

    final style = ButtonStyle.from(
      backgroundColor: pane == null ? fill : Colors.transparent,
      foregroundColor: content,
      backgroundBuilder: pane == null ? null : LiquidGlass.buttonBackground((_) => pane),
      pressLook: PressLook.none,
    );

    final button = shown != null
        ? Tooltip(
            message: appLocalizations.liveStatus,
            child: FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: icon,
              label: Text(shown, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            ),
          )
        : IconButton.filled(
            tooltip: appLocalizations.liveStatus,
            style: style,
            onPressed: onPressed,
            icon: icon,
          );

    return Semantics(
      label: shown == null ? label : '$label, $shown',
      excludeSemantics: true,
      button: true,
      child: isConnecting
          ? _M3GlowWrapper(glowColor: fill ?? colorScheme.primaryContainer, child: button)
          : button,
    );
  }
}

class _M3GlowWrapper extends StatefulWidget {
  const _M3GlowWrapper({required this.child, required this.glowColor});
  final Widget child;
  final Color glowColor;
  @override
  State<_M3GlowWrapper> createState() => _M3GlowWrapperState();
}

class _M3GlowWrapperState extends State<_M3GlowWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final spread = 2.0 + _pulse.value * 4.0;
        final opacity = 0.25 + _pulse.value * 0.35;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: widget.glowColor.withValues(alpha: opacity), blurRadius: spread * 2, spreadRadius: spread),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _M3PulseIndicator extends StatefulWidget {
  const _M3PulseIndicator({required this.color});
  final Color color;
  @override
  State<_M3PulseIndicator> createState() => _M3PulseIndicatorState();
}

class _M3PulseIndicatorState extends State<_M3PulseIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)));
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = 0.6 + (_controller.value * 0.4);
        final opacity = 0.4 + (_controller.value * 0.6);
        return Center(
          child: Transform.scale(
            scale: scale,
            child: Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color.withValues(alpha: opacity), shape: BoxShape.circle)),
          ),
        );
      },
    );
  }
}

class _PillProgressRing extends StatelessWidget {
  const _PillProgressRing({required this.value});
  final double? value;
  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? context.colorScheme.onPrimary;
    return CustomPaint(painter: _RingPainter(value: value ?? 0, color: color));
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});
  final double value;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.14;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = color.withValues(alpha: 0.3);
    canvas.drawOval(rect, paint);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value.clamp(0, 1), false, paint..color = color);
    }
  }
  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value || oldDelegate.color != color;
}
