import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

abstract class ISelectingState {
  /// Multi-selection state.
  bool get isSelecting;

  /// [selectingMode]
  PlutoGridSelectingMode get selectingMode;

  /// Current position of multi-select cell.
  /// Calculate the currently selected cell and its multi-selection range.
  PlutoGridCellPosition? get currentSelectingPosition;

  /// First position of multi-select cell.
  PlutoGridCellPosition? get firstSelectingPosition;

  /// Position list of currently selected.
  /// Only valid in [PlutoGridSelectingMode.cell].
  ///
  /// ```dart
  /// stateManager.currentSelectingPositionList.forEach((element) {
  ///   final cellValue = stateManager.rows[element.rowIdx].cells[element.field].value;
  /// });
  /// ```
  List<PlutoGridSelectingCellPosition> get currentSelectingPositionList;

  bool get hasCurrentSelectingPosition;

  /// Rows of currently selected.
  /// Only valid in [PlutoGridSelectingMode.row].
  List<PlutoRow> get currentSelectingRows;

  /// String of multi-selected cells.
  /// Preserves the structure of the cells selected by the tabs and the enter key.
  String get currentSelectingText;

  /// Change Multi-Select Status.
  void setSelecting(bool flag, {bool notify = true});

  /// Set the mode to select cells or rows.
  ///
  /// If [PlutoGrid.mode] is [PlutoGridMode.select] or [PlutoGridMode.selectWithOneTap]
  /// Coerced to [PlutoGridSelectingMode.none] regardless of [selectingMode] value.
  ///
  /// When [PlutoGrid.mode] is [PlutoGridMode.multiSelect]
  /// Coerced to [PlutoGridSelectingMode.row] regardless of [selectingMode] value.
  void setSelectingMode(
    PlutoGridSelectingMode selectingMode, {
    bool notify = true,
  });

  void setAllCurrentSelecting();

  /// Sets the position of a multi-selected cell.
  void setCurrentSelectingPosition({
    PlutoGridCellPosition? cellPosition,
    bool notify = true,
  });

  void setCurrentSelectingPositionByCellKey(
    Key? cellKey, {
    bool notify = true,
  });

  /// Sets the position of a multi-selected cell.
  void setCurrentSelectingPositionWithOffset(Offset offset);

  /// Sets the currentSelectingRows by range.
  /// [from] rowIdx of rows.
  /// [to] rowIdx of rows.
  void setCurrentSelectingRowsByRange(int from, int to, {bool notify = true});

  /// Resets currently selected rows and cells.
  void clearCurrentSelecting({bool notify = true});

  /// Select or unselect a row.
  void toggleSelectingRow(int rowIdx, {bool notify = true});

  bool isSelectingInteraction();

  bool isSelectedRow(Key rowKey);

  /// Whether the cell is the currently multi selected cell.
  bool isSelectedCell(PlutoCell cell, PlutoColumn column, int rowIdx);

  /// The action that is selected in the Select dialog
  /// and processed after the dialog is closed.
  void handleAfterSelectingRow(PlutoCell cell, dynamic value);

  void selectCell(PlutoColumn column, int rowIdx);

  void unselectCell(PlutoColumn column, int rowIdx);
}

class _State {
  bool _isSelecting = false;

  PlutoGridSelectingMode _selectingMode = PlutoGridSelectingMode.cell;

  List<PlutoRow> _currentSelectingRows = [];

  PlutoGridCellPosition? _currentSelectingPositionWithShift;

  PlutoGridCellPosition? _firstSelectingPositionWithShiftOrMeta;

  final _selectedPositionsWithMeta = <PlutoGridCellPosition>{};

  final _ignoredPositionsWithMeta = <PlutoGridCellPosition>{};

  bool get isSelectingWithShift =>
      _currentSelectingPositionWithShift != null &&
      _selectedPositionsWithMeta.isEmpty;

  bool get isSelectingWithMeta => _selectedPositionsWithMeta.isNotEmpty;
}

