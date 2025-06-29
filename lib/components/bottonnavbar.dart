import 'package:flutter/material.dart';
import 'package:rcspos/screens/cartpage.dart';
import 'package:rcspos/screens/home.dart';
import 'package:rcspos/screens/orderspage.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
  });

  void _navigate(BuildContext context, int index) {
    Widget targetPage;

    switch (index) {
      case 0:
        targetPage = const HomePage();
        break;
      case 1:
        targetPage = const OrdersPage();
        break;
      case 2:
        targetPage = const CartPage(cartItems: []); // You'll need to pass cart data properly
        break;
      // case 3:
      //   targetPage = const MorePage(); // create this page if needed
      //   break;
      default:
        targetPage = const HomePage();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF228CF0),
      unselectedItemColor: Colors.grey,
      onTap: (index) => _navigate(context, index),
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
          icon: Icon(Icons.shopping_cart),
          label: 'Cart',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}
