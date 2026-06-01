// ============================================================
// FILE: lib/main.dart
// PURPOSE: App entry point. Initializes Supabase, sets up
// the AuthController, wires GoRouter, and launches
// MaterialApp.router with AppTheme.dark.
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universe_v1/core/constants/app_constants.dart';
import 'package:universe_v1/core/router/app_router.dart';
import 'package:universe_v1/core/app_theme.dart';
import 'package:universe_v1/features/auth/controllers/auth_controller.dart';
import 'package:universe_v1/features/auth/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── System UI (status bar transparent, light icons) ───────
  AppTheme.setSystemUI();

  // ── Supabase initialization ───────────────────────────────
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // PKCE = secure for mobile
    ),
  );

  // ── Auth controller ───────────────────────────────────────
  final authController = AuthController();

  // ── Router ────────────────────────────────────────────────
  final appRouter = AppRouter(authController: authController);

  // ── Listen for OAuth deep link callbacks ──────────────────
  // When Google OAuth completes and redirects back to the app,
  // Supabase fires an onAuthStateChange event. We hook into
  // it here to call handleOAuthCallback on the controller.
  AuthService().authStateChanges.listen((event) async {
    if (event.event == AuthChangeEvent.signedIn) {
      // Only handle if not already authenticated (avoids
      // double-calling on app restore with existing session)
      if (authController.status != AuthStatus.authenticated) {
        await authController.handleOAuthCallback();
      }
    } else if (event.event == AuthChangeEvent.signedOut) {
      // GoRouter refresh will handle redirect to login
    }
  });

  runApp(UniVerseApp(router: appRouter));
}

class UniVerseApp extends StatelessWidget {
  final AppRouter router;

  const UniVerseApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router.router,
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:universe_v1/core/app_colors.dart';
// import 'package:universe_v1/core/app_theme.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:universe_v1/core/navigation/app_router.dart';

// void main() async {
//   // Ensure framework services are initialized before setting up system flags
//   WidgetsFlutterBinding.ensureInitialized();
  
//   await Supabase.initialize(
//     url: 'https://yxqyrjyzxitrgkhgauli.supabase.co',
//     anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4cXlyanl6eGl0cmdraGdhdWxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0NzM2OTYsImV4cCI6MjA5NTA0OTY5Nn0.smtNEPQrag9yETZXdA2UqqCmxu_fjmGG8K4Vbot2O-w',
//   );
//   // Set up transparent status bar and orientation configurations from your theme
//   AppTheme.setSystemUI();
  
//   runApp(const UniVerseApp());
// }

// class UniVerseApp extends StatelessWidget {
//   const UniVerseApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp.router(
//       title: 'UniVerse',
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.dark, // Applies your warm dark academia design system
//       routerConfig: AppRouter.router, // Use GoRouter for navigation and auth flow management
//     );
//   }
// }

// class MainNavigationShell extends StatefulWidget {
//   const MainNavigationShell({super.key});

//   @override
//   State<MainNavigationShell> createState() => _MainNavigationShellState();
// }

// class _MainNavigationShellState extends State<MainNavigationShell> {
//   int _currentIndex = 0;

//   // Initializing mock screens for state and feature validation
//   final List<Widget> _screens = [
//     const StudentDashboardMock(),
//     const AIAssistantMock(),
//     const ProfileRoleMock(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: IndexedStack(
//         index: _currentIndex,
//         children: _screens,
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: (index) {
//           setState(() {
//             _currentIndex = index;
//           });
//         },
//         backgroundColor: AppColors.bgPrimary,
//         selectedItemColor: const Color(0xFFFF7A00), // Warm Orange Accent
//         unselectedItemColor: const Color(0xFF6E7278), // Secondary Text
//         type: BottomNavigationBarType.fixed,
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.dashboard_rounded),
//             label: 'Dashboard',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.psychology_rounded),
//             label: 'AI Assistant',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.person_outline_rounded),
//             label: 'Profile',
//           ),
//         ],
//       ),
//     );
//   }
// }

// // --- INTERACTIVE MOCK 1: STUDENT DASHBOARD ---
// class StudentDashboardMock extends StatefulWidget {
//   const StudentDashboardMock({super.key});

//   @override
//   State<StudentDashboardMock> createState() => _StudentDashboardMockState();
// }

// class _StudentDashboardMockState extends State<StudentDashboardMock> {
//   bool _isAttendingAlgorithmClass = false;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('UniVerse Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
//         backgroundColor: AppColors.bgPrimary,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Welcome Back, Student',
//               style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Leading University | Batch 62, Section G',
//               style: TextStyle(fontSize: 14, color: Colors.grey[400]),
//             ),
//             const SizedBox(height: 24),
//             // Mock Academic Card
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1A1A1C), // AppColors.bgCard fallback
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: const Color(0xFF2A2C30)),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Next Up: CSE-3240 (Project I)',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFF7A00)),
//                   ),
//                   const SizedBox(height: 6),
//                   const Text('Advisor: Kazi Md. Jahid Hasan', style: TextStyle(color: Colors.white70)),
//                   const SizedBox(height: 16),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text('Mark Attendance for today:', style: TextStyle(color: Colors.white)),
//                       Switch(
//                         value: _isAttendingAlgorithmClass,
//                         activeColor: const Color(0xFFFF7A00),
//                         onChanged: (value) {
//                           setState(() {
//                             _isAttendingAlgorithmClass = value;
//                           });
//                         },
//                       ),
//                     ],
//                   ),
//                   Text(
//                     _isAttendingAlgorithmClass ? 'Status: Marked Present' : 'Status: Absent / Not Checked',
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: _isAttendingAlgorithmClass ? Colors.green : Colors.redAccent,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // --- INTERACTIVE MOCK 2: AI ASSISTANT CHAT SYSTEM ---
// class AIAssistantMock extends StatefulWidget {
//   const AIAssistantMock({super.key});

