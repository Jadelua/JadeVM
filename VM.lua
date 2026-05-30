local function newVM()
    return {
        stack = {},
        code = {},
        callstack = {},
        frames = {},
        ext = {},
        labels = {},
        globals = {},
        ip = 1
    }
end

local types = {
    T_INT = 1,
    T_STR = 2,
    T_NULL = 3,
    T_BOOL = 4,
    T_ARRAY = 5,
    T_CHAR = 6,
    T_FLOAT = 7,
    T_VECTOR = 8, -- might not need
    T_STRUCT = 9, -- same here
}

local ARRAY_END = { __type = "_ARRAY_END_" }

-- excpect some helpers here not be used in any code at all, maybe
local function resolve(arg, labels)
    if labels[arg] then
        return labels[arg]
    end

    local n = tonumber(arg)
    if n == nil then
        error("invalid operand: " .. tostring(arg))
    end

    return n
end

local function push(stack, v)
    stack[#stack + 1] = v
end

local function pop(stack, ip)
    if #stack == 0 then
        error("VM error <"..ip..">: stack underflow", 3)
    end

    local v = stack[#stack]
    stack[#stack] = nil

    return v
end

local function peek(stack)
    return stack[#stack]
end

local function jump(vm, target)
    if not tonumber(target) then
        error("VM helper error <"..vm.ip..">: target needs to be a number")
    end

    -- i won't need to touch this cus before runtime it automatically removes labels
    -- and adds {"labelname", ipnum} into labels table then when JMP, JZ, JNZ, etc
    -- are detected, it checks if the label name that the OP is trying to go to exists
    -- and if it is there then jump there
    vm.ip = tonumber(target)
end

local function advance(vm, old_ip)
    if vm.ip == old_ip then
        vm.ip = vm.ip + 1
    end
end

local function getType(arg)
    -- why lua just dosen't add a switch????

    -- while making this i realized i don't know why i'm making this
    -- i forgor, ill finish it ig
    local v = arg
    if type(v) == "number" and v % 1 ~= 0 then
        return types.T_FLOAT
    elseif type(v) == "number" then -- hate that math.type was added in lua 5.3 and higher
        return types.T_INT
    elseif type(v) == "boolean" then
        return types.T_BOOL
    elseif type(v) == "table" and type(v.x) == "number" then
        return types.T_VECTOR
    elseif type(v) == "table" and type(v.__type) == "string" then --[[lua has no structs so i just check if the
__type value exists (and is a string)]]
        return types.T_STRUCT
    elseif type(v) == "string" and #v == 1 then
        return types.T_CHAR
    elseif type(v) == "string" then
        return types.T_STR
    elseif type(v) == "table" then
        return types.T_ARRAY -- in the VM context it would be an array rather than a table (meaning no dicts or anything)
    elseif type(v) == "nil" then
        return types.T_NULL -- ehh, i don't really want to call it T_NIL, sounds not so nice
    else
        return nil
    end
end

-- i hate this gibberish
local function isLabel(line)
    return tostring(line):match("^%s*[%a_][%w_]*%s*:$") ~= nil
end

-- mostly for debugging
function toBinary(n)
    if n == 0 then
        return "0"
    end

    local binary = ""

    while n > 0 do
        binary = (n % 2) .. binary
        n = math.floor(n / 2)
    end

    return binary
end

-- sucks that lua does not have built-in enums like C
local OP = {
    PUSH = 1,
    POP = 2,
    DUP = 3,

    ADD = 4,
    SUB = 5,
    MUL = 6, -- i don't know if i should call it MULT or MUL
    DIV = 7,
    NEG = 8,

    JMP = 9,
    JZ = 10,
    JNZ = 11,

    EQ = 12,
    NEQ = 13,
    LT = 14,
    GT = 15,
    LTE = 16,
    GTE = 17,

    AND = 18,
    OR = 19,
    NOT = 20,
    NAND = 21,
    NOR = 22,
    XOR = 23,
    XNOR = 24,

    STORE = 25,
    LOAD = 26,

    PRINT = 27,

    CALL = 28,
    RET = 29,
    LOAD_ARGS = 30,

    NEW_ARRAY = 31,
    GET_ARRAY = 32,
    SET_ARRAY = 33,
    GET_ARRAY_SIZE = 34,

    EXT = 35,
    EXT_CALL = 36,

    HALT = 37,
    GET_TYPE = 38,
    PUSH_STR = 39, -- made it cus PUSH cannot push things like "123"
    TYPE_TO_STRING = 40,
    STRING_TO_ARRAY = 41,
}

local handlers = {}

handlers[OP.PUSH] = function(vm, arg)
    local value = tonumber(arg)

    if value then
        push(vm.stack, value)
        return
    end

    push(vm.stack, arg)
end

handlers[OP.POP] = function(vm)
    pop(vm.stack, vm.ip)
end

handlers[OP.DUP] = function(vm)
    push(vm.stack, peek(vm.stack))
end

handlers[OP.ADD] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)
    push(vm.stack, a + b)
end

handlers[OP.SUB] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)
    push(vm.stack, a - b)
end

handlers[OP.MUL] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)
    push(vm.stack, a * b)
end

handlers[OP.DIV] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)
    push(vm.stack, a / b)
