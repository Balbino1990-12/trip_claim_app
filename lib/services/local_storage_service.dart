import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorageService {
  static const String _claimsKey = 'cached_claims';
  static const String _apiUrlKey = 'api_url';
  static const String _tokenKey = 'auth_token';
  static const String _userPhoneKey = 'user_phone';

  // Save trip claim locally
  static Future<bool> saveTripClaim(Map<String, dynamic> claim) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final claims = await getAllCachedClaims();

      // Add timestamp if not present
      claim['savedAt'] = DateTime.now().toIso8601String();
      claim['synced'] = claim['synced'] ?? false;

      claims.add(claim);

      final jsonString = jsonEncode(claims);
      return await prefs.setString(_claimsKey, jsonString);
    } catch (e) {
      print('Error saving claim locally: $e');
      return false;
    }
  }

  // Get all cached claims
  static Future<List<Map<String, dynamic>>> getAllCachedClaims() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_claimsKey);

      if (jsonString == null) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error retrieving cached claims: $e');
      return [];
    }
  }

  // Get unsynced claims (not yet sent to server)
  static Future<List<Map<String, dynamic>>> getUnsyncedClaims() async {
    try {
      final claims = await getAllCachedClaims();
      return claims
          .where((claim) => claim['synced'] != true)
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error retrieving unsynced claims: $e');
      return [];
    }
  }

  // Mark claim as synced
  static Future<bool> markClaimAsSynced(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final claims = await getAllCachedClaims();

      if (index >= 0 && index < claims.length) {
        claims[index]['synced'] = true;
        final jsonString = jsonEncode(claims);
        return await prefs.setString(_claimsKey, jsonString);
      }
      return false;
    } catch (e) {
      print('Error marking claim as synced: $e');
      return false;
    }
  }

  // Delete specific claim
  static Future<bool> deleteClaim(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final claims = await getAllCachedClaims();

      if (index >= 0 && index < claims.length) {
        claims.removeAt(index);
        final jsonString = jsonEncode(claims);
        return await prefs.setString(_claimsKey, jsonString);
      }
      return false;
    } catch (e) {
      print('Error deleting claim: $e');
      return false;
    }
  }

  // Clear all cached claims
  static Future<bool> clearAllClaims() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_claimsKey);
    } catch (e) {
      print('Error clearing claims: $e');
      return false;
    }
  }

  // Save API URL
  static Future<bool> saveApiUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_apiUrlKey, url);
    } catch (e) {
      print('Error saving API URL: $e');
      return false;
    }
  }

  // Get saved API URL
  static Future<String?> getApiUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_apiUrlKey);
    } catch (e) {
      print('Error retrieving API URL: $e');
      return null;
    }
  }

  // Save authentication token
  static Future<bool> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_tokenKey, token);
    } catch (e) {
      print('Error saving token: $e');
      return false;
    }
  }

  // Get saved token
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('Error retrieving token: $e');
      return null;
    }
  }

  // Clear token (logout)
  static Future<bool> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_tokenKey);
    } catch (e) {
      print('Error clearing token: $e');
      return false;
    }
  }

  // Save user phone
  static Future<bool> saveUserPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_userPhoneKey, phone);
    } catch (e) {
      print('Error saving user phone: $e');
      return false;
    }
  }

  // Get saved user phone
  static Future<String?> getUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userPhoneKey);
    } catch (e) {
      print('Error retrieving user phone: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Meter number helpers
  static const String _userMeterKey = 'user_meter';

  // Save meter number locally
  static Future<bool> saveUserMeter(String meter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_userMeterKey, meter);
    } catch (e) {
      print('Error saving user meter: $e');
      return false;
    }
  }

  // Get saved meter number
  static Future<String?> getUserMeter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userMeterKey);
    } catch (e) {
      print('Error retrieving user meter: $e');
      return null;
    }
  }

  // Clear all local data (logout completely)
  static Future<bool> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userPhoneKey);
      return true;
    } catch (e) {
      print('Error clearing all data: $e');
      return false;
    }
  }

  // Get storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final claims = await getAllCachedClaims();
      final unsynced = await getUnsyncedClaims();

      return {
        'totalClaims': claims.length,
        'unsyncedClaims': unsynced.length,
        'syncedClaims': claims.length - unsynced.length,
      };
    } catch (e) {
      print('Error getting storage stats: $e');
      return {'totalClaims': 0, 'unsyncedClaims': 0, 'syncedClaims': 0};
    }
  }
}
