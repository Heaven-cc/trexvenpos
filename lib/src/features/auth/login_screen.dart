import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _ownerLogin = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: TrexvenSpacing.pagePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and Branding Header
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/trexvenpos_logo.png', height: 56),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Trexven POS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Operational terminal for businesses',
                    style: TextStyle(
                      fontSize: TrexvenFontSize.body,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Login Form Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: TrexvenSpacing.cardPadding,
                  child: Form(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Material(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.06),
                          borderRadius:
                              BorderRadius.circular(TrexvenRadii.card),
                          child: SwitchListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: Text(
                              'Business owner sign-in',
                              style: TextStyle(
                                fontSize: TrexvenFontSize.input,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              _ownerLogin
                                  ? 'Signing in as business owner'
                                  : 'Signing in as employee / cashier',
                              style: TextStyle(
                                fontSize: TrexvenFontSize.caption,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            value: _ownerLogin,
                            onChanged: authState.isLoading
                                ? null
                                : (value) =>
                                    setState(() => _ownerLogin = value),
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final context in authState.contexts)
                          if (authState.employee == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Theme.of(this.context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(TrexvenRadii.card),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.store_outlined,
                                    color: Theme.of(this.context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  title: Text(
                                    (context['business'] as Map)['business_name']
                                        as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: const Text('Restore previous session'),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                  onTap: () => ref
                                      .read(authStateProvider.notifier)
                                      .restoreSession(
                                        businessId:
                                            (context['business'] as Map)['id']
                                                as String,
                                      ),
                                ),
                              ),
                            ),
                        TrexvenTextField(
                          controller: _employeeIdController,
                          enabled: !authState.isLoading,
                          keyboardType: _ownerLogin
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          autocorrect: false,
                          autofillHints: [
                            _ownerLogin
                                ? AutofillHints.email
                                : AutofillHints.username,
                          ],
                          decoration: TrexvenInputDecoration(
                            labelText:
                                _ownerLogin ? 'Owner email' : 'Employee ID',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        TrexvenTextField(
                          controller: _passwordController,
                          gap: 0,
                          enabled: !authState.isLoading,
                          obscureText: _obscurePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.password],
                          decoration: TrexvenInputDecoration(
                            labelText: 'Password / PIN',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (authState.error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(TrexvenRadii.card),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    authState.error!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.w500,
                                      fontSize: TrexvenFontSize.body,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: TrexvenSpacing.buttonHeight,
                          ),
                          child: ElevatedButton(
                            onPressed: authState.isLoading
                                ? null
                                : () {
                                    final auth = ref.read(
                                      authStateProvider.notifier,
                                    );
                                    if (_ownerLogin) {
                                      auth.loginOwner(
                                        _employeeIdController.text,
                                        _passwordController.text,
                                      );
                                    } else {
                                      auth.login(
                                        _employeeIdController.text,
                                        _passwordController.text,
                                      );
                                    }
                                  },
                            style: Theme.of(context).elevatedButtonTheme.style,
                            child: authState.isLoading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.login_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: TrexvenFontSize.input,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '© 2026 ODT Web Ecosystem',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: TrexvenFontSize.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
