import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const KnaufApp());
}

class KnaufApp extends StatelessWidget {
  const KnaufApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'КНАУФ МП 75',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),
          primary: const Color(0xFFFF5722),
          secondary: const Color(0xFF212121),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF5722),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// Полноэкранный стартовый экран
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Задержка 2.5 секунды, затем переход на калькулятор
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CalcScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'app_icon.png',
          // Картинка на 75% ширины экрана — теперь точно сытая и крупная!
          width: screenWidth * 0.75, 
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// Экран калькулятора
class CalcScreen extends StatefulWidget {
  const CalcScreen({super.key});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _hCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _tCtrl = TextEditingController();
  
  double _area = 0, _weight = 0, _water = 0, _bags = 0;

  @override
  void initState() {
    super.initState();
    _loadH();
    _hCtrl.addListener(() {
      _saveH(_hCtrl.text);
      _calc();
    });
    _wCtrl.addListener(_calc);
    _tCtrl.addListener(_calc);
  }

  void _loadH() async {
    final p = await SharedPreferences.getInstance();
    _hCtrl.text = p.getString('h') ?? '';
  }

  void _saveH(String v) async {
    final p = await SharedPreferences.getInstance();
    p.setString('h', v);
  }

  void _calc() {
    final h = double.tryParse(_hCtrl.text.replaceAll(',', '.')) ?? 0;
    final w = double.tryParse(_wCtrl.text.replaceAll(',', '.')) ?? 0;
    final t = double.tryParse(_tCtrl.text.replaceAll(',', '.')) ?? 0;

    if (h > 0 && w > 0 && t > 0) {
      final a = h * w;
      final kg = a * (t / 10.0) * 10.0;
      setState(() {
        _area = a;
        _weight = kg;
        _water = kg * 0.6;
        _bags = kg / 30;
      });
    } else {
      setState(() {
        _area = 0;
        _weight = 0;
        _water = 0;
        _bags = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('КНАУФ МП 75', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Очистить',
            onPressed: () {
              _wCtrl.clear();
              _tCtrl.clear();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: const Color(0xFF212121),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _hCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Высота помещения (м)',
                    labelStyle: TextStyle(color: Colors.orangeAccent),
                    suffixText: 'м',
                    suffixStyle: TextStyle(color: Colors.white),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ширина (м)',
                      suffixText: 'м',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Толщина слоя (мм)',
                      suffixText: 'мм',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.aspect_ratio, color: Color(0xFFFF5722)),
                      title: const Text('Площадь стен'),
                      trailing: Text('${_area.toStringAsFixed(2)} м²', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.scale, color: Color(0xFFFF5722)),
                      title: const Text('Сухая смесь'),
                      trailing: Text('${_weight.toStringAsFixed(1)} кг', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.water_drop, color: Colors.blue),
                      title: const Text('Расход воды'),
                      trailing: Text('${_water.toStringAsFixed(1)} л', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.inventory_2, color: Color(0xFF212121)),
                      title: const Text('Мешки (по 30 кг)'),
                      trailing: Text('${_bags.toStringAsFixed(1)} шт.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Точное значение (дробное)'),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}