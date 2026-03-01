import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

import 'lib/config/secrets.dart';
import 'lib/config/service_account.dart';

Future<void> main() async {
  try {
    final accountCredentials = ServiceAccountCredentials.fromJson(ServiceAccount.json);
    final scopes = [
      'https://www.googleapis.com/auth/drive'
    ];
    final client = await clientViaServiceAccount(accountCredentials, scopes);
    
    final token = client.credentials.accessToken.data;
    print('Token obtained');

    final yearFolderId = Secrets.driveFolders[2024]?.toString();
    print('Checking access to folder 2024: $yearFolderId');

    final url = Uri.parse('https://www.googleapis.com/drive/v3/files/$yearFolderId?fields=id,name');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    
    print('Status: ${resp.statusCode}');
    print('Body: ${resp.body}');

    client.close();
  } catch(e) {
    print('Error: $e');
  }
}
