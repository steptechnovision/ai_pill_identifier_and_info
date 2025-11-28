import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  const AppText(
    this.msg, {
    super.key,
    this.fontSize,
    this.overflow,
    this.textAlign,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.maxLines,
    this.letterSpacing,
    this.lineHeight,
    this.color,
    this.showCustomUnderLine = false,
    this.underLineColor,
    this.showHtmlFormat = false,
  }) : textSpan = null;

  const AppText.rich({
    super.key,
    required this.textSpan,
    this.fontSize,
    this.overflow,
    this.textAlign,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.maxLines,
    this.letterSpacing,
    this.lineHeight,
    this.color,
    this.showCustomUnderLine = false,
    this.underLineColor,
    this.showHtmlFormat = false,
  }) : msg = '';

  final String? msg;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final Color? color;
  final TextDecoration? decoration;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final double? letterSpacing, lineHeight;
  final bool showCustomUnderLine;
  final Color? underLineColor;
  final bool showHtmlFormat;
  final TextSpan? textSpan;

  @override
  Widget build(BuildContext context) {
    return showCustomUnderLine
        ? Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: underLineColor ?? Colors.white,
                  width: 1.0,
                ),
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
      height: lineHeight,
      color: color,
      decoration: decoration,
    );
  }
}

class AppTextSpan extends StatelessWidget {
  const AppTextSpan({
    super.key,
    this.fontSize,
    this.overflow,
    this.textAlign,
    this.fontWeight,
    this.fontStyle,
    this.textDecoration,
    this.maxLines,
    required this.childSpans,
    this.textColor,
    this.lineHeight,
  });

  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final Color? textColor;
  final TextDecoration? textDecoration;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final List<TextSpan> childSpans;
  final double? lineHeight;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: '',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: textColor,
          height: lineHeight,
          decoration: textDecoration,
        ),
        children: childSpans,
      ),
      textAlign: textAlign ?? TextAlign.start,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: true,
      maxLines: maxLines,
    );
  }
}
