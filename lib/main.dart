import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'providers/wallet_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CryptoVaultApp()));
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);
  
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/level', builder: (context, state) => const LevelScreen()),
          GoRoute(path: '/bike', builder: (context, state) => const BikeScreen()),
          GoRoute(path: '/team', builder: (context, state) => const TeamScreen()),
          GoRoute(path: '/my', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/deposit', builder: (context, state) => const DepositScreen()),
          GoRoute(path: '/withdraw', builder: (context, state) => const WithdrawScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/users', builder: (context, state) => const UserManagementScreen()),
        ],
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;

      if (!auth.sessionRestored) return null;

      final isLoggingIn = path == '/login';
      final isVerifying = path == '/verify-email';
      final isAdminPage = path.startsWith('/admin');

      if (auth.userId == null) {
        return isLoggingIn ? null : '/login';
      }

      if (isAdminPage && !auth.isAdmin) return '/';

      if (isLoggingIn || isVerifying) return '/';
      
      return null;
    },
  );
});

class CryptoVaultApp extends ConsumerWidget {
  const CryptoVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CryptoVault Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F0F0F),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF141414),
          indicatorColor: Color(0xFF00C853),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF141414),
          indicatorColor: Color(0xFF00C853),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      routerConfig: router,
    );
  }
}

// --- Replaceable Carousel Data ---
// To swap products, just edit this list. Each entry: title, subtitle, imageAsset/URL, tag.
final List<Map<String, String>> carouselProducts = [
  {
    'title': 'Crypto Savings Vault',
    'subtitle': 'Earn up to 8% APY on stablecoins',
    'image': 'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=600&h=300&fit=crop',
    'tag': 'Featured',
  },
  {
    'title': 'Instant Cross-Chain Bridge',
    'subtitle': 'Move assets across 10+ networks in seconds',
    'image': 'https://images.unsplash.com/photo-1621761191319-c6fb62004040?w=600&h=300&fit=crop',
    'tag': 'New',
  },
  {
    'title': 'DeFi Yield Optimizer',
    'subtitle': 'Auto-compound returns with one click',
    'image': 'https://images.unsplash.com/photo-1642790106117-e829e14a795f?w=600&h=300&fit=crop',
    'tag': 'Popular',
  },
];

// --- Responsive Main Shell ---
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _navItems = [
    ('/', Icons.home_rounded, 'Home'),
    ('/level', Icons.auto_graph_rounded, 'Level'),
    ('/bike', Icons.directions_bike_rounded, 'Bike'),
    ('/team', Icons.people_rounded, 'Team'),
    ('/my', Icons.person_rounded, 'My'),
  ];

  int _resolveIndex(String path) {
    for (int i = 0; i < _navItems.length; i++) {
      if (path == _navItems[i].$1) return i;
    }
    if (path == '/settings') return 4;
    if (path.startsWith('/admin')) return 4;
    if (path == '/deposit' || path == '/withdraw') return 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _resolveIndex(location);
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final colorScheme = Theme.of(context).colorScheme;

    if (isDesktop) {
      return Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => context.go(_navItems[i].$1),
            labelType: NavigationRailLabelType.all,
            minExtendedWidth: 200,
            groupAlignment: -0.3,
            backgroundColor: const Color(0xFF0A0A0A),
            indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.shield_rounded, size: 32, color: colorScheme.primary),
            ),
            destinations: _navItems.map((item) => NavigationRailDestination(
              icon: Icon(item.$2),
              selectedIcon: Icon(item.$2, color: colorScheme.primary),
              label: Text(item.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
            )).toList(),
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(child: child),
        ],
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(_navItems[i].$1),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0F0F0F),
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Icon(item.$2),
            activeIcon: Icon(item.$2, color: colorScheme.primary),
            label: item.$3,
          )).toList(),
        ),
      ),
    );
  }
}