//   @override
//   State<AIAssistantMock> createState() => _AIAssistantMockState();
// }

// class _AIAssistantMockState extends State<AIAssistantMock> {
//   final TextEditingController _chatController = TextEditingController();
//   final List<Map<String, String>> _messages = [
//     {'sender': 'ai', 'text': 'Hello! I am your UniVerse Campus Companion. How can I help with your routine or grades today?'}
//   ];

//   void _sendMessage() {
//     if (_chatController.text.trim().isEmpty) return;
    
//     setState(() {
//       _messages.add({'sender': 'user', 'text': _chatController.text});
//       // Simulate an automated contextual response
//       _messages.add({
//         'sender': 'ai', 
//         'text': 'Received: "${_chatController.text}". RAG and Gemini backend integration will process this prompt soon!'
//       });
//       _chatController.clear();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('UniVerse AI Assistant'),
//         backgroundColor: AppColors.bgPrimary,
//         elevation: 0,
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final msg = _messages[index];
//                 final isUser = msg['sender'] == 'user';
//                 return Align(
//                   alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(vertical: 6),
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: isUser ? const Color(0xFFFF7A00) : const Color(0xFF1A1A1C),
//                       borderRadius: BorderRadius.circular(12),
//                       border: isUser ? null : Border.all(color: const Color(0xFF2A2C30)),
//                     ),
//                     constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
//                     child: Text(
//                       msg['text']!,
//                       style: TextStyle(color: isUser ? Colors.black : Colors.white),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _chatController,
//                     style: const TextStyle(color: Colors.white),
//                     decoration: InputDecoration(
//                       hintText: 'Ask about routines, class cancellations...',
//                       hintStyle: const TextStyle(color: Colors.grey),
//                       filled: true,
//                       fillColor: const Color(0xFF1A1A1C),
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24),
//                         borderSide: const BorderSide(color: Color(0xFF2A2C30)),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24),
//                         borderSide: const BorderSide(color: Color(0xFFFF7A00)),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 IconButton(
//                   icon: const Icon(Icons.send_rounded, color: Color(0xFFFF7A00)),
//                   onPressed: _sendMessage,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // --- INTERACTIVE MOCK 3: PROFILE & ROLE VALIDATOR ---
// class ProfileRoleMock extends StatelessWidget {
//   const ProfileRoleMock({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Account Profile'),
//         backgroundColor: AppColors.bgPrimary,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             const CircleAvatar(
//               radius: 40,
//               backgroundColor: Color(0xFF1A1A1C),
//               child: const Icon(Icons.person, size: 48, color: Color(0xFFFF7A00)),
//             ),
//             const SizedBox(height: 16),
//             const Text('Team Sherlocked', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
//             const SizedBox(height: 4),
//             Text('Fahmid | Swadheen | Ratul', style: TextStyle(color: Colors.grey[400])),
//             const SizedBox(height: 32),
//             const Align(
//               alignment: Alignment.centerLeft,
//               child: Text('Actor Shell Access Verification:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
//             ),
//             const SizedBox(height: 12),
//             _buildRoleTile('Student Actor Context', true),
//             _buildRoleTile('Teacher Actor Context', false),
//             _buildRoleTile('Admin Actor Context', false),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildRoleTile(String roleName, bool isCurrent) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 6),
//       decoration: BoxDecoration(
//         color: const Color(0xFF1A1A1C),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: isCurrent ? const Color(0xFFFF7A00) : const Color(0xFF2A2C30)),
//       ),
//       child: ListTile(
//         title: Text(roleName, style: const TextStyle(color: Colors.white, fontSize: 14)),
//         trailing: isCurrent 
//           ? const Icon(Icons.check_circle, color: Color(0xFFFF7A00)) 
//           : const Icon(Icons.radio_button_off, color: Colors.grey),
//       ),
//     );
//   }
// }