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
  bool _hasFocus = false; // ✨ Tracks focus for styling

  late stt.SpeechToText _speech;
  bool _isListening = false;
  BuildContext? _bottomSheetContext;
  bool _showClearIcon = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    widget.controller?.addListener(_handleTextChange);

    // ✨ Listen to focus changes to animate the border
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
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
            Navigator.pop(_bottomSheetContext!);
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
      backgroundColor: Colors.grey[900], // Dark theme friendly
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
    // ✨ Compact Height
    final double height = 46.h;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✨ Using AnimatedContainer for smooth focus transition
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: height,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            // ✨ Soft Background Fill (Clean look)
            color: widget.isDisabled
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12), // Soft corners
            border: Border.all(
              // ✨ Only show border/glow when focused or error
              color: widget.showError
                  ? Colors.redAccent
                  : (_hasFocus ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.transparent),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // PREFIX ICON
              if (widget.prefixIcon != null)
                Padding(
                  padding: EdgeInsets.only(left: 12.w, right: 6.w),
                  child: widget.prefixIcon is String
                      ? SvgPicture.asset(
                    widget.prefixIcon!,
                    width: 20.r, // Smaller icon
                    height: 20.r,
                    colorFilter: ColorFilter.mode(
                      _hasFocus ? Colors.white : Colors.white60,
                      BlendMode.srcIn,
                    ),
                  )
                      : Icon(
                    widget.prefixIcon,
                    size: 20.r,
                    color: _hasFocus ? Colors.white : Colors.white60,
                  ),
                ),

              // TEXT FIELD
              Expanded(
                child: TextField(
                  enabled: !widget.isDisabled,
                  focusNode: _focusNode,
                  controller: widget.controller,
                  obscureText: widget.isPassword ? _obscureText : false,
                  style: TextStyle(
                    fontSize: widget.fontSize ?? 15.sp, // Slightly smaller text
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                  textInputAction: widget.textInputAction,
                  keyboardType: widget.textInputType,
                  maxLength: widget.maxLength,
                  onChanged: widget.onChanged,
                  autofocus: false,
                  maxLines: widget.maxLines,
                  inputFormatters: widget.inputFormatters,
                  onSubmitted: widget.onSubmitted,
                  // ✨ Center text vertically
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    counterText: "",
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: widget.fontSize ?? 15.sp,
                      color: widget.textFieldHintTextColor ?? Colors.white30,
                    ),
                    // ✨ Zero padding is key for alignment in fixed height container
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              // SUFFIX ICONS
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        child: Icon(Icons.cancel, size: 16.r, color: Colors.white38),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    if (widget.showDividerOnSuffixIcon)
                      Container(
                        width: 1,
                        color: Colors.white12,
                        height: 20.h,
                        margin: EdgeInsets.only(right: 8.w),
                      ),
                    widget.enableVoiceInput
                        ? GestureDetector(
                      onTap: _listen,
                      child: _suffixView(),
                    )
                        : const SizedBox.shrink(),

                    // Handle custom suffix if voice input is not active
                    if (!widget.enableVoiceInput && widget.suffixIcon != null)
                      _suffixView(),
                  ],
                ),
              ),

              if (widget.isPassword)
                Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: GestureDetector(
                    onTap: () => setState(() => _obscureText = !_obscureText),
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 20.r,
                      color: Colors.white54,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Counter text remains underneath if needed
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
        ? SvgPicture.asset(
      widget.suffixIcon!,
      width: 20.w,
      height: 20.w,
      colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
    )
        : widget.suffixIcon is Icon
        ? widget.suffixIcon
        : Icon(widget.suffixIcon, size: 20.w, color: Colors.white70);
  }
}
