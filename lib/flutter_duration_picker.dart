library flutter_duration_picker;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const Duration _kDialAnimateDuration = const Duration(milliseconds: 200);

const double _kDurationPickerWidthPortrait = 328.0;
const double _kDurationPickerWidthLandscape = 512.0;

const double _kDurationPickerHeightPortrait = 380.0;
const double _kDurationPickerHeightLandscape = 304.0;

const double _kTwoPi = 2 * math.pi;
const double _kPiByTwo = math.pi / 2;

const double _kCircleTop = _kPiByTwo;
const double _kCircleBottom = 3 * math.pi / 2;
const double _kCircleRight = 0.0;
const double _kCircleRightComplete = _kTwoPi;
const double _kCircleLeft = math.pi;

class _DialPainter extends CustomPainter {
  const _DialPainter({
    @required this.context,
    @required this.labels,
    @required this.backgroundColor,
    @required this.accentColor,
    @required this.theta,
    @required this.textDirection,
    @required this.selectedValue,
    @required this.pct,
    @required this.multiplier,
  });

  final List<TextPainter> labels;
  final Color backgroundColor;
  final Color accentColor;
  final double theta;
  final TextDirection textDirection;
  final int selectedValue;
  final BuildContext context;

  final double pct;
  final int multiplier;

  @override
  void paint(Canvas canvas, Size size) {
    const double _epsilon = .001;
    const double _sweep = _kTwoPi - _epsilon;
    const double _startAngle = -math.pi / 2.0;

    final double radius = size.shortestSide / 2.0;
    final Offset center = new Offset(size.width / 2.0, size.height / 2.0);
    final Offset centerPoint = center;

    double pctTheta = (0.25 - (theta % _kTwoPi) / _kTwoPi) % 1.0;

    // Draw the background outer ring
    canvas.drawCircle(
        centerPoint, radius, new Paint()..color = backgroundColor);

    // Draw a translucent circle for every hour
    for (int i = 0; i < multiplier; i = i + 1) {
      canvas.drawCircle(centerPoint, radius,
          new Paint()..color = accentColor.withOpacity((i == 0) ? 0.3 : 0.1));
    }

    // Draw the inner background circle
    canvas.drawCircle(
        centerPoint, radius * 0.88, new Paint()..color = Theme.of(context).canvasColor);

    // Get the offset point for an angle value of theta, and a distance of _radius
    Offset getOffsetForTheta(double theta, double _radius) {
      return center +
          new Offset(_radius * math.cos(theta), -_radius * math.sin(theta));
    }

    // Draw the handle that is used to drag and to indicate the position around the circle
    final Paint handlePaint = new Paint()..color = accentColor;
    final Offset handlePoint = getOffsetForTheta(theta, radius - 10.0);
    canvas.drawCircle(handlePoint, 20.0, handlePaint);

    // Draw the Text in the center of the circle which displays hours and mins
    String hours = (multiplier == 0) ? '' : "${multiplier}h ";
    int minutes = (pctTheta * 60).round();
    minutes = minutes == 60 ? 0 : minutes;
    TextPainter textDurationValuePainter = new TextPainter(
        textAlign: TextAlign.center,
        text: new TextSpan(
            text: '${hours}${minutes > 0 ? minutes : ""}',
            style: Theme.of(context)
                .textTheme
                .display3
                .copyWith(fontSize: size.shortestSide * 0.15)),
        textDirection: TextDirection.ltr)
      ..layout();
    Offset middleForValueText = new Offset(
        centerPoint.dx - (textDurationValuePainter.width / 2),
        centerPoint.dy - textDurationValuePainter.height / 2);
    textDurationValuePainter.paint(canvas, middleForValueText);

    TextPainter textMinPainter = new TextPainter(
        textAlign: TextAlign.center,
        text: new TextSpan(
            text: 'min.', //th: ${theta}',
            style: Theme.of(context).textTheme.body1),
        textDirection: TextDirection.ltr)
      ..layout();
    textMinPainter.paint(
        canvas,
        new Offset(
            centerPoint.dx - (textMinPainter.width / 2),
            centerPoint.dy +
                (textDurationValuePainter.height / 2) -
                textMinPainter.height / 2));

    // Draw an arc around the circle for the amount of the circle that has elapsed.
    var elapsedPainter = new Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = accentColor.withOpacity(0.3)
      ..isAntiAlias = true
      ..strokeWidth = radius * 0.12;

    canvas.drawArc(
      new Rect.fromCircle(
        center: centerPoint,
        radius: radius - radius * 0.12 / 2,
      ),
      _startAngle,
      _sweep * pctTheta,
      false,
      elapsedPainter,
    );

    // Paint the labels (the minute strings)
    void paintLabels(List<TextPainter> labels) {
      if (labels == null) return;
      final double labelThetaIncrement = -_kTwoPi / labels.length;
      double labelTheta = _kPiByTwo;

      for (TextPainter label in labels) {
        final Offset labelOffset =
            new Offset(-label.width / 2.0, -label.height / 2.0);

        label.paint(
            canvas, getOffsetForTheta(labelTheta, radius - 40.0) + labelOffset);

        labelTheta += labelThetaIncrement;
      }
    }

    paintLabels(labels);
  }

