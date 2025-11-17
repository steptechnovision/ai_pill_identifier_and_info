import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppText extends StatelessWidget {
  const AppText(
    this.msg, {
    super.key,
    this.fontSize,
    this.overflow = TextOverflow.visible,
    this.textAlign = TextAlign.center,
    this.fontWeight = FontWeight.w400,
    this.fontStyle = FontStyle.normal,
    this.decoration = TextDecoration.none,
    this.maxLines = 1,
    this.letterSpacing,
    this.lineHeight,
    this.color = Colors.white,
    this.showCustomUnderLine = false,
    this.underLineColor = Colors.white,
    this.showHtmlFormat = false,
  }) : textSpan = null;

  const AppText.rich({
    super.key,
    required this.textSpan,
    this.fontSize,
    this.overflow = TextOverflow.visible,
    this.textAlign = TextAlign.center,
    this.fontWeight = FontWeight.w400,
    this.fontStyle = FontStyle.normal,
    this.decoration = TextDecoration.none,
    this.maxLines = 1,
    this.letterSpacing,
    this.lineHeight,
    this.color = Colors.white,
    this.showCustomUnderLine = false,
    this.underLineColor = Colors.white,
    this.showHtmlFormat = false,
  }) : msg = '';

  final String? msg;
  final double? fontSize;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final Color color;
  final TextDecoration decoration;
  final TextAlign textAlign;
  final TextOverflow overflow;
  final int? maxLines;
  final double? letterSpacing, lineHeight;
  final bool showCustomUnderLine;
  final Color underLineColor;
  final bool showHtmlFormat;
  final TextSpan? textSpan;

  @override
  Widget build(BuildContext context) {
    return showCustomUnderLine
        ? Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: underLineColor, width: 1.0),
              ),
            ),
            child: textWidget(),
          )
        : textWidget();
  }

  Widget textWidget() {
    if (textSpan != null) {
      return Text.rich(
        textSpan!,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }
    return Text(
      msg ?? '',
      textAlign: textAlign,
      overflow: overflow,
      softWrap: true,
      maxLines: maxLines,
      style: getTextStyle(),
    );
  }

  TextStyle getTextStyle() {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: lineHeight ?? 1,
      color: color,
      decoration: decoration,
    );
  }
}

class AppTextSpan extends StatelessWidget {
  const AppTextSpan({
    super.key,
    this.fontSize,
    this.overflow = TextOverflow.visible,
    this.textAlign = TextAlign.center,
    this.fontWeight = FontWeight.w500,
    this.fontStyle = FontStyle.normal,
    this.textDecoration = TextDecoration.none,
    this.maxLines = 1,
    required this.childSpans,
    this.textColor = Colors.white,
    this.lineHeight,
  });

  final double? fontSize;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final Color textColor;
  final TextDecoration textDecoration;
  final TextAlign textAlign;
  final TextOverflow overflow;
  final int maxLines;
  final List<TextSpan> childSpans;
  final double? lineHeight;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: '',
        style: TextStyle(
          fontSize: (fontSize ?? 18).sp,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: textColor,
          height: lineHeight,
          decoration: textDecoration,
        ),
        children: childSpans,
      ),
      textAlign: textAlign,
      overflow: overflow,
      softWrap: true,
      maxLines: maxLines,
    );
  }
}
