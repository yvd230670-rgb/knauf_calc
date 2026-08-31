// room_planner.dart
// Компонент для построения схемы комнаты через маршрут (прямая, угол внутрь, угол наружу)

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';  // для HapticFeedback

// ============ МОДЕЛИ ДАННЫХ ============

/// Модель для хранения одной стены (отрезка)
class WallSegment {
  final int id;
  final double length; // в метрах
  final int layerThickness; // в мм
  final Color color;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double angle; // угол в радианах

  WallSegment({
    required this.id,
    required this.length,
    required this.layerThickness,
    required this.color,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.angle,
  });

  double get area => length * 2.7; // высота комнаты по умолчанию 2.7м

  Map<String, dynamic> toJson() => {
    'id': id,
    'length': length,
    'layerThickness': layerThickness,
    'color': color.value,
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
    'angle': angle,
  };

  factory WallSegment.fromJson(Map<String, dynamic> json) => WallSegment(
    id: json['id'],
    length: json['length'],
    layerThickness: json['layerThickness'],
    color: Color(json['color']),
    startX: json['startX'],
    startY: json['startY'],
    endX: json['endX'],
    endY: json['endY'],
    angle: json['angle'],
  );
}

/// Модель комнаты
class RoomPlan {
  final String name;
  final double height; // высота стен в метрах
  final List<WallSegment> walls;
  final DateTime createdAt;

