import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HelpAndSupportScreen extends StatelessWidget {
  const HelpAndSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B2D93),
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
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
                  const Icon(Icons.help_outline, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'How can we help you?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find answers to common questions and learn how to use TamkeenED features',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Getting Started Section
            _buildSectionTitle('Getting Started'),
            const SizedBox(height: 12),
            _buildHelpCard(
              icon: Icons.account_circle,
              title: 'Create an Account',
              description:
                  'Sign up with your email and password to start using TamkeenED. Your profile will be automatically created.',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildHelpCard(
              icon: Icons.dashboard,
              title: 'Navigate the App',
              description:
                  'Use the bottom navigation bar to access Home, Visual Aid, Hearing Aid, and ADHD Support features.',
              color: Colors.green,
            ),
            const SizedBox(height: 24),

            // Features Guide Section
            _buildSectionTitle('Features Guide'),
            const SizedBox(height: 12),

            // ADHD Support
            _buildFeatureCard(
              icon: Icons.psychology,
              title: 'ADHD Support',
              color: Colors.purple,
              features: [
                'Upload PDF, DOCX, or TXT documents',
                'Get AI-powered summaries using Google Gemini',
                'Generate interactive flashcards for learning',
                'Use Focus Timer to track study sessions',
                'Earn points and track your progress',
              ],
            ),
            const SizedBox(height: 12),

            // Visual Aid
            _buildFeatureCard(
              icon: Icons.visibility,
              title: 'Visual Aid',
              color: Colors.blue,
              features: [
                'Upload documents for text-to-speech support',
                'Customize font size and family',
                'Adjust reading speed (0.3x - 2.0x)',
                'Change background and text colors',
                'View AI summaries with speech support',
                'Study with audio-enabled flashcards',
              ],
            ),
            const SizedBox(height: 12),

            // Hearing Aid
            _buildFeatureCard(
              icon: Icons.hearing,
              title: 'Hearing Aid',
              color: Colors.green,
              features: [
                'Upload audio/video files for transcription',
                'Get accurate transcriptions using Deepgram AI',
                'Play audio with synchronized text highlighting',
                'Adjust playback speed',
                'Save and manage your media files',
              ],
            ),
            const SizedBox(height: 24),

            // Tips & Tricks
            _buildSectionTitle('Tips & Tricks'),
            const SizedBox(height: 12),
            _buildTipCard(
              icon: Icons.lightbulb_outline,
              tip:
                  'Use the Focus Timer regularly to build consistent study habits and earn more points.',
            ),
            const SizedBox(height: 8),
            _buildTipCard(
              icon: Icons.lightbulb_outline,
              tip:
                  'Customize Visual Aid settings to find what works best for your reading comfort.',
            ),
            const SizedBox(height: 8),
            _buildTipCard(
              icon: Icons.lightbulb_outline,
              tip:
                  'Review flashcards multiple times to improve retention and track your progress.',
            ),
            const SizedBox(height: 8),
            _buildTipCard(
              icon: Icons.lightbulb_outline,
              tip:
                  'Pull down on the Home page to refresh your stats and see updated progress.',
            ),
            const SizedBox(height: 24),

            // FAQ Section
            _buildSectionTitle('Frequently Asked Questions'),
            const SizedBox(height: 12),
            _buildFAQCard(
              question: 'What file formats are supported?',
              answer:
                  'ADHD Support and Visual Aid accept PDF, DOCX, and TXT files. Hearing Aid supports most audio and video formats including MP3, WAV, M4A, MP4, and MOV.',
            ),
            const SizedBox(height: 12),
            _buildFAQCard(
              question: 'How does the Focus Timer work?',
              answer:
                  'Set your desired focus duration, start the timer, and concentrate on your work. When completed, you\'ll earn points and the session will be tracked in your progress.',
            ),
            const SizedBox(height: 12),
            _buildFAQCard(
              question: 'Can I delete uploaded documents?',
              answer:
                  'Yes! Simply tap and hold on any document or media card, then select delete. Your progress stats will automatically update.',
            ),
            const SizedBox(height: 12),
            _buildFAQCard(
              question: 'Is my data secure?',
              answer:
                  'Yes, all your data is securely stored in Firebase with authentication. Only you can access your documents and progress.',
            ),
            const SizedBox(height: 24),



            // Development Team
            _buildSectionTitle('Development Team'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B2D93).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.group,
                          color: Color(0xFF7B2D93),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'TamkeenED Team',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDeveloperRow('Aljazi Alghunaim', '221410108'),
                  _buildDeveloperRow('Lara AlBaijan', '218510816'),
                  _buildDeveloperRow('Rose Alrabah', '219510958'),
                  _buildDeveloperRow('Manar Altuwaim', '220410529'),
                  _buildDeveloperRow('Nouf Almojel', '222410007'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B2D93).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),

                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Version
            Center(
              child: Column(
                children: [
                  Text(
                    'TamkeenED',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2025 TamkeenED. All rights reserved.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF7B2D93),
      ),
    );
  }

  Widget _buildHelpCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard({required IconData icon, required String tip}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQCard({required String question, required String answer}) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      title: Text(
        question,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      children: [
        Text(
          answer,
          style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2D93).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF7B2D93), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperRow(String name, String id) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF7B2D93),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            id,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email, {String? subject}) async {
    // Copy email to clipboard and show notification
    await Clipboard.setData(ClipboardData(text: email));
    // Note: This is a simplified version. In production, you would use url_launcher package
  }
}
