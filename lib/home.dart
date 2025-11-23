import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'firebase_auth.dart';
import 'login_screen.dart';
import 'ADHD.dart';
import 'profile.dart';
import 'visual.dart';
import 'hearing.dart';
import 'user_activity_service.dart';
import 'helpandsupport.dart';
import 'feedback.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Public setter for navigation
  void setTabIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _pages = [
    const HomeTabPage(),
    const VisualPage(),
    const HearingPage(),
    const ADHDPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B2D93),
        foregroundColor: Colors.white,
        elevation: 2,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'TamkeenED',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              _showNotificationsModal(context);
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _pages[_currentIndex],
      bottomNavigationBar: ConvexAppBar(
        key: ValueKey<int>(_currentIndex),
        style: TabStyle.reactCircle,
        backgroundColor: const Color(
          0xFF7B2D93,
        ), // Purple color to match app theme
        activeColor: Colors.white,
        color: Colors.white70,
        height: 60,
        curveSize: 80,
        top: -25,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.visibility, title: 'Visual Aid'),
          TabItem(icon: Icons.hearing, title: 'Hearing Aid'),
          TabItem(icon: Icons.psychology, title: 'ADHD'),
        ],
        initialActiveIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  void _showNotificationsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const NotificationsModal(),
    );
  }
}

