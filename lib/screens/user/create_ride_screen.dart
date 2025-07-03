import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import 'location_picker_screen.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CreateRideScreen extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic>? rideData;
  final bool isEdit;

  const CreateRideScreen({
    Key? key,
    required this.user,
    this.rideData,
    this.isEdit = false,
  }) : super(key: key);

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _capacityController = TextEditingController();
  final _fareController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  // Error state booleans
  bool _titleError = false;
  bool _startError = false;
  bool _endError = false;
  bool _vehicleError = false;
  bool _vehicleModelError = false;
  bool _capacityError = false;
  bool _fareError = false;
  bool _dateError = false;
  bool _timeError = false;

  LatLng? _startLatLng;
  LatLng? _endLatLng;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.rideData != null) {
      final data = widget.rideData!;
      _titleController.text = data['title'] ?? '';
      _startController.text = data['start_location']?['name'] ?? '';
      _endController.text = data['end_location']?['name'] ?? '';
      _vehicleController.text = data['vehicle'] ?? '';
      _vehicleModelController.text = data['vehicle_model'] ?? '';
      _capacityController.text = data['capacity']?.toString() ?? '';
      _fareController.text = data['fare']?.toString() ?? '';
      if (data['datetime'] is Timestamp) {
        final dt = (data['datetime'] as Timestamp).toDate();
        _selectedDate = DateTime(dt.year, dt.month, dt.day);
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
      if (data['start_location']?['latitude'] != null && data['start_location']?['longitude'] != null) {
        _startLatLng = LatLng(
          (data['start_location']['latitude'] as num).toDouble(),
          (data['start_location']['longitude'] as num).toDouble(),
        );
      }
      if (data['end_location']?['latitude'] != null && data['end_location']?['longitude'] != null) {
        _endLatLng = LatLng(
          (data['end_location']['latitude'] as num).toDouble(),
          (data['end_location']['longitude'] as num).toDouble(),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startController.dispose();
    _endController.dispose();
    _vehicleController.dispose();
    _vehicleModelController.dispose();
    _capacityController.dispose();
    _fareController.dispose();
    super.dispose();
  }

  Future<void> _submitRide() async {
    setState(() {
      _titleError = _titleController.text.trim().isEmpty;
      _startError = _startController.text.trim().isEmpty;
      _endError = _endController.text.trim().isEmpty;
      _vehicleError = _vehicleController.text.trim().isEmpty;
      _vehicleModelError = _vehicleModelController.text.trim().isEmpty;
      _capacityError = _capacityController.text.trim().isEmpty || int.tryParse(_capacityController.text.trim()) == null || int.parse(_capacityController.text.trim()) <= 0;
      _fareError = _fareController.text.trim().isEmpty || double.tryParse(_fareController.text.trim()) == null || double.parse(_fareController.text.trim()) <= 0;
      _dateError = _selectedDate == null;
      _timeError = _selectedTime == null;
    });

    if (_titleError || _startError || _endError || _vehicleError || _vehicleModelError || _capacityError || _fareError || _dateError || _timeError) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final rideData = {
        'uid': widget.user.uid,
        'title': _titleController.text.trim(),
        'start_location': {
          'name': _startController.text.trim(),
          'latitude': _startLatLng?.latitude,
          'longitude': _startLatLng?.longitude,
        },
        'end_location': {
          'name': _endController.text.trim(),
          'latitude': _endLatLng?.latitude,
          'longitude': _endLatLng?.longitude,
        },
        'vehicle': _vehicleController.text.trim(),
        'vehicle_model': _vehicleModelController.text.trim(),
        'capacity': int.parse(_capacityController.text.trim()),
        'fare': double.parse(_fareController.text.trim()),
        'datetime': Timestamp.fromDate(DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute)),
        'status': 'active',
        'passengers': <String>[],
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.isEdit && widget.rideData != null && widget.rideData!['id'] != null) {
        // Update existing ride (do not overwrite created_at)
        final updateData = Map<String, dynamic>.from(rideData);
        updateData.remove('created_at');
        await FirebaseFirestore.instance.collection('rides').doc(widget.rideData!['id']).update(updateData);
      } else {
        // Create new ride
        await FirebaseFirestore.instance.collection('rides').add({
          ...rideData,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Ride updated successfully!' : 'Ride created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create ride: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Ride' : 'Offer Ride', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ride Details Title
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ride Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Ride Title *',
                      hintText: 'e.g., Morning commute',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.title),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _titleError ? 'Please enter a ride title' : null,
                    ),
                    validator: (_) => null,
                    onChanged: (_) {
                      if (_titleError) setState(() => _titleError = false);
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 16),
                  
                  // Start Location
                  TextFormField(
                    readOnly: true,
                    controller: _startController,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationPickerScreen(
                            title: 'Select Start Location',
                            initialLocation: _startController.text,
                            initialLatLng: _startLatLng,
                          ),
                        ),
                      );
                      
                      if (result != null) {
                        setState(() {
                          _startController.text = result['location'];
                          _startLatLng = result['latLng'] as LatLng?;
                          if (_startError) _startError = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Start Location *',
                      hintText: 'Tap to select start location',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: const Icon(Icons.map),
                      errorText: _startError ? 'Please select start location' : null,
                    ),
                    validator: (_) => null,
                    onChanged: (_) {
                      if (_startError) setState(() => _startError = false);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // End Location
                  TextFormField(
                    readOnly: true,
                    controller: _endController,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationPickerScreen(
                            title: 'Select End Location',
                            initialLocation: _endController.text,
                            initialLatLng: _endLatLng,
                          ),
                        ),
                      );
                      
                      if (result != null) {
                        setState(() {
                          _endController.text = result['location'];
                          _endLatLng = result['latLng'] as LatLng?;
                          if (_endError) _endError = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'End Location *',
                      hintText: 'Tap to select end location',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: const Icon(Icons.map),
                      errorText: _endError
                        ? (_endLatLng != null && _startLatLng != null && _calculateDistance(_startLatLng!.latitude, _startLatLng!.longitude, _endLatLng!.latitude, _endLatLng!.longitude) < 0.01
                            ? 'Cannot be same as start'
                            : 'Please select end location')
                        : null,
                    ),
                    validator: (_) => null,
                    onChanged: (_) {
                      if (_endError) setState(() => _endError = false);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Vehicle
                  TextFormField(
                    controller: _vehicleController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                      UpperCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Vehicle Plate Number *',
                      hintText: 'e.g., WXY 1234',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _vehicleError ? 'Please enter vehicle plate number' : null,
                    ),
                    validator: (_) => null,
                    onChanged: (_) {
                      if (_vehicleError) setState(() => _vehicleError = false);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Vehicle Model
                  TextFormField(
                    controller: _vehicleModelController,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Model *',
                      hintText: 'e.g., Toyota Vios',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.directions_car),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _vehicleModelError ? 'Please enter vehicle model' : null,
                    ),
                    validator: (_) => null,
                    onChanged: (_) {
                      if (_vehicleModelError) setState(() => _vehicleModelError = false);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Capacity
                  TextFormField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Capacity *',
                      hintText: 'e.g., 4',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.people),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _capacityError ? 'Please enter a valid capacity' : null,
                    ),
                    validator: (_) => null,
                    onChanged: (_) {
                      if (_capacityError) setState(() => _capacityError = false);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Departure Date
                  TextFormField(
                    readOnly: true,
                    onTap: () async {
                      final now = DateTime.now();
                      final minDate = now.add(const Duration(hours: 3));
                      final today = DateTime(now.year, now.month, now.day);
                      final tomorrow = today.add(const Duration(days: 1));
                      final firstDate = (minDate.year != now.year || minDate.month != now.month || minDate.day != now.day)
                          ? tomorrow
                          : today;
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? firstDate,
                        firstDate: firstDate,
                        lastDate: today.add(const Duration(days: 30)),
                      );

                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                          if (_dateError) _dateError = false;
                        });
                      }
                    },
                    controller: TextEditingController(
                      text: _selectedDate != null
                          ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                          : '',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Departure Date *',
                      hintText: 'Select departure date',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.calendar_today),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _dateError ? 'Please select departure date' : null,
                    ),
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Departure Time
                  TextFormField(
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                      );

                      if (pickedTime != null) {
                        setState(() {
                          _selectedTime = pickedTime;
                          if (_timeError) _timeError = false;
                        });
                      }
                    },
                    controller: TextEditingController(
                      text: _selectedTime != null
                          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                          : '',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Departure Time *',
                      hintText: 'Select departure time',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.access_time),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _timeError
                        ? (_selectedDate != null && _selectedTime != null
                            ? 'At least 3 hours from now'
                            : 'Please select departure time')
                        : null,
                    ),
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Fare
                  TextFormField(
                    controller: _fareController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Fare per Person (RM) *',
                      hintText: 'e.g., 25.00',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money),
                      filled: true,
                      fillColor: Colors.white,
                      errorText: _fareError ? 'Please enter a valid fare amount' : null,
                    ),
                    validator: (_) => null,
                    onChanged: (_) {
                      if (_fareError) setState(() => _fareError = false);
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            // Validate all fields as before
                            setState(() {
                              _titleError = _titleController.text.trim().isEmpty;
                              _startError = _startController.text.trim().isEmpty;
                              _endError = _endController.text.trim().isEmpty;
                              _vehicleError = _vehicleController.text.trim().isEmpty;
                              _vehicleModelError = _vehicleModelController.text.trim().isEmpty;
                              _capacityError = _capacityController.text.trim().isEmpty || int.tryParse(_capacityController.text.trim()) == null || int.parse(_capacityController.text.trim()) <= 0;
                              _fareError = _fareController.text.trim().isEmpty || double.tryParse(_fareController.text.trim()) == null || double.parse(_fareController.text.trim()) <= 0;
                              _dateError = _selectedDate == null;
                              _timeError = _selectedTime == null;
                              if (_endError) _endError = false;
                            });
                            if (_titleError || _startError || _endError || _vehicleError || _vehicleModelError || _capacityError || _fareError || _dateError || _timeError) {
                              return;
                            }
                            if (_startLatLng != null && _endLatLng != null) {
                              final distance = _calculateDistance(
                                _startLatLng!.latitude, _startLatLng!.longitude,
                                _endLatLng!.latitude, _endLatLng!.longitude,
                              );
                              if (distance < 0.01) {
                                setState(() {
                                  _endError = true;
                                });
                                return;
                              }
                            }
                            final now = DateTime.now();
                            final selectedDateTime = DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                              _selectedTime!.hour,
                              _selectedTime!.minute,
                            );
                            if (selectedDateTime.isBefore(now.add(const Duration(hours: 3)))) {
                              setState(() {
                                _timeError = true;
                              });
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReviewRideScreen(
                                  title: _titleController.text.trim(),
                                  startLocation: _startController.text.trim(),
                                  endLocation: _endController.text.trim(),
                                  vehicle: _vehicleController.text.trim(),
                                  vehicleModel: _vehicleModelController.text.trim(),
                                  capacity: int.parse(_capacityController.text.trim()),
                                  departureDateTime: selectedDateTime,
                                  fare: double.parse(_fareController.text.trim()),
                                  startLatLng: _startLatLng,
                                  endLatLng: _endLatLng,
                                  onCreateRide: () async {
                                    Navigator.pop(context);
                                    await _submitRide();
                                  },
                                  isEdit: widget.isEdit,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Creating Ride...'),
                            ],
                          )
                        : const Text(
                            'Review',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the earth in km
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = R * c;
    return distance;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }
}

