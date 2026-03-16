import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/calendar_service.dart';
import '../models/calendar_event.dart';
import '../widgets/event_modal.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  Map<DateTime, List<CalendarEvent>> _eventsMap = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEventsForMonth(_focusedDay);
  }

  void reload() {
    _loadEventsForMonth(_focusedDay);
  }

  Future<void> _loadEventsForMonth(DateTime month) async {
    setState(() => _isLoading = true);
    try {
      final eventsList = await _calendarService.getEvents(month.year, month.month);
      
      final Map<DateTime, List<CalendarEvent>> newEvents = {};
      for (final event in eventsList) {
        // Normalizamos la fecha eliminando hora/minuto/segundo para agrupar por día
        final normalizedDay = DateTime(event.start.year, event.start.month, event.start.day);
        if (newEvents[normalizedDay] == null) {
          newEvents[normalizedDay] = [];
        }
        newEvents[normalizedDay]!.add(event);
      }
      
      setState(() => _eventsMap = newEvents);
    } catch (e) {
      debugPrint('Error loading events: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando calendario', style: const TextStyle(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsMap[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _loadEventsForMonth(focusedDay);
  }

  void _showEventModal([CalendarEvent? event]) async {
    final result = await showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EventModal(
        selectedDay: event?.start ?? _selectedDay ?? _focusedDay,
        eventToEdit: event,
        // Callback para borrar desde dentro del modal
        onDelete: () async {
          if (event == null) return;
          setState(() => _isLoading = true);
          try {
            await _calendarService.deleteEvent(event.id);
            reload();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error eliminando evento: $e')),
              );
            }
            setState(() => _isLoading = false);
          }
        },
      ),
    );

    if (result != null) {
      _saveEvent(result);
    }
  }

  Future<void> _saveEvent(CalendarEvent event) async {
    setState(() => _isLoading = true);
    try {
      if (event.id.isEmpty) {
        // Verificar si es un extraescolar con repetición semanal
        if (event.repeatWeekly && (event.colorId == '10' || event.colorId == '6')) {
          final instances = event.generateRecurringInstances();
          await _calendarService.createEventBatch(instances);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✓ ${instances.length} extraescolares creados', style: const TextStyle(color: Colors.white)),
                backgroundColor: const Color(0xFF10B981), // Color extraescolar (verde)
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          await _calendarService.createEvent(event);
        }
      } else {
        await _calendarService.updateEvent(event);
      }
      reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando evento: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Eliminar evento', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que deseas eliminar este evento del calendario y agenda?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Color(0xFFF43F5E)))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _calendarService.deleteEvent(event.id);
      reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error eliminando evento: \$e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsForSelectedDay = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Calendario', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: reload,
          )
        ],
      ),
      body: Column(
        children: [
          // Sección del Calendario
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: TableCalendar<CalendarEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              startingDayOfWeek: StartingDayOfWeek.monday,
              eventLoader: _getEventsForDay,
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() => _calendarFormat = format);
                }
              },
              onPageChanged: _onPageChanged,
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                formatButtonTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                formatButtonDecoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white70),
                rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white70),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: const TextStyle(color: Colors.white70),
                weekendTextStyle: const TextStyle(color: Color(0xFFF43F5E)),
                selectedDecoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.3), shape: BoxShape.circle),
              ),
              calendarBuilders: CalendarBuilders<CalendarEvent>(
                singleMarkerBuilder: (context, date, event) {
                  Color markerColor = const Color(0xFF3B82F6);
                  if (event.colorId == '10') markerColor = const Color(0xFF10B981);
                  if (event.colorId == '3') markerColor = const Color(0xFF8B5CF6);
                  if (event.colorId == '11') markerColor = const Color(0xFFF43F5E);
                  if (event.colorId == '6') markerColor = const Color(0xFFEAB308);  // Visita
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: markerColor),
                  );
                },
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                weekendStyle: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))))
          else
            Expanded(
              child: eventsForSelectedDay.isEmpty
                ? Center(
                    child: Text(
                      'No hay eventos para este día.',
                      style: TextStyle(color: Colors.white.withOpacity(0.4)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Añadido margen inferior para el botón
                    itemCount: eventsForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final event = eventsForSelectedDay[index];
                      return _buildEventCard(event);
                    },
                  ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEventModal(),
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final timeFormat = DateFormat('HH:mm');
    final String timeStr = event.allDay 
        ? 'Todo el día' 
        : "${timeFormat.format(event.start)} - ${timeFormat.format(event.end)}";
    
    // Asignar color según el colorId que viene de Google Calendar
    Color eventColor = const Color(0xFF3B82F6); // Default Blue
    if (event.colorId == '10') eventColor = const Color(0xFF10B981); // Extraescolar
    if (event.colorId == '3') eventColor = const Color(0xFF8B5CF6);  // Cita
    if (event.colorId == '11') eventColor = const Color(0xFFF43F5E); // Importante
    if (event.colorId == '6') eventColor = const Color(0xFFEAB308);  // Visita
    
    final bool isLocationUrl = event.location.toLowerCase().startsWith('http');
        
    return GestureDetector(
      onTap: () => _showEventModal(event),
      onLongPress: () => _deleteEvent(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: eventColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        if (event.location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: isLocationUrl ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: isLocationUrl
                                  ? GestureDetector(
                                      onTap: () async {
                                        final uri = Uri.parse(event.location);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: const Text(
                                        'Ver ubicación en mapa',
                                        style: TextStyle(color: Color(0xFF6C63FF), fontSize: 13, decoration: TextDecoration.underline, decorationColor: Color(0xFF6C63FF)),
                                      ),
                                    )
                                  : Text(event.location, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                        if (event.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            event.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