// --- Placeholder screens for Level, Bike, Team ---
class LevelScreen extends StatelessWidget {
  const LevelScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LEVEL PROGRESS')),
      body: const Center(child: Text('Level & progress tracking coming soon', style: TextStyle(color: Colors.white54))),
    );
  }
}

class BikeScreen extends StatelessWidget {
  const BikeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BIKE TRACKER')),
      body: const Center(child: Text('Bike tracking features coming soon', style: TextStyle(color: Colors.white54))),
    );
  }
}

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEAM HUB')),
      body: const Center(child: Text('Team management coming soon', style: TextStyle(color: Colors.white54))),
    );
  }
}

// --- Auth / Login & Register ---
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _transPassCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  
  bool _isLogin = true;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _obscureTransPass = true;

  Future<void> _handleSubmit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final transPass = _transPassCtrl.text.trim();
    final invite = _inviteCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showError('Please fill in required fields');
      return;
    }

    bool success;
    if (_isLogin) {
      success = await ref.read(authProvider.notifier).login(email, pass);
    } else {
      final confirmPass = _confirmPassCtrl.text.trim();
      if (pass != confirmPass) {
        _showError('Passwords do not match');
        return;
      }
      if (transPass.isEmpty) {
        _showError('Please set a transaction password');
        return;
      }
      success = await ref.read(authProvider.notifier).register(
        email: email,
        password: pass,
        transactionPassword: transPass,
        invitationCode: invite.isEmpty ? null : invite,
      );
    }

    if (success && mounted) {
      context.go('/');
    } else if (mounted) {
      final error = ref.read(authProvider).error ?? 'Authentication failed';
      _showError(error);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 900;
    final bool isTablet = size.width > 600;
    final double horizontalPadding = isDesktop ? size.width * 0.25 : isTablet ? size.width * 0.15 : 24.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.withValues(alpha: 0.05), Colors.black],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 60),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_rounded, size: 70, color: Color(0xFF00C853)),
                  const SizedBox(height: 15),
                  Text(
                    'CryptoVault Pro',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  
                  _buildTextField('Email Address', Icons.email_outlined, _emailCtrl),
                  const SizedBox(height: 15),
                  _buildTextField(
                    'Password', 
                    Icons.lock_outline, 
                    _passCtrl, 
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  
                  if (!_isLogin) ...[
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Confirm Password', 
                      Icons.lock_reset, 
                      _confirmPassCtrl, 
                      obscureText: _obscureConfirmPass,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      'Transaction Password', 
                      Icons.enhanced_encryption_outlined, 
                      _transPassCtrl, 
                      obscureText: _obscureTransPass,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureTransPass ? Icons.visibility_off : Icons.visibility, color: Colors.greenAccent),
                        onPressed: () => setState(() => _obscureTransPass = !_obscureTransPass),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField('Invitation Code (Optional)', Icons.card_giftcard, _inviteCtrl),
                  ],
                  
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(_isLogin ? 'Access Wallet' : 'Create Account', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? "Don't have an account? Register" : "Already have an account? Login", style: const TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, IconData icon, TextEditingController ctrl, {bool obscureText = false, Widget? suffixIcon}) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}

