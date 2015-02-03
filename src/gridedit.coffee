class Utilities
  constructor: ->
  setAttributes: (el, attrs) ->
    for key, value of attrs
      el.setAttribute key, value if value
  setStyles: (el, styles) ->
    for key, value of styles
      el.style[key] = "#{value}px"
  clearActiveCells: (table) ->
    redCells = table.redCells
    activeCells = table.activeCells
    if redCells.length > 0
      for redCell, index in redCells
        redCell?.makeInactive()
      table.redCells = []
    if activeCells.length > 0
      for activeCell, index in activeCells
        activeCell?.makeInactive()
        activeCell?.hideControl()
      table.activeCells = []
    table.selectionStart = null
    table.selectionEnd = null
    table.contextMenu.hide()
    if table.selectedCol then table.selectedCol.makeInactive()
  capitalize: (string) -> string.toLowerCase().replace /\b./g, (a) -> a.toUpperCase()

class GridEdit
  constructor: (@config, @actionStack) ->
    @element = document.querySelectorAll(@config.element || '#gridedit')[0]
    @headers = []
    @rows = []
    @subtotalRows = []
    @cols = []
    @source = @config.rows
    @redCells = []
    @activeCells = []
    @copiedCells = null
    @selectionStart = null
    @selectionEnd = null
    @selectedCol = null
    @openCell = null
    @state = "ready"
    @mobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
    @topOffset = if not @config.topOffset then 0 else @config.topOffset
    @cellStyles =
      activeColor: "#FFE16F"
      uneditableColor: "#FFBBB3"
    if @config.custom
      @set key, value for key, value of @config.custom when key of @config.custom
      delete @config.custom
    do @init if @config.initialize
    @copiedCellMatrix = null
    @contextMenu = new ContextMenu @
    @actionStack = new ActionStack(@) unless @actionStack
    if @config.selectedCell
      cell = @getCell(@config.selectedCell[0], @config.selectedCell[1])
      cell.makeActive() if cell
      @config.selectedCell = undefined # don't let this propagate to next rebuild
  init: ->
    do @config.beforeInit if @config.beforeInit
    do @build
    do @events
    do @render
    do @config.afterInit if @config.afterInit
    return
  build: ->
    # Build Table Header
    tr = document.createElement 'tr'

    if @config.includeRowHandles
      handleHeader = document.createElement 'th'
      tr.appendChild handleHeader

    for colAttributes, i in @config.cols
      col = new Column(colAttributes, @)
      @cols.push col
      tr.appendChild col.element
    thead = document.createElement 'thead'
    thead.appendChild tr

    # Build Table Body
    tbody = document.createElement 'tbody'
    for rowAttributes, i in @source
      row = new Row rowAttributes, @
      @rows.push row
      tbody.appendChild row.element

    #Build Table
    table = document.createElement 'table'
    Utilities::setAttributes table, {id: 'editable-grid', class: @config.tableClass}
    table.appendChild thead
    table.appendChild tbody
    @tableEl = table
  rebuild: (newConfig = null) ->
    config = Object.create @config
    if newConfig isnt null
      for optionKey, optionValue of newConfig
        config[optionKey] = newConfig[optionKey]
    actionStack = @actionStack
    do @destroy
    @constructor(config, actionStack)
  events: ->
    table = @
    moveTo = table.moveTo
    edit = table.edit
    document.onkeydown = (e) ->
      if table.activeCell()
        key = e.keyCode
        shift = e.shiftKey
        ctrl = e.ctrlKey
        cmd = e.metaKey

        valueFromKey = (key, shift) ->
          char = String.fromCharCode key
          if not shift then char.toLowerCase() else char

        openCellAndPopulateInitialValue = -> if not table.openCell then table.activeCell().showControl(valueFromKey key, shift)

        if cmd or ctrl
          if key && key != 91 && key != 92
            if table.contextMenu.actionCallbacks.byControl[key]
              e.preventDefault();
              table.contextMenu.actionCallbacks.byControl[key](e, table)


        else
          switch key
            when 39 # right arrow
              if not table.activeCell().isBeingEdited()
                moveTo table.nextCell()
            when 9
              if shift then moveTo table.previousCell() else moveTo table.nextCell()
            when 37 then moveTo table.previousCell()
            when 38 then moveTo table.aboveCell()
            when 40 then moveTo table.belowCell()
            when 32 # space
              if not table.openCell then edit table.activeCell()
            when 13 then break
            when 16 then break
            when 17 then break
            when 91 then break
            when 8
              if not table.openCell
                e.preventDefault()
                table.delete()
            when 46
              if not table.openCell
                e.preventDefault()
                table.delete()
            else
              key = key - 48 if key in [96..111] # For numpad
              openCellAndPopulateInitialValue()
    window.onresize = -> Utilities::setStyles table.openCell.control, table.openCell.position() if table.openCell
    window.onscroll = -> table.openCell.reposition() if table.openCell
    @tableEl.oncontextmenu = (e) -> false
    document.onclick = (e) ->
      Utilities::clearActiveCells table unless (table.isDescendant e.target) or (e.target is table.activeCell()?.control or table.contextMenu)
      table.contextMenu.hide()
  render: ->
    @element = document.querySelectorAll(@config.element || '#gridedit')[0] if @element.hasChildNodes()
    @element.appendChild @tableEl
  set: (key, value) -> @config[key] = value if key isnt undefined
  getCell: (x, y) ->
    try
      @rows[x].cells[y]
    catch e
      # out of range
  activeCell: -> if @activeCells.length > 1 then @activeCells else @activeCells[0]
  nextCell: -> @activeCell()?.next()
  previousCell: -> @activeCell()?.previous()
  aboveCell: -> @activeCell()?.above()
  belowCell: -> @activeCell()?.below()
  moveTo: (toCell, fromCell) ->
    if toCell
      fromCell = toCell.table.activeCell() if fromCell is undefined
      direction = toCell.table.getDirection(fromCell, toCell)
      beforeCellNavigateReturnVal = toCell.beforeNavigateTo(toCell, fromCell, direction) if toCell.beforeNavigateTo
      if beforeCellNavigateReturnVal isnt false
        if not toCell.isVisible()
          oldY = toCell.table.activeCell().address[0]
          newY = toCell.address[0]
          directionModifier = 1
          if newY < oldY # Then going up - This is because you need -1 for scrolling up to work properly
            directionModifier = -1
          window.scrollBy(0, toCell?.position().height * directionModifier)
        do toCell.makeActive
    false
  getDirection: (fromCell, toCell) ->
    fromAddressY = fromCell.address[0]
    toAddressY = toCell.address[0]
    fromAddressX = fromCell.address[1]
    toAddressX = toCell.address[1]
    if fromAddressY is toAddressY # Going right or left
      if fromAddressX > toAddressX # Going Left
        direction = "left"
      else if fromAddressX < toAddressX # Going Right
        direction = "right"
      else
        console.log("Cannot calculate direction going from cell #{fromCell.address} to cell #{toCell.address}")
    else if fromAddressY > toAddressY # Going Up
      direction = "up"
    else if fromAddressY < toAddressY # Going Down
      direction = "down"
    else
      console.log("Cannot calculate direction going from cell #{fromCell.address} to cell #{toCell.address}")
    direction
  edit: (cell, newValue = null) ->
    if newValue isnt null
      cell?.edit newValue
    else
      do cell?.edit
      false
  delete: ->
    for cell in @activeCells
      cell.value('')
  clearActiveCells: -> Utilities::clearActiveCells @
  setSelection: ->
    if @selectionStart and @selectionEnd and @selectionStart isnt @selectionEnd
      do cell.showInactive for cell in @activeCells
      @activeCells = []
      rowRange = [@selectionStart.address[0]..@selectionEnd.address[0]]
      colRange = [@selectionStart.address[1]..@selectionEnd.address[1]]
      for row in rowRange
        @rows[row].cells[col].addToSelection() for col in colRange
      return
  data: ->
    data = []
    for row in @rows
      rowData = []
      for cell in row.cells
        rowData.push cell.cellTypeObject.value()
      data.push rowData
    data
  repopulate: ->
    for row in @rows
      for cell in row.cells
        cell.value(cell.source[cell.valueKey])
  destroy: ->
    @element.removeChild @tableEl
    for key of @
      delete @[key]
  isDescendant: (child) ->
    node = child.parentNode
    while node?
      return true if node is @tableEl
      node = node.parentNode
    false
  addToStack: (action) ->
    @actionStack.addAction(action)
  undo: ->
    @actionStack.undo()
  redo: ->
    @actionStack.redo()

  addRow: (index, addToStack=true, rowObject=false) ->
    if rowObject
      row = rowObject
    else
      row = {}
      for c in @cols
        row[c.valueKey] = c.defaultValue || ''

    if index or index == 0
      @source.splice(index, 0, row)
    else
      index = @source.length - 1
      @source.push(row)

    @addToStack({ type: 'add-row', index: index }) if addToStack
    @rebuild({ rows: @source, initialize: true, selectedCell: [index, 0] })


  insertBelow: ->
    cell = @.contextMenu.getTargetPasteCell()
    @addRow(cell.address[0] + 1)

  insertAbove: ->
    cell = @.contextMenu.getTargetPasteCell()
    @addRow(cell.address[0])


  removeRow: (index, addToStack=true) ->
    rows = @source.splice(index, 1)
    @addToStack({ type: 'remove-row', index: index }) if addToStack
    @rebuild({ rows: @source, initialize: true, selectedCell: [ index, 0 ] })

  selectRow: (index) ->
    row = @rows[index]
    row.select()

  calculateSubtotals: () ->
    for row in @subtotalRows
      row.calculate()

