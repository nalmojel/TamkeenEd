import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'firebase_auth.dart';
import 'login_screen.dart';
import 'ADHD.dart';
import 'profile.dart';
import 'visual.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeTabPage(),
    const VisualPage(),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
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
        style: TabStyle.reactCircle,
        backgroundColor: const Color(0xFF7B2D93), // Purple color to match app theme
        activeColor: Colors.white,
        color: Colors.white70,
        height: 60,
        curveSize: 80,
        top: -25,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.visibility, title: 'Visual'),
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
class HomeTabPage extends StatelessWidget {
  const HomeTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Continue your learning journey',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Stats
          const Text(
            'Your Progress',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.book,
                  title: 'Courses',
                  value: '12',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  title: 'Completed',
                  value: '8',
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
                  title: 'Hours',
                  value: '45',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  title: 'Points',
                  value: '1,250',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Courses
          const Text(
            'Continue Learning',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildCourseCard(
            title: 'Mathematics Fundamentals',
            progress: 0.75,
            duration: '2h 30m left',
          ),
          const SizedBox(height: 12),
          _buildCourseCard(
            title: 'Science Exploration',
            progress: 0.45,
            duration: '4h 15m left',
          ),
        ],
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
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard({
    required String title,
    required double progress,
    required String duration,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B2D93)),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% Complete',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// Message Tab Page
class MessageTabPage extends StatelessWidget {
  const MessageTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message,
            size: 64,
            color: Color(0xFF7B2D93),
          ),
          SizedBox(height: 16),
          Text(
            'Messages',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Chat with teachers and classmates',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Courses Tab Page
class CoursesTabPage extends StatelessWidget {
  const CoursesTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book,
            size: 64,
            color: Color(0xFF7B2D93),
          ),
          SizedBox(height: 16),
          Text(
            'Courses',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Browse and enroll in courses',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// Progress Tab Page
class ProgressTabPage extends StatelessWidget {
  const ProgressTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 64,
            color: Color(0xFF7B2D93),
          ),
          SizedBox(height: 16),
          Text(
            'Progress',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Track your learning progress',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
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
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.pop(context),
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
            onTap: () => Navigator.pop(context),
          ),
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: Consumer<FocusTimerService>(
              builder: (context, timerService, child) {
                return ListView(
                  children: [
                    // Show running timer notification if timer is active
                    if (timerService.isRunning || timerService.stopWatchTimer.rawTime.value > 0)
                      _buildTimerNotification(timerService),
                    
                    // Regular notifications
                    _buildNotificationItem(
                      icon: Icons.assignment,
                      title: 'New Assignment Available',
                      subtitle: 'Mathematics Chapter 5 assignment is now available',
                      time: '2 hours ago',
                    ),
                    _buildNotificationItem(
                      icon: Icons.grade,
                      title: 'Grade Posted',
                      subtitle: 'Your Science quiz grade has been posted',
                      time: '1 day ago',
                    ),
                    _buildNotificationItem(
                      icon: Icons.event,
                      title: 'Upcoming Class',
                      subtitle: 'Physics class starts in 30 minutes',
                      time: '2 days ago',
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
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

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF7B2D93).withOpacity(0.1),
        child: Icon(icon, color: const Color(0xFF7B2D93)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}