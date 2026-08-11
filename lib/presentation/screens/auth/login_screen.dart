import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _PasswordStrength { empty, weak, good, strong }

class _LoginScreenState extends State<LoginScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _hasLetterPattern = RegExp(r'[A-Za-z]');
  static final RegExp _hasUppercasePattern = RegExp(r'[A-Z]');
  static final RegExp _hasLowercasePattern = RegExp(r'[a-z]');
  static final RegExp _hasNumberPattern = RegExp(r'\d');
  static final RegExp _hasSymbolPattern = RegExp(r'[^\w\s]');

  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(_handleFieldChanged);
    _emailController.addListener(_handleFieldChanged);
    _passwordController.addListener(_handleFieldChanged);
    _confirmPasswordController.addListener(_handleFieldChanged);
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_handleFieldChanged);
    _emailController.removeListener(_handleFieldChanged);
    _passwordController.removeListener(_handleFieldChanged);
    _confirmPasswordController.removeListener(_handleFieldChanged);
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleFieldChanged() {
    if (!mounted) {
      return;
    }
    context.read<AuthProvider>().clearError();
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final success = _isSignUp
        ? await authProvider.signUp(
            email,
            password,
            displayName: _displayNameController.text.trim(),
          )
        : await authProvider.signIn(email, password);

    if (!success || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    } else {
      navigator.pushReplacementNamed('/home');
    }
  }

  Future<void> _handleForgotPassword() async {
    final l10n = context.l10n;
    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.translate('auth.resetPasswordTitle')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.translate('auth.resetPasswordBody')),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.translate('auth.email'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (!_emailPattern.hasMatch((value ?? '').trim())) {
                    return l10n.translate('auth.resetPasswordHint');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.translate('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(_emailController.text.trim());
              }
            },
            child: Text(l10n.translate('auth.sendResetLink')),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !mounted) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.resetPassword(email);
    if (!mounted) {
      return;
    }

    final key = authProvider.errorKey;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          key == null
              ? l10n.translate('auth.resetPasswordSent', args: {'email': email})
              : l10n.translate(key),
        ),
        backgroundColor: key == null ? null : Colors.red,
      ),
    );
  }

  void _toggleMode(bool signUp) {
    if (_isSignUp == signUp) {
      return;
    }
    context.read<AuthProvider>().clearError();
    setState(() {
      _isSignUp = signUp;
      _obscurePassword = true;
      _obscureConfirmPassword = true;
    });
  }

  _PasswordStrength _passwordStrength(String password) {
    if (password.isEmpty) {
      return _PasswordStrength.empty;
    }

    var score = 0;
    if (password.length >= 8) {
      score += 1;
    }
    if (_hasUppercasePattern.hasMatch(password) &&
        _hasLowercasePattern.hasMatch(password)) {
      score += 1;
    }
    if (_hasNumberPattern.hasMatch(password)) {
      score += 1;
    }
    if (_hasSymbolPattern.hasMatch(password)) {
      score += 1;
    }

    if (score <= 1) {
      return _PasswordStrength.weak;
    }
    if (score <= 2) {
      return _PasswordStrength.good;
    }
    return _PasswordStrength.strong;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isCompact = Responsive.isCompact(context);
    final heroHeight =
        MediaQuery.sizeOf(context).height * (isCompact ? .40 : .44);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E9),
      body: Column(
        children: [
          SizedBox(
            height: heroHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/stitch/bagan_sunrise.jpg',
                  fit: BoxFit.cover,
                ),
                // Flat matte scrim — spec prohibits gradients
                const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x44000000)),
                ),
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.temple_buddhist_outlined,
                          size: 54,
                          color: Color(0xFFC19A49),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Baganetic',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.translate('app.tagline'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            letterSpacing: 3,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F2E9),
                // Flat top edge — spec calls for no pill/rounded transition here
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 42, 28, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _buildFormCard(context, l10n, theme, isCompact),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    bool isCompact,
  ) {
    final auth = context.watch<AuthProvider>();

    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuthIntro(l10n, theme, auth),
              const SizedBox(height: 18),
              _buildNameField(l10n),
              _buildEmailField(l10n),
              _buildPasswordField(l10n, auth),
              _buildPasswordPanel(l10n, theme, auth),
              _buildFooterActions(context, l10n, theme, auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthIntro(
    AppLocalizations l10n,
    ThemeData theme,
    AuthProvider auth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSignUp
              ? l10n.translate('auth.createAccount')
              : l10n.translate('auth.welcomeBack'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? l10n.translateOr(
                  'auth.signUpSubtitle',
                  'Set up a stronger account before you start exploring.',
                )
              : l10n.translateOr(
                  'auth.signInSubtitle',
                  'Sign in to continue with your saved progress.',
                ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
            height: 1.5,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: auth.errorKey == null
              ? const SizedBox.shrink()
              : Container(
                  key: ValueKey(auth.errorKey),
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F0),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFF0B7AC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFD64545),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.translate(auth.errorKey!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF7A2419),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: !_isSignUp
          ? const SizedBox.shrink()
          : Column(
              key: const ValueKey('signup-name'),
              children: [
                TextFormField(
                  controller: _displayNameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: l10n.translate('profile.displayNameLabel'),
                    hintText: l10n.translate('profile.displayNameHint'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (!_isSignUp) {
                      return null;
                    }
                    final normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) {
                      return l10n.translate('profile.displayNameRequired');
                    }
                    if (normalized.length < 2) {
                      return l10n.translateOr(
                        'auth.displayNameLength',
                        'Use at least 2 characters',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildEmailField(AppLocalizations l10n) {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          decoration: InputDecoration(
            labelText: l10n.translate('auth.email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          validator: (value) {
            final normalized = value?.trim() ?? '';
            if (normalized.isEmpty) {
              return l10n.translate('auth.emailRequired');
            }
            if (!_emailPattern.hasMatch(normalized)) {
              return l10n.translate('auth.emailInvalid');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPasswordField(AppLocalizations l10n, AuthProvider auth) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
      autofillHints: [
        _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
      ],
      enableSuggestions: false,
      autocorrect: false,
      onFieldSubmitted: (_) {
        if (!_isSignUp && !auth.isLoading) {
          _submit();
        }
      },
      decoration: InputDecoration(
        labelText: l10n.translate('auth.password'),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: auth.isLoading
              ? null
              : () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) {
          return l10n.translate('auth.passwordRequired');
        }
        if (_isSignUp && password.length < 8) {
          return l10n.translateOr(
            'auth.passwordCreateLength',
            'Use at least 8 characters for your new password',
          );
        }
        if (_isSignUp &&
            (!_hasLetterPattern.hasMatch(password) ||
                !_hasNumberPattern.hasMatch(password))) {
          return l10n.translateOr(
            'auth.passwordCreateMix',
            'Use both letters and numbers',
          );
        }
        if (!_isSignUp && password.length < 6) {
          return l10n.translate('auth.passwordLength');
        }
        return null;
      },
    );
  }

  Widget _buildPasswordPanel(
    AppLocalizations l10n,
    ThemeData theme,
    AuthProvider auth,
  ) {
    final password = _passwordController.text;
    final strength = _passwordStrength(password);
    final strengthColor = _strengthColor(strength);
    final strengthSegments = _strengthSegments(strength);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: !_isSignUp
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('signup-password-extra'),
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.translateOr(
                          'auth.passwordStrengthLabel',
                          'Password strength',
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _strengthLabel(l10n, strength),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: strengthColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(3, (index) {
                      final isActive = index < strengthSegments;
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                          decoration: BoxDecoration(
                            color: isActive ? strengthColor : Colors.black12,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.translateOr(
                      'auth.passwordHelper',
                      'Use 8+ characters with uppercase, lowercase, numbers, and a symbol for the strongest password.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  _buildPasswordRequirement(
                    theme,
                    l10n.translateOr(
                      'auth.passwordRuleLength',
                      '8+ characters',
                    ),
                    password.length >= 8,
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordRequirement(
                    theme,
                    l10n.translateOr(
                      'auth.passwordRuleMix',
                      'Letters + numbers',
                    ),
                    _hasLetterPattern.hasMatch(password) &&
                        _hasNumberPattern.hasMatch(password),
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordRequirement(
                    theme,
                    l10n.translateOr(
                      'auth.passwordRuleCase',
                      'Upper + lower case',
                    ),
                    _hasUppercasePattern.hasMatch(password) &&
                        _hasLowercasePattern.hasMatch(password),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    enableSuggestions: false,
                    autocorrect: false,
                    onFieldSubmitted: (_) {
                      if (!auth.isLoading) {
                        _submit();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.translateOr(
                        'auth.confirmPassword',
                        'Confirm password',
                      ),
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        onPressed: auth.isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (!_isSignUp) {
                        return null;
                      }
                      if ((value ?? '').isEmpty) {
                        return l10n.translateOr(
                          'auth.confirmPasswordRequired',
                          'Please confirm your password',
                        );
                      }
                      if (value != _passwordController.text) {
                        return l10n.translateOr(
                          'auth.passwordMismatch',
                          'Passwords do not match',
                        );
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFooterActions(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    AuthProvider auth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isSignUp)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: auth.isLoading ? null : _handleForgotPassword,
              child: Text(l10n.translate('auth.forgotPassword')),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isSignUp
                        ? l10n.translate('auth.signUp')
                        : l10n.translate('auth.signIn'),
                    style: const TextStyle(fontSize: 17),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.translateOr('auth.formDivider', 'or'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          l10n.translateOr(
            'auth.heroBody',
            'Create an account to sync trips, favorites, and community activity.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: auth.isLoading
                ? null
                : () {
                    context.read<AuthProvider>().setGuestMode();
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop(false);
                    } else {
                      navigator.pushReplacementNamed('/home');
                    }
                  },
            icon: const Icon(Icons.explore_outlined),
            label: Text(l10n.translate('auth.continueGuest')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: auth.isLoading ? null : () => _toggleMode(!_isSignUp),
            child: Text(
              _isSignUp
                  ? l10n.translate('auth.haveAccount')
                  : l10n.translate('auth.noAccount'),
            ),
          ),
        ),
      ],
    );
  }

  int _strengthSegments(_PasswordStrength strength) {
    switch (strength) {
      case _PasswordStrength.empty:
        return 0;
      case _PasswordStrength.weak:
        return 1;
      case _PasswordStrength.good:
        return 2;
      case _PasswordStrength.strong:
        return 3;
    }
  }

  Color _strengthColor(_PasswordStrength strength) {
    switch (strength) {
      case _PasswordStrength.empty:
        return Colors.black12;
      case _PasswordStrength.weak:
        return const Color(0xFFD64545);
      case _PasswordStrength.good:
        return const Color(0xFFAE5038);
      case _PasswordStrength.strong:
        return const Color(0xFF2E8B57);
    }
  }

  String _strengthLabel(AppLocalizations l10n, _PasswordStrength strength) {
    switch (strength) {
      case _PasswordStrength.empty:
        return l10n.translateOr('auth.passwordStrengthEmpty', 'Add a password');
      case _PasswordStrength.weak:
        return l10n.translateOr('auth.passwordStrengthWeak', 'Weak');
      case _PasswordStrength.good:
        return l10n.translateOr('auth.passwordStrengthGood', 'Good');
      case _PasswordStrength.strong:
        return l10n.translateOr('auth.passwordStrengthStrong', 'Strong');
    }
  }

  // ignore: unused_element
  Widget _buildHeaderPanel(ThemeData theme, bool isCompact) {
    final iconSize = isCompact ? 72.0 : 84.0;

    return Padding(
      padding: EdgeInsets.only(
        top: isCompact ? 6 : 8,
        bottom: isCompact ? 2 : 4,
      ),
      child: Align(
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.temple_buddhist_rounded,
              size: iconSize + 10,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, const Color(0xFF8B5A2B)],
              ).createShader(bounds),
              child: Icon(
                Icons.temple_buddhist_rounded,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildModeSelector(
    AppLocalizations l10n,
    ThemeData theme,
    bool loading,
  ) {
    Widget buildItem(bool signUp, String label) {
      final selected = _isSignUp == signUp;
      return Expanded(
        child: GestureDetector(
          onTap: loading ? null : () => _toggleMode(signUp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          buildItem(false, l10n.translate('auth.signIn')),
          buildItem(true, l10n.translate('auth.signUp')),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirement(ThemeData theme, String label, bool met) {
    final color = met ? const Color(0xFF2E8B57) : const Color(0xFF8B867C);
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: met ? const Color(0xFF215D3D) : const Color(0xFF5A554E),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildGlow(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
