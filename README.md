# JadeVM
A VM that executes Codebyte, made only using lua
Has support for polytoria's modulescript

How to use:
inside VM.lua, there is a function VM(codebyte) where codebyte is a multi-line string

Instructions:

<pre>
PUSH value - Pushes an int to the stack (LIFO)
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
CALL label arg_count - calls a function/label, arg_count works just like the EXT_CALL's one
RET arg - returns + ends the function (Required for every function made, arg is optional)
LOAD_ARG - returns the last thing before function call (Should only be called inside a function)
HALT - ends the program/code
EXT mod_name - requires a lua library or a .lua module
EXT_CALL mod_name func_name arg_count - calls a function from the module or library, mod name is the module name, func name is the function name and arg count is the arguments to input from stack (LIFO)
AND - and logical operator
OR - or logical operator
NOT - not logical operator
NAND - nand logical operator
NOR - nor logical operator
XOR - xor logical operator
XNOR - xnor logical operator
NEW_ARRAY amount - creates an array, amount works like just arg_count from EXT_CALL
GET_ARRAY element - pushes an element from an array, element should be an integer, also if element is not passed then it would just push everything the array has into the stack
SET_ARRAY value, pos - pushes or changes an element into the table, value is required while pos is optional
GET_ARRAY_SIZE - pushes the size of the array
GET_TYPE - gets the type of a value (be ware it pushes a value from 1 to 9, NOT a string, use TYPE_TO_STRING to conver it to a string)
TYPE_TO_STRING - converts a number between 1 to 9 into a type, intended to be used after GET_TYPE)
</pre>
