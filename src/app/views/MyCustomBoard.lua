
local Levels = import("..data.MyLevels")
local Cell   = import("..views.MyCell")

local MyBoard = class("MyBoard", function()
    return display.newNode()
end)

local NODE_PADDING   = 100 * GAME_CELL_STAND_SCALE
local NODE_ZORDER    = 0

local COIN_ZORDER    = 1000

function MyBoard:ctor(levelData)
    math.randomseed(tostring(os.time()):reverse():sub(1, 6))

    cc.GameObject.extend(self):addComponent("components.behavior.EventProtocol"):exportMethods()

    self.batch = display.newNode()
    self.batch:setPosition(display.cx, display.cy)
    self:addChild(self.batch)

    self.grid = {}

    --多加上一个屏幕的缓冲格子
    for i=1,levelData.rows * 2 do
        self.grid[i] = {}
        if levelData.grid[i] == nil then
            levelData.grid[i] = {}
        end
        for j=1,levelData.cols do
            self.grid[i][j] = levelData.grid[i][j]
        end
    end

    -- self.grid = clone(levelData.grid)
    self.rows = levelData.rows
    self.cols = levelData.cols
    self.cells = {}
    self.flipAnimationCount = 0

    if self.rows <= 8 then
        GAME_CELL_EIGHT_ADD_SCALE = 1.0
        self.offsetX = -math.floor(NODE_PADDING * self.cols / 2) - NODE_PADDING / 2
        self.offsetY = -math.floor(NODE_PADDING * self.rows / 2) - NODE_PADDING / 2
        NODE_PADDING   = 100 * GAME_CELL_STAND_SCALE
        -- create board, place all cells
        for row = 1, self.rows do
            local y = row * NODE_PADDING + self.offsetY
            for col = 1, self.cols do
                local x = col * NODE_PADDING + self.offsetX
                local nodeSprite = display.newSprite("#BoardNode.png", x, y)
                nodeSprite:setScale(GAME_CELL_STAND_SCALE)
                self.batch:addChild(nodeSprite, NODE_ZORDER)

                local node = self.grid[row][col]
                if node ~= Levels.NODE_IS_EMPTY then
                    -- local cell = Cell.new(node)
                    local cell = Cell.new()
                    cell.isNeedClean = false
                    cell:setPosition(x, y)
                    cell:setScale(GAME_CELL_STAND_SCALE  * 1.65)
                    cell.row = row
                    cell.col = col
                    self.grid[row][col] = cell
                    self.cells[#self.cells + 1] = cell
                    self.batch:addChild(cell, COIN_ZORDER)
                end
            end
        end
    else
        self.offsetX = -math.floor(NODE_PADDING * 8 / 2) - NODE_PADDING / 2
        self.offsetY = -math.floor(NODE_PADDING * 8 / 2) - NODE_PADDING / 2
        GAME_CELL_EIGHT_ADD_SCALE = 8.0 / self.rows

        NODE_PADDING = 100 * GAME_CELL_STAND_SCALE * GAME_CELL_EIGHT_ADD_SCALE
        -- create board, place all cells
        for row = 1, self.rows do
            local y = row * NODE_PADDING + self.offsetY
            for col = 1, self.cols do
                local x = col * NODE_PADDING + self.offsetX
                local nodeSprite = display.newSprite("#BoardNode.png", x, y)
                nodeSprite:setScale(GAME_CELL_STAND_SCALE * GAME_CELL_EIGHT_ADD_SCALE)
                self.batch:addChild(nodeSprite, NODE_ZORDER)

                local node = self.grid[row][col]
                if node ~= Levels.NODE_IS_EMPTY then
                    -- local cell = Cell.new(node)
                    local cell = Cell.new()
                    cell.isNeedClean = false
                    cell:setPosition(x, y)
                    cell:setScale(GAME_CELL_STAND_SCALE * GAME_CELL_EIGHT_ADD_SCALE * 1.65)
                    cell.row = row
                    cell.col = col
                    self.grid[row][col] = cell
                    self.cells[#self.cells + 1] = cell
                    self.batch:addChild(cell, COIN_ZORDER)
                end
            end
        end
        
    end

    self:setNodeEventEnabled(true)
    self:setTouchEnabled(true)
    self:addNodeEventListener(cc.NODE_TOUCH_EVENT, function(event)
        return self:onTouch(event.name, event.x, event.y)
    end)
    self:checkAll()
    self:changeSingedCell()
end

function MyBoard:checkLevelCompleted()
    local count = 0
    for _, cell in ipairs(self.cells) do
        if cell.isWhite then count = count + 1 end
    end
    if count == #self.cells then
        -- completed
        self:setTouchEnabled(false)
        self:dispatchEvent({name = "LEVEL_COMPLETED"})
    end
end

function MyBoard:getCell(row, col)
    if self.grid[row] then
        return self.grid[row][col]
    end
end

function MyBoard:onTouch(event, x, y)
    return true
end

function MyBoard:checkAll()
    for _, cell in ipairs(self.cells) do
        self:checkCell(cell)
    end
    print("length of self.cells" , #self.cells)
end

function MyBoard:checkCell(cell)
    local listH = {}
    listH [#listH + 1] = cell
    local i=cell.col
    --格子中左边对象是否相同的遍历
    while i > 1 do
        i = i -1
        local cell_left = self:getCell(cell.row,i)
        if cell.nodeType == cell_left.nodeType then
            listH [#listH + 1] = cell_left
        else
            break
        end
    end
    --格子中右边对象是否相同的遍历
    if cell.col ~= self.cols then
        for j=cell.col+1 , self.cols do
            local cell_right = self:getCell(cell.row,j)
            if cell.nodeType == cell_right.nodeType then
                listH [#listH + 1] = cell_right
            else
                break
            end
        end
    end
    --目前的当前格子的左右待消除对象(连同自己)

    --print(#listH)

    if #listH < 3 then
    else
        -- print("find a 3 coup H cell")
        for i,v in pairs(listH) do
            v.isNeedClean = true
        end

    end
    for i=2,#listH do
        listH[i] = nil
    end

    --判断格子的上边的待消除对象

    if cell.row ~= self.rows then
        for j=cell.row+1 , self.rows do
            local cell_up = self:getCell(j,cell.col)
            if cell.nodeType == cell_up.nodeType then
                listH [#listH + 1] = cell_up
            else
                break
            end
        end
    end

    local i=cell.row

    --格子中下面对象是否相同的遍历
    while i > 1 do
        i = i -1
        local cell_down = self:getCell(i,cell.col)
        if cell.nodeType == cell_down.nodeType then
            listH [#listH + 1] = cell_down
        else
            break
        end
    end

    if #listH < 3 then
        for i=2,#listH do
            listH[i] = nil
        end
    else
        for i,v in pairs(listH) do
            v.isNeedClean = true
        end
    end

    
end
--通过缺省的机制来实现同一个函数的多种不同用法
function MyBoard:changeSingedCell(onAnimationComplete)
    local sum = 0
    local DropList = {}

    for i,v in pairs(self.cells) do
        if v.isNeedClean then
            sum = sum +1
            local drop_pad = 0
            local row = v.row
            local col = v.col
            local x = col * NODE_PADDING + self.offsetX
            local y = (self.rows + 1)* NODE_PADDING + self.offsetY
            for i,v in pairs(DropList) do
                if col == v.col then
                    drop_pad = drop_pad + 1
                    y = y + NODE_PADDING
                    table.remove(DropList,i) 
                end
            end

            local cell = Cell.new()
            DropList [#DropList + 1] = cell
            cell.isNeedClean = false
            cell:setPosition(x, y)
            cell:setScale(GAME_CELL_STAND_SCALE * GAME_CELL_EIGHT_ADD_SCALE * 1.65)
            cell.row = self.rows + drop_pad
            cell.col = col

            self.grid[self.rows + drop_pad][col] = cell

            if onAnimationComplete == nil then
                self.batch:removeChild(v, true)
                self.grid[row][col] = nil
            else
            end
            

            self.cells[i] = cell
            self.batch:addChild(cell, COIN_ZORDER)
        end
    end
    local temp = nil

    for i,v in pairs(DropList) do
        print(v.row,v.col)
    end
end

function MyBoard:onEnter()
    self:setTouchEnabled(true)
end

function MyBoard:onExit()
    GAME_CELL_EIGHT_ADD_SCALE = 1.0
    NODE_PADDING = 100 * GAME_CELL_STAND_SCALE
    self:removeAllEventListeners()
end

return MyBoard