// --- Email Verification ---
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.greenAccent),
              const SizedBox(height: 20),
              const Text('Verify Your Email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Text(
                'A verification link has been sent to ${auth.email ?? "your email"}. Please click it to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => ref.read(authProvider.notifier).verifyEmail(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('I\'ve Verified (Simulate)'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  ref.read(authProvider.notifier).skipVerification();
                  context.go('/');
                },
                child: const Text('Skip for now', style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
                child: const Text('Back to Login', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Dashboard ---
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).refreshUser());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    
    final balanceAsync = ref.watch(balanceProvider(userId));
    final txsAsync = ref.watch(transactionsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('PORTFOLIO'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshUser();
          await ref.refresh(transactionsProvider(userId).future);
          ref.refresh(balanceProvider(userId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const _ImageCarousel(),
              const SizedBox(height: 24),
              balanceAsync.when(
                data: (balance) => _PortfolioCard(balance: balance, isAdmin: auth.isAdmin),
                loading: () => _PortfolioCard(balance: "...", isLoading: true, isAdmin: auth.isAdmin),
                error: (e, s) => _PortfolioCard(balance: "0.00", isAdmin: auth.isAdmin),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(child: _ActionTile(icon: Icons.add_circle_outline, label: 'Deposit', color: Colors.greenAccent, onTap: () => context.push('/deposit'))),
                  const SizedBox(width: 15),
                  Expanded(child: _ActionTile(icon: Icons.arrow_circle_up_outlined, label: 'Withdraw', color: Colors.orangeAccent, onTap: () => context.push('/withdraw'))),
                ],
              ),
              const SizedBox(height: 32),
              const _VideoExplainer(),
              const SizedBox(height: 32),
              const _OurProductSection(),
              const SizedBox(height: 40),
              const _RecentActivityHeader(),
              const SizedBox(height: 20),
              txsAsync.when(
                data: (txs) => _TransactionList(transactions: txs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Failed to load transactions')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Image Carousel (easily replaceable via carouselProducts list at top) ---
class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel();

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final _pageCtrl = PageController(viewportFraction: 0.92);
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageCtrl.hasClients) {
        final next = (_current + 1) % carouselProducts.length;
        _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: carouselProducts.length,
            itemBuilder: (context, i) {
              final p = carouselProducts[i];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(p['image']!),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(p['tag'] ?? '', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                      const SizedBox(height: 6),
                      Text(p['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(p['subtitle']!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(carouselProducts.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _current == i ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _current == i ? const Color(0xFF00C853) : Colors.white24,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// --- Video Explainer Section ---
class _VideoExplainer extends StatelessWidget {
  const _VideoExplainer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.play_circle_fill, color: Color(0xFF00C853), size: 22),
            SizedBox(width: 8),
            Text('How It Works', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF0D0D0D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill, size: 64, color: Color(0xFF00C853)),
                    const SizedBox(height: 12),
                    Text('Watch: How CryptoVault Protects Your Assets',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text('Tap to watch on YouTube', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                    child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Our Product Section (mirrors the video content with our company) ---
class _OurProductSection extends StatelessWidget {
  const _OurProductSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0D0D0D),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFF00C853), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('How CryptoVault Helps', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _benefitRow(Icons.verified_user_rounded, 'Military-grade encryption keeps your funds safe at all times.'),
          const SizedBox(height: 10),
          _benefitRow(Icons.swap_horiz_rounded, 'Instant deposits and withdrawals across all major blockchain networks.'),
          const SizedBox(height: 10),
          _benefitRow(Icons.trending_up_rounded, 'Real-time balance tracking with automated sweep consolidation.'),
          const SizedBox(height: 10),
          _benefitRow(Icons.support_agent_rounded, '24/7 monitoring and support — our team never sleeps on security.'),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [const Color(0xFF00C853).withValues(alpha: 0.08), const Color(0xFF00C853).withValues(alpha: 0.02)],
              ),
              border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF00C853), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trusted by 10,000+ users worldwide. Start protecting your crypto today.',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00C853)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.3)),
        ),
      ],
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final String balance;
  final bool isLoading;
  final bool isAdmin;
  const _PortfolioCard({required this.balance, this.isLoading = false, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    double displayBalance = 0;
    try {
      displayBalance = double.parse(balance) / 1000000;
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF00C853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Stablecoin Balance', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.greenAccent, size: 14),
                      SizedBox(width: 4),
                      Text('ADMIN', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          isLoading 
            ? const SizedBox(height: 45, width: 45, child: CircularProgressIndicator(color: Colors.white))
            : Text('\$${displayBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Live monitoring active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityHeader extends StatelessWidget {
  const _RecentActivityHeader();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(color: Colors.greenAccent))),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<dynamic> transactions;
  const _TransactionList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No transactions yet", style: TextStyle(color: Colors.white38)),
      ));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, i) {
        final tx = transactions[i];
        double amount = double.parse(tx['amount']) / 1000000;
        String token = tx['token'] ?? 'USDT';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                child: const Icon(Icons.call_received, color: Colors.greenAccent, size: 18),
              ),
              title: Text('$token Received (${tx['network']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text("${tx['txHash'].toString().substring(0, 10)}...", style: const TextStyle(fontSize: 12, color: Colors.white54)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  Text(tx['status'], style: TextStyle(fontSize: 10, color: tx['status'] == 'swept' ? Colors.blueAccent : Colors.greenAccent)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- Deposit Screen ---
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});
  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  String selectedNetwork = 'Polygon Amoy';
  String selectedToken = 'USDT';
  
  final List<String> networks = ['Ethereum Sepolia', 'Polygon Amoy', 'BSC Testnet'];
  final List<String> tokens = ['USDT', 'USDC'];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    final walletAsync = ref.watch(walletProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('DEPOSIT ASSETS')),
      body: walletAsync.when(
        data: (wallet) {
          if (wallet == null || wallet['address'] == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }
          return _buildBody(wallet['address']);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(String address) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTokenDropdown(),
          const SizedBox(height: 15),
          _buildNetworkDropdown(),
          const SizedBox(height: 40),
          _buildQRCode(address),
          const SizedBox(height: 40),
          Text('Your Permanent $selectedToken Address', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          _buildAddressDisplay(address),
          const SizedBox(height: 50),
          _buildSecurityNotice(),
        ],
      ),
    );
  }

  Widget _buildTokenDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedToken,
      decoration: InputDecoration(
        labelText: 'Select Token',
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      items: tokens.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => selectedToken = v!),
    );
  }

  Widget _buildNetworkDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: selectedNetwork,
      decoration: InputDecoration(
        labelText: 'Select Network',
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      items: networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
      onChanged: (v) => setState(() => selectedNetwork = v!),
    );
  }

  Widget _buildQRCode(String address) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: QrImageView(data: address, version: QrVersions.auto, size: 200.0),
    );
  }

  Widget _buildAddressDisplay(String address) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Expanded(child: Text(address, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.greenAccent))),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied to clipboard')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text('Only send TESTNET $selectedToken to this address via $selectedNetwork. Using mainnet funds will result in permanent loss.', style: const TextStyle(fontSize: 12, color: Colors.orangeAccent))),
        ],
      ),
    );
  }
}

