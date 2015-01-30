(function() {
  var ActionStack, Cell, Column, ContextMenu, DateCell, GenericCell, GridChange, GridEdit, HTMLCell, NumberCell, Row, SelectCell, StringCell, Utilities, root,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Utilities = (function() {
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

    return Utilities;

  })();

  GridEdit = (function() {
    function GridEdit(config, actionStack) {
      var key, value, _ref;
      this.config = config;
      this.actionStack = actionStack;
      this.element = document.querySelectorAll(this.config.element || '#gridedit')[0];
      this.headers = [];
      this.rows = [];
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
      this.cellStyles = {
        activeColor: "#FFE16F",
        uneditableColor: "#FFBBB3"
      };
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
      this.contextMenu = new ContextMenu(this);
      if (!this.actionStack) {
        this.actionStack = new ActionStack(this);
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
      var col, colAttributes, i, row, rowAttributes, table, tbody, thead, tr, _i, _j, _len, _len1, _ref, _ref1;
      tr = document.createElement('tr');
      _ref = this.config.cols;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        colAttributes = _ref[i];
        col = new Column(colAttributes, this);
        this.cols.push(col);
        tr.appendChild(col.element);
      }
      thead = document.createElement('thead');
      thead.appendChild(tr);
      tbody = document.createElement('tbody');
      _ref1 = this.source;
      for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
        rowAttributes = _ref1[i];
        row = new Row(rowAttributes, this);
        this.rows.push(row);
        tbody.appendChild(row.element);
      }
      table = document.createElement('table');
      Utilities.prototype.setAttributes(table, {
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

    GridEdit.prototype.events = function() {
      var edit, moveTo, table;
      table = this;
      moveTo = table.moveTo;
      edit = table.edit;
      document.onkeydown = function(e) {
        var cmd, ctrl, key, openCellAndPopulateInitialValue, shift, valueFromKey;
        if (table.activeCell()) {
          key = e.keyCode;
          shift = e.shiftKey;
          ctrl = e.ctrlKey;
          cmd = e.metaKey;
          valueFromKey = function(key, shift) {
            var char;
            char = String.fromCharCode(key);
            if (!shift) {
              return char.toLowerCase();
            } else {
              return char;
            }
          };
          openCellAndPopulateInitialValue = function() {
            if (!table.openCell) {
              return table.activeCell().showControl(valueFromKey(key, shift));
            }
          };
          if (cmd || ctrl) {
            if (key && key !== 91 && key !== 92) {
              if (table.contextMenu.actionCallbacks.byControl[key]) {
                e.preventDefault();
                return table.contextMenu.actionCallbacks.byControl[key](e, table);
              }
            }
          } else {
            switch (key) {
              case 39:
                if (!table.activeCell().isBeingEdited()) {
                  return moveTo(table.nextCell());
                }
                break;
              case 9:
                if (shift) {
                  return moveTo(table.previousCell());
                } else {
                  return moveTo(table.nextCell());
                }
                break;
              case 37:
                return moveTo(table.previousCell());
              case 38:
                return moveTo(table.aboveCell());
              case 40:
                return moveTo(table.belowCell());
              case 32:
                if (!table.openCell) {
                  return edit(table.activeCell());
                }
                break;
              case 13:
                break;
              case 16:
                break;
              case 17:
                break;
              case 91:
                break;
              case 8:
                if (!table.openCell) {
                  e.preventDefault();
                  return table["delete"]();
                }
                break;
              case 46:
                if (!table.openCell) {
                  e.preventDefault();
                  return table["delete"]();
                }
                break;
              default:
                if (__indexOf.call([96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111], key) >= 0) {
                  key = key - 48;
                }
                return openCellAndPopulateInitialValue();
            }
          }
        }
      };
      window.onresize = function() {
        if (table.openCell) {
          return Utilities.prototype.setStyles(table.openCell.control, table.openCell.position());
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
        var _ref;
        if (!((table.isDescendant(e.target)) || (e.target === ((_ref = table.activeCell()) != null ? _ref.control : void 0) || table.contextMenu))) {
          Utilities.prototype.clearActiveCells(table);
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

    GridEdit.prototype.set = function(key, value) {
      if (key !== void 0) {
        return this.config[key] = value;
      }
    };

    GridEdit.prototype.getCell = function(x, y) {
      var e;
      try {
        return this.rows[x].cells[y];
      } catch (_error) {
        e = _error;
      }
    };

    GridEdit.prototype.activeCell = function() {
      if (this.activeCells.length > 1) {
        return this.activeCells;
      } else {
        return this.activeCells[0];
      }
    };

    GridEdit.prototype.nextCell = function() {
      var _ref;
      return (_ref = this.activeCell()) != null ? _ref.next() : void 0;
    };

    GridEdit.prototype.previousCell = function() {
      var _ref;
      return (_ref = this.activeCell()) != null ? _ref.previous() : void 0;
    };

    GridEdit.prototype.aboveCell = function() {
      var _ref;
      return (_ref = this.activeCell()) != null ? _ref.above() : void 0;
    };

    GridEdit.prototype.belowCell = function() {
      var _ref;
      return (_ref = this.activeCell()) != null ? _ref.below() : void 0;
    };

    GridEdit.prototype.moveTo = function(toCell, fromCell) {
      var beforeCellNavigateReturnVal, direction, directionModifier, newY, oldY;
      if (toCell) {
        if (fromCell === void 0) {
          fromCell = toCell.table.activeCell();
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
        return cell != null ? cell.edit(newValue) : void 0;
      } else {
        if (cell != null) {
          cell.edit();
        }
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
      return Utilities.prototype.clearActiveCells(this);
    };

    GridEdit.prototype.setSelection = function() {
      var cell, col, colRange, row, rowRange, _i, _j, _k, _l, _len, _len1, _len2, _m, _ref, _ref1, _ref2, _ref3, _ref4, _results, _results1;
      if (this.selectionStart !== this.selectionEnd) {
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

    GridEdit.prototype.addRow = function(index, addToStack) {
      var c, row, _i, _len, _ref;
      if (addToStack == null) {
        addToStack = true;
      }
      row = {};
      _ref = this.cols;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        c = _ref[_i];
        row[c.valueKey] = c.defaultValue || '';
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
          index: index
        });
      }
      return this.rebuild({
        rows: this.source,
        initialize: true
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
      var rows;
      if (addToStack == null) {
        addToStack = true;
      }
      rows = this.source.splice(index, 1);
      if (addToStack) {
        this.addToStack({
          type: 'remove-row',
          index: index
        });
      }
      return this.rebuild({
        rows: this.source,
        initialize: true
      });
    };

    GridEdit.prototype.selectRow = function(index) {
      var row;
      row = this.rows[index];
      return row.select();
    };

    return GridEdit;

  })();

  Column = (function() {
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
        Utilities.prototype.clearActiveCells(table);
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

  Row = (function() {
    function Row(attributes, table) {
      var cell, col, i, _i, _len, _ref;
      this.attributes = attributes;
      this.table = table;
      this.id = this.table.rows.length;
      this.cells = [];
      this.index = this.table.rows.length;
      this.element = document.createElement('tr');
      this.editable = true;
      Utilities.prototype.setAttributes(this.element, {
        id: "row-" + this.id
      });
      _ref = this.table.cols;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        col = _ref[i];
        cell = new Cell(this.attributes[col.valueKey], this);
        this.cells.push(cell);
        this.table.cols[i].cells.push(cell);
        this.element.appendChild(cell.element);
      }
      delete this.attributes;
    }

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

    return Row;

  })();

  Cell = (function() {
    function Cell(originalValue, row) {
      var styleName;
      this.originalValue = originalValue;
      this.row = row;
      this.id = "" + this.row.id + "-" + this.row.cells.length;
      this.address = [this.row.id, this.row.cells.length];
      this.index = this.row.cells.length;
      this.table = this.row.table;
      this.col = this.table.cols[this.index];
      this.type = this.col.type;
      this.meta = this.col;
      this.editable = this.col.editable !== false;
      this.element = document.createElement('td');
      if (this.col.cellClass) {
        this.element.classList.add(this.col.cellClass);
      }
      this.valueKey = this.col.valueKey;
      this.source = this.table.config.rows[this.address[0]];
      this.initCallbacks();
      if (this.col.style) {
        for (styleName in this.col.style) {
          this.element.style[styleName] = this.col.style[styleName];
        }
      }
      switch (this.type) {
        case 'string':
          this.cellTypeObject = new StringCell(this);
          break;
        case 'number':
          this.cellTypeObject = new NumberCell(this);
          break;
        case 'date':
          this.cellTypeObject = new DateCell(this);
          break;
        case 'html':
          this.cellTypeObject = new HTMLCell(this);
          break;
        case 'select':
          this.cellTypeObject = new SelectCell(this);
      }
      this.events(this);
    }

    Cell.prototype.initCallbacks = function() {
      if (this.table.config.beforeEdit) {
        this.beforeEdit = this.table.config.beforeEdit;
      }
      if (this.table.config.afterEdit) {
        this.afterEdit = this.table.config.afterEdit;
      }
      if (this.table.config.beforeCellActivate) {
        this.beforeActivate = this.table.config.beforeCellActivate;
      }
      if (this.table.config.afterCellActivate) {
        this.afterActivate = this.table.config.afterCellActivate;
      }
      if (this.table.config.beforeControlInit) {
        this.beforeControlInit = this.table.config.beforeControlInit;
      }
      if (this.table.config.afterControlInit) {
        this.afterControlInit = this.table.config.afterControlInit;
      }
      if (this.table.config.beforeControlHide) {
        this.beforeControlHide = this.table.config.beforeControlHide;
      }
      if (this.table.config.afterControlHide) {
        this.afterControlHide = this.table.config.afterControlHide;
      }
      if (this.table.config.onCellClick) {
        this.onClick = this.table.config.onCellClick;
      }
      if (this.table.config.beforeCellNavigateTo) {
        return this.beforeNavigateTo = this.table.config.beforeCellNavigateTo;
      }
    };

    Cell.prototype.value = function(newValue, addToStack) {
      var oldValue;
      if (newValue == null) {
        newValue = null;
      }
      if (addToStack == null) {
        addToStack = true;
      }
      if (newValue !== null && newValue !== this.element.textContent) {
        newValue = this.cellTypeObject.formatValue(newValue);
        oldValue = this.value();
        if (this.beforeEdit) {
          this.beforeEdit(this, oldValue, newValue);
        }
        if (addToStack) {
          this.table.addToStack({
            type: 'cell-edit',
            oldValue: oldValue,
            newValue: newValue,
            address: this.address
          });
        }
        this.element.textContent = this.col.format(newValue);
        this.cellTypeObject.setValue(newValue);
        if (this.control) {
          Utilities.prototype.setStyles(this.control, this.position());
        }
        if (this.afterEdit) {
          this.afterEdit(this, oldValue, newValue, this.table.contextMenu.getTargetPasteCell());
        }
        return newValue;
      } else {
        return this.source[this.valueKey];
      }
    };

    Cell.prototype.makeActive = function(clearActiveCells) {
      var beforeActivateReturnVal;
      if (clearActiveCells == null) {
        clearActiveCells = true;
      }
      if (!this.isActive()) {
        if (this.beforeActivate) {
          beforeActivateReturnVal = this.beforeActivate(this);
        }
        if (this.beforeActivate && beforeActivateReturnVal !== false || !this.beforeActivate) {
          if (clearActiveCells) {
            Utilities.prototype.clearActiveCells(this.table);
          }
          this.showActive();
          this.table.activeCells.push(this);
          this.table.selectionStart = this;
          if (this.table.openCell) {
            this.table.openCell.edit(this.table.openCell.control.value);
          }
          if (this.afterActivate) {
            return this.afterActivate(this);
          }
        }
      }
    };

    Cell.prototype.makeInactive = function() {
      return this.showInactive();
    };

    Cell.prototype.addToSelection = function() {
      this.showActive();
      return this.table.activeCells.push(this);
    };

    Cell.prototype.isActive = function() {
      return this.table.activeCells.indexOf(this) !== -1;
    };

    Cell.prototype.removeFromSelection = function() {
      var index;
      index = this.table.activeCells.indexOf(this);
      this.table.activeCells.splice(index, 1);
      return this.showInactive();
    };

    Cell.prototype.showActive = function() {
      var cssText;
      if (!this.isActive()) {
        cssText = this.element.style.cssText;
        this.oldCssText = cssText;
        return this.element.style.cssText = cssText + ' ' + ("background-color: " + this.table.cellStyles.activeColor + ";");
      }
    };

    Cell.prototype.showInactive = function() {
      return this.element.style.cssText = this.oldCssText;
    };

    Cell.prototype.showRed = function() {
      this.element.style.cssText = "background-color: " + this.table.cellStyles.uneditableColor + ";";
      return this.table.redCells.push(this);
    };

    Cell.prototype.showControl = function(value) {
      var beforeControlInitReturnVal, control;
      if (value == null) {
        value = null;
      }
      Utilities.prototype.clearActiveCells(this.table);
      if (this.table.copiedCellMatrix) {
        this.table.contextMenu.hideBorders();
      }
      if (!this.editable) {
        return this.showRed();
      } else {
        if (this.beforeControlInit) {
          beforeControlInitReturnVal = this.beforeControlInit(this);
        }
        if (this.beforeControlInit && beforeControlInitReturnVal !== false || !this.beforeControlInit) {
          if (value !== null) {
            this.control.value = value;
            control = this.control;
            setTimeout(function() {
              return control.focus();
            }, 0);
          } else {
            this.cellTypeObject.initControl();
          }
          this.control.style.position = "fixed";
          Utilities.prototype.setStyles(this.control, this.position());
          this.table.element.appendChild(this.control);
          this.table.openCell = this;
          if (this.afterControlInit) {
            return this.afterControlInit(this);
          }
        }
      }
    };

    Cell.prototype.hideControl = function() {
      var beforeControlHideReturnVal;
      if (this.table.openCell !== null) {
        if (this.beforeControlHide) {
          beforeControlHideReturnVal = this.beforeControlHide(this);
        }
        if (this.beforeControlHide && beforeControlHideReturnVal !== false || !this.beforeControlHide) {
          if (this.isControlInDocument()) {
            this.control.parentNode.removeChild(this.control);
          }
          this.table.openCell = null;
          if (this.afterControlHide) {
            return this.afterControlHide(this);
          }
        }
      }
    };

    Cell.prototype.edit = function(newValue) {
      if (newValue == null) {
        newValue = null;
      }
      if (!this.editable) {
        return this.showRed();
      } else {
        if (newValue !== null) {
          this.value(newValue);
          if (this.isBeingEdited()) {
            return this.hideControl();
          } else {
            return this.edit();
          }
        } else {
          this.showControl();
          this.control.focus();
          return this.cellTypeObject.select();
        }
      }
    };

    Cell.prototype.position = function() {
      return this.element.getBoundingClientRect();
    };

    Cell.prototype.isVisible = function() {
      var position;
      position = this.position();
      return (position.top >= this.table.topOffset) && (position.bottom <= window.innerHeight);
    };

    Cell.prototype.isControlInDocument = function() {
      return this.control.parentNode !== null;
    };

    Cell.prototype.reposition = function() {
      return Utilities.prototype.setStyles(this.control, this.position());
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

    Cell.prototype.events = function(cell) {
      var activeCells, redCells, startY, table;
      table = cell.table;
      redCells = table.redCells;
      activeCells = table.activeCells;
      this.element.onclick = function(e) {
        var activateRow, cellFrom, cellFromCol, cellFromRow, cellToCol, cellToRow, cmd, ctrl, onClickReturnVal, row, shift, _i, _j, _results, _results1;
        onClickReturnVal = true;
        if (cell.col.onClick) {
          onClickReturnVal = cell.col.onClick(cell, e);
        }
        if (onClickReturnVal !== false) {
          ctrl = e.ctrlKey;
          cmd = e.metaKey;
          shift = e.shiftKey;
          if (ctrl || cmd) {
            cell.toggleActive();
          }
          if (shift) {
            cellFrom = table.activeCells[0];
            cellFromRow = cellFrom.address[0];
            cellFromCol = cellFrom.address[1];
            cellToRow = cell.address[0];
            cellToCol = cell.address[1];
            activateRow = function(row) {
              var c, col, _i, _j, _results, _results1;
              if (cellFromCol <= cellToCol) {
                _results = [];
                for (col = _i = cellFromCol; cellFromCol <= cellToCol ? _i <= cellToCol : _i >= cellToCol; col = cellFromCol <= cellToCol ? ++_i : --_i) {
                  c = table.getCell(row, col);
                  _results.push(c.makeActive(false));
                }
                return _results;
              } else {
                _results1 = [];
                for (col = _j = cellToCol; cellToCol <= cellFromCol ? _j <= cellFromCol : _j >= cellFromCol; col = cellToCol <= cellFromCol ? ++_j : --_j) {
                  c = table.getCell(row, col);
                  _results1.push(c.makeActive(false));
                }
                return _results1;
              }
            };
            if (cellFromRow <= cellToRow) {
              _results = [];
              for (row = _i = cellFromRow; cellFromRow <= cellToRow ? _i <= cellToRow : _i >= cellToRow; row = cellFromRow <= cellToRow ? ++_i : --_i) {
                _results.push(activateRow(row));
              }
              return _results;
            } else {
              _results1 = [];
              for (row = _j = cellToRow; cellToRow <= cellFromRow ? _j <= cellFromRow : _j >= cellFromRow; row = cellToRow <= cellFromRow ? ++_j : --_j) {
                _results1.push(activateRow(row));
              }
              return _results1;
            }
          }
        }
      };
      this.element.ondblclick = function() {
        return cell.edit();
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
      this.control.onkeydown = function(e) {
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
      if (table.mobile) {
        startY = null;
        this.element.ontouchstart = function(e) {
          startY = e.changedTouches[0].clientY;
          Utilities.prototype.clearActiveCells(table);
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
  
  Context Menu
  -----------------------------------------------------------------------------------------
   */

  ContextMenu = (function() {
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
        }
      };
      this.element = document.createElement('div');
      this.element.style.position = 'fixed';
      this.menu = document.createElement('ul');
      Utilities.prototype.setAttributes(this.menu, {
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
      Utilities.prototype.setAttributes(divider, {
        "class": 'divider'
      });
      return this.menu.appendChild(divider);
    };

    ContextMenu.prototype.addAction = function(action) {
      var a, code, div, key, li, shortCut, span;
      li = document.createElement('li');
      div = document.createElement('div');
      span = document.createElement('span');
      span.textContent = action.shortCut;
      span.setAttribute('name', action.name);
      Utilities.prototype.setAttributes(span, {
        style: "float: right !important;"
      });
      a = document.createElement('a');
      a.textContent = action.name;
      a.setAttribute('name', action.name);
      Utilities.prototype.setAttributes(a, {
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
      Utilities.prototype.setStyles(this.element, {
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
      gridChange = new GridChange(table.activeCells, 'ge-blank');
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
      table.copiedGridChange = new GridChange(table.activeCells);
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
      gridChange = new GridChange(table.activeCells, fillValue);
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


  /*
  
    Cell Type Behavior
    -----------------------------------------------------------------------------------------
    generic behavior will be in GenericCell class
    type specific behavior will be in the associated <type>Cell class
   */

  GenericCell = (function() {
    function GenericCell(cell) {
      var node;
      this.cell = cell;
      node = document.createTextNode(this.cell.originalValue);
      this.cell.control = document.createElement('input');
      this.cell.element.appendChild(node);
    }

    GenericCell.prototype.initControl = function() {
      return this.cell.control.value = this.cell.value();
    };

    GenericCell.prototype.formatValue = function(newValue) {
      return newValue;
    };

    GenericCell.prototype.setValue = function(newValue) {
      return this.cell.source[this.cell.valueKey] = newValue;
    };

    GenericCell.prototype.value = function() {
      return this.cell.value();
    };

    GenericCell.prototype.render = function() {
      return this.cell.element.textContent;
    };

    GenericCell.prototype.select = function() {
      return this.cell.control.select();
    };

    return GenericCell;

  })();

  StringCell = (function(_super) {
    __extends(StringCell, _super);

    function StringCell() {
      return StringCell.__super__.constructor.apply(this, arguments);
    }

    return StringCell;

  })(GenericCell);

  NumberCell = (function(_super) {
    __extends(NumberCell, _super);

    function NumberCell() {
      return NumberCell.__super__.constructor.apply(this, arguments);
    }

    NumberCell.prototype.formatValue = function(newValue) {
      return Number(newValue);
    };

    NumberCell.prototype.setValue = function(newValue) {
      return this.cell.source[this.cell.valueKey] = Number(newValue);
    };

    return NumberCell;

  })(GenericCell);

  DateCell = (function(_super) {
    __extends(DateCell, _super);

    function DateCell(cell) {
      var node;
      this.cell = cell;
      node = document.createTextNode(this.toDateString(this.cell.originalValue));
      this.cell.control = this.toDate();
      if (this.cell.originalValue) {
        this.cell.control.valueAsDate = new Date(this.cell.originalValue);
      }
      this.cell.element.appendChild(node);
    }

    DateCell.prototype.formatValue = function(newValue) {
      if (newValue.length > 0) {
        return this.toDateString(Date.parse(newValue));
      } else if (newValue instanceof Date) {
        return this.toDateString(newValue);
      } else if (newValue.length === 0) {
        this.cell.control.valueAsDate = null;
        return '';
      }
    };

    DateCell.prototype.setValue = function(newValue) {
      this.cell.source[this.cell.valueKey] = new Date(newValue);
      return this.cell.control.valueAsDate = new Date(newValue);
    };

    DateCell.prototype.initControl = function() {
      DateCell.__super__.initControl.call(this);
      return this.cell.control.value = this.toDateInputString(this.cell.value());
    };

    DateCell.prototype.value = function() {
      return this.cell.control.valueAsDate;
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

  })(GenericCell);

  HTMLCell = (function(_super) {
    __extends(HTMLCell, _super);

    function HTMLCell(cell) {
      var node;
      this.cell = cell;
      this.cell.htmlContent = this.cell.col.defaultValue || this.cell.originalValue;
      node = this.toFragment();
      this.cell.control = document.createElement('input');
      this.cell.element.appendChild(node);
    }

    HTMLCell.prototype.setValue = function(newValue) {
      var node;
      this.cell.htmlContent = newValue;
      node = this.toFragment();
      this.cell.element.innerHTML = "";
      return this.cell.element.appendChild(node);
    };

    HTMLCell.prototype.toFragment = function() {
      var element, fragment;
      element = document.createElement("div");
      fragment = document.createDocumentFragment();
      element.innerHTML = this.cell.htmlContent;
      fragment.appendChild(element.firstChild || document.createTextNode(''));
      return fragment;
    };

    HTMLCell.prototype.render = function() {
      return this.htmlContent;
    };

    return HTMLCell;

  })(GenericCell);

  SelectCell = (function(_super) {
    __extends(SelectCell, _super);

    function SelectCell(cell) {
      var node;
      this.cell = cell;
      node = document.createTextNode(this.cell.originalValue || '');
      this.initControl();
      this.cell.element.appendChild(node);
    }

    SelectCell.prototype.initControl = function() {
      var cell, choice, index, option, select, subchoice, _i, _j, _len, _len1, _ref;
      cell = this.cell;
      select = document.createElement("select");
      if (!this.cell.meta.choices) {
        console.log("There is not a 'choices' key in cell " + this.cell.address + " and you specified that it was of type 'select'");
      }
      _ref = this.cell.meta.choices;
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
      select.classList.add('form-control');
      select.onchange = function(e) {
        return cell.edit(e.target.value);
      };
      return this.cell.control = select;
    };

    SelectCell.prototype.select = function() {};


    /*
    
    	Grid Change
    	-----------------------------------------------------------------------------------------
     */

    return SelectCell;

  })(GenericCell);

  GridChange = (function() {
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


  /*
  
  	ActionStack
  	-----------------------------------------------------------------------------------------
    used for undo/redo functionality
  
    todo - splice actions array at X elements to conserve memory
   */

  ActionStack = (function() {
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
            return cell.value(action.oldValue, false);
          case 'cut':
            return action.grid.undo(false, false);
          case 'paste':
            return action.grid.undo(action.x, action.y);
          case 'fill':
            return action.grid.undo(false, false);
          case 'add-row':
            return this.table.removeRow(action.index, false);
          case 'remove-row':
            return this.table.addRow(action.index, false);
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
            return cell.value(action.newValue, false);
          case 'cut':
            return action.grid.apply(false, false);
          case 'paste':
            return action.grid.apply(action.x, action.y);
          case 'fill':
            return action.grid.apply(false, false);
          case 'add-row':
            return this.table.addRow(action.index, false);
          case 'remove-row':
            return this.table.removeRow(action.index, false);
        }
      }
    };

    return ActionStack;

  })();

  root = typeof exports !== "undefined" && exports !== null ? exports : window;

  root.GridEdit = GridEdit;

}).call(this);
