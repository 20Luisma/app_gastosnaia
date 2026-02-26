import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class AiService {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  Future<String> _getFirebaseContext() async {
    final url =
        '${Secrets.firebaseDatabaseUrl}/ai_context.json?auth=${Secrets.firebaseSecret}';
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) return resp.body;
    return '{}';
  }

  Future<String> ask(String question) async {
    final context = await _getFirebaseContext();

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'system',
          'content': '''Eres Alfred, el asistente contable de la familia.
Tienes acceso al historial completo de gastos en formato JSON.
Responde siempre en español, de forma concisa y profesional.
Cuando cites cantidades, usa el formato europeo (ej: 1.234,56 €).
Si te preguntan por totales, calcúlalos con precisión.

Historial de gastos (datos reales de Google Sheets vía Firebase):
$context''',
        },
        {
          'role': 'user',
          'content': question,
        }
      ],
      'max_tokens': 1000,
      'temperature': 0.3,
    });

    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer ${Secrets.openAiApiKey}',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('Error OpenAI (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    return data['choices'][0]['message']['content'] as String? ??
        'Sin respuesta.';
  }
}
