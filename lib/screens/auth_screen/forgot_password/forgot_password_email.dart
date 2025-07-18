import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:p_chat/global_content/snack_bar.dart';
import 'package:p_chat/models/forgot_password_model.dart';
import 'package:p_chat/screens/auth_screen/export.dart';
import 'package:p_chat/services/auth_services/forgot_password_service.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({Key? key}) : super(key: key);

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final TextEditingController _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColor.colorBlueBlack,
        body:
            ListView(padding: EdgeInsets.symmetric(horizontal: 6.w), children: [
          SizedBox(height: 17.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppText.boldText('P - ', FontWeight.bold,
                  color: AppColor.colorWhite, fontSize: FontSize.font50),
              AppText.boldText('CHAT', FontWeight.bold,
                  color: AppColor.colorOrange, fontSize: FontSize.font50),
            ],
          ),
          Center(
            child: AppText.boldText(
                'Enter Email link with account', FontWeight.w500,
                color: AppColor.colorWhite,
                fontSize: FontSize.font18,
                maxLine: 3),
          ),
          SizedBox(height: 5.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 3.w),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: AppColor.colorLightGray.withOpacity(0.5)),
            child: Column(
              children: [
                TextInput(
                  borderColor: AppColor.colorLightGray,
                  hintText: 'Enter email address',
                  textInput: _emailController,
                  inputColor: AppColor.colorWhite,
                  textType: TextInputType.emailAddress,
                  validate: (p0) {
                    return null;
                  },
                ),
                SizedBox(height: 3.h),
                materialButton(
                  buttonBkColor: AppColor.colorOrange.withOpacity(0.8),
                  width: 100.w,
                  height: 7.h,
                  onPres: () {
                    final data =
                        ForgotPasswordModel(email: _emailController.text);
                    ref.read(loadingAnimationSpinkit.notifier).state = true;
                    ForgotPasswordApi.userForgotPassword(ref, data, context);
                  },
                  widget: ref.watch(loadingAnimationSpinkit)
                      ? const SpinKitCircle(
                          color: AppColor.colorWhite,
                        )
                      : AppText.boldText(
                          'Continue',
                          FontWeight.bold,
                          fontSize: FontSize.font16,
                          color: AppColor.colorWhite,
                        ),
                )
              ],
            ),
          ),
        ]));
  }
}
