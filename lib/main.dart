import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'providers/wallet_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'services/api_service.dart';
import 'screens/referral_screens.dart';

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
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/deposit', builder: (context, state) => const DepositScreen()),
      GoRoute(path: '/withdraw', builder: (context, state) => const WithdrawScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/users', builder: (context, state) => const UserManagementScreen()),
      GoRoute(path: '/admin/withdrawals', builder: (context, state) => const PendingWithdrawalsScreen()),
      
      // Referral Routes
      GoRoute(path: '/referrals', builder: (context, state) => const ReferralDashboardScreen()),
      GoRoute(path: '/referrals/team', builder: (context, state) => const TeamMembersScreen()),
      GoRoute(path: '/referrals/earnings', builder: (context, state) => const ReferralEarningsScreen()),
      GoRoute(path: '/referrals/leaderboard', builder: (context, state) => const LeaderboardScreen()),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;

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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _transPassCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    
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

      // Check referral code validity before registering
      if (invite.isNotEmpty) {
        final isValid = await ref.read(authProvider.notifier).checkReferralCode(invite);
        if (!isValid) {
          _showError('Invalid referral code. Please check and try again.');
          return;
        }
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.withValues(alpha: 0.05), Colors.black],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 60),
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
        child: Padding(
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
                  if (context.mounted) context.go('/');
                },
                child: const Text('Skip for now', style: TextStyle(color: Colors.greenAccent)),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
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
    final activityAsync = ref.watch(activityProvider(userId));

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
          ref.invalidate(transactionsProvider(userId));
          ref.invalidate(withdrawalsProvider(userId));
          ref.invalidate(balanceProvider(userId));
          await ref.read(activityProvider(userId).future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              balanceAsync.when(
                data: (balance) => _PortfolioCard(balance: balance, isAdmin: auth.isAdmin),
                loading: () => _PortfolioCard(balance: "...", isLoading: true, isAdmin: auth.isAdmin),
                error: (e, s) => _PortfolioCard(balance: "0.00", isAdmin: auth.isAdmin),
              ),
              const SizedBox(height: 25),
              _AffiliatePromotionCard(onTap: () => context.push('/referrals')),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: _ActionTile(icon: Icons.add_circle_outline, label: 'Deposit', color: Colors.greenAccent, onTap: () => context.push('/deposit'))),
                  const SizedBox(width: 15),
                  Expanded(child: _ActionTile(icon: Icons.arrow_circle_up_outlined, label: 'Withdraw', color: Colors.orangeAccent, onTap: () => context.push('/withdraw'))),
                ],
              ),
              const SizedBox(height: 40),
              const _RecentActivityHeader(),
              const SizedBox(height: 20),
              activityAsync.when(
                data: (items) => _ActivityList(items: items),
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                )),
                error: (e, s) => _ErrorState(
                  message: 'Failed to load activity',
                  onRetry: () => ref.invalidate(activityProvider(userId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AffiliatePromotionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AffiliatePromotionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          gradient: LinearGradient(
            colors: [Colors.blueAccent.withValues(alpha: 0.05), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.people_outline, color: Colors.blueAccent),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Affiliate Program', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Earn up to 23% in commissions', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white54)),
            TextButton.icon(
              onPressed: onRetry, 
              icon: const Icon(Icons.refresh, size: 18), 
              label: const Text('Try Again'),
              style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
            ),
          ],
        ),
      ),
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

