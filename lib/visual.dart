import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:io';
import 'user_activity_service.dart';

class VisualPage extends StatefulWidget {
  const VisualPage({super.key});

  @override
  State<VisualPage> createState() => _VisualPageState();
}

class _VisualPageState extends State<VisualPage> {
  List<Map<String, String>> uploadedDocuments = [];
  bool _isLoading = false;
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _boldText = false;

  // TTS related variables
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  double _speechRate = 0.5;
  double _speechVolume = 0.8;
  double _speechPitch = 1.0;

  // Gemini API configuration
  static const String _geminiApiKey = 'AIzaSyDXCrnGQgAF__FotBEfYythr8-MgJAKuOY';
  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    _initializeTts();
    _loadUploadedDocuments();
    _loadAccessibilitySettings();
  }

  void _initializeGemini() {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
  }

  Future<void> _initializeTts() async {
    _flutterTts = FlutterTts();

    try {
      // Check if TTS is available
      dynamic languages = await _flutterTts.getLanguages;
      if (languages != null) {
        print("Available TTS languages: $languages");
      }

      // Wait a bit for TTS engine to initialize
      await Future.delayed(Duration(milliseconds: 500));

      // Set up TTS configuration with error handling
      var result = await _flutterTts.setLanguage("en-US");
      print("Language set result: $result");

      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_speechVolume);
      await _flutterTts.setPitch(_speechPitch);

      // Set up TTS handlers
      _flutterTts.setStartHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = true;
          });
        }
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
        print("TTS Error: $msg");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Speech error: Please check your device's text-to-speech settings",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      print("TTS initialized successfully");
    } catch (e) {
      print("TTS Initialization Error: $e");
    }
  }

  // TTS control methods
  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      try {
        // Track TTS usage
        await UserActivityService.trackVisualAidUsage('text_to_speech');

        // Check if TTS is ready before speaking
        var isReady = await _flutterTts.awaitSpeakCompletion(false);
        print("TTS ready status: $isReady");

        // Stop any current speech
        await _flutterTts.stop();

        // Wait a moment for the engine to be ready
        await Future.delayed(Duration(milliseconds: 100));

        var result = await _flutterTts.speak(text);
        print("TTS speak result: $result");
      } catch (e) {
        print("TTS Speak Error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Cannot speak text: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _pauseSpeaking() async {
    await _flutterTts.pause();
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _loadAccessibilitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontScale = prefs.getDouble('visual_font_scale') ?? 1.0;
      _highContrast = prefs.getBool('visual_high_contrast') ?? false;
      _boldText = prefs.getBool('visual_bold_text') ?? false;
      _speechRate = prefs.getDouble('visual_speech_rate') ?? 0.5;
      _speechVolume = prefs.getDouble('visual_speech_volume') ?? 0.8;
      _speechPitch = prefs.getDouble('visual_speech_pitch') ?? 1.0;
    });

    // Update TTS settings
    if (_flutterTts != null) {
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_speechVolume);
      await _flutterTts.setPitch(_speechPitch);
    }
  }

  Future<void> _saveAccessibilitySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('visual_font_scale', _fontScale);
    await prefs.setBool('visual_high_contrast', _highContrast);
    await prefs.setBool('visual_bold_text', _boldText);
    await prefs.setDouble('visual_speech_rate', _speechRate);
    await prefs.setDouble('visual_speech_volume', _speechVolume);
    await prefs.setDouble('visual_speech_pitch', _speechPitch);

    // Update TTS settings immediately
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(_speechVolume);
    await _flutterTts.setPitch(_speechPitch);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  // Load uploaded documents from local storage
  Future<void> _loadUploadedDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsJson = prefs.getString('visual_uploaded_documents');
    if (documentsJson != null) {
      final List<dynamic> documentsList = json.decode(documentsJson);
      setState(() {
        uploadedDocuments = documentsList
            .map((doc) => Map<String, String>.from(doc))
            .toList();
      });
    }
  }

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

  // Save uploaded documents to local storage
  Future<String> _generateSummary(String documentPath) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final file = File(documentPath);
      final fileName = documentPath.split('/').last;
      final extension = fileName.contains('.') ? fileName.split('.').last : '';

      // Extract content from the file
      String content = await _extractFileContent(file, extension);

      if (content.isEmpty ||
          content.startsWith('Error') ||
          content.startsWith('Unable')) {
        // If extraction failed, provide feedback to user
        throw Exception(content);
      }

      final prompt =
          '''
Create a comprehensive summary specifically designed for visually impaired learners from this document.

Requirements for visual accessibility:
1. Use clear, descriptive language that works well with screen readers
2. Structure information hierarchically with clear headings
3. Include detailed descriptions of any visual elements
4. Use consistent formatting for better text-to-speech conversion
5. Emphasize key concepts using text markers like "IMPORTANT:" and "KEY POINT:"
6. Break down complex information into logical segments
7. Use descriptive language for spatial relationships and visual layouts

Make the summary rich in descriptive detail to compensate for visual limitations.

Document: $fileName
Content: $content

Format as a well-structured, accessible summary with clear sections and detailed descriptions.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final result =
          response.text ?? 'Unable to generate summary at this time.';

      return result;
    } catch (e) {
      throw Exception('Failed to generate summary: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _generateFlashcards(String documentPath) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final file = File(documentPath);
      final fileName = documentPath.split('/').last;
      final extension = fileName.contains('.') ? fileName.split('.').last : '';

      // Extract content from the file
      String content = await _extractFileContent(file, extension);

      if (content.isEmpty ||
          content.startsWith('Error') ||
          content.startsWith('Unable')) {
        // If extraction failed, provide feedback to user
        throw Exception(content);
      }

      print('Generating flashcards for: $fileName');
      print('Content length: ${content.length}');

      final prompt =
          '''
Create flashcards specifically designed for visually impaired learners from this document.

Requirements for visually accessible flashcards:
1. Use clear, descriptive language for both questions and answers
2. Avoid references to visual elements unless described in detail
3. Keep questions concise but descriptive (2-3 sentences max)
4. Make answers comprehensive and self-contained
5. Focus on conceptual understanding rather than visual recognition
6. Use consistent formatting for screen reader compatibility
7. Create 5-7 cards maximum for focused learning
8. Include descriptive context where needed

Document: $fileName
Content: $content

Format each card as:
CARD_START
QUESTION: [Clear, descriptive question suitable for audio consumption]
ANSWER: [Comprehensive, detailed answer with full context]
CARD_END

