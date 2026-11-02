import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import 'auth_service.dart';

/// Member site agreement shown after a successful returning login.
class AgreementPage extends ConsumerWidget {
  const AgreementPage({super.key});

  static const _paragraphs = [
    '本公司是缅甸合法互联网交易机构，现提醒有意参与本公司所有游戏的客户，应注意其国家或居住地区的相关法律法规，如有问题应就相关问题寻求当地法律意见及/或其网站是否合法的责任。',
    '本网站规则及声明',
    '1. 为避免于本网站下注时之争议，请会员务必于进入网站前，详细阅读本网站所定的各项规则，客户一经进入游戏，即被视为已接受所有之规定。',
    '2. 所有下注必须在"指定时间"内进行，若该局未开牌之前因故取消或终止则该之下注特视为无效，本网站应退回投注的所有金额。',
    '3. 本网站在下注过程中，若出现任何错误或非故意之人为疏失，本网站将保留更改的权利，并以公布，不会另行通知各位会员。',
    '4. 客户有责任确保自己的账户及资料的保密性，如果客户发现或怀疑自己的资料被盗用，请立即通知本网站或代理商，立即做密码变更之动作。',
    '5. 每次登入时，客户都应该核对自己的账户余额，如果对余额有任何疑问，请立即通知本网站代理商。',
    '6. 客户完成任何下注后，在"下注记录"内检查下注金额及派彩结果及派彩结果有异议请及时通本网站或代理商。',
    '7. 客户若不能提供充分的数据，其账户内一切数据或历史数据，以本公司数据库中的数据为准。',
    '8. 若遇发牌时发生人为错误，现场经理将依国际惯例公平公正处理。',
    '9. 恶意透过本网站漏洞，或使用外挂程序，或擅自修改取得之不当账目，经查证属实者，本网站将立即关闭该用户之账户，及所有账目将不予计算。',
    '10. 本公司只受理会员在三日内提出之投诉，逾期将不予受理，本公司不接受任何代他人的诉之投诉。',
    '11. 本网站如被"黑客入侵"或"电脑病毒感染"而导致之问题，处理及安排之权利归于本公司。',
    '12. 本网投系统设定会员长时间没有投注，逾时将被自动注销。',
    '13. 本网站对每一局结果之处理保留最终决定之权利。',
  ];

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GoldenDarkBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          children: [
            const Text(
              '网站规则及声明',
              style: TextStyle(
                color: CasinoColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x66C6A15B)),
                  color: const Color(0x66140F0A),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _paragraphs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return Text(
                      _paragraphs[index],
                      style: const TextStyle(
                        color: Color(0xFFF4E7C3),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AgreementButton(
                  label: '同意',
                  colors: const [
                    Color(0xFFE53935),
                    Color(0xFFC62828),
                    Color(0xFFB71C1C),
                  ],
                  foreground: Colors.white,
                  onPressed: () => context.go('${AppRoutes.lobby}?notice=1'),
                ),
                const SizedBox(width: 28),
                _AgreementButton(
                  label: '拒绝',
                  colors: const [
                    Color(0xFFE0E0E0),
                    Color(0xFFBDBDBD),
                    Color(0xFF9E9E9E),
                  ],
                  foreground: const Color(0xFF2A2A2A),
                  onPressed: () => _reject(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreementButton extends StatelessWidget {
  const _AgreementButton({
    required this.label,
    required this.colors,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final List<Color> colors;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(96, 36),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