// --- Withdraw Screen ---
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});
  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _addressCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _transPassCtrl = TextEditingController();
  
  String selectedNetwork = 'Polygon Amoy';
  String selectedToken = 'USDT';
  
  final Map<String, int> networkToChainId = {
    'Ethereum Sepolia': 11155111,
    'Polygon Amoy': 80002,
    'BSC Testnet': 97,
  };

  Future<void> _handleWithdraw() async {
    final address = _addressCtrl.text.trim();
    final amount = _amountCtrl.text.trim();
    final transPass = _transPassCtrl.text.trim();

    if (address.isEmpty || amount.isEmpty || transPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      final userId = ref.read(authProvider).userId!;
      final chainId = networkToChainId[selectedNetwork] ?? 80002;

      await ref.read(apiServiceProvider).requestWithdrawal({
        'userId': userId,
        'toAddress': address,
        'amount': (double.parse(amount) * 1000000).toInt().toString(),
        'chainId': chainId,
        'network': selectedNetwork,
        'token': selectedToken,
        'transactionPassword': transPass,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal Request Submitted')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WITHDRAW ASSETS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTokenDropdown(),
            const SizedBox(height: 20),
            _buildNetworkDropdown(),
            const SizedBox(height: 20),
            _buildInputField('Recipient Address', _addressCtrl, hint: '0x...'),
            const SizedBox(height: 20),
            _buildInputField('Amount', _amountCtrl, suffix: selectedToken, keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            _buildInputField('Transaction Password', _transPassCtrl, obscureText: true, hint: 'Required for security'),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _handleWithdraw,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: Text('Confirm $selectedToken Withdrawal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Asset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedToken,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
          items: ['USDT', 'USDC'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => selectedToken = v!),
        ),
      ],
    );
  }

  Widget _buildNetworkDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: selectedNetwork,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
          items: networkToChainId.keys.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) => setState(() => selectedNetwork = v!),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, {String? hint, String? suffix, TextInputType? keyboardType, bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            suffixText: suffix,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

// --- Settings ---
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).refreshUser());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.greenAccent),
            tooltip: 'Refresh Status',
            onPressed: () async {
              await ref.read(authProvider.notifier).refreshUser();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status Refreshed')));
            },
          )
        ],
      ),
      body: ListView(
        children: [
          _buildSettingsTile(Icons.person_outline, 'Profile', auth.email ?? 'Not logged in'),
          _buildSettingsTile(
            Icons.security, 
            'Security & Role', 
            'Current Role: ${auth.role?.toUpperCase() ?? "USER"}',
            trailing: auth.isAdmin ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(5)),
              child: const Text('ADMIN', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
            ) : null,
          ),
          if (auth.isAdmin)
            _buildSettingsTile(Icons.admin_panel_settings_outlined, 'Admin Dashboard', 'Manage users and system', 
                onTap: () => context.push('/admin')),
          const Divider(height: 40, color: Colors.white10),
          _buildSettingsTile(Icons.logout, 'Log Out', null, color: Colors.redAccent, onTap: () {
            ref.read(authProvider.notifier).logout();
            context.go('/login');
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String? subtitle, {Color? color, VoidCallback? onTap, Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.greenAccent),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24) : null),
      onTap: onTap,
    );
  }
}

