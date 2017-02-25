# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

TILE_SCAN       = 0xffff0024
SEED_TILE       = 0xffff0054
WATER_TILE      = 0xffff002c
MAX_GROWTH_TILE = 0xffff0030
HARVEST_TILE    = 0xffff0020
BURN_TILE       = 0xffff0058
GET_FIRE_LOC    = 0xffff0028
PUT_OUT_FIRE    = 0xffff0040

GET_NUM_WATER_DROPS   = 0xffff0044
GET_NUM_SEEDS         = 0xffff0048
GET_NUM_FIRE_STARTERS = 0xffff004c
SET_RESOURCE_TYPE     = 0xffff00dc
REQUEST_PUZZLE        = 0xffff00d0
SUBMIT_SOLUTION       = 0xffff00d4

# interrupt constants
BONK_MASK               = 0x1000
BONK_ACK                = 0xffff0060
TIMER_MASK              = 0x8000
TIMER_ACK               = 0xffff006c
ON_FIRE_MASK            = 0x400
ON_FIRE_ACK             = 0xffff0050
MAX_GROWTH_ACK          = 0xffff005c
MAX_GROWTH_INT_MASK     = 0x2000
REQUEST_PUZZLE_ACK      = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800

# size constants
TILE_ARRAY_SIZE = 1600
PUZZLE_SIZE = 4096
SOLUTION_SIZE = 328

WATER_AMOUNT = 5
HARVEST_AT = 0

.data
# data things go here
.align 3
tile_data: .space 1600
puzzle_requests: .word -1 -1 -1 -1 -1 -1 -1 -1 -1
puzzle: .space 40960 # 10 puzzle slots
solution: .space 3280 # 10 solution slots
path: .space 40 # 10 growing tiles
#water: .word 0 0 0 0 0 0 0 0 0 0

fire_buf: .space 400
fire_buf_size: .word 0
fire_buf_start: .word 0
fire_buf_end: .word 0

three:  .float  3.0
five:   .float  5.0
PI: .float  3.141592
F180:   .float  180.0
ten: .double 10.0
velocity_fac: .double 0.0001

arrived: .word 0
pending_puzzle: .word 0

.text
main:
    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp) 
    sw $s5, 24($sp)
    sw $s6, 28($sp)
    sw $s7, 32($sp)

	# go wild
	# the world is your oyster :)
    sw $zero, VELOCITY

    li $t8, BONK_MASK
    #or $t8, $t8, ON_FIRE_MASK
    #or $t8, $t8, MAX_GROWTH_INT_MASK
    or $t8, $t8, REQUEST_PUZZLE_INT_MASK
    or $t8, $t8, TIMER_MASK
    or $t8, $t8, 1
    mtc0 $t8, $12

    la $a2, path
    lw $a0, BOT_X
    div $a0, $a0, 30
    lw $a1, BOT_Y
    div $a1, $a1, 30
    jal create_path

    la $t0, path
    lw $t0, 0($t0)
    li $t1, 10
    div $t0, $t1
    mfhi $a0
    mflo $a1
    jal move_bot
wait:
    la $t0, arrived
    lw $t0, 0($t0)
    beqz $t0, wait

    li $s0, 1
m_for_83: 
    la $t1, puzzle_requests
    lw $t0, GET_NUM_WATER_DROPS
    bgt $t0, 10, check_seeds
    li $t0, 0
    sw $t0, 0($t1)
    #sw $t0, 4($t1)
    #sw $t0, 8($t1)

check_seeds:
    lw $t0, GET_NUM_SEEDS
    bgt $t0, 1, check_flint
    li $t0, 1
    sw $t0, 4($t1)

check_flint:
    lw $t0, GET_NUM_FIRE_STARTERS
    bgt $t0, 1, request_res
    li $t0, 2
    sw $t0, 8($t1)

request_res:
    jal request

    lw $t8, BOT_X
    div $t8, $t8, 30

    lw $t9, BOT_Y
    div $t9, $t9, 30

    mul $t0, $t9, 10
    add $t0, $t0, $t8

    la $t8, tile_data
    sw $t8, TILE_SCAN
    sll $t2, $t0, 4
    add $t2, $t2, $t8 # tile_data + i
    lw $t5, 0($t2) # state
    lw $t6, 4($t2) # owning
    lw $t7, 8($t2) # growth
    beqz $t5, seeding
    bnez $t6, sabotage # sabotage
    #blt $t7, HARVEST_AT, watering

harvesting:
    sw $zero, HARVEST_TILE

seeding:
    sw $zero, SEED_TILE

watering:
    li $t8, WATER_AMOUNT
    sw $t8, WATER_TILE

    j finish_up

sabotage:
    sw $zero, BURN_TILE

finish_up:
    sll $t0, $s0, 2
    la $t1, path
    add $t0, $t0, $t1 # path + i
    lw $t0, 0($t0) # path[i]
    li $t1, 10
    div $t0, $t1
    mfhi $a0
    mflo $a1
    #sw $a0, PRINT_INT_ADDR
    #sw $a1, PRINT_INT_ADDR
    jal move_bot
    jal solve
wait_for_arriving:
    la $t0, arrived
    lw $t0, 0($t0)
    beqz $t0, wait_for_arriving
    #sw $a0, PRINT_INT_ADDR
    #sw $a1, PRINT_INT_ADDR
    add $s0, $s0, 1
    rem $s0, $s0, 10
    j m_for_83
m_endfor_83:

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp) 
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    add $sp, $sp, 36

	jr $ra

#int create_path(int x_coord, int y_coord, int* path) {
create_path:
    sub $sp, $sp, 32
    sw  $s0, 0($sp)
    sw  $s1, 4($sp)
    sw  $s2, 8($sp)
    sw  $s3, 12($sp)
    sw  $s4, 16($sp)
    sw  $s5, 20($sp)
    sw  $s6, 24($sp)
    sw  $s7, 28($sp)

