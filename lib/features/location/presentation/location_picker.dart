import 'dart:developer' show log;

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
  const LocationPicker({super.key, required this.controller});

  final LocationPickerController controller;

  static LocationPicker locationDisplayer(GeoPoint location) {
    return LocationPicker(controller: LocationPickerController(point: location, canMove: false));
  }

  static Future<GeoPoint?> pickLocation(BuildContext context, GeoPoint startLocation) async {
    final LocationPickerController controller = LocationPickerController(point: startLocation);
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
  @override
  Widget build(BuildContext context) {
    final initialPoint = widget.controller.point;
    final styleAsync = ref.read(mapStyleProvider);
    final route = ModalRoute.of(context);

    final isAnimating =
        route?.animation?.status == AnimationStatus.forward || route?.animation?.status == AnimationStatus.reverse;
    log(isAnimating.toString());
    return ClipRSuperellipse(
      borderRadius: .circular(34),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height / 3,
        child: Stack(
          children: [
            if (!isAnimating)
              SizedBox.expand(
                child: SkeletonWidget<String>(
                  builder: (style) => GoogleMap(
                    style: style,
                    scrollGesturesEnabled: widget.controller.canMove,
                    padding: EdgeInsets.zero,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    minMaxZoomPreference: MinMaxZoomPreference(5, 18),
                    initialCameraPosition: CameraPosition(
                      target: LatLng(initialPoint.latitude, initialPoint.longitude),
                      zoom: 8,
                    ),
                    zoomControlsEnabled: false,
                    onCameraMove: (position) {
                      widget.controller.point = GeoPoint(position.target.latitude, position.target.longitude);
                    },
                  ),
                  val: styleAsync,
                  dummyData: '',
                ),
              ),
            Padding(
              padding: EdgeInsets.only(bottom: 40.0),
              child: const Center(child: Icon(Icons.location_on, size: 50)),
            ),
          ],
        ),
      ),
    );
  }
}