  @override
  bool shouldRepaint(_DialPainter oldPainter) {
    return oldPainter.labels != labels ||
        oldPainter.backgroundColor != backgroundColor ||
        oldPainter.accentColor != accentColor ||
        oldPainter.theta != theta;
  }
}

class _Dial extends StatefulWidget {
  const _Dial(
      {@required this.duration,
      @required this.onChanged,
      this.snapToMins = 1.0})
      : assert(duration != null);

  final Duration duration;
  final ValueChanged<Duration> onChanged;

  /// The resolution of mins of the dial, i.e. if snapToMins = 5.0, only durations of 5min intervals will be selectable.
  final double snapToMins;
  @override
  _DialState createState() => new _DialState();
}

class _DialState extends State<_Dial> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _thetaController = new AnimationController(
      duration: _kDialAnimateDuration,
      vsync: this,
    );
    _thetaTween =
        new Tween<double>(begin: _getThetaForDuration(widget.duration));
    _theta = _thetaTween.animate(new CurvedAnimation(
        parent: _thetaController, curve: Curves.fastOutSlowIn))
      ..addListener(() => setState(() {}));
    _thetaController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _hours != _snappedHours) {
        _hours = _snappedHours;
        setState(() {});
      }
    });
    _hours = widget.duration.inHours;
  }

  ThemeData themeData;
  MaterialLocalizations localizations;
  MediaQueryData media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMediaQuery(context));
    themeData = Theme.of(context);
    localizations = MaterialLocalizations.of(context);
    media = MediaQuery.of(context);
  }

  @override
  void dispose() {
    _thetaController.dispose();
    super.dispose();
  }

  Tween<double> _thetaTween;
  Animation<double> _theta;
  AnimationController _thetaController;

  double _pct = 0.0;
  int _hours = 0;
  int _snappedHours = 0;
  bool _dragging = false;

  static double _nearest(double target, double a, double b) {
    return ((target - a).abs() < (target - b).abs()) ? a : b;
  }

  void _animateTo(double targetTheta) {
    final double currentTheta = _theta.value;
    double beginTheta =
        _nearest(targetTheta, currentTheta, currentTheta + _kTwoPi);
    beginTheta = _nearest(targetTheta, beginTheta, currentTheta - _kTwoPi);
    _thetaTween
      ..begin = beginTheta
      ..end = targetTheta;
    _thetaController
      ..value = 0.0
      ..forward();
  }

  double _getThetaForDuration(Duration duration) {
    final double fractionalRotation = (duration.inMinutes / 60);
    var theta = (_kPiByTwo - fractionalRotation * _kTwoPi) % _kTwoPi;
    return theta;
  }

  Duration _getTimeForTheta(double theta) {
    double fractionalRotation = (0.25 - (theta / _kTwoPi));
    fractionalRotation = fractionalRotation < 0
        ? 1 - fractionalRotation.abs()
        : fractionalRotation;
    int mins = (fractionalRotation * 60).round();
    if (widget.snapToMins != null) {
      mins = ((mins / widget.snapToMins).round() * widget.snapToMins).round();
    }
    if (mins == 60) {
      _snappedHours = _hours + 1;
      mins = 0;
      return new Duration(hours: _snappedHours, minutes: mins);
    } else {
      _snappedHours = _hours;
      return new Duration(hours: _hours, minutes: mins);
    }
  }

  Duration _notifyOnChangedIfNeeded() {
    final Duration current = _getTimeForTheta(_theta.value);
    var d = Duration(hours: _hours, minutes: current.inMinutes % 60);
    widget.onChanged(d);

    return d;
  }

  void _updateThetaForPan() {
    setState(() {
      final Offset offset = _position - _center;
      final double angle =
          (math.atan2(offset.dx, offset.dy) - _kPiByTwo) % _kTwoPi;

      // Stop accidental abrupt pans from making the dial seem like it starts from 1h.
      // (happens when wanting to pan from 0 clockwise, but when doing so quickly, one actually pans from before 0 (e.g. setting the duration to 59mins, and then crossing 0, which would then mean 1h 1min).
      if (angle >= _kCircleTop &&
          _theta.value <= _kCircleTop &&
          _theta.value >= 0.1 && // to allow the radians sign change at 15mins.
          _hours == 0) return;

      _thetaTween
        ..begin = angle
        ..end = angle;
    });
  }

  Offset _position;
  Offset _center;

  void _handlePanStart(DragStartDetails details) {
    assert(!_dragging);
    _dragging = true;
    final RenderBox box = context.findRenderObject();
    _position = box.globalToLocal(details.globalPosition);
    _center = box.size.center(Offset.zero);

    _updateThetaForPan();
    _notifyOnChangedIfNeeded();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    double oldTheta = _theta.value;
    _position += details.delta;
    _updateThetaForPan();
    double newTheta = _theta.value;

    _updateRotations(oldTheta, newTheta);

    _notifyOnChangedIfNeeded();
  }

  void _updateRotations(double oldTheta, double newTheta) {
    // If the angle crosses clockwise through 12'o'clock
    if (oldTheta > _kCircleTop &&
        newTheta <= _kCircleTop &&
        oldTheta < _kCircleLeft) {
      setState(() => _hours = _hours + 1);
      // If the angle cross anti-clockwise through 12'o'clock
    } else if (oldTheta <= _kCircleTop &&
        newTheta > _kCircleTop &&
        newTheta < _kCircleBottom) {
      if (_hours > 0) {
        setState(() => _hours = _hours - 1);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    assert(_dragging);
    _dragging = false;
    _position = null;
    _center = null;
    //_notifyOnChangedIfNeeded();
    _animateTo(_getThetaForDuration(widget.duration));
  }

  void _handleTapUp(TapUpDetails details) {
    final RenderBox box = context.findRenderObject();
    _position = box.globalToLocal(details.globalPosition);
    _center = box.size.center(Offset.zero);
    _updateThetaForPan();
    _notifyOnChangedIfNeeded();

    _animateTo(_getThetaForDuration(_getTimeForTheta(_theta.value)));
    _dragging = false;
    _position = null;
    _center = null;
  }

  List<TextPainter> _buildMinutes(TextTheme textTheme) {
    final TextStyle style = textTheme.subhead;

    const List<Duration> _minuteMarkerValues = const <Duration>[
      const Duration(hours: 0, minutes: 0),
      const Duration(hours: 0, minutes: 5),
      const Duration(hours: 0, minutes: 10),
      const Duration(hours: 0, minutes: 15),
      const Duration(hours: 0, minutes: 20),
      const Duration(hours: 0, minutes: 25),
      const Duration(hours: 0, minutes: 30),
      const Duration(hours: 0, minutes: 35),
      const Duration(hours: 0, minutes: 40),
      const Duration(hours: 0, minutes: 45),
      const Duration(hours: 0, minutes: 50),
      const Duration(hours: 0, minutes: 55),
    ];

    final List<TextPainter> labels = <TextPainter>[];
    for (Duration duration in _minuteMarkerValues) {
      var painter = new TextPainter(
        text: new TextSpan(style: style, text: duration.inMinutes.toString()),
        textDirection: TextDirection.ltr,
      )..layout();
      labels.add(painter);
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    switch (themeData.brightness) {
      case Brightness.light:
        backgroundColor = Colors.grey[200];
        break;
      case Brightness.dark:
        backgroundColor = themeData.backgroundColor;
        break;
    }

    final ThemeData theme = Theme.of(context);

    int selectedDialValue;

    return new GestureDetector(
        excludeFromSemantics: true,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onTapUp: _handleTapUp,
        child: new CustomPaint(
          painter: new _DialPainter(
            pct: _pct,
            multiplier: _hours,
            context: context,
            selectedValue: selectedDialValue,
            labels: _buildMinutes(theme.textTheme),
            backgroundColor: backgroundColor,
            accentColor: themeData.accentColor,
            theta: _theta.value,
            textDirection: Directionality.of(context),
          ),
        ));
  }
}

/// A duration picker designed to appear inside a popup dialog.
///
/// Pass this widget to [showDialog]. The value returned by [showDialog] is the
/// selected [Duration] if the user taps the "OK" button, or null if the user
/// taps the "CANCEL" button. The selected time is reported by calling
/// [Navigator.pop].
class _DurationPickerDialog extends StatefulWidget {
  /// Creates a duration picker.
  ///
  /// [initialTime] must not be null.
  const _DurationPickerDialog(
      {Key key, @required this.initialTime, this.snapToMins})
      : assert(initialTime != null),
        super(key: key);

  /// The duration initially selected when the dialog is shown.
  final Duration initialTime;
  final double snapToMins;

  @override
  _DurationPickerDialogState createState() => new _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialTime;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = MaterialLocalizations.of(context);
  }

  Duration get selectedDuration => _selectedDuration;
  Duration _selectedDuration;

  MaterialLocalizations localizations;

  void _handleTimeChanged(Duration value) {
    setState(() {
      _selectedDuration = value;
    });
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  void _handleOk() {
    Navigator.pop(context, _selectedDuration);
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final ThemeData theme = Theme.of(context);

    final Widget picker = new Padding(
        padding: const EdgeInsets.all(16.0),
        child: new AspectRatio(
            aspectRatio: 1.0,
            child: new _Dial(
              duration: _selectedDuration,
              onChanged: _handleTimeChanged,
              snapToMins: widget.snapToMins,
            )));

    final Widget actions = new ButtonTheme.bar(
        child: new ButtonBar(children: <Widget>[
      new FlatButton(
          child: new Text(localizations.cancelButtonLabel),
          onPressed: _handleCancel),
      new FlatButton(
          child: new Text(localizations.okButtonLabel), onPressed: _handleOk),
    ]));

    final Dialog dialog = new Dialog(child: new OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
      final Widget pickerAndActions = new Container(
        color: theme.dialogBackgroundColor,
        child: new Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Expanded(
                child:
                    picker), // picker grows and shrinks with the available space
            actions,
          ],
        ),
      );

      assert(orientation != null);
      switch (orientation) {
        case Orientation.portrait:
          return new SizedBox(
              width: _kDurationPickerWidthPortrait,
              height: _kDurationPickerHeightPortrait,
              child: new Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    new Expanded(
                      child: pickerAndActions,
                    ),
                  ]));
        case Orientation.landscape:
          return new SizedBox(
              width: _kDurationPickerWidthLandscape,
              height: _kDurationPickerHeightLandscape,
              child: new Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    new Flexible(
                      child: pickerAndActions,
                    ),
                  ]));
      }
      return null;
    }));

    return new Theme(
      data: theme.copyWith(
        dialogBackgroundColor: Colors.transparent,
      ),
      child: dialog,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Shows a dialog containing the duration picker.
///
/// The returned Future resolves to the duration selected by the user when the user
/// closes the dialog. If the user cancels the dialog, null is returned.
///
/// To show a dialog with [initialTime] equal to the current time:
///
/// ```dart
/// showDurationPicker(
///   initialTime: new Duration.now(),
///   context: context,
/// );
/// ```
Future<Duration> showDurationPicker(
    {@required BuildContext context,
    @required Duration initialTime,
    double snapToMins}) async {
  assert(context != null);
  assert(initialTime != null);

  return await showDialog<Duration>(
    context: context,
    builder: (BuildContext context) =>
        new _DurationPickerDialog(initialTime: initialTime, snapToMins: snapToMins),
  );
}

class DurationPicker extends StatelessWidget {
  final Duration duration;
  final ValueChanged<Duration> onChange;
  final double snapToMins;

  final double width;
  final double height;

  DurationPicker(
      {this.duration = const Duration(minutes: 0),
      @required this.onChange,
      this.snapToMins,
      this.width,
      this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width ?? _kDurationPickerWidthPortrait / 1.5,
        height: height ?? _kDurationPickerHeightPortrait / 1.5,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _Dial(
                  duration: duration,
                  onChanged: onChange,
                  snapToMins: snapToMins,
                ),
              ),
            ]));
  }
}