// Custom formatter to capitalize all input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class ReviewRideScreen extends StatefulWidget {
  final String title;
  final String startLocation;
  final String endLocation;
  final String vehicle;
  final String vehicleModel;
  final int capacity;
  final DateTime departureDateTime;
  final double fare;
  final LatLng? startLatLng;
  final LatLng? endLatLng;
  final VoidCallback onCreateRide;
  final bool isEdit;

  const ReviewRideScreen({
    Key? key,
    required this.title,
    required this.startLocation,
    required this.endLocation,
    required this.vehicle,
    required this.vehicleModel,
    required this.capacity,
    required this.departureDateTime,
    required this.fare,
    this.startLatLng,
    this.endLatLng,
    required this.onCreateRide,
    this.isEdit = false,
  }) : super(key: key);

  @override
  State<ReviewRideScreen> createState() => _ReviewRideScreenState();
}

class _ReviewRideScreenState extends State<ReviewRideScreen> {
  String? _selectedMarkerId;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    if (widget.startLatLng != null && widget.endLatLng != null) {
      _getRoute();
    }
  }

  Future<void> _getRoute() async {
    if (widget.startLatLng == null || widget.endLatLng == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.startLatLng!.latitude},${widget.startLatLng!.longitude}'
        '&destination=${widget.endLatLng!.latitude},${widget.endLatLng!.longitude}'
        '&key=AIzaSyDNM21ltVcIVErtC6GkPg0QK-TW-6WLu8w'
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final points = route['overview_polyline']['points'];
        _routePoints = _decodePolyline(points);
        
        setState(() {
          _isLoadingRoute = false;
        });
      } else {
        // Fallback to straight line if route not found
        setState(() {
          _routePoints = [widget.startLatLng!, widget.endLatLng!];
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      // Fallback to straight line
      setState(() {
        _routePoints = [widget.startLatLng!, widget.endLatLng!];
        _isLoadingRoute = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final p = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      poly.add(p);
    }
    return poly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Ride'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map as background
          if (widget.startLatLng != null && widget.endLatLng != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _getCenterPoint(widget.startLatLng!, widget.endLatLng!),
                zoom: _getZoomLevel(widget.startLatLng!, widget.endLatLng!),
              ),
              onMapCreated: (GoogleMapController controller) {
                // Fit both markers in view after map is created
                _fitBounds(controller);
              },
              markers: {
                Marker(
                  markerId: const MarkerId('start'), 
                  position: widget.startLatLng!, 
                  infoWindow: const InfoWindow(title: 'Start Location'),
                  onTap: () {
                    setState(() {
                      _selectedMarkerId = 'start';
                    });
                  },
                ),
                Marker(
                  markerId: const MarkerId('end'), 
                  position: widget.endLatLng!, 
                  infoWindow: const InfoWindow(title: 'End Location'),
                  onTap: () {
                    setState(() {
                      _selectedMarkerId = 'end';
                    });
                  },
                ),
              },
              polylines: _routePoints.isNotEmpty ? {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _routePoints,
                  color: Colors.blue,
                  width: 4,
                ),
              } : {},
              onTap: (_) {
                setState(() {
                  _selectedMarkerId = null;
                });
              },
              zoomControlsEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
            ),
          // Loading indicator for route
          if (_isLoadingRoute)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading route...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          // Navigate button - only show when a marker is selected
          if (_selectedMarkerId != null && widget.startLatLng != null && widget.endLatLng != null)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: () {
                  final destination = _selectedMarkerId == 'start' ? widget.startLatLng! : widget.endLatLng!;
                  _openGoogleMaps(destination);
                },
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                mini: true,
                child: const Icon(Icons.navigation),
              ),
            ),
          // Draggable review card
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.25,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _reviewItem('Title:', widget.title),
                      _reviewItem('Start Location:', widget.startLocation),
                      _reviewItem('End Location:', widget.endLocation),
                      _reviewItem('Vehicle Plate Number:', widget.vehicle),
                      _reviewItem('Vehicle Model:', widget.vehicleModel),
                      _reviewItem('Capacity:', widget.capacity.toString()),
                      _reviewItem('Departure:',
                        '${widget.departureDateTime.toLocal()}'.split('.').first.replaceAll('T', ' ')),
                      _reviewItem('Fare per Person (RM):', widget.fare.toStringAsFixed(2)),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: widget.onCreateRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: Text(
                                widget.isEdit ? 'Done' : 'Create Ride',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the earth in km
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = R * c;
    return distance;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  double _getZoomLevel(LatLng start, LatLng end) {
    final distance = _calculateDistance(start.latitude, start.longitude, end.latitude, end.longitude);
    if (distance < 1) {
      return 16;
    } else if (distance < 5) {
      return 14;
    } else if (distance < 20) {
      return 12;
    } else if (distance < 50) {
      return 10;
    } else {
      return 8;
    }
  }

  void _openGoogleMaps(LatLng destination) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}';
    try {
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        // Fallback to general Google Maps URL
        final fallbackUrl = 'https://www.google.com/maps';
        if (await canLaunch(fallbackUrl)) {
          await launch(fallbackUrl);
        }
      }
    } catch (e) {
      print('Error launching Google Maps: $e');
    }
  }

  LatLng _getCenterPoint(LatLng start, LatLng end) {
    return LatLng(
      (start.latitude + end.latitude) / 2,
      (start.longitude + end.longitude) / 2,
    );
  }

  void _fitBounds(GoogleMapController controller) {
    final bounds = LatLngBounds(
      southwest: LatLng(
        min(widget.startLatLng!.latitude, widget.endLatLng!.latitude),
        min(widget.startLatLng!.longitude, widget.endLatLng!.longitude),
      ),
      northeast: LatLng(
        max(widget.startLatLng!.latitude, widget.endLatLng!.latitude),
        max(widget.startLatLng!.longitude, widget.endLatLng!.longitude),
      ),
    );
    
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
  }
} 