// --- Admin Dashboard ---
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ADMIN CONSOLE')),
      body: statsAsync.when(
        data: (stats) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  children: [
                    _buildStatCard('Total Deposits', '${stats['depositCount']}', Colors.greenAccent),
                    _buildStatCard('Total Volume', '\$${(stats['totalVolume'] / 1000000).toStringAsFixed(2)}', Colors.orangeAccent),
                    _buildStatCard('Pending Sweeps', '${stats['pendingSweeps']}', Colors.blueAccent),
                    _buildStatCard('Withdrawals', '${stats['withdrawalCount']}', Colors.purpleAccent),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                leading: const Icon(Icons.people_alt_outlined, color: Colors.greenAccent),
                title: const Text('User Management'),
                subtitle: const Text('View users and change roles'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/users'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        error: (e, s) => Center(child: Text('Error loading stats: $e')),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MANAGE USERS')),
      body: usersAsync.when(
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final user = users[i];
            final String currentRole = user['role'] ?? 'user';

            return ListTile(
              title: Text(user['email'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Role: ${currentRole.toUpperCase()}', style: TextStyle(color: currentRole == 'admin' ? Colors.greenAccent : Colors.white54)),
              trailing: DropdownButton<String>(
                value: currentRole,
                underline: const SizedBox(),
                dropdownColor: const Color(0xFF1E1E1E),
                items: ['user', 'admin'].map((role) {
                  return DropdownMenuItem(
                    value: role, 
                    child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.greenAccent))
                  );
                }).toList(),
                onChanged: (newRole) async {
                  if (newRole != null && newRole != currentRole) {
                    await ref.read(adminNotifierProvider.notifier).updateUserRole(user['_id'], newRole);
                    if (user['_id'] == ref.read(authProvider).userId) {
                      await ref.read(authProvider.notifier).refreshUser();
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated ${user['email']} to $newRole')));
                    }
                  }
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
