import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _extraDayPriceController = TextEditingController();
  String _rentOption = "Te leen";

  final List<File> _imageFiles = [];
  final List<Uint8List> _webImageBytesList = [];

  String? _selectedCategory; 
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories(); 
  }

Future<void> _fetchCategories() async {
  final snapshot = await FirebaseFirestore.instance.collection('Categories').doc('1').get();  
  if (snapshot.exists) {
    final data = snapshot.data() as Map<String, dynamic>;  
    final categories = List<String>.from(data.keys); 
    setState(() {
      _categories = categories;
    });
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blueGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final images = (kIsWeb ? _webImageBytesList : _imageFiles).take(3).toList();

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              ...images.map((img) {
                int index = images.indexOf(
                  img,
                );
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    clipBehavior:
                        Clip.none, 
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child:
                              kIsWeb
                                  ? Image.memory(
                                    img as Uint8List,
                                    fit: BoxFit.cover,
                                  )
                                  : Image.file(img as File, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: -5,
                        top: -5,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (kIsWeb) {
                                _webImageBytesList.removeAt(index);
                              } else {
                                _imageFiles.removeAt(index);
                              }
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey,
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
              }),
              if (images.length < 3)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Container(
                    width: 90,
                    height: 90,
                    child: const Icon(
                      Icons.add_a_photo_rounded,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRentOption() {
    return Row(
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
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    _rentOption == "Te leen"
                        ? Colors.blueGrey
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "Te leen",
                  style: TextStyle(
                    color:
                        _rentOption == "Te leen"
                            ? Colors.white
                            : Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _rentOption = "Te huur";
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color:
                    _rentOption == "Te huur"
                        ? Colors.blueGrey
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "Te huur",
                  style: TextStyle(
                    color:
                        _rentOption == "Te huur"
                            ? Colors.white
                            : Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtraPriceFields() {
    if (_rentOption == "Te huur") {
      return Column(
        children: [
          _buildInputField(
            controller: _priceController,
            label: "Prijs per dag",
          ),
          _buildInputField(
            controller: _extraDayPriceController,
            label: "Prijs per extra dag",
          ),
        ],
      );
    } else {
      return SizedBox.shrink();
    }
  }

 Widget _buildCategoryDropdown() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      value: _selectedCategory,
      onChanged: (newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      items: [
        DropdownMenuItem<String>(
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
        labelStyle: TextStyle(color: Colors.grey),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blueGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        filled: true,
        fillColor: Colors.grey[200],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Center(
                child: Text(
                  "Voeg een nieuw item toe", 
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              SizedBox(height: 50), 
              _buildImageGrid(),
              _buildInputField(controller: _titleController, label: "Titel"),
              _buildInputField(
                controller: _descriptionController,
                label: "Beschrijving",
                maxLines: 3,
              ),
              _buildRentOption(),
              _buildExtraPriceFields(),
              _buildCategoryDropdown(),  
              SizedBox(height: 16),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: () {
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 60), 
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      elevation: 0, 
                    ),
                    child: Text(
                      "Opslaan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
