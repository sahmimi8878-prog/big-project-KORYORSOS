import 'package:flutter/material.dart';

class MenuCard extends StatefulWidget {
  final String title;
  final String image;
  final Color color;
  final bool imageLeft;
<<<<<<< HEAD
  final VoidCallback? onTap; // เพิ่มตรงนี้
=======
  final VoidCallback? onTap; // 1. เพิ่ม field รับ callback
>>>>>>> bb18172c93572e96cd428a5227f05b60eb295ff1

  const MenuCard({
    super.key,
    required this.title,
    required this.image,
    required this.color,
    required this.imageLeft,
<<<<<<< HEAD
    this.onTap, // เพิ่มตรงนี้
=======
    this.onTap, // 2. เพิ่มในนี้ (ไม่ required เพราะบางการ์ดอาจไม่ต้องกดได้)
>>>>>>> bb18172c93572e96cd428a5227f05b60eb295ff1
  });

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    

    return GestureDetector(
      onTap: onTap, // <-- เพิ่มบรรทัดนี้
      child: Container(
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
              if (imageLeft) Image.asset(image, height: 80),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff5a4037),
                ),
              ),
              if (!imageLeft) Image.asset(image, height: 80),
            ],
          ),
=======
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

      // 3. ครอบด้วย GestureDetector เพื่อรับการกด แล้วเรียก widget.onTap
      child: GestureDetector(
        onTap: widget.onTap,
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
>>>>>>> bb18172c93572e96cd428a5227f05b60eb295ff1
        ),
      ),
    );
  }
}