class Column
  constructor: (@attributes, @table) ->
    @id = @index = @table.cols.length
    @defaultValue = @attributes.defaultValue
    @cellClass = @attributes.cellClass
    @cells = []
    @element = document.createElement 'th'
    @textNode = document.createTextNode @attributes.label
    @element.appendChild @textNode
    format = @attributes.format
    @format = (v) -> if format then format(v) else v
    for key, value of @attributes
      @[key] = value
    delete @attributes
    do @events
  next: -> @table.cols[@index + 1]
  previous: -> @table.cols[@index - 1]
  makeActive: ->
    @element.classList.add('active')
    @table.selectedCol = @
  makeInactive: ->
    @element.classList.remove('active')
    @table.selectedCol = null
  events: ->
    col = @
    table = col.table
    @element.onclick = (e) ->
      Utilities::clearActiveCells table
      col.makeActive()
      for cell in col.cells
        cell.addToSelection()
    @element.onmousedown = (e) ->
      if e.which is 3
        table.contextMenu.show(e.x, e.y, col.cells[0])
        return
      false

# Receives an array or object of Cells and is passed to a GridEdit
class Row
  constructor: (@attributes, @table) ->
    @id = @table.rows.length
    @cells = []
    @index = @table.rows.length
    @element = document.createElement 'tr'

    switch @attributes.gridEditRowType
      when 'static'
        @rowTypeObject = new StaticRow(@)
      when 'subtotal'
        @rowTypeObject = new SubTotalRow(@)
      else
        @rowTypeObject = new GenericRow(@)

    Utilities::setAttributes @element,
      id: "row-#{@id}"


    delete @attributes
  below: -> @table.rows[@index + 1]
  above: -> @table.rows[@index - 1]
  select: ->
    for cell in @cells
      cell.addToSelection()