#   int vec[2];
    # $s2, $s3
#   int pos[2];
    # $s0, $s1
#   int idx = 0;
    # $s4
    move $s4, $zero
#   int size = 10;
#   int a = 0, b = 0;
    # $s5, $s6
    move $s5, $zero
    move $s6, $zero
#   int turn_num = 0;
    # $s7
    move $s7, $zero
#
#   pos[0] = x_coord;
    move $s0, $a0
#   pos[1] = y_coord;
    move $s1, $a1
#
#   int temp0 = (x_coord <= 1 || x_coord >= 8);
    sle $t8, $a0, 1
    sge $t9, $a0, 8
    or  $t0, $t8, $t9
#   int temp1 = (y_coord <= 1 || y_coord >= 8);
    sle $t8, $a1, 1
    sge $t9, $a1, 8
    or  $t1, $t8, $t9
#   int temp2 = (x_coord == 1 || x_coord == 8);
    seq $t8, $a0, 1
    seq $t9, $a0, 8
    or  $t2, $t8, $t9
#   int temp3 = (y_coord == 1 || y_coord == 8);
    seq $t8, $a1, 1
    seq $t9, $a1, 8
    or  $t3, $t8, $t9
#
#   if (temp0 && temp1 && !(temp2 && temp3)) {
cp_if_0:
    and $t2, $t2, $t3
    not $t2, $t2
    beqz $t0, cp_endif_0
    beqz $t1, cp_endif_0
    beqz $t2, cp_endif_0

#       if (pos[0] <= 1) pos[0] = 1;
cp_if_1: 
    bgt $s0, 1, cp_if_2
    li $s0, 1
    j cp_if_3
#       else if (pos[0] >= 8) pos[0] = 8;
cp_if_2:
    blt $s0, 8, cp_if_3
    li $s0, 8
#       if (pos[1] <= 1) pos[1] = 1;
cp_if_3:
    bgt $s1, 1, cp_if_4
    li $s1, 1
    j cp_endif_0
#       else if (pos[1] >= 8) pos[1] = 8;
cp_if_4: 
    blt $s1, 8, cp_endif_0
    li $s1, 8
#   }
cp_endif_0: 

#
#   if (pos[0] < 5 && pos[1] < 5) {
#       vec[0] = -1;
#       vec[1] = 1;
#   } else if (pos[0] < 5) {
#       vec[0] = 1;
#       vec[1] = 1;
#   } else if (pos[1] < 5) {
#       vec[0] = -1;
#       vec[1] = -1;
#   } else {
#       vec[0] = 1;
#       vec[1] = -1;
#   }
#

    slt $t8, $s0, 5 # pos[0] < 5
    slt $t9, $s1, 5 # pos[1] < 5
    and $t0, $t8, $t9 # pos[0] < 5 && pos[1] < 5

cp_if_5: 
    bnez $t0, cp_if_5_b0
    bnez $t8, cp_if_5_b1
    bnez $t9, cp_if_5_b2
    j cp_if_5_b3

cp_if_5_b0:
    li $s2, -1
    li $s3, 1
    j cp_endif_5

cp_if_5_b1:
    li $s2, 1
    li $s3, 1
    j cp_endif_5

cp_if_5_b2:
    li $s2, -1
    li $s3, -1
    j cp_endif_5

cp_if_5_b3:
    li $s2, 1
    li $s3, -1

cp_endif_5:

#   int temp = 3; 
    # temp $t0
    li $t0, 3
#   
#   while (turn_num < 5) {
cp_while_0: 
    bge $s7, 5, cp_endwhile_0
#       while (idx < temp) {
cp_while_1:
    bge $s4, $t0, cp_endwhile_1
#           int next_x = pos[0] + vec[0];
    # next_x $t8
    add $t8, $s0, $s2
#           int next_y = pos[1] + vec[1];
    # next_y $t9
    add $t9, $s1, $s3
#   
#           if (next_x >= 0 && next_x < size && next_y >= 0 && next_y < size) {
cp_if_6:
    blt $t8, 0, cp_endwhile_1 # else break
    bge $t8, 10, cp_endwhile_1 # else break
    blt $t9, 0, cp_endwhile_1 # else break
    bge $t9, 10, cp_endwhile_1 # else break
    
#               pos[0] = next_x;
    move $s0, $t8
#               pos[1] = next_y;
    move $s1, $t9
#               path[idx++] = pos[1] * size + pos[0];
    mul $t1, $s1, 10 # pos[1] * size
    add $t1, $t1, $s0 # pos[1] * size + pos[0]
    sll $t2, $s4, 2 # idx * 4
    add $t2, $t2, $a2 # (char*) path + idx * 4
    sw $t1, 0($t2) # path[idx] = pos[1] * size + pos[0];
    add $s4, $s4, 1

#           } else break;
cp_endif_6: 
#       }
    j cp_while_1
cp_endwhile_1:
#       
#       turn_num++;
    add $s7, $s7, 1
#       int x = vec[1], y = -vec[0];
    # x $t8 y $t9
    neg $t9, $s2
#       vec[0] = x;
    move $s2, $s3
#       vec[1] = y;
    move $s3, $t9
#       
#       if (turn_num == 1) {
#           a = idx;
#           temp = idx + 3;
#       } else if (turn_num == 2) {
#           b = idx - a;
#           a = 5 - b;
#           temp = idx + a;
#       } else if (turn_num == 3) {
#           temp = idx + b;
#       } else if (turn_num == 4) {
#           temp = 10;
#       }

cp_if_7:
    beq $s7, 1, cp_if_7_b0
    beq $s7, 2, cp_if_7_b1
    beq $s7, 3, cp_if_7_b2
    j cp_if_7_b3

