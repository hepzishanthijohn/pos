import 'package:flutter/material.dart';
import 'package:rcspos/screens/cartpage.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/screens/productstablepage.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int)? onTap;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF228CF0),
      unselectedItemColor: Colors.grey,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.table_chart), // New icon for Product Table
          label: 'Products',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'Cart',
        ),
       
      ],
    );
  }
}
