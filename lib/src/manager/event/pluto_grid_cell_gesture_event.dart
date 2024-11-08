import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

/// [PlutoCell] This event handles the gesture of the widget.
class PlutoGridCellGestureEvent extends PlutoGridEvent {
  final PlutoGridGestureType gestureType;
  final Offset offset;
  final PlutoCell cell;
  final PlutoColumn column;
  final int rowIdx;

  PlutoGridCellGestureEvent({
    required this.gestureType,
    required this.offset,
    required this.cell,
    required this.column,
    required this.rowIdx,
  });

  @override
  void handler(PlutoGridStateManager stateManager) {
    switch (gestureType) {
      case PlutoGridGestureType.onTapUp:
        _onTapUp(stateManager);
        break;
      case PlutoGridGestureType.onLongPressStart:
        _onLongPressStart(stateManager);
        break;
      case PlutoGridGestureType.onLongPressMoveUpdate:
        _onLongPressMoveUpdate(stateManager);
        break;
      case PlutoGridGestureType.onLongPressEnd:
        _onLongPressEnd(stateManager);
        break;
      case PlutoGridGestureType.onDoubleTap:
        _onDoubleTap(stateManager);
        break;
      case PlutoGridGestureType.onSecondaryTap:
        _onSecondaryTap(stateManager);
        break;
      case PlutoGridGestureType.onStartCellDrag:
        _onStartCellDrag(stateManager);
        break;
      case PlutoGridGestureType.onEndCellDrag:
        _onEndCellDrag(stateManager);
        break;
      case PlutoGridGestureType.onEnterCell:
        _onEnterCell(stateManager);
        break;
    }
  }

  void _onStartCellDrag(PlutoGridStateManager stateManager) =>
      stateManager.dragCellWithPosition(
        cell: cell,
        columnIdx: stateManager.columnIndex(column)!,
        rowIdx: rowIdx,
        initialCell: true,
      );

  void _onEndCellDrag(PlutoGridStateManager stateManager) {
    stateManager.finishCellDrag();
  }

  void _onEnterCell(PlutoGridStateManager stateManager) =>
      stateManager.dragCellWithPosition(
        cell: cell,
        columnIdx: stateManager.columnIndex(column)!,
        rowIdx: rowIdx,
        initialCell: false,
      );

  void _onTapUp(PlutoGridStateManager stateManager) {
    if (_setKeepFocusAndCurrentCell(stateManager)) {
      return;
    }
    // Triggering multi-select mode.
    else if (stateManager.isSelectingInteraction()) {
      _selecting(stateManager);
      return;
    } else if (stateManager.mode.isSelectMode) {
      _selectMode(stateManager);
      return;
    }
    // Selecting a cell and the cell tapped was not a selected or current cell nor editing.
    else if (stateManager.isSelecting &&
        stateManager.selectingMode.isCell &&
        !stateManager.isSelectedCell(cell, column, rowIdx) &&
        !stateManager.isCurrentCell(cell) &&
        !stateManager.isEditing) {
      // Exit selection mode and clear selected cells.
      stateManager.setSelecting(false);
      stateManager.clearCurrentSelecting();
    }

    // Cell is currently focused and not editing yet.
    if (stateManager.isCurrentCell(cell) && stateManager.isEditing != true) {
      // Selected cell, so go into edit mode without clearing selected cells.
      if (stateManager.isSelecting) {
        stateManager.setEditingSelectedCell(true);
      } else {
        // Go into edit mode and clear selected cells.
        stateManager.setEditing(true);
      }
    }
    // Currently selected cell is being edited.
    else if (stateManager.isEditing) {
      // Cells are selected, so just exit the edit mode for the selected cell
      // without clearing selected cells.
      if (stateManager.isSelecting) {
        stateManager.setEditingSelectedCell(false);
      } else {
        // Cells are not selected, so just clear selected cells.
        stateManager.setEditing(false);
      }
    } else {
      stateManager.setCurrentCell(cell, rowIdx);
    }
  }

  void _onLongPressStart(PlutoGridStateManager stateManager) {
    _setCurrentCell(stateManager, cell, rowIdx);

    stateManager.setSelecting(true);

    if (stateManager.selectingMode.isRow) {
      stateManager.toggleSelectingRow(rowIdx);
    }
  }

  void _onLongPressMoveUpdate(PlutoGridStateManager stateManager) {
    _setCurrentCell(stateManager, cell, rowIdx);

    stateManager.setCurrentSelectingPositionWithOffset(offset);

    stateManager.eventManager!.addEvent(
      PlutoGridScrollUpdateEvent(offset: offset),
    );
  }