cp_if_7_b0:
    move $s5, $s4
    add $t0, $s4, 3
    j cp_endif_7

cp_if_7_b1:
    sub $s6, $s4, $s5
    neg $s5, $s6 # a = -b
    add $s5, $s5, 5 # a = -b + 5
    add $t0, $s4, $s5 
    j cp_endif_7

cp_if_7_b2:
    add $t0, $s4, $s6
    j cp_endif_7

cp_if_7_b3:
    li $t0, 10

cp_endif_7:

#   }
    j cp_while_0
cp_endwhile_0:
#}
    sw  $s0, 0($sp)
    sw  $s1, 4($sp)
    sw  $s2, 8($sp)
    sw  $s3, 12($sp)
    sw  $s4, 16($sp)
    sw  $s5, 20($sp)
    sw  $s6, 24($sp)
    sw  $s7, 28($sp)
    add $sp, $sp, 32

    jr $ra

move_bot:
    sw $zero, VELOCITY

    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp) 
    sw $s5, 24($sp)
    sw $s6, 28($sp)
    sw $s7, 32($sp)

    la $t0, arrived
    sw $zero, 0($t0)
    
    move $s0, $a0
    move $s1, $a1   
    
    lw $s2, BOT_X
    lw $s3, BOT_Y
    li $t0, 30
    div $s2, $t0
    mflo $s4
    div $s3, $t0
    mflo $s5
    
    # $s6 stores the x coord the bot aims to move
    # $s7 stores the y coord the bot aims to move
    # temporily
    #beq $s0, $s4, adjust_y
    mul $s6, $s0, 30
    add $s6, $s6, 15
    #bgt $s6, $s2, left_side
    #add $s6, $s6, 10
    #j adjust_y
    #left_side:
    #sub $s6, $s7 10
    #adjust_y:
    #beq $s7, $s5, end_adjust
    mul $s7, $s1, 30
    add $s7, $s7, 15
    #bgt $s7, $s3, up_side
    #add $s7, $t1, 10
    #j end_adjust
    #up_side:
    #sub $s7, $s7, 10
    
    end_adjust:
    sub $a0, $s6, $s2
    sub $a1, $s7, $s3
    jal sb_arctan
    
    # use atan2(x,y) to convert arctan(x,y)
    sub $t0, $s6, $s2 # $t0: x
    sub $t1, $s7, $s3 # $t1: y
    
    bgt $t0, $0, case1
    #revise
    #sge $t2, $t1, $0 # $t2 = 1 if y >= 0
    #slt $t3, $t0, $0 # $t3 = 1 if x < 0
    #and $t4, $t2, $t3 # $t4 = 1 if y >= 0 && x < 0
    #beq $t4, 1, case2
    
    #slt $t2, $t1, $0 # $t2 = 1 if y < 0
    #slt $t3, $t0, $0 # $t3 = 1 if x < 0
    #and $t4, $t2, $t3 # $t4 = 1 if y < 0 && x < 0
    #beq $t4, 1, case3
    
    #sgt $t2, $t1, $0 # $t2 = 1 if y > 0
    #seq $t3, $t0, $0 # $t3 = 0 if x == 0
    #and $t4, $t2, $t3 # $t4 = 1 if y > 0 && x == 0
    #beq $t4, 1, case4
    
    #slt $t2, $t1, $0 # $t2 = 1 if y < 0
    #seq $t3, $t0, $0 # $t3 = 0 if x == 0
    #and $t4, $t2, $t3 # $t4 = 1 if y < 0 && x == 0
    #beq $t4, 1, case5
    
    #seq $t2, $t1, $0 # $t2 = 1 if y == 0
    #seq $t3, $t0, $0 # $t3 = 0 if x == 0
    #and $t4, $t2, $t3 # $t4 = 1 if y == 0 && x == 0
    #beq $t4, 1, end_move_bot
    
    
    
    blt $t0, 0, y_situation_1;
    beq $t0, 0, y_situation_2;
    
    y_situation_1:
      bge $t1, 0, case2;
      blt $t1, 0, case3;
     
     y_situation_2:
       bgt $t1, 0, case4;
       blt $t1, 0, case5;
       beq $t1, 0, end_move_bot;
    
    # $t5 will be the absolute angle the bot should head to
    case1:
    move $t5, $v0
    j orientation
    
    case2:
    add $t5, $v0, 0
    j orientation
    
    case3:
    sub $t5, $v0, 0
    j orientation
    
    case4:
    li $t5, 270
    j orientation
    
    case5:
    li $t5, 90
    j orientation
    
    orientation:
    sw $t5, ANGLE
    li $t6, 1
    sw $t6, ANGLE_CONTROL
# -----------------------------------------------------
    lw $t0, BOT_X
    lw $t1, BOT_Y
    mul $t2, $s0, 30 
    add $t2, $t2, 15
    mul $t3, $s1, 30
    add $t3, $t3, 15
    sub $t2, $t2, $t0 # dx
    sub $t3, $t3, $t1 # dy
    mul $t2, $t2, $t2 # dx^2
    mul $t3, $t3, $t3 # dy^2
    add $t2, $t2, $t3 # dx^2 + dy^2
    #sw $t2, PRINT_INT_ADDR
    mtc1 $t2, $f0
    cvt.d.w $f0, $f0
    sqrt.d $f0, $f0 # dist = sqrt(dx^2 + dy^2)
    l.d $f2, ten
    l.d $f4, velocity_fac
    mul.d $f2, $f2, $f4 # velocity
    div.d $f6, $f0, $f2 # num_cycles
    cvt.w.d $f6, $f6
    mfc1 $t6, $f6 # num_cycles
    lw $t5, TIMER
    add $t5, $t5, $t6
    sw $t5, TIMER # request timer interrupt
