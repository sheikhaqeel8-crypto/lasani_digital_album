import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LasaniDigitalAlbumApp());
}

class LasaniDigitalAlbumApp extends StatelessWidget {
  const LasaniDigitalAlbumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lasani Digital Album',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A148C),
          primary: const Color(0xFF4A148C),
          secondary: const Color(0xFFB71C1C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4A148C),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class ProductItem {
  final int? id;
  final String name;
  final String price;
  final String imagePath;

  ProductItem({this.id, required this.name, required this.price, required this.imagePath});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price, 'imagePath': imagePath};
  }

  factory ProductItem.fromMap(Map<String, dynamic> map) {
    return ProductItem(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      imagePath: map['imagePath'],
    );
  }
}

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  static Future<Database> initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'lasani_catalog.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            price TEXT,
            imagePath TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insertProduct(ProductItem product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  static Future<List<ProductItem>> getProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => ProductItem.fromMap(maps[i]));
  }

  static Future<int> updateProduct(ProductItem product) async {
    final db = await database;
    return await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  static Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  List<ProductItem> _products = [];
  String _companyName = 'LV Traders';
  String _companyPhone = '+92 300 0000000';
  String _companyAddress = 'Raja Bazar, Rawalpindi';
  String? _companyLogo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshProducts();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _companyName = prefs.getString('c_name') ?? 'LV Traders';
      _companyPhone = prefs.getString('c_phone') ?? '+92 300 0000000';
      _companyAddress = prefs.getString('c_address') ?? 'Raja Bazar, Rawalpindi';
      _companyLogo = prefs.getString('c_logo');
    });
  }

  Future<void> _refreshProducts() async {
    final data = await DatabaseHelper.getProducts();
    setState(() {
      _products = data;
    });
  }

  Future<void> _addBulkProducts() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isEmpty) return;

    if (!mounted) return;

    for (int i = 0; i < pickedFiles.length; i++) {
      final nameController = TextEditingController(text: 'Item ${i + 1}');
      final priceController = TextEditingController(text: '0');

      bool? saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Edit Item ${i + 1} of ${pickedFiles.length}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Image.file(File(pickedFiles[i].path), fit: BoxFit.cover),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name / Code', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (Rs.)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Item'),
            ),
          ],
        ),
      );

      if (saved == true) {
        await DatabaseHelper.insertProduct(
          ProductItem(
            name: nameController.text,
            price: priceController.text,
            imagePath: pickedFiles[i].path,
          ),
        );
      }
    }

    _refreshProducts();
  }

  Future<void> _editProduct(ProductItem item) async {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name / Code')),
            const SizedBox(height: 12),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (item.id != null) {
                await DatabaseHelper.updateProduct(
                  ProductItem(
                    id: item.id,
                    name: nameController.text,
                    price: priceController.text,
                    imagePath: item.imagePath,
                  ),
                );
                if (context.mounted) Navigator.pop(context);
                _refreshProducts();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePDF() async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    if (_companyLogo != null && File(_companyLogo!).existsSync()) {
      logoImage = pw.MemoryImage(File(_companyLogo!).readAsBytesSync());
    }

    List<pw.Widget> productWidgets = [];
    for (var item in _products) {
      pw.MemoryImage? img;
      if (File(item.imagePath).existsSync()) {
        img = pw.MemoryImage(File(item.imagePath).readAsBytesSync());
      }

      productWidgets.add(
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              img != null
                  ? pw.Expanded(child: pw.Image(img, fit: pw.BoxFit.contain))
                  : pw.Expanded(child: pw.Container(color: PdfColors.grey200)),
              pw.SizedBox(height: 6),
              pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.SizedBox(height: 2),
              pw.Text('Rs. ${item.price}', style: const pw.TextStyle(color: PdfColors.red900, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('4A148C'))),
                  pw.Text(_companyAddress, style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(_companyPhone, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (logoImage != null) pw.Container(height: 40, width: 40, child: pw.Image(logoImage)),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.GridView(
            crossAxisCount: 3,
            childAspectRatio: 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: productWidgets,
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Lasani_Digital_Album_Catalog.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Lasani Digital Album Catalog');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_companyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CompanySettingsScreen(
                    name: _companyName,
                    phone: _companyPhone,
                    address: _companyAddress,
                    logo: _companyLogo,
                    onSave: _loadSettings,
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: _products.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No products added yet.\nTap below to select multiple images from gallery!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final p = _products[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _editProduct(p),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Image.file(File(p.imagePath), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          color: Colors.white,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('Rs. ${p.price}', style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  if (p.id != null) {
                                    await DatabaseHelper.deleteProduct(p.id!);
                                    _refreshProducts();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "bulk_add",
            backgroundColor: const Color(0xFFB71C1C),
            onPressed: _addBulkProducts,
            icon: const Icon(Icons.library_add, color: Colors.white),
            label: const Text("Add Bulk Images", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "share_pdf",
            backgroundColor: const Color(0xFF4A148C),
            onPressed: _generateAndSharePDF,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text("Export A4 PDF Catalog", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class CompanySettingsScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String address;
  final String? logo;
  final VoidCallback onSave;

  const CompanySettingsScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    this.logo,
    required this.onSave,
  });

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  late TextEditingController nameC;
  late TextEditingController phoneC;
  late TextEditingController addressC;
  String? currentLogo;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController(text: widget.name);
    phoneC = TextEditingController(text: widget.phone);
    addressC = TextEditingController(text: widget.address);
    currentLogo = widget.logo;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Company Settings")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null) {
                  setState(() => currentLogo = img.path);
                }
              },
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF4A148C),
                backgroundImage: currentLogo != null ? FileImage(File(currentLogo!)) : null,
                child: currentLogo == null
                    ? const Icon(Icons.add_a_photo, color: Colors.white, size: 32)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            const Text("Tap to change company logo", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Company Name", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: addressC, decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('c_name', nameC.text);
                  await prefs.setString('c_phone', phoneC.text);
                  await prefs.setString('c_address', addressC.text);
                  if (currentLogo != null) {
                    await prefs.setString('c_logo', currentLogo!);
                  }
                  widget.onSave();
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("Save Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
