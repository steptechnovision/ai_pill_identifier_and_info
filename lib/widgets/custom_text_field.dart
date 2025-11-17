import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/widgets/counter_text_widget.dart';
import 'package:ai_medicine_tracker/widgets/dialogs/voice_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CustomTextField extends StatefulWidget {
  final String? hintText;
  final String? labelText;
  final String? lastLabel;
  final Color? lastLabelBorderColor;
  final Function? onTapLabel;
  final TextEditingController? controller;
  final dynamic prefixIcon;
  final dynamic suffixIcon;
  final bool showDividerOnSuffixIcon;
  final bool isPassword;
  final TextInputAction? textInputAction;
  final TextInputType? textInputType;
  final bool isMobileNumberFieldAndShowCountryCode;
  final bool showShadowOnTextField;
  final bool isRequired;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final double? fontSize;
  final bool digitsOnly;
  final bool allowNegativeNumbers;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool isDisabled;
  final bool useDisableBackground;
  final bool enableVoiceInput;
  final Function(String)? onVoiceResult;
  final bool isSearchView;
  final bool showInfoIcon;
  final String? infoMessage;
  final String? infoIconAsset;
  final bool showCancelButton;
  final VoidCallback? onCancelTap;
  final Color? textFieldHintTextColor;
  final String? errorText;
  final bool showError;

  const CustomTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.lastLabel,
    this.lastLabelBorderColor,
    this.onTapLabel,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.showDividerOnSuffixIcon = false,
    this.textInputAction,
    this.textInputType,
    this.isMobileNumberFieldAndShowCountryCode = false,
    this.showShadowOnTextField = false,
    this.isRequired = false,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    this.fontSize,
    this.digitsOnly = false,
    this.allowNegativeNumbers = true,
    this.inputFormatters,
    this.onSubmitted,
    this.isDisabled = false,
    this.useDisableBackground = false,
    this.enableVoiceInput = false,
    this.onVoiceResult,
    this.isSearchView = false,
    this.showInfoIcon = false,
    this.infoMessage,
    this.infoIconAsset,
    this.showCancelButton = false,
    this.onCancelTap,
    this.textFieldHintTextColor,
    this.errorText,
    this.showError = false,
  });

  @override
  State<CustomTextField> createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _obscureText = true;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  BuildContext? _bottomSheetContext;
  bool _showClearIcon = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    widget.controller?.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleTextChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    if (!widget.isSearchView) return;
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    if (hasText != _showClearIcon) {
      setState(() {
        _showClearIcon = hasText;
      });
    }
  }

  Future<void> _listen() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == "done") {
          if (_bottomSheetContext != null) {
            Navigator.pop(_bottomSheetContext!); // ✅ only closes dialog
            _bottomSheetContext = null;
          }
        }
      },
      onError: (error) {
        print("ERROR: $error");
        Utils.runAfterCurrentSuccess(() {
          if (_bottomSheetContext != null) {
            Navigator.pop(_bottomSheetContext!);
            _bottomSheetContext = null;
          }
          _showVoiceDialog(hasError: true);
        });
      },
    );

    if (available) {
      _speech.listen(
        onResult: (result) {
          final spokenText = result.recognizedWords;
          widget.controller?.text = spokenText;

          if (result.finalResult) {
            widget.onVoiceResult?.call(spokenText);
            if (_bottomSheetContext != null) {
              Navigator.pop(_bottomSheetContext!);
              _bottomSheetContext = null;
            }
          }
        },
      );

      _showVoiceDialog(isListening: true);
    }
  }

  void _showVoiceDialog({bool isListening = false, bool hasError = false}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
      ),
      builder: (ctx) {
        _bottomSheetContext = ctx;
        return VoiceDialog(
          isListening: isListening,
          hasError: hasError,
          onRetry: () {
            Navigator.pop(ctx);
            _listen();
          },
          onClose: () {
            _speech.stop();
            Utils.runAfterCurrentSuccess(() {
              if (_bottomSheetContext != null) {
                Navigator.pop(_bottomSheetContext!);
                _bottomSheetContext = null;
              }
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.transparent, // 🌙 dark background
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.isDisabled ? Colors.white12 : Colors.white24, // 🌙 softer border
              width: 1,
            ),
            boxShadow: widget.showShadowOnTextField
                ? [
              BoxShadow(
                color: Colors.black45, // 🌙 subtle shadow
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ]
                : [],
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null)
                Padding(
                  padding: EdgeInsets.only(left: 12.w),
                  child: widget.prefixIcon is String
                      ? SvgPicture.asset(
                    widget.prefixIcon!,
                    width: 23.r,
                    height: 23.r,
                    colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn,
                    ), // 🌙 tint icon
                  )
                      : Icon(
                    widget.prefixIcon,
                    size: 23.r,
                    color: Colors.white, // 🌙 icon color
                  ),
                ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: widget.prefixIcon != null ? 6.w : 12.w,
                  ),
                  color: Colors.transparent,
                  child: TextField(
                    enabled: !widget.isDisabled,
                    focusNode: _focusNode,
                    controller: widget.controller,
                    obscureText: widget.isPassword ? _obscureText : false,
                    style: TextStyle(
                      fontSize: widget.fontSize ?? 17.sp,
                      color: Colors.white, // 🌙 text color
                    ),
                    textInputAction: widget.textInputAction,
                    keyboardType: widget.textInputType,
                    maxLength: widget.maxLength,
                    onChanged: widget.onChanged,
                    autofocus: false,
                    maxLines: widget.maxLines,
                    inputFormatters: widget.inputFormatters,
                    onSubmitted: widget.onSubmitted,
                    decoration: InputDecoration(
                      border: InputBorder.none,           // 🚀 Removes the default underline
                      enabledBorder: InputBorder.none,    // 🚀 Removes border when enabled
                      focusedBorder: InputBorder.none,    // 🚀 Removes border when focused
                      disabledBorder: InputBorder.none,   // 🚀 Removes border when disabled
                      filled: false,
                      isDense: true,
                      counterText: "",
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: widget.fontSize ?? 17.sp,
                        color: widget.textFieldHintTextColor ??
                            Colors.white38, // 🌙 hint text
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 0,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.suffixIcon != null || widget.isSearchView)
                Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.isSearchView && _showClearIcon) ...[
                        GestureDetector(
                          onTap: () {
                            widget.controller?.clear();
                            widget.onChanged?.call("");
                            setState(() {
                              _showClearIcon = false;
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 20.r,
                            color: Colors.white60,
                          ),
                        ),
                        SizedBox(width: 8.w),
                      ],
                      if (widget.showDividerOnSuffixIcon)
                        Container(
                          width: 1,
                          color: Colors.white24,
                          height: 24.h,
                          margin: EdgeInsets.only(right: 8.w),
                        ),
                      widget.enableVoiceInput
                          ? GestureDetector(
                        onTap: _listen,
                        child: _suffixView(),
                      )
                          : SizedBox.shrink(),
                    ],
                  ),
                ),
              SizedBox(width: 2.w),
              if (widget.isPassword)
                Padding(
                  padding: EdgeInsets.only(right: 13.w),
                  child: GestureDetector(
                    onTap: () => setState(() => _obscureText = !_obscureText),
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 6.w,
                      color: Colors.white60,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.maxLength != null && widget.controller != null)
          CounterTextWidget(
            controller: widget.controller!,
            maxLength: widget.maxLength!,
          ),
      ],
    );
  }

  Widget _suffixView() {
    return widget.suffixIcon is String
        ? SvgPicture.asset(widget.suffixIcon!, width: 23.w, height: 23.w)
        : widget.suffixIcon is Icon
        ? widget.suffixIcon
        : Icon(widget.suffixIcon, size: 23.w);
  }
}