# -----------------------------------------------------
    li $t6, 10
    sw $t6, VELOCITY
    
    movement:
#    li $t6, 30
#    lw $t0, BOT_X
#    lw $t1, BOT_Y
#    div $t0, $t6
#    mflo $t2 # $t2 is the x-idx of the tile that the bot is currently in
#    div $t1, $t6
#    mflo $t3 # $t3 is the y-idx of the tile that the bot is currently in
#    bne $t2, $s0, movement
#    bne $t3, $s1, movement
    
    end_move_bot:
#    sw $0, VELOCITY
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp) 
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    add $sp, $sp, 36
    jr $ra

request: 

    move $t4, $zero # pending_puzzle
    move $t0, $zero
r_for_0:
    bge $t0, 10, r_endfor_0
    
    sll $t1, $t0, 2
    la $t2, puzzle_requests
    add $t2, $t2, $t1
    lw $t3, 0($t2) # puzzle_requests[i]
    beq $t3, -1, r_for_0_continue # if (puzzle_requests[i] == -1) continue;
    add $t4, $t4, 1

r_for_0_continue:
    add $t0, $t0, 1
    j r_for_0
r_endfor_0:
    la $t0, pending_puzzle
    sw $t4, 0($t0)

    move $t0, $zero
r_for_1:
    bge $t0, 10, r_endfor_1

    sll $t1, $t0, 2
    la $t2, puzzle_requests
    add $t2, $t2, $t1
    lw $t3, 0($t2) # puzzle_requests[i]
    beq $t3, -1, r_for_1_continue # if (puzzle_requests[i] == -1) continue;
    sw $t3, SET_RESOURCE_TYPE

    sll $t1, $t0, 12
    la $t2, puzzle
    add $t2, $t2, $t1
    sw $t2, REQUEST_PUZZLE

r_for_1_continue:
    add $t0, $t0, 1
    j r_for_1
r_endfor_1:

    jr $ra
    
solve: 
    wait_for_puzzle: 
    la $t0, pending_puzzle
    lw $t0, 0($t0)
    bnez $t0, wait_for_puzzle

    sub $sp, $sp, 12
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)

    move $s0, $zero
s_for_0:
    bge $s0, 10, s_endfor_0

    sll $t1, $s0, 2
    la $t2, puzzle_requests
    add $t2, $t2, $t1
    lw $t3, 0($t2) # puzzle_requests[i]
    beq $t3, -1, s_for_0_continue # if (puzzle_requests[i] == -1) continue;
    li $t3, -1
    sw $t3, 0($t2)

    mul $t1, $s0, 328
    la $t2, solution
    add $t2, $t2, $t1 # solution[i]
    move $t8, $t2 # start 
    add $t9, $t8, 328 # end
    zeroing:
    bge $t8, $t9, finish_zeroing
    sw $zero, 0($t8)
    add $t8, $t8, 4
    j zeroing
    finish_zeroing:
    sll $t1, $s0, 12
    la $t3, puzzle
    add $t3, $t3, $t1 # puzzle[i]
    move $a0, $t2
    move $a1, $t3
    move $s1, $t2
    jal recursive_backtracking

    sw $s1, SUBMIT_SOLUTION

s_for_0_continue:
    add $s0, $s0, 1
    j s_for_0
s_endfor_0:

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    add $sp, $sp, 12

    jr $ra

sb_arctan:
    li  $v0, 0      # angle = 0;

    abs $t0, $a0    # get absolute values
    abs $t1, $a1
    ble $t1, $t0, no_TURN_90      

    ## if (abs(y) > abs(x)) { rotate 90 degrees }
    move    $t0, $a1    # int temp = y;
    neg $a1, $a0    # y = -x;      
    move    $a0, $t0    # x = temp;    
    li  $v0, 90     # angle = 90;  

no_TURN_90:
    bgez    $a0, pos_x  # skip if (x >= 0)

    ## if (x < 0) 
    add $v0, $v0, 180   # angle += 180;

pos_x:
    mtc1    $a0, $f0
    mtc1    $a1, $f1
    cvt.s.w $f0, $f0    # convert from ints to floats
    cvt.s.w $f1, $f1
    
    div.s   $f0, $f1, $f0   # float v = (float) y / (float) x;

    mul.s   $f1, $f0, $f0   # v^^2
    mul.s   $f2, $f1, $f0   # v^^3
    l.s $f3, three  # load 5.0
    div.s   $f3, $f2, $f3   # v^^3/3
    sub.s   $f6, $f0, $f3   # v - v^^3/3

    mul.s   $f4, $f1, $f2   # v^^5
    l.s $f5, five   # load 3.0
    div.s   $f5, $f4, $f5   # v^^5/5
    add.s   $f6, $f6, $f5   # value = v - v^^3/3 + v^^5/5

    l.s $f8, PI     # load PI
    div.s   $f6, $f6, $f8   # value / PI
    l.s $f7, F180   # load 180.0
    mul.s   $f6, $f6, $f7   # 180.0 * value / PI

    cvt.w.s $f6, $f6    # convert "delta" back to integer
    mfc1    $t0, $f6
    add $v0, $v0, $t0   # angle += delta

    jr  $ra
    

# -----------------------------------------------------------------------
# euclidean_dist - computes sqrt(x^2 + y^2)
# $a0 - x
# $a1 - y
# returns the distance
# -----------------------------------------------------------------------

euclidean_dist:
    mul $a0, $a0, $a0   # x^2
    mul $a1, $a1, $a1   # y^2
    add $v0, $a0, $a1   # x^2 + y^2
    mtc1    $v0, $f0
    cvt.s.w $f0, $f0    # float(x^2 + y^2)
    sqrt.s  $f0, $f0    # sqrt(x^2 + y^2)
    cvt.w.s $f0, $f0    # int(sqrt(...))
    mfc1    $v0, $f0
    jr  $ra

