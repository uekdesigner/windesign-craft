import 'package:flutter/material.dart';
import '../../../models/shape_spec.dart';

class ToolbarIcon {
  final IconData icon;
  final String label;
  final String action;
  final bool isDraggable;

  const ToolbarIcon({
    required this.icon,
    required this.label,
    required this.action,
    this.isDraggable = true,
  });
}

class ScrollableToolbar extends StatelessWidget {
  final Function(String action) onAction;
  final Function(InternalElementType type) onDragStart;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const ScrollableToolbar({
    Key? key,
    required this.onAction,
    required this.onDragStart,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  }) : super(key: key);

  static const List<ToolbarIcon> icons = [
    ToolbarIcon(
      icon: Icons.pan_tool,
      label: 'Seçim',
      action: 'select',
      isDraggable: false,
    ),
    ToolbarIcon(
      icon: Icons.vertical_align_center,
      label: 'Dik Çizgi',
      action: 'vertical_line',
    ),
    ToolbarIcon(
      icon: Icons.horizontal_rule,
      label: 'Yatay Çizgi',
      action: 'horizontal_line',
    ),
    ToolbarIcon(icon: Icons.change_history, label: 'Üçgen', action: 'triangle'),
    ToolbarIcon(icon: Icons.drag_handle, label: 'Paralel', action: 'parallel'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 8),
        children: [
          // Action buttons
          _buildActionButton(
            icon: Icons.undo,
            onTap: canUndo ? onUndo : null,
            color: canUndo ? Colors.white : Colors.white54,
          ),
          _buildActionButton(
            icon: Icons.redo,
            onTap: canRedo ? onRedo : null,
            color: canRedo ? Colors.white : Colors.white54,
          ),
          VerticalDivider(color: Colors.white30, width: 20),

          // Draggable icons
          ...icons.map((iconData) => _buildDraggableIcon(iconData)),

          VerticalDivider(color: Colors.white30, width: 20),

          // Delete button
          _buildActionButton(
            icon: Icons.delete,
            onTap: () => onAction('delete'),
            color: Colors.red.shade300,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onTap,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }

  Widget _buildDraggableIcon(ToolbarIcon iconData) {
    InternalElementType? type;
    switch (iconData.action) {
      case 'vertical_line':
        type = InternalElementType.verticalLine;
        break;
      case 'horizontal_line':
        type = InternalElementType.horizontalLine;
        break;
      case 'triangle':
        type = InternalElementType.triangle;
        break;
      case 'parallel':
        type = InternalElementType.parallelLines;
        break;
    }

    Widget iconWidget = Container(
      width: 70,
      height: 70,
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: iconData.action == 'select'
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData.icon, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text(
            iconData.label,
            style: TextStyle(color: Colors.white, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    if (!iconData.isDraggable || type == null) {
      return GestureDetector(
        onTap: () => onAction(iconData.action),
        child: iconWidget,
      );
    }

    return Draggable<InternalElementType>(
      data: type,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData.icon, color: Colors.white, size: 32),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: iconWidget),
      child: iconWidget,
    );
  }
}
