import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';

/*
 * This is pretty much all a massive hack for a missing feature in the
 * Flutter framework. Basically, Flutter doesn't support dynamically
 * updating _viewportFraction for a PageView. This code solves that.
 * There's a more devious problem though, and this is when _viewportFraction
 * is updated while viewing the last page. Because the maxScrollExtent is
 * changing, the pixel scroll position isn't quite computed accurately for
 * some reason, so the last page transition gets really glitchy. There are
 * a few ways to handle this, the best (and most consistent) I've found
 * is just to force the user to go to the first screen before applying
 * the zoom affect. This can been seen in the BoardViewController
 * "toggleMode" function.
 */

typedef OnAttemptDrag(int from, int to);

class DynamicPageController extends PageController {
  double _viewportFraction = 1;

  double get viewportFraction => _viewportFraction;

  DynamicPageController({int initialPage = 0})
      : super(initialPage: initialPage);

  void updateViewportFraction(double fraction) {
    _viewportFraction = fraction;

    final PagePosition pagePosition = position as PagePosition;
    pagePosition.viewportFraction = fraction;
  }

  bool get ready {
    return positions.length == 1;
  }

  @override
  double get page {
    assert(
      positions.isNotEmpty,
      'PageController.page cannot be accessed before a PageView is built with it.',
    );
    assert(
      positions.length == 1,
      'The page property cannot be read when multiple PageViews are attached to '
      'the same PageController.',
    );
    final PagePosition position = this.position as PagePosition;
    return position.page;
  }

  /// Changes which page is displayed in the controlled [PageView].
  ///
  /// Jumps the page position from its current value to the given value,
  /// without animation, and without checking if the new value is in range.
  void jumpToPage(int page) {
    final PagePosition position = this.position as PagePosition;
    position.jumpTo(position.getPixelsFromPage(page.toDouble()));
  }

  Future<void> animateToPage(
    int page, {
    @required Duration duration,
    @required Curve curve,
  }) {
    final PagePosition position = this.position as PagePosition;
    return position.animateTo(
      position.getPixelsFromPage(page.toDouble()),
      duration: duration,
      curve: curve,
    );
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics,
      ScrollContext context, ScrollPosition oldPosition) {
    return PagePosition(
      physics: physics,
      context: context,
      initialPage: initialPage,
      keepPage: keepPage,
      viewportFraction: viewportFraction,
      oldPosition: oldPosition,
    );
  }

  @override
  void attach(ScrollPosition position) {
    try {
      super.attach(position);
    } catch (e) {
      // Ignore, this is a hack because super.super needs to get
      // called, but the parent has some code that isn't compatible,
      // which is mirrored below using type PagePosition instead
      // of the private _PagePosition
    } finally {
      final PagePosition pagePosition = position as PagePosition;
      pagePosition.viewportFraction = viewportFraction;
    }
  }
}

class DynamicPageScrollPhysics extends ScrollPhysics {
  /// Requests whether a drag may occur from the page at index "from"
  /// to the page at index "to". Return true to allow, false to deny.
  final OnAttemptDrag onAttemptDrag;

  /// Creates physics for a [PageView].
  const DynamicPageScrollPhysics(
      {ScrollPhysics parent, @required this.onAttemptDrag})
      : super(parent: parent);

  @override
  DynamicPageScrollPhysics applyTo(ScrollPhysics ancestor) {
    return DynamicPageScrollPhysics(
        parent: buildParent(ancestor), onAttemptDrag: onAttemptDrag);
  }

  double _getPage(ScrollMetrics position) {
    if (position is PagePosition) return position.page;
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    if (position is PagePosition) return position.getPixelsFromPage(page);
    return page * position.viewportDimension;
  }

  double _getTargetPixels(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    double page = _getPage(position);
    if (velocity < -tolerance.velocity)
      page -= 0.5;
    else if (velocity > tolerance.velocity) page += 0.5;
    return _getPixels(position, page.roundToDouble());
  }

  // position is the pixels of the left edge of the screen
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    assert(() {
      if (value == position.pixels) {
        throw FlutterError(
            '$runtimeType.applyBoundaryConditions() was called redundantly.\n'
            'The proposed new position, $value, is exactly equal to the current position of the '
            'given ${position.runtimeType}, ${position.pixels}.\n'
            'The applyBoundaryConditions method should only be called when the value is '
            'going to actually change the pixels, otherwise it is redundant.\n'
            'The physics object in question was:\n'
            '  $this\n'
            'The position object in question was:\n'
            '  $position\n');
      }
      return true;
    }());

