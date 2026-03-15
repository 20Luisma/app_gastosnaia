import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';

class EventModal extends StatefulWidget {
  final DateTime selectedDay;
  final CalendarEvent? eventToEdit;

  const EventModal({super.key, required this.selectedDay, this.eventToEdit});

  @override
  State<EventModal> createState() => _EventModalState();
}

class _EventModalState extends State<EventModal> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationController;
  
  late bool _allDay;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  
  late String _colorId;

  // Options matching backend types
  final List<Map<String, dynamic>> _colorOptions = [
    {'id': '1', 'name': 'Evento General', 'color': const Color(0xFF3B82F6)},
    {'id': '3', 'name': 'Cita / Agenda', 'color': const Color(0xFF8B5CF6)},
    {'id': '10', 'name': 'Extraescolar', 'color': const Color(0xFF10B981)},
    {'id': '11', 'name': 'Importante', 'color': const Color(0xFFF43F5E)},
  ];

  @override
  void initState() {
    super.initState();
    
    final ev = widget.eventToEdit;
    
    _titleController = TextEditingController(text: ev?.title ?? '');
    _descController = TextEditingController(text: ev?.description ?? '');
    _locationController = TextEditingController(text: ev?.location ?? '');
    
    _allDay = ev?.allDay ?? false;
    _colorId = ev?.colorId ?? '1';

    if (ev != null) {
      _startDate = ev.start;
      _startTime = TimeOfDay.fromDateTime(ev.start);
      _endDate = ev.end;
      _endTime = TimeOfDay.fromDateTime(ev.end);
    } else {
      _startDate = widget.selectedDay;
      final now = DateTime.now();
      _startTime = TimeOfDay(hour: now.hour + 1, minute: 0); // Next hour by default
      _endDate = widget.selectedDay;
      _endTime = TimeOfDay(hour: now.hour + 2, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1A2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    final finalStart = DateTime(
      _startDate.year, _startDate.month, _startDate.day,
      _allDay ? 0 : _startTime.hour, _allDay ? 0 : _startTime.minute
    );
    
    final finalEnd = DateTime(
      _endDate.year, _endDate.month, _endDate.day,
      _allDay ? 23 : _endTime.hour, _allDay ? 59 : _endTime.minute
    );

    if (!finalEnd.isAfter(finalStart) && !_allDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La hora de fin debe ser posterior a la de inicio.')),
      );
      return;
    }

    final newEvent = CalendarEvent(
      id: widget.eventToEdit?.id ?? '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      location: _locationController.text.trim(),
      start: finalStart,
      end: finalEnd,
      allDay: _allDay,
      colorId: _colorId,
    );
    
    Navigator.of(context).pop(newEvent);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 24
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.eventToEdit == null ? 'Nuevo Evento' : 'Editar Evento',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Tipo de Evento / Color
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colorOptions.map((opt) {
                    final isSelected = _colorId == opt['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _colorId = opt['id']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? opt['color'] : (opt['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? opt['color'] : Colors.transparent,
                            width: 2
                          )
                        ),
                        child: Text(
                          opt['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : opt['color'],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Título del evento',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    const Text('Todo el día', style: TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Switch(
                      value: _allDay,
                      activeColor: const Color(0xFF6C63FF),
                      onChanged: (v) => setState(() => _allDay = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fechas y Horas
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildDateTimeSelector(
                        title: 'Inicio',
                        dateText: dateFormat.format(_startDate),
                        timeText: _startTime.format(context),
                        isAllDay: _allDay,
                        onDateTap: () => _selectDate(context, true),
                        onTimeTap: () => _selectTime(context, true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _buildDateTimeSelector(
                        title: 'Fin',
                        dateText: dateFormat.format(_endDate),
                        timeText: _endTime.format(context),
                        isAllDay: _allDay,
                        onDateTap: () => _selectDate(context, false),
                        onTimeTap: () => _selectTime(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _locationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ubicación (Opcional)',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.white54),
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Descripción (Opcional)',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.eventToEdit == null ? 'Guardar Evento' : 'Actualizar Evento',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector({
    required String title,
    required String dateText,
    required String timeText,
    required bool isAllDay,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onDateTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateText, 
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isAllDay) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timeText, 
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]
      ],
    );
  }
}
