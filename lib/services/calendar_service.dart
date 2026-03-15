import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';
import '../models/calendar_event.dart';

class CalendarService {
  static const _timeout = Duration(seconds: 15);

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'X-API-Key': Secrets.webhookSecret,
      };

  /// Obtiene los eventos combinados de Google Calendar y Extraescolares para un mes.
  Future<List<CalendarEvent>> getEvents(int year, int month) async {
    final gCalUrl = Uri.parse(
        '${Secrets.backendUrl}/?action=calendar_events&year=$year&month=$month&secret=${Secrets.webhookSecret}');
        
    final extraUrl = Uri.parse(
        '${Secrets.backendUrl}/?action=extraescolar_list&secret=${Secrets.webhookSecret}');

    try {
      // Lanzamos ambas peticiones en paralelo
      final responses = await Future.wait([
        http.get(gCalUrl, headers: _headers()).timeout(_timeout),
        http.get(extraUrl, headers: _headers()).timeout(_timeout),
      ]);

      final gCalResp = responses[0];
      final extraResp = responses[1];
      
      List<CalendarEvent> allEvents = [];

      // Parsear Google Calendar
      if (gCalResp.statusCode == 200) {
        final data = jsonDecode(gCalResp.body);
        final eventsList = (data['events'] as List?) ?? [];
        allEvents.addAll(eventsList.map((e) => CalendarEvent.fromJson(e)));
      }

      // Parsear Extraescolares
      if (extraResp.statusCode == 200) {
        final data = jsonDecode(extraResp.body);
        final extraItems = (data['items'] as List?) ?? [];
        debugPrint('Extraescolares raw count: ${extraItems.length}');
        
        final filteredExtra = extraItems.where((item) {
           if (item is! Map) return false;
           final startDate = DateTime.tryParse(item['start']?.toString() ?? '');
           if (startDate == null) return false;
           return startDate.year == year && startDate.month == month;
        }).map((e) => CalendarEvent.fromJson(Map<String, dynamic>.from(e as Map)));
        
        debugPrint('Extraescolares filtered for $year-$month count: ${filteredExtra.length}');
        allEvents.addAll(filteredExtra);
      } else {
        debugPrint('Extraescolares fetch failed: ${extraResp.statusCode}');
      }

      return allEvents;
    } catch (e) {
      debugPrint('Exception fetching events: $e');
      throw Exception('Error obteniendo eventos: $e');
    }
  }

  /// Crea un nuevo evento en Google Calendar o Local Extraescolar
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    final isExtraescolar = event.colorId == '10';
    final action = isExtraescolar ? 'extraescolar_save' : 'calendar_create';
    
    final url = Uri.parse('${Secrets.backendUrl}/?action=$action&secret=${Secrets.webhookSecret}');

    final body = jsonEncode(event.toJson());

    final resp = await http
        .post(url, headers: _headers(), body: body)
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception('Error creando evento: ${resp.body}');
    }

    // Para la creación, el PHP devuelve success y un `event` o un `id` (extraescolar). 
    // Por simplicidad, recargamos la lista desde el servidor en la UI.
    return event;
  }

  /// Actualiza un evento existente en Google Calendar o Extraescolares.
  Future<CalendarEvent> updateEvent(CalendarEvent event) async {
    if (event.id.isEmpty) {
      throw Exception('El evento necesita un ID válido para ser actualizado.');
    }

    final isLocal = event.id.startsWith('local-');
    final action = isLocal ? 'extraescolar_save' : 'calendar_update';

    final url = Uri.parse('${Secrets.backendUrl}/?action=$action&secret=${Secrets.webhookSecret}');

    // En calendar_update, el backend PHP espera eventId aparte del payload. 
    // En extraescolar_save, si le pasamos el id lo machaca.
    final payload = event.toJson();
    if (!isLocal) {
       payload['eventId'] = event.id; // Renombrar para Calendar
    }

    final body = jsonEncode(payload);

    final resp = await http
        .post(url, headers: _headers(), body: body)
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception('Error actualizando evento: ${resp.body}');
    }

    return event;
  }

  /// Elimina un evento en Google Calendar o Extraescolares
  Future<bool> deleteEvent(String eventId) async {
    final isLocal = eventId.startsWith('local-');
    final action = isLocal ? 'extraescolar_delete' : 'calendar_delete';
    
    final url = Uri.parse('${Secrets.backendUrl}/?action=$action&secret=${Secrets.webhookSecret}');

    final body = jsonEncode({
      isLocal ? 'id' : 'eventId': eventId,
    });

    final resp = await http
        .post(url, headers: _headers(), body: body)
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception('Error eliminando evento: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    return data['success'] == true;
  }
}
