(function() {
  var Cell, ContextMenu, GridEdit, Row, Utilities, root,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

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
            redCell.removeClass('uneditable');
          }
        }
        table.redCells = [];
      }
      if (activeCells.length > 0) {
        for (index = _j = 0, _len1 = activeCells.length; _j < _len1; index = ++_j) {
          activeCell = activeCells[index];
          if (activeCell != null) {
            activeCell.removeClass('active');
          }
          if (activeCell != null) {
            activeCell.hideControl;
          }
        }
        table.activeCells = [];
      }
      table.selectionStart = null;
      table.selectionEnd = null;
      return table.contextMenu.hide();
    };

    Utilities.prototype.capitalize = function(string) {
      return string.toLowerCase().replace(/\b./g, function(a) {
        return a.toUpperCase();
      });
    };

    return Utilities;

  })();

  GridEdit = (function() {
    function GridEdit(config) {
      var key, value, _ref;
      this.config = config;
      this.element = document.querySelectorAll(this.config.element || '#gridedit')[0];
      this.headers = [];
      this.rows = [];
      this.cols = this.config.cols;
      this.source = this.config.rows;
      this.redCells = [];
      this.activeCells = [];
      this.copiedCells = [];
      this.selectionStart = null;
      this.selectionEnd = null;
      this.openCell = null;
      this.state = "ready";
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
      this.contextMenu = new ContextMenu(['cut', 'copy', 'paste', 'fill'], this);
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
      var col, i, row, rowAttributes, table, tbody, textNode, th, thead, tr, _i, _j, _len, _len1, _ref, _ref1;
      tr = document.createElement('tr');
      _ref = this.config.cols;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        col = _ref[_i];
        th = document.createElement('th');
        if (typeof col === 'object') {
          textNode = document.createTextNode(col.label);
        } else if (typeof header === 'string') {
          textNode = document.createTextNode(header);
        }
        th.appendChild(textNode);
        tr.appendChild(th);
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
      var config, option;
      if (newConfig == null) {
        newConfig = null;
      }
      config = Object.create(this.config);
      if (newConfig !== null) {
        for (option in newConfig) {
          if (newConfig[option]) {
            config[option] = newConfig[option];
          }
        }
      }
      this.destroy();
      return this.constructor(config);
    };

    GridEdit.prototype.events = function() {
      var edit, moveTo, table;
      table = this;
      moveTo = table.moveTo;
      edit = table.edit;
      document.onkeydown = function(e) {
        var cmd, ctrl, key, shift, valueFromKey;
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
            }
          };
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
            case 67:
              if (cmd || ctrl) {
                return table.copy();
              }
              break;
            case 86:
              if (cmd || ctrl) {
                return table.paste();
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
                return table.activeCell().value('');
              }
              break;
            case 46:
              if (!table.openCell) {
                e.preventDefault();
                return table.activeCell().value('');
              }
              break;
            default:
              if (__indexOf.call([96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111], key) >= 0) {
                key = key - 48;
              }
              if (!table.openCell) {
                return table.activeCell().showControl(valueFromKey(key));
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
        if (!table.isDescendant(e.target)) {
          return Utilities.prototype.clearActiveCells(table);
        }
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
      return this.rows[x].cells[y];
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

    GridEdit.prototype.moveTo = function(cell) {
      if (cell != null) {
        cell.makeActive();
      }
      return false;
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

    GridEdit.prototype.setSelection = function() {
      var cell, col, colRange, row, rowRange, _i, _j, _k, _l, _len, _len1, _len2, _m, _ref, _ref1, _ref2, _ref3, _ref4, _results, _results1;
      if (this.selectionStart !== this.selectionEnd) {
        _ref = this.activeCells;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          cell = _ref[_i];
          cell.removeFromSelection();
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
          rowData.push(cell.type === 'date' ? cell.control.valueAsDate : cell.value());
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

    GridEdit.prototype.copy = function(selection) {
      if (selection == null) {
        selection = this.activeCells;
      }
      return this.copiedCells = selection;
    };

    GridEdit.prototype.paste = function(selection) {
      if (selection == null) {
        selection = this.activeCells;
      }
      return this.activeCells = this.copiedCells;
    };

    GridEdit.prototype.cut = function() {};

    GridEdit.prototype.filldown = function() {};

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

    return GridEdit;

  })();

  Row = (function() {
    function Row(attributes, table) {
      var cell, col, _i, _len, _ref;
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
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        col = _ref[_i];
        cell = new Cell(this.attributes[col.valueKey], this);
        this.cells.push(cell);
        this.element.appendChild(cell.element);
      }
      delete this.attributes;
    }

    Row.prototype.below = function() {
      return this.table.rows[this.id + 1];
    };

    Row.prototype.above = function() {
      return this.table.rows[this.id - 1];
    };

    return Row;

  })();

  Cell = (function() {
    function Cell(attributes, row) {
      var node, styleName, _ref, _ref1;
      this.attributes = attributes;
      this.row = row;
      this.id = "" + this.row.id + "-" + this.row.cells.length;
      this.address = [this.row.id, this.row.cells.length];
      this.index = this.row.cells.length;
      this.table = this.row.table;
      this.col = this.table.cols[this.index];
      this.type = this.col.type;
      this.meta = this.col;
      if ('editable' in this.col) {
        this.editable = this.col.editable;
      } else {
        this.editable = true;
      }
      this.element = document.createElement('td');
      this.originalValue = this.attributes;
      this.val = this.originalValue;
      this.previousValue = null;
      this.valueKey = this.col.valueKey;
      this.source = this.table.config.rows[this.address[0]];
      this.beforeEdit = this.table.config.beforeEdit;
      this.afterEdit = this.table.config.afterEdit;
      this.beforeActivate = this.table.config.beforeCellActivate;
      this.afterActivate = this.table.config.afterCellActivate;
      this.beforeControlInit = this.table.config.beforeControlInit;
      this.afterControlInit = this.table.config.afterControlInit;
      this.onClick = this.table.config.onCellClick;
      Utilities.prototype.setAttributes(this.element, {
        id: "cell-" + this.id,
        "class": ((_ref = this.attributes) != null ? _ref["class"] : void 0) || '',
        style: ((_ref1 = this.attributes) != null ? _ref1.styles : void 0) || ''
      });
      if (this.col.style) {
        for (styleName in this.col.style) {
          this.element.style[styleName] = this.col.style[styleName];
        }
      }
      switch (this.type) {
        case 'string':
          node = document.createTextNode(this.attributes);
          this.control = document.createElement('input');
          break;
        case 'number':
          node = document.createTextNode(this.attributes);
          this.control = document.createElement('input');
          break;
        case 'date':
          node = document.createTextNode(this.toDateString(this.attributes));
          this.control = this.toDate();
          break;
        case 'html':
          this.htmlContent = this.attributes;
          node = this.toFragment();
          this.control = document.createElement('input');
          break;
        case 'select':
          node = document.createTextNode(this.attributes || '');
          this.control = this.toSelect();
      }
      this.element.appendChild(node);
      this.events(this);
    }

    Cell.prototype.setNewHTMLValue = function(newValue) {
      var node;
      this.htmlContent = newValue;
      node = this.toFragment();
      this.element.innerHTML = "";
      return this.element.appendChild(node);
    };

    Cell.prototype.value = function(newValue) {
      var oldValue;
      if (newValue == null) {
        newValue = null;
      }
      if (newValue !== null && newValue !== this.element.textContent) {
        if (this.type === 'date') {
          if (newValue.length > 0) {
            newValue = this.toDateString(Date.parse(newValue));
          } else if (newValue instanceof Date) {
            newValue = this.toDateString(newValue);
          } else if (newValue.length === 0) {
            newValue = "";
            this.control.valueAsDate = null;
          }
        }
        oldValue = this.value();
        if (this.beforeEdit) {
          this.beforeEdit(this, oldValue, newValue);
        }
        this.previousValue = this.element.textContent;
        this.element.textContent = newValue;
        if (this.type === 'number') {
          this.source[this.valueKey] = Number(newValue);
        } else if (this.type === 'date') {
          this.source[this.valueKey] = new Date(newValue);
        } else if (this.type === 'html') {
          this.setNewHTMLValue(newValue);
        } else {
          this.source[this.valueKey] = newValue;
        }
        Utilities.prototype.setStyles(this.control, this.position());
        if (this.afterEdit) {
          this.afterEdit(this, oldValue, newValue);
        }
        return newValue;
      } else {
        if (this.type !== 'html') {
          return this.element.textContent;
        } else {
          return this.htmlContent;
        }
      }
    };

    Cell.prototype.makeActive = function() {
      var beforeActivateReturnVal;
      Utilities.prototype.clearActiveCells(this.table);
      if (this.beforeActivate(this)) {
        beforeActivateReturnVal = this.beforeActivate(this);
      }
      if (this.beforeActivate && beforeActivateReturnVal !== false || !this.beforeActivate) {
        this.addClass('active');
        this.table.activeCells.push(this);
        this.table.selectionStart = this;
        if (this.table.openCell) {
          this.table.openCell.edit(this.table.openCell.control.value);
        }
        if (this.afterActivate(this)) {
          return this.afterActivate(this);
        }
      }
    };

    Cell.prototype.addToSelection = function() {
      this.addClass('active');
      return this.table.activeCells.push(this);
    };

    Cell.prototype.isActive = function() {
      return this.table.activeCells.indexOf(this) !== -1;
    };

    Cell.prototype.removeFromSelection = function() {
      return this.removeClass('active');
    };

    Cell.prototype.showRed = function() {
      this.addClass('uneditable');
      return this.table.redCells.push(this);
    };

    Cell.prototype.showControl = function(value) {
      var beforeControlInitReturnVal, cell, control;
      if (value == null) {
        value = null;
      }
      if (!this.editable) {
        return this.showRed();
      } else {
        if (this.beforeControlInit) {
          beforeControlInitReturnVal = this.beforeControlInit(this);
        }
        if (this.beforeControlInit && beforeControlInitReturnVal !== false || !this.beforeControlInit) {
          if (value !== null) {
            if (this.type === 'date') {
              this.control.valueAsDate = new Date(this.value());
            } else {
              this.control.value = value;
            }
            this.control.value = value;
            control = this.control;
            setTimeout(function() {
              return control.focus();
            }, 0);
          } else {
            if (this.type === 'select') {
              this.control = this.toSelect();
              cell = this;
              this.control.onchange = function(e) {
                return cell.edit(e.target.value);
              };
            }
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
      if (this.table.openCell !== null) {
        this.table.element.removeChild(this.control);
        return this.table.openCell = null;
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
          if (this.type !== 'select') {
            return this.control.select();
          }
        }
      }
    };

    Cell.prototype.position = function() {
      return this.element.getBoundingClientRect();
    };

    Cell.prototype.reposition = function() {
      return Utilities.prototype.setStyles(this.control, this.position());
    };

    Cell.prototype.next = function() {
      return this.row.cells[this.index + 1];
    };

    Cell.prototype.previous = function() {
      return this.row.cells[this.index - 1];
    };

    Cell.prototype.above = function() {
      var _ref;
      return (_ref = this.row.above()) != null ? _ref.cells[this.index] : void 0;
    };

    Cell.prototype.below = function() {
      var _ref;
      return (_ref = this.row.below()) != null ? _ref.cells[this.index] : void 0;
    };

    Cell.prototype.addClass = function(newClass) {
      return this.element.classList.add(newClass);
    };

    Cell.prototype.removeClass = function(classToRemove) {
      return this.element.classList.remove(classToRemove);
    };

    Cell.prototype.toFragment = function() {
      var element, fragment;
      element = document.createElement("div");
      fragment = document.createDocumentFragment();
      element.innerHTML = this.htmlContent;
      fragment.appendChild(element.firstChild || document.createTextNode(''));
      return fragment;
    };

    Cell.prototype.toSelect = function() {
      var choice, index, option, select, subchoice, _i, _j, _len, _len1, _ref;
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
        if (this.value() === choice) {
          option.selected = true;
        }
        select.add(option);
      }
      select.classList.add('form-control');
      return select;
    };

    Cell.prototype.toDateString = function(passedDate) {
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

    Cell.prototype.toDate = function() {
      var input;
      input = document.createElement('input');
      input.type = 'date';
      input.value = this.toDateString();
      return input;
    };

    Cell.prototype.isBeingEdited = function() {
      return this.control.parentNode != null;
    };

    Cell.prototype.events = function(cell) {
      var activeCells, redCells, table;
      table = cell.table;
      redCells = table.redCells;
      activeCells = table.activeCells;
      this.element.onclick = function(e) {
        var onClickReturnVal;
        if (cell.onClick) {
          onClickReturnVal = cell.onClick(cell, e);
        }
        if (onClickReturnVal === false) {
          return false;
        }
      };
      this.element.ondblclick = function() {
        return cell.edit();
      };
      this.element.onmousedown = function(e) {
        if (e.which === 3) {
          table.contextMenu.show(e.x, e.y, cell);
          return;
        }
        table.state = "selecting";
        cell.makeActive();
        return false;
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
          table.setSelection();
          return table.state = "ready";
        }
      };
      this.control.onkeydown = function(e) {
        var key, _ref;
        key = e.which;
        switch (key) {
          case 13:
            cell.edit(this.value);
            return (_ref = cell.below()) != null ? _ref.makeActive() : void 0;
        }
      };
      if (this.type === 'select' || 'date') {
        return this.control.onchange = function(e) {
          return cell.edit(e.target.value);
        };
      }
    };

    return Cell;

  })();

  ContextMenu = (function() {
    function ContextMenu(actions, table) {
      var a, action, divider, li, ul, _i, _len, _ref;
      this.actions = actions;
      this.table = table;
      this.defaultActions = ['cut', 'copy', 'paste', 'fill'];
      this.element = document.createElement('div');
      this.actionNodes = {};
      Utilities.prototype.setAttributes(this.element, {
        id: 'contextMenu',
        "class": 'dropdown clearfix'
      });
      ul = document.createElement('ul');
      Utilities.prototype.setAttributes(ul, {
        "class": 'dropdown-menu',
        role: 'menu',
        'aria-labelledby': 'aria-labelledby',
        style: 'display:block;position:static;margin-bottom:5px;'
      });
      _ref = this.defaultActions;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        action = _ref[_i];
        li = document.createElement('li');
        divider = document.createElement('li');
        Utilities.prototype.setAttributes(divider, {
          "class": 'divider'
        });
        a = document.createElement('a');
        a.textContent = Utilities.prototype.capitalize(action);
        if (__indexOf.call(this.actions, action) >= 0) {
          Utilities.prototype.setAttributes(a, {
            "class": 'enabled',
            tabIndex: '-1'
          });
        } else {
          Utilities.prototype.setAttributes(a, {
            "class": 'disabled',
            tabIndex: '-1'
          });
        }
        if (action === 'fill') {
          ul.appendChild(divider);
        }
        this.actionNodes[action] = a;
        li.appendChild(a);
        ul.appendChild(li);
      }
      this.element.appendChild(ul);
      this.events(this);
    }

    ContextMenu.prototype.show = function(x, y, cell) {
      if (cell.isActive()) {
        Utilities.prototype.setStyles(this.element, {
          left: x,
          top: y
        });
        return this.table.tableEl.appendChild(this.element);
      }
    };

    ContextMenu.prototype.hide = function() {
      if (this.isVisible()) {
        return this.table.tableEl.removeChild(this.element);
      }
    };

    ContextMenu.prototype.isVisible = function() {
      return this.element.parentNode != null;
    };

    ContextMenu.prototype.toggle = function(action) {
      var classes;
      classes = this.actionNodes[action].classList;
      classes.toggle('enabled');
      return classes.toggle('disabled');
    };

    ContextMenu.prototype.events = function(menu) {
      return this.element.onclick = function(e) {
        if (e.target.textContent === 'Cut') {
          console.log(e.target.textContent);
        }
        if (e.target.textContent === 'Copy') {
          console.log('copy');
        }
        if (e.target.textContent === 'Paste') {
          console.log('paste');
        }
        if (e.target.textContent === 'Fill') {
          return console.log('fill');
        }
      };
    };

    return ContextMenu;

  })();

  root = typeof exports !== "undefined" && exports !== null ? exports : window;

  root.GridEdit = GridEdit;

}).call(this);