  RoomPlan({
    required this.name,
    this.height = 2.7,
    this.walls = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalArea => walls.fold(0, (sum, w) => sum + w.area);
  double get totalLength => walls.fold(0, (sum, w) => sum + w.length);

  Map<String, dynamic> toJson() => {
    'name': name,
    'height': height,
    'walls': walls.map((w) => w.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory RoomPlan.fromJson(Map<String, dynamic> json) => RoomPlan(
    name: json['name'],
    height: json['height'],
    walls: (json['walls'] as List).map((w) => WallSegment.fromJson(w)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
  );
}

// ============ ОСНОВНОЙ КОМПОНЕНТ ============

class RoomPlanner extends StatefulWidget {
  final Function(RoomPlan)? onSave;
  final RoomPlan? initialPlan;

  const RoomPlanner({
    Key? key,
    this.onSave,
    this.initialPlan,
  }) : super(key: key);

  @override
  State<RoomPlanner> createState() => _RoomPlannerState();
}

class _RoomPlannerState extends State<RoomPlanner> with TickerProviderStateMixin {
  // Состояние построения
  List<WallSegment> _walls = [];
  double _currentX = 0;
  double _currentY = 0;
  double _currentAngle = 0; // 0 = вправо (начальное направление)
  int _nextId = 1;
  bool _isClosed = false;
  String _roomName = '';
  double _roomHeight = 2.7;
  double _closureError = 0; // ошибка замыкания в метрах

  // Для анимации
  late AnimationController _animationController;
  List<Offset> _animatedPoints = [];

  // Палитра цветов для стен
  static const List<Color> _colorPalette = [
    Color(0xFFE74C3C), // Красный
    Color(0xFF3498DB), // Синий
    Color(0xFF2ECC71), // Зеленый
    Color(0xFFF39C12), // Оранжевый
    Color(0xFF9B59B6), // Фиолетовый
    Color(0xFF1ABC9C), // Бирюзовый
    Color(0xFFE67E22), // Морковный
    Color(0xFFE91E63), // Розовый
    Color(0xFF00BCD4), // Голубой
    Color(0xFF8BC34A), // Салатовый
  ];

  // Контроллеры для ввода
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _layerController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    if (widget.initialPlan != null) {
      _loadPlan(widget.initialPlan!);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _lengthController.dispose();
    _layerController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  void _loadPlan(RoomPlan plan) {
    _walls = List.from(plan.walls);
    _roomHeight = plan.height;
    _roomName = plan.name;
    if (_walls.isNotEmpty) {
      final last = _walls.last;
      _currentX = last.endX;
      _currentY = last.endY;
      _currentAngle = last.angle;
      _nextId = _walls.length + 1;
      _checkIfClosed();
    }
    setState(() {});
  }

  // ============ ГЕОМЕТРИЧЕСКИЕ РАСЧЕТЫ ============

  void _addStraightWall() {
    // Показываем диалог для ввода длины и слоя
    _lengthController.clear();
    _layerController.text = '10'; // Значение по умолчанию

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('📏 Стена №$_nextId'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _lengthController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Длина (м)',
                prefixIcon: Icon(Icons.horizontal_rule),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _layerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Слой штукатурки (мм)',
                prefixIcon: Icon(Icons.height),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final length = double.tryParse(_lengthController.text.replaceAll(',', '.'));
              final layer = int.tryParse(_layerController.text) ?? 10;
              if (length != null && length > 0) {
                Navigator.pop(context);
                _addStraightWallWithParams(length, layer);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _addStraightWallWithParams(double length, int layer) {
    if (_isClosed) return;

    final endX = _currentX + length * math.cos(_currentAngle);
    final endY = _currentY + length * math.sin(_currentAngle);

    final color = _colorPalette[(_walls.length) % _colorPalette.length];

    final wall = WallSegment(
      id: _nextId++,
      length: length,
      layerThickness: layer,
      color: color,
      startX: _currentX,
      startY: _currentY,
      endX: endX,
      endY: endY,
      angle: _currentAngle,
    );

    setState(() {
      _walls.add(wall);
      _currentX = endX;
      _currentY = endY;
      _checkIfClosed();
    });
  }

  void _addInnerCorner() {
    if (_isClosed) return;
    setState(() {
      _currentAngle += math.pi / 2; // Поворот на -90° (внутрь)
    });
    _animateCorner();
  }

  void _addOuterCorner() {
    if (_isClosed) return;
    setState(() {
      _currentAngle -= math.pi / 2; // Поворот на +90° (наружу)
    });
    _animateCorner();
  }

  void _animateCorner() {
    _animationController.reset();
    _animationController.forward();
  }

  void _checkIfClosed() {
    if (_walls.length < 3) {
      setState(() {
        _closureError = 0;
      });
      return;
    }

    final first = _walls.first;
    final distance = math.sqrt(
      math.pow(_currentX - first.startX, 2) + 
      math.pow(_currentY - first.startY, 2)
    );

    setState(() {
      _closureError = distance;
    });

    // Если расстояние меньше 0.05м (5 см) — замыкаем
    if (distance < 0.05 && !_isClosed) {
      _isClosed = true;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Комната замкнута! Можно сохранять.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ============ СОХРАНЕНИЕ ============

  void _saveRoom() {
    if (_walls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Добавьте хотя бы одну стену'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Комната не замкнута. Пройдите полный круг.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('💾 Сохранить комнату'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                labelText: 'Название комнаты',
                prefixIcon: Icon(Icons.home),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _roomHeight.toString()),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Высота потолка (м)',
                prefixIcon: Icon(Icons.height),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _roomHeight = double.tryParse(value.replaceAll(',', '.')) ?? 2.7;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _roomNameController.text.trim().isEmpty
                  ? 'Комната ${DateTime.now().day}.${DateTime.now().month}'
                  : _roomNameController.text.trim();
              Navigator.pop(context);
              final room = RoomPlan(
                name: name,
                height: _roomHeight,
                walls: List.from(_walls),
              );
              if (widget.onSave != null) {
                widget.onSave!(room);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Комната "$name" сохранена!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _resetRoom() {
    setState(() {
      _walls.clear();
      _currentX = 0;
      _currentY = 0;
      _currentAngle = 0;
      _nextId = 1;
      _isClosed = false;
      _roomName = '';
    });
  }

  // ============ ВСТАВЬ СЮДА ============
  void _undoLastAction() {
    if (_walls.isEmpty) return;
    
    setState(() {
      _walls.removeLast();
      
      if (_walls.isNotEmpty) {
        final last = _walls.last;
        _currentX = last.endX;
        _currentY = last.endY;
        _currentAngle = last.angle;
        _nextId = last.id + 1;
      } else {
        _currentX = 0;
        _currentY = 0;
        _currentAngle = 0;
        _nextId = 1;
      }
      
      _isClosed = false;
      _closureError = 0;
    });
  }
  // ====================================

  // ============ ОТРИСОВКА ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 Планировщик комнаты'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _walls.isEmpty ? null : _undoLastAction,
            tooltip: 'Отменить последнее действие',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _walls.isEmpty ? null : _resetRoom,
            tooltip: 'Очистить всё',
          ),
        ],
      ),
      body: Column(
        children: [
          // Верхняя панель с информацией
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📐 Стен: ${_walls.length}'),
                    if (_isClosed)
                      Text(
                        '📏 Общая длина: ${_totalLength.toStringAsFixed(1)}м',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    // ============ ВСТАВЬ СЮДА ============
                    if (_walls.length >= 3 && !_isClosed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚠️ НЕ ЗАМКНУТО',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Ошибка: ${_closureError.toStringAsFixed(2)} м',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ====================================  
                  ],
                ),
                if (_isClosed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      '✅ ЗАМКНУТО',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Графический холст для схемы
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: RoomPainter(
                    walls: _walls,
                    isClosed: _isClosed,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),

          // Нижняя панель с кнопками действий
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Кнопки построения
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.horizontal_rule,
                      label: 'Прямая',
                      color: Colors.blue,
                      onPressed: _isClosed ? null : _addStraightWall,
                    ),
                    _buildActionButton(
                      icon: Icons.turn_right,
                      label: 'Угол внутрь',
                      color: Colors.orange,
                      onPressed: _isClosed ? null : _addInnerCorner,
                    ),
                    _buildActionButton(
                      icon: Icons.turn_left,
                      label: 'Угол наружу',
                      color: Colors.purple,
                      onPressed: _isClosed ? null : _addOuterCorner,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Кнопка сохранения
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _walls.isEmpty ? null : _saveRoom,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          '💾 Сохранить комнату',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _walls.isEmpty ? Colors.grey : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 28),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed == null ? Colors.grey.shade400 : color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ),
    );
  }

  double get _totalLength => _walls.fold(0, (sum, w) => sum + w.length);
}

// ============ ХУДОЖНИК ДЛЯ ОТРИСОВКИ СХЕМЫ ============

class RoomPainter extends CustomPainter {
  final List<WallSegment> walls;
  final bool isClosed;

  RoomPainter({required this.walls, required this.isClosed});

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    // Находим границы схемы
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (final wall in walls) {
      minX = [minX, wall.startX, wall.endX].reduce((a, b) => a < b ? a : b);
      maxX = [maxX, wall.startX, wall.endX].reduce((a, b) => a > b ? a : b);
      minY = [minY, wall.startY, wall.endY].reduce((a, b) => a < b ? a : b);
      maxY = [maxY, wall.startY, wall.endY].reduce((a, b) => a > b ? a : b);
    }

    // Отступы
    final padding = 40.0;
    final drawingWidth = size.width - padding * 2;
    final drawingHeight = size.height - padding * 2;

    // Масштабирование с сохранением пропорций
    final widthRange = maxX - minX;
    final heightRange = maxY - minY;
    final scaleX = drawingWidth / (widthRange > 0 ? widthRange : 1);
    final scaleY = drawingHeight / (heightRange > 0 ? heightRange : 1);
    final scale = math.min(scaleX, scaleY) * 0.9;

    // Центрирование
    final centerX = padding + drawingWidth / 2;
    final centerY = padding + drawingHeight / 2;
    final offsetX = centerX - (minX + maxX) / 2 * scale;
    final offsetY = centerY - (minY + maxY) / 2 * scale;

    Offset transform(Offset point) => Offset(
      offsetX + point.dx * scale,
      offsetY + point.dy * scale,
    );

    // Рисуем стены
    final paint = Paint()
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < walls.length; i++) {
      final wall = walls[i];
      final start = transform(Offset(wall.startX, wall.startY));
      final end = transform(Offset(wall.endX, wall.endY));

      paint.color = wall.color;

      // Основная линия стены
      canvas.drawLine(start, end, paint);

      // Подпись длины и слоя
      final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${wall.length.toStringAsFixed(1)}м | ${wall.layerThickness}мм',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            backgroundColor: Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(midPoint.dx - textPainter.width / 2, midPoint.dy - 20),
      );

      // Номер стены
      final numberPainter = TextPainter(
        text: TextSpan(
          text: '№${wall.id}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      numberPainter.layout();
      numberPainter.paint(
        canvas,
        Offset(midPoint.dx - numberPainter.width / 2, midPoint.dy + 8),
      );
    }

    // ============ ВСТАВЬ СЮДА (ПОСЛЕ ЦИКЛА, НО ПЕРЕД НАЧАЛЬНОЙ ТОЧКОЙ) ============
    // Если не замкнуто и есть стены — рисуем красную пунктирную линию
    if (!isClosed && walls.isNotEmpty) {
      final first = walls.first;
      final last = walls.last;
      final start = transform(Offset(first.startX, first.startY));
      final end = transform(Offset(last.endX, last.endY));

      final dashPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

      // Рисуем пунктир
      const dashWidth = 8;
      const dashSpace = 6;
      double distance = (end - start).distance;
      for (double d = 0; d < distance; d += dashWidth + dashSpace) {
        final t1 = d / distance;
        final t2 = (d + dashWidth) / distance;
        if (t2 > 1) break;
        final p1 = Offset(
          start.dx + (end.dx - start.dx) * t1,
          start.dy + (end.dy - start.dy) * t1,
        );
        final p2 = Offset(
          start.dx + (end.dx - start.dx) * t2,
          start.dy + (end.dy - start.dy) * t2,
        );
        canvas.drawLine(p1, p2, dashPaint);
      }

      // Подпись ошибки
            // Подпись ошибки (в метрах)
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2 - 16);
      
      // Считаем ошибку в метрах через реальные координаты
      final lastWall = walls.last;
      final firstWall = walls.first;
      final errorInMeters = math.sqrt(
        math.pow(lastWall.endX - firstWall.startX, 2) +
        math.pow(lastWall.endY - firstWall.startY, 2)
      );
      
      final errorText = TextPainter(
        text: TextSpan(
          text: '❌ ${errorInMeters.toStringAsFixed(2)} м',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            backgroundColor: Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      errorText.layout();
      errorText.paint(canvas, Offset(mid.dx - errorText.width / 2, mid.dy));
    }
    // ==================================================================

    // Рисуем начальную точку
    if (walls.isNotEmpty) {
      final startPoint = transform(Offset(walls.first.startX, walls.first.startY));
      final pointPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(startPoint, 8, pointPaint);
      // Обводка
      pointPaint.style = PaintingStyle.stroke;
      pointPaint.strokeWidth = 2;
      pointPaint.color = Colors.white;
      canvas.drawCircle(startPoint, 8, pointPaint);
    }

    // Рисуем конечную точку (если не замкнуто)
    if (!isClosed && walls.isNotEmpty) {
      final endPoint = transform(Offset(walls.last.endX, walls.last.endY));
      final pointPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, 6, pointPaint);
      // Пульсирующая обводка (имитация)
      pointPaint.style = PaintingStyle.stroke;
      pointPaint.strokeWidth = 2;
      pointPaint.color = Colors.red.withAlpha(128);
      canvas.drawCircle(endPoint, 10, pointPaint);
    }

    // Если замкнуто - рисуем зеленый контур
    if (isClosed && walls.isNotEmpty) {
      final first = walls.first;
      final last = walls.last;
      final start = transform(Offset(first.startX, first.startY));
      final end = transform(Offset(last.endX, last.endY));

      final closePaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      canvas.drawLine(end, start, closePaint);

      // Звездочка "Готово"
      final center = transform(Offset(
        (first.startX + last.endX) / 2,
        (first.startY + last.endY) / 2,
      ));
      final donePaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 12, donePaint);
      const icon = TextSpan(
        text: '✅',
        style: TextStyle(fontSize: 16),
      );
      final iconPainter = TextPainter(text: icon, textDirection: TextDirection.ltr);
      iconPainter.layout();
      iconPainter.paint(canvas, Offset(center.dx - 8, center.dy - 8));
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🖐️ Начните с кнопки\n"Прямая"',
        style: TextStyle(fontSize: 20, color: Colors.grey),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2 - 20,
      ),
    );

    // Рисуем стартовую точку
    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2 + 30),
      12,
      pointPaint,
    );
    pointPaint.style = PaintingStyle.stroke;
    pointPaint.strokeWidth = 3;
    pointPaint.color = Colors.blue.withAlpha(100);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2 + 30),
      18,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============ ПРИМЕР ИСПОЛЬЗОВАНИЯ ============

class RoomPlannerExample extends StatelessWidget {
  const RoomPlannerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Планировщик комнаты',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: RoomPlanner(
        onSave: (room) {
          // Здесь ты можешь сохранить комнату в базу данных
          print('Сохранена комната: ${room.name}');
          print('Стен: ${room.walls.length}');
          print('Общая площадь: ${room.totalArea.toStringAsFixed(2)} м²');
          print('Данные: ${room.toJson()}');
        },
      ),
    );
  }
}