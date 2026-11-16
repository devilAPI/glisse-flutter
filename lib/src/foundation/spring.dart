import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A damped spring that eases a value towards a target, keeping its velocity
/// when the target changes mid-flight, as Glisse's springs do.
///
/// Each frame it steps by the spring's exact solution, so it is stable at any
/// frame rate. [stiffness] and [damping] are per unit mass.
class GlassSpring extends ChangeNotifier implements ValueListenable<double> {
  GlassSpring({
    required TickerProvider vsync,
    double value = 0,
    required double stiffness,
    required double damping,
  })  : _value = value,
        _target = value,
        _stiffness = stiffness,
        _damping = damping {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  double _value;
  double _target;
  double _velocity = 0;
  double _stiffness;
  double _damping;
  Duration _last = Duration.zero;

  /// When true, every change lands at once, as when the platform asks for
  /// reduced motion.
  bool reduceMotion = false;

  @override
  double get value => _value;

  double get target => _target;

  double get velocity => _velocity;

  bool get isMoving => _ticker.isActive;

  double get stiffness => _stiffness;

  double get damping => _damping;

  /// Changes how the spring moves from now on, keeping where it is and how fast.
  void tune(double stiffness, double damping) {
    _stiffness = stiffness;
    _damping = damping;
  }

  /// Springs towards [target], or jumps there when [instant].
  void set(double target, {bool instant = false}) {
    _target = target;
    if (instant || reduceMotion) {
      _value = target;
      _velocity = 0;
      if (_ticker.isActive) _ticker.stop();
      notifyListeners();
      return;
    }
    if (_value == target && _velocity == 0) return;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// Jumps to [value] and keeps moving at [velocity] towards the target.
  void jump(double value, {double velocity = 0}) {
    _value = value;
    _velocity = velocity;
    notifyListeners();
    if (!_ticker.isActive && (value != _target || velocity != 0)) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// Stops where it is.
  void stop() {
    if (_ticker.isActive) _ticker.stop();
    _velocity = 0;
  }

  void _tick(Duration elapsed) {
    // The first frame already shows one frame's worth of motion.
    final dt = _last == Duration.zero && elapsed == Duration.zero
        ? 1 / 60
        : math.min(0.1, math.max(0.0, (elapsed - _last).inMicroseconds / 1e6));
    _last = elapsed;
    _advance(dt);
    if ((_value - _target).abs() < 1e-4 && _velocity.abs() < 1e-3) {
      _value = _target;
      _velocity = 0;
      _ticker.stop();
    }
    notifyListeners();
  }

  void _advance(double dt) {
    final x = _value - _target;
    final v = _velocity;
    final half = _damping / 2;
    final discriminant = half * half - _stiffness;
    if (discriminant.abs() < 1e-4) {
      final decay = math.exp(-half * dt);
      final b = v + half * x;
      _value = _target + decay * (x + b * dt);
      _velocity = decay * (v - half * b * dt);
    } else if (discriminant > 0) {
      final root = math.sqrt(discriminant);
      final r1 = -half + root;
      final r2 = -half - root;
      final a = (v - r2 * x) / (r1 - r2);
      final b = x - a;
      _value = _target + a * math.exp(r1 * dt) + b * math.exp(r2 * dt);
      _velocity = a * r1 * math.exp(r1 * dt) + b * r2 * math.exp(r2 * dt);
    } else {
      final omega = math.sqrt(-discriminant);
      final decay = math.exp(-half * dt);
      final cos = math.cos(omega * dt);
      final sin = math.sin(omega * dt);
      _value = _target + decay * (x * cos + ((v + half * x) / omega) * sin);
      _velocity = decay * (v * cos - ((half * v + _stiffness * x) / omega) * sin);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
