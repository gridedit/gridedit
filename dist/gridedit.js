(function() {
  var GridEdit, root,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  GridEdit = (function() {
    function GridEdit(config, actionStack) {
      var cell, key, value, _ref;
      this.config = config;
      this.actionStack = actionStack;
      this.element = document.querySelectorAll(this.config.element || '#gridedit')[0];
      this.contextMenu = new GridEdit.ContextMenu(this);
      this.themeName = this.config.themeName;
      this.customTheme = this.config.themeTemplate;
      this.theme = new GridEdit.Theme(this.themeName, this.customTheme);
      this.draggingRow = null;
      this.lastDragOver = null;
      this.lastDragOverIsBeforeFirstRow = false;
      this.lastClickCell = null;
      this.headers = [];
      this.rows = [];
      this.subtotalRows = [];
      this.cols = [];
      this.source = this.config.rows;
      this.redCells = [];
      this.activeCells = [];
      this.copiedCells = null;
      this.selectionStart = null;
      this.selectionEnd = null;
      this.selectedCol = null;
      this.openCell = null;
      this.state = "ready";
      this.mobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
      this.topOffset = !this.config.topOffset ? 0 : this.config.topOffset;
      if (this.config.custom) {
        _ref = this.config.custom;
        for (key in _ref) {
          value = _ref[key];
          if (key in this.config.custom) {
            this.set(key, value);
          }
        }
        delete this.config.custom;
      }
      if (this.config.initialize) {
        this.init();
      }
      this.copiedCellMatrix = null;
      if (!this.actionStack) {
        this.actionStack = new GridEdit.ActionStack(this);
      }
      if (this.config.selectedCell) {
        cell = this.getCell(this.config.selectedCell[0], this.config.selectedCell[1]);
        if (cell) {
          cell.makeActive();
        }
        this.config.selectedCell = void 0;
      }
    }

    GridEdit.prototype.init = function() {
      if (this.config.beforeInit) {
        this.config.beforeInit();
      }
      this.build();
      this.events();
      this.render();
      if (this.config.afterInit) {
        this.config.afterInit();
      }
    };

    GridEdit.prototype.build = function() {
      var col, colAttributes, ge, handleHeader, i, row, rowAttributes, table, tbody, thead, tr, _i, _j, _len, _len1, _ref, _ref1;
      tr = document.createElement('tr');
      if (this.config.includeRowHandles) {
        handleHeader = document.createElement('th');
        tr.appendChild(handleHeader);
      }
      _ref = this.config.cols;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        colAttributes = _ref[i];
        col = new GridEdit.Column(colAttributes, this);
        this.cols.push(col);
        tr.appendChild(col.element);
      }
      thead = document.createElement('thead');
      ge = this;
      thead.ondragenter = function() {
        var prevRow;
        ge.lastDragOverIsBeforeFirstRow = true;
        prevRow = ge.lastDragOver;
        prevRow.element.style.borderBottom = prevRow.oldBorderBottom;
        return prevRow.element.style.borderTop = ge.ge.theme.borders.dragBorderStyle;
      };
      thead.ondragleave = function() {
        var firstRow;
        firstRow = ge.rows[0];
        return firstRow.element.style.borderTop = firstRow.oldBorderTop;
      };
      thead.appendChild(tr);
      tbody = document.createElement('tbody');
      _ref1 = this.source;
      for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
        rowAttributes = _ref1[i];
        switch (rowAttributes.gridEditRowType) {
          case 'static':
            row = new GridEdit.StaticRow(rowAttributes, this);
            break;
          case 'subtotal':
            row = new GridEdit.SubTotalRow(rowAttributes, this);
            break;
          case 'heading':
            row = new GridEdit.HeaderRow(rowAttributes, this);
            break;
          default:
            row = new GridEdit.GenericRow(rowAttributes, this);
        }
        this.rows.push(row);
        tbody.appendChild(row.element);
      }
      table = document.createElement('table');
      GridEdit.Utilities.prototype.setAttributes(table, {
        id: 'editable-grid',
        "class": this.config.tableClass
      });
      table.appendChild(thead);
      table.appendChild(tbody);
      return this.tableEl = table;
    };

    GridEdit.prototype.rebuild = function(newConfig) {
      var actionStack, config, optionKey, optionValue;
      if (newConfig == null) {
        newConfig = null;
      }
      config = Object.create(this.config);
      if (newConfig !== null) {
        for (optionKey in newConfig) {
          optionValue = newConfig[optionKey];
          config[optionKey] = newConfig[optionKey];
        }
      }
      actionStack = this.actionStack;
      this.destroy();
      return this.constructor(config, actionStack);
    };

    GridEdit.prototype.hideControl = function() {
      if (this.openCell) {
        return this.openCell.edit(this.openCell.control.value);
      }
    };

    GridEdit.prototype.events = function() {
      var table;
      table = this;
      document.onkeydown = function(e) {
        var cmd, ctrl, key, shift;
        if (table.activeCell()) {
          key = e.keyCode;
          shift = e.shiftKey;
          ctrl = e.ctrlKey;
          cmd = e.metaKey;
          if (cmd || ctrl) {
            if (key && key !== 91 && key !== 92) {
              if (table.contextMenu.actionCallbacks.byControl[key]) {
                e.preventDefault();
                return table.contextMenu.actionCallbacks.byControl[key](e, table);
              }
            }
          } else {
            switch (key) {
              case 8:
                if (!table.openCell) {
                  e.preventDefault();
                  table["delete"]();
                }
                break;
              case 9:
                e.preventDefault();
                if (shift) {
                  return table.moveTo(table.previousCell());
                } else {
                  return table.moveTo(table.nextCell());
                }
                break;
              case 13:
                table.activeCell().onReturnKeyPress();
                break;
              case 16:
                break;
              case 32:
                if (!table.openCell) {
                  table.activeCell().onSpaceKeyPress();
                }
                break;
              case 37:
                table.moveTo(table.previousCell());
                break;
              case 38:
                table.moveTo(table.aboveCell());
                break;
              case 39:
                if (!table.activeCell().isBeingEdited()) {
                  table.moveTo(table.nextCell());
                }
                break;
              case 40:
                table.moveTo(table.belowCell());
                break;
              case 46:
                if (!table.openCell) {
                  e.preventDefault();
                  table["delete"]();
                  break;
                }
                break;
              default:
                if (__indexOf.call([96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111], key) >= 0) {
                  key = key - 48;
                }
                return table.openCellAndPopulateInitialValue(shift, key);
            }
          }
        }
      };
      window.onresize = function() {
        if (table.openCell) {
          return GridEdit.Utilities.prototype.setStyles(table.openCell.control, table.openCell.position());
        }
      };
      window.onscroll = function() {
        if (table.openCell) {
          return table.openCell.reposition();
        }
      };
      this.tableEl.oncontextmenu = function(e) {
        return false;
      };
      return document.onclick = function(e) {
        var activeCell;
        activeCell = table.firstActiveCell();
        if (!table.isDescendant(e.target || table.contextMenu.isVisible())) {
          if (e.target !== (activeCell != null ? activeCell.control : void 0)) {
            if (activeCell != null ? activeCell.isBeingEdited() : void 0) {
              if (activeCell != null) {
                activeCell.edit(activeCell != null ? activeCell.control.value : void 0);
              }
            }
            GridEdit.Utilities.prototype.clearActiveCells(table);
          }
        }
        return table.contextMenu.hide();
      };
    };

    GridEdit.prototype.render = function() {
      if (this.element.hasChildNodes()) {
        this.element = document.querySelectorAll(this.config.element || '#gridedit')[0];
      }
      return this.element.appendChild(this.tableEl);
    };

    GridEdit.prototype.getCell = function(x, y) {
      var e;
      try {
        return this.rows[x].cells[y];
      } catch (_error) {
        e = _error;
      }
    };

    GridEdit.prototype.set = function(key, value) {
      if (key !== void 0) {
        return this.config[key] = value;
      }
    };

    GridEdit.prototype.activeCell = function() {
      if (this.activeCells.length > 1) {
        return this.activeCells;
      } else {
        return this.activeCells[0];
      }
    };

    GridEdit.prototype.firstActiveCell = function() {
      return this.activeCells[0];
    };

    GridEdit.prototype.nextCell = function() {
      var _ref;
      return (_ref = this.firstActiveCell()) != null ? _ref.next() : void 0;
    };

    GridEdit.prototype.previousCell = function() {
      var _ref;
      return (_ref = this.firstActiveCell()) != null ? _ref.previous() : void 0;
    };

    GridEdit.prototype.aboveCell = function() {
      var _ref;
      return (_ref = this.firstActiveCell()) != null ? _ref.above() : void 0;
    };

    GridEdit.prototype.belowCell = function() {
      var _ref;
      return (_ref = this.firstActiveCell()) != null ? _ref.below() : void 0;
    };

    GridEdit.prototype.moveTo = function(toCell, fromCell) {
      var beforeCellNavigateReturnVal, direction, directionModifier, newY, oldY;
      if (toCell) {
        if (fromCell === void 0) {
          fromCell = toCell.table.firstActiveCell();
        }
        direction = toCell.table.getDirection(fromCell, toCell);
        if (toCell.beforeNavigateTo) {
          beforeCellNavigateReturnVal = toCell.beforeNavigateTo(toCell, fromCell, direction);
        }
        if (beforeCellNavigateReturnVal !== false) {
          if (!toCell.isVisible()) {
            oldY = toCell.table.activeCell().address[0];
            newY = toCell.address[0];
            directionModifier = 1;
            if (newY < oldY) {
              directionModifier = -1;
            }
            window.scrollBy(0, (toCell != null ? toCell.position().height : void 0) * directionModifier);
          }
          toCell.makeActive();
        }
      }
      return false;
    };

    GridEdit.prototype.getDirection = function(fromCell, toCell) {
      var direction, fromAddressX, fromAddressY, toAddressX, toAddressY;
      fromAddressY = fromCell.address[0];
      toAddressY = toCell.address[0];
      fromAddressX = fromCell.address[1];
      toAddressX = toCell.address[1];
      if (fromAddressY === toAddressY) {
        if (fromAddressX > toAddressX) {
          direction = "left";
        } else if (fromAddressX < toAddressX) {
          direction = "right";
        } else {
          console.log("Cannot calculate direction going from cell " + fromCell.address + " to cell " + toCell.address);
        }
      } else if (fromAddressY > toAddressY) {
        direction = "up";
      } else if (fromAddressY < toAddressY) {
        direction = "down";
      } else {
        console.log("Cannot calculate direction going from cell " + fromCell.address + " to cell " + toCell.address);
      }
      return direction;
    };

    GridEdit.prototype.edit = function(cell, newValue) {
      if (newValue == null) {
        newValue = null;
      }
      if (newValue !== null) {
        return cell != null ? cell.cellTypeObject.edit(newValue) : void 0;
      } else {
        cell.cellTypeObject.edit();
        return false;
      }
    };

    GridEdit.prototype["delete"] = function() {
      var cell, _i, _len, _ref, _results;
      _ref = this.activeCells;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        cell = _ref[_i];
        _results.push(cell.value(''));
      }
      return _results;
    };

    GridEdit.prototype.clearActiveCells = function() {
      return GridEdit.Utilities.prototype.clearActiveCells(this);
    };

    GridEdit.prototype.setSelection = function() {
      var cell, col, colRange, row, rowRange, _i, _j, _k, _l, _len, _len1, _len2, _m, _ref, _ref1, _ref2, _ref3, _ref4, _results, _results1;
      if (this.selectionStart && this.selectionEnd && this.selectionStart !== this.selectionEnd) {
        _ref = this.activeCells;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          cell = _ref[_i];
          cell.showInactive();
        }
        this.activeCells = [];
        rowRange = (function() {
          _results = [];
          for (var _j = _ref1 = this.selectionStart.address[0], _ref2 = this.selectionEnd.address[0]; _ref1 <= _ref2 ? _j <= _ref2 : _j >= _ref2; _ref1 <= _ref2 ? _j++ : _j--){ _results.push(_j); }
          return _results;
        }).apply(this);
        colRange = (function() {
          _results1 = [];
          for (var _k = _ref3 = this.selectionStart.address[1], _ref4 = this.selectionEnd.address[1]; _ref3 <= _ref4 ? _k <= _ref4 : _k >= _ref4; _ref3 <= _ref4 ? _k++ : _k--){ _results1.push(_k); }
          return _results1;
        }).apply(this);
        for (_l = 0, _len1 = rowRange.length; _l < _len1; _l++) {
          row = rowRange[_l];
          for (_m = 0, _len2 = colRange.length; _m < _len2; _m++) {
            col = colRange[_m];
            this.rows[row].cells[col].addToSelection();
          }
        }
      }
    };

    GridEdit.prototype.data = function() {
      var cell, data, row, rowData, _i, _j, _len, _len1, _ref, _ref1;
      data = [];
      _ref = this.rows;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        row = _ref[_i];
        rowData = [];
        _ref1 = row.cells;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          cell = _ref1[_j];
          rowData.push(cell.cellTypeObject.value());
        }
        data.push(rowData);
      }
      return data;
    };

    GridEdit.prototype.repopulate = function() {
      var cell, row, _i, _len, _ref, _results;
      _ref = this.rows;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        row = _ref[_i];
        _results.push((function() {
          var _j, _len1, _ref1, _results1;
          _ref1 = row.cells;
          _results1 = [];
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            cell = _ref1[_j];
            _results1.push(cell.value(cell.source[cell.valueKey]));
          }
          return _results1;
        })());
      }
      return _results;
    };

    GridEdit.prototype.destroy = function() {
      var key, _results;
      this.element.removeChild(this.tableEl);
      _results = [];
      for (key in this) {
        _results.push(delete this[key]);
      }
      return _results;
    };

    GridEdit.prototype.isDescendant = function(child) {
      var node;
      node = child.parentNode;
      while (node != null) {
        if (node === this.tableEl) {
          return true;
        }
        node = node.parentNode;
      }
      return false;
    };

    GridEdit.prototype.addToStack = function(action) {
      return this.actionStack.addAction(action);
    };

    GridEdit.prototype.undo = function() {
      return this.actionStack.undo();
    };

    GridEdit.prototype.redo = function() {
      return this.actionStack.redo();
    };

    GridEdit.prototype.moveRow = function(rowToMoveIndex, newIndex, addToStack) {
      var row;
      if (addToStack == null) {
        addToStack = true;
      }
      row = this.source[rowToMoveIndex];
      this.source.splice(rowToMoveIndex, 1);
      this.source.splice(newIndex, 0, row);
      if (addToStack) {
        this.addToStack({
          type: 'move-row',
          oldIndex: rowToMoveIndex,
          newIndex: newIndex
        });
      }
      return this.rebuild({
        rows: this.source,
        initialize: true,
        selectedCell: [newIndex, 0]
      });
    };

    GridEdit.prototype.addRow = function(index, addToStack, rowObject) {
      var c, row, _i, _len, _ref;
      if (addToStack == null) {
        addToStack = true;
      }
      if (rowObject == null) {
        rowObject = false;
      }
      if (rowObject) {
        row = rowObject;
      } else {
        row = {};
        _ref = this.cols;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          c = _ref[_i];
          row[c.valueKey] = c.defaultValue || '';
        }
      }
      if (index || index === 0) {
        this.source.splice(index, 0, row);
      } else {
        index = this.source.length - 1;
        this.source.push(row);
      }
      if (addToStack) {
        this.addToStack({
          type: 'add-row',
          index: index,
          rowObject: rowObject
        });
      }
      return this.rebuild({
        rows: this.source,
        initialize: true,
        selectedCell: [index, 0]
      });
    };

    GridEdit.prototype.insertBelow = function() {
      var cell;
      cell = this.contextMenu.getTargetPasteCell();
      return this.addRow(cell.address[0] + 1);
    };

    GridEdit.prototype.insertAbove = function() {
      var cell;
      cell = this.contextMenu.getTargetPasteCell();
      return this.addRow(cell.address[0]);
    };

    GridEdit.prototype.removeRow = function(index, addToStack) {
      var row, rowObject, rows;
      if (addToStack == null) {
        addToStack = true;
      }
      rowObject = this.source[index];
      row = this.rows[index];
      rows = this.source.splice(index, 1);
      if (addToStack) {
        this.addToStack({
          type: 'remove-row',
          index: index,
          rowObject: rowObject
        });
      }
      return this.rebuild({
        rows: this.source,
        initialize: true,
        selectedCell: [index, 0]
      });
    };

    GridEdit.prototype.selectRow = function(e, index) {
      var cmd, ctrl, currentRowIndex, diff, row, shift, _i, _j, _len, _len1, _ref, _ref1, _results, _results1;
      if (this.activeCell() && e) {
        currentRowIndex = this.activeCells[0].address[0];
        shift = e.shiftKey;
        ctrl = e.ctrlKey;
        cmd = e.metaKey;
        if (!(ctrl || cmd)) {
          GridEdit.Utilities.prototype.clearActiveCells(this);
        }
        if (shift) {
          diff = currentRowIndex - index;
          if (diff < 0) {
            _ref = this.rows.slice(currentRowIndex, +index + 1 || 9e9);
            _results = [];
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              row = _ref[_i];
              _results.push(row.select());
            }
            return _results;
          } else {
            _ref1 = this.rows.slice(index, +currentRowIndex + 1 || 9e9);
            _results1 = [];
            for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
              row = _ref1[_j];
              _results1.push(row.select());
            }
            return _results1;
          }
        } else {
          row = this.rows[index];
          return row.select();
        }
      } else {
        row = this.rows[index];
        return row.select();
      }
    };

    GridEdit.prototype.calculateSubtotals = function() {
      var row, _i, _len, _ref, _results;
      _ref = this.subtotalRows;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        row = _ref[_i];
        _results.push(row.calculate());
      }
      return _results;
    };

    GridEdit.prototype.openCellAndPopulateInitialValue = function(shift, key) {
      if (!this.openCell) {
        return this.activeCell().onKeyPress(GridEdit.Utilities.prototype.valueFromKey(key, shift));
      }
    };

    return GridEdit;

  })();

  root = typeof exports !== "undefined" && exports !== null ? exports : window;

  root.GridEdit = GridEdit;

}).call(this);
;(function() {
  GridEdit.ActionStack = (function() {
    function ActionStack(table) {
      this.table = table;
      this.index = -1;
      this.actions = [];
    }

    ActionStack.prototype.getCell = function(action) {
      return this.table.getCell(action.address[0], action.address[1]);
    };

    ActionStack.prototype.addAction = function(actionObject) {
      if (this.actions.length > 0 && this.index < this.actions.length - 1) {
        this.actions = this.actions.splice(0, this.index + 1);
      }
      this.actions.push(actionObject);
      return this.index++;
    };

    ActionStack.prototype.undo = function() {
      var action, cell;
      if (this.index > -1) {
        this.index--;
        action = this.actions[this.index + 1];
        switch (action.type) {
          case 'cell-edit':
            cell = this.getCell(action);
            cell.value(action.oldValue, false);
            break;
          case 'cut':
            action.grid.undo(false, false);
            break;
          case 'paste':
            action.grid.undo(action.x, action.y);
            break;
          case 'fill':
            action.grid.undo(false, false);
            break;
          case 'add-row':
            this.table.removeRow(action.index, false);
            break;
          case 'remove-row':
            this.table.addRow(action.index, false, action.rowObject);
            break;
          case 'move-row':
            this.table.moveRow(action.newIndex, action.oldIndex, false);
            break;
        }
      }
    };

    ActionStack.prototype.redo = function() {
      var action, cell;
      if (this.index < this.actions.length - 1) {
        this.index++;
        action = this.actions[this.index];
        switch (action.type) {
          case 'cell-edit':
            cell = this.table.getCell(action.address[0], action.address[1]);
            cell.value(action.newValue, false);
            break;
          case 'cut':
            action.grid.apply(false, false);
            break;
          case 'paste':
            action.grid.apply(action.x, action.y);
            break;
          case 'fill':
            action.grid.apply(false, false);
            break;
          case 'add-row':
            this.table.addRow(action.index, false, action.rowObject);
            break;
          case 'remove-row':
            this.table.removeRow(action.index, false);
            break;
          case 'move-row':
            this.table.moveRow(action.oldIndex, action.newIndex, false);
            break;
        }
      }
    };

    return ActionStack;

  })();

}).call(this);
;(function() {
  GridEdit.ContextMenu = (function() {
    function ContextMenu(table) {
      var action, actionName, ctrlOrCmd, _i, _len, _ref, _ref1, _ref2;
      this.table = table;
      this.userDefinedActions = this.table.config.contextMenuItems;
      this.userDefinedOrder = this.table.config.contextMenuOrder;
      ctrlOrCmd = /Mac/.test(navigator.platform) ? 'Cmd' : 'Ctrl';
      this.actionNodes = {};
      this.actionCallbacks = {
        byName: {},
        byControl: {}
      };
      this.borderedCells = [];
      this.defaultActions = {
        cut: {
          name: 'Cut',
          shortCut: ctrlOrCmd + '+X',
          callback: this.cut
        },
        copy: {
          name: 'Copy',
          shortCut: ctrlOrCmd + '+C',
          callback: this.copy
        },
        paste: {
          name: 'Paste',
          shortCut: ctrlOrCmd + '+V',
          callback: this.paste
        },
        undo: {
          name: 'Undo',
          shortCut: ctrlOrCmd + '+Z',
          callback: this.undo
        },
        redo: {
          name: 'Redo',
          shortCut: ctrlOrCmd + '+Y',
          callback: this.redo
        },
        fill: {
          name: 'Fill',
          shortCut: '',
          hasDivider: true,
          callback: this.fill
        },
        selectAll: {
          name: 'Select All',
          shortCut: ctrlOrCmd + '+A',
          callback: this.selectAll
        },
        insertBelow: {
          name: 'Insert Row Below',
          shortCut: '',
          callback: this.insertBelow
        },
        insertAbove: {
          name: 'Insert Row Above',
          shortCut: '',
          callback: this.insertAbove
        },
        removeRow: {
          name: 'Remove Row',
          shortCut: '',
          callback: this.removeRow
        }
      };
      this.element = document.createElement('div');
      this.element.style.position = 'fixed';
      this.menu = document.createElement('ul');
      GridEdit.Utilities.prototype.setAttributes(this.menu, {
        "class": 'dropdown-menu',
        role: 'menu',
        'aria-labelledby': 'aria-labelledby',
        style: 'display:block;position:static;margin-bottom:5px;'
      });
      if (this.userDefinedOrder) {
        _ref = this.userDefinedOrder;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          actionName = _ref[_i];
          if (this.userDefinedActions) {
            action = this.userDefinedActions[actionName] || this.defaultActions[actionName];
          } else {
            action = this.defaultActions[actionName];
          }
          if (action) {
            this.addAction(action);
          }
        }
      } else {
        _ref1 = this.defaultActions;
        for (actionName in _ref1) {
          action = _ref1[actionName];
          if (this.userDefinedActions && (this.userDefinedActions[actionName] || this.userDefinedActions[actionName] === false)) {
            continue;
          }
          this.addAction(action);
        }
        _ref2 = this.userDefinedActions;
        for (actionName in _ref2) {
          action = _ref2[actionName];
          this.addAction(action);
        }
      }
      this.element.appendChild(this.menu);
      this.events(this);
    }

    ContextMenu.prototype.addDivider = function() {
      var divider;
      divider = document.createElement('li');
      GridEdit.Utilities.prototype.setAttributes(divider, {
        "class": 'divider'
      });
      return this.menu.appendChild(divider);
    };

    ContextMenu.prototype.addAction = function(action) {
      var a, code, div, key, li, shortCut, span;
      li = document.createElement('li');
      li.setAttribute('name', action.name);
      div = document.createElement('div');
      span = document.createElement('span');
      span.textContent = action.shortCut;
      GridEdit.Utilities.prototype.setAttributes(span, {
        style: "float: right !important;"
      });
      a = document.createElement('a');
      a.textContent = action.name;
      a.setAttribute('name', action.name);
      GridEdit.Utilities.prototype.setAttributes(a, {
        "class": 'enabled',
        tabIndex: '-1'
      });
      if (action.hasDivider) {
        this.addDivider();
      }
      a.appendChild(span);
      li.appendChild(a);
      this.actionNodes[action.name] = li;
      this.actionCallbacks.byName[action.name] = action.callback;
      shortCut = action.shortCut;
      if (shortCut) {
        if (/(ctrl|cmd)/i.test(shortCut)) {
          key = shortCut.split('+')[1];
          code = key.charCodeAt(0);
          this.actionCallbacks.byControl[code] = action.callback;
        }
      }
      return this.menu.appendChild(li);
    };

    ContextMenu.prototype.show = function(x, y, cell) {
      this.cell = cell;
      if (!cell.isActive()) {
        cell.makeActive();
      }
      this.cells = cell.table.activeCells;
      GridEdit.Utilities.prototype.setStyles(this.element, {
        left: x,
        top: y
      });
      return this.table.tableEl.appendChild(this.element);
    };

    ContextMenu.prototype.hide = function() {
      if (this.isVisible()) {
        return this.table.tableEl.removeChild(this.element);
      }
    };

    ContextMenu.prototype.isVisible = function() {
      return this.element.parentNode != null;
    };

    ContextMenu.prototype.getTargetPasteCell = function() {
      return this.table.activeCells.sort(this.sortFunc)[0];
    };

    ContextMenu.prototype.sortFunc = function(a, b) {
      return a.address[0] - b.address[0];
    };

    ContextMenu.prototype.displayBorders = function() {
      if (this.table.copiedGridChange) {
        return this.table.copiedGridChange.displayBorders();
      }
    };

    ContextMenu.prototype.hideBorders = function() {
      if (this.table.copiedGridChange) {
        return this.table.copiedGridChange.removeBorders();
      }
    };

    ContextMenu.prototype.cut = function(e, table) {
      var gridChange, menu;
      menu = table.contextMenu;
      menu.hideBorders();
      gridChange = new GridEdit.GridChange(table.activeCells, 'ge-blank');
      gridChange.apply(false, false);
      table.copiedGridChange = gridChange;
      table.addToStack({
        type: 'cut',
        grid: gridChange
      });
      menu.displayBorders();
      return menu.hide();
    };

    ContextMenu.prototype.copy = function(e, table) {
      var menu;
      menu = table.contextMenu;
      table.copiedGridChange = new GridEdit.GridChange(table.activeCells);
      menu.displayBorders();
      return menu.hide();
    };

    ContextMenu.prototype.paste = function(e, table) {
      var cell, gridChange, menu, x, y;
      menu = table.contextMenu;
      menu.hide();
      cell = menu.getTargetPasteCell();
      if (cell.editable) {
        gridChange = table.copiedGridChange;
        x = cell.address[0];
        y = cell.address[1];
        gridChange.apply(x, y);
        return table.addToStack({
          type: 'paste',
          grid: gridChange,
          x: x,
          y: y
        });
      }
    };

    ContextMenu.prototype.fill = function(e, table) {
      var cell, fillValue, gridChange, menu;
      menu = table.contextMenu;
      cell = menu.getTargetPasteCell();
      fillValue = cell.value();
      gridChange = new GridEdit.GridChange(table.activeCells, fillValue);
      gridChange.apply(false, false);
      table.addToStack({
        type: 'fill',
        grid: gridChange
      });
      return menu.hide();
    };

    ContextMenu.prototype.selectAll = function(e, table) {
      var cell, row, _i, _len, _ref, _results;
      table.clearActiveCells();
      _ref = table.rows;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        row = _ref[_i];
        _results.push((function() {
          var _j, _len1, _ref1, _results1;
          _ref1 = row.cells;
          _results1 = [];
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            cell = _ref1[_j];
            _results1.push(cell.addToSelection());
          }
          return _results1;
        })());
      }
      return _results;
    };

    ContextMenu.prototype.insertBelow = function(e, table) {
      return table.insertBelow();
    };

    ContextMenu.prototype.insertAbove = function(e, table) {
      return table.insertAbove();
    };

    ContextMenu.prototype.removeRow = function(e, table) {
      var cell;
      cell = table.contextMenu.getTargetPasteCell();
      return table.removeRow(cell.row.index);
    };

    ContextMenu.prototype.undo = function(e, table) {
      return table.undo();
    };

    ContextMenu.prototype.redo = function(e, table) {
      return table.redo();
    };

    ContextMenu.prototype.toggle = function(action) {
      var classes;
      classes = this.actionNodes[action].classList;
      classes.toggle('enabled');
      return classes.toggle('disabled');
    };

    ContextMenu.prototype.events = function(menu) {
      return this.element.onclick = function(e) {
        var actionName;
        actionName = e.target.getAttribute('name');
        return menu.actionCallbacks.byName[actionName](e, menu.table);
      };
    };

    return ContextMenu;

  })();

}).call(this);
;(function() {
  GridEdit.Utilities = (function() {
    function Utilities() {}

    Utilities.prototype.setAttributes = function(el, attrs) {
      var key, value, _results;
      _results = [];
      for (key in attrs) {
        value = attrs[key];
        if (value) {
          _results.push(el.setAttribute(key, value));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Utilities.prototype.setStyles = function(el, styles) {
      var key, value, _results;
      _results = [];
      for (key in styles) {
        value = styles[key];
        _results.push(el.style[key] = "" + value + "px");
      }
      return _results;
    };

    Utilities.prototype.clearActiveCells = function(table) {
      var activeCell, activeCells, index, redCell, redCells, _i, _j, _len, _len1;
      redCells = table.redCells;
      activeCells = table.activeCells;
      if (redCells.length > 0) {
        for (index = _i = 0, _len = redCells.length; _i < _len; index = ++_i) {
          redCell = redCells[index];
          if (redCell != null) {
            redCell.makeInactive();
          }
        }
        table.redCells = [];
      }
      if (activeCells.length > 0) {
        for (index = _j = 0, _len1 = activeCells.length; _j < _len1; index = ++_j) {
          activeCell = activeCells[index];
          if (activeCell != null) {
            activeCell.makeInactive();
          }
          if (activeCell != null) {
            activeCell.hideControl();
          }
        }
        table.activeCells = [];
      }
      table.selectionStart = null;
      table.selectionEnd = null;
      table.contextMenu.hide();
      if (table.selectedCol) {
        return table.selectedCol.makeInactive();
      }
    };

    Utilities.prototype.capitalize = function(string) {
      return string.toLowerCase().replace(/\b./g, function(a) {
        return a.toUpperCase();
      });
    };

    Utilities.prototype.valueFromKey = function(key, shift) {
      var char;
      char = String.fromCharCode(key);
      if (shift) {
        return char;
      } else {
        return char.toLowerCase();
      }
    };

    return Utilities;

  })();

}).call(this);
;(function() {
  GridEdit.Column = (function() {
    function Column(attributes, table) {
      var format, key, value, _ref;
      this.attributes = attributes;
      this.table = table;
      this.id = this.index = this.table.cols.length;
      this.defaultValue = this.attributes.defaultValue;
      this.cellClass = this.attributes.cellClass;
      this.cells = [];
      this.element = document.createElement('th');
      this.textNode = document.createTextNode(this.attributes.label);
      this.element.appendChild(this.textNode);
      format = this.attributes.format;
      this.format = function(v) {
        if (format) {
          return format(v);
        } else {
          return v;
        }
      };
      _ref = this.attributes;
      for (key in _ref) {
        value = _ref[key];
        this[key] = value;
      }
      delete this.attributes;
      this.events();
    }

    Column.prototype.next = function() {
      return this.table.cols[this.index + 1];
    };

    Column.prototype.previous = function() {
      return this.table.cols[this.index - 1];
    };

    Column.prototype.makeActive = function() {
      this.element.classList.add('active');
      return this.table.selectedCol = this;
    };

    Column.prototype.makeInactive = function() {
      this.element.classList.remove('active');
      return this.table.selectedCol = null;
    };

    Column.prototype.events = function() {
      var col, table;
      col = this;
      table = col.table;
      this.element.onclick = function(e) {
        var cell, _i, _len, _ref, _results;
        GridEdit.Utilities.prototype.clearActiveCells(table);
        col.makeActive();
        _ref = col.cells;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          cell = _ref[_i];
          _results.push(cell.addToSelection());
        }
        return _results;
      };
      return this.element.onmousedown = function(e) {
        if (e.which === 3) {
          table.contextMenu.show(e.x, e.y, col.cells[0]);
          return;
        }
        return false;
      };
    };

    return Column;

  })();

}).call(this);
;(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  GridEdit.Row = (function() {
    function Row(attributes, table) {
      var row;
      this.attributes = attributes;
      this.table = table;
      this.id = this.table.rows.length;
      this.cells = [];
      this.index = this.table.rows.length;
      this.element = document.createElement('tr');
      this.cssClass = this.attributes.cssClass;
      if (this.cssClass) {
        this.element.className = this.cssClass;
      }
      this.oldBorderBottom = this.element.style.borderBottom;
      this.oldBorderTop = this.element.style.borderTop;
      this.type = this.attributes.gridEditRowType;
      table = this.table;
      row = this;
      this.element.ondragenter = function(e) {
        var prevRow;
        table.lastDragOverIsBeforeFirstRow = false;
        prevRow = table.lastDragOver;
        if (prevRow) {
          if (row.index !== 0 && prevRow.index === row.index) {

          } else {
            prevRow.element.style.borderBottom = row.oldBorderBottom;
            row.element.style.borderBottom = table.theme.borders.dragBorderStyle;
          }
        } else {
          row.element.style.borderBottom = table.theme.borders.dragBorderStyle;
        }
        return table.lastDragOver = row;
      };
      this.includeRowHandles = this.table.config.includeRowHandles;
      GridEdit.Utilities.prototype.setAttributes(this.element, {
        id: "row-" + this.id
      });
    }

    Row.prototype.createCell = function(value) {
      var cell, col, index, type;
      index = this.cells.length;
      col = this.table.cols[index];
      type = col.type;
      cell;
      switch (type) {
        case 'string':
          cell = new GridEdit.StringCell(value, this);
          break;
        case 'number':
          cell = new GridEdit.NumberCell(value, this);
          break;
        case 'date':
          cell = new GridEdit.DateCell(value, this);
          break;
        case 'html':
          cell = new GridEdit.HTMLCell(value, this);
          break;
        case 'select':
          cell = new GridEdit.SelectCell(value, this);
          break;
        case 'textarea':
          cell = new GridEdit.TextAreaCell(value, this);
          break;
        case 'checkbox':
          cell = new GridEdit.CheckBoxCell(value, this);
          break;
        default:
          cell = new GridEdit.GenericCell(value, this);
          break;
      }
      return cell;
    };

    Row.prototype.below = function() {
      return this.table.rows[this.index + 1];
    };

    Row.prototype.above = function() {
      return this.table.rows[this.index - 1];
    };

    Row.prototype.select = function() {
      var cell, _i, _len, _ref, _results;
      _ref = this.cells;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        cell = _ref[_i];
        _results.push(cell.addToSelection());
      }
      return _results;
    };

    Row.prototype.afterEdit = function() {
      return this.table.calculateSubtotals();
    };

    Row.prototype.addHandle = function() {
      var cell;
      if (this.includeRowHandles) {
        cell = new GridEdit.HandleCell(this);
        return this.element.appendChild(cell.element);
      }
    };

    return Row;

  })();


  /*
    Generic Row
    -----------------------------------------------------------------------------------------
   */

  GridEdit.GenericRow = (function(_super) {
    __extends(GenericRow, _super);

    function GenericRow(attributes, table) {
      var cell, col, i, _i, _len, _ref;
      this.attributes = attributes;
      this.table = table;
      GenericRow.__super__.constructor.apply(this, arguments);
      this.editable = true;
      this.addHandle();
      _ref = this.table.cols;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        col = _ref[i];
        cell = this.createCell(this.attributes[col.valueKey]);
        this.cells.push(cell);
        this.table.cols[i].cells.push(cell);
        this.element.appendChild(cell.element);
      }
      delete this.attributes;
    }

    return GenericRow;

  })(GridEdit.Row);


  /*
    Static Row
    -----------------------------------------------------------------------------------------
   */

  GridEdit.StaticRow = (function(_super) {
    __extends(StaticRow, _super);

    function StaticRow(attributes, table) {
      this.attributes = attributes;
      this.table = table;
      StaticRow.__super__.constructor.apply(this, arguments);
      this.addHandle();
      this.editable = this.attributes.editable = false;
      this.element.innerHTML = this.attributes.html;
      this.type = 'static';
      delete this.attributes;
    }

    return StaticRow;

  })(GridEdit.Row);


  /*
    Subtotal Row
    -----------------------------------------------------------------------------------------
   */

  GridEdit.SubTotalRow = (function(_super) {
    __extends(SubTotalRow, _super);

    function SubTotalRow(attributes, table) {
      var cell, col, i, value, _i, _len, _ref;
      this.attributes = attributes;
      this.table = table;
      SubTotalRow.__super__.constructor.apply(this, arguments);
      this.subtotalColumns = {};
      this.labels = this.attributes.labels;
      this.running = this.attributes.running;
      this.addHandle();
      _ref = this.table.cols;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        col = _ref[i];
        cell = new GridEdit.GenericCell('', this);
        cell.editable = false;
        if (this.labels) {
          value = this.labels[col.valueKey];
          cell.element.innerHTML = value || '';
        }
        this.cells.push(cell);
        this.table.cols[i].cells.push(cell);
        this.element.appendChild(cell.element);
        if (this.attributes.subtotal[col.valueKey]) {
          this.subtotalColumns[col.valueKey] = i;
        }
      }
      this.table.subtotalRows.push(this);
      this.calculate();
    }

    SubTotalRow.prototype.calculate = function() {
      var cell, col, index, row, rowIndex, start, sub, total, _i, _j, _len, _len1, _ref, _ref1, _ref2;
      start = -1;
      if (!this.running) {
        _ref = this.table.subtotalRows;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          sub = _ref[_i];
          rowIndex = sub.index;
          if (rowIndex < this.index && rowIndex > start) {
            start = rowIndex;
          }
        }
      }
      _ref1 = this.subtotalColumns;
      for (col in _ref1) {
        index = _ref1[col];
        total = 0;
        _ref2 = this.table.rows;
        for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
          row = _ref2[_j];
          if (!(row.index > start)) {
            continue;
          }
          if (row.index === this.index) {
            break;
          }
          if (row.type === 'subtotal' || row.type === 'header') {
            continue;
          }
          cell = row.cells[index];
          if (cell) {
            total += Number(cell.value());
          }
        }
        this.cells[index].value(total, false);
      }
      delete this.attributes;
      return this;
    };

    SubTotalRow.prototype.afterEdit = function() {};

    return SubTotalRow;

  })(GridEdit.Row);


  /*
    Header Row
    -----------------------------------------------------------------------------------------
   */

  GridEdit.HeaderRow = (function(_super) {
    __extends(HeaderRow, _super);

    function HeaderRow(attributes, table) {
      var cell, col, i, _i, _len, _ref;
      this.attributes = attributes;
      this.table = table;
      HeaderRow.__super__.constructor.apply(this, arguments);
      this.editable = true;
      this.addHandle();
      _ref = this.table.cols;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        col = _ref[i];
        cell = new GridEdit.Cell(this.attributes[col.valueKey], this, 'html');
        this.cells.push(cell);
        this.table.cols[i].cells.push(cell);
        this.element.appendChild(cell.element);
      }
      delete this.attributes;
    }

    return HeaderRow;

  })(GridEdit.Row);

}).call(this);
;(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  GridEdit.Cell = (function() {
    function Cell(originalValue, row) {
      this.originalValue = originalValue;
      this.row = row;
      this.index = this.row.cells.length;
      this.id = "" + this.row.id + "-" + this.index;
      this.address = [this.row.id, this.index];
      this.table = this.row.table;
      this.col = this.table.cols[this.index];
      this.meta = this.col;
      this.element = document.createElement('td');
    }


    /*
    		Initialization
    		-----------------------------------------------------------------------------------------
     */

    Cell.prototype.initialize = function() {
      this.initEditable();
      this.initValueKey();
      this.initSource();
      this.initOriginalValue();
      this.initSourceValue();
      this.initNode();
      this.initControl();
      this.applyControlBehavior();
      this.applyEventBehavior();
      this.initUserHooks();
      return this.applyStyle();
    };

    Cell.prototype.initOriginalValue = function() {
      if (this.originalValue === void 0) {
        return this.originalValue = '';
      }
    };

    Cell.prototype.initSourceValue = function() {
      return this.source[this.valueKey] = this.originalValue;
    };

    Cell.prototype.initEditable = function() {
      return this.editable = this.col.editable !== false;
    };

    Cell.prototype.initValueKey = function() {
      return this.valueKey = this.col.valueKey;
    };

    Cell.prototype.initSource = function() {
      return this.source = this.table.config.rows[this.address[0]];
    };

    Cell.prototype.initNode = function() {
      return this.element.appendChild(document.createTextNode(this.col.format(this.originalValue)));
    };

    Cell.prototype.initControl = function() {
      return this.control = document.createElement('input');
    };


    /*
    	User Hooks
    	  -----------------------------------------------------------------------------------------
     */

    Cell.prototype.initUserHooks = function() {
      this.beforeEdit = this.table.config.beforeEdit;
      this.afterEdit = this.table.config.afterEdit;
      this.beforeActivate = this.table.config.beforeCellActivate;
      this.afterActivate = this.table.config.afterCellActivate;
      this.beforeControlInit = this.table.config.beforeControlInit;
      this.afterControlInit = this.table.config.afterControlInit;
      this.beforeControlHide = this.table.config.beforeControlHide;
      this.afterControlHide = this.table.config.afterControlHide;
      return this.beforeNavigateTo = this.table.config.beforeCellNavigateTo;
    };

    Cell.prototype.userHook = function(hookName) {
      var arg, i, userArguments, _i, _len;
      if (this[hookName]) {
        userArguments = [];
        for (i = _i = 0, _len = arguments.length; _i < _len; i = ++_i) {
          arg = arguments[i];
          if (i === 0) {
            continue;
          }
          userArguments.push(arg);
        }
        return this[hookName].apply(userArguments);
      } else {
        return true;
      }
    };


    /*
    	Display
    	  -----------------------------------------------------------------------------------------
     */

    Cell.prototype.applyStyle = function() {
      var styleName, _results;
      if (this.col.cellClass) {
        this.element.classList.add(this.col.cellClass);
      }
      if (this.col.style) {
        _results = [];
        for (styleName in this.col.style) {
          _results.push(this.element.style[styleName] = this.col.style[styleName]);
        }
        return _results;
      }
    };

    Cell.prototype.addToSelection = function() {
      this.showActive();
      return this.table.activeCells.push(this);
    };

    Cell.prototype.removeFromSelection = function() {
      var index;
      index = this.table.activeCells.indexOf(this);
      this.table.activeCells.splice(index, 1);
      return this.showInactive();
    };

    Cell.prototype.isActive = function() {
      return this.table.activeCells.indexOf(this) !== -1;
    };

    Cell.prototype.makeActive = function(clearActiveCells) {
      var openCell;
      if (clearActiveCells == null) {
        clearActiveCells = true;
      }
      this.table.hideControl();
      if (clearActiveCells) {
        GridEdit.Utilities.prototype.clearActiveCells(this.table);
      }
      if (!this.isActive()) {
        if (this.userHook('beforeActivate', this)) {
          this.showActive();
          this.table.activeCells.push(this);
          this.table.selectionStart = this;
          openCell = this.table.openCell;
          if (openCell) {
            openCell.edit(openCell.control.value);
          }
          return this.userHook('afterActivate', this);
        }
      }
    };

    Cell.prototype.makeInactive = function() {
      return this.showInactive();
    };

    Cell.prototype.showActive = function() {
      if (!this.isActive()) {
        this.oldBackgroundColor = this.element.style.backgroundColor;
        return this.element.style.backgroundColor = this.table.theme.cells.activeColor;
      }
    };

    Cell.prototype.showInactive = function() {
      return this.element.style.backgroundColor = this.oldBackgroundColor;
    };

    Cell.prototype.showUneditable = function() {
      this.element.style.backgroundColor = this.table.theme.cells.uneditableColor;
      return this.table.redCells.push(this);
    };


    /*
    	Edit
    	  -----------------------------------------------------------------------------------------
     */

    Cell.prototype.edit = function(value) {
      if (value == null) {
        value = null;
      }
      if (this.editable) {
        if (value !== null) {
          this.value(value);
          if (this.isBeingEdited()) {
            return this.hideControl();
          } else {
            return this.edit();
          }
        } else {
          return this.showControl();
        }
      } else {
        return this.showUneditable();
      }
    };


    /*
    	Value
    	  -----------------------------------------------------------------------------------------
     */

    Cell.prototype.value = function(newValue, addToStack) {
      var currentValue, oldValue;
      if (newValue == null) {
        newValue = null;
      }
      if (addToStack == null) {
        addToStack = true;
      }
      currentValue = this.source[this.valueKey];
      if (newValue !== null && newValue !== currentValue) {
        newValue = this.formatValue(newValue);
        oldValue = this.value();
        if (this.userHook('beforeEdit', this, oldValue, newValue)) {
          if (addToStack) {
            this.table.addToStack({
              type: 'cell-edit',
              oldValue: oldValue,
              newValue: newValue,
              address: this.address
            });
          }
          this.setValue(newValue);
          this.renderValue(newValue);
          this.row.afterEdit();
          this.userHook('afterEdit', this, oldValue, newValue, this.table.contextMenu.getTargetPasteCell());
          return newValue;
        } else {
          return currentValue;
        }
      } else {
        return currentValue;
      }
    };

    Cell.prototype.formatValue = function(value) {
      return value;
    };

    Cell.prototype.setValue = function(value) {
      return this.source[this.valueKey] = value;
    };

    Cell.prototype.renderValue = function(value) {
      return this.element.textContent = this.col.format(value);
    };

    Cell.prototype.select = function() {
      return this.control.select();
    };


    /*
    	Control
    	  -----------------------------------------------------------------------------------------
     */

    Cell.prototype.showControl = function(value) {
      if (value == null) {
        value = null;
      }
      if (this.editable) {
        if (this.userHook('beforeControlInit', this)) {
          this.table.contextMenu.hideBorders();
          this.renderControl();
          this.setControlValue(value);
          this.table.openCell = this;
          return this.userHook('afterControlInit', this);
        }
      } else {
        return this.showUneditable();
      }
    };

    Cell.prototype.setControlValue = function(value) {
      return this.control.value = value;
    };

    Cell.prototype.renderControl = function() {
      var control;
      GridEdit.Utilities.prototype.setStyles(this.control, this.position());
      this.table.element.appendChild(this.control);
      this.control.style.position = 'fixed';
      control = this.control;
      return setTimeout(function() {
        return control.focus();
      }, 0);
    };

    Cell.prototype.hideControl = function() {
      if (this.userHook('beforeControlHide', this)) {
        if (this.isBeingEdited()) {
          this.control.parentNode.removeChild(this.control);
        }
        this.table.openCell = null;
        return this.userHook('afterControlHide', this);
      }
    };

    Cell.prototype.applyControlBehavior = function() {
      var cell, table;
      cell = this;
      table = this.table;
      return this.control.onkeydown = function(e) {
        var key, _ref;
        key = e.which;
        switch (key) {
          case 13:
            cell.edit(this.value);
            return (_ref = cell.below()) != null ? _ref.makeActive() : void 0;
          case 9:
            cell.edit(this.value);
            return moveTo(table.nextCell());
        }
      };
    };


    /*
    	Positioning
    	  -----------------------------------------------------------------------------------------
     */

    Cell.prototype.position = function() {
      return this.element.getBoundingClientRect();
    };

    Cell.prototype.reposition = function() {
      return GridEdit.Utilities.prototype.setStyles(this.control, this.position());
    };

    Cell.prototype.next = function() {
      var _ref;
      return this.row.cells[this.index + 1] || ((_ref = this.row.below()) != null ? _ref.cells[0] : void 0);
    };

    Cell.prototype.previous = function() {
      var _ref;
      return this.row.cells[this.index - 1] || ((_ref = this.row.above()) != null ? _ref.cells[this.row.cells.length - 1] : void 0);
    };

    Cell.prototype.above = function() {
      var _ref;
      return (_ref = this.row.above()) != null ? _ref.cells[this.index] : void 0;
    };

    Cell.prototype.below = function() {
      var _ref;
      return (_ref = this.row.below()) != null ? _ref.cells[this.index] : void 0;
    };

    Cell.prototype.isBefore = function(cell) {
      return cell.address[0] === this.address[0] && cell.address[1] > this.address[1];
    };

    Cell.prototype.isAfter = function(cell) {
      return cell.address[0] === this.address[0] && cell.address[1] < this.address[1];
    };

    Cell.prototype.isAbove = function(cell) {
      return cell.address[0] > this.address[0] && cell.address[1] === this.address[1];
    };

    Cell.prototype.isBelow = function(cell) {
      return cell.address[0] < this.address[0] && cell.address[1] === this.address[1];
    };

    Cell.prototype.addClass = function(newClass) {
      return this.element.classList.add(newClass);
    };

    Cell.prototype.removeClass = function(classToRemove) {
      return this.element.classList.remove(classToRemove);
    };

    Cell.prototype.isBeingEdited = function() {
      return this.control.parentNode != null;
    };

    Cell.prototype.toggleActive = function() {
      if (this.isActive()) {
        return this.removeFromSelection();
      } else {
        return this.makeActive(false);
      }
    };

    Cell.prototype.isVisible = function() {
      var position;
      position = this.position();
      return (position.top >= this.table.topOffset) && (position.bottom <= window.innerHeight);
    };


    /*
    	Events
    	  -----------------------------------------------------------------------------------------
     */

    Cell.prototype.onReturnKeyPress = function() {
      return false;
    };

    Cell.prototype.onSpaceKeyPress = function() {
      return this.edit();
    };

    Cell.prototype.onKeyPress = function(value) {
      return this.showControl(value);
    };

    Cell.prototype.applyEventBehavior = function() {
      var cell, doubleClickTimeout, startY, table;
      cell = this;
      table = this.table;
      doubleClickTimeout = null;
      this.element.onclick = function(e) {
        var activateRow, c, cellFrom, cellFromCol, cellFromRow, cellToCol, cellToRow, cmd, col, ctrl, onClickReturnVal, row, shift, _i, _j, _k, _l, _results, _results1;
        table.contextMenu.hideBorders();
        if (table.lastClickCell === cell) {
          table.lastClickCell = null;
          return cell.showControl(cell.value());
        } else {
          table.lastClickCell = cell;
          clearInterval(doubleClickTimeout);
          doubleClickTimeout = setTimeout(function() {
            return table.lastClickCell = null;
          }, 1000);
          onClickReturnVal = cell.col.onClick ? cell.col.onClick(cell, e) : true;
          if (onClickReturnVal) {
            ctrl = e.ctrlKey;
            cmd = e.metaKey;
            shift = e.shiftKey;
            activateRow = function(row) {};
            if (cellFromCol <= cellToCol) {
              for (col = _i = cellFromCol; cellFromCol <= cellToCol ? _i <= cellToCol : _i >= cellToCol; col = cellFromCol <= cellToCol ? ++_i : --_i) {
                c = table.getCell(row, col);
                c.makeActive(false);
              }
            } else {
              for (col = _j = cellToCol; cellToCol <= cellFromCol ? _j <= cellFromCol : _j >= cellFromCol; col = cellToCol <= cellFromCol ? ++_j : --_j) {
                c = table.getCell(row, col);
                c.makeActive(false);
              }
            }
            if (ctrl || cmd) {
              cell.toggleActive();
            }
            if (shift) {
              cellFrom = table.activeCells[0];
              cellFromRow = cellFrom.address[0];
              cellFromCol = cellFrom.address[1];
              cellToRow = cell.address[0];
              cellToCol = cell.address[1];
              if (cellFromRow <= cellToRow) {
                _results = [];
                for (row = _k = cellFromRow; cellFromRow <= cellToRow ? _k <= cellToRow : _k >= cellToRow; row = cellFromRow <= cellToRow ? ++_k : --_k) {
                  _results.push(activateRow(row));
                }
                return _results;
              } else {
                _results1 = [];
                for (row = _l = cellToRow; cellToRow <= cellFromRow ? _l <= cellFromRow : _l >= cellFromRow; row = cellToRow <= cellFromRow ? ++_l : --_l) {
                  _results1.push(activateRow(row));
                }
                return _results1;
              }
            }
          }
        }
      };
      this.element.onmousedown = function(e) {
        if (e.which === 3) {
          table.contextMenu.show(e.x, e.y, cell);
        } else {
          if (!(e.shiftKey || e.ctrlKey || e.metaKey)) {
            table.state = "selecting";
            return cell.makeActive();
          }
        }
      };
      this.element.onmouseover = function(e) {
        if (table.state === 'selecting') {
          table.selectionEnd = cell;
          return table.setSelection();
        }
      };
      this.element.onmouseup = function(e) {
        if (e.which !== 3) {
          table.selectionEnd = cell;
          table.state = "ready";
          if (!(e.metaKey || e.ctrlKey)) {
            return table.setSelection();
          }
        }
      };
      if (table.mobile) {
        startY = null;
        this.element.ontouchstart = function(e) {
          startY = e.changedTouches[0].clientY;
          GridEdit.Utilities.prototype.clearActiveCells(table);
          if (table.openCell) {
            return table.openCell.hideControl();
          }
        };
        return this.element.ontouchend = function(e) {
          var y;
          y = e.changedTouches[0].clientY;
          if (e.changedTouches.length < 2 && (y === startY)) {
            e.preventDefault();
            return cell.edit();
          }
        };
      }
    };

    return Cell;

  })();


  /*
    String Cell
    -----------------------------------------------------------------------------------------
   */

  GridEdit.StringCell = (function(_super) {
    __extends(StringCell, _super);

    function StringCell(value, row) {
      this.row = row;
      StringCell.__super__.constructor.apply(this, arguments);
      this.type = 'string';
      this.initialize();
      this;
    }

    return StringCell;

  })(GridEdit.Cell);


  /*
    Number Cell
    -----------------------------------------------------------------------------------------
   */

  GridEdit.NumberCell = (function(_super) {
    __extends(NumberCell, _super);

    function NumberCell(value, row) {
      this.row = row;
      NumberCell.__super__.constructor.apply(this, arguments);
      this.type = 'number';
      this.initialize();
      this;
    }

    NumberCell.prototype.formatValue = function(newValue) {
      return Number(newValue);
    };

    NumberCell.prototype.setValue = function(newValue) {
      return this.source[this.valueKey] = Number(newValue);
    };


    /*
    		CheckBox Cell
    		-----------------------------------------------------------------------------------------
     */

    return NumberCell;

  })(GridEdit.Cell);

  GridEdit.CheckBoxCell = (function(_super) {
    __extends(CheckBoxCell, _super);

    function CheckBoxCell(value, row) {
      this.row = row;
      CheckBoxCell.__super__.constructor.apply(this, arguments);
      this.type = 'checkbox';
      this.initialize();
      this;
    }

    CheckBoxCell.prototype.initialize = function() {
      this.initEditable();
      this.initValueKey();
      this.initSource();
      this.initOriginalValue();
      this.initSourceValue();
      this.applyEventBehavior();
      this.initUserHooks();
      this.applyStyle();
      this.initNode();
      this.toggleable = this.editable;
      this.editable = false;
      return this.renderValue();
    };

    CheckBoxCell.prototype.initNode = function() {
      var div;
      div = document.createElement('div');
      div.style.width = '1em';
      div.style.margin = 'auto';
      this.span = document.createElement('span');
      div.appendChild(this.span);
      return this.element.appendChild(div);
    };

    CheckBoxCell.prototype.edit = function() {
      return false;
    };

    CheckBoxCell.prototype.onReturnKeyPress = function() {
      return this.toggle();
    };

    CheckBoxCell.prototype.initControl = function() {
      return this.toggle();
    };

    CheckBoxCell.prototype.renderControl = function() {
      return GridEdit.Utilities.prototype.clearActiveCells(this.table);
    };

    CheckBoxCell.prototype.isBeingEdited = function() {
      return false;
    };

    CheckBoxCell.prototype.toggle = function() {
      if (this.toggleable) {
        return this.value(!this.value());
      }
    };

    CheckBoxCell.prototype.renderValue = function() {
      if (this.value()) {
        if (this.table.theme.inputs.checkbox.checkedClassName) {
          return this.span.className = this.table.theme.inputs.checkbox.checkedClassName;
        } else {
          return this.span.innerHTML = '&#x2714;';
        }
      } else {
        if (this.table.theme.inputs.checkbox.uncheckedClassName) {
          return this.span.className = this.table.theme.inputs.checkbox.uncheckedClassName;
        } else {
          return this.span.innerHTML = '';
        }
      }
    };

    CheckBoxCell.prototype.applyEventBehavior = function() {
      var cell;
      CheckBoxCell.__super__.applyEventBehavior.apply(this, arguments);
      cell = this;
      return this.element.onclick = function(e) {
        cell.table.contextMenu.hideBorders();
        return cell.toggle();
      };
    };

    CheckBoxCell.prototype.onSpaceKeyPress = function() {
      return this.toggle();
    };

    return CheckBoxCell;

  })(GridEdit.Cell);


  /*
  	Date Cell
  	-----------------------------------------------------------------------------------------
   */

  GridEdit.DateCell = (function(_super) {
    __extends(DateCell, _super);

    function DateCell(value, row) {
      var node;
      this.row = row;
      node = document.createTextNode(this.toDateString(this.originalValue));
      this.control = this.toDate();
      if (this.originalValue) {
        this.control.valueAsDate = new Date(this.originalValue);
      }
      this.element.appendChild(node);
    }

    DateCell.prototype.formatValue = function(newValue) {
      if (newValue.length > 0) {
        return this.toDateString(Date.parse(newValue));
      } else if (newValue instanceof Date) {
        return this.toDateString(newValue);
      } else if (newValue.length === 0) {
        this.control.valueAsDate = null;
        return '';
      }
    };

    DateCell.prototype.setValue = function(newValue) {
      this.source[this.valueKey] = new Date(newValue);
      return this.control.valueAsDate = new Date(newValue);
    };

    DateCell.prototype.initControl = function() {
      DateCell.__super__.initControl.call(this);
      return this.control.value = this.toDateInputString(this.value());
    };

    DateCell.prototype.value = function() {
      return this.control.valueAsDate;
    };

    DateCell.prototype.toDateString = function(passedDate) {
      var date;
      if (passedDate == null) {
        passedDate = null;
      }
      if (passedDate && passedDate !== '') {
        date = new Date(passedDate);
      } else {
        if (this.value()) {
          date = new Date(this.value());
        } else {
          null;
        }
      }
      if (date instanceof Date) {
        return ('0' + (date.getMonth() + 1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2) + '-' + date.getFullYear();
      } else {
        return '';
      }
    };

    DateCell.prototype.toDate = function() {
      var input;
      input = document.createElement('input');
      input.type = 'date';
      input.value = this.toDateString();
      return input;
    };

    DateCell.prototype.toDateInputString = function(passedDate) {
      var date;
      if (passedDate == null) {
        passedDate = null;
      }
      if (passedDate && passedDate !== '') {
        date = new Date(passedDate);
      } else {
        if (this.value()) {
          date = new Date(this.value());
        } else {
          null;
        }
      }
      if (date instanceof Date) {
        return date.getFullYear() + '-' + ('0' + (date.getMonth() + 1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2);
      } else {
        return '';
      }
    };

    return DateCell;

  })(GridEdit.Cell);


  /*
  	HTML Cell
  	-----------------------------------------------------------------------------------------
   */

  GridEdit.HTMLCell = (function(_super) {
    __extends(HTMLCell, _super);

    function HTMLCell(value, row) {
      var node;
      this.row = row;
      this.htmlContent = this.col.defaultValue || this.originalValue || '';
      node = this.toFragment();
      this.control = document.createElement('input');
      this.element.appendChild(node);
    }

    HTMLCell.prototype.setValue = function(newValue) {
      var node;
      this.htmlContent = newValue;
      node = this.toFragment();
      this.element.innerHTML = "";
      return this.element.appendChild(node);
    };

    HTMLCell.prototype.toFragment = function() {
      var element, fragment;
      element = document.createElement("div");
      fragment = document.createDocumentFragment();
      element.innerHTML = this.htmlContent;
      fragment.appendChild(element.firstChild || document.createTextNode(''));
      return fragment;
    };

    HTMLCell.prototype.render = function() {
      return this.htmlContent;
    };

    return HTMLCell;

  })(GridEdit.Cell);


  /*
  	Select Cell
  	-----------------------------------------------------------------------------------------
   */

  GridEdit.SelectCell = (function(_super) {
    __extends(SelectCell, _super);

    function SelectCell(value, row) {
      this.row = row;
      SelectCell.__super__.constructor.apply(this, arguments);
      this.type = 'select';
      this.initialize();
      this;
    }

    SelectCell.prototype.initNode = function() {
      var node;
      node = document.createTextNode(this.originalValue);
      return this.element.appendChild(node);
    };

    SelectCell.prototype.initControl = function() {
      var cell, choice, index, option, select, subchoice, _i, _j, _len, _len1, _ref;
      cell = this;
      select = document.createElement("select");
      if (!this.meta.choices) {
        console.log("There is not a 'choices' key in cell " + this.address + " and you specified that it was of type 'select'");
      }
      _ref = this.meta.choices;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        choice = _ref[_i];
        option = document.createElement("option");
        if (choice instanceof Array) {
          for (index = _j = 0, _len1 = choice.length; _j < _len1; index = ++_j) {
            subchoice = choice[index];
            if (index === 0) {
              option.value = subchoice;
            }
            if (index === 1) {
              option.text = subchoice;
            }
          }
        } else {
          option.value = option.text = choice;
        }
        if (cell.value() === choice) {
          option.selected = true;
        }
        select.add(option);
      }
      select.classList.add(this.table.theme.inputs.select.className);
      select.onchange = function(e) {
        return cell.edit(e.target.value);
      };
      return this.control = select;
    };

    SelectCell.prototype.select = function() {
      return false;
    };

    SelectCell.prototype.onSpaceKeyPress = function() {
      var control;
      this.renderControl();
      control = this.control;
      return setTimeout(function() {
        var event;
        event = document.createEvent('MouseEvents');
        event.initMouseEvent('mousedown', true, true, window);
        return control.dispatchEvent(event);
      }, 0);
    };

    return SelectCell;

  })(GridEdit.Cell);


  /*
    TextArea Cell
    -----------------------------------------------------------------------------------------
   */

  GridEdit.TextAreaCell = (function(_super) {
    __extends(TextAreaCell, _super);

    function TextAreaCell(value, row) {
      var node;
      this.row = row;
      node = document.createTextNode(this.originalValue || '');
      this.element.appendChild(node);
      this.control = document.createElement('textarea');
      this.control.classList.add(this.table.theme.inputs.textarea.className);
    }

    return TextAreaCell;

  })(GridEdit.Cell);


  /*
    Generic Cell
    -----------------------------------------------------------------------------------------
  
    Special cell class used by GridEdit for specialty rows and cells
   */

  GridEdit.GenericCell = (function(_super) {
    __extends(GenericCell, _super);

    function GenericCell(value, row) {
      this.row = row;
      GenericCell.__super__.constructor.apply(this, arguments);
      this.type = 'generic';
      this.initialize();
      this;
    }

    return GenericCell;

  })(GridEdit.Cell);


  /*
    Handle Cell
    -----------------------------------------------------------------------------------------
  
    Special cell class used by GridEdit to create row handles for moving rows
   */

  GridEdit.HandleCell = (function() {
    function HandleCell(row) {
      var node, table;
      this.row = row;
      row = this.row;
      table = row.table;
      this.element = document.createElement('td');
      this.element.setAttribute("draggable", true);
      this.element.className = table.theme.cells.handleClassName;
      node = document.createElement('div');
      node.innerHTML = '<span></span><span></span><span></span>';
      this.element.appendChild(node);
      this.element.onclick = function(e) {
        var index;
        index = row.index;
        return row.table.selectRow(e, index);
      };
      this.element.ondragstart = function() {
        GridEdit.Utilities.prototype.clearActiveCells(table);
        table.contextMenu.hideBorders();
        row.select();
        return table.draggingRow = row;
      };
      this.element.ondragend = function() {
        var insertAtIndex, lastDragOverIndex, modifier, rowToMoveInex;
        rowToMoveInex = table.draggingRow.index;
        lastDragOverIndex = table.lastDragOver.index;
        modifier = lastDragOverIndex === 0 && !table.lastDragOverIsBeforeFirstRow ? 1 : 0;
        insertAtIndex = lastDragOverIndex + modifier;
        table.lastDragOver.element.style.borderBottom = table.lastDragOver.oldBorderBottom;
        table.lastDragOver.element.style.borderTop = table.lastDragOver.oldBorderTop;
        table.lastDragOver.element.style.borderTop = table.lastDragOver.oldBorderTop;
        table.lastDragOver = null;
        return table.moveRow(rowToMoveInex, insertAtIndex);
      };
      this;
    }

    return HandleCell;

  })();

}).call(this);
;(function() {
  GridEdit.GridChange = (function() {
    function GridChange(cells, value) {
      var area, cell, change, colIndex, height, rowIndex, thisChange, useBlank, width, _i, _j, _len, _len1, _ref;
      this.cells = cells;
      useBlank = value === 'ge-blank';
      this.changes = [];
      this.table = this.cells[0].col.table;
      this.borderStyle = this.table.config.selectionBorderStyle || "2px dashed blue";
      this.highRow = 0;
      this.highCol = 0;
      for (_i = 0, _len = cells.length; _i < _len; _i++) {
        cell = cells[_i];
        rowIndex = cell.address[0];
        colIndex = cell.address[1];
        thisChange = {
          row: rowIndex,
          col: colIndex,
          value: useBlank ? '' : value || cell.value()
        };
        if (this.firstCell) {
          if (thisChange.row < this.firstCell.row) {
            this.firstCell = thisChange;
          } else if (thisChange.row === this.firstCell.row) {
            if (thisChange.col < this.firstCell.col) {
              this.firstCell = thisChange;
            }
          }
        } else {
          this.firstCell = thisChange;
          this.lowRow = thisChange.row;
          this.lowCol = thisChange.col;
        }
        if (thisChange.row > this.highRow) {
          this.highRow = thisChange.row;
        }
        if (thisChange.col > this.highCol) {
          this.highCol = thisChange.col;
        }
        if (thisChange.row < this.lowRow) {
          this.lowRow = thisChange.row;
        }
        if (thisChange.col < this.lowCol) {
          this.lowCol = thisChange.col;
        }
        this.changes.push(thisChange);
      }
      _ref = this.changes;
      for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
        change = _ref[_j];
        change.rowVector = change.row - this.firstCell.row;
        change.colVector = change.col - this.firstCell.col;
      }
      width = this.highCol - this.lowCol + 1;
      height = this.highRow - this.lowRow + 1;
      area = width * height;
      this.scattered = this.cells.length !== area;
    }

    GridChange.prototype.apply = function(x, y) {
      var cell, change, _i, _len, _ref, _results;
      if (x === false || y === false) {
        x = this.firstCell.row;
        y = this.firstCell.col;
      }
      _ref = this.changes;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        change = _ref[_i];
        cell = this.table.getCell(x + change.rowVector, y + change.colVector);
        if (cell && cell.editable) {
          change.oldValue = cell.value();
          _results.push(cell.value(change.value, false));
        } else {
          _results.push(change.oldValue = '');
        }
      }
      return _results;
    };

    GridChange.prototype.undo = function(x, y) {
      var cell, change, _i, _len, _ref, _results;
      if (x === false || y === false) {
        x = this.firstCell.row;
        y = this.firstCell.col;
      }
      _ref = this.changes;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        change = _ref[_i];
        cell = this.table.getCell(x + change.rowVector, y + change.colVector);
        if (cell && cell.editable) {
          _results.push(cell.value(change.oldValue, false));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    GridChange.prototype.displayBorders = function() {
      var cell, _i, _len, _ref, _results;
      _ref = this.cells;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        cell = _ref[_i];
        _results.push(this.addBorder(cell));
      }
      return _results;
    };

    GridChange.prototype.removeBorders = function() {
      var cell, _i, _len, _ref, _results;
      _ref = this.cells;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        cell = _ref[_i];
        _results.push(cell.element.style.border = "");
      }
      return _results;
    };

    GridChange.prototype.addBorder = function(cell) {
      var colIndex, rowIndex;
      rowIndex = cell.address[0];
      colIndex = cell.address[1];
      if (this.scattered) {
        return cell.element.style.border = this.borderStyle;
      } else {
        if (this.firstCell.row === this.highRow) {
          cell.element.style.borderTop = this.borderStyle;
          cell.element.style.borderBottom = this.borderStyle;
        } else {
          if (rowIndex === this.lowRow) {
            cell.element.style.borderTop = this.borderStyle;
          } else if (rowIndex === this.highRow) {
            cell.element.style.borderBottom = this.borderStyle;
          }
        }
        if (this.firstCell.col === this.highCol) {
          cell.element.style.borderRight = this.borderStyle;
          return cell.element.style.borderLeft = this.borderStyle;
        } else {
          if (colIndex === this.lowCol) {
            return cell.element.style.borderLeft = this.borderStyle;
          } else if (colIndex === this.highCol) {
            return cell.element.style.borderRight = this.borderStyle;
          }
        }
      }
    };

    return GridChange;

  })();

}).call(this);
;(function() {
  GridEdit.Theme = (function() {
    function Theme(themeName, customTheme) {
      this.themeName = themeName;
      switch (this.themeName) {
        case 'bootstrap':
          this.apply(this.bootstrap);
          break;
        default:
          this.themeName = 'default';
          this.apply(this["default"]);
          break;
      }
      if (customTheme) {
        this.themeName = "" + this.themeName + "-custom";
        this.apply(customTheme);
      }
    }

    Theme.prototype.apply = function(theme) {
      var apply, k, self, v, _results;
      self = this;
      apply = function(target, obj) {
        var k, v, _results;
        _results = [];
        for (k in obj) {
          v = obj[k];
          if (typeof v === 'object') {
            if (!target[k]) {
              target[k] = {};
            }
            _results.push(apply(target[k], v));
          } else {
            _results.push(target[k] = v);
          }
        }
        return _results;
      };
      _results = [];
      for (k in theme) {
        v = theme[k];
        if (typeof v === 'object') {
          if (!self[k]) {
            self[k] = {};
          }
          _results.push(apply(self[k], v));
        } else {
          _results.push(self[k] = v);
        }
      }
      return _results;
    };

    Theme.prototype["default"] = {
      bootstrap: false,
      cells: {
        activeColor: "#FFE16F",
        uneditableColor: "#FFBBB3",
        handleClassName: 'handle'
      },
      borders: {
        dragBorderStyle: '3px solid rgb(160, 195, 240)'
      },
      inputs: {
        textarea: {
          className: 'grid-edit'
        },
        select: {
          className: 'grid-edit'
        },
        checkbox: {
          checkedClassName: false,
          uncheckedClassName: false
        }
      }
    };

    Theme.prototype.bootstrap = {
      bootstrap: true,
      cells: {
        activeColor: "#FFE16F",
        uneditableColor: "#FFBBB3",
        handleClassName: 'handle'
      },
      borders: {
        dragBorderStyle: '3px solid rgb(160, 195, 240)'
      },
      inputs: {
        textarea: 'form-control',
        select: {
          className: 'form-control'
        },
        checkbox: {
          checkedClassName: 'glyphicon glyphicon-check',
          uncheckedClassName: 'glyphicon glyphicon-unchecked'
        }
      }
    };

    return Theme;

  })();

}).call(this);
