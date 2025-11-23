import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:io';
import 'user_activity_service.dart';

class HearingPage extends StatefulWidget {
  const HearingPage({super.key});

  @override
  State<HearingPage> createState() => _HearingPageState();
}

class _HearingPageState extends State<HearingPage> {
  List<Map<String, String>> uploadedMedia = [];
  bool _isLoading = false;

  // Deepgram API configuration
  static const String _deepgramApiKey =
      'b877c2ad23653ed8fc82fd3aac043dcf32b9bd80'; // Replace with your actual API key
  late final Deepgram _deepgram;

  @override
  void initState() {
    super.initState();
    _initializeDeepgram();
    _loadUploadedMedia();
  }

  void _initializeDeepgram() {
    _deepgram = Deepgram(_deepgramApiKey);
  }

  // Load uploaded media from local storage
  Future<void> _loadUploadedMedia() async {
    final prefs = await SharedPreferences.getInstance();
    final mediaJson = prefs.getString('hearing_uploaded_media');
    if (mediaJson != null) {
      final List<dynamic> mediaList = json.decode(mediaJson);
      setState(() {
        uploadedMedia = mediaList
            .map((media) => Map<String, String>.from(media))
            .toList();
      });
    }
  }

  // Save uploaded media to local storage
  Future<void> _saveUploadedMedia() async {
    final prefs = await SharedPreferences.getInstance();
    final mediaJson = json.encode(uploadedMedia);
    await prefs.setString('hearing_uploaded_media', mediaJson);
  }

  // Transcribe audio/video file using Deepgram
  Future<String> _transcribeMedia(String filePath, String fileName) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final file = File(filePath);

      print('Starting transcription for: $fileName');
      print('File path: $filePath');

      // Use Deepgram to transcribe the file
      final result = await _deepgram.listen.file(
        file,
        queryParams: {
          'model': 'nova-2-general',
          'detect_language': true,
          'punctuate': true,
          'diarize': true,
          'smart_format': true,
          'utterances': true,
        },
      );

      print('Transcription completed');

      // Extract transcript from result
      final transcript = result.transcript ?? 'No transcript available';

      if (transcript.isEmpty || transcript == 'No transcript available') {
        throw Exception('Failed to generate transcript from audio');
      }

