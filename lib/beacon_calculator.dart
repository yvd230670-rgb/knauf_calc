import 'package:flutter/material.dart';

class BeaconCalculator extends StatefulWidget {
  const BeaconCalculator({super.key});

  @override
  State<BeaconCalculator> createState() => _BeaconCalculatorState();
}

class _BeaconCalculatorState extends State<BeaconCalculator> {
  final _widthCtrl = TextEditingController();
  final _stepCtrl = TextEditingController();
  final _offsetCtrl = TextEditingController();

  int _count = 0;
  double _remainder = 0;

  void _calculate() {
    final L = double.tryParse(_widthCtrl.text.replaceAll(',', '.')) ?? 0;
    final P = double.tryParse(_stepCtrl.text.replaceAll(',', '.')) ?? 0;
    final O = double.tryParse(_offsetCtrl.text.replaceAll(',', '.')) ?? 0;

    if (L <= 0 || P <= 0 || O <= 0) {
      setState(() {
        _count = 0;
        _remainder = 0;
      });
      return;
    }

    int count = ((L - O) / P).floor();
    double remainder = (L - O) - count * P;

    setState(() {
      _count = count;
      _remainder = remainder;
    });
  }

  void _clearAll() {
    _widthCtrl.clear();
    _stepCtrl.clear();
    _offsetCtrl.clear();
    setState(() {
      _count = 0;
      _remainder = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + кнопка очистки (как в main.dart)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'РАСЧЁТ МАЯКОВ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5722),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services),
                  tooltip: 'Очистить',
                  onPressed: _clearAll,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. Ширина стены
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: const Color(0xFF212121),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _widthCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ширина стены (м)',
                    labelStyle: TextStyle(color: Colors.orangeAccent),
                    suffixText: 'м',
                    suffixStyle: TextStyle(color: Colors.white),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                  ),
                  onChanged: (_) => _calculate(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Пролёт и Отступ
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stepCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Пролёт (м)',
                      suffixText: 'м',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _offsetCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Отступ от края (м)',
                      suffixText: 'м',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Результаты
            if (_count > 0) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.straighten, color: Color(0xFFFF5722)),
                title: const Text('Всего маяков'),
                trailing: Text(
                  '${_count + 3} шт.',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.repeat, color: Colors.blue),
                title: const Text('Отступ от края'),
                trailing: Text(
                  '${_offsetCtrl.text} м',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.timeline, color: Color(0xFFFF5722)),
                title: Text('Пролёты (по ${_stepCtrl.text} м)'),
                trailing: Text(
                  '$_count шт.',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calculate, color: Color(0xFFFF5722)),
                title: const Text('Остаток (не мерять!)'),
                trailing: Text(
                  '${_remainder.toStringAsFixed(2)} м',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}