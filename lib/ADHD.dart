import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'user_activity_service.dart';

// Global navigator key for showing dialogs from anywhere
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

// Global Timer Service
class FocusTimerService extends ChangeNotifier {
  static final FocusTimerService _instance = FocusTimerService._internal();
  factory FocusTimerService() => _instance;
  FocusTimerService._internal() {
    _initializeTimer();
  }

  late StopWatchTimer _stopWatchTimer;
  int _selectedMinutes = 25;
  int _presetMilliseconds = 25 * 60 * 1000; // 25 minutes in milliseconds
  bool _isCompleted = false;
  bool _isRunning = false; // Local running state for immediate UI updates

  // Getters
  int get selectedMinutes => _selectedMinutes;
  int get presetMilliseconds => _presetMilliseconds;
  StopWatchTimer get stopWatchTimer => _stopWatchTimer;
  bool get isRunning =>
      _isRunning; // Use local state instead of stopwatch state
  bool get isActive => isRunning;
  bool get isCompleted => _isCompleted;

  void _initializeTimer() {
    _stopWatchTimer = StopWatchTimer(
      mode: StopWatchMode.countDown,
      presetMillisecond: _presetMilliseconds,
      onChange: (value) {
        print(
          "DEBUG: Timer value changed to: $value, isRunning: ${_stopWatchTimer.isRunning}",
        );
        // Check if timer has completed (value reached 0)
        if (value == 0 && !_isCompleted) {
          print("DEBUG: Timer reached 0, calling completion!");
          _onTimerCompleted();
        }
        notifyListeners();
      },
    );
  }

  void setDuration(int minutes) {
    if (!isRunning) {
      _selectedMinutes = minutes;
      _presetMilliseconds = minutes * 60 * 1000;
      _resetTimerWithNewDuration();
      notifyListeners();
    }
  }

  void setDurationInSeconds(int seconds) {
    if (!isRunning) {
      _selectedMinutes = (seconds / 60).ceil();
      _presetMilliseconds = seconds * 1000;
      _resetTimerWithNewDuration();
      notifyListeners();
    }
  }

  void _resetTimerWithNewDuration() {
    _stopWatchTimer.dispose();
    _isCompleted = false;
    _isRunning = false; // Reset running state
    _initializeTimer();
  }

  void startTimer() {
    _isCompleted = false;
    _isRunning = true; // Update local state immediately
    _stopWatchTimer.onStartTimer();
    notifyListeners(); // Trigger UI rebuild immediately
  }

  void pauseTimer() {
    _isRunning = false; // Update local state immediately
    _stopWatchTimer.onStopTimer();
    notifyListeners(); // Trigger UI rebuild immediately
  }

  void resetTimer() {
    _isCompleted = false;
    _isRunning = false; // Update local state immediately
    _stopWatchTimer.onResetTimer();
    notifyListeners(); // Trigger UI rebuild immediately
  }

  void _onTimerCompleted() {
    print("DEBUG: Timer completed! Setting completion flags...");
    _isCompleted = true;
    _isRunning = false; // Ensure running state is false when completed

    // Track focus session completion
    UserActivityService.trackFocusSession(_selectedMinutes);

    // Play completion effects
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.heavyImpact();

    // Notify completion for global dialog
    _showCompletionDialogGlobally = true;
    print("DEBUG: Global completion dialog flag set to true");

    notifyListeners();

    // Show dialog directly using global navigator
    _showCompletionDialogDirectly();

    // Also try to trigger a delayed notification to ensure it propagates
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_showCompletionDialogGlobally) {
        print("DEBUG: Delayed notification for completion dialog");
        notifyListeners();
      }
    });
  }

  void _showCompletionDialogDirectly() {
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      print("DEBUG: Showing completion dialog directly");
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.celebration, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('Session Complete!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Great job! You\'ve completed your ${_selectedMinutes}-minute focus session.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  '🎉 Keep up the great work! 🎉',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7B2D93),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  resetTimer();
                  _showCompletionDialogGlobally = false;
                  notifyListeners();
                },
                child: Text(
                  'Start New Session',
                  style: TextStyle(color: Color(0xFF7B2D93)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showCompletionDialogGlobally = false;
                  notifyListeners();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF7B2D93),
                  foregroundColor: Colors.white,
                ),
                child: Text('Done'),
              ),
            ],
          );
        },
      );
    } else {
      print("DEBUG: No valid context found for showing dialog");
    }
  }

  // Global completion dialog flag
  bool _showCompletionDialogGlobally = false;
  bool get shouldShowCompletionDialog => _showCompletionDialogGlobally;

  void clearCompletionDialog() {
    _showCompletionDialogGlobally = false;
    _isCompleted = false;
    notifyListeners();
  }

  String formatTime(int milliseconds) {
    return StopWatchTimer.getDisplayTime(
      milliseconds,
      hours: false,
      milliSecond: false,
    );
  }

  @override
  void dispose() {
    _stopWatchTimer.dispose();
    super.dispose();
  }
}

