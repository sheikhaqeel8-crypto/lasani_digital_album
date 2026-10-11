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
        primaryColor: const Color(0xFF800020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B11B0),
          primary: const Color(0xFFB31217),
          secondary: const Color(0xFF6B11B0),
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF8FC),
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
    final path = p.join(docsDir.path, 'lasani_album.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            price TEXT,
            imagePath TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insertProduct(ProductItem item) async {
    final db = await database;
    return await db.insert('products', item.toMap());
  }

  static Future<List<ProductItem>> getProducts() async {
    final db = await database;
    final res = await db.query('products');
    return res.map((e) => ProductItem.fromMap(e)).toList();
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
  List<ProductItem> products = [];
  String companyName = "Lasani Cloth House";
  String companyPhone = "0300-1234567";
  String companyAddress = "Main Cloth Market, Rawalpindi";
  String? logoPath;

  @override
  void initState() {
    super.initState();
    _loadCompanySettings();
    _refreshProducts();
  }

  Future<void> _loadCompanySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      companyName = prefs.getString('c_name') ?? companyName;
      companyPhone = prefs.getString('c_phone') ?? companyPhone;
      companyAddress = prefs.getString('c_address') ?? companyAddress;
      logoPath = prefs.getString('c_logo');
    });
  }

  Future<void> _refreshProducts() async {
    final list = await DatabaseHelper.getProducts();
    setState(() {
      products = list;
    });
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    XFile? pickedImg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text("نئی پروڈکٹ شامل کریں", style: TextStyle(color: Color(0xFF6B11B0))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (img != null) {
                      setDlgState(() => pickedImg = img);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      border: Border.all(color: const Color(0xFFB31217)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: pickedImg == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: Color(0xFFB31217), size: 40),
                              Text("تصویر منتخب کریں"),
                            ],
                          )
                        : Image.file(File(pickedImg!.path), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "پروڈکٹ کا نام"),
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "قیمت (Rs.)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("کینسل")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB31217)),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty && pickedImg != null) {
                  await DatabaseHelper.insertProduct(ProductItem(
                    name: nameCtrl.text,
                    price: priceCtrl.text,
                    imagePath: pickedImg!.path,
                  ));
                  Navigator.pop(ctx);
                  _refreshProducts();
                }
              },
              child: const Text("سیو کریں", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanySettingsScreen(
          name: companyName,
          phone: companyPhone,
          address: companyAddress,
          logo: logoPath,
          onSave: _loadCompanySettings,
        ),
      ),
    );
  }

  Future<void> _generateAndSharePDF() async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImg;
    if (logoPath != null && File(logoPath!).existsSync()) {
      logoImg = pw.MemoryImage(File(logoPath!).readAsBytesSync());
    }

    // A4 12 items grid calculation
    int totalPages = (products.length / 12).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int p = 0; p < totalPages; p++) {
      int start = p * 12;
      int end = (start + 12 < products.length) ? start + 12 : products.length;
      List<ProductItem> pageProducts = products.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Header
                pw.Row(
                  main: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logoImg != null)
                      pw.Container(width: 50, height: 50, child: pw.Image(logoImg))
                    else
                      pw.SizedBox(width: 50),
                    pw.Column(
                      children: [
                        pw.Text(companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900)),
                        pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Ph: $companyPhone", style: const pw.TextStyle(fontSize: 10, color: PdfColors.red900)),
                      ],
                    ),
                    pw.SizedBox(width: 50),
                  ],
                ),
                pw.Divider(thickness: 1, color: PdfColors.red),
                pw.SizedBox(height: 10),

                // 12 Items Grid Layout
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: List.generate(12, (index) {
                      if (index < pageProducts.length) {
                        final item = pageProducts[index];
                        final imgFile = File(item.imagePath);
                        pw.MemoryImage? itemImg;
                        if (imgFile.existsSync()) {
                          itemImg = pw.MemoryImage(imgFile.readAsBytesSync());
                        }

                        return pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.purple200),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Expanded(
                                child: itemImg != null
                                    ? pw.Image(itemImg, fit: pw.BoxFit.cover)
                                    : pw.Container(color: PdfColors.grey200),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(item.name, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.Text("Rs. ${item.price}", style: pw.TextStyle(fontSize: 9, color: PdfColors.red800, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        );
                      } else {
                        // Empty slot placeholder
                        return pw.Container(
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300, style: pw.BorderStyle.dashed),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                        );
                      }
                    }),
                  ),
                ),
                pw.Text("Generated by Lasani Digital Album", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ],
            );
          },
        ),
      );
    }

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/lasani_catalog.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: '$companyName - Digital Catalog');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("لسانی ڈیجیٹل البم", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _openSettingsScreen),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF6B11B0).withOpacity(0.08),
            child: Row(
              children: [
                logoPath != null && File(logoPath!).existsSync()
                    ? CircleAvatar(backgroundImage: FileImage(File(logoPath!)), radius: 25)
                    : const CircleAvatar(backgroundColor: Color(0xFFB31217), radius: 25, child: Icon(Icons.business, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: Cross-AxisAlignment.start,
                    children: [
                      Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("$companyAddress | $companyPhone", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text("کوئی پروڈکٹ موجود نہیں۔ نچلے بٹن سے شامل کریں!"))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: products.length,
                    itemBuilder: (ctx, i) {
                      final item = products[i];
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.shade100),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    child: Image.file(File(item.imagePath), fit: BoxFit.cover, width: double.infinity),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    children: [
                                      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text("Rs. ${item.price}", style: const TextStyle(color: Color(0xFFB31217), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () async {
                                await DatabaseHelper.deleteProduct(item.id!);
                                _refreshProducts();
                              },
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "add",
            backgroundColor: const Color(0xFFB31217),
            onPressed: _showAddProductDialog,
            child: const Icon(Icons.add, color: Colors.white),
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
              TextField(controller: addressC, decoration: const InputDecoration(labelText: "ایڈریس")),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  b
