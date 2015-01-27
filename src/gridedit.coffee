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
    do @destroy
    @constructor(config, @actionStack)
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
    if @selectionStart isnt @selectionEnd
      do cell.removeFromSelection for cell in @activeCells
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





  addRow: (index) ->
    row = {}
    for c in @cols
      row[c.valueKey] = c.defaultValue || ''

    if index
      @source.splice(index, 0, row)
    else
      @source.push(row)

    @rebuild({ rows: @source, initialize: true })







  insertBelow: ->
    cell = @.contextMenu.getTargetPasteCell()
    @addRow(cell.address[0] + 1)






class Column
  constructor: (@attributes, @table) ->
    @id = @index = @table.cols.length
    @defaultValue = @attributes.defaultValue
    @cellClass = @attributes.cellClass
    @cells = []
    @element = document.createElement 'th'
    @textNode = document.createTextNode @attributes.label
    @element.appendChild @textNode
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
    @editable = true
    Utilities::setAttributes @element,
      id: "row-#{@id}"
    for col, i in @table.cols
      cell = new Cell @attributes[col.valueKey], @
      @cells.push cell
      @table.cols[i].cells.push cell
      @element.appendChild cell.element
    delete @attributes
  below: -> @table.rows[@index + 1]
  above: -> @table.rows[@index - 1]

# Creates a cell object in memory to store in a row
class Cell
  constructor: (@originalValue, @row) ->
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
#    @values = [@originalValue]
#    @previousValue = null
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
#      @previousValue = @element.textContent
      @table.addToStack { type: 'cell-edit', oldValue: oldValue, newValue: newValue, address: @address } if addToStack
#      @values.push newValue
      @element.textContent = newValue
      @cellTypeObject.setValue(newValue)
      Utilities::setStyles @control, @position()
      @afterEdit(@, oldValue, newValue, @table.contextMenu.getTargetPasteCell()) if @afterEdit
      return newValue
    else
      @cellTypeObject.render()
  makeActive: ->
    beforeActivateReturnVal = @beforeActivate @ if @beforeActivate
    if @beforeActivate and beforeActivateReturnVal isnt false or not @beforeActivate
      Utilities::clearActiveCells @table
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
  removeFromSelection: -> @showInactive()
  showActive: ->
    cssText = @element.style.cssText
    @oldCssText = cssText
    @element.style.cssText = cssText + ' ' + "background-color: #{@table.cellStyles.activeColor};"
  showInactive: -> @element.style.cssText = @oldCssText
  showRed: ->
    @element.style.cssText = "background-color: #{@table.cellStyles.uneditableColor};"
    @table.redCells.push @
  showControl: (value = null) ->
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
        @control.remove() if @isControlInDocument()
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
  events: (cell) ->
    table = cell.table
    redCells = table.redCells
    activeCells = table.activeCells
    @element.onclick = (e) ->
      onClickReturnVal = cell.onClick(cell, e) if cell.onClick
      if onClickReturnVal is false
        return false
    @element.ondblclick = ->
      do cell.edit
    @element.onmousedown = (e) ->
      if e.which is 3
        table.contextMenu.show(e.x, e.y, cell)
        return
      table.state = "selecting"
      do cell.makeActive
      false
    @element.onmouseover = (e) ->
      if table.state is 'selecting'
        table.selectionEnd = cell
        do table.setSelection
    @element.onmouseup = (e) ->
      if e.which isnt 3
        table.selectionEnd = cell
        do table.setSelection
        table.state = "ready"
    @control.onkeydown = (e) ->
      key = e.which
      switch key
        when 13
          cell.edit @value
          cell.below()?.makeActive()
        when 9
          cell.edit @value
          moveTo table.nextCell()
    @cellTypeObject.addControlEvents(cell)
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
        action = @userDefinedActions[actionName] || @defaultActions[actionName]
        if action
          @addAction action
    # use the default ordering
    else
      for actionName, action of @defaultActions
        # allow the user to override defaults, or remove them by setting them to false
        continue if @userDefinedActions[actionName] || @userDefinedActions[actionName] == false;
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
    @table.copiedCellMatrix.displayBorders() if @table.copiedCellMatrix

  hideBorders: ->
    @table.copiedCellMatrix.removeBorders() if @table.copiedCellMatrix

  cut: (e, table) ->
    menu = table.contextMenu
    cellMatrix = new CellMatrix(table.activeCells)
    table.copiedCellMatrix = cellMatrix
    table.addToStack({ type: 'cut', oldMatrix: cellMatrix.values, address: [cellMatrix.lowRow, cellMatrix.lowCol ] })
    for cell in table.activeCells
      cell.value('', false)
    menu.displayBorders()
    menu.hide()

  copy: (e, table) ->
    menu = table.contextMenu
    table.copiedCellMatrix = new CellMatrix(table.activeCells)
    menu.displayBorders()
    menu.hide()

  paste: (e, table) ->
    menu = table.contextMenu
    cell = menu.getTargetPasteCell()

    if cell.editable
      matrix = []
      rowIndex = cell.address[0] - 1
      for row in table.copiedCellMatrix.values
        rowIndex++
        colIndex = cell.address[1]
        matrix[rowIndex] = []
        for value in row
          currentCell = table.getCell(rowIndex, colIndex)
          if currentCell and currentCell.editable
            matrix[rowIndex].push currentCell.value()
            currentCell.value(value, false)
          colIndex++

      menu.hideBorders()
      table.addToStack({ type: 'paste', oldMatrix: matrix, matrix: table.copiedCellMatrix.values, address: cell.address })

    menu.hide()

  fill: (e, table) ->
    menu = table.contextMenu
    cell = menu.getTargetPasteCell()
    fillValue = cell.value()

    cellMatrix = new CellMatrix(table.activeCells)
    table.copiedCellMatrix = cellMatrix

    if cell.editable
      matrix = []
      rowIndex = cellMatrix.lowRow - 1
      for row in cellMatrix.values
        rowIndex++
        colIndex = cellMatrix.lowCol
        matrix[rowIndex] = []
        for value in row
          currentCell = table.getCell(rowIndex, colIndex)
          if currentCell and currentCell.editable
            matrix[rowIndex].push currentCell.value()
            currentCell.value(fillValue, false)
          colIndex++

      table.addToStack({ type: 'fill', oldMatrix: matrix, fillValue: fillValue, address: [ cellMatrix.lowRow, cellMatrix.lowCol ] })


    menu.hide()

  selectAll: (e, table) ->
    table.clearActiveCells()
    for row in table.rows
      for cell in row.cells
        cell.addToSelection()

  insertBelow: (e, table) ->
    table.insertBelow()


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
    node = document.createTextNode @cell.originalValue
    @cell.control = document.createElement 'input'
    @cell.element.appendChild node

  initControl: ->
    @cell.control.value = @cell.value()

  formatValue: (newValue) ->
    newValue

  setValue: (newValue) ->
    @cell.source[@cell.valueKey] = newValue

  addControlEvents: (cell) ->
    # stub

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

  addControlEvents: (cell) ->
    @cell.control.onchange = (e) ->
      cell.edit e.target.value

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
    @cell.htmlContent = @cell.col.defaultValue || @cell.originalValue
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
    @cell.control = @initControl
    @cell.element.appendChild node

  initControl: ->
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
      option.selected = true if @cell.value() is choice
      select.add option
    select.classList.add 'form-control'
    @cell.control = select
    @cell.control.onchange = (e) ->
      @cell.edit e.target.value

  addControlEvents: (cell) ->
    @cell.control.onchange = (e) ->
      cell.edit e.target.value

  select: ->
    # stub


  ###

    Cell Matrix
    -----------------------------------------------------------------------------------------

  ###