// Consumer widget import for state management
class Consumer<T extends ChangeNotifier> extends StatelessWidget {
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  const Consumer({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final service = context
        .dependOnInheritedWidgetOfExactType<_InheritedProvider<T>>();
    return builder(context, service!.service, child);
  }
}

class ChangeNotifierProvider<T extends ChangeNotifier> extends StatefulWidget {
  final T create;
  final Widget child;

  const ChangeNotifierProvider({
    super.key,
    required this.create,
    required this.child,
  });

  @override
  State<ChangeNotifierProvider<T>> createState() =>
      _ChangeNotifierProviderState<T>();
}

class _ChangeNotifierProviderState<T extends ChangeNotifier>
    extends State<ChangeNotifierProvider<T>> {
  late T _service;

  @override
  void initState() {
    super.initState();
    _service = widget.create;
    _service.addListener(_listener);
  }

  void _listener() {
    setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedProvider<T>(service: _service, child: widget.child);
  }
}

class _InheritedProvider<T extends ChangeNotifier> extends InheritedWidget {
  final T service;

  const _InheritedProvider({required this.service, required super.child});

  @override
  bool updateShouldNotify(covariant _InheritedProvider<T> oldWidget) {
    return service != oldWidget.service;
  }
}

class ADHDPage extends StatefulWidget {
  const ADHDPage({super.key});

  @override
  State<ADHDPage> createState() => _ADHDPageState();
}

class _ADHDPageState extends State<ADHDPage> {
  List<Map<String, String>> uploadedDocuments = [];
  static const String _geminiApiKey = 'AIzaSyDXCrnGQgAF__FotBEfYythr8-MgJAKuOY';
  late final GenerativeModel _model;

  // User stats
  Map<String, dynamic> _userStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _loadUploadedDocuments();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await UserActivityService.getUserStats();
      setState(() {
        _userStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      print('Error loading user stats: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  void _initializeGemini() {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
  }

  // Load uploaded documents from local storage
  Future<void> _loadUploadedDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsJson = prefs.getString('adhd_uploaded_documents');
    if (documentsJson != null) {
      final List<dynamic> documentsList = json.decode(documentsJson);
      setState(() {
        uploadedDocuments = documentsList
            .map((doc) => Map<String, String>.from(doc))
            .toList();
      });
    }
  }

  // Save uploaded documents to local storage
  Future<void> _saveUploadedDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsJson = json.encode(uploadedDocuments);
    await prefs.setString('adhd_uploaded_documents', documentsJson);
  }

  // Upload document functionality
  Future<void> _uploadDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileExtension = result.files.single.extension ?? '';
        final fileSize = result.files.single.size;

        // Validate file extension - reject unsupported file types
        final unsupportedExtensions = [
          'csv',
          'xls',
          'xlsx',
          'pptx',
          'ppt',
          'xlsm',
          'xlsb',
          'ods',
          'odp',
        ];
        final supportedExtensions = ['pdf', 'docx', 'txt'];

