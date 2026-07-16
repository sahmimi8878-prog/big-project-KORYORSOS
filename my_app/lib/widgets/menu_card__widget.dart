import 'package:flutter/material.dart';

class MenuCard extends StatefulWidget {
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
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          isHover = true;
        });
      },

      onExit: (_) {
        setState(() {
          isHover = false;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        height: 110,

        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(25),

          boxShadow: [
            BoxShadow(
              color: isHover
                  ? const Color(0x66FF7CB1) // เงาสีชมพูตอน Hover
                  : Colors.black12,         // เงาปกติ
              blurRadius: isHover ? 22 : 8,
              spreadRadius: isHover ? 2 : 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              if (widget.imageLeft)
                Image.asset(
                  widget.image,
                  height: 80,
                ),

              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff5a4037),
                ),
              ),

              if (!widget.imageLeft)
                Image.asset(
                  widget.image,
                  height: 80,
                ),
            ],
          ),
        ),
      ),
    );
  }
}