end

handlers[OP.NEG] = function(vm)
    local raw = pop(vm.stack, vm.ip)
    local v = tonumber(raw)
    if not v then
        error("VM error <"..vm.ip..">: NEG expects number")
    end
    push(vm.stack, -v)
end

handlers[OP.JMP] = function(vm, arg)
    local target = resolve(arg, vm.labels)

    if target == nil then
        error("VM error <"..vm.ip..">: invalid JMP target")
    end

    jump(vm, target)
end

handlers[OP.JZ] = function(vm, arg)
    local target = resolve(arg, vm.labels)

    if target == nil then
        error("VM error <"..vm.ip..">: invalid JMP target")
    end

    if peek(vm.stack) == 0 then
        pop(vm.stack, vm.ip)
        jump(vm, target)
        return
    end

    pop(vm.stack, vm.ip)
end

handlers[OP.JNZ] = function(vm, arg)
    local target = resolve(arg, vm.labels)

    if target == nil then
        error("VM error <"..vm.ip..">: invalid JMP target")
    end

    if peek(vm.stack) ~= 0 then
        pop(vm.stack, vm.ip)
        jump(vm, target)
        return
    end

    pop(vm.stack, vm.ip)
end

handlers[OP.EQ] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: idk how to name this error")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)

    if a == b then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.NEQ] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: idk how to name this error")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)

    if a ~= b then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.LT] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: idk how to name this error")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)

    if a < b then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.GT] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: idk how to name this error")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)

    if a > b then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.LTE] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: idk how to name this error")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)

    if a <= b then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.GTE] = function(vm)
    if #vm.stack <= 1 then
        error("VM error <"..vm.ip..">: idk how to name this error")
    end

    local b = pop(vm.stack, vm.ip)
    local a = pop(vm.stack, vm.ip)

    if a >= b then
        push(vm.stack, 1)
    else
        push(vm.stack, 0)
    end
end

handlers[OP.AND] = function(vm)
    if #vm.stack < 2 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local rawa, rawb = pop(vm.stack, vm.ip), pop(vm.stack, vm.ip)
    local b = tonumber(rawb)
    local a = tonumber(rawa)

    if not a then
        error("VM error <"..vm.ip..">: AND operator expected number, instead got "..type(rawa))
    end

    if not b then
        error("VM error <"..vm.ip..">: AND operator expected number, instead got "..type(rawb))
    end

    -- i'm so glad lua 5.2 has the bit32 library
    push(vm.stack, bit32.band(a, b))
end

handlers[OP.OR] = function(vm)
    if #vm.stack < 2 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local rawa, rawb = pop(vm.stack, vm.ip), pop(vm.stack, vm.ip)
    local b = tonumber(rawb)
    local a = tonumber(rawa)

    if not a then
        error("VM error <"..vm.ip..">: OR operator expected number, instead got "..type(rawa))
    end

    if not b then
        error("VM error <"..vm.ip..">: OR operator expected number, instead got "..type(rawb))
    end

    push(vm.stack, bit32.bor(a, b))
end

