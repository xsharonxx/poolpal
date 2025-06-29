import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController dobController;
  DateTime? selectedDOB;
  String? selectedGender;
  String? selectedRace;
  Uint8List? _profileImage;

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _races = ['Chinese', 'Malay', 'Indian', 'Other'];

  final CropController _cropController = CropController();
  Uint8List? _croppingImage;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.fullName);
    dobController = TextEditingController(text: widget.user.dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(widget.user.dateOfBirth!) : '');
    selectedDOB = widget.user.dateOfBirth;
    selectedGender = widget.user.gender;
    selectedRace = widget.user.race;
  }

  @override
  void dispose() {
    nameController.dispose();
    dobController.dispose();
    super.dispose();
  }

  bool _formValid() {
    return _formKey.currentState?.validate() ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final source = await showModalBottomSheet<ImageSource>(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('Take Photo'),
                                  onTap: () => Navigator.pop(context, ImageSource.camera),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Choose from Gallery'),
                                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (source != null) {
                          final picked = await picker.pickImage(source: source);
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setState(() {
                              _croppingImage = bytes;
                            });
                            showGeneralDialog(
                              context: context,
                              barrierDismissible: true,
                              barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                              pageBuilder: (context, anim1, anim2) {
                                bool isCropping = false;
                                
                                return StatefulBuilder(
                                  builder: (context, setDialogState) {
                                    final double dialogWidth = MediaQuery.of(context).size.width - 16;
                                    return SafeArea(
                                      child: Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            width: dialogWidth,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(24),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Crop Image',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                ),
                                                const SizedBox(height: 16),
                                                SizedBox(
                                                  width: dialogWidth,
                                                  height: 400,
                                                  child: Crop(
                                                    image: _croppingImage!,
                                                    controller: _cropController,
                                                    onCropped: (croppedData) {
                                                      setState(() {
                                                        _profileImage = croppedData;
                                                        _croppingImage = null;
                                                      });
                                                      Navigator.of(context).pop();
                                                    },
                                                    aspectRatio: 1,
                                                    initialSize: 0.8,
                                                    baseColor: Colors.black,
                                                    maskColor: Colors.black.withOpacity(0.4),
                                                    cornerDotBuilder: (size, edgeAlignment) => const DotControl(),
                                                    withCircleUi: true,
                                                  ),
                                                ),
                                                const SizedBox(height: 24),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: isCropping ? null : () => Navigator.of(context).pop(),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                        ),
                                                        child: const Text('Cancel'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: isCropping ? null : () {
                                                          setDialogState(() {
                                                            isCropping = true;
                                                          });
                                                          _cropController.crop();
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.primary,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                                        ),
                                                        child: isCropping
                                                            ? const SizedBox(
                                                                height: 16,
                                                                width: 16,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                                ),
                                                              )
                                                            : const Text('Crop'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }
                        }
                      },
                      child: _profileImage != null
                          ? CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primary,
                              backgroundImage: MemoryImage(_profileImage!),
                            )
                          : (widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty
                              ? CircleAvatar(
                                  radius: 48,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage: NetworkImage(widget.user.photoUrl!),
                                )
                              : CircleAvatar(
                                  radius: 48,
                                  backgroundColor: AppColors.primary,
                                  child: const Icon(Icons.person, size: 48, color: Colors.white),
                                )),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Full Name
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                      ),
                    ),
                    validator: (value) => Validators.validateRequired(value, 'Full Name'),
                  ),
                  const SizedBox(height: 18),
                  // Date of Birth
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDOB ?? DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
                        firstDate: DateTime.now().subtract(const Duration(days: 36500)), // 100 years ago
                        lastDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDOB = picked;
                          dobController.text = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: dobController,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: const Icon(Icons.cake),
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF65B36A)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF65B36A)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                          ),
                        ),
                        validator: (_) => Validators.validateDateOfBirth(selectedDOB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    items: _genders
                        .map((gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => selectedGender = value),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.wc),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                      ),
                    ),
                    validator: (value) => value == null ? 'Gender is required' : null,
                  ),
                  const SizedBox(height: 18),
                  // Race Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedRace,
                    items: _races
                        .map((race) => DropdownMenuItem(
                              value: race,
                              child: Text(race),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => selectedRace = value),
                    decoration: InputDecoration(
                      labelText: 'Race',
                      prefixIcon: const Icon(Icons.flag),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF65B36A)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                      ),
                    ),
                    validator: (value) => value == null ? 'Race is required' : null,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator()),
                              );
                              final user = widget.user;
                              String? photoUrl = user.photoUrl;
                              // Upload new profile image if picked
                              if (_profileImage != null) {
                                final ref = FirebaseStorage.instance.ref().child('profile/${user.uid}.jpg');
                                await ref.putData(_profileImage!, SettableMetadata(contentType: 'image/jpeg'));
                                photoUrl = await ref.getDownloadURL();
                              }
                              // Prepare update data
                              final updateData = {
                                'fullName': nameController.text,
                                'dateOfBirth': dobController.text,
                                'gender': selectedGender,
                                'race': selectedRace,
                                if (photoUrl != null) 'photoUrl': photoUrl,
                              };
                              // Parse dateOfBirth to ISO string if needed
                              if (dobController.text.isNotEmpty) {
                                updateData['dateOfBirth'] = dobController.text;
                              }
                              // Update Firestore
                              await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updateData);
                              // Fetch updated user data and update AuthProvider
                              final updatedDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                              final updatedUser = UserModel.fromMap({'uid': user.uid, ...?updatedDoc.data()});
                              if (mounted) {
                                context.read<AuthProvider>().setUser(updatedUser);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 