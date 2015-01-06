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
        redCell?.removeClass 'uneditable'
      table.redCells = []
    if activeCells.length > 0
      for activeCell, index in activeCells
        activeCell?.removeClass 'active'
        activeCell?.hideControl
      table.activeCells = []
    table.selectionStart = null
    table.selectionEnd = null
    table.contextMenu.hide()
  capitalize: (string) -> string.toLowerCase().replace /\b./g, (a) -> a.toUpperCase()

class GridEdit
  constructor: (@config) ->
    @element = document.querySelectorAll(@config.element || '#gridedit')[0]
    @headers = []
    @rows = []
    @cols = @config.cols
    @source = @config.rows
    @redCells = []
    @activeCells = []
    @copiedCells = []
    @copiedValues = []
    @selectionStart = null
    @selectionEnd = null
    @openCell = null
    @state = "ready"
    @mobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
    @topOffset = if not @config.topOffset then 0 else @config.topOffset
    if @config.custom
      @set key, value for key, value of @config.custom when key of @config.custom
      delete @config.custom
    do @init if @config.initialize
    @contextMenu = new ContextMenu ['cut', 'copy', 'paste', 'undo', 'fill'], @
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
    for col in @config.cols
      th = document.createElement 'th'
      if typeof col is 'object'
        textNode = document.createTextNode col.label
      else if typeof header is 'string'
        textNode = document.createTextNode header
      th.appendChild textNode
      col.th = th
      tr.appendChild th
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
  rebuild: (newConfig=null) ->
    config = Object.create @config
    if newConfig isnt null
      for option of newConfig
        if newConfig[option] then config[option] = newConfig[option]
    do @destroy
    @constructor config
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
          char.toLowerCase() if not shift
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
          when 67
            if cmd or ctrl then do table.copy
          when 86
            if cmd or ctrl then do table.paste
          when 13 then break
          when 16 then break
          when 17 then break
          when 91 then break
          when 67
            if cmd or ctrl
              @contextMenu.cell = table.activeCell()
              @contextMenu.copy()
          when 8
            if not table.openCell
              e.preventDefault()
              table.delete()
          when 46
            if not table.openCell
              e.preventDefault()
              table.delete()
          else
            key = key-48 if key in [96..111] # For numpad
            if not table.openCell then table.activeCell().showControl(valueFromKey key)
    window.onresize = -> Utilities::setStyles table.openCell.control, table.openCell.position() if table.openCell
    window.onscroll = -> table.openCell.reposition() if table.openCell
    @tableEl.oncontextmenu = (e) -> false
    document.onclick = (e) -> Utilities::clearActiveCells table unless table.isDescendant e.target
  render: ->
    @element = document.querySelectorAll(@config.element || '#gridedit')[0] if @element.hasChildNodes()
    @element.appendChild @tableEl
  set: (key, value) -> @config[key] = value if key isnt undefined
  getCell: (x, y) -> @rows[x].cells[y]
  activeCell: -> if @activeCells.length > 1 then @activeCells else @activeCells[0]
  nextCell: -> @activeCell()?.next()
  previousCell: -> @activeCell()?.previous()
  aboveCell: -> @activeCell()?.above()
  belowCell: -> @activeCell()?.below()
  moveTo: (cell) ->
    if cell
      if not cell.isVisible()
        oldY = cell.table.activeCell().address[0]
        newY = cell.address[0]
        directionModifier = 1
        if newY < oldY # Then going up - This is because you need -1 for scrolling up to work properly
          directionModifier = -1
        window.scrollBy(0, cell.position().height * directionModifier)
      do cell.makeActive
    false
  edit: (cell, newValue=null) ->
    if newValue isnt null
      cell?.edit newValue
    else
      do cell?.edit
      false
  delete: ->
    for cell in @activeCells
      cell.value('')
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
        rowData.push if cell.type is 'date' then cell.control.valueAsDate else cell.value()
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
  copy: (selection=@activeCells) -> @copiedCells = selection
  paste: (selection=@activeCells) -> @activeCells = @copiedCells
  cut: ->
  filldown: ->
  isDescendant: (child) ->
    node = child.parentNode
    while node?
      return true if node is @tableEl
      node = node.parentNode
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
    for col in @table.cols
      cell = new Cell @attributes[col.valueKey], @
      @cells.push cell
      @element.appendChild cell.element
    delete @attributes
  below: -> @table.rows[@id + 1]
  above: -> @table.rows[@id - 1]