.text

## struct Cage {
##   char operation;
##   int target;
##   int num_cell;
##   int* positions;
## };
##
## struct Cell {
##   int domain;
##   Cage* cage;
## };
##
## struct Puzzle {
##   int size;
##   Cell* grid;
## };
##
## struct Solution {
##   int size;
##   int assignment[81];
## };
##
## int recursive_backtracking(Solution* solution, Puzzle* puzzle) {
##   if (is_complete(solution, puzzle)) {
##     return 1;
##   }
##   int position = get_unassigned_position(solution, puzzle);
##   for (int val = 1; val < puzzle->size + 1; val++) {
##     if (puzzle->grid[position].domain & (0x1 << (val - 1))) {
##       solution->assignment[position] = val;
##       solution->size += 1;
##       // Applies inference to reduce space of possible assignment.
##       Puzzle puzzle_copy;
##       Cell grid_copy [81]; // 81 is the maximum size of the grid.
##       puzzle_copy.grid = grid_copy;
##       clone(puzzle, &puzzle_copy);
##       puzzle_copy.grid[position].domain = 0x1 << (val - 1);
##       if (forward_checking(position, &puzzle_copy)) {
##         if (recursive_backtracking(solution, &puzzle_copy)) {
##           return 1;
##         }
##       }
##       solution->assignment[position] = 0;
##       solution->size -= 1;
##     }
##   }
##   return 0;
## }

.globl recursive_backtracking
recursive_backtracking:
  sub   $sp, $sp, 680
  sw    $ra, 0($sp)
  sw    $a0, 4($sp)     # solution
  sw    $a1, 8($sp)     # puzzle
  sw    $s0, 12($sp)    # position
  sw    $s1, 16($sp)    # val
  sw    $s2, 20($sp)    # 0x1 << (val - 1)
                        # sizeof(Puzzle) = 8
                        # sizeof(Cell [81]) = 648

  jal   is_complete
  bne   $v0, $0, recursive_backtracking_return_one
  lw    $a0, 4($sp)     # solution
  lw    $a1, 8($sp)     # puzzle
  jal   get_unassigned_position
  move  $s0, $v0        # position
  li    $s1, 1          # val = 1
recursive_backtracking_for_loop:
  lw    $a0, 4($sp)     # solution
  lw    $a1, 8($sp)     # puzzle
  lw    $t0, 0($a1)     # puzzle->size
  add   $t1, $t0, 1     # puzzle->size + 1
  bge   $s1, $t1, recursive_backtracking_return_zero  # val < puzzle->size + 1
  lw    $t1, 4($a1)     # puzzle->grid
  mul   $t4, $s0, 8     # sizeof(Cell) = 8
  add   $t1, $t1, $t4   # &puzzle->grid[position]
  lw    $t1, 0($t1)     # puzzle->grid[position].domain
  sub   $t4, $s1, 1     # val - 1
  li    $t5, 1
  sll   $s2, $t5, $t4   # 0x1 << (val - 1)
  and   $t1, $t1, $s2   # puzzle->grid[position].domain & (0x1 << (val - 1))
  beq   $t1, $0, recursive_backtracking_for_loop_continue # if (domain & (0x1 << (val - 1)))
  mul   $t0, $s0, 4     # position * 4
  add   $t0, $t0, $a0
  add   $t0, $t0, 4     # &solution->assignment[position]
  sw    $s1, 0($t0)     # solution->assignment[position] = val
  lw    $t0, 0($a0)     # solution->size
  add   $t0, $t0, 1
  sw    $t0, 0($a0)     # solution->size++
  add   $t0, $sp, 32    # &grid_copy
  sw    $t0, 28($sp)    # puzzle_copy.grid = grid_copy !!!
  move  $a0, $a1        # &puzzle
  add   $a1, $sp, 24    # &puzzle_copy
  jal   clone           # clone(puzzle, &puzzle_copy)
  mul   $t0, $s0, 8     # !!! grid size 8
  lw    $t1, 28($sp)
  
  add   $t1, $t1, $t0   # &puzzle_copy.grid[position]
  sw    $s2, 0($t1)     # puzzle_copy.grid[position].domain = 0x1 << (val - 1);
  move  $a0, $s0
  add   $a1, $sp, 24
  jal   forward_checking  # forward_checking(position, &puzzle_copy)
  beq   $v0, $0, recursive_backtracking_skip

  lw    $a0, 4($sp)     # solution
  add   $a1, $sp, 24    # &puzzle_copy
  jal   recursive_backtracking
  beq   $v0, $0, recursive_backtracking_skip
  j     recursive_backtracking_return_one # if (recursive_backtracking(solution, &puzzle_copy))
recursive_backtracking_skip:
  lw    $a0, 4($sp)     # solution
  mul   $t0, $s0, 4
  add   $t1, $a0, 4
  add   $t1, $t1, $t0
  sw    $0, 0($t1)      # solution->assignment[position] = 0
  lw    $t0, 0($a0)
  sub   $t0, $t0, 1
  sw    $t0, 0($a0)     # solution->size -= 1
recursive_backtracking_for_loop_continue:
  add   $s1, $s1, 1     # val++
  j     recursive_backtracking_for_loop
recursive_backtracking_return_zero:
  li    $v0, 0
  j     recursive_backtracking_return
recursive_backtracking_return_one:
  li    $v0, 1
recursive_backtracking_return:
  lw    $ra, 0($sp)
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  lw    $s0, 12($sp)
  lw    $s1, 16($sp)
  lw    $s2, 20($sp)
  add   $sp, $sp, 680
  jr    $ra

