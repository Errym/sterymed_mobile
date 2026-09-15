import 'package:flutter/material.dart';

import 'timeline_entry.dart';

class TimelineWidget extends StatelessWidget {
  final List<TimelineEntry> entries;

  const TimelineWidget({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entries.length; i++)
          TimelineEntry(
            title: entries[i].title,
            subtitle: entries[i].subtitle,
            timestamp: entries[i].timestamp,
            color: entries[i].color,
            isFirst: i == 0,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}