// Home Tab Page
class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  String _userName = '';
  String _userEmail = '';
  bool _isLoading = true;

  // User stats
  Map<String, dynamic> _userStats = {};
  List<Map<String, dynamic>> _userDocuments = [];
  List<Map<String, dynamic>> _featureProgress = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadUserData();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuthService.currentUser;
    if (user != null) {
      final profile = await FirebaseAuthService.getUserProfile(user.uid);
      setState(() {
        if (profile != null) {
          _userName =
              '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'
                  .trim();
        }
        _userEmail = user.email ?? '';
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await UserActivityService.getUserStats();
      final documents = await UserActivityService.getUserDocumentsProgress();
      final features = await UserActivityService.getFeatureProgress();

      setState(() {
        _userStats = stats;
        _userDocuments = documents;
        _featureProgress = features;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToTab(BuildContext context, int index) {
    final homeState = context.findAncestorStateOfType<_HomePageState>();
    if (homeState != null) {
      homeState.setTabIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B2D93)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: const Color(0xFF7B2D93),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section with Real User Data
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
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_userName.isNotEmpty)
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_userName.isEmpty && _userEmail.isNotEmpty)
                    Text(
                      _userEmail,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Continue your learning journey with TamkeenED',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Feature Progress Cards
            if (_featureProgress.isNotEmpty) ...[
              const Text(
                'Feature Progress',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._featureProgress.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFeatureProgressCard(feature),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Real Progress Statistics
            const Text(
              'Your Progress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.description,
                    title: 'Documents',
                    value: '${_userStats['documentsProcessed'] ?? 0}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.timer,
                    title: 'Sessions',
                    value: '${_userStats['focusSessions'] ?? 0}',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.schedule,
                    title: 'Study Time',
                    value: UserActivityService.formatStudyTime(
                      _userStats['studyTimeMinutes'] ?? 0,
                    ),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.stars,
                    title: 'Points',
                    value: '${_userStats['points'] ?? 0}',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Access Section
            const Text(
              'Quick Access',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickAccessCard(
              icon: Icons.visibility,
              title: 'Visual Aid',
              description: 'Text-to-speech and font customization',
              color: Colors.blue,
              onTap: () {
                _navigateToTab(context, 1);
              },
            ),
            const SizedBox(height: 12),
            _buildQuickAccessCard(
              icon: Icons.hearing,
              title: 'Hearing Aid',
              description: 'Audio transcription and playback',
              color: Colors.green,
              onTap: () {
                _navigateToTab(context, 2);
              },
            ),
            const SizedBox(height: 12),
            _buildQuickAccessCard(
              icon: Icons.psychology,
              title: 'ADHD Support',
              description: 'Focus timer and document processing',
              color: Colors.purple,
              onTap: () {
                _navigateToTab(context, 3);
              },
            ),
            const SizedBox(height: 24),

            // App Features Info (only show if no documents yet)
            if (_userDocuments.isEmpty) ...[
              const Text(
                'Get Started',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                icon: Icons.upload_file,
                title: 'Upload Your First Document',
                description:
                    'Go to ADHD Support and upload a PDF, DOCX, or TXT file to get AI-powered summaries and flashcards.',
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.timer,
                title: 'Start a Focus Session',
                description:
                    'Use the Focus Timer in ADHD Support to track your study sessions and earn points.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentProgressCard(Map<String, dynamic> document) {
    final documentName = document['documentName'] ?? 'Unknown Document';
    final summaryViewed = document['summaryViewed'] ?? false;
    final flashcardProgress = (document['flashcardProgress'] ?? 0.0) as double;
    final flashcardViewed = document['flashcardViewed'] ?? 0;
    final flashcardTotal = document['flashcardTotal'] ?? 0;
    final lastAccessed = document['lastAccessed'] ?? '';

    String progressText = '';
    double overallProgress = 0.0;

    if (summaryViewed && flashcardTotal > 0) {
      // Both summary and flashcards
      overallProgress =
          (0.3 +
          (flashcardProgress * 0.7)); // 30% for summary, 70% for flashcards
      if (flashcardProgress >= 1.0) {
        progressText = 'Completed';
      } else {
        progressText = '${flashcardViewed}/${flashcardTotal} flashcards';
      }
    } else if (summaryViewed) {
      overallProgress = 0.3;
      progressText = 'Summary viewed';
    } else if (flashcardTotal > 0) {
      overallProgress = flashcardProgress * 0.7;
      progressText = '${flashcardViewed}/${flashcardTotal} flashcards';
    } else {
      overallProgress = 0.0;
      progressText = 'Not started';
    }

    return GestureDetector(
      onTap: () =>
          _navigateToTab(context, 3), // Navigate to ADHD tab to see document
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
                    Icons.description,
                    color: Color(0xFF7B2D93),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (lastAccessed.isNotEmpty)
                        Text(
                          UserActivityService.formatTimeAgo(lastAccessed),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7B2D93),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progressText,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureProgressCard(Map<String, dynamic> feature) {
    final name = feature['name'] ?? '';
    final iconName = feature['icon'] ?? 'info';
    final colorName = feature['color'] ?? 'grey';
    final progress = (feature['progress'] ?? 0.0) as double;
    final progressText = feature['progressText'] ?? '';
    final subtitle = feature['subtitle'] ?? '';

    // Get icon based on name
    IconData icon;
    switch (iconName) {
      case 'psychology':
        icon = Icons.psychology;
        break;
      case 'visibility':
        icon = Icons.visibility;
        break;
      case 'hearing':
        icon = Icons.hearing;
        break;
      default:
        icon = Icons.info;
    }

    // Get color based on name
    Color color;
    switch (colorName) {
      case 'purple':
        color = Colors.purple;
        break;
      case 'blue':
        color = Colors.blue;
        break;
      case 'green':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        progressText,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTimerCard(FocusTimerService timerService) {
    return StreamBuilder<int>(
      stream: timerService.stopWatchTimer.rawTime,
      initialData: timerService.stopWatchTimer.rawTime.value,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        final displayTime = StopWatchTimer.getDisplayTime(
          value,
          hours: false,
          milliSecond: false,
        );

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FocusTimerScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7B2D93).withOpacity(0.8),
                  const Color(0xFF5D1A73).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B2D93).withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    timerService.isRunning ? Icons.timer : Icons.pause_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timerService.isRunning
                            ? 'Focus Session Active'
                            : 'Focus Session Paused',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time remaining: $displayTime',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required String description,
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
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
                    description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
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
          Icon(icon, color: const Color(0xFF7B2D93), size: 28),
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
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// App Drawer
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7B2D93), Color(0xFF5D1A73)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.school,
                          size: 36,
                          color: Color(0xFF7B2D93),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TamkeenED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Empowering Education',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to home tab (index 0)
              final homeState = context
                  .findAncestorStateOfType<_HomePageState>();
              if (homeState != null) {
                homeState.setTabIndex(0);
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Profile Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpAndSupportScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Send Feedback'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeedbackScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuthService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// Notifications Modal
class NotificationsModal extends StatefulWidget {
  const NotificationsModal({super.key});

  @override
  State<NotificationsModal> createState() => _NotificationsModalState();
}

class _NotificationsModalState extends State<NotificationsModal> {
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentActivities();
  }

  Future<void> _loadRecentActivities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final activities = await UserActivityService.getRecentActivities(
        limit: 10,
      );
      setState(() {
        _recentActivities = activities;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading activities: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF7B2D93),
                      ),
                    ),
                  )
                : Consumer<FocusTimerService>(
                    builder: (context, timerService, child) {
                      final hasActiveTimer =
                          timerService.isRunning ||
                          timerService.stopWatchTimer.rawTime.value > 0;

                      final hasNotifications =
                          hasActiveTimer || _recentActivities.isNotEmpty;

                      if (!hasNotifications) {
                        // No notifications to show
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You\'re all caught up!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        children: [
                          // Show running timer notification if timer is active
                          if (hasActiveTimer)
                            _buildTimerNotification(timerService),

                          // Show recent activities
                          ..._recentActivities.map(
                            (activity) => _buildActivityNotification(activity),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityNotification(Map<String, dynamic> activity) {
    final message = activity['message'] ?? '';
    final type = activity['type'] ?? '';
    final timestamp = activity['timestamp'] ?? '';

    IconData icon;
    Color color;

    switch (type) {
      case 'document_upload':
        icon = Icons.upload_file;
        color = Colors.blue;
        break;
      case 'media_upload':
        icon = Icons.audiotrack;
        color = Colors.green;
        break;
      case 'transcription_view':
        icon = Icons.closed_caption;
        color = Colors.teal;
        break;
      case 'focus_session':
        icon = Icons.timer;
        color = Colors.green;
        break;
      case 'summary_view':
        icon = Icons.summarize;
        color = Colors.orange;
        break;
      case 'flashcards_complete':
        icon = Icons.check_circle;
        color = Colors.purple;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: Text(
          UserActivityService.formatTimeAgo(timestamp),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildTimerNotification(FocusTimerService timerService) {
    return StreamBuilder<int>(
      stream: timerService.stopWatchTimer.rawTime,
      initialData: timerService.stopWatchTimer.rawTime.value,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        final displayTime = StopWatchTimer.getDisplayTime(
          value,
          hours: false,
          milliSecond: false,
        );

        final isRunning = timerService.isRunning;
        final isCompleted = timerService.isCompleted;

        String title;
        String subtitle;
        IconData icon;
        Color color;

        if (isCompleted) {
          title = 'Focus Session Complete!';
          subtitle = 'Great job! You completed your focus session.';
          icon = Icons.celebration;
          color = Colors.green;
        } else if (isRunning) {
          title = 'Focus Session Active';
          subtitle = 'Keep focusing! Time remaining: $displayTime';
          icon = Icons.timer;
          color = const Color(0xFF7B2D93);
        } else if (value > 0) {
          title = 'Focus Session Paused';
          subtitle = 'Time remaining: $displayTime';
          icon = Icons.pause_circle;
          color = Colors.orange;
        } else {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: color.withOpacity(0.8)),
            ),
            trailing: isRunning
                ? Icon(Icons.access_time, color: color, size: 20)
                : isCompleted
                ? Icon(Icons.check_circle, color: color, size: 20)
                : Icon(Icons.pause, color: color, size: 20),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FocusTimerScreen(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