# Creates a cell object in memory to store in a row
class Cell
  constructor: (@originalValue, @row) ->
    @originalValue = '' if @originalValue == undefined
    @id = "#{@row.id}-#{@row.cells.length}"
    @address = [@row.id, @row.cells.length]
    @index = @row.cells.length
    @table = @row.table
    @col = @table.cols[@index]
    @type = @col.type
    @meta = @col
    @editable = @col.editable != false
    @element = document.createElement 'td'
    @element.classList.add @col.cellClass if @col.cellClass
    @valueKey = @col.valueKey
    @source = @table.config.rows[@address[0]]
    @initCallbacks()
    if @col.style
      for styleName of @col.style
        @element.style[styleName] = @col.style[styleName]
    switch @type
      when 'string'
        @cellTypeObject = new StringCell(@)
      when 'number'
        @cellTypeObject = new NumberCell(@)
      when 'date'
        @cellTypeObject = new DateCell(@)
      when 'html'
        @cellTypeObject = new HTMLCell(@)
      when 'select'
        @cellTypeObject = new SelectCell(@)
      when 'textarea'
        @cellTypeObject = new TextAreaCell(@)
    @events @
  initCallbacks: ->
    @beforeEdit = @table.config.beforeEdit if @table.config.beforeEdit
    @afterEdit = @table.config.afterEdit if @table.config.afterEdit
    @beforeActivate = @table.config.beforeCellActivate if @table.config.beforeCellActivate
    @afterActivate = @table.config.afterCellActivate if @table.config.afterCellActivate
    @beforeControlInit = @table.config.beforeControlInit if @table.config.beforeControlInit
    @afterControlInit = @table.config.afterControlInit if @table.config.afterControlInit
    @beforeControlHide = @table.config.beforeControlHide if @table.config.beforeControlHide
    @afterControlHide = @table.config.afterControlHide if @table.config.afterControlHide
    @onClick = @table.config.onCellClick if @table.config.onCellClick
    @beforeNavigateTo = @table.config.beforeCellNavigateTo if @table.config.beforeCellNavigateTo
  value: (newValue = null, addToStack=true) ->
    if newValue isnt null and newValue isnt @element.textContent
      newValue = @cellTypeObject.formatValue(newValue)
      oldValue = @value()
      @beforeEdit(@, oldValue, newValue) if @beforeEdit
      @table.addToStack { type: 'cell-edit', oldValue: oldValue, newValue: newValue, address: @address } if addToStack
      @element.textContent = @col.format(newValue)
      @cellTypeObject.setValue(newValue)
      Utilities::setStyles @control, @position() if @control
      @row.rowTypeObject.afterEdit() if @row.rowTypeObject
      @afterEdit(@, oldValue, newValue, @table.contextMenu.getTargetPasteCell()) if @afterEdit
      return newValue
    else
      @source[@valueKey]
  makeActive: (clearActiveCells = true) ->
    unless @isActive()
      beforeActivateReturnVal = @beforeActivate @ if @beforeActivate
      if @beforeActivate and beforeActivateReturnVal isnt false or not @beforeActivate
        Utilities::clearActiveCells @table if clearActiveCells
        @showActive()
        @table.activeCells.push @
        @table.selectionStart = @
        if @table.openCell
          @table.openCell.edit @table.openCell.control.value
        @afterActivate @ if @afterActivate
  makeInactive: -> @showInactive()
  addToSelection: ->
    @showActive()
    @table.activeCells.push @
  isActive: -> @table.activeCells.indexOf(@) isnt -1
  removeFromSelection: ->
    index = @table.activeCells.indexOf(@)
    @table.activeCells.splice(index, 1)
    @showInactive()
  showActive: ->
    unless @isActive()
      cssText = @element.style.cssText
      @oldCssText = cssText
      @element.style.cssText = cssText + ' ' + "background-color: #{@table.cellStyles.activeColor};"
  showInactive: ->
    @element.style.cssText = @oldCssText
  showRed: ->
    @element.style.cssText = "background-color: #{@table.cellStyles.uneditableColor};"
    @table.redCells.push @
  showControl: (value = null) ->
    Utilities::clearActiveCells(@table)
    @table.contextMenu.hideBorders() if @table.copiedCellMatrix
    if not @editable
      @showRed()
    else
      beforeControlInitReturnVal = @beforeControlInit @ if @beforeControlInit
      if @beforeControlInit and beforeControlInitReturnVal isnt false or not @beforeControlInit
        if value isnt null
          @control.value = value
          control = @control
          setTimeout(->
            control.focus()
          , 0)
        else
          @cellTypeObject.initControl()
        @control.style.position = "fixed"
        Utilities::setStyles @control, @position()
        @table.element.appendChild @control
        @table.openCell = @
        @afterControlInit @ if @afterControlInit
  hideControl: ->
    if @table.openCell isnt null
      beforeControlHideReturnVal = @beforeControlHide @ if @beforeControlHide
      if @beforeControlHide and beforeControlHideReturnVal isnt false or not @beforeControlHide
        @control.parentNode.removeChild(@control) if @isControlInDocument()
        @table.openCell = null
        @afterControlHide @ if @afterControlHide
  edit: (newValue = null) ->
    if not @editable
      @showRed()
    else
      if newValue isnt null
        @value newValue
        if @isBeingEdited() then do @hideControl else do @edit
      else
        do @showControl
        @control.focus()
        @cellTypeObject.select()
  position: -> @element.getBoundingClientRect()
  isVisible: ->
    position = @position()
    (position.top >= @table.topOffset) and (position.bottom <= window.innerHeight)
  isControlInDocument: -> @control.parentNode isnt null
  reposition: ->
    Utilities::setStyles @control, @position()
  next: -> @row.cells[@index + 1] or @row.below()?.cells[0]
  previous: -> @row.cells[@index - 1] or @row.above()?.cells[@row.cells.length - 1]
  above: -> @row.above()?.cells[@index]
  below: -> @row.below()?.cells[@index]
  isBefore: (cell) -> cell.address[0] is @address[0] and cell.address[1] > @address[1]
  isAfter: (cell) -> cell.address[0] is @address[0] and cell.address[1] < @address[1]
  isAbove: (cell) -> cell.address[0] > @address[0] and cell.address[1] is @address[1]
  isBelow: (cell) -> cell.address[0] < @address[0] and cell.address[1] is @address[1]
  addClass: (newClass) -> @element.classList.add newClass
  removeClass: (classToRemove) -> @element.classList.remove classToRemove
  isBeingEdited: -> @control.parentNode?

  toggleActive: ->
    if @isActive()
      @removeFromSelection()
    else
      @makeActive(false)
  events: (cell) ->
    table = cell.table
    redCells = table.redCells
    activeCells = table.activeCells
    @element.onclick = (e) ->
      onClickReturnVal = true
      onClickReturnVal = cell.col.onClick(cell, e) if cell.col.onClick

      if onClickReturnVal != false
        ctrl = e.ctrlKey
        cmd = e.metaKey
        shift = e.shiftKey

        if ctrl or cmd
          cell.toggleActive()

        if shift
          cellFrom = table.activeCells[0]
          cellFromRow = cellFrom.address[0]
          cellFromCol = cellFrom.address[1]

          cellToRow = cell.address[0]
          cellToCol = cell.address[1]

          activateRow = (row) ->
            if cellFromCol <= cellToCol
              for col in [cellFromCol..cellToCol]
                c = table.getCell(row, col)
                c.makeActive(false)
            else
              for col in [cellToCol..cellFromCol]
                c = table.getCell(row, col)
                c.makeActive(false)

          if cellFromRow <= cellToRow
            for row in [cellFromRow..cellToRow]
              activateRow row
          else
            for row in [cellToRow..cellFromRow]
              activateRow row

    @element.ondblclick = ->
      do cell.edit

    @element.onmousedown = (e) ->
      if e.which is 3
        table.contextMenu.show(e.x, e.y, cell)
        return
      else
        unless e.shiftKey or e.ctrlKey or e.metaKey
          table.state = "selecting"
          cell.makeActive()

    @element.onmouseover = (e) ->
      if table.state is 'selecting'
        table.selectionEnd = cell
        do table.setSelection

    @element.onmouseup = (e) ->
      if e.which != 3
        table.selectionEnd = cell
        table.state = "ready"
        do table.setSelection unless e.metaKey or e.ctrlKey

    @control.onkeydown = (e) ->
      key = e.which
      switch key
        when 13 #return
          cell.edit @value
          cell.below()?.makeActive()
        when 9 #tab
          cell.edit @value
          moveTo table.nextCell()

    if table.mobile
      startY = null
      @element.ontouchstart = (e) ->
        startY = e.changedTouches[0].clientY
        Utilities::clearActiveCells table
        if table.openCell then table.openCell.hideControl()
      @element.ontouchend = (e) ->
        y = e.changedTouches[0].clientY
        if e.changedTouches.length < 2 and (y is startY)
          e.preventDefault()
          do cell.edit