      return transcript;
    } catch (e) {
      print('Transcription error: $e');
      throw Exception('Failed to transcribe media: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show transcription in new page
  void _showTranscription(String filePath, String fileName) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B2D93)),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Text(
                'Transcribing audio...\nThis may take a few moments.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final transcript = await _transcribeMedia(filePath, fileName);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Track transcription view with proper points and activity logging
      await UserActivityService.trackTranscriptionView(fileName);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TranscriptionScreen(fileName: fileName, transcript: transcript),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Upload audio or video file
  Future<void> _pickAndUploadMedia() async {
    try {
      setState(() {
        _isLoading = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'mp4',
          'avi',
          'mov',
          'm4a',
          'aac',
          'flac',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileExtension = result.files.single.extension ?? '';
        final fileSize = result.files.single.size;

        // Determine if it's video or audio
        final videoExtensions = ['mp4', 'avi', 'mov'];
        final audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'flac'];

        String mediaType = '';
        String processingNote = '';
        String finalPath = file.path;

        if (videoExtensions.contains(fileExtension.toLowerCase())) {
          mediaType = 'video';
          processingNote = 'Video file uploaded successfully';
          finalPath = file.path;
          print('Video uploaded: $fileName');
        } else if (audioExtensions.contains(fileExtension.toLowerCase())) {
          mediaType = 'audio';
          processingNote = 'Audio file ready for processing';
          print('Audio uploaded: $fileName');
        } else {
          // Show error for unsupported file type
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error 400: Unsupported file type ".$fileExtension". Only audio and video files are supported.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // Get the final file size (in case audio was extracted)
        final finalFile = File(finalPath);
        final finalSize = await finalFile.length();

        // Store media information with all necessary metadata
        final mediaInfo = {
          'name': fileName,
          'path': finalPath,
          'extension': fileExtension,
          'size': finalSize.toString(),
          'uploadDate': DateTime.now().toIso8601String(),
          'type': mediaType,
          'description': processingNote,
        };

        setState(() {
          uploadedMedia.add(mediaInfo);
        });

        await _saveUploadedMedia();

        // Track media upload for hearing aid - use dedicated media upload tracking
        await UserActivityService.trackMediaUpload(fileName, finalPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$mediaType file "$fileName" uploaded successfully!',
              ),
              backgroundColor: const Color(0xFF7B2D93),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
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

  // Get icon for media type
  IconData _getMediaIcon(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Get color for media type
  Color _getMediaColor(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return Colors.blue;
      case 'audio':
        return Colors.green;
      default:
        return const Color(0xFF7B2D93);
    }
  }

  // Delete media
  Future<void> _deleteMedia(int index) async {
    final mediaPath = uploadedMedia[index]['path']!;

    setState(() {
      uploadedMedia.removeAt(index);
    });
    await _saveUploadedMedia();

    // Delete from Firebase to update usage counts
    await UserActivityService.deleteDocument(mediaPath);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media deleted successfully'),
          backgroundColor: Color(0xFF7B2D93),
        ),
      );
    }
  }

  // Build media card
  Widget _buildMediaCard(Map<String, String> media, int index) {
    final fileName = media['name'] ?? '';
    final fileSize = media['size'] ?? '';
    final uploadDate = media['uploadDate'] ?? '';
    final mediaType = media['type'] ?? '';
    final description = media['description'] ?? '';

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
          // Media Header
          Row(
            children: [
              // Media Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getMediaColor(mediaType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getMediaIcon(mediaType),
                  color: _getMediaColor(mediaType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Media Info
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$mediaType • ${_formatFileSize(int.tryParse(fileSize) ?? 0)} • $formattedDate',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () =>
                    _showDeleteConfirmation(context, index, fileName),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _showTranscription(media['path'] ?? '', fileName),
                  icon: const Icon(Icons.closed_caption, size: 18),
                  label: const Text('Transcribe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2D93),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  void _showDeleteConfirmation(
    BuildContext context,
    int index,
    String fileName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMedia(index);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card (same style as visual.dart)
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
                  const Icon(Icons.hearing, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Hearing Learning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload audio or video files to enhance your learning experience with audio-based content.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Upload Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Media Files',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickAndUploadMedia,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_isLoading ? 'Uploading...' : 'Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2D93),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Media list
            uploadedMedia.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(55),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No media files uploaded yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload audio or video files to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: uploadedMedia.asMap().entries.map((entry) {
                      final index = entry.key;
                      final media = entry.value;
                      return _buildMediaCard(media, index);
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

// Transcription Screen - Full page view (matches VisualSummaryScreen styling)
class TranscriptionScreen extends StatefulWidget {
  final String fileName;
  final String transcript;

  const TranscriptionScreen({
    super.key,
    required this.fileName,
    required this.transcript,
  });

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();

      print("Initializing TTS for TranscriptionScreen...");

      // Check if TTS is available
      dynamic languages = await _flutterTts.getLanguages;
      if (languages != null) {
        print("Transcription TTS - Available languages: $languages");
      }

      // Wait a bit for TTS engine to initialize
      await Future.delayed(const Duration(milliseconds: 1000));

      // Set up TTS configuration
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(0.8);
      await _flutterTts.setPitch(1.0);

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
        print("TTS Error: $msg");
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      });

      print("Transcription TTS initialized successfully");
    } catch (e) {
      print("Transcription TTS Initialization Error: $e");
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakTranscript() async {
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
        setState(() {
          _isSpeaking = false;
        });
        print("Stopped TTS playback");
      } else {
        print("Starting TTS playback");
        await _flutterTts.stop();
        await Future.delayed(const Duration(milliseconds: 200));

        var result = await _flutterTts.speak(widget.transcript);
        print("TTS speak result: $result");

        if (result == 1) {
          setState(() {
            _isSpeaking = true;
          });
        }
      }
    } catch (e) {
      print("TTS Speak Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Text-to-speech error: $e'),
            backgroundColor: Colors.red,
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
          'Transcription',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF7B2D93),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _speakTranscript,
        backgroundColor: const Color(0xFF7B2D93),
        child: Icon(
          _isSpeaking ? Icons.stop : Icons.volume_up,
          color: Colors.white,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF7B2D93).withOpacity(0.1), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
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
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2D93).withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.closed_caption,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Audio Transcription',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Transcript content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.article,
                          color: Color(0xFF7B2D93),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Transcript',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7B2D93),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    SelectableText(
                      widget.transcript,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }
}
