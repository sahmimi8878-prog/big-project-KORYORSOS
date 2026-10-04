import 'package:flutter/material.dart';

class MenuCard extends StatefulWidget {
  final String title;
  final String? image; // ไม่ใส่ = ไม่มีรูป และข้อความจัดกึ่งกลางการ์ด
  final Color color;
  final bool imageLeft;
  final VoidCallback? onTap; // 1. เพิ่ม field รับ callback
  final String? subtitle; // คำอธิบายใต้ชื่อการ์ด
  final String? status; // ข้อความสถานะในป้ายสีขาว เช่น คิวถัดไปของผู้ใช้
  final IconData? statusIcon;
  final double titleSize; // ขนาดตัวอักษรชื่อการ์ด

  const MenuCard({
    super.key,
    required this.title,
    this.image,
    required this.color,
    this.imageLeft = false,
    this.onTap, // 2. เพิ่มในนี้ (ไม่ required เพราะบางการ์ดอาจไม่ต้องกดได้)
    this.subtitle,
    this.status,
    this.statusIcon,
    this.titleSize = 28,
  });

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    // ตัวหนังสืออยู่ฝั่งตรงข้ามรูป
    final bool hasImage = widget.image != null;
    final CrossAxisAlignment textAlign = !hasImage
        ? CrossAxisAlignment.center
        : (widget.imageLeft
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start);
    final TextAlign textAlignment = !hasImage
        ? TextAlign.center
        : (widget.imageLeft ? TextAlign.right : TextAlign.left);

    final Widget text = Expanded(
      child: Column(
        crossAxisAlignment: textAlign,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: widget.titleSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xff5a4037),
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.subtitle!,
              textAlign: textAlignment,
              style: const TextStyle(fontSize: 13, color: Color(0xff7a5a50)),
            ),
          ],
          if (widget.status != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.statusIcon != null) ...[
                    Icon(
                      widget.statusIcon,
                      size: 16,
                      color: const Color(0xff9a4a76),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      widget.status!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff6a2e4e),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

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

          // สูงขั้นต่ำ 110 ถ้ามีคำอธิบาย/สถานะการ์ดจะสูงขึ้นตามเนื้อหา
          constraints: const BoxConstraints(minHeight: 110),

          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(25),

            boxShadow: [
              BoxShadow(
                color: isHover
                    ? const Color(0x66FF7CB1) // เงาสีชมพูตอน Hover
                    : Colors.black12, // เงาปกติ
                blurRadius: isHover ? 22 : 8,
                spreadRadius: isHover ? 2 : 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (hasImage && widget.imageLeft) ...[
                  Image.asset(widget.image!, height: 80),
                  const SizedBox(width: 16),
                ],

                text,

                if (hasImage && !widget.imageLeft) ...[
                  const SizedBox(width: 16),
                  Image.asset(widget.image!, height: 80),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
