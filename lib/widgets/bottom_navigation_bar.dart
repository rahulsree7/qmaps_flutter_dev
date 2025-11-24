import 'package:flutter/material.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onAddTap;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  Widget _buildCentralAddButton() {
    return GestureDetector(
      onTap: onAddTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF8B5CF6),
              const Color(0xFF7C3AED),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Active indicator line
              if (isActive)
                Container(
                  width: 20,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                )
              else
                const SizedBox(height: 4),
              // Icon
              Icon(
                icon,
                color: isActive ? const Color(0xFF3B82F6) : Colors.grey[400],
                size: 22,
              ),
              const SizedBox(height: 1),
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? const Color(0xFF3B82F6) : Colors.grey[400],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildBottomNavItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  index: 0,
                  isActive: currentIndex == 0,
                ),
              ),
              Expanded(
                child: _buildBottomNavItem(
                  icon: Icons.checklist_rounded,
                  label: 'Checklists',
                  index: 1,
                  isActive: currentIndex == 1,
                ),
              ),
              // Central elevated + button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildCentralAddButton(),
              ),
              Expanded(
                child: _buildBottomNavItem(
                  icon: Icons.confirmation_num_outlined,
                  label: 'Tickets',
                  index: 2,
                  isActive: currentIndex == 2,
                ),
              ),
              Expanded(
                child: _buildBottomNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  index: 3,
                  isActive: currentIndex == 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

