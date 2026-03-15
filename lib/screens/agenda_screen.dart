import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/calendar_service.dart';
import '../models/calendar_event.dart';
import '../widgets/event_modal.dart';
import 'calendar_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isLoading = false;
  List<CalendarEvent> _events = [];

  // Almacenar el mes actual para la consulta inicial
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _loadAgenda(_currentMonth);
  }

  void _reload() {
    _loadAgenda(_currentMonth);
  }

  Future<void> _loadAgenda(DateTime month) async {
    setState(() => _isLoading = true);
    try {
      // Obtenemos eventos del mes actual
      final currentEvents = await _calendarService.getEvents(month.year, month.month);
      
      // Para una agenda "más completa", podríamos cargar también el mes siguiente
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final nextEvents = await _calendarService.getEvents(nextMonth.year, nextMonth.month);
      
      final allEvents = [...currentEvents, ...nextEvents];
      
      // Filtrar eventos pasados (dejamos solo desde hoy hacia el futuro)
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final futureEvents = allEvents.where((e) {
        final eventDay = DateTime(e.end.year, e.end.month, e.end.day);
        return !eventDay.isBefore(today);
      }).toList();

      // Ordenar cronológicamente
      futureEvents.sort((a, b) => a.start.compareTo(b.start));

      setState(() => _events = futureEvents);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando la agenda: \$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEventModal([CalendarEvent? event]) async {
    final result = await showModalBottomSheet<CalendarEvent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EventModal(
        selectedDay: event?.start ?? DateTime.now(),
        eventToEdit: event,
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        if (result.id.isEmpty) {
          await _calendarService.createEvent(result);
        } else {
          await _calendarService.updateEvent(result);
        }
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error guardando evento: \$e')),
          );
        }
        setState(() => _isLoading = false);
      }
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
      _reload();
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
    // Agrupar eventos por día
    final Map<DateTime, List<CalendarEvent>> groupedEvents = {};
    for (final ev in _events) {
      final d = DateTime(ev.start.year, ev.start.month, ev.start.day);
      if (groupedEvents[d] == null) groupedEvents[d] = [];
      groupedEvents[d]!.add(ev);
    }

    final sortedDays = groupedEvents.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Próximos Eventos', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              ).then((_) => _reload());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _reload,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : sortedDays.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'No hay próximos eventos en la agenda.',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF6C63FF),
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 80),
                    itemCount: sortedDays.length,
                    itemBuilder: (context, index) {
                      final day = sortedDays[index];
                      final dayEvents = groupedEvents[day]!;
                      return _buildDayBlock(day, dayEvents);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showEventModal(),
      ),
    );
  }

  Widget _buildDayBlock(DateTime day, List<CalendarEvent> dayEvents) {
    final isToday = DateTime.now().year == day.year && 
                    DateTime.now().month == day.month && 
                    DateTime.now().day == day.day;
                    
    final isTomorrow = DateTime.now().add(const Duration(days: 1)).year == day.year &&
                       DateTime.now().add(const Duration(days: 1)).month == day.month &&
                       DateTime.now().add(const Duration(days: 1)).day == day.day;

    String dayTitle = DateFormat('EEEE d \'de\' MMMM', 'es_ES').format(day);
    dayTitle = dayTitle[0].toUpperCase() + dayTitle.substring(1);
    
    if (isToday) dayTitle = 'Hoy, $dayTitle';
    if (isTomorrow) dayTitle = 'Mañana, $dayTitle';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isToday ? const Color(0xFF6C63FF) : Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dayTitle,
                style: TextStyle(
                  color: isToday ? const Color(0xFF6C63FF) : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              children: dayEvents.map((ev) => _buildEventCard(ev)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final timeFormat = DateFormat('HH:mm');
    final String timeStr = event.allDay 
        ? 'Todo el día' 
        : "${timeFormat.format(event.start)} - ${timeFormat.format(event.end)}";
    
    Color eventColor = const Color(0xFF3B82F6); // Default Blue
    if (event.colorId == '10') eventColor = const Color(0xFF10B981); // Extraescolar
    if (event.colorId == '3') eventColor = const Color(0xFF8B5CF6);  // Cita
    if (event.colorId == '11') eventColor = const Color(0xFFF43F5E); // Importante
    
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
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: eventColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                            
                            if (event.location.isNotEmpty) ...[
                              const SizedBox(width: 12),
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
                                        'Abrir mapa', 
                                        style: TextStyle(color: Color(0xFF6C63FF), fontSize: 13, decoration: TextDecoration.underline, decorationColor: Color(0xFF6C63FF))
                                      ),
                                    )
                                  : Text(
                                      event.location, 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)
                                    ),
                              ),
                            ],
                          ],
                        ),
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