## int convert_highest_bit_to_int(int domain) {
##   int result = 0;
##   for (; domain; domain >>= 1) {
##     result ++;
##   }
##   return result;
## }


convert_highest_bit_to_int:
    move  $v0, $0             # result = 0

chbti_loop:
    beq   $a0, $0, chbti_end
    add   $v0, $v0, 1         # result ++
    sra   $a0, $a0, 1         # domain >>= 1
    j     chbti_loop

chbti_end:
    jr    $ra


is_single_value_domain:
    beq    $a0, $0, isvd_zero     # return 0 if domain == 0
    sub    $t0, $a0, 1	          # (domain - 1)
    and    $t0, $t0, $a0          # (domain & (domain - 1))
    bne    $t0, $0, isvd_zero     # return 0 if (domain & (domain - 1)) != 0
    li     $v0, 1
    jr	   $ra

isvd_zero:	   
    li	   $v0, 0
    jr	   $ra
    

get_domain_for_addition:
    sub    $sp, $sp, 20
    sw     $ra, 0($sp)
    sw     $s0, 4($sp)
    sw     $s1, 8($sp)
    sw     $s2, 12($sp)
    sw     $s3, 16($sp)
    move   $s0, $a0                     # s0 = target
    move   $s1, $a1                     # s1 = num_cell
    move   $s2, $a2                     # s2 = domain

    move   $a0, $a2
    jal    convert_highest_bit_to_int
    move   $s3, $v0                     # s3 = upper_bound

    sub    $a0, $0, $s2                 # -domain
    and    $a0, $a0, $s2                # domain & (-domain)
    jal    convert_highest_bit_to_int   # v0 = lower_bound
       
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $v0                # (num_cell - 1) * lower_bound
    sub    $t0, $s0, $t0                # t0 = high_bits

    # ** fix **
    bge $t0, $zero, end_fix
    move $t0, $zero
    end_fix: nop
    # ** fix **

    bge    $t0, $s3, gdfa_skip1

    li     $t1, 1          
    sll    $t0, $t1, $t0                # 1 << high_bits
    sub    $t0, $t0, 1                  # (1 << high_bits) - 1
    and    $s2, $s2, $t0                # domain & ((1 << high_bits) - 1)

gdfa_skip1:    
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $s3                # (num_cell - 1) * upper_bound
    sub    $t0, $s0, $t0                # t0 = low_bits
    ble    $t0, $0, gdfa_skip2

    sub    $t0, $t0, 1                  # low_bits - 1
    sra    $s2, $s2, $t0                # domain >> (low_bits - 1)
    sll    $s2, $s2, $t0                # domain >> (low_bits - 1) << (low_bits - 1)

gdfa_skip2:    
    move   $v0, $s2                     # return domain
    lw     $ra, 0($sp)
    lw     $s0, 4($sp)
    lw     $s1, 8($sp)
    lw     $s2, 12($sp)
    lw     $s3, 16($sp)
    add    $sp, $sp, 20
    jr     $ra


get_domain_for_subtraction:
    li     $t0, 1              
    li     $t1, 2
    mul    $t1, $t1, $a0            # target * 2
    sll    $t1, $t0, $t1            # 1 << (target * 2)
    or     $t0, $t0, $t1            # t0 = base_mask
    li     $t1, 0                   # t1 = mask

gdfs_loop:
    beq    $a2, $0, gdfs_loop_end   
    and    $t2, $a2, 1              # other_domain & 1
    beq    $t2, $0, gdfs_if_end
       
    sra    $t2, $t0, $a0            # base_mask >> target
    or     $t1, $t1, $t2            # mask |= (base_mask >> target)

gdfs_if_end:
    sll    $t0, $t0, 1              # base_mask <<= 1
    sra    $a2, $a2, 1              # other_domain >>= 1
    j      gdfs_loop

gdfs_loop_end:
    and    $v0, $a1, $t1            # domain & mask
    jr     $ra


get_domain_for_cell:
    # save registers    
    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    sw $s6, 28($sp)
    sw $s7, 32($sp)

    li $t0, 0 # valid_domain
    lw $t1, 4($a1) # puzzle->grid (t1 free)
    sll $t2, $a0, 3 # position*8 (actual offset) (t2 free)
    add $t3, $t1, $t2 # &puzzle->grid[position]
    lw  $t4, 4($t3) # &puzzle->grid[position].cage
    lw  $t5, 0($t4) # puzzle->grid[posiition].cage->operation

    lw $t2, 4($t4) # puzzle->grid[position].cage->target

    move $s0, $t2   # remain_target = $s0  *!*!
    lw $s1, 8($t4) # remain_cell = $s1 = puzzle->grid[position].cage->num_cell
    lw $s2, 0($t3) # domain_union = $s2 = puzzle->grid[position].domain
    move $s3, $t4 # puzzle->grid[position].cage
    li $s4, 0   # i = 0
    move $s5, $t1 # $s5 = puzzle->grid
    move $s6, $a0 # $s6 = position
    # move $s7, $s2 # $s7 = puzzle->grid[position].domain

    bne $t5, 0, gdfc_check_else_if

    li $t1, 1
    sub $t2, $t2, $t1 # (puzzle->grid[position].cage->target-1)
    sll $v0, $t1, $t2 # valid_domain = 0x1 << (prev line comment)
    j gdfc_end # somewhere!!!!!!!!

gdfc_check_else_if:
    bne $t5, '+', gdfc_check_else