handlers[OP.NOT] = function(vm)
    if #vm.stack < 1 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local rawa = pop(vm.stack, vm.ip)
    local a = tonumber(rawa)

    if not a then
        error("VM error <"..vm.ip..">: NOT operator expected number, instead got "..type(rawa))
    end

    push(vm.stack, bit32.bnot(a))
end

handlers[OP.NAND] = function(vm)
    if #vm.stack < 2 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local rawa, rawb = pop(vm.stack, vm.ip), pop(vm.stack, vm.ip)
    local b = tonumber(rawb)
    local a = tonumber(rawa)

    if not a then
        error("VM error <"..vm.ip..">: NAND operator expected number, instead got "..type(rawa))
    end

    if not b then
        error("VM error <"..vm.ip..">: NAND operator expected number, instead got "..type(rawb))
    end

    push(vm.stack, bit32.bnot(bit32.band(a, b)))
end

handlers[OP.NOR] = function(vm)
    if #vm.stack < 2 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local rawa, rawb = pop(vm.stack, vm.ip), pop(vm.stack, vm.ip)
    local b = tonumber(rawb)
    local a = tonumber(rawa)

    if not a then
        error("VM error <"..vm.ip..">: NOR operator expected number, instead got "..type(rawa))
    end

    if not b then
        error("VM error <"..vm.ip..">: NOR operator expected number, instead got "..type(rawb))
    end

    push(vm.stack, bit32.bnot(bit32.bor(a, b)))
end

handlers[OP.XOR] = function(vm)
    if #vm.stack < 2 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local rawa, rawb = pop(vm.stack, vm.ip), pop(vm.stack, vm.ip)
    local b = tonumber(rawb)
    local a = tonumber(rawa)

    if not a then
        error("VM error <"..vm.ip..">: XOR operator expected number, instead got "..type(rawa))
    end

    if not b then
        error("VM error <"..vm.ip..">: XOR operator expected number, instead got "..type(rawb))
    end

    push(vm.stack, bit32.bxor(a, b))
end

handlers[OP.XNOR] = function(vm)
    if #vm.stack < 2 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local rawa, rawb = pop(vm.stack, vm.ip), pop(vm.stack, vm.ip)
    local b = tonumber(rawb)
    local a = tonumber(rawa)

    if not a then
        error("VM error <"..vm.ip..">: XNOR operator expected number, instead got "..type(rawa))
    end

    if not b then
        error("VM error <"..vm.ip..">: XNOR operator expected number, instead got "..type(rawb))
    end

    push(vm.stack, bit32.bnot(bit32.bxor(a, b)))
end

