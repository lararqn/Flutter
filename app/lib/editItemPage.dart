import 'dart:io';
import 'dart:typed_data';
import 'package:app/main.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:app/strings.dart';

class EditItemPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditItemPage({super.key, required this.item});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _extraDayPriceController = TextEditingController();
  String _rentOption = "Te leen";

  final List<File> _imageFiles = [];
  final List<Uint8List> _webImageBytesList = [];
  List<String> _existingImageUrls = [];

  String? _selectedCategory;
  List<String> _categories = [];
  GeoPoint? _itemLocation;
  String? _locationName;
  bool _isAvailable = true;
  bool _isLoadingCategories = true;

  static const Color _primaryColor = Color(0xFF333333); 
  static const Color _accentColor = Color(0xFF4A4A4A); 
  static const Color _borderColor = Color(0xFFDBDBDB); 
  static const Color _inputFillColor = Color(0xFFFAFAFA); 

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _initializeFields();
  }

  Future<void> _fetchCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Categories')
          .doc('1')
          .get();
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final categories = List<String>.from(data.keys).toSet().toList();
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
          if (_selectedCategory != null &&
              !_categories.contains(_selectedCategory)) {
            _selectedCategory = null;
          }
        });
      } else {
        setState(() {
          _isLoadingCategories = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.noCategoriesFound)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.noCategoriesFound}: $e')),
      );
    }
  }

  void _initializeFields() {
    _titleController.text = widget.item['title'] ?? '';
    _descriptionController.text = widget.item['description'] ?? '';
    _selectedCategory = widget.item['category'];
    _rentOption = widget.item['rentOption'] ?? 'Te leen';
    _priceController.text = widget.item['pricePerDay']?.toString() ?? '0.0';
    _extraDayPriceController.text =
        widget.item['extraDayPrice']?.toString() ?? '0.0';
    _existingImageUrls = List<String>.from(widget.item['imageUrls'] ?? []);
    _itemLocation = widget.item['location'] as GeoPoint?;
    _locationName = widget.item['locationName'] ?? 'Locatie niet opgegeven';
    _isAvailable = widget.item['available'] ?? true;
    if (_itemLocation == null) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Locatiediensten zijn uitgeschakeld.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Locatie permissie geweigerd.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Locatie permissie permanent geweigerd.'),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String locationName = 'Onbekende locatie';
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        locationName =
            placemark.locality ??
            placemark.subAdministrativeArea ??
            'Onbekende locatie';
      }

      setState(() {
        _itemLocation = GeoPoint(position.latitude, position.longitude);
        _locationName = locationName;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fout bij ophalen locatie: $e')));
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImageBytesList.add(bytes);
        });
      } else {
        setState(() {
          _imageFiles.add(File(pickedFile.path));
        });
      }
    }
  }

  Future<void> _updateItem() async {
    if (_titleController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.addItemIncomplete)),
      );
      return;
    }

    if (_rentOption == "Te huur") {
      final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
      final extraPrice = double.tryParse(
        _extraDayPriceController.text.replaceAll(',', '.'),
      );
      if (price == null ||
          extraPrice == null ||
          price <= 0 ||
          extraPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vul geldige prijzen in voor verhuur.')),
        );
        return;
      }
    }

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item wordt bijgewerkt...')));

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Je moet ingelogd zijn om een item te bewerken.'),
          ),
        );
        return;
      }

      List<String> imageUrls = List.from(_existingImageUrls);
      final storageRef = FirebaseStorage.instance.ref().child(
        'items/${user.uid}',
      );

      if (kIsWeb) {
        for (var bytes in _webImageBytesList) {
          final ref = storageRef.child(
            '${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await ref.putData(bytes);
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
        }
      } else {
        for (var file in _imageFiles) {
          final ref = storageRef.child(
            '${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await ref.putFile(file);
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
        }
      }

      await FirebaseFirestore.instance
          .collection('Items')
          .doc(widget.item['id'])
          .update({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category': _selectedCategory,
            'pricePerDay':
                _rentOption == "Te huur"
                    ? double.parse(_priceController.text.replaceAll(',', '.'))
                    : 0.0,
            'extraDayPrice':
                _rentOption == "Te huur"
                    ? double.parse(
                        _extraDayPriceController.text.replaceAll(',', '.'),
                      )
                    : 0.0,
            'rentOption': _rentOption,
            'imageUrls': imageUrls,
            'location': _itemLocation,
            'locationName': _locationName,
            'available': _isAvailable,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item succesvol bijgewerkt!')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigation(initialIndex: 0),
        ),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fout bij bewerken item: $e')));
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12), 
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _primaryColor),
          floatingLabelBehavior: FloatingLabelBehavior.auto, 
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _accentColor),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _borderColor),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          filled: true,
          fillColor: _inputFillColor,
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final images = (kIsWeb ? _webImageBytesList : _imageFiles).toList();
    final allImages = [..._existingImageUrls, ...images];

    BoxDecoration inputFieldDecoration = BoxDecoration(
      color: _inputFillColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _borderColor),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          allImages.isEmpty
              ? GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: inputFieldDecoration,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded,
                              color: _primaryColor, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'Afbeelding toevoegen',
                            style: TextStyle(color: _primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ...allImages.asMap().entries.map((entry) {
                        int index = entry.key;
                        var img = entry.value;
                        bool isExisting = index < _existingImageUrls.length;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: inputFieldDecoration,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isExisting
                                      ? Image.network(
                                          img as String,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                                        )
                                      : kIsWeb
                                          ? Image.memory(
                                              img as Uint8List,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              img as File,
                                              fit: BoxFit.cover,
                                            ),
                                ),
                              ),
                              Positioned(
                                right: -5,
                                top: -5,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isExisting) {
                                        _existingImageUrls.removeAt(index);
                                      } else {
                                        int newIndex = index - _existingImageUrls.length;
                                        if (kIsWeb) {
                                          _webImageBytesList.removeAt(newIndex);
                                        } else {
                                          _imageFiles.removeAt(newIndex);
                                        }
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _accentColor,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 8.0),
                          decoration: inputFieldDecoration,
                          child: const Center(
                            child: Icon(Icons.add_a_photo_rounded,
                                color: _primaryColor, size: 30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRentOption() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _rentOption = "Te leen";
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      _rentOption == "Te leen" ? _primaryColor : _inputFillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _rentOption == "Te leen"
                          ? _primaryColor
                          : _borderColor),
                ),
                child: Center(
                  child: Text(
                    "Te leen",
                    style: TextStyle(
                      color: _rentOption == "Te leen"
                          ? Colors.white
                          : _primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _rentOption = "Te huur";
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      _rentOption == "Te huur" ? _primaryColor : _inputFillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _rentOption == "Te huur"
                          ? _primaryColor
                          : _borderColor),
                ),
                child: Center(
                  child: Text(
                    "Te huur",
                    style: TextStyle(
                      color: _rentOption == "Te huur"
                          ? Colors.white
                          : _primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraPriceFields() {
    if (_rentOption == "Te huur") {
      return Column(
        children: [
          _buildInputField(
            controller: _priceController,
            label: "Prijs per dag",
            keyboardType: TextInputType.number,
          ),
          _buildInputField(
            controller: _extraDayPriceController,
            label: "Prijs per extra dag",
            keyboardType: TextInputType.number,
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildCategoryDropdown() {
    if (_isLoadingCategories) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12), 
        child: TextField(
          enabled: false,
          decoration: InputDecoration(
            labelText: "Categorieën laden...",
            labelStyle: const TextStyle(color: _primaryColor),
            floatingLabelBehavior: FloatingLabelBehavior.auto, 
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: _accentColor),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _borderColor),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _borderColor),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            filled: true,
            fillColor: _inputFillColor,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12), 
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        onChanged: (newValue) {
          setState(() {
            _selectedCategory = newValue;
          });
        },
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Selecteer een categorie'),
          ),
          ..._categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(category),
            );
          }).toList(),
        ],
        decoration: InputDecoration(
          labelText: "Categorie",
          labelStyle: const TextStyle(color: _primaryColor),
          floatingLabelBehavior: FloatingLabelBehavior.auto, 
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _accentColor),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _borderColor),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          filled: true,
          fillColor: _inputFillColor,
        ),
        hint: const Text('Selecteer een categorie'),
        style: const TextStyle(color: _primaryColor),
        dropdownColor: Colors.white,
        iconEnabledColor: _primaryColor,
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12), 
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: _inputFillColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Beschikbaar",
              style: TextStyle(fontSize: 16, color: _primaryColor),
            ),
            Switch(
              value: _isAvailable,
              onChanged: (value) {
                setState(() {
                  _isAvailable = value;
                });
              },
              activeColor: _primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Bewerk item",
          style: TextStyle(
            fontSize: 15,
            color: _primaryColor,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: _borderColor,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageSection(),
            _buildInputField(controller: _titleController, label: "Titel"),
            _buildInputField(
              controller: _descriptionController,
              label: "Beschrijving",
              maxLines: 3,
            ),
            _buildRentOption(),
            _buildExtraPriceFields(),
            _buildCategoryDropdown(),
            _buildAvailabilityToggle(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _updateItem,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Bijwerken",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}