# Creates a cell object in memory to store in a row
class Cell
  constructor: (@attributes, @row) ->
    @id = "#{@row.id}-#{@row.cells.length}"
    @address = [@row.id, @row.cells.length]
    @index = @row.cells.length
    @table = @row.table
    @col = @table.cols[@index]
    @type = @col.type
    @meta = @col
    if 'editable' of @col
      @editable = @col.editable
    else
      @editable = true
    @element = document.createElement 'td'
    @originalValue = @attributes
    @val = @originalValue
    @values = [@originalValue]
    @previousValue = null
    @valueKey = @col.valueKey
    @source = @table.config.rows[@address[0]]
    @beforeEdit = @table.config.beforeEdit
    @afterEdit = @table.config.afterEdit
    @beforeActivate = @table.config.beforeCellActivate
    @afterActivate = @table.config.afterCellActivate
    @beforeControlInit = @table.config.beforeControlInit
    @afterControlInit = @table.config.afterControlInit
    @onClick = @table.config.onCellClick
    Utilities::setAttributes @element,
      id: "cell-#{@id}"
      class: @attributes?.class or ''
      style: @attributes?.styles or ''
    if @col.style
      for styleName of @col.style
        @element.style[styleName] = @col.style[styleName]
    switch @type
      when 'string'
        node = document.createTextNode @attributes
        @control = document.createElement 'input'
      when 'number'
        node = document.createTextNode @attributes
        @control = document.createElement 'input'
      when 'date'
        node = document.createTextNode @toDateString @attributes
        @control = @toDate()
        @control.valueAsDate = new Date(@originalValue)
      when 'html'
        @htmlContent = @attributes
        node = @toFragment()
        @control = document.createElement 'input'
      when 'select'
        node = document.createTextNode @attributes || ''
        @control = @toSelect()
    @element.appendChild node
    # delete @attributes
    @events @
  setNewHTMLValue: (newValue) ->
    @htmlContent = newValue
    node = @toFragment()
    @element.innerHTML = ""
    @element.appendChild node
  value: (newValue=null) ->
    if newValue isnt null and newValue isnt @element.textContent
      if @type is 'date'
        if newValue.length > 0
          newValue = @toDateString(Date.parse(newValue))
        else if newValue instanceof Date
          newValue = @toDateString newValue
        else if newValue.length is 0
          newValue = ""
          @control.valueAsDate = null
      else if @type is 'number'
        if newValue.length is 0
          newValue = null
        else
          newValue = Number(newValue)
      oldValue = @value()
      @beforeEdit(@, oldValue, newValue) if @beforeEdit
      @previousValue = @element.textContent
      @values.push newValue
      @element.textContent = newValue
      if @type is 'number'
        @source[@valueKey] = Number(newValue)
      else if @type is 'date'
        @source[@valueKey] = new Date(newValue)
        @control.valueAsDate = new Date(newValue)
        # @control.value = new Date(newValue)
      else if  @type is 'html'
        @setNewHTMLValue newValue
      else
        @source[@valueKey] = newValue
      Utilities::setStyles @control, @position()
      @afterEdit(@, oldValue, newValue) if @afterEdit
      return newValue
    else
      unless @type is 'html' then @element.textContent else @htmlContent
  makeActive: ->
    Utilities::clearActiveCells @table
    beforeActivateReturnVal = @beforeActivate @ if @beforeActivate @
    if @beforeActivate and beforeActivateReturnVal isnt false or not @beforeActivate
      @addClass 'active'
      @table.activeCells.push @
      @table.selectionStart = @
      if @table.openCell
        @table.openCell.edit @table.openCell.control.value
      @afterActivate @ if @afterActivate @
  addToSelection: ->
    @addClass 'active'
    @table.activeCells.push @
  isActive: -> @table.activeCells.indexOf(@) isnt -1
  removeFromSelection: -> @removeClass 'active'
  showRed: ->
    @addClass 'uneditable'
    @table.redCells.push @
  showControl: (value=null) ->
    if not @editable
      @showRed()
    else
      beforeControlInitReturnVal = @beforeControlInit @ if @beforeControlInit
      if @beforeControlInit and beforeControlInitReturnVal isnt false or not @beforeControlInit
        if value isnt null
          @control.value = value
          control = @control
          setTimeout( ->
            control.focus()
          , 0)
        else
          if @type is 'select'
            @control = @toSelect()
            cell = @
            @control.onchange = (e) ->
              cell.edit e.target.value
          else
            @control.value = @value()
        @control.value = @toDateInputString(@value()) if @type is 'date'
        @control.style.position = "fixed"
        Utilities::setStyles @control, @position()
        @table.element.appendChild @control
        @table.openCell = @
        @afterControlInit @ if @afterControlInit
  hideControl: ->
    if @table.openCell isnt null
      @table.element.removeChild @control
    @table.openCell = null
  edit: (newValue=null) ->
    if not @editable
      @showRed()
    else
      if newValue isnt null
        @value newValue
        if @isBeingEdited() then do @hideControl else do @edit
      else
        do @showControl
        @control.focus()
        @control.select() if @type isnt 'select'
  position: -> @element.getBoundingClientRect()
  isVisible: ->
    position = @position()
    (position.top >= @table.topOffset) and (position.bottom <= window.innerHeight)
  reposition: ->
    Utilities::setStyles @control, @position()
  next: -> @row.cells[@index + 1] or @row.below()?.cells[0]
  previous: -> @row.cells[@index - 1] or @row.above()?.cells[@row.cells.length - 1]
  above: -> @row.above()?.cells[@index]
  below: -> @row.below()?.cells[@index]
  addClass: (newClass) -> @element.classList.add newClass
  removeClass: (classToRemove) -> @element.classList.remove classToRemove
  toFragment: ->
    element = document.createElement "div"
    fragment = document.createDocumentFragment()
    element.innerHTML = @htmlContent
    fragment.appendChild(element.firstChild || document.createTextNode(''))
    fragment
  toSelect: ->
    select = document.createElement "select"
    console.log "There is not a 'choices' key in cell #{@address} and you specified that it was of type 'select'" if not @meta.choices
    for choice in @meta.choices
      option = document.createElement "option"
      if choice instanceof Array
        for subchoice, index in choice
          option.value = subchoice if index is 0
          option.text = subchoice if index is 1
      else
        option.value = option.text = choice
      option.selected = true if @value() is choice
      select.add option
    select.classList.add 'form-control'
    select
  toDateString: (passedDate=null) ->
    if passedDate and passedDate isnt ''
      date = new Date(passedDate)
    else
      if @value() then date = new Date(@value()) else null
    if date instanceof Date
      ('0' + (date.getMonth()+1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2) + '-' + date.getFullYear()
      # date.getFullYear() + '-' + ('0' + (date.getMonth()+1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2)
    else
      ''
  toDate: ->
    input = document.createElement 'input'
    input.type = 'date'
    input.value = @toDateString()
    input
  toDateInputString: (passedDate=null) ->
    if passedDate and passedDate isnt ''
      date = new Date(passedDate)
    else
      if @value() then date = new Date(@value()) else null
    if date instanceof Date
      date.getFullYear() + '-' + ('0' + (date.getMonth()+1)).slice(-2) + '-' + ('0' + date.getDate()).slice(-2)
    else
      ''
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
        # else cell.value @value
    if @type is 'select' or 'date'
      @control.onchange = (e) ->
        cell.edit e.target.value
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

class ContextMenu
  constructor: (@actions, @table) ->
    @defaultActions = ['cut', 'copy', 'paste', 'undo', 'fill']
    @element = document.createElement 'div'
    @actionNodes = {}
    Utilities::setAttributes @element, {id: 'contextMenu', class: 'dropdown clearfix'}
    ul = document.createElement 'ul'
    Utilities::setAttributes ul, {class: 'dropdown-menu', role: 'menu', 'aria-labelledby', style: 'display:block;position:static;margin-bottom:5px;'}
    for action in @defaultActions
      li = document.createElement 'li'
      divider = document.createElement 'li'
      Utilities::setAttributes divider, {class: 'divider'}
      a = document.createElement 'a'
      a.textContent = Utilities::capitalize action
      if action in @actions
        Utilities::setAttributes a, {class: 'enabled', tabIndex: '-1'}
      else
        Utilities::setAttributes a, {class: 'disabled', tabIndex: '-1'}
      if action is 'fill'
        ul.appendChild divider
      @actionNodes[action] = a
      li.appendChild a
      ul.appendChild li
    @element.appendChild ul
    @events @
  show: (x, y, cell) ->
    cell.makeActive() if not cell.isActive()
    @cells = cell.table.activeCells
    Utilities::setStyles @element, {left: x, top: y}
    @table.tableEl.appendChild @element
  hide: -> @table.tableEl.removeChild @element if @isVisible()
  isVisible: -> @element.parentNode?
  getTargetPasteCell: -> @table.activeCells.sort(@sortFunc)[0]
  sortFunc: (a,b) -> a.address[0] > b.address[0];
  cut: ->
    @table.copiedValues = []
    @table.copiedCells = @table.activeCells
    for cell in @table.activeCells
      @table.copiedValues.push cell.value()
      cell.value('')
    do @afterAction
  copy: ->
    @table.copiedValues = []
    @table.copiedCells = @table.activeCells
    for cell in @table.activeCells
      @table.copiedValues.push cell.value()
    do @afterAction
  paste: ->
    cell = @getTargetPasteCell()
    if @table.copiedValues.length > 1
      for value, index in @table.copiedValues
        cell.value(@table.copiedValues[index])
        cell = cell.below()
    else
      for activeCell, index in @table.activeCells
        activeCell.value(@table.copiedValues[0])
    do @afterAction
  undo: ->
    value = @cell.values.pop()
    @cell.value(value)
    do @afterAction
  fill: ->
    do @afterAction
  afterAction: ->
    do @hide
  toggle: (action) ->
    classes = @actionNodes[action].classList
    classes.toggle 'enabled'
    classes.toggle 'disabled'
  events: (menu) ->
    @element.onclick = (e) ->
      action = e.target.textContent
      switch action
        when 'Cut' then do menu.cut
        when 'Copy' then do menu.copy
        when 'Paste' then do menu.paste
        when 'Undo' then do menu.undo
        when 'Fill' then do menu.fill

root = exports ? window
root.GridEdit = GridEdit
