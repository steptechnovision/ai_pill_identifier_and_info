import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/models/family_member.dart';
import 'package:ai_medicine_tracker/screens/drug_interaction_screen.dart';
import 'package:ai_medicine_tracker/screens/family_members_screen.dart';
import 'package:ai_medicine_tracker/screens/paywall_screen.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool get _isPro => SubscriptionService.instance.isPro;
  List<FamilyMember> _family = [];

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  void _loadFamily() {
    setState(() => _family = FamilyMember.loadAll());
  }

  Future<void> _openPaywall() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
    setState(() {});
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: UIConstants.darkBackgroundEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText('Clear Search Cache?',
            fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.bold),
        content: AppText(
            'All locally cached medicine data will be removed. Future searches will use 1 token/credit each.',
            fontSize: 13.sp,
            color: Colors.white54,
            lineHeight: 1.4,
            maxLines: 5),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel', color: Colors.white38)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Clear', color: UIConstants.accentRed)),
        ],
      ),
    );

    if (confirm != true) return;
    await Prefs.prefs.remove('medicine_cache');
    if (mounted) {
      Utils.showMessage(context, 'Cache cleared.', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        title: AppText(
          'Settings',
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubscriptionCard(),
            24.verticalSpace,
            _sectionTitle('Family & Caregiving'),
            _buildFamilyTile(),
            24.verticalSpace,
            _sectionTitle('Tools'),
            _buildTile(
              icon: Icons.compare_arrows_rounded,
              title: 'Drug Interaction Checker',
              subtitle: 'Check if your medicines are safe together',
              iconColor: Colors.redAccent,
              onTap: () {
                AdmobService.instance.onNewSearch();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DrugInteractionScreen()),
                );
              },
            ),
            24.verticalSpace,
            _buildSimulateProToggle(),
            24.verticalSpace,
            _sectionTitle('Account'),
            _buildTile(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear Cache',
              subtitle: 'Remove locally saved medicine data',
              onTap: _clearCache,
            ),
            24.verticalSpace,
            _sectionTitle('Support'),
            _buildTile(
              icon: Icons.star_rate_rounded,
              title: 'Rate the App',
              subtitle: 'Love the app? Leave us a review',
              iconColor: Colors.amber,
              onTap: () async {
                final review = InAppReview.instance;
                if (await review.isAvailable()) {
                  review.requestReview();
                } else {
                  review.openStoreListing(appStoreId: Constants.appStoreId);
                }
              },
            ),
            _buildTile(
              icon: Icons.share_rounded,
              title: 'Share App',
              subtitle: 'Help others stay safe with their meds',
              onTap: () => SharePlus.instance.share(ShareParams(
                text: Constants.shareText,
                subject: 'Check out ${Constants.appName}!',
              )),
            ),
            24.verticalSpace,
            _sectionTitle('Legal'),
            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => launchUrl(Uri.parse(Constants.privacyPolicyUrl)),
            ),
            _buildTile(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              onTap: () => launchUrl(Uri.parse(Constants.termsAndConditionUrl)),
            ),
            32.verticalSpace,
            Center(
              child: AppText(
                'Made with ❤️ in India',
                fontSize: 12.sp,
                color: Colors.white24,
              ),
            ),
            16.verticalSpace,
          ],
        ),
      ),
    );
  }

  // ── Simulate Pro toggle ───────────────────────────────

  Widget _buildSimulateProToggle() {
    final isSimulating = Prefs.isSimulatePro();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isSimulating
            ? UIConstants.accentGreen.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSimulating
              ? UIConstants.accentGreen.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.developer_mode_rounded,
                color: Colors.purple, size: 16),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Simulate Pro Mode',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                3.verticalSpace,
                AppText(
                  'Testing only — unlocks Pro features without a subscription',
                  fontSize: 11.sp,
                  color: Colors.white38,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: isSimulating,
              activeTrackColor: UIConstants.accentGreen,
              activeThumbColor: Colors.black,
              inactiveTrackColor: Colors.white10,
              inactiveThumbColor: Colors.grey,
              onChanged: (v) async {
                await Prefs.setSimulatePro(v);
                SubscriptionService.instance.proChangeNotifier.value++;
                if (!mounted) return;
                setState(() {});
                Utils.showMessage(
                  context,
                  v ? 'Pro mode ON — applied instantly.' : 'Pro mode OFF.',
                  success: v,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Family Members tile ───────────────────────────────

  Widget _buildFamilyTile() {
    final count = _family.length;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
        );
        _loadFamily();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: UIConstants.accentGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_rounded,
                  color: UIConstants.accentGreen, size: 18),
            ),
            14.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('Family / Caregiver',
                      fontSize: 14.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                  3.verticalSpace,
                  AppText(
                    count == 0
                        ? 'Add members to track their medications separately'
                        : '$count member${count == 1 ? '' : 's'} · Free: 2, Pro: 5',
                    fontSize: 11.sp,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isPro
              ? [
                  UIConstants.accentGreen.withValues(alpha: 0.15),
                  UIConstants.accentGreen.withValues(alpha: 0.05),
                ]
              : [
                  Colors.amber.withValues(alpha: 0.12),
                  Colors.amber.withValues(alpha: 0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isPro
              ? UIConstants.accentGreen.withValues(alpha: 0.3)
              : Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_isPro ? UIConstants.accentGreen : Colors.amber)
                  .withValues(alpha: 0.15),
            ),
            child: Icon(
              _isPro ? Icons.verified_rounded : Icons.stars_rounded,
              color: _isPro ? UIConstants.accentGreen : Colors.amber,
              size: 24,
            ),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  _isPro ? 'Pro Active' : 'Free Plan',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                4.verticalSpace,
                AppText(
                  _isPro
                      ? 'Enjoy unlimited access to all Pro features.'
                      : 'Upgrade to Pro for unlimited searches & more.',
                  fontSize: 12.sp,
                  color: Colors.white54,
                  lineHeight: 1.4,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          if (!_isPro) ...[
            12.horizontalSpace,
            GestureDetector(
              onTap: _openPaywall,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppText('Upgrade',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: AppText(
        title,
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white38,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = Colors.white54,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            14.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title,
                      fontSize: 14.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                  if (subtitle != null) ...[
                    3.verticalSpace,
                    AppText(subtitle, fontSize: 11.sp, color: Colors.white38),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