  void _onLongPressEnd(PlutoGridStateManager stateManager) {
    _setCurrentCell(stateManager, cell, rowIdx);

    stateManager.setSelecting(false);

    PlutoGridScrollUpdateEvent.stopScroll(
      stateManager,
      PlutoGridScrollUpdateDirection.all,
    );

    if (stateManager.mode.isMultiSelectMode) {
      stateManager.handleOnSelected();
    }
  }

  void _onDoubleTap(PlutoGridStateManager stateManager) {
    stateManager.onRowDoubleTap!(
      PlutoGridOnRowDoubleTapEvent(
        row: stateManager.getRowByIdx(rowIdx)!,
        rowIdx: rowIdx,
        cell: cell,
      ),
    );
  }

  void _onSecondaryTap(PlutoGridStateManager stateManager) {
    stateManager.onRowSecondaryTap!(
      PlutoGridOnRowSecondaryTapEvent(
        row: stateManager.getRowByIdx(rowIdx)!,
        rowIdx: rowIdx,
        cell: cell,
        offset: offset,
      ),
    );
  }

  bool _setKeepFocusAndCurrentCell(PlutoGridStateManager stateManager) {
    if (stateManager.hasFocus) {
      return false;
    }

    stateManager.setKeepFocus(true);

    return stateManager.isCurrentCell(cell);
  }

  void _selecting(PlutoGridStateManager stateManager) {
    bool callOnSelected = stateManager.mode.isMultiSelectMode;

    // Using shift key to select cells.
    if (stateManager.keyPressed.shift) {
      // If not in selecting mode yet for cells, trigger it.
      if (stateManager.selectingMode.isCell) {
        stateManager.setSelecting(true);
      }

      final int? columnIdx = stateManager.columnIndex(column);

      stateManager.setCurrentSelectingPosition(
        cellPosition: PlutoGridCellPosition(
          columnIdx: columnIdx,
          rowIdx: rowIdx,
        ),
      );
    }
    // Selecting cells using meta key.
    else if (stateManager.keyPressed.meta) {
      // Not in selecting mode yet, so set first selection as current cell
      // and toggle selection mode.
      if (!stateManager.isSelecting) {
        stateManager.setCurrentCell(cell, rowIdx);
        stateManager.setSelecting(true);
      }

      if (stateManager.isSelectedCell(cell, column, rowIdx)) {
        stateManager.unselectCell(column, rowIdx);
      } else {
        stateManager.selectCell(column, rowIdx);
      }
    } else if (stateManager.keyPressed.ctrl) {
      stateManager.toggleSelectingRow(rowIdx);
    } else {
      callOnSelected = false;
    }

    if (callOnSelected) {
      stateManager.handleOnSelected();
    }
  }

  void _selectMode(PlutoGridStateManager stateManager) {
    switch (stateManager.mode) {
      case PlutoGridMode.normal:
      case PlutoGridMode.readOnly:
      case PlutoGridMode.popup:
        return;
      case PlutoGridMode.select:
      case PlutoGridMode.selectWithOneTap:
        if (stateManager.isCurrentCell(cell) == false) {
          stateManager.setCurrentCell(cell, rowIdx);

          if (!stateManager.mode.isSelectWithOneTap) {
            return;
          }
        }
        break;
      case PlutoGridMode.multiSelect:
        stateManager.toggleSelectingRow(rowIdx);
        break;
    }

    stateManager.handleOnSelected();
  }

  void _setCurrentCell(
    PlutoGridStateManager stateManager,
    PlutoCell? cell,
    int? rowIdx,
  ) {
    if (stateManager.isCurrentCell(cell) != true) {
      stateManager.setCurrentCell(cell, rowIdx, notify: false);
    }
  }
}

enum PlutoGridGestureType {
  onTapUp,
  onLongPressStart,
  onLongPressMoveUpdate,
  onLongPressEnd,
  onDoubleTap,
  onStartCellDrag,
  onEndCellDrag,
  onEnterCell,
  onSecondaryTap;

  bool get isOnTapUp => this == PlutoGridGestureType.onTapUp;

  bool get isOnLongPressStart => this == PlutoGridGestureType.onLongPressStart;

  bool get isOnLongPressMoveUpdate =>
      this == PlutoGridGestureType.onLongPressMoveUpdate;

  bool get isOnLongPressEnd => this == PlutoGridGestureType.onLongPressEnd;

  bool get isOnDoubleTap => this == PlutoGridGestureType.onDoubleTap;

  bool get isOnSecondaryTap => this == PlutoGridGestureType.onSecondaryTap;

  bool get isOnStartCellDrag => this == PlutoGridGestureType.onStartCellDrag;

  bool get isOnEndCellDrag => this == PlutoGridGestureType.onEndCellDrag;

  bool get isOnEnterCell => this == PlutoGridGestureType.onEnterCell;
}
