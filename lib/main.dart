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
        primaryColor: const Color(0xFF6B11B0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B11B0),
          primary: const Color(0xFFB31217),
          secondary: const Color(0xFF6B11B0),
        ),
        scaffoldBackgroundColor: const Color(0xFFFBFBFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF6B11B0),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

// Data Model for Products
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

// Database Helper for local saving
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

  Future<void> _addProduct() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final nameController = TextEditingController();
    final priceController = TextEditingController();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پروڈکٹ شامل کریں'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'نام/کوڈ')),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'قیمت')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('منسوخ')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await DatabaseHelper.insertProduct(
                  ProductItem(
                    name: nameController.text,
                    price: priceController.text,
                    imagePath: pickedFile.path,
                  ),
                );
                if (context.mounted) Navigator.pop(context);
                _refreshProducts();
              }
            },
            child: const Text('محفوظ کریں'),
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
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              img != null
                  ? pw.Expanded(child: pw.Image(img, fit: pw.BoxFit.contain))
                  : pw.Container(height: 80, color: PdfColors.grey200),
              pw.SizedBox(height: 4),
              pw.Text(item.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Rs. ${item.price}', style: const pw.TextStyle(color: PdfColors.red900, fontSize: 9)),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.bottom(10),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('6B11B0'))),
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
            childAspectRatio: 0.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: productWidgets,
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Lasani_Catalog.pdf');
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
          ? const Center(child: Text('کوئی پروڈکٹ موجود نہیں ہے۔ نیچے بٹن پر کلک کر کے شامل کریں۔'))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final p = _products[index];
                return Card(
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Image.file(File(p.imagePath), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Rs. ${p.price}', style: const TextStyle(color: Color(0xFFB31217))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          if (p.id != null) {
                            await DatabaseHelper.deleteProduct(p.id!);
                            _refreshProducts();
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "add",
            backgroundColor: const Color(0xFFB31217),
            onPressed: _addProduct,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("آئٹم شامل کریں", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "share",
            backgroundColor: const Color(0xFF6B11B0),
            onPressed: _generateAndSharePDF,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text("A4 PDF بنائیں", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Company Settings Screen
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
      appBar: AppBar(title: const Text("کمپنی کی سیٹنگز")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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
                  radius: 45,
                  backgroundColor: const Color(0xFF6B11B0),
                  backgroundImage: currentLogo != null ? FileImage(File(currentLogo!)) : null,
                  child: currentLogo == null
                      ? const Icon(Icons.add_a_photo, color: Colors.white, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              const Text("لوگو تبدیل کرنے کے لیے ٹیپ کریں"),
              const SizedBox(height: 20),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: "کمپنی کا نام")),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: "فون نمبر")),
              TextField(controller: addressC, decoration: const InputDecoration(labelText: "پتہ")),
              const SizedBox(height: 30),
              ElevatedButton(
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B11B0)),
                child: const Text("سیٹنگز محفوظ کریں", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