mixin SelectingState implements IPlutoGridState {
  final _State _state = _State();

  @override
  bool get isSelecting => _state._isSelecting;

  @override
  PlutoGridSelectingMode get selectingMode => _state._selectingMode;

  @override
  PlutoGridCellPosition? get currentSelectingPosition =>
      _state._currentSelectingPositionWithShift;

  @override
  PlutoGridCellPosition? get firstSelectingPosition =>
      _state._firstSelectingPositionWithShiftOrMeta;

  @override
  List<PlutoGridSelectingCellPosition> get currentSelectingPositionList {
    // No selections either with shift or meta.
    if ((currentCellPosition == null || currentSelectingPosition == null) &&
        _state._selectedPositionsWithMeta.isEmpty) {
      return [];
    }

    switch (selectingMode) {
      case PlutoGridSelectingMode.cell:
        return _selectingCells();
      case PlutoGridSelectingMode.horizontal:
        return _selectingCellsHorizontally();
      case PlutoGridSelectingMode.row:
      case PlutoGridSelectingMode.none:
        return [];
    }
  }

  @override
  bool get hasCurrentSelectingPosition => currentSelectingPosition != null;

  @override
  List<PlutoRow> get currentSelectingRows => _state._currentSelectingRows;

  @override
  String get currentSelectingText {
    final bool fromSelectingRows =
        selectingMode.isRow && currentSelectingRows.isNotEmpty;

    final bool fromSelectingPosition =
        currentCellPosition != null && currentSelectingPosition != null;

    final bool fromCurrentCell = currentCellPosition != null;

    if (fromSelectingRows) {
      return _selectingTextFromSelectingRows();
    } else if (fromSelectingPosition) {
      return _selectingTextFromSelectingPosition();
    } else if (fromCurrentCell) {
      return _selectingTextFromCurrentCell();
    }

    return '';
  }

  @override
  void setSelecting(bool flag, {bool notify = true}) {
    if (selectingMode.isNone) {
      return;
    }

    if (currentCell == null || isSelecting == flag) {
      return;
    }

    _state._isSelecting = flag;

    if (isEditing == true) {
      setEditing(false, notify: false);
    }

    // Invalidates the previously selected row.
    if (isSelecting) {
      clearCurrentSelecting(notify: false);
    }

    notifyListeners(notify, setSelecting.hashCode);
  }

  @override
  void setSelectingMode(
    PlutoGridSelectingMode selectingMode, {
    bool notify = true,
  }) {
    if (mode.isSingleSelectMode) {
      selectingMode = PlutoGridSelectingMode.none;
    } else if (mode.isMultiSelectMode) {
      selectingMode = PlutoGridSelectingMode.row;
    }

    if (_state._selectingMode == selectingMode) {
      return;
    }

    _state._currentSelectingRows = [];

    _state._currentSelectingPositionWithShift = null;

    _state._firstSelectingPositionWithShiftOrMeta = null;

    _state._ignoredPositionsWithMeta.clear();

    _state._selectedPositionsWithMeta.clear();

    _state._selectingMode = selectingMode;

    notifyListeners(notify, setSelectingMode.hashCode);
  }

  @override
  void setAllCurrentSelecting() {
    if (refRows.isEmpty) {
      return;
    }

    switch (selectingMode) {
      case PlutoGridSelectingMode.cell:
      case PlutoGridSelectingMode.horizontal:
        _setFirstCellAsCurrent();

        setCurrentSelectingPosition(
          cellPosition: PlutoGridCellPosition(
            columnIdx: refColumns.length - 1,
            rowIdx: refRows.length - 1,
          ),
        );
        break;
      case PlutoGridSelectingMode.row:
        if (currentCell == null) {
          _setFirstCellAsCurrent();
        }

        _state._currentSelectingPositionWithShift = PlutoGridCellPosition(
          columnIdx: refColumns.length - 1,
          rowIdx: refRows.length - 1,
        );

        setCurrentSelectingRowsByRange(0, refRows.length - 1);
        break;
      case PlutoGridSelectingMode.none:
      default:
        break;
    }
  }

  @override
  void setCurrentSelectingPosition({
    PlutoGridCellPosition? cellPosition,
    bool notify = true,
  }) {
    if (selectingMode.isNone) {
      return;
    }

    if (currentSelectingPosition == cellPosition) {
      return;
    }

    _state._currentSelectingPositionWithShift =
        isInvalidCellPosition(cellPosition) ? null : cellPosition;

    _state._firstSelectingPositionWithShiftOrMeta ??= currentCellPosition;

    if (currentSelectingPosition != null && selectingMode.isRow) {
      setCurrentSelectingRowsByRange(
        currentRowIdx,
        currentSelectingPosition!.rowIdx,
        notify: false,
      );
    }

    notifyListeners(notify, setCurrentSelectingPosition.hashCode);
  }

  @override
  void setCurrentSelectingPositionByCellKey(
    Key? cellKey, {
    bool notify = true,
  }) {
    if (cellKey == null) {
      return;
    }

    setCurrentSelectingPosition(
      cellPosition: cellPositionByCellKey(cellKey),
      notify: notify,
    );
  }

  @override
  void setCurrentSelectingPositionWithOffset(Offset? offset) {
    if (currentCell == null) {
      return;
    }

    if (_state.isSelectingWithMeta) {
      return;
    }

    final double gridBodyOffsetDy = gridGlobalOffset!.dy +
        PlutoGridSettings.gridBorderWidth +
        headerHeight +
        columnGroupHeight +
        columnHeight +
        columnFilterHeight;

    double currentCellOffsetDy = (currentRowIdx! * rowTotalHeight) +
        gridBodyOffsetDy -
        scroll.vertical!.offset;

    if (gridBodyOffsetDy > offset!.dy) {
      return;
    }

    int rowIdx = (((currentCellOffsetDy - offset.dy) / rowTotalHeight).ceil() -
            currentRowIdx!)
        .abs();

    int? columnIdx;

    final directionalOffset = toDirectionalOffset(offset);
    double currentWidth = isLTR ? gridGlobalOffset!.dx : 0.0;

    final columnIndexes = columnIndexesByShowFrozen;

    final savedRightBlankOffset = rightBlankOffset;
    final savedHorizontalScrollOffset = scroll.horizontal!.offset;

    for (int i = 0; i < columnIndexes.length; i += 1) {
      final column = refColumns[columnIndexes[i]];

      currentWidth += column.width;

      final rightFrozenColumnOffset =
          column.frozen.isEnd && showFrozenColumn ? savedRightBlankOffset : 0;

      if (currentWidth + rightFrozenColumnOffset >
          directionalOffset.dx + savedHorizontalScrollOffset) {
        columnIdx = i;
        break;
      }
    }

    if (columnIdx == null) {
      return;
    }

    setCurrentSelectingPosition(
      cellPosition: PlutoGridCellPosition(
        columnIdx: columnIdx,
        rowIdx: rowIdx,
      ),
    );
  }

  @override
  void setCurrentSelectingRowsByRange(int? from, int? to,
      {bool notify = true}) {
    if (!selectingMode.isRow) {
      return;
    }

    final maxFrom = min(from!, to!);

    final maxTo = max(from, to) + 1;

    if (maxFrom < 0 || maxTo > refRows.length) {
      return;
    }

    _state._currentSelectingRows = refRows.getRange(maxFrom, maxTo).toList();

    notifyListeners(notify, setCurrentSelectingRowsByRange.hashCode);
  }

  @override
  void clearCurrentSelecting({bool notify = true}) {
    _clearCurrentSelectingPosition(notify: false);

    _clearCurrentSelectingRows(notify: false);

    _clearIndividuallySelectedCells(notify: false);

    notifyListeners(notify, clearCurrentSelecting.hashCode);
  }

  @override
  void toggleSelectingRow(int? rowIdx, {notify = true}) {
    if (!selectingMode.isRow) {
      return;
    }

    if (rowIdx == null || rowIdx < 0 || rowIdx > refRows.length - 1) {
      return;
    }

    final PlutoRow row = refRows[rowIdx];

    final keys = Set.from(currentSelectingRows.map((e) => e.key));

    if (keys.contains(row.key)) {
      currentSelectingRows.removeWhere((element) => element.key == row.key);
    } else {
      currentSelectingRows.add(row);
    }

    notifyListeners(notify, toggleSelectingRow.hashCode);
  }

  @override
  bool isSelectingInteraction() {
    if (selectingMode.isNone) {
      return false;
    }

    // No keys pressed
    if (!(keyPressed.shift || keyPressed.ctrl || keyPressed.meta)) {
      return false;
    }

    // No current cell.
    if (currentCell == null) {
      return false;
    }

    return true;
  }

  @override
  bool isSelectedRow(Key? rowKey) {
    if (rowKey == null ||
        !selectingMode.isRow ||
        currentSelectingRows.isEmpty) {
      return false;
    }

    return currentSelectingRows.firstWhereOrNull(
          (element) => element.key == rowKey,
        ) !=
        null;
  }

  @override
  void selectCell(PlutoColumn column, int rowIdx) {
    // Not in selecting state.
    if (!_state._isSelecting) {
      return;
    }

    // Not in cell select mode.
    if (!selectingMode.isCell) {
      return;
    }

    // If selecting a range using shift, change into meta mode which only allows
    // individual selection.
    if (_state.isSelectingWithShift) {
      // Get selecting cells and remove ignored positions.
      final selectingCells = _selectingCells()
        // Remove those that have been ignored.
        ..removeWhere(
          (cellSelectingPosition) => _state._ignoredPositionsWithMeta.contains(
            PlutoGridCellPosition(
              rowIdx: cellSelectingPosition.rowIdx,
              columnIdx: cellSelectingPosition.columnIdx,
            ),
          ),
        );

      // Convert to positions.
      final selectedCellPositions = selectingCells.map(
        (cellSelectingPosition) => PlutoGridCellPosition(
          rowIdx: cellSelectingPosition.rowIdx,
          columnIdx: cellSelectingPosition.columnIdx,
        ),
      );

      // Add all selected cells.
      _state._selectedPositionsWithMeta.addAll(selectedCellPositions);

      // Clear existing.
      _state._ignoredPositionsWithMeta.clear();
    }

    // Add selected cell.
    _state._selectedPositionsWithMeta.add(
      PlutoGridCellPosition(
        columnIdx: columnIndex(column),
        rowIdx: rowIdx,
      ),
    );

    // First cell added, so mark it as first.
    if (_state._selectedPositionsWithMeta.length == 1) {
      _state._firstSelectingPositionWithShiftOrMeta =
          _state._selectedPositionsWithMeta.first;
    }

    notifyListeners(true, selectCell.hashCode);
  }

  @override
  void unselectCell(PlutoColumn column, int rowIdx) {
    // Not in selecting state.
    if (!_state._isSelecting) {
      return;
    }

    // Not in cell select mode.
    if (!selectingMode.isCell) {
      return;
    }

    final cellPosition = PlutoGridCellPosition(
      columnIdx: columnIndex(column),
      rowIdx: rowIdx,
    );

    // When using shift, we can ignore specific cells, but cannot add specific cells,
    // so add it to ignored cell.
    if (_state.isSelectingWithShift) {
      _state._ignoredPositionsWithMeta.add(
        cellPosition,
      );
    } else {
      // Remove added cell since you can individually add and remove cells in this mode.
      _state._selectedPositionsWithMeta.remove(cellPosition);
    }

    notifyListeners(true, unselectCell.hashCode);
  }

  // todo : code cleanup
  @override
  bool isSelectedCell(PlutoCell cell, PlutoColumn column, int rowIdx) {
    if (selectingMode.isNone) {
      return false;
    }

    if (currentCellPosition == null) {
      return false;
    }

    if (currentSelectingPosition == null &&
        _state._selectedPositionsWithMeta.isEmpty) {
      return false;
    }

    if (selectingMode.isCell) {
      final cellPosition = PlutoGridCellPosition(
        columnIdx: columnIndex(column),
        rowIdx: rowIdx,
      );

      // Individually selecting, so just check if it's there.
      if (_state.isSelectingWithMeta) {
        return _state._selectedPositionsWithMeta.contains(cellPosition);
      }

      // Selecting with shift, so we need to check if individually ignored.
      if (_state._ignoredPositionsWithMeta.contains(cellPosition)) {
        return false;
      }

      // Selecting with shift, so we need to check ranges.
      final bool inRangeOfRows = min(
                currentCellPosition!.rowIdx as num,
                currentSelectingPosition!.rowIdx as num,
              ) <=
              rowIdx &&
          rowIdx <=
              max(
                currentCellPosition!.rowIdx!,
                currentSelectingPosition!.rowIdx!,
              );

      if (inRangeOfRows == false) {
        return false;
      }

      final int? columnIdx = columnIndex(column);

      if (columnIdx == null) {
        return false;
      }

      final bool inRangeOfColumns = min(
                currentCellPosition!.columnIdx as num,
                currentSelectingPosition!.columnIdx as num,
              ) <=
              columnIdx &&
          columnIdx <=
              max(
                currentCellPosition!.columnIdx!,
                currentSelectingPosition!.columnIdx!,
              );

      if (inRangeOfColumns == false) {
        return false;
      }

      return true;
    } else if (selectingMode.isHorizontal) {
      int startRowIdx = min(
        currentCellPosition!.rowIdx!,
        currentSelectingPosition!.rowIdx!,
      );

      int endRowIdx = max(
        currentCellPosition!.rowIdx!,
        currentSelectingPosition!.rowIdx!,
      );

      final int? columnIdx = columnIndex(column);

      if (columnIdx == null) {
        return false;
      }

      int? startColumnIdx;

      int? endColumnIdx;

      if (currentCellPosition!.rowIdx! < currentSelectingPosition!.rowIdx!) {
        startColumnIdx = currentCellPosition!.columnIdx;
        endColumnIdx = currentSelectingPosition!.columnIdx;
      } else if (currentCellPosition!.rowIdx! >
          currentSelectingPosition!.rowIdx!) {
        startColumnIdx = currentSelectingPosition!.columnIdx;
        endColumnIdx = currentCellPosition!.columnIdx;
      } else {
        startColumnIdx = min(
          currentCellPosition!.columnIdx!,
          currentSelectingPosition!.columnIdx!,
        );
        endColumnIdx = max(
          currentCellPosition!.columnIdx!,
          currentSelectingPosition!.columnIdx!,
        );
      }

      if (rowIdx == startRowIdx && startRowIdx == endRowIdx) {
        return !(columnIdx < startColumnIdx! || columnIdx > endColumnIdx!);
      } else if (rowIdx == startRowIdx && columnIdx >= startColumnIdx!) {
        return true;
      } else if (rowIdx == endRowIdx && columnIdx <= endColumnIdx!) {
        return true;
      } else if (rowIdx > startRowIdx && rowIdx < endRowIdx) {
        return true;
      }

      return false;
    } else if (selectingMode.isRow) {
      return false;
    } else {
      throw Exception('selectingMode is not handled');
    }
  }

  @override
  void handleAfterSelectingRow(PlutoCell cell, dynamic value) {
    changeCellValue(cell, value, notify: false);

    if (configuration.enableMoveDownAfterSelecting) {
      moveCurrentCell(PlutoMoveDirection.down, notify: false);

      setEditing(true, notify: false);
    }

    setKeepFocus(true, notify: false);

    notifyListeners(true, handleAfterSelectingRow.hashCode);
  }

  List<PlutoGridSelectingCellPosition> _selectingCells() {
    final List<PlutoGridSelectingCellPosition> positions = [];

    final columnIndexes = columnIndexesByShowFrozen;

    // Individually selecting, so just return cells.
    if (_state.isSelectingWithMeta) {
      return _state._selectedPositionsWithMeta.map((cellPosition) {
        final field = refColumns[columnIndexes[cellPosition.columnIdx!]].field;

        return PlutoGridSelectingCellPosition(
          rowIdx: cellPosition.rowIdx,
          field: field,
          columnIdx: cellPosition.columnIdx,
        );
      }).toList();
    }

    int columnStartIdx = min(
        currentCellPosition!.columnIdx!, currentSelectingPosition!.columnIdx!);

    int columnEndIdx = max(
        currentCellPosition!.columnIdx!, currentSelectingPosition!.columnIdx!);

    int rowStartIdx =
        min(currentCellPosition!.rowIdx!, currentSelectingPosition!.rowIdx!);

    int rowEndIdx =
        max(currentCellPosition!.rowIdx!, currentSelectingPosition!.rowIdx!);

    for (int i = rowStartIdx; i <= rowEndIdx; i += 1) {
      for (int j = columnStartIdx; j <= columnEndIdx; j += 1) {
        final String field = refColumns[columnIndexes[j]].field;

        // Skip individually ignored positions.
        if (_state._ignoredPositionsWithMeta
            .contains(PlutoGridCellPosition(columnIdx: j, rowIdx: i))) {
          continue;
        }

        positions.add(PlutoGridSelectingCellPosition(
          rowIdx: i,
          field: field,
          columnIdx: j,
        ));
      }
    }

    return positions;
  }

  List<PlutoGridSelectingCellPosition> _selectingCellsHorizontally() {
    final List<PlutoGridSelectingCellPosition> positions = [];

    final columnIndexes = columnIndexesByShowFrozen;

    final bool firstCurrent = currentCellPosition!.rowIdx! <
            currentSelectingPosition!.rowIdx! ||
        (currentCellPosition!.rowIdx! == currentSelectingPosition!.rowIdx! &&
            currentCellPosition!.columnIdx! <=
                currentSelectingPosition!.columnIdx!);

    PlutoGridCellPosition startCell =
        firstCurrent ? currentCellPosition! : currentSelectingPosition!;

    PlutoGridCellPosition endCell =
        !firstCurrent ? currentCellPosition! : currentSelectingPosition!;

    int columnStartIdx = startCell.columnIdx!;

    int columnEndIdx = endCell.columnIdx!;

    int rowStartIdx = startCell.rowIdx!;

    int rowEndIdx = endCell.rowIdx!;

    final length = columnIndexes.length;

    for (int i = rowStartIdx; i <= rowEndIdx; i += 1) {
      for (int j = 0; j < length; j += 1) {
        if (i == rowStartIdx && j < columnStartIdx) {
          continue;
        }

        final String field = refColumns[columnIndexes[j]].field;

        positions.add(PlutoGridSelectingCellPosition(
          rowIdx: i,
          columnIdx: j,
          field: field,
        ));

        if (i == rowEndIdx && j == columnEndIdx) {
          break;
        }
      }
    }

    return positions;
  }

  String _selectingTextFromSelectingRows() {
    final columnIndexes = columnIndexesByShowFrozen;

    List<String> rowText = [];

    for (final row in currentSelectingRows) {
      List<String> columnText = [];

      for (int i = 0; i < columnIndexes.length; i += 1) {
        final String field = refColumns[columnIndexes[i]].field;

        columnText.add(row.cells[field]!.value.toString());
      }

      rowText.add(columnText.join('\t'));
    }

    return rowText.join('\n');
  }

  String _selectingTextFromSelectingPosition() {
    final columnIndexes = columnIndexesByShowFrozen;

    List<String> rowText = [];

    int columnStartIdx = min(
        currentCellPosition!.columnIdx!, currentSelectingPosition!.columnIdx!);

    int columnEndIdx = max(
        currentCellPosition!.columnIdx!, currentSelectingPosition!.columnIdx!);

    int rowStartIdx =
        min(currentCellPosition!.rowIdx!, currentSelectingPosition!.rowIdx!);

    int rowEndIdx =
        max(currentCellPosition!.rowIdx!, currentSelectingPosition!.rowIdx!);

    for (int i = rowStartIdx; i <= rowEndIdx; i += 1) {
      List<String> columnText = [];

      for (int j = columnStartIdx; j <= columnEndIdx; j += 1) {
        final String field = refColumns[columnIndexes[j]].field;

        columnText.add(refRows[i].cells[field]!.value.toString());
      }

      rowText.add(columnText.join('\t'));
    }

    return rowText.join('\n');
  }

  String _selectingTextFromCurrentCell() {
    return currentCell!.value.toString();
  }

  void _setFirstCellAsCurrent() {
    setCurrentCell(firstCell, 0, notify: false);

    if (isEditing == true) {
      setEditing(false, notify: false);
    }
  }

  void _clearCurrentSelectingPosition({bool notify = true}) {
    if (currentSelectingPosition == null) {
      return;
    }

    _state._currentSelectingPositionWithShift = null;

    _state._firstSelectingPositionWithShiftOrMeta = null;

    if (notify) {
      notifyListeners();
    }
  }

  void _clearCurrentSelectingRows({bool notify = true}) {
    if (currentSelectingRows.isEmpty) {
      return;
    }

    _state._currentSelectingRows = [];

    if (notify) {
      notifyListeners();
    }
  }

  void _clearIndividuallySelectedCells({bool notify = true}) {
    if (_state._ignoredPositionsWithMeta.isEmpty &&
        _state._selectedPositionsWithMeta.isEmpty) {
      return;
    }

    _state._ignoredPositionsWithMeta.clear();
    _state._selectedPositionsWithMeta.clear();

    if (notify) {
      notifyListeners();
    }
  }
}