class _ActivityList extends StatelessWidget {
  final List<dynamic> items;
  const _ActivityList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No activity yet", style: TextStyle(color: Colors.white38)),
      ));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final bool isDeposit = item['type'] == 'deposit';
        
        double amount = 0;
        try {
          amount = double.parse(item['amount'].toString()) / 1000000;
        } catch (_) {}
        
        String token = item['token'] ?? 'USDT';
        String status = item['status'] ?? 'pending';
        // Map 'swept' to 'confirmed' for the UI
        if (status == 'swept') status = 'confirmed';
        
        String hash = item['txHash']?.toString() ?? "";
        String displayHash = "Pending...";
        if (hash.isNotEmpty) {
          displayHash = hash.length > 10 ? "${hash.substring(0, 10)}..." : hash;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (isDeposit ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                child: Icon(
                  isDeposit ? Icons.call_received : Icons.call_made, 
                  color: isDeposit ? Colors.greenAccent : Colors.orangeAccent, 
                  size: 18
                ),
              ),
              title: Text(
                isDeposit ? '$token Received' : '$token Withdrawal', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
              ),
              subtitle: Text(displayHash, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(2)}', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: isDeposit ? Colors.greenAccent : Colors.orangeAccent
                    )
                  ),
                  Text(
                    status.toUpperCase(), 
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      color: status == 'confirmed' || status == 'completed' ? Colors.greenAccent : Colors.orangeAccent
                    )
                  ),
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
  String selectedNetwork = 'Polygon Mainnet';
  String selectedToken = 'USDT';
  
  final List<String> networks = ['Ethereum (ERC20)', 'Polygon Mainnet'];
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
          Expanded(child: Text('Only send $selectedToken to this address via $selectedNetwork. Using unsupported networks will result in permanent loss.', style: const TextStyle(fontSize: 12, color: Colors.orangeAccent))),
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
  
  static const _storage = FlutterSecureStorage();
  
  String selectedNetwork = 'Polygon Mainnet';
  String selectedToken = 'USDT';
  bool _isLoading = false;
  Timer? _refreshTimer;
  
  final Map<String, int> networkToChainId = {
    'Ethereum (ERC20)': 1,
    'Polygon Mainnet': 137,
  };

  @override
  void initState() {
    super.initState();
    _loadSavedDetails();
    // Auto-refresh withdrawal status every 10 seconds while on this screen
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        final userId = ref.read(authProvider).userId;
        if (userId != null) {
          ref.invalidate(withdrawalsProvider(userId));
          ref.invalidate(balanceProvider(userId));
        }
      }
    });
  }

  Future<void> _loadSavedDetails() async {
    final savedAddress = await _storage.read(key: 'last_withdrawal_address');
    final savedPass = await _storage.read(key: 'last_transaction_password');
    if (mounted) {
      if (savedAddress != null) _addressCtrl.text = savedAddress;
      if (savedPass != null) _transPassCtrl.text = savedPass;
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _amountCtrl.dispose();
    _transPassCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleWithdraw(double available) async {
    FocusManager.instance.primaryFocus?.unfocus();
    
    String addressInput = _addressCtrl.text.trim().replaceAll(' ', '');
    final amountStr = _amountCtrl.text.trim();
    final transPass = _transPassCtrl.text.trim();

    if (addressInput.isEmpty || amountStr.isEmpty || transPass.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    final amount = double.tryParse(amountStr) ?? 0;

    if (amount < 2.0) {
      _showError(r'Minimum withdrawal amount is $2.00');
      return;
    }

    if (amount > available) {
      _showError('Insufficient balance.');
      return;
    }

    // Auto-fix address formatting
    String cleanAddress = addressInput;
    if (cleanAddress.startsWith('I') || cleanAddress.startsWith('l')) {
        if (cleanAddress.length >= 40 && !cleanAddress.startsWith('0x')) {
             cleanAddress = '0x${cleanAddress.substring(1)}';
        }
    }
    if (!cleanAddress.startsWith('0x')) cleanAddress = '0x$cleanAddress';

    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(cleanAddress)) {
      _showError('Invalid Wallet Address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = ref.read(authProvider).userId!;
      final chainId = networkToChainId[selectedNetwork] ?? 137;

      await ref.read(apiServiceProvider).requestWithdrawal({
        'userId': userId,
        'toAddress': cleanAddress,
        'amount': (amount * 1000000).toInt().toString(),
        'chainId': chainId,
        'network': selectedNetwork,
        'token': selectedToken,
        'transactionPassword': transPass,
      });
      
      // Save details for next time
      await _storage.write(key: 'last_withdrawal_address', value: cleanAddress);
      await _storage.write(key: 'last_transaction_password', value: transPass);
      
      if (mounted) {
        _showSuccess('Withdrawal Request Submitted');
        _amountCtrl.clear();
        // Keep address and password but clear amount
        ref.invalidate(withdrawalsProvider(userId));
        ref.invalidate(balanceProvider(userId));
        ref.invalidate(activityProvider(userId));
      }
    } catch (e) {
      String errorMsg = "Withdrawal failed";
      if (e is DioException) {
        final data = e.response?.data;
        if (data != null) {
          errorMsg = data.toString()
              .replaceAll('"', '')
              .replaceFirst(RegExp(r'\[CONVEX.*?\]\s*'), '')
              .replaceFirst('Uncaught Error: ', '')
              .trim();
        } else {
          errorMsg = e.message ?? "Connection error";
        }
      }
      if (mounted) _showError(errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating)
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.greenAccent, behavior: SnackBarBehavior.floating)
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.userId ?? "";
    final balanceAsync = ref.watch(balanceProvider(userId));
    final withdrawalsAsync = ref.watch(withdrawalsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('WITHDRAW'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Network & Asset'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildModernDropdown(
                    label: 'Select Token',
                    value: selectedToken,
                    items: ['USDT', 'USDC'],
                    onChanged: (v) => setState(() => selectedToken = v!),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10)),
                  _buildModernDropdown(
                    label: 'Target Network',
                    value: selectedNetwork,
                    items: networkToChainId.keys.toList(),
                    onChanged: (v) => setState(() => selectedNetwork = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Withdrawal Details'),
            const SizedBox(height: 12),
            _buildAddressInput(),
            const SizedBox(height: 16),
            
            balanceAsync.when(
              data: (balance) => _buildAmountInput((double.tryParse(balance) ?? 0) / 1000000),
              loading: () => _buildAmountInput(0.0, isLoading: true),
              error: (e, s) => _buildAmountInput(0.0),
            ),
            
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 40),
            
            balanceAsync.when(
              data: (balance) => _buildSummary((double.tryParse(balance) ?? 0) / 1000000),
              loading: () => _buildSummary(0.0),
              error: (e, s) => _buildSummary(0.0),
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: (_isLoading || (double.tryParse(_amountCtrl.text) ?? 0) < 2.0) ? null : () {
                  final bal = balanceAsync.asData?.value ?? "0";
                  _handleWithdraw((double.tryParse(bal) ?? 0) / 1000000);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text('Withdraw $selectedToken', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Withdrawal Process & History'),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.greenAccent),
                  onPressed: () {
                    ref.invalidate(withdrawalsProvider(userId));
                    ref.invalidate(balanceProvider(userId));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            withdrawalsAsync.when(
              data: (withdrawals) => _WithdrawalHistoryList(withdrawals: withdrawals),
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Colors.greenAccent),
              )),
              error: (e, s) => const Text('Failed to load history', style: TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5));
  }

  Widget _buildModernDropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          dropdownColor: const Color(0xFF2A2A2A),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.greenAccent),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildAddressInput() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: _addressCtrl,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Recipient Address (0x...)',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Colors.greenAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAmountInput(double displayBalance, {bool isLoading = false}) {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final isInvalid = _amountCtrl.text.isNotEmpty && amount < 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), 
            borderRadius: BorderRadius.circular(15),
            border: isInvalid ? Border.all(color: Colors.redAccent.withValues(alpha: 0.5)) : null,
          ),
          child: TextField(
            controller: _amountCtrl,
            onChanged: (v) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.toll_outlined, color: Colors.greenAccent),
              suffixIcon: TextButton(
                onPressed: () => setState(() => _amountCtrl.text = displayBalance.toStringAsFixed(2)),
                child: const Text('MAX', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (isInvalid)
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 6),
            child: Text("Amount must be at least \$2.00", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(r'Min: $2.00', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Text('Available ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  isLoading 
                    ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('\$${displayBalance.toStringAsFixed(2)} $selectedToken', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: _transPassCtrl,
        obscureText: true,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Transaction Password',
          hintStyle: TextStyle(color: Colors.white38),
          prefixIcon: Icon(Icons.lock_outline, color: Colors.greenAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSummary(double available) {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    const fee = 0.25;
    final amountToReceive = amount > fee ? amount - fee : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Total to Deduct', '${amount.toStringAsFixed(2)} $selectedToken', isBold: true),
          const SizedBox(height: 8),
          _buildSummaryRow('Withdrawal Fee', '0.25 $selectedToken'),
          const Divider(color: Colors.white10, height: 20),
          _buildSummaryRow('You will Receive', '${amountToReceive.toStringAsFixed(2)} $selectedToken', isBold: true, color: Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value, style: TextStyle(color: color ?? (isBold ? Colors.white : Colors.white), fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

class _WithdrawalHistoryList extends StatelessWidget {
  final List<dynamic> withdrawals;
  const _WithdrawalHistoryList({required this.withdrawals});

  @override
  Widget build(BuildContext context) {
    if (withdrawals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Column(
          children: [
            Icon(Icons.history, color: Colors.white12, size: 40),
            SizedBox(height: 10),
            Text("No withdrawals yet", style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    // Sort by createdAt desc
    final sorted = List.from(withdrawals);
    sorted.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));

    return Column(
      children: sorted.map((w) => _WithdrawalProcessItem(w: w)).toList(),
    );
  }
}

class _WithdrawalProcessItem extends StatelessWidget {
  final dynamic w;
  const _WithdrawalProcessItem({required this.w});

  @override
  Widget build(BuildContext context) {
    double amount = 0;
    try { amount = double.parse(w['amount'].toString()) / 1000000; } catch (_) {}
    
    String status = w['status'] ?? 'pending';
    String token = w['token'] ?? 'USDT';
    String network = w['network'] ?? 'Unknown';
    String txHash = w['txHash']?.toString() ?? "";
    
    DateTime date = DateTime.fromMillisecondsSinceEpoch(w['createdAt'] ?? 0);
    String dateStr = "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$token Withdrawal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('$network • $dateStr', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              Text('-${amount.toStringAsFixed(2)}', style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: status == 'failed' ? Colors.redAccent : Colors.orangeAccent,
                decoration: status == 'failed' ? TextDecoration.lineThrough : null,
              )),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatusStepper(status),
          if (status == 'processing')
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                  SizedBox(width: 8),
                  Text("Broadcasting to Blockchain...", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (status == 'failed') 
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.redAccent, size: 12),
                  SizedBox(width: 4),
                  Text("Failed & Balance Refunded", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          if (txHash.isNotEmpty && txHash.length >= 16) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("TX Hash: ${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 8)}", style: const TextStyle(fontSize: 10, color: Colors.white24, fontFamily: 'monospace')),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: txHash));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hash copied')));
                  },
                  child: const Icon(Icons.copy, size: 14, color: Colors.greenAccent),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusStepper(String status) {
    int currentStep = 0;
    if (status == 'pending') currentStep = 1;
    if (status == 'processing') currentStep = 2;
    if (status == 'completed') currentStep = 3;
    if (status == 'failed') currentStep = -1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStepIndicator('Requested', currentStep >= 1, isFailed: currentStep == -1),
        _buildStepLine(currentStep >= 2, isFailed: currentStep == -1),
        _buildStepIndicator('Verifying', currentStep >= 2, isFailed: currentStep == -1),
        _buildStepLine(currentStep >= 3, isFailed: currentStep == -1),
        _buildStepIndicator('On-Chain', currentStep >= 3, isFailed: currentStep == -1),
      ],
    );
  }

  Widget _buildStepIndicator(String label, bool isActive, {bool isFailed = false}) {
    Color color = isActive ? Colors.greenAccent : Colors.white10;
    if (isFailed) color = Colors.redAccent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFailed ? Icons.close : (isActive ? Icons.check_circle : Icons.circle), 
            color: color, 
            size: 14
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildStepLine(bool isActive, {bool isFailed = false}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
        decoration: BoxDecoration(
          color: isFailed ? Colors.redAccent.withValues(alpha: 0.1) : (isActive ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white10),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
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
            if (context.mounted) context.go('/login');
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
                    _buildStatCard('Pending Withdrawals', '${stats['pendingWithdrawals']}', Colors.orangeAccent),
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
              const SizedBox(height: 12),
              ListTile(
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),                leading: const Icon(Icons.outbox_outlined, color: Colors.orangeAccent),
                title: const Text('Withdrawal Management'),
                subtitle: const Text('Process pending requests'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.push('/admin/withdrawals'),
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

class PendingWithdrawalsScreen extends ConsumerStatefulWidget {
  const PendingWithdrawalsScreen({super.key});
  @override
  ConsumerState<PendingWithdrawalsScreen> createState() => _PendingWithdrawalsScreenState();
}

class _PendingWithdrawalsScreenState extends ConsumerState<PendingWithdrawalsScreen> {
  bool _isProcessingAll = false;

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingWithdrawalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PENDING WITHDRAWALS'),
        actions: [
          if (pendingAsync.hasValue && pendingAsync.value!.isNotEmpty)
            IconButton(
              icon: _isProcessingAll 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bolt, color: Colors.orangeAccent),
              tooltip: 'Process All',
              onPressed: _isProcessingAll ? null : () async {
                setState(() => _isProcessingAll = true);
                await ref.read(adminNotifierProvider.notifier).processAllWithdrawals();
                if (mounted) {
                  setState(() => _isProcessingAll = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Processing started for all requests')));
                }
              },
            ),
        ],
      ),
      body: pendingAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No pending withdrawals', style: TextStyle(color: Colors.white38)));
          }
          return ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final w = list[i];
              double amount = 0;
              try { amount = double.parse(w['amount'].toString()) / 1000000; } catch (_) {}
              
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  title: Text('${amount.toStringAsFixed(2)} ${w['token']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  subtitle: Text('To: ${w['toAddress'].substring(0, 10)}...\nNet: ${w['network']}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: () async {
                      await ref.read(adminNotifierProvider.notifier).processWithdrawal(w['_id']);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal processing...')));
                      }
                    },
                    child: const Text('PROCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