-- idk why this took too much thinking, atleast there is scope now
handlers[OP.STORE] = function(vm, arg)
    if #vm.stack == 0 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local value = pop(vm.stack, vm.ip)

    local frame = vm.frames[#vm.frames]

    if frame and frame.vars then
        frame.vars[arg] = value
    else
        vm.globals[arg] = value
    end
end

handlers[OP.LOAD] = function(vm, arg)
    if not arg then
        error("VM error <"..vm.ip..">: no variable passed in")
    end

    local frame = vm.frames[#vm.frames]

    if frame and frame.vars and frame.vars[arg] ~= nil then
        push(vm.stack, frame.vars[arg])
        return
    elseif vm.globals[arg] ~= nil then
        push(vm.stack, vm.globals[arg])
        return
    end

    error("VM error <"..vm.ip..">: undefined variable")
end

handlers[OP.PRINT] = function(vm)
    if #vm.stack == 0 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    print(peek(vm.stack))
end

handlers[OP.CALL] = function(vm, arg, arg_count)
    table.insert(vm.frames, {})
    local frame = vm.frames[#vm.frames]
    frame.vars = {}
    frame.return_ip = vm.ip + 1
    frame.args = {}

    if tonumber(arg_count) == nil then
        error("VM error <"..vm.ip..">: arg_count is supposed to be a number")
    end

    for i = tonumber(arg_count), 1, -1 do
        table.insert(frame.args, 1, pop(vm.stack, vm.ip))
    end

    vm.ip = resolve(arg, vm.labels)
end

handlers[OP.RET] = function(vm)
    local frame = vm.frames[#vm.frames]

    if not frame then
        error("VM error <"..vm.ip..">: RET with no frame")
    end

    vm.ip = frame.return_ip
    table.remove(vm.frames, #vm.frames)
end

handlers[OP.LOAD_ARGS] = function(vm)
    local frame = vm.frames[#vm.frames]

    if not frame then
        error("VM error <"..vm.ip..">: LOAD_ARGS outside function")
    end

    for i = 1, #frame.args do
        -- if there i more than 1 arg, to get all of these you'd need to use NEW_ARRAY then
        -- GET_ARRAY to get an element from the array
        push(vm.stack, frame.args[i])
    end
end

handlers[OP.NEW_ARRAY] = function(vm, count)
    if count and not tonumber(count) then
        error("VM error <"..vm.ip..">: NEW_ARRAY expected integer, instead got: "..type(count))
    elseif count then
        local values = {}
        count = tonumber(count)

        for i = count, 1, -1 do
            values[i] = pop(vm.stack, vm.ip)
        end

        values[count + 1] = ARRAY_END
        push(vm.stack, values)
        return
    end

    push(vm.stack, {})
end

handlers[OP.GET_ARRAY] = function(vm, arg)
    if type(peek(vm.stack)) ~= "table" then
        error("VM error <"..vm.ip..">: tried to use GET_ARRAY on a non-array value")
    end

    local t = pop(vm.stack, vm.ip)

    if arg and not tonumber(arg) then
        error("VM error <"..vm.ip..">: GET_ARRAY expected integer, instead got: "..type(arg))
    elseif arg then
        push(vm.stack, t[tonumber(arg)])
        return
    end

    for i = 1, #t do
        if t[i] == ARRAY_END then
            break
        end

        push(vm.stack, t[i])
    end
end

handlers[OP.SET_ARRAY] = function(vm, value, pos)
    if type(peek(vm.stack)) ~= "table" then
        error("VM error <"..vm.ip..">: tried to use SET_ARRAY on a non-array value")
    end

    if not value then
        error("VM error <"..vm.ip..">: SET_ARRAY expected a value to be set, instead got none")
    end

    if pos and not tonumber(pos) then
        error("VM error <"..vm.ip..">: SET_ARRAY expected integer, instead got: "..type(pos))
    elseif pos then
        peek(vm.stack)[tonumber(pos)] = value
    end
end

handlers[OP.GET_ARRAY_SIZE] = function(vm)
    if type(peek(vm.stack)) ~= "table" then
        error("VM error <"..vm.ip..">: tried to use GET_ARRAY_SIZE on a non-array value")
    end

    local t = pop(vm.stack, vm.ip)

    local i = 1
    while t[i] and t[i] ~= ARRAY_END do
        i = i + 1
    end

    push(vm.stack, i - 1)
end

handlers[OP.EXT] = function(vm, arg)
    if not arg or arg == "" then
        error("VM error <"..vm.ip..">: EXT missing module name")
    end

    local ok, mod = pcall(require, arg)
    if ok then
        vm.ext = vm.ext or {} -- just in case it does not exist cus like smth happened
        vm.ext[arg] = mod
        return
    end

    -- polytoria module support
    mod = _G
    for part in arg:gmatch("[^%.]+") do
        mod = mod[part]
        if mod == nil then
            error("VM error <"..vm.ip..">: failed to resolve '"..arg.."'")
        end
    end

    ok, mod = pcall(require , mod)
    if not ok then
        error("VM error <"..vm.ip..">: failed to require '"..arg.."': "..tostring(mod))
    end

    vm.ext = vm.ext or {}
    vm.ext[arg] = mod
end

handlers[OP.EXT_CALL] = function(vm, arg)
    if not arg then
        error("VM error <"..vm.ip..">: EXT_CALL missing arguments")
    end

    local mod_name, func_name, count_str = arg:match("^(%S+)%s+(%S+)%s+(%d+)$") -- this was annoying to make
    if not mod_name then
        error("VM error <"..vm.ip..">: EXT_CALL syntax: 'module func count'")
    end

    local count = tonumber(count_str)
    if count < 0 then
        error("VM error <"..vm.ip.."<: EXT_CALL arg count must be >= 0")
    end

    vm.ext = vm.ext or {} -- just in case, you neve know, also i don't trust my code
    local mod = vm.ext[mod_name]
    if not mod then
        error("VM error <"..vm.ip..">: module '"..mod_name.."' not loaded, use EXT first")
    end

    local func = mod[func_name]
    if not func then
        error("VM error <"..vm.ip..">: function '"..func_name.."' not loaded in module '"..mod_name.."'")
    end

    local args = {}
    for i = count, 1, -1 do
        args[i] = pop(vm.stack, vm.ip)
    end

    local result = func(table.unpack(args))

    if result ~= nil then
        push(vm.stack, result)
    end
end

handlers[OP.HALT] = function(vm)
    vm.ip = math.huge
end

handlers[OP.GET_TYPE] = function(vm)
    if #vm.stack == 0 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local value = pop(vm.stack, vm.ip)
    push(vm.stack, getType(value)) -- you can replace type() with typeof() if you are using luau
end

handlers[OP.PUSH_STR] = function(vm, arg)
    if not arg then
        error("VM error <"..vm.ip..">: PUSH_STR expected value, instead got none")
    end

    arg = tostring(arg)

    push(vm.stack, arg)
end

handlers[OP.TYPE_TO_STRING] = function(vm)
    if #vm.stack == 0 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local value = pop(vm.stack, vm.ip)
    if not tonumber(value) or value >= 10 or value <= 0 then
        error("VM error <"..vm.ip..">: type not found")
    end

    value = tonumber(value)

    if value == 1 then
        push(vm.stack, "T_INT")
    elseif value == 2 then
        push(vm.stack, "T_STR")
    elseif value == 3 then
        push(vm.stack, "T_NULL")
    elseif value == 4 then
        push(vm.stack, "T_BOOL")
    elseif value == 5 then
        push(vm.stack, "T_ARRAY")
    elseif value == 6 then
        push(vm.stack, "T_CHAR")
    elseif value == 7 then
        push(vm.stack, "T_FLOAT")
    elseif value == 8 then
        push(vm.stack, "T_VECTOR")
    elseif value == 9 then
        push(vm.stack, "T_STRUCT")
    end
end

handlers[OP.STRING_TO_ARRAY] = function(vm)
    if #vm.stack == 0 then
        error("VM error <"..vm.ip..">: stack underflow")
    end

    local stringval = pop(vm.stack, vm.ip)

    if type(stringval) ~= "string" then
        error("VM error <"..vm.ip..">: passed a non-string value to STRING_TO_ARRAY")
    end
    
    local string_array = {}

    for i = 1, #stringval then
        table.insert(string_array, stringval:sub(i, i))
    end

    -- uncomment this if you plan on adding stuff into the string array (specifically nil)
    -- table.insert(string_array, #string_array + 1, ARRAY_END)

    push(vm.stack, string_array)
end

local jvm = {} -- JadeVM, the name of my VM

function jvm.VM(bytecode)
    local vm = newVM()
    local labels = vm.labels
    local instructions = {}

    for line in bytecode:gmatch("([^\n]+)") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^%-%-") then
            local label = trimmed:match("^(%w+):$")
            if label then
                labels[label] = #instructions + 1
            else
                local op, rest = trimmed:match("^(%S+)%s*(.*)$")

                if op == "CALL" then
                    local label, count = rest:match("^(%S+)%s+(%d+)$")
                    table.insert(instructions, {OP.CALL, label, tonumber(count)})
                else
                    table.insert(instructions, {OP[op], rest})
                end
            end
        end
    end

    vm.code = instructions

    while vm.ip <= #vm.code do
        local line = vm.code[vm.ip]
        local op, arg, arg_count = line[1], line[2], line[3]

        local handler = handlers[op]
        if not handler then
            error("VM error <"..vm.ip..">: Unknown opcode")
        end

        local old_ip = vm.ip
        handler(vm, arg, arg_count, vm.labels)

        if vm.ip == old_ip then
            vm.ip = vm.ip + 1
        end
    end
end

return jvm