###

Context Menu
-----------------------------------------------------------------------------------------

###


class ContextMenu
  constructor: (@table) ->
    @userDefinedActions = @table.config.contextMenuItems
    @userDefinedOrder = @table.config.contextMenuOrder

    ctrlOrCmd = if /Mac/.test(navigator.platform) then 'Cmd' else 'Ctrl'
    @actionNodes = {}
    @actionCallbacks = {
      byName: {},
      byControl: {}
    }
    @borderedCells = []
    @defaultActions = {
      cut: {
        name: 'Cut',
        shortCut: ctrlOrCmd + '+X',
        callback: @cut
      },
      copy: {
        name: 'Copy',
        shortCut: ctrlOrCmd + '+C',
        callback: @copy
      },
      paste: {
        name: 'Paste',
        shortCut: ctrlOrCmd + '+V',
        callback: @paste
      },
      undo: {
        name: 'Undo',
        shortCut: ctrlOrCmd + '+Z',
        callback: @undo
      },
      redo: {
        name: 'Redo',
        shortCut: ctrlOrCmd + '+Y',
        callback: @redo
      },
      fill: {
        name: 'Fill',
        shortCut: '',
        hasDivider: true,
        callback: @fill
      },
      selectAll: {
        name: 'Select All',
        shortCut: ctrlOrCmd + '+A',
        callback: @selectAll
      },
      insertBelow: {
        name: 'Insert Row Below',
        shortCut: '',
        callback: @insertBelow
      },
      insertAbove: {
        name: 'Insert Row Above',
        shortCut: '',
        callback: @insertAbove
      }
    }
    # create the contextMenu div
    @element = document.createElement 'div'
    @element.style.position = 'fixed'
    # create the ul to hold context menu items
    @menu = document.createElement 'ul'
    # todo - remove bootstrap style dependence
    Utilities::setAttributes @menu, {class: 'dropdown-menu', role: 'menu', 'aria-labelledby', style: 'display:block;position:static;margin-bottom:5px;'}

    # if the user specifed a contextMenuOrder
    # only add the actions specified
    # order them as in the array
    if @userDefinedOrder
      for actionName in @userDefinedOrder
        if @userDefinedActions
          action = @userDefinedActions[actionName] || @defaultActions[actionName]
        else
          action = @defaultActions[actionName]
        if action
          @addAction action
    # use the default ordering
    else
      for actionName, action of @defaultActions
        # allow the user to override defaults, or remove them by setting them to false
        continue if @userDefinedActions and (@userDefinedActions[actionName] || @userDefinedActions[actionName] == false)
        @addAction action
      for actionName, action of @userDefinedActions
        @addAction action

    @element.appendChild @menu
    @events @

  # add a divider to the context menu
  addDivider: ->
    divider = document.createElement 'li'
    Utilities::setAttributes divider, {class: 'divider'}
    @menu.appendChild divider

  # add an action to the context menu
  addAction: (action) ->
    li = document.createElement 'li'
    div = document.createElement 'div'
    span = document.createElement 'span'
    span.textContent = action.shortCut
    span.setAttribute('name', action.name)
    Utilities::setAttributes span, {style: "float: right !important;"}
    a = document.createElement 'a'
    a.textContent = action.name
    a.setAttribute('name', action.name)
    Utilities::setAttributes a, {class: 'enabled', tabIndex: '-1'}
    @addDivider() if action.hasDivider
    a.appendChild span
    li.appendChild a
    @actionNodes[action.name] = li
    @actionCallbacks.byName[action.name] = action.callback
    shortCut = action.shortCut
    # register shortcuts to the actionCallbacks index
    # todo - honor shift+key variations ie: Shift+X
    # todo - honor complex shortcut variations ie: Shift+Ctrl+X
    # currently only allowing simple variations of <Ctrl|Cmd>+<key>
    if shortCut
      if /(ctrl|cmd)/i.test shortCut
        key = shortCut.split('+')[1]
        code = key.charCodeAt(0)
        @actionCallbacks.byControl[code] = action.callback
    @menu.appendChild li

  show: (x, y, @cell) ->
    cell.makeActive() if not cell.isActive()
    @cells = cell.table.activeCells
    Utilities::setStyles @element, {left: x, top: y}
    @table.tableEl.appendChild @element

  hide: -> @table.tableEl.removeChild @element if @isVisible()

  isVisible: -> @element.parentNode?

  getTargetPasteCell: -> @table.activeCells.sort(@sortFunc)[0]

  sortFunc: (a, b) -> a.address[0] - b.address[0]

  displayBorders: ->
    @table.copiedGridChange.displayBorders() if @table.copiedGridChange

  hideBorders: ->
    @table.copiedGridChange.removeBorders() if @table.copiedGridChange

  cut: (e, table) ->
    menu = table.contextMenu
    menu.hideBorders()
    gridChange = new GridChange(table.activeCells, 'ge-blank')
    gridChange.apply(false, false)
    table.copiedGridChange = gridChange
    table.addToStack({ type: 'cut', grid: gridChange })
    menu.displayBorders()
    menu.hide()

  copy: (e, table) ->
    menu = table.contextMenu
    table.copiedGridChange = new GridChange(table.activeCells)
    menu.displayBorders()
    menu.hide()

  paste: (e, table) ->
    menu = table.contextMenu
    menu.hide()
    cell = menu.getTargetPasteCell()

    if cell.editable
      gridChange = table.copiedGridChange
      x = cell.address[0]
      y = cell.address[1]
      gridChange.apply(x, y)
      table.addToStack({ type: 'paste', grid: gridChange, x: x, y: y })

  fill: (e, table) ->
    menu = table.contextMenu
    cell = menu.getTargetPasteCell()
    fillValue = cell.value()
    gridChange = new GridChange(table.activeCells, fillValue)
    gridChange.apply(false, false)
    table.addToStack({ type: 'fill', grid: gridChange })
    menu.hide()

  selectAll: (e, table) ->
    table.clearActiveCells()
    for row in table.rows
      for cell in row.cells
        cell.addToSelection()

  insertBelow: (e, table) ->
    table.insertBelow()

  insertAbove: (e, table) ->
    table.insertAbove()

  undo: (e, table) ->
    table.undo()

  redo: (e, table) ->
    table.redo()

  toggle: (action) ->
    classes = @actionNodes[action].classList
    classes.toggle 'enabled'
    classes.toggle 'disabled'

  events: (menu) ->
    @element.onclick = (e) ->
      actionName = e.target.getAttribute('name')
      menu.actionCallbacks.byName[actionName](e, menu.table)


