import 'package:flutter/material.dart';
import '../widgets/menu_card__widget.dart';
import '../widgets/navbar.dart';
import 'booking_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      bottomNavigationBar: CustomNavBar(
        currentIndex: 0,
        onTap: (index) {},
      ),

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
            padding: const EdgeInsets.fromLTRB(
              20,
              40,
              20,
              110,
            ),

            child: SingleChildScrollView(
              child: Column(
                children: [

                  /// HEADER
                  Row(
                    children: [

                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(
                                120,
                                90,
                                160,
                                0.28,
                              ),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),

                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            "assets/images/logo3.jpg",
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 16),

                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),

                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(
                                  120,
                                  90,
                                  160,
                                  0.28,
                                ),
                                blurRadius: 24,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),

                          child: const Row(
                            children: [

                              Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),

                              SizedBox(width: 10),

                              Text(
                                "ค้นหา...",
                                style: TextStyle(
                                  color: Color(0xff8B6FA3),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BookingScreen(),
      ),
    );
  },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}