gdfc_else_if_loop:
    lw $t5, 8($s3) # puzzle->grid[position].cage->num_cell
    bge $s4, $t5, gdfc_for_end # branch if i >= puzzle->grid[position].cage->num_cell
    sll $t1, $s4, 2 # i*4
    lw $t6, 12($s3) # puzzle->grid[position].cage->positions
    add $t1, $t6, $t1 # &puzzle->grid[position].cage->positions[i]
    lw $t1, 0($t1) # pos = puzzle->grid[position].cage->positions[i]
    add $s4, $s4, 1 # i++

    sll $t2, $t1, 3 # pos * 8
    add $s7, $s5, $t2 # &puzzle->grid[pos]
    lw  $s7, 0($s7) # puzzle->grid[pos].domain

    beq $t1, $s6 gdfc_else_if_else # branch if pos == position

    

    move $a0, $s7 # $a0 = puzzle->grid[pos].domain
    jal is_single_value_domain
    bne $v0, 1 gdfc_else_if_else # branch if !is_single_value_domain()
    move $a0, $s7
    jal convert_highest_bit_to_int
    sub $s0, $s0, $v0 # remain_target -= convert_highest_bit_to_int
    addi $s1, $s1, -1 # remain_cell -= 1
    j gdfc_else_if_loop
gdfc_else_if_else:
    or $s2, $s2, $s7 # domain_union |= puzzle->grid[pos].domain
    j gdfc_else_if_loop

gdfc_for_end:
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal get_domain_for_addition # $v0 = valid_domain = get_domain_for_addition()
    j gdfc_end

gdfc_check_else:
    lw $t3, 12($s3) # puzzle->grid[position].cage->positions
    lw $t0, 0($t3) # puzzle->grid[position].cage->positions[0]
    lw $t1, 4($t3) # puzzle->grid[position].cage->positions[1]
    xor $t0, $t0, $t1
    xor $t0, $t0, $s6 # other_pos = $t0 = $t0 ^ position
    lw $a0, 4($s3) # puzzle->grid[position].cage->target

    sll $t2, $s6, 3 # position * 8
    add $a1, $s5, $t2 # &puzzle->grid[position]
    lw  $a1, 0($a1) # puzzle->grid[position].domain
    # move $a1, $s7 

    sll $t1, $t0, 3 # other_pos*8 (actual offset)
    add $t3, $s5, $t1 # &puzzle->grid[other_pos]
    lw $a2, 0($t3)  # puzzle->grid[other_pos].domian

    jal get_domain_for_subtraction # $v0 = valid_domain = get_domain_for_subtraction()
    # j gdfc_end
gdfc_end:
# restore registers
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    add $sp, $sp, 36    
    jr $ra



clone:

    lw  $t0, 0($a0)
    sw  $t0, 0($a1)

    mul $t0, $t0, $t0
    mul $t0, $t0, 2 # two words in one grid

    lw  $t1, 4($a0) # &puzzle(ori).grid
    lw  $t2, 4($a1) # &puzzle(clone).grid

    li  $t3, 0 # i = 0;
clone_for_loop:
    bge  $t3, $t0, clone_for_loop_end
    sll $t4, $t3, 2 # i * 4
    add $t5, $t1, $t4 # puzzle(ori).grid ith word
    lw   $t6, 0($t5)

    add $t5, $t2, $t4 # puzzle(clone).grid ith word
    sw   $t6, 0($t5)
    
    addi $t3, $t3, 1 # i++
    
    j    clone_for_loop
clone_for_loop_end:

    jr  $ra


forward_checking:
    sub   $sp, $sp, 24
    sw    $ra, 0($sp)
    sw    $a0, 4($sp)
    sw    $a1, 8($sp)
    sw    $s0, 12($sp)
    sw    $s1, 16($sp)
    sw    $s2, 20($sp)
    lw    $t0, 0($a1)     # size
    li    $t1, 0          # col = 0
fc_for_col:
    bge   $t1, $t0, fc_end_for_col  # col < size
    div   $a0, $t0
    mfhi  $t2             # position % size
    mflo  $t3             # position / size
    beq   $t1, $t2, fc_for_col_continue    # if (col != position % size)
    mul   $t4, $t3, $t0
    add   $t4, $t4, $t1   # position / size * size + col
    mul   $t4, $t4, 8
    lw    $t5, 4($a1) # puzzle->grid
    add   $t4, $t4, $t5   # &puzzle->grid[position / size * size + col].domain
    mul   $t2, $a0, 8   # position * 8
    add   $t2, $t5, $t2 # puzzle->grid[position]
    lw    $t2, 0($t2) # puzzle -> grid[position].domain
    not   $t2, $t2        # ~puzzle->grid[position].domain
    lw    $t3, 0($t4) #
    and   $t3, $t3, $t2
    sw    $t3, 0($t4)
    beq   $t3, $0, fc_return_zero # if (!puzzle->grid[position / size * size + col].domain)
fc_for_col_continue:
    add   $t1, $t1, 1     # col++
    j     fc_for_col
fc_end_for_col:
  li    $t1, 0          # row = 0
fc_for_row:
  bge   $t1, $t0, fc_end_for_row  # row < size
  div   $a0, $t0
  mflo  $t2             # position / size
  mfhi  $t3             # position % size
  beq   $t1, $t2, fc_for_row_continue
  lw    $t2, 4($a1)     # puzzle->grid
  mul   $t4, $t1, $t0
  add   $t4, $t4, $t3
  mul   $t4, $t4, 8
  add   $t4, $t2, $t4   # &puzzle->grid[row * size + position % size]
  lw    $t6, 0($t4)
  mul   $t5, $a0, 8
  add   $t5, $t2, $t5
  lw    $t5, 0($t5)     # puzzle->grid[position].domain
  not   $t5, $t5
  and   $t5, $t6, $t5
  sw    $t5, 0($t4)
  beq   $t5, $0, fc_return_zero
fc_for_row_continue:
  add   $t1, $t1, 1     # row++
  j     fc_for_row
fc_end_for_row:

  li    $s0, 0          # i = 0
