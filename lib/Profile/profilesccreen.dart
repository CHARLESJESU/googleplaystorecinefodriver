import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:production/Screens/Home/colorcode.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class Profilesccreen extends StatefulWidget {
  const Profilesccreen({super.key});

  @override
  State<Profilesccreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<Profilesccreen> {
  File? _profileImage;
  Map<String, dynamic>? loginData;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });

      // Persist selected image path into the local DB so it remains across app restarts.
      try {
        final dbPath = await getDatabasesPath();
        final db = await openDatabase(path.join(dbPath, 'production_login.db'));
        // Update all rows (assumes single login row). Adjust WHERE clause if you have an id.
        await db.rawUpdate('UPDATE login_data SET profile_image = ?', [pickedFile.path]);
        // Also update the in-memory loginData map so UI updates immediately
        setState(() {
          if (loginData != null) loginData!['profile_image'] = pickedFile.path;
        });
        await db.close();
      } catch (e) {
        // ignore DB save errors but keep the picked image in memory
        print('Failed to persist profile image path: $e');
      }
    }
  }

  Future<void> _checkImageUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: 10);
      final request = await client.getUrl(uri);
      // you can add headers if needed: request.headers.add('Authorization', 'Bearer ...');
      final response = await request.close();
      debugPrint('Image URL check: status=${response.statusCode}, contentType=${response.headers.contentType} for $url');
      // Optionally read a few bytes to ensure data flows
      final firstBytes = await response.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
      debugPrint('Image URL check: received ${firstBytes.length} bytes');
      client.close(force: true);
    } catch (e) {
      debugPrint('Image URL check failed for $url: $e');
    }
  }

  Future<void> _fetchLoginData() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(path.join(dbPath, 'production_login.db'));
    final List<Map<String, dynamic>> loginMaps = await db.query('login_data');
    if (loginMaps.isNotEmpty) {
      setState(() {
        loginData = loginMaps.first;
      });

      // If profile_image is a network URL, perform a quick diagnostic request
      final img = loginData?['profile_image'];
      if (img is String && (img.startsWith('http://') || img.startsWith('https://'))) {
        _checkImageUrl(img);
      }
    }
    await db.close();
  }

  // Helper to choose the correct ImageProvider for the CircleAvatar
  ImageProvider? _getProfileImageProvider() {
    // If user picked an image during this session, use it first
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }

    final img = loginData?['profile_image'];
    print("img: $img");
    if (img == null) return null;

    if (img is String) {
      final s = img.trim();
      if (s.isEmpty) return null;

      // Network URL
      if (s.startsWith('http://') || s.startsWith('https://')) {
        return NetworkImage(s);
      }

      // Local file path on device
      try {
        final file = File(s);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (e) {
        // ignore and try asset below
      }

      // Fallback to asset image (assumes string is asset path)
      try {
        return AssetImage(s);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  // Helper widget that builds the avatar with proper loading/error handling
  Widget _buildAvatarWidget(double radius) {
    final provider = _getProfileImageProvider();

    // If no provider, show a default CircleAvatar with an icon
    if (provider == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: Icon(Icons.person, size: radius * 0.6, color: Colors.grey[700]),
      );
    }

    // Use different builders depending on provider type
    if (provider is NetworkImage) {
      final url = provider.url;
      return ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          color: Colors.white,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            // show a small spinner while loading
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: SizedBox(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                ),
              );
            },
            // show fallback on error
            errorBuilder: (context, error, stackTrace) {
              // Log error for debugging
              debugPrint('Avatar network image load error: $error');
              return Center(
                child: Icon(Icons.person, size: radius * 0.6, color: Colors.grey[700]),
              );
            },
          ),
        ),
      );
    }

    if (provider is FileImage) {
      try {
        return ClipOval(
          child: Container(
            width: radius * 2,
            height: radius * 2,
            color: Colors.white,
            child: Image.file(
              provider.file,
              fit: BoxFit.cover,
              width: radius * 2,
              height: radius * 2,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Avatar file image load error: $error');
                return Center(
                  child: Icon(Icons.person, size: radius * 0.6, color: Colors.grey[700]),
                );
              },
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error building FileImage avatar: $e');
      }
    }

    if (provider is AssetImage) {
      try {
        return ClipOval(
          child: Container(
            width: radius * 2,
            height: radius * 2,
            color: Colors.white,
            child: Image(image: provider, fit: BoxFit.cover),
          ),
        );
      } catch (e) {
        debugPrint('Error building AssetImage avatar: $e');
      }
    }

    // Fallback
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Icon(Icons.person, size: radius * 0.6, color: Colors.grey[700]),
    );
  }

  Widget buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(label, style: TextStyle(color: Colors.white70))),
          SizedBox(width: 16), // Add horizontal space between label and value
          Expanded(
            child: Text(
              value,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchLoginData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            const Text('Profile Info', style: TextStyle(color: Colors.white)),
      ),
      body: loginData == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 10),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Use our robust avatar builder so we can show loading/error states
                    _buildAvatarWidget(55),
                    Positioned(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: const CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.blue,
                          child:
                              Icon(Icons.edit, size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loginData?["manager_name"] ?? '',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.white24, height: 30, thickness: 1),
                buildProfileField('Name', loginData?["manager_name"] ?? ''),
                buildProfileField('Mobile', loginData?['mobile_number'] ?? ''),
                buildProfileField('Designation', loginData?['subUnitName'] ?? ''),
                buildProfileField(
                    'Production House', loginData?["production_house"] ?? ''),
              ],
            ),
    );
  }
}
