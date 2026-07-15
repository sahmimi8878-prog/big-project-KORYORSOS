import 'package:flutter/material.dart';

class MenuCard extends StatelessWidget {

  final String title;
  final String image;
  final Color color;
  final bool imageLeft;

  const MenuCard({
    super.key,
    required this.title,
    required this.image,
    required this.color,
    required this.imageLeft,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      height: 110,

      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),

        child: Row(

          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [

            if(imageLeft)
              Image.asset(image,height:80),

            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xff5a4037),
              ),
            ),

            if(!imageLeft)
              Image.asset(image,height:80),

          ],
        ),
      ),
    );
  }
}