fc_for_i:
  lw    $t2, 4($a1)
  mul   $t3, $a0, 8
  add   $t2, $t2, $t3
  lw    $t2, 4($t2)     # &puzzle->grid[position].cage
  lw    $t3, 8($t2)     # puzzle->grid[position].cage->num_cell
  bge   $s0, $t3, fc_return_one
  lw    $t3, 12($t2)    # puzzle->grid[position].cage->positions
  mul   $s1, $s0, 4
  add   $t3, $t3, $s1
  lw    $t3, 0($t3)     # pos
  lw    $s1, 4($a1)
  mul   $s2, $t3, 8
  add   $s2, $s1, $s2   # &puzzle->grid[pos].domain
  lw    $s1, 0($s2)
  move  $a0, $t3
  jal get_domain_for_cell
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  and   $s1, $s1, $v0
  sw    $s1, 0($s2)     # puzzle->grid[pos].domain &= get_domain_for_cell(pos, puzzle)
  beq   $s1, $0, fc_return_zero
fc_for_i_continue:
  add   $s0, $s0, 1     # i++
  j     fc_for_i
fc_return_one:
  li    $v0, 1
  j     fc_return
fc_return_zero:
  li    $v0, 0
fc_return:
  lw    $ra, 0($sp)
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  lw    $s0, 12($sp)
  lw    $s1, 16($sp)
  lw    $s2, 20($sp)
  add   $sp, $sp, 24
  jr    $ra

get_unassigned_position:
  li    $v0, 0            # unassigned_pos = 0
  lw    $t0, 0($a1)       # puzzle->size
  mul  $t0, $t0, $t0     # puzzle->size * puzzle->size
  add   $t1, $a0, 4       # &solution->assignment[0]
get_unassigned_position_for_begin:
  bge   $v0, $t0, get_unassigned_position_return  # if (unassigned_pos < puzzle->size * puzzle->size)
  mul  $t2, $v0, 4
  add   $t2, $t1, $t2     # &solution->assignment[unassigned_pos]
  lw    $t2, 0($t2)       # solution->assignment[unassigned_pos]
  beq   $t2, 0, get_unassigned_position_return  # if (solution->assignment[unassigned_pos] == 0)
  add   $v0, $v0, 1       # unassigned_pos++
  j   get_unassigned_position_for_begin
get_unassigned_position_return:
  jr    $ra


is_complete:
  lw    $t0, 0($a0)       # solution->size
  lw    $t1, 0($a1)       # puzzle->size
  mul   $t1, $t1, $t1     # puzzle->size * puzzle->size
  move  $v0, $0
  seq   $v0, $t0, $t1
  j     $ra

.kdata
temp: .space 100

.ktext 0x80000180
interrupt_handler:

.set noat
	add $k1, $zero, $at
.set at
	la $k0, temp;
	sw $t0, 0($k0)
	sw $t1, 4($k0)
	sw $t2, 8($k0)
	sw $t3, 12($k0)
	sw $t4, 16($k0)
	sw $t5, 20($k0)
	sw $t6, 24($k0)
	sw $t7, 28($k0)
	sw $t8, 32($k0)
	sw $t9, 36($k0)

	mfc0 $t0, $13
	srl $t0, $t0, 2
	add $t0, $t0, 0xf
	# bne $t0, $zero, cleanup

interrupt:

	mfc0 $t0, $13
	beqz $t0, cleanup

	and $t1, $t0, BONK_MASK
	bne $t1, $zero, bonk_handler

	and $t1, $t0, ON_FIRE_MASK
	bne $t1, $zero, fire_handler

	and $t1, $t0, REQUEST_PUZZLE_INT_MASK
	bne $t1, $zero, puzzle_handler

	and $t1, $t0, MAX_GROWTH_INT_MASK
	bne $t1, $zero, harvest_handler 

    and $t1, $t0, TIMER_MASK
    bne $t1, $zero, timer_handler

	j cleanup

bonk_handler:
	sw $t0, BONK_ACK
	sw $zero, VELOCITY

	j interrupt

fire_handler:
	sw $t0, ON_FIRE_ACK
	lw $t5, GET_FIRE_LOC
	srl $t3, $t5, 16 # x
	and $t4, $t5, 0x0000ffff # y

	mul $t5, $t4, 10
	add $t5, $t5, $t3 # value

	la $t6, fire_buf
	la $t3,	fire_buf_end
	lw $t4, 0($t3) # end

	sll $t4, $t4, 2
	add $t4, $t4, $t6
	sw $t5, 0($t4)

	lw $t4, 0($t3)
	add $t4, $t4, 1
    rem $t4, $t4, 100
	sw $t4, 0($t3)

    la $t3, fire_buf_size
    lw $t4, 0($t3)
    add $t4, $t4, 1
    sw $t4, 0($t3)

	j interrupt

puzzle_handler:
	#li $t0, 0xdeadcafe
	#sw $t0, PRINT_HEX_ADDR
	sw $t0, REQUEST_PUZZLE_ACK
    la $t0, pending_puzzle
    lw $t1, 0($t0)
    sub $t1, $t1, 1
    sw $t1, 0($t0)
	j interrupt

harvest_handler:

	j interrupt

timer_handler: 
    sw $t0, TIMER_ACK
    sw $zero, VELOCITY
    la $t0, arrived
    li $t1, 1
    sw $t1, 0($t0)

    j interrupt

cleanup:
	la $k0, temp;
	lw $t0, 0($k0)
	lw $t1, 4($k0)
	lw $t2, 8($k0)
	lw $t3, 12($k0)
	lw $t4, 16($k0)
	lw $t5, 20($k0)
	lw $t6, 24($k0)
	lw $t7, 28($k0)
	lw $t8, 32($k0)
	lw $t9, 36($k0)

    .set noat
    move $at, $k1
    .set at

	eret