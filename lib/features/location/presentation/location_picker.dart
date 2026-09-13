import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooper/core/services/providers.dart';
import 'package:hooper/core/widgets/skeleton_widget.dart';

class LocationPickerController {
  GeoPoint _point;
  bool hasMoved = false;
  final bool canMove;
  set point(GeoPoint newPoint) {
    hasMoved = true;
    _point = newPoint;
  }

  GeoPoint get point => _point;

  LocationPickerController({required this._point, this.canMove = true});
}

class LocationPicker extends ConsumerStatefulWidget {
  const LocationPicker({
    super.key,
    required this.controller,
    this.height,
    this.borderRadius = 34,
  });

  final LocationPickerController controller;
  final double? height;
  final double borderRadius;

  static LocationPicker locationDisplayer(
    GeoPoint location, {
    double? height,
    double borderRadius = 34,
  }) {
    return LocationPicker(
      controller: LocationPickerController(point: location, canMove: false),
      height: height,
      borderRadius: borderRadius,
    );
  }

  static Future<GeoPoint?> pickLocation(
    BuildContext context,
    GeoPoint startLocation,
  ) async {
    final LocationPickerController controller = LocationPickerController(
      point: startLocation,
    );
    return await showModalBottomSheet(
      enableDrag: false,
      isDismissible: true,
      showDragHandle: true,
      context: context,
      builder: (context) {
        GeoPoint location = startLocation;
        return Column(
          children: [
            LocationPicker(controller: controller),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(null);
                      },
                      child: Text("Cancel"),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(location);
                      },
                      child: Text("Confirm"),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  Animation<double>? _routeAnimation;

  void _onRouteAnimationStatusChange(AnimationStatus status) {
    // The status notification can land while an unrelated widget is mid-build
    // (e.g. this route's own transition finishing while a Firestore update
    // rebuilds this widget's parent), which would throw "setState() called
    // during build". Defer to the next frame so it's always safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChange);
      _routeAnimation = animation;
      _routeAnimation?.addStatusListener(_onRouteAnimationStatusChange);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialPoint = widget.controller.point;
    final styleAsync = ref.read(mapStyleProvider);

    final anim = _routeAnimation;
    final isAnim =
        anim == null || anim.status == .forward || anim.status == .reverse;
    final isThumbnail = widget.height != null && widget.height! < 100;
    final markerSize = isThumbnail ? 18.0 : 50.0;
    final markerBottomPadding = isThumbnail ? 4.0 : 40.0;
    return ClipRSuperellipse(
      borderRadius: .circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height ?? MediaQuery.sizeOf(context).height / 3,
        child: Stack(
          children: [
            if (!isAnim)
              SizedBox.expand(
                child: SkeletonWidget<String>(
                  builder: (style) => GoogleMap(
                    style: style,
                    scrollGesturesEnabled: widget.controller.canMove,
                    zoomGesturesEnabled: widget.controller.canMove,
                    padding: EdgeInsets.zero,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    minMaxZoomPreference: MinMaxZoomPreference(5, 18),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        initialPoint.latitude,
                        initialPoint.longitude,
                      ),
                      zoom: 8,
                    ),
                    zoomControlsEnabled: false,
                    onCameraMove: (position) {
                      widget.controller.point = GeoPoint(
                        position.target.latitude,
                        position.target.longitude,
                      );
                    },
                  ),
                  val: styleAsync,
                  dummyData: '',
                ),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: markerBottomPadding),
              child: Center(child: Icon(Icons.location_on, size: markerSize)),
            ),
          ],
        ),
      ),
    );
  }
}
