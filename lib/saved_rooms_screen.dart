import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'room_planner.dart';
import 'main.dart';

// ===== МИНИАТЮРА КОМНАТЫ =====
class RoomThumbnail extends StatelessWidget {
  final List<WallSegment> walls;

  const RoomThumbnail({super.key, required this.walls});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: CustomPaint(
        painter: ThumbnailPainter(walls: walls),
      ),
    );
  }
}

// ===== ХУДОЖНИК ДЛЯ МИНИАТЮРЫ =====
class ThumbnailPainter extends CustomPainter {
  final List<WallSegment> walls;

  ThumbnailPainter({required this.walls});

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.isEmpty) return;

    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (final wall in walls) {
      minX = [minX, wall.startX, wall.endX].reduce((a, b) => a < b ? a : b);
      maxX = [maxX, wall.startX, wall.endX].reduce((a, b) => a > b ? a : b);
      minY = [minY, wall.startY, wall.endY].reduce((a, b) => a < b ? a : b);
      maxY = [maxY, wall.startY, wall.endY].reduce((a, b) => a > b ? a : b);
    }

    final padding = 8.0;
    final drawingSize = size.width - padding * 2;
    final widthRange = maxX - minX;
    final heightRange = maxY - minY;
    final scale = drawingSize / (widthRange > heightRange ? widthRange : heightRange);
    final offsetX = padding + (size.width - widthRange * scale) / 2 - minX * scale;
    final offsetY = padding + (size.height - heightRange * scale) / 2 - minY * scale;

    final paint = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final wall in walls) {
      final start = Offset(offsetX + wall.startX * scale, offsetY + wall.startY * scale);
      final end = Offset(offsetX + wall.endX * scale, offsetY + wall.endY * scale);
      paint.color = wall.color;
      canvas.drawLine(start, end, paint);
    }

    final pointPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;
    for (final wall in walls) {
      final point = Offset(offsetX + wall.startX * scale, offsetY + wall.startY * scale);
      canvas.drawCircle(point, 2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===== ЭКРАН СПИСКА КОМНАТ (Stateful) =====
class SavedRoomsScreen extends StatefulWidget {
  final List<RoomPlan> rooms;
  final Function(List<RoomPlan>)? onRoomsChanged;

  const SavedRoomsScreen({
    super.key,
    required this.rooms,
    this.onRoomsChanged,
  });

  @override
  State<SavedRoomsScreen> createState() => _SavedRoomsScreenState();
}

class _SavedRoomsScreenState extends State<SavedRoomsScreen> {
  late List<RoomPlan> _localRooms;

  @override
  void initState() {
    super.initState();
    _localRooms = List.from(widget.rooms); // копируем начальный список
  }

  void _sendWallToCalculator(
    BuildContext context, {
    required WallSegment wall,
    required double roomHeight,
  }) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalcScreen(
          initialHeight: roomHeight,
          initialWidth: wall.length,
          initialThickness: wall.layerThickness.toDouble(),
        ),
      ),
    );
  }

  void _showRoomDetails(BuildContext context, RoomPlan room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Всего стен: ${room.walls.length}',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        Text(
                          'Общая длина: ${room.totalLength.toStringAsFixed(2)} м',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        Text(
                          'Высота: ${room.height.toStringAsFixed(1)} м',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: CustomPaint(
                        painter: ThumbnailPainter(walls: room.walls),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Стены:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: room.walls.length,
                  itemBuilder: (context, i) {
                    final wall = room.walls[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: wall.color.withAlpha(200),
                        child: Text(
                          '${wall.id}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text('Стена №${wall.id}'),
                      subtitle: Text(
                        'Длина: ${wall.length.toStringAsFixed(2)} м, Слой: ${wall.layerThickness} мм',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Color(0xFFFF5722)),
                        tooltip: 'Посчитать эту стену',
                        onPressed: () {
                          _sendWallToCalculator(
                            context,
                            wall: wall,
                            roomHeight: room.height,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сохранённые комнаты'),
        centerTitle: true,
      ),
      body: _localRooms.isEmpty
          ? const Center(
              child: Text(
                'Нет сохранённых комнат',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _localRooms.length,
              itemBuilder: (context, index) {
                final room = _localRooms[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Slidable(
                    key: Key(room.name + index.toString()),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      extentRatio: 0.25,
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Удалить комнату?'),
                                content: Text('Вы точно хотите удалить комнату "${room.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Нет'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Да', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              // 1. Удаляем локально — карточка исчезает сразу
                              setState(() {
                                _localRooms.removeAt(index);
                              });
                              // 2. Сохраняем изменения в родительском виджете
                              widget.onRoomsChanged?.call(_localRooms);
                            }
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 2,
                      child: ListTile(
                        leading: RoomThumbnail(walls: room.walls),
                        title: Text(
                          room.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Стен: ${room.walls.length} | Длина: ${room.totalLength.toStringAsFixed(1)} м',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showRoomDetails(context, room),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}