class CellMatrix
  constructor: (@cells) ->
    rows = []
    matrix = {}
    for cell in @cells
      rowIndex = cell.address[0]
      colIndex = cell.address[1]
      if(matrix[rowIndex])
        matrix[rowIndex][colIndex] = cell.value()
      else
        rows.push rowIndex
        matrix[rowIndex] = {}
        matrix[rowIndex][colIndex] = cell.value()

    # store row metaData
    @matrix = matrix
    @rowCount = rows.length
    rows.sort (a,b) -> Number(a) - Number(b)
    @lowRow = rows[0]
    @highRow = rows[rows.length - 1]

    # store column metaData
    cols = Object.keys(@matrix[@lowRow])
    @colCount = cols.length
    cols =  cols.sort (a,b) -> Number(a) - Number(b)
    @lowCol = cols[0]
    @highCol = cols[@colCount - 1]

    # create a matrix of values
    m = []
    for row in rows
      a = []
      for col in cols
        a.push @matrix[row][col]
      m.push a

    @values = m

  displayBorders: ->
    for cell in @cells
      @addBorder cell

  removeBorders: ->
    for cell in @cells
      cell.element.style.border = ""

  addBorder: (cell) ->
    borderStyle = "2px dashed blue"
    rowIndex = cell.address[0]
    colIndex = cell.address[1]

    if @lowRow == @highRow
      cell.element.style.borderTop = borderStyle
      cell.element.style.borderBottom = borderStyle
    else
      if rowIndex < @highRow
        # top or middle
        cell.element.style.borderTop = borderStyle
        cell.element.style.borderBottom = borderStyle
      else
        # bottom
        cell.element.style.borderBottom = borderStyle

    if @lowCol == @highCol
      cell.element.style.borderLeft = borderStyle
      cell.element.style.borderRight = borderStyle
    else
      if colIndex < @highCol
        # left or middle
        cell.element.style.borderLeft = borderStyle
        cell.element.style.borderRight = borderStyle
      else
        # right
        cell.element.style.borderRight = borderStyle


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
    if @index > - 1 and @index < @actions.length - 1

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
          @updateMatrix(action, 'oldMatrix')

        when 'paste'
          @updateMatrix(action, 'oldMatrix')


        when 'fill'
          @updateMatrix(action, 'oldMatrix')

  redo: ->
    if(@index < @actions.length - 1)
      @index++
      action = @actions[@index]

      switch action.type
        when 'cell-edit'
          cell = @table.getCell(action.address[0], action.address[1])
          cell.value(action.newValue, false)

        when 'cut'
          rowIndex = action.address[0] - 1
          for row in action.oldMatrix
            rowIndex++
            colIndex = action.address[1]
            for value in row
              currentCell = @table.getCell(rowIndex, colIndex)
              currentCell.value('', false)
              colIndex++

        when 'paste'
          @updateMatrix(action, 'oldMatrix')

        when 'fill'
          rowIndex = action.address[0] - 1
          for row in action.oldMatrix
            rowIndex++
            colIndex = action.address[1]
            for value in row
              currentCell = @table.getCell(rowIndex, colIndex)
              currentCell.value(action.fillValue, false)
              colIndex++

  updateMatrix: (action, matrixKey) ->
    rowIndex = action.address[0] - 1
    for row in action[matrixKey]
      rowIndex++
      colIndex = action.address[1]
      for value in row
        currentCell = @table.getCell(rowIndex, colIndex)
        currentCell.value(value, false)
        colIndex++

root = exports ? window
root.GridEdit = GridEdit
