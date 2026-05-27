local stack = {}
local code = {}
local ip = 1

local function newVM()
    return {
        stack = {},
        code = {},
        vars = {},
        callstack = {},
        frames = {{vars = {}}},
        ip = 1,
        globals = {}
    }
end

local function resolve(arg, labels)
    if labels[arg] then
        return labels[arg]
    end
    return tonumber(arg)
end

local function push(stack, v)
    stack[#stack + 1] = v
end

local function pop(stack, ip)
    if #stack == 0 then
        error("VM error <" .. ip .. ">: stack underflow", 3)
    end

    local v = stack[#stack]
    stack[#stack] = nil

    return v
end

local OP = {
    -- stack
    PUSH_INT = 1,
    POP = 2,
    DUP = 3,

    -- arithmetic
    ADD = 4,
    SUB = 5,
    MUL = 6,
    DIV = 7,
    NEG = 8,

    -- jumps
    JMP = 9,
    --JMP_IF_FALSE = 10, -- this was for debugging but i'm lazy to change all values to be in order rn
    JZ = 11,
    JNZ = 12,

    -- comparisons:
    EQ = 13,
    NEQ = 14,
    LT = 15,
    GT = 16,
    LTE = 17,
    GTE = 18,

    -- I/O
    PRINT = 19,

    -- variables
    STORE = 20,
    LOAD = 21,

    -- functions
    CALL = 22,
    RET = 23,
    LOAD_ARG = 25,

    -- misc
    HALT = 24,
    
}

local handlers = {}

handlers[OP.PUSH_INT] = function(vm, arg)
    if not tonumber(arg) then
        error("VM error <" .. vm.ip .. ">: tried to insert a non-integer value using PUSH_INT", 3)
    end

    push(vm.stack, tonumber(arg))
end

handlers[OP.POP] = function(vm, arg)
    if #vm.stack == 0 then
        error("VM error <" .. vm.ip .. ">: stack underflow", 3)
    end

    table.remove(vm.stack)
end

handlers[OP.DUP] = function(vm, arg)
    if #vm.stack == 0 then
        error("VM error <" .. vm.ip .. ">: stack underflow", 3)
    end

    table.insert(vm.stack, vm.stack[#vm.stack])
end

handlers[OP.ADD] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for arithmetic operation", 3)
    end

    local v1, v2 = vm.stack[#vm.stack - 1], vm.stack[#vm.stack]
    local result = v1 + v2

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    push(vm.stack, result)
end

handlers[OP.SUB] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for arithmetic operation", 3)
    end

    local v1, v2 = vm.stack[#vm.stack - 1], vm.stack[#vm.stack]
    local result = v1 - v2

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    push(vm.stack, result)
end

handlers[OP.MUL] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for arithmetic operation", 3)
    end

    local v1, v2 = vm.stack[#vm.stack - 1], vm.stack[#vm.stack]
    local result = v1 * v2

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    push(vm.stack, result)
end

handlers[OP.DIV] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for arithmetic operation", 3)
    end

    local v1, v2 = vm.stack[#vm.stack - 1], vm.stack[#vm.stack]

    if v2 == 0 then
        error("VM error <" .. vm.ip .. ">: cannot divide by 0", 3)
    end

    local result = v1 / v2

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    push(vm.stack, result)
end

handlers[OP.NEG] = function(vm)
    if #vm.stack == 0 then
        error("VM error <" .. vm.ip .. ">: stack underflow", 3)
    end

    vm.stack[#vm.stack] = -vm.stack[#vm.stack]
end

handlers[OP.JMP] = function(vm, arg, labels)
    local target = resolve(arg, labels)

    if not target then
        error("VM error <" .. vm.ip .. ">: invalid JMP target")
    end

    vm.ip = target
end

handlers[OP.EQ] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for comparison operation", 3)
    end

    local result = vm.stack[#vm.stack - 1] == vm.stack[#vm.stack]

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    if result then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.LT] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for comparison operation", 3)
    end

    local result = vm.stack[#vm.stack - 1] < vm.stack[#vm.stack]

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    if result then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.GT] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for comparison operation", 3)
    end

    local result = vm.stack[#vm.stack - 1] > vm.stack[#vm.stack]

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    if result then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.NEQ] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for comparison operation", 3)
    end

    local result = vm.stack[#vm.stack - 1] ~= vm.stack[#vm.stack]

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    if result then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.LTE] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for comparison operation", 3)
    end

    local result = vm.stack[#vm.stack - 1] <= vm.stack[#vm.stack]

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    if result then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.GTE] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <" .. vm.ip .. ">: stack underflow for comparison operation", 3)
    end

    local result = vm.stack[#vm.stack - 1] >= vm.stack[#vm.stack]

    pop(vm.stack, vm.ip)
    pop(vm.stack, vm.ip)

    if result then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.PRINT] = function(vm)
    if #vm.stack == 0 then
        error("VM error <"..vm.ip..">: PRINT on empty stack")
    end
    
    print(vm.stack[#vm.stack])
end

handlers[OP.STORE] = function(vm, arg)
    local target = pop(vm.stack, vm.ip)
    local frame = vm.frames[#vm.frames]
    frame.vars[arg] = target
    vm.vars[arg] = target

    vm.vars[arg] = target
end

handlers[OP.LOAD] = function(vm, arg)
    local frame = vm.frames[#vm.frames]
    local scope_Var = frame.vars[arg]
    
    if scope_Var then
        push(vm.stack, scope_Var)
    else
        error("VM error <" .. vm.ip .. ">: undefined variable: " .. arg)
    end
end

handlers[OP.JZ] = function(vm, arg, labels)
    local target = resolve(arg, labels)

    if not target then
        error("VM error <" .. vm.ip .. ">: invalid JMP target")
    end

    local v = pop(vm.stack, vm.ip)
    if v == 0 then vm.ip = target end
end

handlers[OP.JNZ] = function(vm, arg, labels)
    local target = resolve(arg, labels)

    if not target then
        error("VM error <" .. vm.ip .. ">: invalid JMP target")
    end

    local v = pop(vm.stack, vm.ip)
    if v ~= 0 then vm.ip = target end
end

handlers[OP.HALT] = function(vm)
    vm.ip = math.huge
end

handlers[OP.CALL] = function(vm, arg, labels)
    local target = resolve(arg, labels)
    if not target then
        error("VM error <" .. vm.ip .. ">: invalid CALL target")
    end

    local argument
    local argument
    if #vm.stack > 0 then
        argument = pop(vm.stack, vm.ip)
    end

    push(vm.callstack, {return_ip = vm.ip + 1, arg = argument})

    push(vm.frames, {vars = {}, arg = argument})

    vm.ip = target
end

handlers[OP.RET] = function(vm, arg)
    local frame = pop(vm.callstack, vm.ip)
    pop(vm.frames, vm.ip)
    vm.ip = frame.return_ip
end

handlers[OP.LOAD_ARG] = function(vm)
    local frame = pop(vm.callstack, vm.ip)
    push(vm.stack, frame.arg)
end

local function VM(bytecode)
    local vm = newVM()
    local labels = {}
    local instructions = {}

    for line in bytecode:gmatch("([^\n]+)") do
        local trimmed = line:match("^%s*(.-)%s*$")
        
        if trimmed ~= "" and not trimmed:match("^%-%-") then
            local label = trimmed:match("^(%w+):$")
            if label then
                labels[label] = #instructions + 1
            else
                local op, arg = trimmed:match("^(%S+)%s*(.*)$")
                op = OP[op]
                table.insert(instructions, {op, arg})
            end
        end
    end

    vm.code = instructions

    while vm.ip <= #vm.code do
        local line = vm.code[vm.ip]
        local op, arg = line[1], line[2]
        
        local handler = handlers[op]
        if not handler then error("VM error <" .. vm.ip .. ">: Unknown opcode") end
        
        local old_ip = vm.ip
        handler(vm, arg, labels)
        
        if vm.ip == old_ip then
            vm.ip = vm.ip + 1
        end
    end
end

VM([[
-- Fibonacci
PUSH_INT 0
STORE a

PUSH_INT 1
STORE b

PUSH_INT 15
STORE n

loop:

    LOAD a
    PRINT

    -- c = a + b
    LOAD a
    LOAD b
    ADD
    STORE c

    -- a = b
    LOAD b
    STORE a

    -- b = c
    LOAD c
    STORE b

    -- n = n - 1
    LOAD n
    PUSH_INT 1
    SUB
    STORE n

    LOAD n
    JNZ loop

HALT
]])
