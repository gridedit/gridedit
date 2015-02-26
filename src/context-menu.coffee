class GridEdit.ContextMenu
  constructor: (@table) ->
    @active = @table.config.includeContextMenu != false
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
      },
      removeRow: {
        name: 'Remove Row',
        shortCut: '',
        callback: @removeRow
      }
    }
    # create the contextMenu div
    @element = document.createElement 'div'
    @element.style.position = 'fixed'
    @element.style.zIndex = '1040'
    # create the ul to hold context menu items
    @menu = document.createElement 'ul'
    GridEdit.Utilities::setAttributes @menu, {class: 'dropdown-menu', role: 'menu', 'aria-labelledby', style: 'display:block;position:static;margin-bottom:5px;'}

    if @active
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
    GridEdit.Hook::initContextMenuHooks(@)
    @

  # add a divider to the context menu
  addDivider: ->
    divider = document.createElement 'li'
    GridEdit.Utilities::setAttributes divider, {class: 'divider'}
    @menu.appendChild divider

  # add an action to the context menu
  addAction: (action) ->
    li = document.createElement 'li'
    li.setAttribute('name', action.name)
    div = document.createElement 'div'
    span = document.createElement 'span'
    span.textContent = action.shortCut

    GridEdit.Utilities::setAttributes span, {style: "float: right !important;"}
    a = document.createElement 'a'
    a.textContent = action.name
    a.setAttribute('name', action.name)
    GridEdit.Utilities::setAttributes a, {class: 'enabled', tabIndex: '-1'}
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
    if @active
      cell.makeActive() if not cell.isActive()
      @cells = cell.table.activeCells
      GridEdit.Utilities::setStyles @element, {left: x, top: y}
      document.body.appendChild @element
      menu = @element
      setTimeout ->
        # reposition the context menu so it is fully visible on screen

        menuBounds = menu.getBoundingClientRect()
        screenDimensions = GridEdit.Utilities::getScreenDimensions()

        # check menu fits on the screen vertically
        fitsVertically = screenDimensions.height > menuBounds.height

        # check menu will be cut off screen vertically
        cutsBottom = menuBounds.bottom > screenDimensions.height
        cutsTop = menuBounds.top < 0

        # check menu fits on the screen horizontally
        fitsHorizontally = screenDimensions.width > menuBounds.width

        # check menu will be cut off screen horizontally
        cutsRight = menuBounds.right > screenDimensions.width
        cutsLeft = menuBounds.left < 0

        if fitsVertically
          menu.style.overflowY = 'hidden'
          menu.style.height = 'auto'
          # reposition the menu within the screen if needed
          if cutsBottom
            top = menuBounds.top - ( menuBounds.bottom - screenDimensions.height )
            menu.style.top = top + 'px'
          if cutsTop
            bottom = menuBounds.bottom + ( Math.abs(menuBounds.top) )
            menu.style.bottom = bottom + 'px'
        else
          # make the menu scrollable vertically
          menu.style.top = 0;
          menu.style.height = screenDimensions.height + 'px';
          menu.style.overflowY = 'scroll'

        if fitsHorizontally
          menu.style.overflowX = 'hidden'
          menu.style.width = 'auto'
          # reposition the menu within the screen if needed
          if cutsRight
            left = menuBounds.left - ( menuBounds.right - screenDimensions.width )
            menu.style.left = left + 'px'
          if cutsLeft
            right = menuBounds.right + ( Math.abs(menuBounds.left) )
            menu.style.right = right + 'px'
        else
          # make the menu scrollable horizontally
          menu.style.left = 0;
          menu.style.width = screenDimensions.width + 'px';
          menu.style.overflowX = 'scroll'
      , 100
      false

  hide: -> document.body.removeChild @element if @isVisible()

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
    gridChange = new GridEdit.GridChange(table.activeCells, 'ge-blank')
    gridChange.apply(false, false)
    table.copiedGridChange = gridChange
    table.addToStack({ type: 'cut', grid: gridChange })
    menu.displayBorders()
    menu.hide()

  copy: (e, table) ->
    menu = table.contextMenu
    table.copiedGridChange = new GridEdit.GridChange(table.activeCells)
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
    gridChange = new GridEdit.GridChange(table.activeCells, fillValue)
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

  removeRow: (e, table) ->
    cell = table.contextMenu.getTargetPasteCell()
    table.removeRow(cell.row.index)

  undo: (e, table) ->
    table.undo()

  redo: (e, table) ->
    table.redo()

  toggle: (action) ->
    classes = @actionNodes[action].classList
    classes.toggle 'enabled'
    classes.toggle 'disabled'

  execute: (actionCallback, event) ->
    if GridEdit.Hook::run @, 'beforeContextMenuAction', event, @table
      actionCallback event, @table
      GridEdit.Hook::run @, 'afterContextMenuAction', event, @table

  events: (menu) ->
    @element.onclick = (e) ->
      actionName = e.target.getAttribute('name')
      menu.execute menu.actionCallbacks.byName[actionName], e
