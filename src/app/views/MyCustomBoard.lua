
local Levels = import("..data.MyLevels")
local Cell   = import("..views.MyCell")

local MyBoard = class("MyBoard", function()
    return display.newNode()
end)

local NODE_PADDING   = 100 * GAME_CELL_STAND_SCALE
local NODE_ZORDER    = 0
local CELL_SCALE = 1.0
local MOVE_TIME = 0.6

local curSwapBeginRow = -1
local curSwapBeginCol = -1
local isEnableTouch = true
local isInTouch = true

local SWAP_TIME = 0.6
local CELL_ZORDER    = 1000

local scheduler = cc.Director:getInstance():getScheduler()

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

    --超过8格和8格以下的情况
    --使用八格作为最适宜适配模式
    if self.cols <= 8 then
        GAME_CELL_EIGHT_ADD_SCALE = 1.0
        self.offsetX = -math.floor(NODE_PADDING * self.cols / 2) - NODE_PADDING / 2
        self.offsetY = -math.floor(NODE_PADDING * self.rows / 2) - NODE_PADDING / 2
        NODE_PADDING   = 100 * GAME_CELL_STAND_SCALE
        CELL_SCALE = GAME_CELL_STAND_SCALE  * 1.65
    else
        self.offsetX = -math.floor(NODE_PADDING * 8 / 2) - NODE_PADDING / 2
        self.offsetY = -math.floor(NODE_PADDING * 8 / 2) - NODE_PADDING / 2
        GAME_CELL_EIGHT_ADD_SCALE = 8.0 / self.cols
        CELL_SCALE = GAME_CELL_STAND_SCALE * GAME_CELL_EIGHT_ADD_SCALE * 1.65
        NODE_PADDING = 100 * GAME_CELL_STAND_SCALE * GAME_CELL_EIGHT_ADD_SCALE
    end
    for row = 1, self.rows do
        local y = row * NODE_PADDING + self.offsetY
        for col = 1, self.cols do
            local x = col * NODE_PADDING + self.offsetX
            local nodeSprite = display.newSprite("#BoardNode.png", x, y)
            nodeSprite:setOpacity(100)
            nodeSprite:setScale(CELL_SCALE/1.65)
            self.batch:addChild(nodeSprite, NODE_ZORDER)
            local node = self.grid[row][col]
            if node ~= Levels.NODE_IS_EMPTY then
                local cell = Cell.new()
                cell.isNeedClean = false
                cell.row = row
                cell.col = col
                self.grid[row][col] = cell
                self.cells[#self.cells + 1] = cell
                self.batch:addChild(cell, CELL_ZORDER)
            end
        end
    end
    self:lined()

    self:setNodeEventEnabled(true)
    self:setTouchEnabled(true)
    self:addNodeEventListener(cc.NODE_TOUCH_EVENT, function(event)
        return self:onTouch(event.name, event.x, event.y)
    end)
    while self:checkAll() do
        self:changeSingedCell()
    end
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

    if not isEnableTouch then
        return false
    end
    if event == "began" then
        local row,col = self:getRandC(x, y)
        curSwapBeginRow = row
        curSwapBeginCol = col
        if curSwapBeginRow == -1 or curSwapBeginCol == -1 then
            return false 
        end
        isInTouch = true
        self.grid[curSwapBeginRow][curSwapBeginCol]:setLocalZOrder(CELL_ZORDER+1)
        return true
    end
    if isInTouch and (event == "moved" or event == "ended"  )then
        local padding = NODE_PADDING / 2
        local cell_center = self.grid[curSwapBeginRow][curSwapBeginCol]
        local cx, cy = cell_center:getPosition()
        cx = cx + display.cx
        cy = cy + display.cy
        --锚点归位
        local AnchBack = function()
            isInTouch = false
            local p_a = cell_center:getAnchorPoint()
            local x_a = (0.5 - p_a.x ) *  NODE_PADDING + curSwapBeginCol * NODE_PADDING + self.offsetX
            local y_a = (0.5 - p_a.y) *  NODE_PADDING + curSwapBeginRow * NODE_PADDING + self.offsetY
            cell_center:setAnchorPoint(cc.p(0.5,0.5))
            cell_center:setPosition(cc.p(x_a  , y_a ))
        end
        --动画回到格子定义点
        local AnimBack = function()
            isEnableTouch = false
                cell_center:runAction(
                    transition.sequence({
                    cc.MoveTo:create(SWAP_TIME/2,cc.p(curSwapBeginCol * NODE_PADDING + self.offsetX,curSwapBeginRow * NODE_PADDING + self.offsetY)),
                    cc.CallFunc:create(function()
                          isEnableTouch = true
                    end)
                }))
            cell_center:runAction(cc.ScaleTo:create(SWAP_TIME/2,CELL_SCALE))
            self.grid[curSwapBeginRow][curSwapBeginCol]:setLocalZOrder(CELL_ZORDER)
        end
        if event == "ended" then
            AnchBack()
            AnimBack()
            return
        end

        if x < cx - 2*padding
            or x > cx + 2*padding
            or y < cy - 2*padding
            or y > cy + 2*padding then
            isInTouch = false
            AnchBack()
            local row,col = self:getRandC(x, y)
            --进入十字框以内
            if ((x >= cx - padding
            and x <= cx + padding)
            or (y >= cy - padding
            and y <= cy + padding) )and (row ~= -1 and col ~= -1)  then
                --防止移动超过一格的情况
                if row - curSwapBeginRow > 1 then row = curSwapBeginRow + 1 end
                if curSwapBeginRow - row > 1 then row = curSwapBeginRow - 1 end
                if col -  curSwapBeginCol > 1 then col = curSwapBeginCol + 1 end
                if curSwapBeginCol - col  > 1 then col = curSwapBeginCol - 1 end
                    self:swap(row,col,curSwapBeginRow,curSwapBeginCol,function()
                        self:checkCell(self.grid[row][col])
                        self:checkCell(self.grid[curSwapBeginRow][curSwapBeginCol])
                        if self:checkNotClean() then
                            self:changeSingedCell(function() end)
                        else
                            self:swap(row,col,curSwapBeginRow,curSwapBeginCol,function()
                                isEnableTouch = true
                            end,0.6)
                        end
                    end
                )
            else
                AnimBack()
                return
            end
        else
            x_vec = (cx - x)/ NODE_PADDING * 0.3 + 0.5
            y_vec = (cy - y)/ NODE_PADDING * 0.3 + 0.5
            cell_center:setAnchorPoint(cc.p(x_vec,y_vec))
        end
    end
    return true
end

function MyBoard:checkAll()
    for _, cell in ipairs(self.cells) do
        self:checkCell(cell)
    end
    return self:checkNotClean()
end

function MyBoard:checkNotClean()
    for _, cell in ipairs(self.cells) do
        if cell.isNeedClean then
            return true
        end
    end
    return false
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
    local DropHight = {}

    for i,v in pairs(self.cells) do
        if v.isNeedClean then
            sum = sum +1
            local drop_pad = 1
            local row = v.row
            local col = v.col
            local x = col * NODE_PADDING + self.offsetX
            local y = (self.rows + 1)* NODE_PADDING + self.offsetY
            for i,v in pairs(DropList) do
                if col == v.col then
                    drop_pad = drop_pad + 1
                    y = y + NODE_PADDING
                    -- table.remove(DropList,i) 
                end
            end
            local cell = nil
            if onAnimationComplete == nil then
                cell = Cell.new()
            else
                cell = Cell.new()
            end
            
            DropList [#DropList + 1] = cell
            DropHight [#DropHight + 1] = cell
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
                self.batch:removeChild(self.grid[row][col], true)
                self.grid[row][col] = nil
            end

            self.cells[i] = cell
            self.batch:addChild(cell, CELL_ZORDER)
        end
    end

    for i,v in pairs(DropList) do
        for j,v_ in pairs(DropHight) do
            if v.col == v_.col then
                if v_.row < v.row then
                    table.remove(DropHight,j)
                end
            end
        end
    end

    --重新排列grid
    for i , v in pairs(DropHight) do
        if v then
            local c = v.row 
            local j = 1
            while j <=  self.rows  do
                if self.grid[j][v.col] == nil then
                    local k = j
                    while k <  c + 1 do
                        self:swap(k,v.col,k+1,v.col)
                        k = k + 1
                    end
                    j = j - 1
                end
                j = j + 1
            end
        end
    end
    --填补self.grid空缺
    --或执行最后的所有动画步骤
    if onAnimationComplete == nil then
        self:lined()
    else
        for i=1,self.rows do
            for j , v in pairs(DropHight) do
                local y = i * NODE_PADDING + self.offsetY
                local x = v.col * NODE_PADDING + self.offsetX
                local cell_t = self.grid[i][v.col]
                if cell_t then
                    local x_t,y_t = cell_t:getPosition()
                    if(math.abs(y_t - y) > NODE_PADDING/2 ) then
                        cell_t:runAction(transition.sequence({
                            cc.DelayTime:create(0.2),
                            cc.MoveTo:create(0.9, cc.p(x, y))
                        }))
                    end
                end
            end
        end
        self.handle  = scheduler:scheduleScriptFunc (function () 
            scheduler:unscheduleScriptEntry(self.handle )
            if self:checkAll() then
                self:changeSingedCell(function() end)
            end
        end, 1.23 , false)
    end
end

--复位
function MyBoard:lined(  )
    for row = 1, self.rows do
        local y = row * NODE_PADDING + self.offsetY
        for col = 1, self.cols do
            local x = col * NODE_PADDING + self.offsetX
            cell = self.grid[row][col]
            cell:setPosition(x, y)
            cell:setScale(CELL_SCALE)
        end
    end
end

--交换格子内容
function MyBoard:swap( row1 , col1 , row2 , col2 , callBack ,timeScale)
    local swap = function(row1_,col1_,row2_,col2_)
        local temp
        if self:getCell(row1_,col1_) then
            self.grid[row1_][col1_].row = row2
            self.grid[row1_][col1_].col = col2
        end
        if self:getCell(row2_,col2_) then
            self.grid[row2_][col2_].row = row1
            self.grid[row2_][col2_].col = col1
        end
        temp = self.grid[row1_][col1_] 
        if self.grid[row2_] and  self.grid[row2_][col2_] then
            self.grid[row1_][col1_] = self.grid[row2_][col2_]
            self.grid[row2_][col2_] = temp
        end
    end

    if callBack == nil then
        swap(row1,col1,row2,col2)
        return
    end

    if self:getCell(row1,col1) == nil or self:getCell(row2,col2) == nil then
        print("have one nil value with the swap function!!!!")
        return
    end

    local X1,Y1 = col1 * NODE_PADDING + self.offsetX , row1  * NODE_PADDING + self.offsetY
    local X2,Y2 = col2 * NODE_PADDING + self.offsetX , row2  * NODE_PADDING + self.offsetY
    local moveTime = MOVE_TIME
    if timeScale then
        moveTime = moveTime * timeScale
    end

    --改动锚点的渲染前后顺序，移动时前置
    self.grid[row2][col2]:setLocalZOrder(CELL_ZORDER + 1)
    self.grid[row1][col1]:runAction(transition.sequence({
            cc.MoveTo:create(moveTime, cc.p(X2,Y2)),
            cc.CallFunc:create(function()
                --改动锚点的渲染前后顺序，移动完成后回归原本zorder
                self.grid[row2][col2]:setLocalZOrder(CELL_ZORDER)
                self:swap(row1,col1,row2,col2)
                callBack()
            end)
        }))
    self.grid[row2][col2]:runAction(cc.MoveTo:create(moveTime, cc.p(X1,Y1)))
end

function MyBoard:getRandC(x,y)
    local padding = NODE_PADDING / 2
    for _, cell in ipairs(self.cells) do
        local cx, cy = cell:getPosition()
        cx = cx + display.cx
        cy = cy + display.cy
        if x >= cx - padding
            and x <= cx + padding
            and y >= cy - padding
            and y <= cy + padding then
            return cell.row , cell.col
        end
    end
    return -1 , -1
end

function MyBoard:onEnter()
    self:setTouchEnabled(true)
end

function MyBoard:onExit()
    self:removeAllEventListeners()
    GAME_CELL_EIGHT_ADD_SCALE = 1.0
    NODE_PADDING = 100 * GAME_CELL_STAND_SCALE
end

return MyBoard