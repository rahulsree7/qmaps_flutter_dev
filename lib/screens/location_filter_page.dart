import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';

class LocationFilterPage extends StatefulWidget {
  final String? sourceType; // 'task' or 'checklist'

  const LocationFilterPage({
    super.key,
    this.sourceType,
  });

  @override
  State<LocationFilterPage> createState() => _LocationFilterPageState();
}

class _LocationFilterPageState extends State<LocationFilterPage> {
  List<dynamic> zones = [];
  List<dynamic> verticals = [];
  List<dynamic> locations = [];

  dynamic selectedZone;
  dynamic selectedVertical;
  dynamic selectedLocation;

  bool loadingZones = true;
  bool loadingVerticals = false;
  bool loadingLocations = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() {
      loadingZones = true;
      errorMessage = null;
    });

    print('Debug - Loading zones...');
    final result = await TaskService.getZones();
    print('Debug - Zones result: $result');

    if (mounted) {
      setState(() {
        if (result['success']) {
          zones = result['zones'] ?? [];
          print('Debug - Zones loaded: ${zones.length}');
        } else {
          errorMessage = result['message'] ?? 'Failed to load zones';
          print('Debug - Error loading zones: $errorMessage');
        }
        loadingZones = false;
      });
    }
  }

  Future<void> _loadVerticalsByZone() async {
    if (selectedZone == null) return;

    setState(() {
      loadingVerticals = true;
      verticals = [];
      selectedVertical = null;
      locations = [];
      selectedLocation = null;
      errorMessage = null;
    });

    print('Debug - Loading verticals for zone: ${selectedZone['id']}');
    final result = await TaskService.getVerticalsByZone(selectedZone['id']);
    print('Debug - Verticals result: $result');

    if (mounted) {
      setState(() {
        if (result['success']) {
          verticals = result['verticals'] ?? [];
          print('Debug - Verticals loaded: ${verticals.length}');
        } else {
          errorMessage = result['message'] ?? 'Failed to load verticals';
          print('Debug - Error loading verticals: $errorMessage');
        }
        loadingVerticals = false;
      });
    }
  }

  Future<void> _loadLocationsByVertical() async {
    if (selectedVertical == null) return;

    setState(() {
      loadingLocations = true;
      locations = [];
      selectedLocation = null;
      errorMessage = null;
    });

    final result =
        await TaskService.getLocationsByVertical(selectedVertical['id']);

    if (mounted) {
      setState(() {
        if (result['success']) {
          locations = result['locations'] ?? [];
        } else {
          errorMessage = result['message'] ?? 'Failed to load locations';
        }
        loadingLocations = false;
      });
    }
  }

  void _selectLocation() {
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a location'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Navigate back with the selected location
    Navigator.pop(context, {
      'zone': selectedZone,
      'vertical': selectedVertical,
      'location': selectedLocation,
    });
  }

  Widget _buildHeaderSection() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              shadowColor: Colors.black.withOpacity(0.05),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context),
                splashColor: Colors.black.withOpacity(0.05),
                highlightColor: Colors.black.withOpacity(0.02),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.black87, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                'Select Location',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header matching checklist page style
            _buildHeaderSection(),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Message
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppTheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: AppTheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Zone Section
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Step 1: Select Zone',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (loadingZones)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryPurple),
                        ),
                      )
                    else if (zones.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.primaryPurple.withOpacity(0.7),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No zones available for your workspace.',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<dynamic>(
                          value: selectedZone,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: AppTheme.primaryPurple, width: 2),
                            ),
                            filled: true,
                            fillColor: AppTheme.cardBackground,
                          ),
                          hint: Text(
                            'Select a zone',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          items: zones.map((zone) {
                            return DropdownMenuItem<dynamic>(
                              value: zone,
                              child: Text(
                                zone['name'] ?? 'Unknown',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedZone = value;
                              if (value != null) {
                                _loadVerticalsByZone();
                              } else {
                                verticals = [];
                                selectedVertical = null;
                                locations = [];
                                selectedLocation = null;
                              }
                            });
                          },
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryPurple,
                          ),
                          dropdownColor: AppTheme.cardBackground,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Vertical Section
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Step 2: Select Vertical',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedZone == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: AppTheme.primaryPurple.withOpacity(0.7),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Select a zone first',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (loadingVerticals)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryPurple),
                        ),
                      )
                    else if (verticals.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.primaryPurple.withOpacity(0.7),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No verticals available for this zone',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<dynamic>(
                          value: selectedVertical,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: AppTheme.primaryPurple, width: 2),
                            ),
                            filled: true,
                            fillColor: AppTheme.cardBackground,
                          ),
                          hint: Text(
                            'Select a vertical',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          items: verticals.map((vertical) {
                            return DropdownMenuItem<dynamic>(
                              value: vertical,
                              child: Text(
                                vertical['vertical_name'] ?? 'Unknown',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedVertical = value;
                              if (value != null) {
                                _loadLocationsByVertical();
                              } else {
                                locations = [];
                                selectedLocation = null;
                              }
                            });
                          },
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryPurple,
                          ),
                          dropdownColor: AppTheme.cardBackground,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Location Section
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Step 3: Select Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedVertical == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: AppTheme.primaryPurple.withOpacity(0.7),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Select a vertical first',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (loadingLocations)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryPurple),
                        ),
                      )
                    else if (locations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.primaryPurple.withOpacity(0.7),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No locations available for this vertical',
                                style: AppTheme.bodyMedium
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<dynamic>(
                          value: selectedLocation,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: AppTheme.primaryPurple, width: 2),
                            ),
                            filled: true,
                            fillColor: AppTheme.cardBackground,
                          ),
                          hint: Text(
                            'Select a location',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          items: locations.map((location) {
                            return DropdownMenuItem<dynamic>(
                              value: location,
                              child: Text(
                                location['title'] ?? 'Unknown',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedLocation = value;
                            });
                          },
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.primaryPurple,
                          ),
                          dropdownColor: AppTheme.cardBackground,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Select Button
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            selectedLocation != null ? _selectLocation : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: AppTheme.textLight,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: selectedLocation != null ? 4 : 0,
                          shadowColor: AppTheme.primaryPurple.withOpacity(0.3),
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                        ),
                        child: Text(
                          'Select Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: selectedLocation != null
                                ? AppTheme.textLight
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryPurple,
                          side: BorderSide(
                            color: AppTheme.primaryPurple.withOpacity(0.5),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