###

  Cell Type Behavior
  -----------------------------------------------------------------------------------------
  generic behavior will be in GenericCell class
  type specific behavior will be in the associated <type>Cell class

###

# Generic Cell
class GenericCell
  constructor: (@cell) ->
    node = document.createTextNode @cell.col.format(@cell.originalValue)
    @cell.control = document.createElement 'input'
    @cell.element.appendChild node

  initControl: ->
    @cell.control.value = @cell.value()

  formatValue: (newValue) ->
    newValue

  setValue: (newValue) ->
    @cell.source[@cell.valueKey] = newValue

  value: ->
    @cell.value()

  render: ->
    @cell.element.textContent

  select: ->
    @cell.control.select()

# String Cell
class StringCell extends GenericCell

# Number Cell
class NumberCell extends GenericCell
  formatValue: (newValue) ->
    Number(newValue)

  setValue: (newValue) ->
    @cell.source[@cell.valueKey] = Number(newValue)

# Date Cell
class DateCell extends GenericCell
  constructor: (@cell) ->
    node = document.createTextNode @toDateString @cell.originalValue
    @cell.control = @toDate()
    @cell.control.valueAsDate = new Date(@cell.originalValue) if @cell.originalValue
    @cell.element.appendChild node

  formatValue: (newValue) ->
    if newValue.length > 0
      @toDateString(Date.parse(newValue))
    else if newValue instanceof Date
      @toDateString newValue
    else if newValue.length is 0
      @cell.control.valueAsDate = null
      ''

  setValue: (newValue) ->
    @cell.source[@cell.valueKey] = new Date(newValue)
    @cell.control.valueAsDate = new Date(newValue)

  initControl: ->
    super()
    @cell.control.value = @toDateInputString(@cell.value())

  value: ->
    @cell.control.valueAsDate

  toDateString: (passedDate = null) ->
    if passedDate and passedDate isnt ''
      date = new Date(passedDate)
    else
      if @value() then date = new Date(@value()) else null
    if date instanceof Date
      ('0' + (date.getMonth() + 1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2) + '-' + date.getFullYear()
      # date.getFullYear() + '-' + ('0' + (date.getMonth()+1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2)
    else
      ''

  toDate: ->
    input = document.createElement 'input'
    input.type = 'date'
    input.value = @toDateString()
    input

  toDateInputString: (passedDate = null) ->
    if passedDate and passedDate isnt ''
      date = new Date(passedDate)
    else
      if @value() then date = new Date(@value()) else null
    if date instanceof Date
      date.getFullYear() + '-' + ('0' + (date.getMonth() + 1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2)
    else
      ''

# HTML Cell
class HTMLCell extends GenericCell
  constructor: (@cell) ->
    @cell.htmlContent = @cell.col.defaultValue || @cell.originalValue || ''
    node = @toFragment()
    @cell.control = document.createElement 'input'
    @cell.element.appendChild node

  setValue: (newValue) ->
    @cell.htmlContent = newValue
    node = @toFragment()
    @cell.element.innerHTML = ""
    @cell.element.appendChild node

  toFragment: ->
    element = document.createElement "div"
    fragment = document.createDocumentFragment()
    element.innerHTML = @cell.htmlContent
    fragment.appendChild(element.firstChild || document.createTextNode(''))
    fragment

  render: ->
    @htmlContent

# Select Cell
class SelectCell extends GenericCell
  constructor: (@cell) ->
    node = document.createTextNode @cell.originalValue || ''
    @initControl()
    @cell.element.appendChild node

  initControl: ->
    cell = @cell
    select = document.createElement "select"
    console.log "There is not a 'choices' key in cell #{@cell.address} and you specified that it was of type 'select'" if not @cell.meta.choices
    for choice in @cell.meta.choices
      option = document.createElement "option"
      if choice instanceof Array
        for subchoice, index in choice
          option.value = subchoice if index is 0
          option.text = subchoice if index is 1
      else
        option.value = option.text = choice
      option.selected = true if cell.value() is choice
      select.add option
    select.classList.add 'form-control'
    select.onchange = (e) ->
      cell.edit e.target.value
    @cell.control = select

  select: ->
    # stub

# TextArea Cell
class TextAreaCell extends GenericCell
  constructor: (@cell) ->
    node = document.createTextNode @cell.originalValue || ''
    @cell.control = document.createElement 'textarea'
    @cell.control.classList.add 'form-control'


  ###

	Grid Change
	-----------------------------------------------------------------------------------------

  ###


class GridChange

  constructor: (@cells, value) ->
    useBlank = value == 'ge-blank'
    @changes = []
    @table = @cells[0].col.table
    @borderStyle = @table.config.selectionBorderStyle || "2px dashed blue"


    @highRow = 0
    @highCol = 0

    for cell in cells
      rowIndex = cell.address[0]
      colIndex = cell.address[1]

      thisChange = {
        row: rowIndex,
        col: colIndex,
        value: if useBlank then '' else value or cell.value()
      }

      if @firstCell
        if thisChange.row < @firstCell.row
          @firstCell = thisChange
        else if thisChange.row == @firstCell.row
          if thisChange.col < @firstCell.col
            @firstCell = thisChange
      else
        @firstCell = thisChange
        @lowRow = thisChange.row
        @lowCol = thisChange.col

      @highRow = thisChange.row if thisChange.row > @highRow
      @highCol = thisChange.col if thisChange.col > @highCol
      @lowRow = thisChange.row if thisChange.row < @lowRow
      @lowCol = thisChange.col if thisChange.col < @lowCol
      @changes.push(thisChange)

    # get relative coordinates for each change
    for change in @changes
      change.rowVector = change.row - @firstCell.row
      change.colVector = change.col - @firstCell.col

    # determine whether this was a scattered change <ctrl>+click
    width = @highCol - @lowCol + 1
    height = @highRow - @lowRow + 1
    area = width * height
    @scattered = @cells.length != area

  apply: (x, y) ->
    if x == false or y == false
      x = @firstCell.row
      y = @firstCell.col

    for change in @changes
      cell = @table.getCell(x + change.rowVector, y + change.colVector)
      if cell and cell.editable
        change.oldValue = cell.value()
        cell.value(change.value, false)
      else
        change.oldValue = ''

  undo: (x, y) ->
    if x == false or y == false
      x = @firstCell.row
      y = @firstCell.col

    for change in @changes
      cell = @table.getCell(x + change.rowVector, y + change.colVector)
      cell.value(change.oldValue, false) if cell and cell.editable

  displayBorders: ->
    for cell in @cells
      @addBorder cell

  removeBorders: ->
    for cell in @cells
      cell.element.style.border = ""

  addBorder: (cell) ->

    rowIndex = cell.address[0]
    colIndex = cell.address[1]

    if @scattered
      cell.element.style.border = @borderStyle
    else
      if @firstCell.row == @highRow
        cell.element.style.borderTop = @borderStyle
        cell.element.style.borderBottom = @borderStyle
      else
        if rowIndex == @lowRow
          # top
          cell.element.style.borderTop = @borderStyle
        else if rowIndex == @highRow
          # bottom
          cell.element.style.borderBottom = @borderStyle

      if @firstCell.col == @highCol
        cell.element.style.borderRight = @borderStyle
        cell.element.style.borderLeft = @borderStyle
      else
        if colIndex == @lowCol
          # left
          cell.element.style.borderLeft = @borderStyle
        else if colIndex == @highCol
          # right
          cell.element.style.borderRight = @borderStyle


###

	ActionStack
	-----------------------------------------------------------------------------------------
  used for undo/redo functionality

  todo - splice actions array at X elements to conserve memory

###


class ActionStack
  constructor: (@table) ->
    @index = -1;
    @actions = [];

  getCell: (action) ->
    @table.getCell(action.address[0], action.address[1])

  addAction: (actionObject) ->
    if @actions.length > 0 and @index < @actions.length - 1
      @actions = @actions.splice(0, @index + 1)
    @actions.push(actionObject)
    @index++;

  undo: ->
    if @index > -1
      @index--
      action = @actions[@index + 1]
      switch action.type
        when 'cell-edit'
          cell = @getCell(action)
          cell.value(action.oldValue, false)

        when 'cut'
          action.grid.undo(false, false)

        when 'paste'
          action.grid.undo(action.x, action.y)

        when 'fill'
          action.grid.undo(false, false)

        when 'add-row'
          @table.removeRow(action.index, false)

        when 'remove-row'
          @table.addRow(action.index, false)

  redo: ->
    if(@index < @actions.length - 1)
      @index++
      action = @actions[@index]

      switch action.type
        when 'cell-edit'
          cell = @table.getCell(action.address[0], action.address[1])
          cell.value(action.newValue, false)

        when 'cut'
          action.grid.apply(false, false)

        when 'paste'
          action.grid.apply(action.x, action.y)

        when 'fill'
          action.grid.apply(false, false)

        when 'add-row'
          @table.addRow(action.index, false)

        when 'remove-row'
          @table.removeRow(action.index, false)


###

Row Type Behavior
-----------------------------------------------------------------------------------------
generic behavior will be in GenericRow class
type specific behavior will be in the associated <type>Row class

###

# Handle Cell
class HandleCell
  constructor: (@row) ->
    @element = document.createElement 'td'
    @element.className = 'handle'
    node = document.createElement 'div'
    node.innerHTML = '<span></span><span></span><span></span>'
    @element.appendChild(node)
    @

class GenericRow
  constructor: (@row) ->
    @row.editable = true
    includeRowHandles = @row.table.config.includeRowHandles

    if includeRowHandles
      console.log('add handle');
      cell = new HandleCell @row
      @row.element.appendChild cell.element

    for col, i in @row.table.cols
      continue if includeRowHandles and i == 0
      cell = new Cell @row.attributes[col.valueKey], @row
      @row.cells.push cell
      @row.table.cols[i].cells.push cell
      @row.element.appendChild cell.element

  afterEdit: () ->
    @row.table.calculateSubtotals()


class StaticRow
  constructor: (@row) ->
    @row.editable = @row.attributes.editable != false
    @row.element.innerHTML = @row.attributes.html


class SubTotalRow
  constructor: (@row) ->
    @cols = {}
    @labels = @row.attributes.labels

    for col, i in @row.table.cols
      cell = new Cell '', @row
      cell.editable = false
      if @labels
        value = @labels[col.valueKey]
        cell.value(value, false) if value
      @row.cells.push cell
      @row.table.cols[i].cells.push cell
      @row.element.appendChild cell.element

      if(@row.attributes.subtotal[col.valueKey])
        @cols[col.valueKey] = i

    @row.table.subtotalRows.push(@)
    @calculate()

  calculate: () ->
    start = -1
    for sub in @row.table.subtotalRows
      rowIndex = sub.row.index
      if rowIndex < @row.index and rowIndex > start
        start = rowIndex

    for col, index of @cols
      total = 0
      for row in @row.table.rows when row.index > start
        break if row.index == @row.index
        cell = row.cells[index]
        total += Number(cell.value()) if cell
      @row.cells[index].value(total, false)

  afterEdit: () ->
    # do not calculate

root = exports ? window
root.GridEdit = GridEdit
