import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class DriverRatingBar extends StatelessWidget {
  final double rating;
  final double size;
  final bool showNumber;
  final Color? color;

  const DriverRatingBar({
    super.key,
    required this.rating,
    this.size = 20,
    this.showNumber = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBar.builder(
          initialRating: rating,
          minRating: 1,
          direction: Axis.horizontal,
          allowHalfRating: true,
          ignoreGestures: true,
          itemCount: 5,
          itemSize: size,
          itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
          itemBuilder: (context, _) => Icon(
            Icons.star,
            color: color ?? Colors.amber,
          ),
          onRatingUpdate: (rating) {},
        ),
        if (showNumber) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.7,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.amber,
            ),
          ),
        ],
      ],
    );
  }
} 