        if (unsupportedExtensions.contains(fileExtension.toLowerCase())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error 400: Unsupported file type ".$fileExtension". Only PDF, DOCX, and TXT files are supported.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        if (!supportedExtensions.contains(fileExtension.toLowerCase())) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error 400: Invalid file type ".$fileExtension". Only PDF, DOCX, and TXT files are supported.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // Show processing dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text('Processing document with AI...'),
                ],
              ),
            ),
          );
        }

        // Process file with Gemini AI - Skip initial processing since we only need summary and flashcards
        String aiSummary =
            'Document uploaded successfully. Use Summary and Flash Cards buttons below.';
        String aiInsights =
            'Click the buttons below to generate ADHD-optimized content.';

        // Close processing dialog
        if (mounted) {
          Navigator.pop(context);
        }

        // Create a document entry
        final document = {
          'name': fileName,
          'path': file.path,
          'extension': fileExtension,
          'size': _formatFileSize(fileSize),
          'uploadDate': DateTime.now().toIso8601String(),
          'aiSummary': aiSummary,
          'aiInsights': aiInsights,
        };

        setState(() {
          uploadedDocuments.add(document);
        });

        await _saveUploadedDocuments();

        // Track document upload activity
        await UserActivityService.trackDocumentUpload(fileName, file.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Document "$fileName" uploaded and processed successfully!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close processing dialog if it's open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Extract content from file based on type
  // Extract content from file based on type
  Future<String> _extractFileContent(File file, String extension) async {
    try {
      print(
        'Extracting content from file: ${file.path}, extension: $extension',
      );

      switch (extension.toLowerCase()) {
        case 'txt':
          final content = await file.readAsString();
          print('TXT file content length: ${content.length}');
          return content;

        case 'pdf':
          try {
            final bytes = await file.readAsBytes();
            final document = PdfDocument(inputBytes: bytes);
            final PdfTextExtractor extractor = PdfTextExtractor(document);
            final content = extractor.extractText();
            document.dispose();
            print('PDF file content length: ${content.length}');
            return content.isNotEmpty
                ? content
                : 'Unable to extract text from this PDF file. The file may be image-based or encrypted.';
          } catch (e) {
            print('Error extracting PDF content: $e');
            return 'Error extracting content from PDF file: $e';
          }

        case 'docx':
          try {
            final bytes = await file.readAsBytes();
            final archive = ZipDecoder().decodeBytes(bytes);

            // Look for document.xml file in the archive
            for (final file in archive) {
              if (file.name == 'word/document.xml') {
                final content = utf8.decode(file.content as List<int>);
                // Basic XML parsing to extract text content
                final textContent = _extractTextFromDocxXml(content);
                print('DOCX file content length: ${textContent.length}');
                return textContent.isNotEmpty
                    ? textContent
                    : 'Unable to extract text from this DOCX file.';
              }
            }
            return 'Unable to find document content in DOCX file.';
          } catch (e) {
            print('Error extracting DOCX content: $e');
            return 'Error extracting content from DOCX file: $e';
          }

        default:
          print('Unsupported file extension: $extension');
          return 'Unsupported file type: $extension. Please upload TXT, PDF, or DOCX files.';
      }
    } catch (e) {
      print('Error extracting file content: $e');
      return 'Error reading file: $e';
    }
  }

  // Basic XML text extraction for DOCX files
  String _extractTextFromDocxXml(String xmlContent) {
    try {
      // Remove XML tags and extract text content
      // This is a simplified approach - for production use a proper XML parser
      String text = xmlContent;

      // Find all <w:t> tags which contain the actual text
      final RegExp textRegex = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
      final matches = textRegex.allMatches(text);

      final StringBuffer extractedText = StringBuffer();
      for (final match in matches) {
        final textContent = match.group(1);
        if (textContent != null && textContent.trim().isNotEmpty) {
          extractedText.write(textContent);
          extractedText.write(' ');
        }
      }

      // Also look for simpler text patterns
      if (extractedText.isEmpty) {
        final RegExp simpleTextRegex = RegExp(r'>([^<>\n]+)<');
        final simpleMatches = simpleTextRegex.allMatches(text);
        for (final match in simpleMatches) {
          final textContent = match.group(1)?.trim();
          if (textContent != null &&
              textContent.isNotEmpty &&
              textContent.length > 2) {
            extractedText.write(textContent);
            extractedText.write(' ');
          }
        }
      }

      return extractedText.toString().trim();
    } catch (e) {
      print('Error parsing DOCX XML: $e');
      return '';
    }
  }

  // Generate ADHD-focused summary
  Future<String> _generateADHDSummary(String content, String fileName) async {
    try {
      print('Generating ADHD summary for: $fileName');
      print('Content length: ${content.length}');
      print(
        'Content preview: ${content.length > 200 ? content.substring(0, 200) : content}...',
      );

      final prompt =
          '''
Create a comprehensive summary specifically designed for ADHD learners from this document. 

Requirements:
1. Use clear, concise language
2. Break information into digestible chunks
3. Highlight key concepts that should be emphasized
4. Use bullet points for better readability
5. Focus on the most important information first
6. Make it engaging and easy to follow

Mark important concepts with **bold** formatting and key terms with ***bold italic*** formatting.

Document: $fileName
Content: $content

Format as a well-structured summary with clear sections and emphasis on crucial points.
''';

      print('Sending prompt to Gemini API...');
      final response = await _model.generateContent([Content.text(prompt)]);
      final result =
          response.text ?? 'Unable to generate summary at this time.';
      print('Received response from Gemini. Length: ${result.length}');

      return result;
    } catch (e) {
      print('Summary generation error: $e');
      return 'Unable to generate summary. Error: $e';
    }
  }

  // Generate flash cards for ADHD learners
  Future<List<Map<String, String>>> _generateFlashCards(
    String content,
    String fileName,
  ) async {
    try {
      final prompt =
          '''
Create flash cards specifically designed for ADHD learners from this document content.

Requirements for ADHD-friendly flash cards:
1. Keep questions short and focused (1-2 sentences max)
2. Make answers clear and concise 
3. Focus on key concepts, definitions, and important facts
4. Use simple, direct language
5. Create 5-8 cards maximum to avoid overwhelm
6. Make questions specific and actionable

Document: $fileName
Content: $content

Format each card as:
CARD_START
QUESTION: [Clear, specific question]
ANSWER: [Concise, focused answer]
CARD_END

Create cards that help reinforce the most important concepts from this material.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      // Parse flash cards
      List<Map<String, String>> flashCards = [];
      final cardMatches = RegExp(
        r'CARD_START(.*?)CARD_END',
        dotAll: true,
      ).allMatches(responseText);

      for (final match in cardMatches) {
        final cardContent = match.group(1) ?? '';
        final questionMatch = RegExp(
          r'QUESTION:\s*(.*?)(?=ANSWER:|$)',
          dotAll: true,
        ).firstMatch(cardContent);
        final answerMatch = RegExp(
          r'ANSWER:\s*(.*?)$',
          dotAll: true,
        ).firstMatch(cardContent);

        if (questionMatch != null && answerMatch != null) {
          flashCards.add({
            'question': questionMatch.group(1)?.trim() ?? '',
            'answer': answerMatch.group(1)?.trim() ?? '',
          });
        }
      }

      // If parsing failed, create some default cards
      if (flashCards.isEmpty) {
        flashCards = [
          {
            'question': 'What is the main topic of this document?',
            'answer':
                'This document covers important information that has been processed for ADHD learning.',
          },
        ];
      }

      return flashCards;
    } catch (e) {
      print('Flash cards generation error: $e');
      return [
        {
          'question': 'Flash cards generation error',
          'answer': 'Unable to generate flash cards. Please try again later.',
        },
      ];
    }
  }

  // Format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  // Delete document
  Future<void> _deleteDocument(int index) async {
    final document = uploadedDocuments[index];
    final documentPath = document['path'] ?? '';

    setState(() {
      uploadedDocuments.removeAt(index);
    });
    await _saveUploadedDocuments();

    // Also delete from Firebase
    if (documentPath.isNotEmpty) {
      await UserActivityService.deleteDocument(documentPath);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Get icon for file type
  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Get color for file type
  Color _getFileColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'docx':
        return Colors.blue;
      case 'txt':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusTimerService>(
      builder: (context, timerService, child) {
        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B2D93), Color(0xFF5D1A73)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ADHD Support',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Resources and tools for ADHD students',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Progress Tracking
                const Text(
                  'Your Progress',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildProgressCard(),
                const SizedBox(height: 24),

                // Quick Tools Section
                const Text(
                  'Quick Tools',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildToolCard(
                        icon: timerService.isActive ? Icons.timer : Icons.timer,
                        title: timerService.isActive
                            ? 'Focus Timer (${timerService.formatTime(timerService.stopWatchTimer.rawTime.value)})'
                            : 'Focus Timer',
                        subtitle: timerService.isRunning
                            ? 'Running...'
                            : 'Pomodoro technique',
                        color: timerService.isActive
                            ? Colors.green
                            : Colors.blue,
                        onTap: () => _showFocusTimer(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Document Upload Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Documents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _uploadDocument,
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B2D93),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Uploaded Documents List
                if (uploadedDocuments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No documents uploaded yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload PDF, DOCX, or TXT files to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: uploadedDocuments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final document = entry.value;
                      return _buildDocumentCard(document, index);
                    }).toList(),
                  ),
                const SizedBox(height: 24),

                // Tips and Strategies Section
                const Text(
                  'Tips & Strategies',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildTipCard(
                  title: 'Study Environment',
                  tip:
                      'Create a quiet, organized space with minimal distractions. Use noise-cancelling headphones if needed.',
                  icon: Icons.desk,
                ),
                const SizedBox(height: 12),
                _buildTipCard(
                  title: 'Time Management',
                  tip:
                      'Use timers and break tasks into smaller, manageable chunks. The Pomodoro Technique works well.',
                  icon: Icons.access_time,
                ),
                const SizedBox(height: 12),
                _buildTipCard(
                  title: 'Note Taking',
                  tip:
                      'Use visual aids, mind maps, and color coding to make information more engaging and memorable.',
                  icon: Icons.note_alt,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required String title,
    required String tip,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF7B2D93), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    if (_isLoadingStats) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B2D93)),
          ),
        ),
      );
    }

    final focusSessions = _userStats['focusSessions'] ?? 0;
    final studyTimeMinutes = _userStats['studyTimeMinutes'] ?? 0;
    final documentsProcessed = _userStats['documentsProcessed'] ?? 0;
    final points = _userStats['points'] ?? 0;

    // Format study time
    final studyTimeFormatted = UserActivityService.formatStudyTime(
      studyTimeMinutes,
    );

    // Calculate progress towards a weekly goal (e.g., 10 sessions)
    final weeklyGoal = 10;
    final progress = (focusSessions / weeklyGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2D93).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, size: 16, color: Color(0xFF7B2D93)),
                    const SizedBox(width: 4),
                    Text(
                      '$points pts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B2D93),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStat('Sessions', '$focusSessions', Colors.green),
              _buildProgressStat('Study Time', studyTimeFormatted, Colors.blue),
              _buildProgressStat(
                'Documents',
                '$documentsProcessed',
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B2D93)),
          ),
          const SizedBox(height: 8),
          Text(
            focusSessions >= weeklyGoal
                ? '🎉 Weekly goal achieved!'
                : '${(progress * 100).toInt()}% of weekly goal ($focusSessions/$weeklyGoal sessions)',
            style: TextStyle(
              color: focusSessions >= weeklyGoal
                  ? Colors.green
                  : Colors.grey[600],
              fontSize: 12,
              fontWeight: focusSessions >= weeklyGoal
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  void _showFocusTimer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FocusTimerScreen()),
    );
  }

  void _showTaskPlanner(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Planner'),
        content: const Text(
          'Task planner feature coming soon! This will help you break down complex tasks into manageable steps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMindfulness(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mindfulness'),
        content: const Text(
          'Mindfulness exercises coming soon! This will include breathing exercises and meditation guides.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFocusSounds(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Focus Sounds'),
        content: const Text(
          'Focus sounds feature coming soon! This will provide background sounds to help with concentration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, String> document, int index) {
    final fileName = document['name'] ?? '';
    final fileExtension = document['extension'] ?? '';
    final fileSize = document['size'] ?? '';
    final uploadDate = document['uploadDate'] ?? '';
    final aiSummary = document['aiSummary'] ?? '';
    final aiInsights = document['aiInsights'] ?? '';

    // Parse and format upload date
    String formattedDate = '';
    try {
      final date = DateTime.parse(uploadDate);
      formattedDate = '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      formattedDate = 'Unknown date';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File Header
          Row(
            children: [
              // File Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getFileColor(fileExtension).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(fileExtension),
                  color: _getFileColor(fileExtension),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // File Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          fileSize,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(context, index, fileName);
                  } else if (value == 'view_ai') {
                    _showAIAnalysis(context, fileName, aiSummary, aiInsights);
                  }
                },
                itemBuilder: (context) => [
                  if (aiSummary.isNotEmpty)
                    const PopupMenuItem(
                      value: 'view_ai',
                      child: Row(
                        children: [
                          Icon(Icons.psychology, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('View AI Analysis'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert, color: Colors.grey),
              ),
            ],
          ),

          // AI Summary Section
          if (aiSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI Summary',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    aiSummary.length > 150
                        ? '${aiSummary.substring(0, 150)}...'
                        : aiSummary,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  if (aiSummary.length > 150 || aiInsights.isNotEmpty)
                    TextButton(
                      onPressed: () => _showAIAnalysis(
                        context,
                        fileName,
                        aiSummary,
                        aiInsights,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View Full Analysis',
                        style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Action Buttons for Summary and Flash Cards
          if (aiSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generateAndShowSummary(context, document),
                    icon: const Icon(Icons.summarize, size: 16),
                    label: const Text(
                      'Summary',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[700],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.blue[200]!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _generateAndShowFlashCards(context, document),
                    icon: const Icon(Icons.quiz, size: 16),
                    label: const Text(
                      'Flash Cards',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[50],
                      foregroundColor: Colors.green[700],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.green[200]!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    int index,
    String fileName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument(index);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAIAnalysis(
    BuildContext context,
    String fileName,
    String summary,
    String insights,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2D93), Color(0xFF5D1A73)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Analysis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            fileName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Section
                      if (summary.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.summarize,
                                    size: 20,
                                    color: Colors.blue[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Summary',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                summary,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Insights Section
                      if (insights.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb,
                                    size: 20,
                                    color: Colors.green[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ADHD Study Insights',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                insights,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Generate and show ADHD-focused summary
  Future<void> _generateAndShowSummary(
    BuildContext context,
    Map<String, String> document,
  ) async {
    print('🔍 === _generateAndShowSummary START ===');
    final fileName = document['name'] ?? '';
    final filePath = document['path'] ?? '';
    print('🔍 fileName: $fileName');
    print('🔍 filePath: $filePath');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating ADHD summary...'),
          ],
        ),
      ),
    );
    print('🔍 Loading dialog shown');

    try {
      // Read file content
      print('🔍 Reading file...');
      final file = File(filePath);
      final content = await _extractFileContent(
        file,
        document['extension'] ?? '',
      );
      print('🔍 File content extracted, length: ${content.length}');

      // Generate summary
      print('🔍 Generating summary...');
      final summary = await _generateADHDSummary(content, fileName);
      print('🔍 Summary generated, length: ${summary.length}');
      print(
        '🔍 Summary preview: ${summary.substring(0, summary.length > 100 ? 100 : summary.length)}',
      );

      // Close loading dialog
      print('🔍 Closing loading dialog, mounted: $mounted');
      if (mounted) {
        Navigator.pop(context);
        print('🔍 Loading dialog closed');
      }

      // Track summary view
      print('🔍 Tracking summary view...');
      await UserActivityService.trackSummaryView(filePath, fileName);
      print('🔍 Summary view tracked');

      // Show summary
      print('🔍 About to call _showADHDSummary...');
      print('🔍 Context valid: ${context != null}');
      print('🔍 fileName: $fileName');
      print('🔍 summary length: ${summary.length}');
      _showADHDSummary(context, fileName, summary);
      print('🔍 _showADHDSummary call completed');
      print('🔍 === _generateAndShowSummary END ===');
    } catch (e, stackTrace) {
      print('🔍 === ERROR in _generateAndShowSummary ===');
      print('🔍 Error: $e');
      print('🔍 StackTrace: $stackTrace');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating summary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Generate and show flash cards
  Future<void> _generateAndShowFlashCards(
    BuildContext context,
    Map<String, String> document,
  ) async {
    final fileName = document['name'] ?? '';
    final filePath = document['path'] ?? '';

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Creating flash cards...'),
          ],
        ),
      ),
    );

    try {
      // Read file content
      final file = File(filePath);
      final content = await _extractFileContent(
        file,
        document['extension'] ?? '',
      );

      // Generate flash cards
      final flashCards = await _generateFlashCards(content, fileName);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show flash cards
      _showFlashCards(context, fileName, filePath, flashCards);
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating flash cards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show ADHD-focused summary in full page
  void _showADHDSummary(BuildContext context, String fileName, String summary) {
    print('🔍 _showADHDSummary called');
    print('🔍 Context: $context');
    print('🔍 fileName: $fileName');
    print(
      '🔍 summary: ${summary.substring(0, summary.length > 50 ? 50 : summary.length)}...',
    );

    Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              print('🔍 Building MaterialPageRoute for ADHDSummaryScreen');
              return ADHDSummaryScreen(fileName: fileName, summary: summary);
            },
          ),
        )
        .then((value) {
          print('🔍 Returned from ADHDSummaryScreen');
        })
        .catchError((error) {
          print('🔍 ERROR navigating to ADHDSummaryScreen: $error');
        });
  }

  // Show flash cards
  void _showFlashCards(
    BuildContext context,
    String fileName,
    String documentId,
    List<Map<String, String>> flashCards,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashCardsScreen(
          fileName: fileName,
          documentId: documentId,
          flashCards: flashCards,
        ),
      ),
    );
  }
}

// Focus Timer Screen
class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _flashController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _flashAnimation;
  late FocusTimerService _timerService;

  // Predefined time options - added 5 seconds for testing
  final List<dynamic> _timeOptions = [
    {'label': '5 sec', 'seconds': 5}, // For testing
    {'label': '5 min', 'minutes': 5},
    {'label': '15 min', 'minutes': 15},
    {'label': '25 min', 'minutes': 25},
    {'label': '30 min', 'minutes': 30},
    {'label': '45 min', 'minutes': 45},
    {'label': '60 min', 'minutes': 60},
  ];

  @override
  void initState() {
    super.initState();
    _timerService = FocusTimerService();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Pulse animation for timer circle
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Flash animation for completion
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _flashAnimation =
        ColorTween(
          begin: Colors.transparent,
          end: const Color(0xFF7B2D93).withOpacity(0.3),
        ).animate(
          CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
        );

    _pulseController.repeat(reverse: true);

    // Listen for timer completion to trigger flash
    _timerService.addListener(_onTimerUpdate);
  }

  void _onTimerUpdate() {
    if (_timerService.isCompleted && _timerService.shouldShowCompletionDialog) {
      _triggerScreenFlash();
      // Don't show local dialog if we're in the timer screen - let global handler manage it
      // The global handler will show the dialog on any screen
    }
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTimerUpdate);
    _pulseController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  void _triggerScreenFlash() {
    _flashController.reset();
    _flashController.forward().then((_) {
      _flashController.reverse();
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2D93).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF7B2D93),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Focus Session Complete!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5D1A73),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great job! You completed a ${_getSelectedTimeLabel()}-minute focus session.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Take a short break before starting your next session.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _timerService.resetTimer();
              _timerService.clearCompletionDialog();
            },
            child: const Text(
              'Start New Session',
              style: TextStyle(color: Color(0xFF7B2D93)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _timerService.clearCompletionDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2D93),
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _getSelectedTimeLabel() {
    final selected = _timeOptions.firstWhere(
      (option) =>
          (option['minutes'] ?? (option['seconds'] ?? 0) ~/ 60) ==
          _timerService.selectedMinutes,
      orElse: () => {'label': '${_timerService.selectedMinutes} min'},
    );
    return selected['label'] ?? '${_timerService.selectedMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusTimerService>(
      builder: (context, timerService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Focus Timer'),
            backgroundColor: const Color(0xFF7B2D93),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF7B2D93).withOpacity(0.1),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.3],
                  ),
                ),
                child: Container(
                  color: _flashAnimation.value,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Time Selection (only show when not running)
                            if (!timerService.isRunning) ...[
                              const Text(
                                'Select Focus Time',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D1A73),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: _timeOptions.map((option) {
                                  final minutes = option['minutes'];
                                  final seconds = option['seconds'];
                                  final label = option['label'];

                                  // Check if this option is currently selected
                                  bool isSelected = false;
                                  if (seconds != null) {
                                    // For second-based options, compare preset milliseconds
                                    isSelected =
                                        timerService.presetMilliseconds ==
                                        seconds * 1000;
                                  } else if (minutes != null) {
                                    // For minute-based options, compare selected minutes
                                    isSelected =
                                        timerService.selectedMinutes == minutes;
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      if (seconds != null) {
                                        // Handle seconds (for testing)
                                        timerService.setDurationInSeconds(
                                          seconds,
                                        );
                                      } else if (minutes != null) {
                                        timerService.setDuration(minutes);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF7B2D93)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF7B2D93),
                                          width: 2,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF7B2D93,
                                                  ).withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF7B2D93),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Timer Display
                            SizedBox(
                              height: 320, // Fixed height for timer section
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Progress Circle
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: timerService.isRunning
                                              ? _pulseAnimation.value
                                              : 1.0,
                                          child: Container(
                                            width: 300,
                                            height: 300,
                                            child: Stack(
                                              children: [
                                                // Background circle
                                                Container(
                                                  width: 300,
                                                  height: 300,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.grey
                                                            .withOpacity(0.2),
                                                        blurRadius: 20,
                                                        offset: const Offset(
                                                          0,
                                                          10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Progress indicator
                                                Center(
                                                  child: SizedBox(
                                                    width: 280,
                                                    height: 280,
                                                    child: CircularProgressIndicator(
                                                      value:
                                                          timerService
                                                                  .presetMilliseconds >
                                                              0
                                                          ? (timerService
                                                                        .presetMilliseconds -
                                                                    timerService
                                                                        .stopWatchTimer
                                                                        .rawTime
                                                                        .value) /
                                                                timerService
                                                                    .presetMilliseconds
                                                          : 0.0,
                                                      strokeWidth: 8,
                                                      backgroundColor:
                                                          Colors.grey[200],
                                                      valueColor:
                                                          const AlwaysStoppedAnimation<
                                                            Color
                                                          >(Color(0xFF7B2D93)),
                                                    ),
                                                  ),
                                                ),

                                                // Time display
                                                Center(
                                                  child: StreamBuilder<int>(
                                                    stream: timerService
                                                        .stopWatchTimer
                                                        .rawTime,
                                                    initialData: timerService
                                                        .stopWatchTimer
                                                        .rawTime
                                                        .value,
                                                    builder: (context, snapshot) {
                                                      final value =
                                                          snapshot.data ?? 0;
                                                      final displayTime =
                                                          StopWatchTimer.getDisplayTime(
                                                            value,
                                                            hours: false,
                                                            milliSecond: false,
                                                          );
                                                      return Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            displayTime,
                                                            style: TextStyle(
                                                              fontSize: 40,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: value == 0
                                                                  ? const Color(
                                                                      0xFF7B2D93,
                                                                    )
                                                                  : const Color(
                                                                      0xFF5D1A73,
                                                                    ),
                                                              fontFamily:
                                                                  'monospace',
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Text(
                                                            _getTimerStatusText(
                                                              timerService,
                                                            ),
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Control Buttons
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Reset Button
                                ElevatedButton.icon(
                                  onPressed: () => timerService.resetTimer(),
                                  icon: const Icon(Icons.refresh, size: 20),
                                  label: const Text('Reset'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[100],
                                    foregroundColor: Colors.grey[700],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 0,
                                  ),
                                ),

                                // Main Action Button (Start/Pause)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (timerService.isRunning) {
                                      timerService.pauseTimer();
                                    } else {
                                      timerService.startTimer();
                                    }
                                  },
                                  icon: Icon(
                                    timerService.isRunning
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 24,
                                  ),
                                  label: Text(
                                    timerService.isRunning ? 'Pause' : 'Start',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7B2D93),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    elevation: 4,
                                    shadowColor: const Color(
                                      0xFF7B2D93,
                                    ).withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Tips for ADHD users
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb,
                                        color: Colors.blue[600],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'ADHD Focus Tips',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '• Start with shorter sessions (15-25 min)\n'
                                    '• Remove distractions from your workspace\n'
                                    '• Take breaks between sessions\n'
                                    '• Celebrate small wins!\n'
                                    '• Timer continues running in background',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getTimerStatusText(FocusTimerService timerService) {
    if (timerService.isRunning) {
      return 'Stay focused...';
    } else if (timerService.stopWatchTimer.rawTime.value > 0 &&
        timerService.stopWatchTimer.rawTime.value <
            timerService.presetMilliseconds) {
      return 'Paused - Tap start to continue';
    } else if (timerService.isCompleted) {
      return 'Session completed!';
    } else {
      return 'Ready to start your focus session';
    }
  }
}

// ADHD Summary Screen - Full page view
class ADHDSummaryScreen extends StatelessWidget {
  final String fileName;
  final String summary;

  const ADHDSummaryScreen({
    super.key,
    required this.fileName,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    print('🔍 ADHDSummaryScreen building...');
    print('🔍 fileName: $fileName');
    print('🔍 summary length: ${summary.length}');
    print(
      '🔍 summary preview: ${summary.substring(0, summary.length > 200 ? 200 : summary.length)}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADHD Summary'),
        backgroundColor: const Color(0xFF7B2D93),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF7B2D93).withOpacity(0.1), Colors.white],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Document info header
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2D93).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.summarize,
                        color: Color(0xFF7B2D93),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ADHD-Optimized Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5D1A73),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Summary content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: _buildMarkdownFormattedText(summary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build properly formatted markdown text
  Widget _buildMarkdownFormattedText(String markdownText) {
    print('🔍 Building markdown text, length: ${markdownText.length}');
    print(
      '🔍 First 100 chars: ${markdownText.substring(0, markdownText.length > 100 ? 100 : markdownText.length)}',
    );

    List<Widget> widgets = [];
    final lines = markdownText.split('\n');
    print('🔍 Total lines: ${lines.length}');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Handle headers
      if (line.startsWith('### ')) {
        widgets.add(_buildHeader(line.substring(4), 18, FontWeight.w600));
      } else if (line.startsWith('## ')) {
        widgets.add(_buildHeader(line.substring(3), 20, FontWeight.bold));
      } else if (line.startsWith('# ')) {
        widgets.add(_buildHeader(line.substring(2), 22, FontWeight.bold));
      }
      // Handle bullet points
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(_buildBulletPoint(line.substring(2)));
      }
      // Handle numbered lists
      else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        widgets.add(_buildNumberedPoint(line));
      }
      // Handle regular text with inline formatting
      else {
        widgets.add(_buildFormattedParagraph(line));
      }
    }

    print('🔍 Total widgets created: ${widgets.length}');
    if (widgets.isNotEmpty) {
      print('🔍 First widget type: ${widgets.first.runtimeType}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildHeader(String text, double fontSize, FontWeight fontWeight) {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: const Color(0xFF5D1A73),
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF7B2D93),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: _buildInlineFormattedText(text)),
        ],
      ),
    );
  }

  Widget _buildNumberedPoint(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: _buildInlineFormattedText(text),
    );
  }

  Widget _buildFormattedParagraph(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildInlineFormattedText(text),
    );
  }

  Widget _buildInlineFormattedText(String text) {
    List<TextSpan> spans = [];

    // Handle bold italic (***text***)
    text = text.replaceAllMapped(
      RegExp(r'\*\*\*(.*?)\*\*\*'),
      (match) => '|||BOLDITALIC|||${match.group(1)}|||BOLDITALIC|||',
    );

    // Handle bold (**text**)
    text = text.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (match) => '|||BOLD|||${match.group(1)}|||BOLD|||',
    );

    // Handle italic (*text*)
    text = text.replaceAllMapped(
      RegExp(r'\*(.*?)\*'),
      (match) => '|||ITALIC|||${match.group(1)}|||ITALIC|||',
    );

    // Split by markers and create spans
    final parts = text.split(RegExp(r'\|\|\|(?:BOLD|ITALIC|BOLDITALIC)\|\|\|'));
    final markers = RegExp(
      r'\|\|\|(BOLD|ITALIC|BOLDITALIC)\|\|\|',
    ).allMatches(text).toList();

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        TextStyle style = TextStyle(
          fontSize: 15,
          color: Colors.grey[800],
          height: 1.6,
        );

        // Check if this part should be formatted
        if (i > 0 && i - 1 < markers.length) {
          final marker = markers[i - 1].group(1);
          switch (marker) {
            case 'BOLDITALIC':
              style = TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF7B2D93),
                height: 1.6,
              );
              break;
            case 'BOLD':
              style = TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D1A73),
                height: 1.6,
              );
              break;
            case 'ITALIC':
              style = TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Colors.blue[700],
                height: 1.6,
              );
              break;
          }
        }

        spans.add(TextSpan(text: parts[i], style: style));
      }
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          height: 1.6,
        ),
      ),
      textAlign: TextAlign.left,
    );
  }
}

// Flash Cards Screen
class FlashCardsScreen extends StatefulWidget {
  final String fileName;
  final String documentId;
  final List<Map<String, String>> flashCards;

  const FlashCardsScreen({
    super.key,
    required this.fileName,
    required this.documentId,
    required this.flashCards,
  });

  @override
  State<FlashCardsScreen> createState() => _FlashCardsScreenState();
}

class _FlashCardsScreenState extends State<FlashCardsScreen> {
  int currentCardIndex = 0;
  bool isFlipped = false;
  Set<int> viewedCards = {0}; // Track viewed cards

  @override
  void dispose() {
    // Track progress when leaving
    _trackProgress();
    super.dispose();
  }

  Future<void> _trackProgress() async {
    await UserActivityService.trackFlashcardProgress(
      widget.documentId,
      widget.fileName,
      viewedCards.length,
      widget.flashCards.length,
    );
  }

  void _nextCard() {
    if (currentCardIndex < widget.flashCards.length - 1) {
      setState(() {
        currentCardIndex++;
        viewedCards.add(currentCardIndex);
        isFlipped = false;
      });
    }
  }

  void _previousCard() {
    if (currentCardIndex > 0) {
      setState(() {
        currentCardIndex--;
        viewedCards.add(currentCardIndex);
        isFlipped = false;
      });
    }
  }

  void _flipCard() {
    setState(() {
      isFlipped = !isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Flash Cards'),
          backgroundColor: const Color(0xFF7B2D93),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('No flash cards available')),
      );
    }

    final currentCard = widget.flashCards[currentCardIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Flash Cards - ${widget.fileName}'),
        backgroundColor: const Color(0xFF7B2D93),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7B2D93), Color(0xFF5D1A73)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Card counter
                Text(
                  'Card ${currentCardIndex + 1} of ${widget.flashCards.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Flash card
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(isFlipped ? 'answer' : 'question'),
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 400),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Card type indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isFlipped
                                      ? Colors.green[50]
                                      : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isFlipped ? 'ANSWER' : 'QUESTION',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isFlipped
                                        ? Colors.green[700]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Card content
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Text(
                                    isFlipped
                                        ? (currentCard['answer'] ??
                                              'No answer available')
                                        : (currentCard['question'] ??
                                              'No question available'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Tap to flip hint
                              if (!isFlipped)
                                Text(
                                  'Tap to reveal answer',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: currentCardIndex > 0 ? _previousCard : null,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7B2D93),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),

                    // Flip button
                    ElevatedButton.icon(
                      onPressed: _flipCard,
                      icon: Icon(
                        isFlipped ? Icons.quiz : Icons.help_outline,
                        size: 18,
                      ),
                      label: Text(isFlipped ? 'Show Question' : 'Show Answer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7B2D93),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: currentCardIndex < widget.flashCards.length - 1
                          ? _nextCard
                          : null,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7B2D93),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
