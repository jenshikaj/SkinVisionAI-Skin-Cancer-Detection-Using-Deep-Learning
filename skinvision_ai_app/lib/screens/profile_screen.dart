import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/app_notification.dart';
import '../services/cloudinary_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser!;
  bool _editing = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = 'Prefer not to say';
  String? _photoUrl;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameCtrl.text = data['name'] ?? _user.displayName ?? '';
          _phoneCtrl.text = data['phone'] ?? '';
          _ageCtrl.text = data['age']?.toString() ?? '';
          _gender = data['gender'] ?? 'Prefer not to say';
          _photoUrl = data['photoUrl'] ?? _user.photoURL;
          _loading = false;
        });
      } else {
        setState(() {
          _nameCtrl.text = _user.displayName ?? '';
          _photoUrl = _user.photoURL;
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      // Upload to Cloudinary
      final url = await CloudinaryService.uploadImage(
        File(picked.path),
        folder: 'skinvision/avatars/${_user.uid}',
      );

      // Save URL to Firestore and Firebase Auth
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({'photoUrl': url});
      await _user.updatePhotoURL(url);

      setState(() => _photoUrl = url);
      if (!mounted) return;
      AppNotification.success(context, 'Profile photo updated!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, 'Photo upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _user.email,
        'phone': _phoneCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'gender': _gender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _user.updateDisplayName(_nameCtrl.text.trim());

      if (!mounted) return;
      AppNotification.success(context, 'Profile updated successfully!');
      setState(() => _editing = false);
    } catch (_) {
      if (!mounted) return;
      AppNotification.error(context, 'Failed to save profile. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white),
                              ),
                              const Expanded(
                                child: Text(
                                  'My Profile',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  if (_editing) {
                                    _saveProfile();
                                  } else {
                                    setState(() => _editing = true);
                                  }
                                },
                                icon: Icon(
                                  _editing
                                      ? Icons.check_rounded
                                      : Icons.edit_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _editing ? 'Save' : 'Edit',
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Avatar with Cloudinary upload
                        GestureDetector(
                          onTap: _editing ? _pickAndUploadPhoto : null,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _uploadingPhoto
                                      ? Container(
                                          color:
                                              AppTheme.primary.withOpacity(0.3),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : _photoUrl != null &&
                                              _photoUrl!.isNotEmpty
                                          ? Image.network(
                                              _photoUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _defaultAvatar(),
                                            )
                                          : _defaultAvatar(),
                                ),
                              ),
                              if (_editing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _profileField(
                                label: 'Full Name',
                                controller: _nameCtrl,
                                icon: Icons.person_outline_rounded,
                                enabled: _editing,
                              ),
                              const SizedBox(height: 14),
                              _profileField(
                                label: 'Email',
                                controller: TextEditingController(
                                    text: _user.email ?? ''),
                                icon: Icons.mail_outline_rounded,
                                enabled: false,
                              ),
                              const SizedBox(height: 14),
                              _profileField(
                                label: 'Phone Number',
                                controller: _phoneCtrl,
                                icon: Icons.phone_outlined,
                                enabled: _editing,
                                keyboard: TextInputType.phone,
                              ),
                              const SizedBox(height: 14),
                              _profileField(
                                label: 'Age',
                                controller: _ageCtrl,
                                icon: Icons.cake_outlined,
                                enabled: _editing,
                                keyboard: TextInputType.number,
                              ),
                              const SizedBox(height: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gender',
                                    style: TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _editing
                                          ? Colors.white
                                          : AppTheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _editing
                                            ? AppTheme.primary.withOpacity(0.4)
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _gender,
                                        isExpanded: true,
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down_rounded),
                                        style: const TextStyle(
                                          fontFamily: 'Nunito',
                                          color: AppTheme.textDark,
                                          fontSize: 14,
                                        ),
                                        onChanged: _editing
                                            ? (v) =>
                                                setState(() => _gender = v!)
                                            : null,
                                        items: [
                                          'Male',
                                          'Female',
                                          'Other',
                                          'Prefer not to say',
                                        ]
                                            .map((g) => DropdownMenuItem(
                                                  value: g,
                                                  child: Text(g),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              label: const Text('Sign Out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.danger,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
          if (_saving)
            Container(
              color: Colors.black38,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppTheme.primary.withOpacity(0.2),
      child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
    );
  }

  Widget _profileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboard,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: AppTheme.textDark,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
            filled: true,
            fillColor: enabled ? Colors.white : AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
