import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home.dart';
import 'firebase_auth.dart';
import 'ADHD.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseAuthService.initializeFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FocusTimerService>(
      create: FocusTimerService(),
      child: MaterialApp(
        navigatorKey: globalNavigatorKey, // Use the global navigator key
        title: 'TamkeenED',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7B2D93), // Purple from logo
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          primaryColor: const Color(0xFF7B2D93), // Main purple
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF7B2D93), // Purple app bar
            foregroundColor: Colors.white,
          ),
        ),
        home: StreamBuilder(
          stream: FirebaseAuthService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B2D93)),
                  ),
                ),
              );
            }
            
            if (snapshot.hasData) {
              return const AppWithFloatingTimer(child: HomePage());
            } else {
              return const AppWithFloatingTimer(child: LoginScreen());
            }
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// Wrapper widget that adds global timer completion handler to any screen
class AppWithFloatingTimer extends StatelessWidget {
  final Widget child;

  const AppWithFloatingTimer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const GlobalTimerCompletionHandler(),
      ],
    );
  }
}

// Global Timer Completion Handler
class GlobalTimerCompletionHandler extends StatefulWidget {
  const GlobalTimerCompletionHandler({super.key});

  @override
  State<GlobalTimerCompletionHandler> createState() => _GlobalTimerCompletionHandlerState();
}

class _GlobalTimerCompletionHandlerState extends State<GlobalTimerCompletionHandler> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusTimerService>(
      builder: (context, timerService, child) {
        print("DEBUG: Global completion handler build called. Flag: ${timerService.shouldShowCompletionDialog}, dialogShown: $_dialogShown");
        
        // Check if we need to show completion dialog
        if (timerService.shouldShowCompletionDialog && !_dialogShown) {
          print("DEBUG: Global completion dialog should show! Flag: ${timerService.shouldShowCompletionDialog}, dialogShown: $_dialogShown");
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showGlobalCompletionDialog(timerService);
          });
        } else if (!timerService.shouldShowCompletionDialog) {
          _dialogShown = false;
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showGlobalCompletionDialog(FocusTimerService timerService) {
    if (!mounted) return;
    
    print("DEBUG: Showing global completion dialog!");
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
                color: Color(0xFF5D1A73), // Darker purple
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Great job! You completed your focus session.',
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
              timerService.clearCompletionDialog();
              timerService.resetTimer();
              // Navigate to timer screen for new session
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FocusTimerScreen(),
                ),
              );
            },
            child: const Text(
              'Start New Session',
              style: TextStyle(color: Color(0xFF7B2D93)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              timerService.clearCompletionDialog();
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
}

