import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/constants.dart';
import 'package:google_places_flutter/google_places_flutter.dart';

const String kGoogleApiKey = "AIzaSyDNM21ltVcIVErtC6GkPg0QK-TW-6WLu8w"; // <-- Inserted actual key

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final String? initialLocation;
  final LatLng? initialLatLng;

  const LocationPickerScreen({
    Key? key,
    required this.title,
    this.initialLocation,
    this.initialLatLng,
  }) : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _center;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatLng != null) {
      _center = widget.initialLatLng;
      _selectedLocation = widget.initialLatLng;
      _getAddressFromLatLng(widget.initialLatLng!);
    } else {
      _getCurrentLocation();
    }
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _center = const LatLng(3.1390, 101.6869);
          _selectedLocation = _center;
        });
        await _getAddressFromLatLng(_center!);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are denied.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _center = const LatLng(3.1390, 101.6869);
            _selectedLocation = _center;
          });
          await _getAddressFromLatLng(_center!);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _center = const LatLng(3.1390, 101.6869);
          _selectedLocation = _center;
        });
        await _getAddressFromLatLng(_center!);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _selectedLocation = _center;
      });
      await _getAddressFromLatLng(_center!);
      // Animate camera to current location
      _mapController?.animateCamera(CameraUpdate.newLatLng(_center!));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _center = const LatLng(3.1390, 101.6869);
        _selectedLocation = _center;
      });
      await _getAddressFromLatLng(_center!);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _selectedAddress = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ].where((element) => element != null && element.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      // Remove all print statements
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _searchController.clear();
    });
    _getAddressFromLatLng(latLng);
  }

  void _confirmLocation() {
    if (_selectedLocation != null && _selectedAddress.isNotEmpty) {
      Navigator.pop(context, {
        'location': _selectedAddress,
        'latLng': _selectedLocation,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location on the map.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: false,
      body: _center == null
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6BC1D1),
                    Color(0xFF9CE09D),
                  ],
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6BC1D1),
                    Color(0xFF9CE09D),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Google Map
                  GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: _center!,
                      zoom: 15.0,
                    ),
                    onTap: _onMapTap,
                    markers: _selectedLocation != null
                        ? {
                            Marker(
                              markerId: const MarkerId('selected_location'),
                              position: _selectedLocation!,
                              infoWindow: InfoWindow(
                                title: 'Selected Location',
                                snippet: _selectedAddress,
                              ),
                            ),
                          }
                        : {},
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                  
                  // Search Bar
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: GooglePlaceAutoCompleteTextField(
                                textEditingController: _searchController,
                                focusNode: _searchFocusNode,
                                googleAPIKey: kGoogleApiKey,
                                inputDecoration: const InputDecoration(
                                  hintText: 'Search for places',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                ),
                                debounceTime: 400,
                                countries: ['my'], // restrict to Malaysia
                                isLatLngRequired: true,
                                getPlaceDetailWithLatLng: (prediction) async {
                                  if (prediction.lat != null && prediction.lng != null) {
                                    final lat = double.tryParse(prediction.lat!);
                                    final lng = double.tryParse(prediction.lng!);
                                    if (lat != null && lng != null) {
                                      setState(() {
                                        _center = LatLng(lat, lng);
                                        _selectedLocation = _center;
                                        _selectedAddress = prediction.description ?? '';
                                        _searchController.text = prediction.description ?? '';
                                      });
                                      _mapController?.animateCamera(CameraUpdate.newLatLng(_center!));
                                    }
                                  }
                                },
                                itemClick: (prediction) {
                                  _searchController.text = prediction.description ?? '';
                                  _searchController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _searchController.text.length),
                                  );
                                  _searchFocusNode.unfocus();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Current Location Button
                  Positioned(
                    top: 120,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _getCurrentLocation,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      mini: true,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                  
                  // Selected Location Info
                  if (_selectedLocation != null)
                    Positioned(
                      bottom: 100,
                      left: 16,
                      right: 16,
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Selected Location:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedAddress.isNotEmpty ? _selectedAddress : 'Loading address...',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Confirm Button
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: ElevatedButton(
                      onPressed: _selectedLocation != null ? _confirmLocation : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  // Loading Indicator
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
} 