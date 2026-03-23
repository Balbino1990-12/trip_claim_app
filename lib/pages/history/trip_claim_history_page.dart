import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../services/network_service.dart';
import '../../services/api_service.dart';

class TripClaimHistoryPage extends StatefulWidget {
  const TripClaimHistoryPage({super.key});

  @override
  State<TripClaimHistoryPage> createState() => _TripClaimHistoryPageState();
}

class _TripClaimHistoryPageState extends State<TripClaimHistoryPage> {
  List<dynamic> _claims = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  int _currentPage = 1;
  int _totalPages = 1;
  String? _errorMessage;
  Map<String, dynamic>? _lastResponse;
  
  // Technician cache to avoid duplicate API calls
  final Map<String, Map<String, dynamic>> _technicianCache = {};

  final List<String> _statuses = ['all', 'pending', 'on-progress', 'approved', 'rejected', 'completed'];

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }


  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getUserTripClaims(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        page: _currentPage,
        limit: 10,
      );

      print('=== DEBUG: Response received ===');
      print('Full response: $response');
      print('Success field: ${response['success']}');
      print('Message: ${response['message']}');
      print('Status code: ${response['statusCode']}');
      print('Data type: ${response['data'].runtimeType}');
      print('Data length: ${(response['data'] as List?)?.length ?? 0}');
      print('Data: ${response['data']}');
      print('================================');

      if (response['success'] == true) {
        final claimsData = response['data'] ?? [];
        print('Setting claims with ${(claimsData as List).length} items');
        
        // Enrich claims with technician data from backend
        await _enrichClaimsWithTechnician(claimsData);
        
        setState(() {
          _claims = claimsData;
          final pagination = response['pagination'] ?? {};
          _totalPages = pagination['pages'] ?? 1;
          _errorMessage = null;
          _lastResponse = response;
        });
        
        print('State updated - claims count: ${_claims.length}');
      } else {
        final errorMsg = response['message'] ?? 'Failed to load claims';
        print('API returned success=false: $errorMsg');
        
        setState(() {
          _errorMessage = errorMsg;
          _lastResponse = response;
          _claims = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      print('Exception in _loadClaims: $e');
      print(e);
      setState(() {
        _errorMessage = 'Error: $e';
        _claims = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading claims: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _changeStatus(String status) {
    setState(() {
      _selectedStatus = status;
      _currentPage = 1;
    });
    _loadClaims();
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() => _currentPage--);
      _loadClaims();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() => _currentPage++);
      _loadClaims();
    }
  }
  
  /// Fetch technician data by ID
  Future<Map<String, dynamic>?> _fetchTechnicianData(String technicianId) async {
    // Check cache first
    if (_technicianCache.containsKey(technicianId)) {
      print('   📦 Technician found in cache');
      return _technicianCache[technicianId];
    }
    
    try {
      print('   🌐 [START] getTechnicianById API call for: $technicianId');
      final techData = await ApiService.getTechnicianById(technicianId);
      print('   🌐 [END] getTechnicianById returned: ${techData == null ? "NULL" : "Data"}');
      
      if (techData != null) {
        print('   📋 Response type: ${techData.runtimeType}');
        print('   📋 Technician data fields: ${techData.keys.toList()}');
        techData.forEach((key, value) {
          if (value is String) {
            print('      ├─ $key = "$value"');
          } else {
            print('      ├─ $key = $value (${value.runtimeType})');
          }
        });
        _technicianCache[technicianId] = techData;
        print('   ✅ Technician data cached successfully');
        return techData;
      } else {
        print('   ❌ API returned null');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching technician data for $technicianId: $e');
      print('   Stack: $stackTrace');
    }
    return null;
  }

  /// Enrich only 'On Progress' claims with technician data
  Future<void> _enrichClaimsWithTechnician(List<dynamic> claims) async {
    print('\n🔍 ENRICHING ON PROGRESS CLAIMS WITH TECHNICIAN DATA...');
    print('Total claims to process: ${claims.length}');
    
    for (var i = 0; i < claims.length; i++) {
      var claim = claims[i];
      print('\n[CLAIM $i] Processing...');
      
      if (claim is! Map) {
        print('   ⏭️  Not a Map');
        continue;
      }
      
      final status = claim['status']?.toString().toLowerCase() ?? '';
      final isOnProgress = status.contains('progress') || status == 'on progress' || status == 'inprogress';
      
      print('   Status: "$status" -> OnProgress: $isOnProgress');
      
      if (!isOnProgress) {
        print('   ⏭️  Skipping - not On Progress');
        continue;
      }
      
      print('   📋 Processing ON PROGRESS claim ${claim['id']}');
      
      // Check 1: Flattened fields in claim
      if (claim['technicalUserName'] != null || claim['technicalUserPhone'] != null) {
        claim['_technicianData'] = {
          'name': claim['technicalUserName'] ?? 'N/A',
          'phoneNumber': claim['technicalUserPhone'] ?? 'N/A',
        };
        print('   ✅ Found flattened technician fields: ${claim['technicalUserName']}');
        continue;
      }
      
      // Also check for 'name' and 'phoneNumber' as alternatives
      if (claim['name'] != null || claim['phoneNumber'] != null) {
        claim['_technicianData'] = {
          'name': claim['name'] ?? 'N/A',
          'phoneNumber': claim['phoneNumber'] ?? 'N/A',
        };
        print('   ✅ Found name/phoneNumber fields');
        continue;
      }
      
      // Check 2: assignedTechnicalUserId - fetch via API
      if (claim['assignedTechnicalUserId'] != null) {
        final techId = claim['assignedTechnicalUserId'];
        print('   🔄 Found assignedTechnicalUserId: $techId');
        
        final techData = await _fetchTechnicianData(techId);
        
        if (techData != null) {
          claim['_technicianData'] = techData;
          print('   ✅ Technician data FETCHED and SET');
          continue;
        } else {
          print('   ⚠️ Technician API returned null');
        }
      }
      
      // Check 3: Technician object fields
      if (claim['assignedTechnician'] is Map) {
        claim['_technicianData'] = claim['assignedTechnician'];
        print('   ✅ Found assignedTechnician object');
      } else if (claim['assigned_technician'] is Map) {
        claim['_technicianData'] = claim['assigned_technician'];
        print('   ✅ Found assigned_technician object');
      } else if (claim['Technician'] is Map) {
        claim['_technicianData'] = claim['Technician'];
        print('   ✅ Found Technician object');
      } else if (claim['technician'] is Map) {
        claim['_technicianData'] = claim['technician'];
        print('   ✅ Found technician object');
      } else {
        print('   ℹ️ No technician data found');
      }
    }
    
    print('\n═══════════════════════════════');
    print('✅ ENRICHMENT COMPLETE\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Column(
              children: [
                const SizedBox(height: 20),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Filter
                        _buildStatusFilter(),
                        const SizedBox(height: 28),
                        // Claims List
                        _buildClaimsList(),
                        const SizedBox(height: 16),
                        // Pagination
                        if (_totalPages > 1) _buildPagination(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }



  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by Status',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E9C),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statuses
                .map((status) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _changeStatus(status),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedStatus == status
                                ? const Color(0xFF0070BA)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedStatus == status
                                  ? const Color(0xFF0070BA)
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                            boxShadow: _selectedStatus == status
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: _selectedStatus == status
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimsList() {
    if (_errorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 20),
          Text(
            'Failed to Load Claims',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[300]!, width: 2),
            ),
            child: SelectableText(
              _errorMessage!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red[900],
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _loadClaims,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E9C), Color(0xFF0070BA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Make sure you are logged in and the backend is running.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    if (_claims.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 48),
          Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No claims found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 48),
        ],
      );
    }

    return Column(
      children: List.generate(
        _claims.length,
        (index) {
          final claim = _claims[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildClaimCard(claim),
          );
        },
      ),
    );
  }

  Widget _buildClaimCard(dynamic claim) {
    print('Building claim card for: ${claim['id']}');
    
    final status = (claim['status'] ?? 'pending').toString().trim().toLowerCase();
    final statusColor = _getStatusColor(status);
    
    // Handle location - it's a Map from backend
    final locationData = claim['location'];
    String location = 'N/A';
    if (locationData is Map) {
      final address = locationData['address'] ?? '';
      if (address.isNotEmpty) {
        location = address;
      } else {
        final lat = locationData['latitude'] ?? 0;
        final lng = locationData['longitude'] ?? 0;
        location = '$lat, $lng';
      }
    } else if (locationData is String) {
      location = locationData;
    }
    
    final description = claim['description'] ?? 'No description';
    final createdAt = claim['createdAt'] ?? '';
    final images = claim['images'] as List? ?? [];
    final imagesCount = images.length;
    final notes = claim['notes'] ?? '';
    
    print('\n📋 ===== CLAIM DATA =====');
    print('Claim ID: ${claim['id']}');
    print('Raw Status: "${claim['status']}" (type: ${claim['status'].runtimeType})');
    print('Normalized Status: "$status"');
    print('All fields: ${claim.keys.toList()}');
    
    // Print all claim data for debugging
    claim.forEach((key, value) {
      print('  $key => $value (${value.runtimeType})');
    });
    print('═════════════════════════\n');
    
    // Extract technician info - only for 'On Progress' status (Option B: Flattened Fields)
    String technicianName = 'N/A';
    String technicianPhone = 'N/A';
    String clientPhone = 'N/A';
    final isOnProgress = status.contains('progress'); // Works with "on progress", "on-progress", "inprogress", etc.
    
    print('🔍 EXTRACTING TECHNICIAN INFO (On Progress: $isOnProgress)...');
    
    if (isOnProgress) {
      // For Option B: Backend sends name + phoneNumber directly in claim
      // OR we fetched it via assignedTechnicalUserId
      
      print('   🔍 Extracting technician info...');
      if (claim['_technicianData'] is Map) {
        final techData = claim['_technicianData'] as Map<String, dynamic>;
        technicianName = techData['name'] ?? techData['Username'] ?? 'N/A';
        technicianPhone = techData['phoneNumber'] ?? techData['PhoneNumber'] ?? 'N/A';
      } else {
        // Try direct claim fields - check all possible field names
        technicianName = claim['technicalUserName'] ?? claim['name'] ?? 'N/A';
        technicianPhone = claim['technicalUserPhone'] ?? claim['phoneNumber'] ?? 'N/A';
      }
      
      print('   ✅ Technician data extracted:');
      print('      Name: $technicianName');
      print('      Phone: $technicianPhone');
    } else {
      print('   ⏭️ Skipping - not On Progress status');
    }
    
    // Get client phone
    if (claim['ClientPhone'] != null) {
      clientPhone = claim['ClientPhone'];
    } else if (claim['client_phone'] != null) {
      clientPhone = claim['client_phone'];
    } else if (claim['UserPhone'] != null) {
      clientPhone = claim['UserPhone'];
    }
    
    print('   👤 Client Phone: $clientPhone');
    
    final isInProgress = isOnProgress;
    
    print('\n✅ EXTRACTED DATA:');
    print('   🔧 Technician Name: $technicianName');
    print('   🔧 Technician Phone: $technicianPhone');
    print('   👤 Client Phone: $clientPhone');
    print('═══════════════════════════════\n');
    
    print('📊 Status check: "$status" -> isInProgress: $isInProgress');
    print('🔧 Final Data - Technician: $technicianName ($technicianPhone), Client: $clientPhone');

    print('Claim details - description: $description, location: $location, status: $status');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 4,
          height: double.infinity,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
          ),
        ),
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    description.length > 35
                        ? '${description.substring(0, 35)}...'
                        : description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location.length > 40 ? '${location.substring(0, 40)}...' : location,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  'Images: $imagesCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show "On The Way" animation inside technician card
                _buildDetailRow('Location', location),
                Divider(
                  color: Colors.grey.shade300,
                ),
                // Show progress timeline instead of simple status
                _buildProgressTimeline(status),
                Divider(
                  color: Colors.grey.shade300,
                ),
                // Show technician section ONLY if 'On Progress' status
                if (isOnProgress && (technicianName != 'N/A' || technicianPhone != 'N/A')) ...[
                  Divider(
                    color: Colors.grey.shade300,
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '👨‍🔧 Assigned Technician (On Progress)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (technicianName != 'N/A')
                          _buildDetailRow('Name', technicianName)
                        else
                          _buildDetailRow('Name', technicianName, Colors.grey),
                        const SizedBox(height: 8),
                        if (technicianPhone != 'N/A')
                          _buildDetailRow('Phone', technicianPhone)
                        else
                          _buildDetailRow('Phone', technicianPhone, Colors.grey),
                      ],
                    ),
                  ),
                ],
                // Show Client Phone  
                if (clientPhone != 'N/A') ...[
                  Divider(
                    color: Colors.grey.shade300,
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '👤 Client (You)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Phone', clientPhone),
                      ],
                    ),
                  ),
                ],
                Divider(
                  color: Colors.grey.shade300,
                ),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(description),
                if (notes.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(notes),
                ],
                if (imagesCount > 0) ...[
                  Divider(
                    color: Colors.grey.shade300,
                  ),
                  const Text(
                    'Images',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: imagesCount,
                    itemBuilder: (context, idx) {
                      final imageData = images[idx];

                      // Normalize different backend image shapes: String, Map, data URI, or plain filename
                      String? rawImage;
                      if (imageData is Map) {
                        final possibleFields = [
                          'url', 'image', 'path', 'file_path', 'filePath', 'fileUrl', 'uploadUrl', 'filename'
                        ];
                        for (var f in possibleFields) {
                          if (imageData.containsKey(f) && imageData[f] != null && imageData[f].toString().isNotEmpty) {
                            rawImage = imageData[f].toString();
                            break;
                          }
                        }
                        rawImage ??= imageData.toString();
                      } else if (imageData is String) {
                        rawImage = imageData;
                      } else if (imageData != null) {
                        rawImage = imageData.toString();
                      }

                      final isDataUri = rawImage != null && rawImage.startsWith('data:') && rawImage.contains('base64,');

                      // More robust base64 heuristics:
                      // - Common image signature prefixes when base64 encoded
                      // - GIF: "R0lGOD" | WebP: "UklGR" | BMP: "Qk" | JPEG: "/9j/" | PNG: "iVBOR"
                      // - Also treat long strings or pure-base64-like strings as base64
                      bool isLikelyBase64 = false;
                      if (rawImage != null) {
                        final s = rawImage;
                        final prefixes = ['/9j/', 'iVBOR', 'R0lGOD', 'UklGR', 'Qk'];
                        for (var p in prefixes) {
                          if (s.startsWith(p)) {
                            isLikelyBase64 = true;
                            break;
                          }
                        }

                        // data URI already handled by isDataUri; check for long payloads
                        if (!isLikelyBase64) {
                          if (s.length > 800) isLikelyBase64 = true;
                        }

                        // Heuristic: if string is composed only of base64 chars and padding, and reasonably long
                        if (!isLikelyBase64) {
                          final base64Like = RegExp(r'^[A-Za-z0-9+/=\s]+$');
                          if (s.length > 200 && base64Like.hasMatch(s)) isLikelyBase64 = true;
                        }
                      }

                      // Debug: print image detection info so we can inspect runtime values
                      try {
                        final normalizedPreview = (rawImage ?? '').length > 120
                            ? '${(rawImage ?? '').substring(0, 120)}...'
                            : (rawImage ?? '');
                        final normalizedUrl = (rawImage != null && !isLikelyBase64 && !isDataUri)
                            ? _normalizeImageUrl(rawImage)
                            : '(in-memory/base64)';
                        print('IMAGE DEBUG -> raw: $normalizedPreview');
                        print('IMAGE DEBUG -> isDataUri: $isDataUri, isLikelyBase64: $isLikelyBase64');
                        print('IMAGE DEBUG -> normalized URL: $normalizedUrl');
                      } catch (e) {
                        print('IMAGE DEBUG -> failed to print debug info: $e');
                      }

                      return GestureDetector(
                        onTap: () {
                          final preview = (rawImage ?? '').length > 60 ? '${(rawImage ?? '').substring(0, 60)}...' : (rawImage ?? '');
                          print('Tapped image: $preview');
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: (rawImage != null && rawImage.isNotEmpty)
                              ? (isDataUri
                                  // data:image/...;base64,<data>
                                  ? _buildBase64Image(rawImage.split('base64,').last)
                                  : (isLikelyBase64
                                      ? _buildBase64Image(rawImage)
                                      : Image.network(
                                          _normalizeImageUrl(rawImage),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            final imageUrl = _normalizeImageUrl(rawImage!);
                                            print('Image.network error for URL: $imageUrl -> $error');
                                            return _buildImageFromUrlFallback(imageUrl);
                                          },
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return _buildImageLoading();
                                          },
                                        )))
                              : _buildImageError(),
                        ),
                      );
                    },
                  ),
                ],
                Divider(
                  color: Colors.grey.shade300,
                ),
                _buildDetailRow('Submitted', _formatDate(createdAt)),
                Divider(
                  color: Colors.grey.shade300,
                ),
                _buildDetailRow('Last Updated', _formatDate(claim['updatedAt'] ?? '')),
                Divider(
                  color: Colors.grey.shade300,
                ),
                _buildDetailRow('Claim ID', claim['id'] ?? 'N/A'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTimeline(String? status) {
    // Handle null status
    if (status == null || status.isEmpty) {
      status = 'pending';
    } else {
      status = status.trim().toLowerCase();
    }
    
    print('📊 _buildProgressTimeline called with: "$status"');
    
    // Map status to progress index
    int currentStep = _getProgressStep(status);
    print('📊 Current step after mapping: $currentStep');
    
    if (currentStep < 0) {
      currentStep = 0; // Default to waiting state
      print('⚠️ Unknown status, defaulting to step 0');
    }
    
    int totalSteps = 4;
    int progressPercent = ((currentStep + 1) / totalSteps * 100).toInt();
    print('📊 Progress: Step $currentStep/$totalSteps = $progressPercent%');
    
    final steps = [
      {
        'icon': Icons.hourglass_empty,
        'label': 'Waiting',
        'color': Colors.orange,
      },
      {
        'icon': Icons.person,
        'label': 'Technician Confirmed',
        'color': Colors.purple,
      },
      {
        'icon': Icons.two_wheeler,
        'label': 'Technician On the Way',
        'color': Colors.green,
      },
      {
        'icon': Icons.check_circle,
        'label': 'Claim Solved',
        'color': Colors.teal,
      },
    ];
    
    // Get safe color reference
    final currentStepIndex = currentStep.clamp(0, totalSteps - 1);
    final currentStepColor = (steps[currentStepIndex]['color'] as Color?) ?? Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Claim Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: currentStepColor,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: currentStepColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$progressPercent%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        SizedBox(
          height: 110,
          child: Stack(
            children: [
              // Background line with gradient
              Positioned(
                top: 25,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF0F0F0), Color(0xFFE0E0E0)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Progress line with vibrant gradient and glow
              Positioned(
                top: 23,
                left: 0,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 700),
                  curve: Curves.easeInOutCubic,
                  width: ((currentStep + 1) / totalSteps) *
                      (MediaQuery.of(context).size.width - 60),
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.orange[300]!,
                        Colors.orange[500]!,
                        Colors.pink[400]!,
                        Colors.purple[400]!,
                        Colors.blue[400]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.7),
                        blurRadius: 16,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // Shimmer overlay for extra live effect
              Positioned(
                top: 23,
                left: 0,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 700),
                  curve: Curves.easeInOutCubic,
                  width: ((currentStep + 1) / totalSteps) *
                      (MediaQuery.of(context).size.width - 60),
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
              // Steps with enhanced styling
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(steps.length, (index) {
                  final step = steps[index];
                  final isCompleted = index <= currentStep;
                  final isActive = index == currentStep;
                  final stepColor = step['color'] as Color;

                  return Column(
                    children: [
                      // Animated container for active step
                      if (isActive)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: 1.25),
                          duration: Duration(seconds: 1),
                          curve: Curves.easeInOut,
                          builder: (context, scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: _buildStepCircle(
                            stepColor,
                            step['icon'] as IconData,
                            isCompleted,
                            isActive,
                          ),
                        )
                      else
                        _buildStepCircle(
                          stepColor,
                          step['icon'] as IconData,
                          isCompleted,
                          isActive,
                        ),
                      SizedBox(height: 10),
                      SizedBox(
                        width: 70,
                        child: Column(
                          children: [
                            Text(
                              step['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : (isCompleted ? FontWeight.w600 : FontWeight.normal),
                                color: isCompleted 
                                    ? stepColor 
                                    : Colors.grey[400],
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (isActive)
                              Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Container(
                                  width: 20,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: stepColor,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepCircle(Color color, IconData icon, bool isCompleted, bool isActive) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCompleted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
              )
            : LinearGradient(
                colors: [Color(0xFFFAFAFA), Color(0xFFF0F0F0)],
              ),
        border: Border.all(
          color: isActive 
              ? color 
              : (isCompleted ? color.withOpacity(0.7) : Colors.grey[300]!),
          width: isActive ? 4 : (isCompleted ? 2 : 1.5),
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: color.withOpacity(0.6),
              blurRadius: 14,
              spreadRadius: 3,
            ),
          if (isActive)
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 1,
              offset: Offset(0, 4),
            ),
          if (isCompleted && !isActive)
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 6,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          color: isCompleted ? Colors.white : Colors.grey[500],
          size: isActive ? 26 : 22,
        ),
      ),
    );
  }

  int _getProgressStep(String status) {
    final cleanStatus = status.toLowerCase().trim();
    
    switch (cleanStatus) {
      case 'pending':
        return 0; // Waiting
      case 'on progress':
      case 'onprogress':
      case 'on-progress':
      case 'in progress':
      case 'inprogress':
      case 'in-progress':
        return 1; // Technician Confirmed (show progress at this step)
      case 'completed':
      case 'done':
      case 'claim solved':
        return 3; // Claim Solved
      default:
        // Debug: log unknown status
        print('⚠️ Unknown status in _getProgressStep: "$status" -> "$cleanStatus"');
        return -1; // Unknown (excludes approved and other statuses)
    }
  }

  Widget _buildRepeatingBikeAnimation() {
    return _RepeatingBikeAnimation();
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _currentPage > 1 ? _previousPage : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: _currentPage > 1 ? const Color(0xFF0070BA) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _currentPage > 1
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: _currentPage > 1 ? Colors.white : Colors.grey[500],
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Previous',
                        style: TextStyle(
                          color: _currentPage > 1 ? Colors.white : Colors.grey[500],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: _currentPage < _totalPages ? _nextPage : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: _currentPage < _totalPages ? const Color(0xFF0070BA) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _currentPage < _totalPages
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          color: _currentPage < _totalPages ? Colors.white : Colors.grey[500],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward,
                        color: _currentPage < _totalPages ? Colors.white : Colors.grey[500],
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final cleanStatus = status.toLowerCase().trim();
    
    switch (cleanStatus) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'on progress':
      case 'onprogress':
      case 'on-progress':
      case 'in progress':
      case 'inprogress':
      case 'in-progress':
        return Colors.blue;
      case 'completed':
      case 'done':
      case 'claim solved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  /// Decode and display base64 image
  Widget _buildBase64Image(String base64String) {
    try {
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error decoding base64 image: $error');
          return _buildImageError();
        },
      );
    } catch (e) {
      print('Failed to decode base64: $e');
      return _buildImageError();
    }
  }

  /// Fallback: fetch URL as text, detect & decode base64, or show error
  Widget _buildImageFromUrlFallback(String imageUrl) {
    return FutureBuilder<Widget>(
      future: _fetchAndDecodeImageAsBase64(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildImageLoading();
        }
        if (snapshot.hasError) {
          print('Fallback decode error: ${snapshot.error}');
          return _buildImageError();
        }
        return snapshot.data ?? _buildImageError();
      },
    );
  }

  /// Fetch URL as binary and display directly
  Future<Widget> _fetchAndDecodeImageAsBase64(String imageUrl) async {
    // if we're offline just bail early
    if (!await NetworkService().isConnected()) {
      print('   ⚠️ Fallback aborted – no network connection');
      return _buildImageError();
    }
    try {
      print('📥 Fallback: fetching image as binary...');
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(imageUrl));
      request.headers.set('Connection', 'close');
      final response = await request.close();
      
      print('   📊 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final bodyBytes = await response.fold<List<int>>([], (p, chunk) => p..addAll(chunk));
        print('   ✅ Received ${bodyBytes.length} bytes');
        
        if (bodyBytes.isEmpty) {
          print('   ❌ Empty response');
          return _buildImageError();
        }
        
        // Display directly with Image.memory
        return Image.memory(
          Uint8List.fromList(bodyBytes),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            // extra diagnostics when decode fails
            final snippetLength = bodyBytes.length < 20 ? bodyBytes.length : 20;
            final hexSnippet = bodyBytes.take(snippetLength).map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ');
            String textSnippet;
            try {
              textSnippet = String.fromCharCodes(bodyBytes.take(100).toList());
            } catch (_) {
              textSnippet = '<unable to convert to text>';
            }
            print('   ❌ Image.memory error: $error');
            print('      first $snippetLength bytes (hex): $hexSnippet');
            print('      text snippet: $textSnippet');
            return _buildImageError();
          },
        );
      } else {
        print('   ❌ HTTP ${response.statusCode}');
        return _buildImageError();
      }
    } catch (e) {
      print('   ❌ Fallback error: $e');
      return _buildImageError();
    }
  }

  /// Helper (now unused, kept for reference)
  Widget _attemptBase64Fallback(List<int> bodyBytes) {
    return _buildImageError();
  }

  /// Loading state widget
  Widget _buildImageLoading() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  /// Error state widget
  Widget _buildImageError() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey),
          const SizedBox(height: 4),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Normalize image URL returned from backend.
  /// If the backend returns a relative path like '/uploads/..',
  /// prefix it with the server origin derived from `ApiService.baseUrl`.
  String _normalizeImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;

    // Normalize known backend folder variants: '/upload' -> '/uploads'
    var path = imagePath;
    if (path == '/upload') {
      path = '/uploads';
    } else if (path.startsWith('/upload/') && !path.startsWith('/uploads/')) {
      path = path.replaceFirst('/upload/', '/uploads/');
    }

    final base = ApiService.baseUrl ?? '';
    try {
      final uri = Uri.parse(base);
      final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      if (path.startsWith('/')) return origin + path;
      return '$origin/$path';
    } catch (e) {
      // Fallback: strip trailing '/api' if present
      var b = base;
      if (b.endsWith('/')) b = b.substring(0, b.length - 1);
      b = b.replaceFirst(RegExp(r'/api$'), '');
      if (path.startsWith('/')) return b + path;
      return '$b/$path';
    }
  }

  String _buildDebugInfo() {
    if (_lastResponse == null) return 'No debug info available';
    
    final buffer = StringBuffer();
    buffer.writeln('Status Code: ${_lastResponse!['statusCode'] ?? 'N/A'}');
    buffer.writeln('');
    
    if (_lastResponse!.containsKey('message')) {
      buffer.writeln('Message:');
      buffer.writeln('  ${_lastResponse!['message']}');
      buffer.writeln('');
    }
    
    if (_lastResponse!.containsKey('error')) {
      buffer.writeln('Error Details:');
      final error = _lastResponse!['error'];
      if (error is Map) {
        buffer.writeln('  ${error.toString()}');
      } else {
        buffer.writeln('  $error');
      }
      buffer.writeln('');
    }
    
    if (_lastResponse!.containsKey('rawResponse')) {
      buffer.writeln('Raw Response:');
      buffer.writeln('  ${_lastResponse!['rawResponse']}');
      buffer.writeln('');
    }
    
    buffer.writeln('All Fields:');
    for (var key in _lastResponse!.keys) {
      final value = _lastResponse![key];
      final valueStr = value is Map ? value.toString() : '$value';
      buffer.writeln('  $key: $valueStr');
    }
    
    return buffer.toString();
  }
}

class _RepeatingBikeAnimation extends StatefulWidget {
  const _RepeatingBikeAnimation();

  @override
  State<_RepeatingBikeAnimation> createState() => _RepeatingBikeAnimationState();
}

class _RepeatingBikeAnimationState extends State<_RepeatingBikeAnimation>
    with TickerProviderStateMixin {
  late AnimationController _bikeController;
  late AnimationController _wheelController;
  late AnimationController _pedalController;

  @override
  void initState() {
    super.initState();
    _bikeController = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _wheelController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..repeat();

    _pedalController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _bikeController.dispose();
    _wheelController.dispose();
    _pedalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated road/path line
          Positioned(
            bottom: 12,
            child: Container(
              width: 4000,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[300]!,
                    Colors.blue[400]!,
                    Colors.grey[300]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Animated progress line
          Positioned(
            bottom: 9,
            child: AnimatedBuilder(
              animation: _bikeController,
              builder: (context, child) {
                return Container(
                  width: 4000 * _bikeController.value,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue[300]!,
                        Colors.blue[400]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
          // Animated bike rider
          AnimatedBuilder(
            animation: _bikeController,
            builder: (context, child) {
              double bikePosition = (_bikeController.value * 4000) - 2000;
              return Transform.translate(
                offset: Offset(bikePosition, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Spinning wheels
                        AnimatedBuilder(
                          animation: _wheelController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _wheelController.value * 6.28,
                              child: Icon(
                                Icons.circle,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                            );
                          },
                        ),
                        // Bike rider with pedaling motion
                        AnimatedBuilder(
                          animation: _pedalController,
                          builder: (context, child) {
                            double pedalbounce =
                                (_pedalController.value < 0.5)
                                    ? _pedalController.value * 6
                                    : (1 - _pedalController.value) * 6;
                            return Transform.translate(
                              offset: Offset(0, -pedalbounce),
                              child: Icon(
                                Icons.two_wheeler,
                                color: Colors.blue[600],
                                size: 36,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Speed indicator particle
          AnimatedBuilder(
            animation: _bikeController,
            builder: (context, child) {
              return Positioned(
                right: -2000 + (_bikeController.value * 4000),
                bottom: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.blue[400]!,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue[300]!.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