Create cards that reinforce understanding through detailed audio-friendly descriptions.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text ?? '';

      // Parse flashcards
      List<String> flashcards = [];
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
          final question = questionMatch.group(1)?.trim() ?? '';
          final answer = answerMatch.group(1)?.trim() ?? '';
          flashcards.add('Q: $question\nA: $answer');
        }
      }

      // If parsing failed, create default accessible flashcards
      if (flashcards.isEmpty) {
        flashcards = [
          "Q: What is visual accessibility in learning?\nA: Visual accessibility refers to designing educational content and interfaces that can be easily perceived and understood by people with visual impairments, including features like screen reader compatibility, high contrast themes, and descriptive text.",
          "Q: How do high contrast themes help visually impaired users?\nA: High contrast themes use stark color differences between text and background elements to improve readability for users with visual difficulties, making content easier to distinguish and read.",
          "Q: What role does font scaling play in accessibility?\nA: Font scaling allows users to increase text size according to their visual needs, making content more readable and reducing eye strain for people with various visual impairments.",
          "Q: Why is screen reader compatibility important?\nA: Screen reader compatibility ensures that assistive technologies can properly interpret and vocalize interface elements, providing audio access to visual content for blind and visually impaired users.",
          "Q: What are the benefits of descriptive language in accessible content?\nA: Descriptive language provides detailed context and visual information through text, helping visually impaired users understand spatial relationships, layout, and visual elements they cannot see directly.",
        ];
      }

      return flashcards;
    } catch (e) {
      throw Exception('Failed to generate flashcards: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUploadedDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsJson = json.encode(uploadedDocuments);
    await prefs.setString('visual_uploaded_documents', documentsJson);
  }

  void _showSummary(String documentPath, String documentName) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _highContrast ? Colors.grey[900] : null,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: _highContrast ? Colors.white : const Color(0xFF7B2D93),
            ),
            SizedBox(width: 16 * _fontScale),
            Text(
              'Generating summary...',
              style: TextStyle(
                fontSize: 16 * _fontScale,
                fontWeight: _boldText ? FontWeight.w500 : FontWeight.normal,
                color: _highContrast ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final summary = await _generateSummary(documentPath);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Track summary view
      await UserActivityService.trackSummaryView(documentPath, documentName);
      await UserActivityService.trackVisualAidUsage('summary_view');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisualSummaryScreen(
              fileName: documentName,
              summary: summary,
              fontScale: _fontScale,
              highContrast: _highContrast,
              boldText: _boldText,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error generating summary: $e',
              style: TextStyle(
                fontSize: 16 * _fontScale,
                fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFlashcards(String documentPath, String documentName) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _highContrast ? Colors.grey[900] : null,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: _highContrast ? Colors.white : const Color(0xFF7B2D93),
            ),
            SizedBox(width: 16 * _fontScale),
            Text(
              'Generating flashcards...',
              style: TextStyle(
                fontSize: 16 * _fontScale,
                fontWeight: _boldText ? FontWeight.w500 : FontWeight.normal,
                color: _highContrast ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final flashcards = await _generateFlashcards(documentPath);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisualFlashCardsScreen(
              fileName: documentName,
              flashCards: flashcards,
              fontScale: _fontScale,
              highContrast: _highContrast,
              boldText: _boldText,
              flutterTts: _flutterTts,
              isSpeaking: _isSpeaking,
              onSpeakingChanged: (speaking) =>
                  setState(() => _isSpeaking = speaking),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error generating flashcards: $e',
              style: TextStyle(
                fontSize: 16 * _fontScale,
                fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAccessibilitySettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _highContrast ? Colors.black : null,
              title: Text(
                'Accessibility Settings',
                style: TextStyle(
                  fontSize: 20 * _fontScale,
                  fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
                  color: _highContrast ? Colors.white : null,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Font Size Control
                    Text(
                      'Font Size: ${(_fontScale * 100).round()}%',
                      style: TextStyle(
                        fontSize: 16 * _fontScale,
                        fontWeight: _boldText
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: _highContrast ? Colors.white : null,
                      ),
                    ),
                    Slider(
                      value: _fontScale,
                      min: 0.8,
                      max: 2.0,
                      divisions: 12,
                      onChanged: (value) {
                        setDialogState(() {
                          _fontScale = value;
                        });
                        setState(() {
                          _fontScale = value;
                        });
                        _saveAccessibilitySettings();
                      },
                    ),
                    const SizedBox(height: 20),

                    // High Contrast Toggle
                    SwitchListTile(
                      title: Text(
                        'High Contrast',
                        style: TextStyle(
                          fontSize: 16 * _fontScale,
                          fontWeight: _boldText
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: _highContrast ? Colors.white : null,
                        ),
                      ),
                      value: _highContrast,
                      onChanged: (value) {
                        setDialogState(() {
                          _highContrast = value;
                        });
                        setState(() {
                          _highContrast = value;
                        });
                        _saveAccessibilitySettings();
                      },
                    ),

                    // Bold Text Toggle
                    SwitchListTile(
                      title: Text(
                        'Bold Text',
                        style: TextStyle(
                          fontSize: 16 * _fontScale,
                          fontWeight: _boldText
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: _highContrast ? Colors.white : null,
                        ),
                      ),
                      value: _boldText,
                      onChanged: (value) {
                        setDialogState(() {
                          _boldText = value;
                        });
                        setState(() {
                          _boldText = value;
                        });
                        _saveAccessibilitySettings();
                      },
                    ),

                    const SizedBox(height: 20),
                    Divider(color: _highContrast ? Colors.grey[600] : null),
                    const SizedBox(height: 10),

                    // Text-to-Speech Settings
                    Text(
                      'Text-to-Speech Settings',
                      style: TextStyle(
                        fontSize: 18 * _fontScale,
                        fontWeight: _boldText
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: _highContrast ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Speech Rate
                    Text(
                      'Speech Rate: ${(_speechRate * 100).round()}%',
                      style: TextStyle(
                        fontSize: 16 * _fontScale,
                        fontWeight: _boldText
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: _highContrast ? Colors.white : null,
                      ),
                    ),
                    Slider(
                      value: _speechRate,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: (value) {
                        setDialogState(() {
                          _speechRate = value;
                        });
                        setState(() {
                          _speechRate = value;
                        });
                        _saveAccessibilitySettings();
                      },
                    ),
                    const SizedBox(height: 10),

                    // Speech Volume
                    Text(
                      'Speech Volume: ${(_speechVolume * 100).round()}%',
                      style: TextStyle(
                        fontSize: 16 * _fontScale,
                        fontWeight: _boldText
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: _highContrast ? Colors.white : null,
                      ),
                    ),
                    Slider(
                      value: _speechVolume,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: (value) {
                        setDialogState(() {
                          _speechVolume = value;
                        });
                        setState(() {
                          _speechVolume = value;
                        });
                        _saveAccessibilitySettings();
                      },
                    ),
                    const SizedBox(height: 10),

                    // Speech Pitch
                    Text(
                      'Speech Pitch: ${(_speechPitch * 100).round()}%',
                      style: TextStyle(
                        fontSize: 16 * _fontScale,
                        fontWeight: _boldText
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: _highContrast ? Colors.white : null,
                      ),
                    ),
                    Slider(
                      value: _speechPitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      onChanged: (value) {
                        setDialogState(() {
                          _speechPitch = value;
                        });
                        setState(() {
                          _speechPitch = value;
                        });
                        _saveAccessibilitySettings();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Test TTS Button
                    ElevatedButton.icon(
                      onPressed: () {
                        _speak(
                          "This is a test of the text to speech functionality for visual learning accessibility.",
                        );
                      },
                      icon: Icon(
                        _isSpeaking ? Icons.stop : Icons.volume_up,
                        size: 20 * _fontScale,
                      ),
                      label: Text(
                        _isSpeaking ? 'Stop Test' : 'Test Speech',
                        style: TextStyle(
                          fontSize: 14 * _fontScale,
                          fontWeight: _boldText
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B2D93),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _stopSpeaking(); // Stop any ongoing speech
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16 * _fontScale,
                      fontWeight: _boldText
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _highContrast
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Upload document functionality
  Future<void> _pickAndUploadDocument() async {
    try {
      setState(() {
        _isLoading = true;
      });

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
        final supportedExtensions = ['pdf', 'doc', 'docx', 'txt'];

        if (unsupportedExtensions.contains(fileExtension.toLowerCase())) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error 400: Unsupported file type ".$fileExtension". Only PDF, DOC, DOCX, and TXT files are supported.',
                  style: TextStyle(
                    fontSize: 16 * _fontScale,
                    fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
                  ),
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
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error 400: Invalid file type ".$fileExtension". Only PDF, DOC, DOCX, and TXT files are supported.',
                  style: TextStyle(
                    fontSize: 16 * _fontScale,
                    fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // Store document information with all necessary metadata
        final documentInfo = {
          'name': fileName,
          'path': file.path,
          'extension': fileExtension,
          'size': fileSize.toString(),
          'uploadDate': DateTime.now().toIso8601String(),
          'type': _getDocumentType(fileExtension),
          'description':
              'Visual learning document uploaded on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        };

        setState(() {
          uploadedDocuments.add(documentInfo);
        });

        await _saveUploadedDocuments();

        // Track document upload for visual aid
        await UserActivityService.trackDocumentUpload(
          fileName,
          file.path,
          category: 'visual',
        );
        await UserActivityService.trackVisualAidUsage('document_upload');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Document "$fileName" uploaded successfully!',
                style: TextStyle(
                  fontSize: 16 * _fontScale,
                  fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              backgroundColor: _highContrast
                  ? Colors.grey[800]
                  : const Color(0xFF7B2D93),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error uploading document: $e',
              style: TextStyle(
                fontSize: 16 * _fontScale,
                fontWeight: _boldText ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  // Get document type based on extension
  String _getDocumentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'PDF Document';
      case 'docx':
        return 'Word Document';
      case 'txt':
        return 'Text File';
      case 'pptx':
        return 'PowerPoint';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Image';
      default:
        return 'Document';
    }
  }

  // Get icon for document type
  IconData _getDocumentIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
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
          content: Text('Document deleted successfully'),
          backgroundColor: Color(0xFF7B2D93),
        ),
      );
    }
  }

  // Show document details
  void _showDocumentDetails(Map<String, String> document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _getDocumentIcon(document['extension'] ?? ''),
              color: const Color(0xFF7B2D93),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                document['name'] ?? '',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', document['type'] ?? ''),
            _buildDetailRow('Size', document['size'] ?? ''),
            _buildDetailRow(
              'Uploaded',
              _formatDate(document['uploadDate'] ?? ''),
            ),
            const SizedBox(height: 16),
            Text(
              document['description'] ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processVisualContent(document);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2D93),
              foregroundColor: Colors.white,
            ),
            child: const Text('Process Visual'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Process visual content (placeholder for future AI integration)
  void _processVisualContent(Map<String, String> document) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Processing visual content for "${document['name']}"...'),
        backgroundColor: const Color(0xFF7B2D93),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Upload document functionality
  Future<void> _uploadDocument() async {
    await _pickAndUploadDocument();
  }

  // Build document card with ADHD.dart styling
  Widget _buildDocumentCard(Map<String, String> document, int index) {
    final fileName = document['name'] ?? '';
    final fileSize = document['size'] ?? '';
    final uploadDate = document['uploadDate'] ?? '';
    final filePath = document['path'] ?? '';
    final fileExtension = document['extension'] ?? '';

    // Parse and format upload date
    String formattedDate = '';
    try {
      final date = DateTime.parse(uploadDate);
      formattedDate = '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      formattedDate = 'Unknown date';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12 * _fontScale),
      padding: EdgeInsets.all(16 * _fontScale),
      decoration: BoxDecoration(
        color: _highContrast ? Colors.grey[900] : Colors.white,
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
                padding: EdgeInsets.all(8 * _fontScale),
                decoration: BoxDecoration(
                  color: _getFileColor(fileExtension).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(fileExtension),
                  color: _getFileColor(fileExtension),
                  size: 24 * _fontScale,
                ),
              ),
              SizedBox(width: 16 * _fontScale),

              // File Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 16 * _fontScale,
                        fontWeight: _boldText
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: _highContrast ? Colors.white : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4 * _fontScale),
                    Row(
                      children: [
                        Text(
                          _formatFileSize(int.tryParse(fileSize) ?? 0),
                          style: TextStyle(
                            color: _highContrast
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 12 * _fontScale,
                            fontWeight: _boldText
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        SizedBox(width: 8 * _fontScale),
                        Text(
                          '•',
                          style: TextStyle(
                            color: _highContrast
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 12 * _fontScale,
                          ),
                        ),
                        SizedBox(width: 8 * _fontScale),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: _highContrast
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 12 * _fontScale,
                            fontWeight: _boldText
                                ? FontWeight.w500
                                : FontWeight.normal,
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
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20 * _fontScale,
                        ),
                        SizedBox(width: 8 * _fontScale),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14 * _fontScale,
                            fontWeight: _boldText
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Icon(
                  Icons.more_vert,
                  color: _highContrast ? Colors.grey[400] : Colors.grey,
                  size: 24 * _fontScale,
                ),
              ),
            ],
          ),

          // Action Buttons for Summary and Flash Cards
          SizedBox(height: 12 * _fontScale),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSummary(filePath, fileName),
                  icon: Icon(Icons.summarize, size: 16 * _fontScale),
                  label: Text(
                    'Summary',
                    style: TextStyle(
                      fontSize: 12 * _fontScale,
                      fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[700],
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: 8 * _fontScale,
                      horizontal: 12 * _fontScale,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blue[200]!),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8 * _fontScale),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showFlashcards(filePath, fileName),
                  icon: Icon(Icons.quiz, size: 16 * _fontScale),
                  label: Text(
                    'Flash Cards',
                    style: TextStyle(
                      fontSize: 12 * _fontScale,
                      fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green[700],
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: 8 * _fontScale,
                      horizontal: 12 * _fontScale,
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
      ),
    );
  }

  // Helper methods for file styling
  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'docx':
      case 'doc':
        return Colors.blue;
      case 'txt':
        return Colors.grey;
      default:
        return const Color(0xFF7B2D93);
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    int index,
    String fileName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _highContrast ? Colors.grey[900] : null,
        title: Text(
          'Delete Document',
          style: TextStyle(
            fontSize: 18 * _fontScale,
            fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
            color: _highContrast ? Colors.white : null,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$fileName"?',
          style: TextStyle(
            fontSize: 16 * _fontScale,
            fontWeight: _boldText ? FontWeight.w500 : FontWeight.normal,
            color: _highContrast ? Colors.white : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14 * _fontScale,
                fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
                color: _highContrast ? Colors.white : null,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument(index);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14 * _fontScale,
                fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _highContrast ? Colors.black : null,
      // appBar: AppBar(
      //   title: Text(
      //     'Visual Learning',
      //     style: TextStyle(
      //       fontSize: 20 * _fontScale,
      //       fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
      //       color: _highContrast ? Colors.white : null,
      //     ),
      //   ),
      //   backgroundColor: _highContrast ? Colors.grey[900] : null,
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card with accessibility features highlight
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
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
                  Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 48 * _fontScale,
                  ),
                  SizedBox(height: 16 * _fontScale),
                  Text(
                    'Visual Learning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28 * _fontScale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8 * _fontScale),
                  Text(
                    'Accessibility features for visually impaired learners',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16 * _fontScale,
                      fontWeight: _boldText
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20 * _fontScale),

            // Accessibility Controls Section
            Card(
              color: _highContrast ? Colors.grey[900] : Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF7B2D93).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width -
                      32, // Account for padding
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0 * _fontScale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8 * _fontScale),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B2D93).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.accessibility_new,
                              size: 20 * _fontScale,
                              color: const Color(0xFF7B2D93),
                            ),
                          ),
                          SizedBox(width: 12 * _fontScale),
                          Expanded(
                            child: Text(
                              'Accessibility Settings',
                              style: TextStyle(
                                fontSize: 16 * _fontScale,
                                fontWeight: FontWeight.bold,
                                color: _highContrast
                                    ? Colors.white
                                    : const Color(0xFF2D2D2D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16 * _fontScale),

                      // Font Size Control
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12 * _fontScale),
                        decoration: BoxDecoration(
                          color: _highContrast
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF7B2D93).withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Font Size',
                                    style: TextStyle(
                                      fontSize: 14 * _fontScale,
                                      fontWeight: FontWeight.w600,
                                      color: _highContrast
                                          ? Colors.white
                                          : const Color(0xFF2D2D2D),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8 * _fontScale,
                                    vertical: 4 * _fontScale,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7B2D93),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${(_fontScale * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 12 * _fontScale,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8 * _fontScale),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF7B2D93),
                                inactiveTrackColor: const Color(
                                  0xFF7B2D93,
                                ).withOpacity(0.3),
                                thumbColor: const Color(0xFF7B2D93),
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: 10 * _fontScale,
                                ),
                                overlayColor: const Color(
                                  0xFF7B2D93,
                                ).withOpacity(0.2),
                                trackHeight: 3 * _fontScale,
                              ),
                              child: Slider(
                                value: _fontScale,
                                min: 0.8,
                                max: 2.0,
                                divisions: 12,
                                onChanged: (value) {
                                  setState(() {
                                    _fontScale = value;
                                  });
                                  _saveAccessibilitySettings();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12 * _fontScale),

                      // High Contrast Toggle
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12 * _fontScale),
                        decoration: BoxDecoration(
                          color: _highContrast
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _highContrast
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF7B2D93).withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6 * _fontScale),
                              decoration: BoxDecoration(
                                color: _highContrast
                                    ? Colors.white.withOpacity(0.1)
                                    : const Color(0xFF7B2D93).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.contrast,
                                size: 16 * _fontScale,
                                color: _highContrast
                                    ? Colors.white
                                    : const Color(0xFF7B2D93),
                              ),
                            ),
                            SizedBox(width: 12 * _fontScale),
                            Expanded(
                              child: Text(
                                'High Contrast',
                                style: TextStyle(
                                  fontSize: 14 * _fontScale,
                                  fontWeight: FontWeight.w600,
                                  color: _highContrast
                                      ? Colors.white
                                      : const Color(0xFF2D2D2D),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _highContrast,
                                activeColor: const Color(0xFF7B2D93),
                                onChanged: (value) {
                                  setState(() {
                                    _highContrast = value;
                                  });
                                  _saveAccessibilitySettings();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12 * _fontScale),

                      // Bold Text Toggle
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12 * _fontScale),
                        decoration: BoxDecoration(
                          color: _highContrast
                              ? Colors.grey[800]
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _boldText
                                ? const Color(0xFF7B2D93)
                                : const Color(0xFF7B2D93).withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6 * _fontScale),
                              decoration: BoxDecoration(
                                color: _boldText
                                    ? const Color(0xFF7B2D93).withOpacity(0.2)
                                    : const Color(0xFF7B2D93).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.format_bold,
                                size: 16 * _fontScale,
                                color: _highContrast
                                    ? Colors.white
                                    : const Color(0xFF7B2D93),
                              ),
                            ),
                            SizedBox(width: 12 * _fontScale),
                            Expanded(
                              child: Text(
                                'Bold Text',
                                style: TextStyle(
                                  fontSize: 14 * _fontScale,
                                  fontWeight: _boldText
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: _highContrast
                                      ? Colors.white
                                      : const Color(0xFF2D2D2D),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _boldText,
                                activeColor: const Color(0xFF7B2D93),
                                onChanged: (value) {
                                  setState(() {
                                    _boldText = value;
                                  });
                                  _saveAccessibilitySettings();
                                },
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
            SizedBox(height: 20 * _fontScale),

            // Document Upload Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Documents',
                  style: TextStyle(
                    fontSize: 20 * _fontScale,
                    fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
                    color: _highContrast ? Colors.white : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickAndUploadDocument,
                  icon: _isLoading
                      ? SizedBox(
                          width: 16 * _fontScale,
                          height: 16 * _fontScale,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.upload_file, size: 20 * _fontScale),
                  label: Text(
                    _isLoading ? 'Uploading...' : 'Upload',
                    style: TextStyle(
                      fontSize: 14 * _fontScale,
                      fontWeight: _boldText ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
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
            SizedBox(height: 16 * _fontScale),

            // Documents list
            uploadedDocuments.isEmpty
                ? Container(
                    padding: EdgeInsets.all(32 * _fontScale),
                    decoration: BoxDecoration(
                      color: _highContrast ? Colors.grey[800] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _highContrast
                            ? Colors.grey[600]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload,
                          size: 48 * _fontScale,
                          color: _highContrast
                              ? Colors.grey[400]
                              : Colors.grey[400],
                        ),
                        SizedBox(height: 16 * _fontScale),
                        Text(
                          'No documents uploaded yet',
                          style: TextStyle(
                            fontSize: 16 * _fontScale,
                            color: _highContrast
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontWeight: _boldText
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8 * _fontScale),
                        Text(
                          'Upload PDF, DOCX, or TXT files to get started with\nsummaries and flashcards',
                          style: TextStyle(
                            fontSize: 14 * _fontScale,
                            color: _highContrast
                                ? Colors.grey[500]
                                : Colors.grey[500],
                            fontWeight: _boldText
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: uploadedDocuments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final document = entry.value;
                      return _buildDocumentCard(document, index);
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

// Visual Summary Screen - Full page view (matches ADHD.dart styling)
class VisualSummaryScreen extends StatefulWidget {
  final String fileName;
  final String summary;
  final double fontScale;
  final bool highContrast;
  final bool boldText;

  const VisualSummaryScreen({
    super.key,
    required this.fileName,
    required this.summary,
    required this.fontScale,
    required this.highContrast,
    required this.boldText,
  });

  @override
  State<VisualSummaryScreen> createState() => _VisualSummaryScreenState();
}

class _VisualSummaryScreenState extends State<VisualSummaryScreen> {
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  double _speechRate = 1; // Default speech rate

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();

      print("Initializing TTS for VisualSummaryScreen...");

      // Check if TTS is available
      dynamic languages = await _flutterTts.getLanguages;
      if (languages != null) {
        print("VisualSummary TTS - Available languages: $languages");
      } else {
        print("Warning: No TTS languages available");
      }

      // Check for specific language availability
      bool isEnglishAvailable = await _flutterTts.isLanguageAvailable("en-US");
      print("English (en-US) available: $isEnglishAvailable");

      if (!isEnglishAvailable) {
        // Try alternative English variants
        List<String> englishVariants = ["en-GB", "en-AU", "en-CA", "en"];
        for (String variant in englishVariants) {
          bool available = await _flutterTts.isLanguageAvailable(variant);
          print("$variant available: $available");
          if (available) {
            var result = await _flutterTts.setLanguage(variant);
            print("Set language to $variant: $result");
            break;
          }
        }
      } else {
        // Set language to US English
        var result = await _flutterTts.setLanguage("en-US");
        print("VisualSummary TTS - Language set result: $result");
      }

      // Wait a bit for TTS engine to initialize
      await Future.delayed(Duration(milliseconds: 1000));

      // Set up TTS configuration with error handling
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(0.8);
      await _flutterTts.setPitch(1.0);

      // Set up TTS handlers
      _flutterTts.setStartHandler(() {
        print("TTS Started");
        if (mounted) {
          setState(() {
            _isSpeaking = true;
          });
        }
      });

      _flutterTts.setCompletionHandler(() {
        print("TTS Completed");
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
        print("VisualSummary TTS Error: $msg");
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Speech error: $msg"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });

      // Test TTS with a simple phrase
      print("Testing TTS with simple phrase...");
      await Future.delayed(Duration(milliseconds: 500));
      var testResult = await _flutterTts.speak("TTS test successful");
      print("TTS test result: $testResult");

      print("VisualSummary TTS initialized successfully");
    } catch (e) {
      print("VisualSummary TTS Initialization Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("TTS initialization failed: $e"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showSpeedControl() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: widget.highContrast
                  ? Colors.grey[900]
                  : Colors.white,
              title: Text(
                'Playback Speed',
                style: TextStyle(
                  fontSize: 20 * widget.fontScale,
                  fontWeight: widget.boldText
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: widget.highContrast ? Colors.white : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_speechRate.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontSize: 24 * widget.fontScale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7B2D93),
                    ),
                  ),
                  SizedBox(height: 16 * widget.fontScale),
                  Slider(
                    value: _speechRate,
                    min: 0.3,
                    max: 2.0,
                    divisions: 17,
                    activeColor: const Color(0xFF7B2D93),
                    inactiveColor: Colors.grey[300],
                    label: '${_speechRate.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setDialogState(() {
                        _speechRate = value;
                      });
                      setState(() {
                        _speechRate = value;
                      });
                      _flutterTts.setSpeechRate(value);
                    },
                  ),
                  SizedBox(height: 8 * widget.fontScale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slower',
                        style: TextStyle(
                          fontSize: 12 * widget.fontScale,
                          color: widget.highContrast
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Faster',
                        style: TextStyle(
                          fontSize: 12 * widget.fontScale,
                          color: widget.highContrast
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16 * widget.fontScale,
                      fontWeight: widget.boldText
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: const Color(0xFF7B2D93),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakSummary() async {
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
        setState(() {
          _isSpeaking = false;
        });
        print("Stopped TTS playback");
      } else {
        // Clean the summary text for better TTS
        String cleanText = widget.summary
            .replaceAll(
              RegExp(r'\*\*\*(.*?)\*\*\*'),
              r'\1',
            ) // Remove bold italic
            .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1') // Remove bold
            .replaceAll(RegExp(r'\*(.*?)\*'), r'\1') // Remove italic
            .replaceAll(RegExp(r'#{1,6}\s*'), '') // Remove headers
            .replaceAll(
              RegExp(r'^[-*]\s*', multiLine: true),
              '',
            ) // Remove bullet points
            .replaceAll(
              RegExp(r'^\d+\.\s*', multiLine: true),
              '',
            ) // Remove numbered lists
            .replaceAll(
              RegExp(r'[^\w\s.,!?;:\-\(\)]'),
              ' ',
            ) // Remove special characters
            .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
            .trim();

        if (cleanText.isNotEmpty) {
          print(
            "Attempting to speak text: ${cleanText.substring(0, cleanText.length > 100 ? 100 : cleanText.length)}...",
          );
          print("Text length: ${cleanText.length} characters");

          // Initialize TTS again if needed
          await _initializeTts();

          // Wait for TTS engine to be ready
          await Future.delayed(Duration(milliseconds: 1000));

          // Check TTS status
          try {
            var languages = await _flutterTts.getLanguages;
            print("TTS Languages available: $languages");

            var isLanguageAvailable = await _flutterTts.isLanguageAvailable(
              "en-US",
            );
            print("English language available: $isLanguageAvailable");

            // Try setting language again
            var langResult = await _flutterTts.setLanguage("en-US");
            print("Language set result: $langResult");

            // Set TTS parameters
            await _flutterTts.setSpeechRate(_speechRate); // Use adjustable rate
            await _flutterTts.setVolume(0.8);
            await _flutterTts.setPitch(1.0);

            print("Starting TTS speech...");
            setState(() {
              _isSpeaking = true;
            });

            // Split text into smaller chunks if it's too long
            if (cleanText.length > 2000) {
              print("Text too long, splitting into chunks");
              List<String> chunks = [];
              int chunkSize = 1500;
              for (int i = 0; i < cleanText.length; i += chunkSize) {
                int end = (i + chunkSize < cleanText.length)
                    ? i + chunkSize
                    : cleanText.length;
                chunks.add(cleanText.substring(i, end));
              }

              for (String chunk in chunks) {
                if (!_isSpeaking) break; // Stop if user stopped
                print(
                  "Speaking chunk: ${chunk.substring(0, chunk.length > 50 ? 50 : chunk.length)}...",
                );
                var result = await _flutterTts.speak(chunk);
                print("Chunk TTS result: $result");

                // Wait for completion before next chunk
                await _flutterTts.awaitSpeakCompletion(true);
              }
            } else {
              var result = await _flutterTts.speak(cleanText);
              print("TTS speak result: $result");
            }
          } catch (ttsError) {
            print("TTS Operation Error: $ttsError");
            throw ttsError;
          }
        } else {
          print("No text to speak (empty after cleaning)");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No text content available to read"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print("TTS Speak Error: $e");
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Speech unavailable. Error: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visual Summary',
          style: TextStyle(
            fontSize: 18 * widget.fontScale,
            fontWeight: widget.boldText ? FontWeight.bold : FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF7B2D93),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.speed),
            onPressed: _showSpeedControl,
            tooltip: "Playback Speed",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _speakSummary,
        backgroundColor: const Color(0xFF7B2D93),
        foregroundColor: Colors.white,
        tooltip: _isSpeaking ? 'Stop Reading' : 'Read Aloud',
        child: Icon(
          _isSpeaking ? Icons.stop : Icons.volume_up,
          size: 28 * widget.fontScale,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.highContrast
                ? [Colors.black, Colors.grey[900]!]
                : [const Color(0xFF7B2D93).withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0 * widget.fontScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.0 * widget.fontScale),
                  decoration: BoxDecoration(
                    color: widget.highContrast
                        ? Colors.grey[900]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                        children: [
                          Icon(
                            Icons.visibility,
                            color: const Color(0xFF7B2D93),
                            size: 28 * widget.fontScale,
                          ),
                          SizedBox(width: 12 * widget.fontScale),
                          Expanded(
                            child: Text(
                              'Visual Learning Summary',
                              style: TextStyle(
                                fontSize: 22 * widget.fontScale,
                                fontWeight: widget.boldText
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: widget.highContrast
                                    ? Colors.white
                                    : const Color(0xFF2D3748),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8 * widget.fontScale),
                      Text(
                        'Document: ${widget.fileName}',
                        style: TextStyle(
                          fontSize: 16 * widget.fontScale,
                          color: widget.highContrast
                              ? Colors.grey[300]
                              : Colors.grey[600],
                          fontWeight: widget.boldText
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24 * widget.fontScale),

                // Summary content
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.0 * widget.fontScale),
                  decoration: BoxDecoration(
                    color: widget.highContrast
                        ? Colors.grey[900]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildMarkdownFormattedText(widget.summary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build properly formatted markdown text (matching ADHD.dart)
  Widget _buildMarkdownFormattedText(String markdownText) {
    List<Widget> widgets = [];
    final lines = markdownText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        widgets.add(SizedBox(height: 8 * widget.fontScale));
        continue;
      }

      // Handle headers
      if (line.startsWith('### ')) {
        widgets.add(
          _buildHeader(
            line.substring(4),
            18 * widget.fontScale,
            FontWeight.w600,
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          _buildHeader(
            line.substring(3),
            20 * widget.fontScale,
            FontWeight.bold,
          ),
        );
      } else if (line.startsWith('# ')) {
        widgets.add(
          _buildHeader(
            line.substring(2),
            22 * widget.fontScale,
            FontWeight.bold,
          ),
        );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildHeader(String text, double fontSize, FontWeight fontWeight) {
    return Container(
      margin: EdgeInsets.only(
        top: 20 * widget.fontScale,
        bottom: 12 * widget.fontScale,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: widget.boldText ? FontWeight.bold : fontWeight,
          color: widget.highContrast ? Colors.white : const Color(0xFF2D3748),
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Container(
      margin: EdgeInsets.only(bottom: 8 * widget.fontScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 6 * widget.fontScale,
              right: 8 * widget.fontScale,
            ),
            width: 6 * widget.fontScale,
            height: 6 * widget.fontScale,
            decoration: BoxDecoration(
              color: const Color(0xFF7B2D93),
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
      margin: EdgeInsets.only(bottom: 8 * widget.fontScale),
      child: _buildInlineFormattedText(text),
    );
  }

  Widget _buildFormattedParagraph(String text) {
    return Container(
      margin: EdgeInsets.only(bottom: 12 * widget.fontScale),
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
          fontSize: 16 * widget.fontScale,
          color: widget.highContrast ? Colors.white : const Color(0xFF4A5568),
          height: 1.6,
        );

        // Check if this part should be formatted
        if (i > 0 && i - 1 < markers.length) {
          final marker = markers[i - 1].group(1);
          switch (marker) {
            case 'BOLD':
              style = style.copyWith(fontWeight: FontWeight.bold);
              break;
            case 'ITALIC':
              style = style.copyWith(fontStyle: FontStyle.italic);
              break;
            case 'BOLDITALIC':
              style = style.copyWith(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
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
        style: TextStyle(
          fontSize: 15 * widget.fontScale,
          color: widget.highContrast ? Colors.white : Colors.black87,
          height: 1.6,
        ),
      ),
      textAlign: TextAlign.left,
    );
  }
}

// Visual Flash Cards Screen (matches ADHD.dart styling)
class VisualFlashCardsScreen extends StatefulWidget {
  final String fileName;
  final List<String> flashCards;
  final double fontScale;
  final bool highContrast;
  final bool boldText;
  final FlutterTts flutterTts;
  final bool isSpeaking;
  final Function(bool) onSpeakingChanged;

  const VisualFlashCardsScreen({
    super.key,
    required this.fileName,
    required this.flashCards,
    required this.fontScale,
    required this.highContrast,
    required this.boldText,
    required this.flutterTts,
    required this.isSpeaking,
    required this.onSpeakingChanged,
  });

  @override
  State<VisualFlashCardsScreen> createState() => _VisualFlashCardsScreenState();
}

class _VisualFlashCardsScreenState extends State<VisualFlashCardsScreen> {
  int currentCardIndex = 0;
  bool isFlipped = false;
  double _speechRate = 0.5; // Default speech rate

  @override
  void initState() {
    super.initState();
    _loadSpeechRate();
  }

  Future<void> _loadSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speechRate = prefs.getDouble('visual_speech_rate') ?? 0.5;
    });
    widget.flutterTts.setSpeechRate(_speechRate);
  }

  Future<void> _saveSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('visual_speech_rate', _speechRate);
  }

  void _showSpeedControl() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: widget.highContrast
                  ? Colors.grey[900]
                  : Colors.white,
              title: Text(
                'Playback Speed',
                style: TextStyle(
                  fontSize: 20 * widget.fontScale,
                  fontWeight: widget.boldText
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: widget.highContrast ? Colors.white : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_speechRate.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontSize: 24 * widget.fontScale,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7B2D93),
                    ),
                  ),
                  SizedBox(height: 16 * widget.fontScale),
                  Slider(
                    value: _speechRate,
                    min: 0.3,
                    max: 2.0,
                    divisions: 17,
                    activeColor: const Color(0xFF7B2D93),
                    inactiveColor: Colors.grey[300],
                    label: '${_speechRate.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setDialogState(() {
                        _speechRate = value;
                      });
                      setState(() {
                        _speechRate = value;
                      });
                      widget.flutterTts.setSpeechRate(value);
                      _saveSpeechRate();
                    },
                  ),
                  SizedBox(height: 8 * widget.fontScale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slower',
                        style: TextStyle(
                          fontSize: 12 * widget.fontScale,
                          color: widget.highContrast
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Faster',
                        style: TextStyle(
                          fontSize: 12 * widget.fontScale,
                          color: widget.highContrast
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16 * widget.fontScale,
                      fontWeight: widget.boldText
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: const Color(0xFF7B2D93),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _nextCard() {
    if (currentCardIndex < widget.flashCards.length - 1) {
      setState(() {
        currentCardIndex++;
        isFlipped = false;
      });
      // Stop any ongoing speech when switching cards
      widget.flutterTts.stop();
      widget.onSpeakingChanged(false);
    }
  }

  void _previousCard() {
    if (currentCardIndex > 0) {
      setState(() {
        currentCardIndex--;
        isFlipped = false;
      });
      // Stop any ongoing speech when switching cards
      widget.flutterTts.stop();
      widget.onSpeakingChanged(false);
    }
  }

  void _flipCard() {
    setState(() {
      isFlipped = !isFlipped;
    });
  }

  Future<void> _speakQuestion(String question) async {
    try {
      if (widget.isSpeaking) {
        await widget.flutterTts.stop();
        widget.onSpeakingChanged(false);
      } else {
        String cleanText = question.replaceFirst('Q: ', '').trim();

        // Check TTS readiness and apply speech rate
        await widget.flutterTts.awaitSpeakCompletion(false);
        await widget.flutterTts.stop();
        await widget.flutterTts.setSpeechRate(
          _speechRate,
        ); // Apply current speech rate
        await Future.delayed(Duration(milliseconds: 100));

        widget.onSpeakingChanged(true);

        widget.flutterTts.setStartHandler(() {
          widget.onSpeakingChanged(true);
        });

        widget.flutterTts.setCompletionHandler(() {
          widget.onSpeakingChanged(false);
        });

        widget.flutterTts.setErrorHandler((msg) {
          print("Flashcard Question TTS Error: $msg");
          widget.onSpeakingChanged(false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Cannot speak question: Please check TTS settings",
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        });

        var result = await widget.flutterTts.speak(cleanText);
        print("Question TTS result: $result");
      }
    } catch (e) {
      print("Question TTS Error: $e");
      widget.onSpeakingChanged(false);
    }
  }

  Future<void> _speakAnswer(String answer) async {
    try {
      if (widget.isSpeaking) {
        await widget.flutterTts.stop();
        widget.onSpeakingChanged(false);
      } else {
        String cleanText = answer.replaceFirst('A: ', '').trim();

        // Check TTS readiness and apply speech rate
        await widget.flutterTts.awaitSpeakCompletion(false);
        await widget.flutterTts.stop();
        await widget.flutterTts.setSpeechRate(
          _speechRate,
        ); // Apply current speech rate
        await Future.delayed(Duration(milliseconds: 100));

        widget.onSpeakingChanged(true);

        widget.flutterTts.setStartHandler(() {
          widget.onSpeakingChanged(true);
        });

        widget.flutterTts.setCompletionHandler(() {
          widget.onSpeakingChanged(false);
        });

        widget.flutterTts.setErrorHandler((msg) {
          print("Flashcard Answer TTS Error: $msg");
          widget.onSpeakingChanged(false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Cannot speak answer: Please check TTS settings"),
                backgroundColor: Colors.red,
              ),
            );
          }
        });

        var result = await widget.flutterTts.speak(cleanText);
        print("Answer TTS result: $result");
      }
    } catch (e) {
      print("Answer TTS Error: $e");
      widget.onSpeakingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashCards.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Visual Flash Cards',
            style: TextStyle(
              fontSize: 18 * widget.fontScale,
              fontWeight: widget.boldText ? FontWeight.bold : FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF7B2D93),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Text(
            'No flash cards available',
            style: TextStyle(
              fontSize: 18 * widget.fontScale,
              fontWeight: widget.boldText ? FontWeight.w500 : FontWeight.normal,
              color: widget.highContrast ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    final currentCard = widget.flashCards[currentCardIndex];
    final parts = currentCard.split('\nA: ');
    final question = parts[0].replaceFirst('Q: ', '');
    final answer = parts.length > 1 ? parts[1] : 'No answer available';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visual Flash Cards',
          style: TextStyle(
            fontSize: 18 * widget.fontScale,
            fontWeight: widget.boldText ? FontWeight.bold : FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF7B2D93),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.speed),
            onPressed: _showSpeedControl,
            tooltip: "Playback Speed",
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.highContrast
                ? [Colors.black, Colors.grey[900]!]
                : [const Color(0xFF7B2D93).withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.0 * widget.fontScale),
            child: Column(
              children: [
                // Header with document name and progress
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.0 * widget.fontScale),
                  decoration: BoxDecoration(
                    color: widget.highContrast
                        ? Colors.grey[900]
                        : Colors.white,
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
                      Text(
                        widget.fileName,
                        style: TextStyle(
                          fontSize: 18 * widget.fontScale,
                          fontWeight: widget.boldText
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: widget.highContrast
                              ? Colors.white
                              : const Color(0xFF2D3748),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12 * widget.fontScale),
                      Text(
                        'Card ${currentCardIndex + 1} of ${widget.flashCards.length}',
                        style: TextStyle(
                          fontSize: 14 * widget.fontScale,
                          color: widget.highContrast
                              ? Colors.grey[300]
                              : Colors.grey[600],
                          fontWeight: widget.boldText
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      SizedBox(height: 8 * widget.fontScale),
                      LinearProgressIndicator(
                        value:
                            (currentCardIndex + 1) / widget.flashCards.length,
                        backgroundColor: widget.highContrast
                            ? Colors.grey[700]
                            : Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF7B2D93),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24 * widget.fontScale),

                // Flashcard
                Expanded(
                  child: SingleChildScrollView(
                    child: Card(
                      color: widget.highContrast ? Colors.grey[900] : null,
                      elevation: widget.highContrast ? 8 : 4,
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        padding: EdgeInsets.all(24.0 * widget.fontScale),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isFlipped
                                      ? Icons.lightbulb
                                      : Icons.help_outline,
                                  size: 48 * widget.fontScale,
                                  color: widget.highContrast
                                      ? Colors.white
                                      : Theme.of(context).primaryColor,
                                ),
                                SizedBox(width: 16 * widget.fontScale),
                                // Speaker button for current content
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF7B2D93,
                                    ).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      if (isFlipped) {
                                        _speakAnswer(answer);
                                      } else {
                                        _speakQuestion(question);
                                      }
                                    },
                                    icon: Icon(
                                      widget.isSpeaking
                                          ? Icons.stop
                                          : Icons.volume_up,
                                      size: 32 * widget.fontScale,
                                      color: const Color(0xFF7B2D93),
                                    ),
                                    tooltip: widget.isSpeaking
                                        ? 'Stop Reading'
                                        : (isFlipped
                                              ? 'Read Answer Aloud'
                                              : 'Read Question Aloud'),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24 * widget.fontScale),
                            Text(
                              isFlipped ? 'Answer:' : 'Question:',
                              style: TextStyle(
                                fontSize: 18 * widget.fontScale,
                                fontWeight: widget.boldText
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: widget.highContrast
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 16 * widget.fontScale),
                            Container(
                              constraints: BoxConstraints(
                                minHeight: 100 * widget.fontScale,
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  isFlipped ? answer : question,
                                  style: TextStyle(
                                    fontSize: 20 * widget.fontScale,
                                    fontWeight: widget.boldText
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: widget.highContrast
                                        ? Colors.white
                                        : null,
                                    height: 1.6,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            SizedBox(height: 24 * widget.fontScale),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Show Answer/Question Button
                                ElevatedButton(
                                  onPressed: _flipCard,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.highContrast
                                        ? Colors.white
                                        : null,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 32 * widget.fontScale,
                                      vertical: 12 * widget.fontScale,
                                    ),
                                  ),
                                  child: Text(
                                    isFlipped ? 'Show Question' : 'Show Answer',
                                    style: TextStyle(
                                      fontSize: 16 * widget.fontScale,
                                      fontWeight: widget.boldText
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: widget.highContrast
                                          ? Colors.black
                                          : null,
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
                ),

                // Navigation buttons
                SizedBox(height: 20 * widget.fontScale),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: currentCardIndex > 0 ? _previousCard : null,
                        icon: Icon(
                          Icons.arrow_back,
                          size: 20 * widget.fontScale,
                          color: widget.highContrast ? Colors.black : null,
                        ),
                        label: Text(
                          'Previous',
                          style: TextStyle(
                            fontSize: 14 * widget.fontScale,
                            fontWeight: widget.boldText
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: widget.highContrast ? Colors.black : null,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.highContrast
                              ? Colors.white
                              : null,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * widget.fontScale,
                            vertical: 12 * widget.fontScale,
                          ),
                        ),
                      ),
                      SizedBox(width: 16 * widget.fontScale),
                      ElevatedButton.icon(
                        onPressed:
                            currentCardIndex < widget.flashCards.length - 1
                            ? _nextCard
                            : null,
                        icon: Icon(
                          Icons.arrow_forward,
                          size: 20 * widget.fontScale,
                          color: widget.highContrast ? Colors.black : null,
                        ),
                        label: Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 14 * widget.fontScale,
                            fontWeight: widget.boldText
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: widget.highContrast ? Colors.black : null,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.highContrast
                              ? Colors.white
                              : null,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * widget.fontScale,
                            vertical: 12 * widget.fontScale,
                          ),
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
    );
  }
}

// Flashcard Screen for visual learning
// DEPRECATED - Replaced by VisualFlashCardsScreen above
