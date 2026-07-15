import 'package:flutter/material.dart';
import '../widgets/menu_card__widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xfff8d7f3),
              Color(0xffeef2ff),
              Colors.white,
            ],
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [

                /// Header
                Row(
                  children: [

                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset(
                        "assets/images/logo3.jpg",
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 25),

                MenuCard(
                  title: "ข้อมูลผู้ใช้",
                  image: "assets/images/Pu.jpg",
                  color: const Color(0xffc7c6ea),
                  imageLeft: true,
                ),

                const SizedBox(height: 22),

                MenuCard(
                  title: "เอกสาร",
                  image: "assets/images/Mee.jpg",
                  color: const Color(0xfffaefef),
                  imageLeft: false,
                ),

                const SizedBox(height: 22),

                MenuCard(
                  title: "การจอง",
                  image: "assets/images/Kame.jpg",
                  color: const Color(0xffeba6d0),
                  imageLeft: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}