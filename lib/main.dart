import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beacon_calculator.dart';
import 'room_planner.dart';
import 'dart:convert';  // для jsonEncode и jsonDecode
import 'saved_rooms_screen.dart';

// ========== СТРУКТУРЫ ДАННЫХ ДЛЯ КОМНАТ ==========

class RoomData {
  final String id;
  final String name;
  final List<WallData> walls;
  final double totalLength;

  RoomData({
    required this.id,
    required this.name,
    required this.walls,
    required this.totalLength,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'walls': walls.map((w) => w.toJson()).toList(),
    'totalLength': totalLength,
  };

  factory RoomData.fromJson(Map<String, dynamic> json) => RoomData(
    id: json['id'],
    name: json['name'],
    walls: (json['walls'] as List).map((w) => WallData.fromJson(w)).toList(),
    totalLength: json['totalLength'],
  );
}

class WallData {
  final int id;
  final double height;
  final double width;
  final double layerThickness;

  WallData({
    required this.id,
    required this.height,
    required this.width,
    required this.layerThickness,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'height': height,
    'width': width,
    'layerThickness': layerThickness,
  };

  factory WallData.fromJson(Map<String, dynamic> json) => WallData(
    id: json['id'],
    height: json['height'],
    width: json['width'],
    layerThickness: json['layerThickness'],
  );
}

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
  final double? initialHeight;
  final double? initialWidth;
  final double? initialThickness;

  const CalcScreen({
    super.key,
    this.initialHeight,
    this.initialWidth,
    this.initialThickness,
  });

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _hCtrl = TextEditingController();
  final _wCtrl = TextEditingController();
  final _tCtrl = TextEditingController();
  
  double _area = 0, _weight = 0, _water = 0, _bags = 0;

  List<RoomPlan> _rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRoomsFromStorage();
    _applyInitialData(); // <-- ДОБАВИТЬ
    _loadH(); // <-- ПОТОМ ЗАГРУЖАЕМ СОХРАНЁННУЮ ВЫСОТУ (ЕСЛИ НЕТ ДАННЫХ ИЗ КОМНАТЫ)
    _hCtrl.addListener(() {
      _saveH(_hCtrl.text);
      _calc();
    });
    _wCtrl.addListener(_calc);
    _tCtrl.addListener(_calc);
  }
  
  void _loadH() async {
    final p = await SharedPreferences.getInstance();
    final savedHeight = p.getString('h') ?? '';
    
    // Если есть переданное значение из комнаты — используем его
    if (widget.initialHeight != null) {
      _hCtrl.text = widget.initialHeight!.toString();
    } else if (savedHeight.isNotEmpty) {
      _hCtrl.text = savedHeight;
    }
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

  void _applyInitialData() {
    final args = widget;
    if (args.initialHeight != null) {
      _hCtrl.text = args.initialHeight!.toString();
    }
    if (args.initialWidth != null) {
      _wCtrl.text = args.initialWidth!.toString();
    }
    if (args.initialThickness != null) {
      _tCtrl.text = args.initialThickness!.toString();
    }
    _calc();
  }

    // ============ ВСТАВЬ СЮДА ============
  void _openRoomPlanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomPlanner(
          onSave: (room) {
            setState(() {
              _rooms.add(room);
            });
            _saveRoomsToStorage();  // ← СОХРАНЯЕМ В ПАМЯТЬ
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Сохранено: ${room.name} (${room.walls.length} стен)'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }
  // ====================================

  // Функция для сохранения в SharedPreferences или SQLite
  Future<void> _saveRoomsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = _rooms.map((room) => room.toJson()).toList();
    final encoded = jsonEncode(roomsJson);
    await prefs.setString('rooms', encoded);
  }

  // Функция для загрузки
  Future<void> _loadRoomsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? roomsJson = prefs.getString('rooms');
    if (roomsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(roomsJson);
        setState(() {
          _rooms = decoded.map((e) => RoomPlan.fromJson(e)).toList();
        });
      } catch (e) {
        print('Ошибка загрузки комнат: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор штукатура', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SavedRoomsScreen(
                    rooms: _rooms,
                    onRoomsChanged: (updatedRooms) {
                      setState(() {
                        _rooms = updatedRooms;
                      });
                      _saveRoomsToStorage();
                    },
                  ),
                ),
              );
            },
            tooltip: 'Сохранённые комнаты',
          ),
          IconButton(
            icon: const Icon(Icons.home_work),
            onPressed: _openRoomPlanner,
            tooltip: 'Планировщик комнат',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ОБЩАЯ КАРТОЧКА (поля + результаты)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ЗАГОЛОВОК + КНОПКА ОЧИСТКИ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'КНАУФ МП 75',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF5722),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cleaning_services),
                          tooltip: 'Очистить',
                          onPressed: () {
                            _hCtrl.clear();
                            _wCtrl.clear();
                            _tCtrl.clear();
                            setState(() {
                              _area = 0;
                              _weight = 0;
                              _water = 0;
                              _bags = 0;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1. Высота
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

                    // 2. Ширина и Толщина
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

                    // 3.  РЕЗУЛЬТАТЫ (появляются только если площадь > 0)
                    if (_area > 0) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.aspect_ratio, color: Color(0xFFFF5722)),
                      title: const Text('Площадь стен(ы)'),
                      trailing: Text(
                        '${_area.toStringAsFixed(2)} м²',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.scale, color: Color(0xFFFF5722)),
                      title: const Text('Сухая смесь'),
                      trailing: Text(
                        '${_weight.toStringAsFixed(1)} кг',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.water_drop, color: Colors.blue),
                      title: const Text('Расход воды'),
                      trailing: Text(
                        '${_water.toStringAsFixed(1)} л',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.inventory_2, color: Color(0xFF212121)),
                      title: const Text('Мешки (по 30 кг)'),
                      trailing: Text(
                        '${_bags.toStringAsFixed(1)} шт.',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Точное значение (дробное)'),
                    ),
                   ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // МАЯКИ (отдельная карточка)
            const BeaconCalculator(),
          ],
        ),
      ),
    );
  }
}