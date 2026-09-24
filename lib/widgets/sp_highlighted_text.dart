import 'package:flutter/material.dart';
import 'package:storypad/core/services/search/search_highlight_service.dart';

/// Plain text with search-match highlighting (matches get the color scheme's
/// inverse background, like a text selection).
///
/// Used for search-result bodies instead of `SpMarkdownBody` — markdown
/// rendering and span highlighting don't compose, and a plain-text preview is
/// the standard search-result treatment.
class SpHighlightedText extends StatelessWidget {
  const SpHighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.maxLines,
    this.style,
  });

  final String text;
  final String? query;
  final int? maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final segments = SearchHighlightService.segments(text, query);
    final highlightStyle =
        style?.copyWith(
          backgroundColor: ColorScheme.of(context).inversePrimary,
        ) ??
        TextStyle(backgroundColor: ColorScheme.of(context).inversePrimary);

    return Text.rich(
      TextSpan(
        children: [
          for (final segment in segments)
            TextSpan(
              text: segment.text,
              style: segment.isMatch ? highlightStyle : style,
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
