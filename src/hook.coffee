class GridEdit.Hook
  constructor:  ->

  run: (obj, hookName) -> # all additional arguments are passed to user function
    if obj[hookName]
      functionArguments = []
      for arg, i in arguments
        continue if i < 2
        functionArguments.push arg
      obj[hookName].apply(obj, functionArguments) != false
    else
      true

  initTableHooks: (table) ->
    config = table.config

    # moveRow
    table.beforeMoveRow = config.beforeMoveRow
    table.afterMoveRow = config.afterMoveRow

    # addRow
    table.beforeAddRow = config.beforeAddRow
    table.afterAddRow = config.afterAddRow

    # addRows
    table.beforeAddRows = config.beforeAddRows
    table.afterAddRows = config.afterAddRows

    # removeRow
    table.beforeRemoveRow = config.beforeRemoveRow
    table.afterRemoveRow = config.afterRemoveRow

    # removeRows
    table.beforeRemoveRows = config.beforeRemoveRows
    table.afterRemoveRows = config.afterRemoveRows

    # insertBelow
    table.beforeInsertBelow = config.beforeInsertBelow
    table.afterInsertBelow = config.afterInsertBelow

    # insertAbove
    table.beforeInsertAbove = config.beforeInsertAbove
    table.afterInsertAbove = config.afterInsertAbove

  initContextMenuHooks: (contextMenu) ->
    config = contextMenu.table.config

    # contextMenuAction
    contextMenu.beforeContextMenuAction = config.beforeContextMenuAction
    contextMenu.afterContextMenuAction = config.afterContextMenuAction

  initCellHooks: (cell) ->
    config = cell.table.config

    # edit
    cell.beforeEdit = config.beforeEdit
    cell.afterEdit = config.afterEdit

    # activate
    cell.beforeActivate = config.beforeCellActivate
    cell.afterActivate = config.afterCellActivate

    # controlInit
    cell.beforeControlInit = config.beforeControlInit
    cell.afterControlInit = config.afterControlInit

    # controlHide
    cell.beforeControlHide = config.beforeControlHide
    cell.afterControlHide = config.afterControlHide

    # navigateTo
    cell.beforeNavigateTo = config.beforeCellNavigateTo

    # onCellClick
    cell.onClick = config.onCellClick

    # onCellDblClick
    cell.onDblClick = config.onCellDblClick
