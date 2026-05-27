# JadeVM
A VM that executes Codebyte, made with pure lua

How to use:
inside VM.lua, there is a function VM(codebyte) where codebyte is a multi-line string

Instructions:

<pre>
PUSH_INT int - Pushes an int to the stack (LIFO)
PUSH_STR string - pushes a string to the stack
POP - pops the last value from the stack
DUP - duplicates the last value in the stack [5] -> [5, 5]
ADD - addition
SUB - subtraction
MUL - multiplication
DIV - division
NEG - negates the value [5] <-> [-5]
JMP int/label - jumps to a label or a line
JZ int/label - jumps to a label or a line IF the the last value is 0
JNZ int/label - does the same as JZ but if it's not a 0
EQ - gives true/false if the last 2 values are equal or not
NEQ - opposite of EQ
LT - lower than
GT - greater than
LTE - basically LT + EQ
GTE - basically GT + EQ
PRINT - prints the last thing into the console
STORE var - stores a variable
LOAD var - loads a variable
CALL label - calls a function/label
RET arg - returns + ends the function (Required for every function made, arg is optional)
LOAD_ARG - returns the last thing before function call (Should only be called inside a function)
HALT - ends the program/code
EXT mod_name - requires a lua library or a .lua module
EXT_CALL mod_name func_name arg_count - calls a function from the module or library, mod name is the module name, func name is the function name and arg count is the arguments to input from stack (LIFO)
</pre>