    /*
     * Handle the hard boundaries (min and max extents)
     * (identical to ClampingScrollPhysics)
     */
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) // under-scroll
      return value - position.pixels;
    if (position.maxScrollExtent <= position.pixels &&
        position.pixels < value) // over-scroll
      return value - position.pixels;
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) // hit top edge
      return value - position.minScrollExtent;
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) // hit bottom edge
      return value - position.maxScrollExtent;

    bool left = value < position.pixels;

    int fromPage, toPage;
    double overScroll = 0;

    if(left) {
      fromPage = position.pixels.ceil() ~/ position.viewportDimension;
      toPage = value ~/ position.viewportDimension;

      overScroll = value - fromPage * position.viewportDimension;
      overScroll = overScroll.clamp(value - position.pixels, 0.0);
    } else {
      fromPage = (position.pixels + position.viewportDimension).floor() ~/ position.viewportDimension;
      toPage = (value + position.viewportDimension) ~/ position.viewportDimension;

      overScroll = value - fromPage * position.viewportDimension;
      overScroll = overScroll.clamp(0.0, value - position.pixels);
    }

    if(fromPage != toPage && !onAttemptDrag(fromPage, toPage)) {
      return overScroll;
    } else {
      return super.applyBoundaryConditions(position, value);
    }
  }

  @override
  Simulation createBallisticSimulation(
      ScrollMetrics position, double velocity) {

    // If we're out of range and not headed back in range, defer to the parent
    // ballistics, which should put us back in range at a page boundary.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent))
      return super.createBallisticSimulation(position, velocity);
    final Tolerance tolerance = this.tolerance;
    final double target = _getTargetPixels(position, tolerance, velocity);
    if (target != position.pixels)
      return ScrollSpringSimulation(spring, position.pixels, target, velocity,
          tolerance: tolerance);
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

class PagePosition extends ScrollPositionWithSingleContext
    implements PageMetrics {
  PagePosition({
    ScrollPhysics physics,
    ScrollContext context,
    this.initialPage = 0,
    bool keepPage = true,
    double viewportFraction = 1.0,
    ScrollPosition oldPosition,
  })  : assert(initialPage != null),
        assert(keepPage != null),
        assert(viewportFraction != null),
        assert(viewportFraction > 0.0),
        _viewportFraction = viewportFraction,
        _pageToUseOnStartup = initialPage.toDouble(),
        super(
          physics: physics,
          context: context,
          initialPixels: null,
          keepScrollOffset: keepPage,
          oldPosition: oldPosition,
        );

  final int initialPage;
  double _pageToUseOnStartup;

  @override
  double get viewportFraction => _viewportFraction;
  double _viewportFraction;

  set viewportFraction(double value) {
    if (_viewportFraction == value) return;
    final double oldPage = page;
    _viewportFraction = value;

    if (oldPage != null) {
      jumpTo(getPixelsFromPage(oldPage));
    }
  }

  // The amount of offset that will be added to [minScrollExtent] and subtracted
  // from [maxScrollExtent], such that every page will properly snap to the center
  // of the viewport when viewportFraction is greater than 1.
  //
  // The value is 0 if viewportFraction is less than or equal to 1, larger than 0
  // otherwise.
  double get _initialPageOffset =>
      math.max(0, viewportDimension * (viewportFraction - 1) / 2);

  double getPageFromPixels(double pixels, double viewportDimension) {
    final double actual = math.max(0.0, pixels - _initialPageOffset) /
        math.max(1.0, viewportDimension * viewportFraction);
    final double round = actual.roundToDouble();
    if ((actual - round).abs() < precisionErrorTolerance) {
      return round;
    }
    return actual;
  }

  double getPixelsFromPage(double page) {
    return page * viewportDimension * viewportFraction + _initialPageOffset;
  }

  @override
  double get page {
    assert(
      pixels == null || (minScrollExtent != null && maxScrollExtent != null),
      'Page value is only available after content dimensions are established.',
    );
    return pixels == null
        ? null
        : getPageFromPixels(
            pixels.clamp(minScrollExtent, maxScrollExtent) as double,
            viewportDimension);
  }

  @override
  void saveScrollOffset() {
    PageStorage.of(context.storageContext)?.writeState(
        context.storageContext, getPageFromPixels(pixels, viewportDimension));
  }

  @override
  void restoreScrollOffset() {
    if (pixels == null) {
      final double value = PageStorage.of(context.storageContext)
          ?.readState(context.storageContext) as double;
      if (value != null) _pageToUseOnStartup = value;
    }
  }

  @override
  bool applyViewportDimension(double viewportDimension) {
    final double oldViewportDimensions = this.viewportDimension;
    final bool result = super.applyViewportDimension(viewportDimension);
    final double oldPixels = pixels;
    final double page = (oldPixels == null || oldViewportDimensions == 0.0)
        ? _pageToUseOnStartup
        : getPageFromPixels(oldPixels, oldViewportDimensions);
    final double newPixels = getPixelsFromPage(page);

    if (newPixels != oldPixels) {
      correctPixels(newPixels);
      return false;
    }
    return result;
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final double newMinScrollExtent = minScrollExtent + _initialPageOffset;
    return super.applyContentDimensions(
      newMinScrollExtent,
      math.max(newMinScrollExtent, maxScrollExtent - _initialPageOffset),
    );
  }

  @override
  PageMetrics copyWith({
    double minScrollExtent,
    double maxScrollExtent,
    double pixels,
    double viewportDimension,
    AxisDirection axisDirection,
    double viewportFraction,
  }) {
    return PageMetrics(
      minScrollExtent: minScrollExtent ?? this.minScrollExtent,
      maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
      pixels: pixels ?? this.pixels,
      viewportDimension: viewportDimension ?? this.viewportDimension,
      axisDirection: axisDirection ?? this.axisDirection,
      viewportFraction: viewportFraction ?? this.viewportFraction,
    );
  }
}
