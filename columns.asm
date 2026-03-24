################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Amey Khatri, 1011175210
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:    256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# Colors
RED:        .word 0xff0000
ORANGE:     .word 0xffaa00
YELLOW:     .word 0xffff00
GREEN:      .word 0x00ff00
BLUE:       .word 0x0000ff
PURPLE:     .word 0xff00ff
BLACK:      .word 0x000000
WHITE:      .word 0xffffff

# Grid configuration
GRID_WIDTH:  .word 6
GRID_HEIGHT: .word 15
DISPLAY_WIDTH: .word 32    # 256 pixels / 8 pixels per unit

# Each direction is (dcol, drow) — 4 directions * 2 words = 8 words
DIRECTIONS:
    .word 0, 1      # vertical (down)
    .word 1, 0      # horizontal (right)
    .word 1, 1      # diagonal ↘
    .word 1, -1     # diagonal ↗
    
GRAVITY_COUNTER:  .word 0      # increments every frame
GRAVITY_RATE:     .word 37     # move down every 37 frames (~600ms at 60fps)

# 5x5 pixel art bitmasks for G, A, M, E, O, V, R (Reuse E)
# Each letter is 5 rows of 5 bits, stored as 5 words
# 1 = draw white pixel, 0 = skip (black)
# Letters are 5 wide x 5 tall, with 1 unit gap between them

LETTER_G:
    .word 0b11111   # █████
    .word 0b10000   # █
    .word 0b10111   # █ ███
    .word 0b10001   # █   █
    .word 0b11111   # █████

LETTER_A:
    .word 0b11111   # █████
    .word 0b10001   # █   █
    .word 0b11111   # █████
    .word 0b10001   # █   █
    .word 0b10001   # █   █

LETTER_M:
    .word 0b10001   # █   █
    .word 0b11111   # █████
    .word 0b10101   # █ █ █
    .word 0b10001   # █   █
    .word 0b10001   # █   █

LETTER_E:
    .word 0b11111   # █████
    .word 0b10000   # █
    .word 0b11110   # ████
    .word 0b10000   # █
    .word 0b11111   # █████

LETTER_O:
    .word 0b11111   # █████
    .word 0b10001   # █   █
    .word 0b10001   # █   █
    .word 0b10001   # █   █
    .word 0b11111   # █████

LETTER_V:
    .word 0b10001   # █   █
    .word 0b10001   # █   █
    .word 0b10001   # █   █
    .word 0b01010   # █ █ 
    .word 0b00100   #   █

LETTER_R:
    .word 0b11110   # ████
    .word 0b10001   # █   █
    .word 0b11110   # ████
    .word 0b10010   # █  █
    .word 0b10001   # █   █

# Lookup table: pointers to each letter's bitmask
# "GAME OVER" = G, A, M, E, O, V, E, R
GAMEOVER_LETTERS:
    .word LETTER_G
    .word LETTER_A
    .word LETTER_M
    .word LETTER_E
    .word LETTER_O
    .word LETTER_V
    .word LETTER_E
    .word LETTER_R

GAMEOVER_LEN: .word 8          # number of letters

##############################################################################
# Mutable Data
##############################################################################
# Grid to store gem colors (6 * 15 = 90 cells * 4 bytes = 360 bytes)
GRID:   .space 360

# Grid to store matches
MATCH:  .space 360    # 90 cells * 4 bytes, 1 = marked for deletion, 0 = keep

# Colour lookup table (index 1-6, index 0 = empty/black)
COLOUR_TABLE:
    .word 0x000000   # 0 = empty
    .word 0xff0000   # 1 = red
    .word 0xffaa00   # 2 = orange
    .word 0xffff00   # 3 = yellow
    .word 0x00ff00   # 4 = green
    .word 0x0000ff   # 5 = blue
    .word 0xff00ff   # 6 = purple

# Grid origin in bitmap units (0-indexed, first playable cell)
GRID_ORIGIN_X:  .word 2     # 0-indexed col of top-left playable cell
GRID_ORIGIN_Y:  .word 3     # 0-indexed row of top-left playable cell

# Current falling column state
COL_X:      .word 2     # grid col (0-indexed, start at center of 6-wide = col 2)
COL_Y:      .word 0     # grid row of TOP gem (0-indexed)
COL_GEM0:   .word 0     # top gem colour ID
COL_GEM1:   .word 0     # middle gem colour ID
COL_GEM2:   .word 0     # bottom gem colour ID



##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    
    li $a0, 1
    li $a1, 2
    jal draw_grid

    jal generate_column
    jal draw_column


    

game_loop:
    # 1. Check keyboard input
    jal check_keyboard          # handle a/d/w/s/q keys

    # 2. Apply gravity
    jal apply_column_gravity    # move column down on timer, land if needed

    # 3. Sleep
    li $v0, 32                  # syscall 32 = sleep
    li $a0, 16                  # sleep 16ms (~60fps)
    syscall

    j game_loop                 # repeat forever
    
    
##############################################################################
# game_over_screen
# Draws game over message, waits for r (retry) or q (quit)
# Clobbers: $t0-$t2 (saves/restores $ra)

game_over_screen:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal draw_game_over          # draw "GAME OVER" on screen

gos_wait_loop:
    # Poll keyboard
    lw $t0, ADDR_KBRD           # keyboard base address
    lw $t1, 0($t0)              # 1 if key pressed
    bne $t1, 1, gos_wait_loop   # no key, keep waiting

    lw $t2, 4($t0)              # ASCII of key pressed
    beq $t2, 0x72, gos_retry    # 'r' = retry
    beq $t2, 0x71, gos_quit     # 'q' = quit
    j gos_wait_loop             # any other key, keep waiting

gos_retry:
    jal reset_game              # clear all state
    li $a0, 1                   # redraw border
    li $a1, 2
    jal draw_grid
    jal generate_column         # spawn first column
    jal draw_column

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra                      # return to game_loop

gos_quit:
    li $v0, 10                  # exit
    syscall    
    
##############################################################################
# reset_game
# Clears all mutable state back to initial values
# Clobbers: $t0-$t2

reset_game:
        # --- Paint entire 256x256 bitmap black ---
    lw $t0, ADDR_DSPL           # base address of display
    li $t1, 4096                # 32*32 = 1024 units, * 4 bytes = 4096 words
    li $t2, 0                   # black

rgo_clear_loop:
    beq $t1, 0, rgo_clear_done  # all units painted
    sw $t2, 0($t0)              # paint this unit black
    addi $t0, $t0, 4            # next unit
    addi $t1, $t1, -1           # decrement counter
    j rgo_clear_loop

rgo_clear_done:

    # Reset falling column position
    li $t0, 2
    sw $t0, COL_X               # center column
    sw $zero, COL_Y             # top row
    sw $zero, COL_GEM0
    sw $zero, COL_GEM1
    sw $zero, COL_GEM2

    # Reset gravity counter
    sw $zero, GRAVITY_COUNTER

    # Clear GRID array (90 cells)
    la $t0, GRID
    li $t1, 90                  # 90 cells
reset_grid_loop:
    beq $t1, 0, reset_grid_done
    sw $zero, 0($t0)            # zero this cell
    addi $t0, $t0, 4            # next cell
    addi $t1, $t1, -1
    j reset_grid_loop
reset_grid_done:

    # Clear MATCH array (90 cells)
    la $t0, MATCH
    li $t1, 90
reset_match_loop:
    beq $t1, 0, reset_match_done
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    j reset_match_loop
reset_match_done:

    jr $ra    
    
##############################################################################
# draw_game_over
# Clears the play area and draws "GAME OVER" in pixel art
# Letters are drawn starting from bitmap row 8, centered in the play area
# Clobbers: $t0-$t9, $s0-$s3 (saves/restores $ra, $s registers)

draw_game_over:
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)              # letter index
    sw $s1, 8($sp)              # current draw x (bitmap units)
    sw $s2, 12($sp)             # current letter address
    sw $s3, 16($sp)             # current row within letter

    # --- Paint entire 256x256 bitmap black ---
    lw $t0, ADDR_DSPL           # base address of display
    li $t1, 4096                # 32*32 = 1024 units, * 4 bytes = 4096 words
    li $t2, 0                   # black

dgo_clear_loop:
    beq $t1, 0, dgo_clear_done  # all units painted
    sw $t2, 0($t0)              # paint this unit black
    addi $t0, $t0, 4            # next unit
    addi $t1, $t1, -1           # decrement counter
    j dgo_clear_loop

dgo_clear_done:


    # --- Draw each letter ---
    # "GAME OVER" is 8 letters * 6 units wide (5 + 1 gap) = 48 units
    # Play area is 6 units wide — we draw 2 rows of 4 letters
    # Row 1 "GAME" starts at grid row 3, col 0
    # Row 2 "OVER" starts at grid row 10, col 0

    li $s0, 0                   # letter index (0-7)

dgo_letter_loop:
    lw $t0, GAMEOVER_LEN
    beq $s0, $t0, dgo_done      # all letters drawn

    # Decide which row and col to draw at
    # Letters 0-3 (GAME): bitmap row = GRID_ORIGIN_Y + 3, col shifts by 6 per letter
    # Letters 4-7 (OVER): bitmap row = GRID_ORIGIN_Y + 10, col shifts by 6 per letter

    li $t1, 4
    bge $s0, $t1, dgo_second_row

    # First row: GAME
    move $t2, $s0               # letter index 0-3
    li $t3, 6
    mul $s1, $t2, $t3           # x = letter_index * 6 (in grid coords)
    li $s3, 3                   # start at grid row 3
    j dgo_draw_letter

dgo_second_row:
    # Second row: OVER
    addi $t2, $s0, -4           # letter index 0-3 within OVER
    li $t3, 6
    mul $s1, $t2, $t3           # x = letter_index * 6
    li $s3, 10                  # start at grid row 10

dgo_draw_letter:
    # Load pointer to this letter's bitmask
    la $t0, GAMEOVER_LETTERS
    sll $t1, $s0, 2             # letter index * 4
    add $t0, $t0, $t1
    lw $s2, 0($t0)              # $s2 = address of letter bitmask

    # Draw 5 rows of this letter
    li $t6, 0                   # row within letter (0-4)

dgo_row_loop:
    li $t7, 5
    beq $t6, $t7, dgo_letter_done  # 5 rows drawn

    # Load bitmask row
    sll $t0, $t6, 2             # row * 4
    add $t0, $t0, $s2           # address of this row's bitmask
    lw $t1, 0($t0)              # $t1 = 5-bit bitmask

    # Draw 5 pixels of this row
    li $t2, 4                   # bit position (start from bit 4 = leftmost)

dgo_pixel_loop:
    bltz $t2, dgo_next_row      # all 5 bits drawn

    # Check if this bit is set
    srlv $t3, $t1, $t2          # shift right by bit position
    andi $t3, $t3, 1            # isolate bit
    beq $t3, 0, dgo_skip_pixel  # bit = 0, skip

    # Compute grid col and row for this pixel
    li $t4, 4
    sub $t4, $t4, $t2           # pixel col within letter = 4 - bit_pos
    add $t4, $t4, $s1           # + letter x offset = grid col
    add $t5, $s3, $t6           # grid row = letter_start_row + row_within_letter

    # Save $t1 (bitmask) and $t2 (bit position) before jal clobbers them
    addi $sp, $sp, -8
    sw $t1, 0($sp)              # save bitmask row
    sw $t2, 4($sp)              # save bit position

    move $a0, $t4               # grid col
    move $a1, $t5               # grid row
    jal grid_to_addr            # $v0 = bitmap address — clobbers $t0-$t3

    lw $t1, 0($sp)              # restore bitmask row
    lw $t2, 4($sp)              # restore bit position
    addi $sp, $sp, 8

    lw $t3, WHITE               # reload WHITE — $t3 was clobbered
    sw $t3, 0($v0)              # paint white

dgo_skip_pixel:
    addi $t2, $t2, -1           # next bit
    j dgo_pixel_loop

dgo_next_row:
    addi $t6, $t6, 1            # next row within letter
    j dgo_row_loop

dgo_letter_done:
    addi $s0, $s0, 1            # next letter
    j dgo_letter_loop

dgo_done:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra    
    
##############################################################################
# apply_column_gravity
# Increments gravity counter each frame, moves column down when counter
# hits GRAVITY_RATE. Calls land_column if column has landed.
# Clobbers: $t0-$t2 (saves/restores $ra)

apply_column_gravity:
    addi $sp, $sp, -4           # allocate stack space
    sw $ra, 0($sp)              # save return address

    # Increment counter
    lw $t0, GRAVITY_COUNTER     # load current counter value
    addi $t0, $t0, 1            # increment by 1
    sw $t0, GRAVITY_COUNTER     # store updated counter

    # Check if counter has reached gravity rate
    lw $t1, GRAVITY_RATE        # load gravity rate threshold
    blt $t0, $t1, acg_done      # counter not yet at threshold, skip

    # Reset counter
    sw $zero, GRAVITY_COUNTER   # reset counter to 0

    # Check if column has landed before moving down
    jal check_landing           # $v0 = 1 if landed, 0 if falling
    bne $v0, 0, acg_land        # landed, lock it in

    # Safe to move down — erase, update, redraw
    jal erase_column            # paint black over current position
    lw $t0, COL_Y               # load current row
    addi $t0, $t0, 1            # move down one row
    sw $t0, COL_Y               # store updated row
    jal draw_column             # draw at new position
    j acg_done

acg_land:
    jal land_column             # lock gems into GRID, check matches, new column

acg_done:
    lw $ra, 0($sp)              # restore return address
    addi $sp, $sp, 4            # free stack space
    jr $ra

##############################################################################
# delete_matches
# Zeros out all cells marked in MATCH array from the GRID
# Also paints those cells black on the bitmap display
# Clobbers: $t0-$t6 (saves/restores $ra)

delete_matches:
    addi $sp, $sp, -4           # allocate stack space
    sw $ra, 0($sp)              # save return address

    li $t0, 0                   # $t0 = current row (0-14)

dm_row_loop:
    li $t1, 15                  # grid height
    beq $t0, $t1, dm_done       # all rows processed, exit

    li $t1, 0                   # $t1 = current col (0-5)

dm_col_loop:
    li $t2, 6                   # grid width
    beq $t1, $t2, dm_col_done   # all cols processed, next row

    # Compute flat index for this cell
    li $t2, 6
    mul $t3, $t0, $t2           # $t3 = row * 6
    add $t3, $t3, $t1           # $t3 += col (flat index)
    sll $t3, $t3, 2             # $t3 *= 4 (byte offset)

    # Check MATCH array at this index
    la $t4, MATCH
    add $t4, $t4, $t3           # $t4 = address in MATCH
    lw $t5, 0($t4)              # $t5 = match flag (0 or 1)
    beq $t5, 0, dm_next_col     # not marked, skip
    
    # Zero out this cell in GRID
    la $t4, GRID
    add $t4, $t4, $t3
    sw $zero, 0($t4)            # clear cell
    
    # Paint cell black on bitmap display
    addi $sp, $sp, -8
    sw $t0, 4($sp)              # save current row — grid_to_addr will clobber $t0
    sw $t1, 0($sp)              # save current col — grid_to_addr will clobber $t1
    move $a0, $t1               # $a0 = col
    move $a1, $t0               # $a1 = row
    jal grid_to_addr            # $v0 = bitmap address
    lw $t6, BLACK
    sw $t6, 0($v0)              # paint black
    lw $t1, 0($sp)              # restore col
    lw $t0, 4($sp)              # restore row
    addi $sp, $sp, 8

dm_next_col:
    addi $t1, $t1, 1            # next col
    j dm_col_loop

dm_col_done:
    addi $t0, $t0, 1            # next row
    j dm_row_loop

dm_done:
    lw $ra, 0($sp)              # restore return address
    addi $sp, $sp, 4            # free stack space
    jr $ra


##############################################################################
# apply_gravity
# For each column, collects all non-zero gems from top to bottom,
# then rewrites the column with gems packed to the bottom, zeroing the top
# Clobbers: $t0-$t9, $s0-$s2 (saves/restores $ra, $s registers)

apply_gravity:
    addi $sp, $sp, -16          # allocate stack space
    sw $ra, 0($sp)              # save return address
    sw $s0, 4($sp)              # save $s0 (current col)
    sw $s1, 8($sp)              # save $s1 (write row pointer)
    sw $s2, 12($sp)             # save $s2 (read row pointer)

    li $s0, 0                   # $s0 = current col (0-5)

ag_col_loop:
    li $t0, 6
    beq $s0, $t0, ag_done       # all cols processed

    # --- Pass 1: scan bottom to top, collect non-zero gems ---
    # We use a temporary buffer on the stack (15 words max)
    addi $sp, $sp, -60          # 15 * 4 bytes for temp buffer
    li $t1, 0                   # $t1 = buffer write index
    li $s2, 14                  # $s2 = read row (start from bottom)

ag_collect_loop:
    bltz $s2, ag_collect_done   # read row < 0, done collecting

    # Load GRID[row][col]
    li $t2, 6
    mul $t3, $s2, $t2           # row * 6
    add $t3, $t3, $s0           # + col
    sll $t3, $t3, 2             # * 4
    la $t4, GRID
    add $t4, $t4, $t3           # address of cell
    lw $t5, 0($t4)              # load colour ID

    beq $t5, 0, ag_skip_empty   # skip empty cells

    # Store gem in temp buffer
    sll $t6, $t1, 2             # buffer index * 4
    add $t6, $t6, $sp           # address in temp buffer
    sw $t5, 0($t6)              # store gem colour ID
    addi $t1, $t1, 1            # increment buffer count

ag_skip_empty:
    addi $s2, $s2, -1           # move read row up
    j ag_collect_loop

ag_collect_done:
    # $t1 = number of non-zero gems collected
    # --- Pass 2: rewrite column bottom to top ---
    li $s1, 14                  # $s1 = write row (start from bottom)
    li $t2, 0                   # $t2 = buffer read index

ag_write_loop:
    bltz $s1, ag_col_done       # write row < 0, done

    # Compute GRID address for write row
    li $t3, 6
    mul $t4, $s1, $t3           # row * 6
    add $t4, $t4, $s0           # + col
    sll $t4, $t4, 2             # * 4
    la $t5, GRID
    add $t5, $t5, $t4           # address of cell

    beq $t2, $t1, ag_write_zero # no more gems in buffer, write zero

    # Write gem from buffer
    sll $t6, $t2, 2             # buffer index * 4
    add $t6, $t6, $sp           # address in temp buffer
    lw $t7, 0($t6)              # load gem from buffer
    sw $t7, 0($t5)              # write gem into GRID
    addi $t2, $t2, 1            # next buffer entry
    j ag_next_write_row

ag_write_zero:
    sw $zero, 0($t5)            # write empty (0) into GRID

ag_next_write_row:
    addi $s1, $s1, -1           # move write row up
    j ag_write_loop

ag_col_done:
    addi $sp, $sp, 60           # free temp buffer
    addi $s0, $s0, 1            # next col
    j ag_col_loop

ag_done:
    lw $ra, 0($sp)              # restore return address
    lw $s0, 4($sp)              # restore $s0
    lw $s1, 8($sp)              # restore $s1
    lw $s2, 12($sp)             # restore $s2
    addi $sp, $sp, 16           # free stack space
    jr $ra


##############################################################################
# draw_grid_gems
# Redraws every cell in the GRID array onto the bitmap display
# Empty cells (0) are painted black, non-zero cells use their colour ID
# Clobbers: $t0-$t6 (saves/restores $ra)

draw_grid_gems:
    addi $sp, $sp, -4           # allocate stack space
    sw $ra, 0($sp)              # save return address

    li $t0, 0                   # $t0 = current row (0-14)

dg_row_loop:
    li $t1, 15                  # grid height
    beq $t0, $t1, dg_done       # all rows drawn, exit

    li $t1, 0                   # $t1 = current col (0-5)

dg_col_loop:
    li $t2, 6                   # grid width
    beq $t1, $t2, dg_col_done   # all cols drawn, next row
    
    # Load colour ID from GRID
    li $t2, 6
    mul $t3, $t0, $t2           # row * 6
    add $t3, $t3, $t1           # + col
    sll $t3, $t3, 2             # * 4
    la $t4, GRID
    add $t4, $t4, $t3           # address of cell
    lw $t5, 0($t4)              # $t5 = colour ID (0 = empty)
    
    # Get bitmap address for this cell
    addi $sp, $sp, -12
    sw $t0, 8($sp)              # save current row
    sw $t1, 4($sp)              # save current col
    sw $t5, 0($sp)              # save colour ID — grid_to_addr clobbers $t0-$t3
    move $a0, $t1               # $a0 = col
    move $a1, $t0               # $a1 = row
    jal grid_to_addr            # $v0 = bitmap address
    move $t6, $v0               # $t6 = bitmap address
    lw $t5, 0($sp)              # restore colour ID
    lw $t1, 4($sp)              # restore col
    lw $t0, 8($sp)              # restore row
    addi $sp, $sp, 12
    
    # Get RGB colour from ID
    addi $sp, $sp, -8
    sw $t0, 4($sp)              # save row — get_colour clobbers $t0
    sw $t1, 0($sp)              # save col — get_colour clobbers $t0 which may alias
    move $a0, $t5               # $a0 = colour ID
    jal get_colour              # $v0 = RGB
    lw $t1, 0($sp)              # restore col
    lw $t0, 4($sp)              # restore row
    addi $sp, $sp, 8
    sw $v0, 0($t6)              # paint pixel on bitmap

dg_next_col:
    addi $t1, $t1, 1            # next col
    j dg_col_loop

dg_col_done:
    addi $t0, $t0, 1            # next row
    j dg_row_loop

dg_done:
    lw $ra, 0($sp)              # restore return address
    addi $sp, $sp, 4            # free stack space
    jr $ra


##############################################################################
# check_game_over
# Checks if the 3 spawn cells at the top center are occupied in GRID
# Output: $v0 = 1 if game over, 0 if safe to spawn
# Clobbers: $t0-$t4

check_game_over:
    li $t0, 2                   # spawn col (center of 6-wide grid)
    li $t1, 6                   # grid width

    # Check row 0
    mul $t2, $zero, $t1         # row 0 * 6 = 0
    add $t2, $t2, $t0           # + col
    sll $t2, $t2, 2             # * 4
    la $t3, GRID
    add $t3, $t3, $t2
    lw $t4, 0($t3)              # load cell (row 0, col 2)
    bne $t4, 0, cgo_yes         # occupied, game over

    # Check row 1
    li $t2, 1
    mul $t2, $t2, $t1           # 1 * 6
    add $t2, $t2, $t0           # + col
    sll $t2, $t2, 2
    la $t3, GRID
    add $t3, $t3, $t2
    lw $t4, 0($t3)              # load cell (row 1, col 2)
    bne $t4, 0, cgo_yes         # occupied, game over

    # Check row 2
    li $t2, 2
    mul $t2, $t2, $t1           # 2 * 6
    add $t2, $t2, $t0           # + col
    sll $t2, $t2, 2
    la $t3, GRID
    add $t3, $t3, $t2
    lw $t4, 0($t3)              # load cell (row 2, col 2)
    bne $t4, 0, cgo_yes         # occupied, game over

    li $v0, 0                   # spawn area clear, safe to continue
    jr $ra

cgo_yes:
    li $v0, 1                   # spawn area blocked, game over
    jr $ra


##############################################################################
# check_matches
# Scans entire GRID for lines of 3+ same-colour gems in any direction.
# Marks matched cells in MATCH array.
# Output: $v0 = total number of cells marked (0 = no matches)
# Clobbers: $t0-$t9, $s0-$s5 (saves/restores $ra, $s registers)

check_matches:
    addi $sp, $sp, -32          # allocate stack space
    sw $ra, 0($sp)              # save return address
    sw $s0, 4($sp)              # save $s0 (current row)
    sw $s1, 8($sp)              # save $s1 (current col)
    sw $s2, 12($sp)             # save $s2 (current colour)
    sw $s3, 16($sp)             # save $s3 (match count)
    sw $s4, 20($sp)             # save $s4 (direction index)
    sw $s5, 24($sp)             # save $s5
    sw $s6, 28($sp)             # save $s6

    # --- Clear MATCH array before scanning ---
    la $t0, MATCH               # $t0 = base of MATCH array
    li $t1, 90                  # 90 cells total
    li $t2, 0                   # zero value
clear_match_loop:
    beq $t1, 0, clear_match_done  # all cells cleared
    sw $t2, 0($t0)              # zero this cell
    addi $t0, $t0, 4            # next cell
    addi $t1, $t1, -1           # decrement counter
    j clear_match_loop
clear_match_done:

    li $s3, 0                   # $s3 = total marked cells (return value)
    li $s0, 0                   # $s0 = current row (0-14)

cm_row_loop:
    li $t0, 15                  # grid height
    beq $s0, $t0, cm_done       # all rows scanned, exit

    li $s1, 0                   # $s1 = current col (0-5)

cm_col_loop:
    li $t0, 6                   # grid width
    beq $s1, $t0, cm_col_done   # all cols scanned, next row

    # --- Load colour of current cell ---
    li $t0, 6
    mul $t0, $s0, $t0           # $t0 = row * 6
    add $t0, $t0, $s1           # $t0 += col (flat index)
    sll $t0, $t0, 2             # $t0 *= 4 (byte offset)
    la $t1, GRID
    add $t1, $t1, $t0           # $t1 = address of current cell
    lw $s2, 0($t1)              # $s2 = colour ID of current cell
    beq $s2, 0, cm_next_col     # skip empty cells

    # --- Loop over 4 directions ---
    li $s4, 0                   # $s4 = direction index (0-3)

cm_dir_loop:
    li $t0, 4
    beq $s4, $t0, cm_next_col

    # Load direction and save permanently into $s5/$s6
    la $t0, DIRECTIONS
    sll $t1, $s4, 3             # direction * 8
    add $t0, $t0, $t1
    lw $s5, 0($t0)              # $s5 = dcol (never changes for this direction)
    lw $s6, 4($t0)              # $s6 = drow (never changes for this direction)

    # --- Count forward using $s5/$s6 directly ---
    li $t4, 1
    move $t5, $s1               # walking col
    move $t6, $s0               # walking row

cm_count_fwd:
    add $t5, $t5, $s5           # col += dcol
    add $t6, $t6, $s6           # row += drow
    bltz $t5, cm_count_bwd
    bltz $t6, cm_count_bwd
    li $t7, 6
    bge $t5, $t7, cm_count_bwd
    li $t7, 15
    bge $t6, $t7, cm_count_bwd
    li $t7, 6
    mul $t8, $t6, $t7
    add $t8, $t8, $t5
    sll $t8, $t8, 2
    la $t9, GRID
    add $t9, $t9, $t8
    lw $t9, 0($t9)
    bne $t9, $s2, cm_count_bwd
    addi $t4, $t4, 1
    j cm_count_fwd

    # --- Count backward using negated $s5/$s6 ---
cm_count_bwd:
    move $t5, $s1               # reset to current cell
    move $t6, $s0

cm_count_bwd_loop:
    sub $t5, $t5, $s5           # col -= dcol (subtract instead of negate)
    sub $t6, $t6, $s6           # row -= drow
    bltz $t5, cm_check_count
    bltz $t6, cm_check_count
    li $t7, 6
    bge $t5, $t7, cm_check_count
    li $t7, 15
    bge $t6, $t7, cm_check_count
    li $t7, 6
    mul $t8, $t6, $t7
    add $t8, $t8, $t5
    sll $t8, $t8, 2
    la $t9, GRID
    add $t9, $t9, $t8
    lw $t9, 0($t9)
    bne $t9, $s2, cm_check_count
    addi $t4, $t4, 1
    j cm_count_bwd_loop

cm_check_count:
    li $t7, 3
    blt $t4, $t7, cm_next_dir

    # --- Mark current cell ---
    move $t5, $s1               # reset to current cell
    move $t6, $s0
    li $t7, 6
    mul $t8, $t6, $t7
    add $t8, $t8, $t5
    sll $t8, $t8, 2
    la $t9, MATCH
    add $t9, $t9, $t8
    lw $t0, 0($t9)
    bne $t0, 0, cm_mark_fwd
    li $t0, 1
    sw $t0, 0($t9)
    addi $s3, $s3, 1

    # --- Mark forward using $s5/$s6 ---
cm_mark_fwd:
    add $t5, $t5, $s5           # col += dcol (clean, no negation)
    add $t6, $t6, $s6           # row += drow
    bltz $t5, cm_mark_bwd
    bltz $t6, cm_mark_bwd
    li $t7, 6
    bge $t5, $t7, cm_mark_bwd
    li $t7, 15
    bge $t6, $t7, cm_mark_bwd
    li $t7, 6
    mul $t8, $t6, $t7
    add $t8, $t8, $t5
    sll $t8, $t8, 2
    la $t9, GRID
    add $t9, $t9, $t8
    lw $t0, 0($t9)
    bne $t0, $s2, cm_mark_bwd
    li $t7, 6
    mul $t8, $t6, $t7
    add $t8, $t8, $t5
    sll $t8, $t8, 2
    la $t9, MATCH
    add $t9, $t9, $t8
    lw $t0, 0($t9)
    bne $t0, 0, cm_mark_fwd
    li $t0, 1
    sw $t0, 0($t9)
    addi $s3, $s3, 1
    j cm_mark_fwd

    # --- Mark backward using subtraction ---
cm_mark_bwd:
    move $t5, $s1               # reset to current cell
    move $t6, $s0

cm_mark_bwd_loop:
    sub $t5, $t5, $s5           # col -= dcol (subtract instead of negate)
    sub $t6, $t6, $s6           # row -= drow
    bltz $t5, cm_next_dir
    bltz $t6, cm_next_dir
    li $t7, 6
    bge $t5, $t7, cm_next_dir
    li $t7, 15
    bge $t6, $t7, cm_next_dir
    li $t7, 6
    mul $t8, $t6, $t7
    add $t8, $t8, $t5
    sll $t8, $t8, 2
    la $t9, GRID
    add $t9, $t9, $t8
    lw $t0, 0($t9)
    bne $t0, $s2, cm_next_dir
    li $t7, 6
    mul $t8, $t6, $t7
    add $t8, $t8, $t5
    sll $t8, $t8, 2
    la $t9, MATCH
    add $t9, $t9, $t8
    lw $t0, 0($t9)
    bne $t0, 0, cm_mark_bwd_loop
    li $t0, 1
    sw $t0, 0($t9)
    addi $s3, $s3, 1
    j cm_mark_bwd_loop

cm_next_dir:
    addi $s4, $s4, 1
    j cm_dir_loop

cm_next_col:
    addi $s1, $s1, 1            # next column
    j cm_col_loop

cm_col_done:
    addi $s0, $s0, 1            # next row
    j cm_row_loop

cm_done:
    move $v0, $s3               # return total marked cell count

    lw $ra, 0($sp)              # restore return address
    lw $s0, 4($sp)              # restore $s0
    lw $s1, 8($sp)              # restore $s1
    lw $s2, 12($sp)             # restore $s2
    lw $s3, 16($sp)             # restore $s3
    lw $s4, 20($sp)             # restore $s4
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    addi $sp, $sp, 32           # free stack space
    jr $ra

##############################################################################
# check_landing
# Checks if the column has landed on the floor or a gem below it
# Output: $v0 = 1 if landed, 0 if still falling
# Clobbers: $t0-$t4

check_landing:
    lw $t0, COL_Y               # load current row of top gem
    lw $t1, COL_X               # load current column

    # Check floor: is bottom gem (COL_Y + 2) at row 14?
    addi $t2, $t0, 2            # $t2 = row of bottom gem
    li $t3, 14                  # $t3 = last valid row index
    beq $t2, $t3, check_landing_yes  # if bottom gem at floor, landed

    # Check GRID cell directly below bottom gem (row COL_Y + 3)
    addi $t2, $t0, 3            # $t2 = row just below bottom gem
    li $t3, 6                   # $t3 = grid width
    mul $t2, $t2, $t3           # $t2 = row * 6 (row-major offset)
    add $t2, $t2, $t1           # $t2 += col (flat grid index)
    sll $t2, $t2, 2             # $t2 *= 4 (byte offset)
    la $t3, GRID                # $t3 = base address of GRID array
    add $t3, $t3, $t2           # $t3 = address of cell below bottom gem
    lw $t4, 0($t3)              # $t4 = value of that cell (0 = empty)
    bne $t4, 0, check_landing_yes    # if cell occupied, landed

    li $v0, 0                   # not landed, return 0
    jr $ra

check_landing_yes:
    li $v0, 1                   # landed, return 1
    jr $ra


##############################################################################
# land_column
# Writes the 3 gems of the current column into the GRID array,
# then checks for matches, and generates a new column.
# Clobbers: $t0-$t5, $a0, $a1, $v0 (saves/restores $ra)

land_column:
    addi $sp, $sp, -4           # allocate 1 word on stack
    sw $ra, 0($sp)              # save return address

    lw $t0, COL_X               # load current column index
    lw $t1, COL_Y               # load current row of top gem
    li $t2, 6                   # $t2 = grid width (6 cols)

    # --- Write gem 0 (top) into GRID at (COL_X, COL_Y) ---
    mul $t3, $t1, $t2           # $t3 = COL_Y * 6
    add $t3, $t3, $t0           # $t3 += COL_X (flat index)
    sll $t3, $t3, 2             # $t3 *= 4 (byte offset)
    la $t4, GRID                # $t4 = base of GRID
    add $t4, $t4, $t3           # $t4 = address of top gem cell
    lw $t5, COL_GEM0            # $t5 = colour ID of top gem
    sw $t5, 0($t4)              # write colour ID into GRID

    # --- Write gem 1 (middle) into GRID at (COL_X, COL_Y + 1) ---
    addi $t3, $t1, 1            # $t3 = COL_Y + 1
    mul $t3, $t3, $t2           # $t3 *= 6
    add $t3, $t3, $t0           # $t3 += COL_X
    sll $t3, $t3, 2             # $t3 *= 4
    la $t4, GRID                # reload GRID base
    add $t4, $t4, $t3           # $t4 = address of middle gem cell
    lw $t5, COL_GEM1            # $t5 = colour ID of middle gem
    sw $t5, 0($t4)              # write into GRID

    # --- Write gem 2 (bottom) into GRID at (COL_X, COL_Y + 2) ---
    addi $t3, $t1, 2            # $t3 = COL_Y + 2
    mul $t3, $t3, $t2           # $t3 *= 6
    add $t3, $t3, $t0           # $t3 += COL_X
    sll $t3, $t3, 2             # $t3 *= 4
    la $t4, GRID                # reload GRID base
    add $t4, $t4, $t3           # $t4 = address of bottom gem cell
    lw $t5, COL_GEM2            # $t5 = colour ID of bottom gem
    sw $t5, 0($t4)              # write into GRID

    # --- Match detection loop (handles chain reactions) ---
match_loop:
    jal check_matches           # scan grid, mark matches, return count in $v0
    beq $v0, 0, match_loop_done # if no matches found, exit loop

    jal delete_matches          # zero out all marked cells in GRID
    jal apply_gravity           # drop unsupported gems downward
    jal draw_grid_gems          # redraw entire grid onto bitmap
    j match_loop                # check again (chain reaction)

match_loop_done:
    # --- Check if new column can spawn before generating ---
    jal check_game_over         # returns 1 in $v0 if spawn area occupied
    bne $v0, 0, game_over       # if game over, branch away

    jal generate_column         # pick 3 new random gem colours
    jal draw_column             # draw new column at top center

    lw $ra, 0($sp)              # restore return address
    addi $sp, $sp, 4            # free stack space
    jr $ra

game_over:
    addi $sp, $sp, -4           # need stack since we jal
    sw $ra, 0($sp)
    jal game_over_screen        # show screen, wait for r/q
    addi $sp, $sp, 4
    lw $ra, 0($sp)
    jr $ra                      # if retry, return up to game_loop

##############################################################################
# check_keyboard
# Polls keyboard, dispatches to correct handler based on key pressed
# Clobbers: $t0-$t2

check_keyboard:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, ADDR_KBRD           # base keyboard address
    lw $t1, 0($t0)              # first word: 1 if key pressed
    bne $t1, 1, check_keyboard_done  # no key pressed, skip

    lw $t2, 4($t0)              # second word: ASCII value of key

    beq $t2, 0x61, handle_a    # 'a' = move left
    beq $t2, 0x64, handle_d    # 'd' = move right
    beq $t2, 0x77, handle_w    # 'w' = shuffle
    beq $t2, 0x73, handle_s    # 's' = drop
    beq $t2, 0x71, handle_q    # 'q' = quit

check_keyboard_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# check_left_blocked
# Checks if any of the 3 falling gems have a gem or wall to their left
# Output: $v0 = 1 if blocked, 0 if free
# Clobbers: $t0-$t4

check_left_blocked:
    lw $t0, COL_X               # load current col
    lw $t1, COL_Y               # load current top row

    # Check left wall first
    beq $t0, 0, clb_blocked     # col == 0, wall on left

    # Check GRID at (COL_X - 1, COL_Y)     — top gem
    addi $t2, $t0, -1           # col - 1
    li $t3, 6
    mul $t4, $t1, $t3           # row * 6
    add $t4, $t4, $t2           # + (col - 1)
    sll $t4, $t4, 2             # * 4
    la $t3, GRID
    add $t3, $t3, $t4
    lw $t4, 0($t3)              # load cell
    bne $t4, 0, clb_blocked     # occupied, blocked

    # Check GRID at (COL_X - 1, COL_Y + 1) — middle gem
    addi $t2, $t0, -1           # col - 1
    addi $t3, $t1, 1            # row + 1
    li $t4, 6
    mul $t3, $t3, $t4           # row * 6
    add $t3, $t3, $t2           # + (col - 1)
    sll $t3, $t3, 2             # * 4
    la $t4, GRID
    add $t4, $t4, $t3
    lw $t4, 0($t4)              # load cell
    bne $t4, 0, clb_blocked     # occupied, blocked

    # Check GRID at (COL_X - 1, COL_Y + 2) — bottom gem
    addi $t2, $t0, -1           # col - 1
    addi $t3, $t1, 2            # row + 2
    li $t4, 6
    mul $t3, $t3, $t4           # row * 6
    add $t3, $t3, $t2           # + (col - 1)
    sll $t3, $t3, 2             # * 4
    la $t4, GRID
    add $t4, $t4, $t3
    lw $t4, 0($t4)              # load cell
    bne $t4, 0, clb_blocked     # occupied, blocked

    li $v0, 0                   # nothing blocking left, free
    jr $ra

clb_blocked:
    li $v0, 1                   # blocked
    jr $ra


##############################################################################
# check_right_blocked
# Checks if any of the 3 falling gems have a gem or wall to their right
# Output: $v0 = 1 if blocked, 0 if free
# Clobbers: $t0-$t4

check_right_blocked:
    lw $t0, COL_X               # load current col
    lw $t1, COL_Y               # load current top row

    # Check right wall first
    li $t2, 5                   # rightmost col index
    beq $t0, $t2, crb_blocked   # col == 5, wall on right

    # Check GRID at (COL_X + 1, COL_Y)     — top gem
    addi $t2, $t0, 1            # col + 1
    li $t3, 6
    mul $t4, $t1, $t3           # row * 6
    add $t4, $t4, $t2           # + (col + 1)
    sll $t4, $t4, 2             # * 4
    la $t3, GRID
    add $t3, $t3, $t4
    lw $t4, 0($t3)              # load cell
    bne $t4, 0, crb_blocked     # occupied, blocked

    # Check GRID at (COL_X + 1, COL_Y + 1) — middle gem
    addi $t2, $t0, 1            # col + 1
    addi $t3, $t1, 1            # row + 1
    li $t4, 6
    mul $t3, $t3, $t4           # row * 6
    add $t3, $t3, $t2           # + (col + 1)
    sll $t3, $t3, 2             # * 4
    la $t4, GRID
    add $t4, $t4, $t3
    lw $t4, 0($t4)              # load cell
    bne $t4, 0, crb_blocked     # occupied, blocked

    # Check GRID at (COL_X + 1, COL_Y + 2) — bottom gem
    addi $t2, $t0, 1            # col + 1
    addi $t3, $t1, 2            # row + 2
    li $t4, 6
    mul $t3, $t3, $t4           # row * 6
    add $t3, $t3, $t2           # + (col + 1)
    sll $t3, $t3, 2             # * 4
    la $t4, GRID
    add $t4, $t4, $t3
    lw $t4, 0($t4)              # load cell
    bne $t4, 0, crb_blocked     # occupied, blocked

    li $v0, 0                   # nothing blocking right, free
    jr $ra

crb_blocked:
    li $v0, 1                   # blocked
    jr $ra


##############################################################################
# handle_a — move column left
# Checks left wall collision before moving

handle_a:
    addi $sp, $sp, -4
    sw $ra, 0($sp)             # save $ra — we're about to jal inside

    jal check_left_blocked      # $v0 = 1 if wall or gem to the left
    bne $v0, 0, handle_a_done   # blocked, skip move

    jal erase_column           # erase at current position
    lw $t0, COL_X
    addi $t0, $t0, -1
    sw $t0, COL_X              # update col
    jal draw_column            # draw at new position

handle_a_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j check_keyboard_done
    
##############################################################################
# handle_d — move column right
# Checks right wall collision before moving

handle_d:
    addi $sp, $sp, -4
    sw $ra, 0($sp)             # save $ra — we're about to jal inside

    jal check_right_blocked     # $v0 = 1 if wall or gem to the right
    bne $v0, 0, handle_d_done   # blocked, skip move

    jal erase_column
    lw $t0, COL_X
    addi $t0, $t0, 1
    sw $t0, COL_X
    jal draw_column

handle_d_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j check_keyboard_done
##############################################################################
# handle_w — shuffle gem colours downward
# gem0 → gem1 → gem2 → gem0 (bottom wraps to top)

handle_w:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, COL_GEM0
    lw $t1, COL_GEM1
    lw $t2, COL_GEM2

    # shift down: new gem0=gem2, new gem1=gem0, new gem2=gem1
    sw $t2, COL_GEM0
    sw $t0, COL_GEM1
    sw $t1, COL_GEM2

    jal erase_column
    jal draw_column

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j check_keyboard_done

##############################################################################
# handle_s — instant drop to bottom
# Repeatedly moves down until collision with bottom wall or landed gem

handle_s:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

handle_s_loop:
    # Check if bottom gem (COL_Y + 2) is at row 14 (bottom of grid)
    lw $t0, COL_Y
    addi $t0, $t0, 2            # row of bottom gem
    li $t1, 14                  # last valid row
    beq $t0, $t1, handle_s_done # at bottom, stop

    # Check if cell directly below bottom gem is occupied in GRID
    lw $t0, COL_Y
    addi $t0, $t0, 3            # row below bottom gem
    lw $t1, COL_X
    li $t2, 6
    mul $t0, $t0, $t2           # row * 6
    add $t0, $t0, $t1           # + col
    sll $t0, $t0, 2             # * 4 = byte offset
    la $t1, GRID
    add $t0, $t1, $t0
    lw $t0, 0($t0)              # load cell value
    bne $t0, 0, handle_s_done   # cell occupied, stop

    # Safe to move down
    jal erase_column
    lw $t0, COL_Y
    addi $t0, $t0, 1
    sw $t0, COL_Y
    j handle_s_loop

handle_s_done:
    jal draw_column
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j check_keyboard_done

##############################################################################
# handle_q — quit

handle_q:
    li $v0, 10
    syscall

##############################################################################
# get_colour
# Input:  $a0 = colour ID (0-6)
# Output: $v0 = RGB colour word
# Clobbers: $t0

get_colour:
    la $t0, COLOUR_TABLE        # base of table
    sll $v0, $a0, 2             # ID * 4 (byte offset)
    add $t0, $t0, $v0           # address of entry
    lw $v0, 0($t0)              # load colour
    jr $ra


##############################################################################
# grid_to_addr
# Converts a grid (col, row) to a bitmap display memory address
# Input:  $a0 = grid col (0-5)
#         $a1 = grid row (0-14)
# Output: $v0 = memory address of that cell
# Clobbers: $t0-$t3

grid_to_addr:
    lw $t0, ADDR_DSPL
    lw $t1, GRID_ORIGIN_X       # = 2
    lw $t2, GRID_ORIGIN_Y       # = 3

    add $t1, $t1, $a0           # bitmap_col = origin_x + grid_col
    add $t2, $t2, $a1           # bitmap_row = origin_y + grid_row

    li $t3, 32                  # display width in units
    mul $t2, $t2, $t3           # bitmap_row * 32
    add $t1, $t1, $t2           # + bitmap_col = flat index
    sll $t1, $t1, 2             # * 4 = byte offset
    add $v0, $t0, $t1           # display_base + offset
    jr $ra

##############################################################################
# generate_column
# Picks 3 random colour IDs (1-6), writes to COL_GEM0/1/2
# Resets COL_X to center (2), COL_Y to 0
# Clobbers: $t0, $a0, $a1, $v0 (saves/restores $ra)

generate_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Reset position to top-center
    li $t0, 2
    sw $t0, COL_X
    sw $zero, COL_Y

    # Generate gem 0
    li $v0, 42                  # syscall 42 = "random int with upper bound"
    li $a0, 0                   # RNG generator ID 
    li $a1, 6                   # upper bound (exclusive), so result is 0-5
    syscall                     # after this, $a0 = random number 0-5
    addi $a0, $a0, 1            # shift to 1-6 (dont want 0 = black)
    sw $a0, COL_GEM0

    # Generate gem 1
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    sw $a0, COL_GEM1

    # Generate gem 2
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    sw $a0, COL_GEM2

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# draw_column
# Draws the 3 gems of the current falling column onto the bitmap display
# Clobbers: $t0-$t4, $a0, $a1, $v0 (saves/restores $ra)

draw_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)              # save return address — use jal inside

    # Gem 0 (top gem, at row COL_Y)
    lw $a0, COL_X              # $a0 = grid col — arg 1 for grid_to_addr
    lw $a1, COL_Y              # $a1 = grid row — arg 2 for grid_to_addr
    jal grid_to_addr           # $v0 = display memory address of this cell
    move $t2, $v0              # save address before get_colour overwrites $v0

    lw $a0, COL_GEM0           # $a0 = colour ID of top gem (1-6)
    jal get_colour             # $v0 = RGB colour word for that ID
    sw $v0, 0($t2)             # write colour to the display address we saved

    # Gem 1 (middle gem, at row COL_Y + 1)
    lw $a0, COL_X              # reload col — $t registers were clobbered above
    lw $a1, COL_Y              # reload base row
    addi $a1, $a1, 1           # shift down 1 row for middle gem
    jal grid_to_addr
    move $t2, $v0

    lw $a0, COL_GEM1
    jal get_colour
    sw $v0, 0($t2)

    # Gem 2 (bottom gem, at row COL_Y + 2)
    lw $a0, COL_X              # reload again for same reason
    lw $a1, COL_Y
    addi $a1, $a1, 2           # shift down 2 rows for bottom gem
    jal grid_to_addr
    move $t2, $v0

    lw $a0, COL_GEM2
    jal get_colour
    sw $v0, 0($t2)

    lw $ra, 0($sp)              # restore return address
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# erase_column
# Paints black over the 3 cells the current column occupies
# Clobbers: same as draw_column

erase_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Gem 0 — erase at (COL_X, COL_Y)
    lw $a0, COL_X
    lw $a1, COL_Y
    jal grid_to_addr            # $t0-$t3 clobbered here, so reload each time
    lw $t4, BLACK
    sw $t4, 0($v0)

    # Gem 1 — erase at (COL_X, COL_Y + 1)
    lw $a0, COL_X              # reload — grid_to_addr clobbered $t0
    lw $a1, COL_Y              # reload — grid_to_addr clobbered $t1
    addi $a1, $a1, 1
    jal grid_to_addr
    lw $t4, BLACK
    sw $t4, 0($v0)

    # Gem 2 — erase at (COL_X, COL_Y + 2)
    lw $a0, COL_X
    lw $a1, COL_Y
    addi $a1, $a1, 2
    jal grid_to_addr
    lw $t4, BLACK
    sw $t4, 0($v0)

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

### GRID DRAWING CODE
# draw_grid: Draw a white border around the game area
# Arguments:
#   $a0 = start X position (in grid units, e.g. 2)
#   $a1 = start Y position (in grid units, e.g. 3)
# Grid is 8 units wide (6 cells + 2 border) and 17 units tall (15 cells + 2 border)
# Registers used: $t0-$t9
draw_grid:
    lw $t0, ADDR_DSPL           # $t0 = base address of display
    lw $t1, WHITE               # $t1 = white color
    lw $t2, DISPLAY_WIDTH       # $t2 = display width in units (32)

    # Compute bytes per row: 32 units * 4 bytes = 128
    mul $t3, $t2, 4             # $t3 = bytes per row (128)

    # Convert start positions to byte offsets
    mul $t4, $a0, 4             # $t4 = x_start byte offset (e.g. 2*4 = 8)
    mul $t5, $a1, $t3           # $t5 = y_start byte offset (e.g. 3*128 = 384)

    # Compute end positions
    # Box is 8 units wide (6 game cols + left + right border), 17 units tall
    addi $t6, $t4, 28           # $t6 = x_end byte offset = x_start + (7 units * 4 bytes)
    addi $s0, $a1, 16           # $s0 = y_end row = y_start + 16 rows
    mul $t7, $s0, $t3           # $t7 = y_end byte offset

    # --- Draw Top Border (left to right at y_start) ---
    move $t8, $t4               # $t8 = current x
draw_top_border:
    bgt $t8, $t6, draw_top_border_end
    add $t9, $t0, $t5           # $t9 = base + y_offset
    add $t9, $t9, $t8           # $t9 += x_offset
    sw $t1, 0($t9)
    addi $t8, $t8, 4
    j draw_top_border
draw_top_border_end:

    # --- Draw Bottom Border (left to right at y_end) ---
    move $t8, $t4               # reset x to x_start
draw_bottom_border:
    bgt $t8, $t6, draw_bottom_border_end
    add $t9, $t0, $t7           # $t9 = base + y_end_offset
    add $t9, $t9, $t8
    sw $t1, 0($t9)
    addi $t8, $t8, 4
    j draw_bottom_border
draw_bottom_border_end:

    # --- Draw Left Border (top to bottom at x_start) ---
    move $t8, $t5               # $t8 = current y offset
draw_left_border:
    bgt $t8, $t7, draw_left_border_end
    add $t9, $t0, $t8           # $t9 = base + y_offset
    add $t9, $t9, $t4           # $t9 += x_start
    sw $t1, 0($t9)
    add $t8, $t8, $t3           # next row
    j draw_left_border
draw_left_border_end:

    # --- Draw Right Border (top to bottom at x_end) ---
    move $t8, $t5               # reset y to y_start
draw_right_border:
    bgt $t8, $t7, draw_right_border_end
    add $t9, $t0, $t8           # $t9 = base + y_offset
    add $t9, $t9, $t6           # $t9 += x_end
    sw $t1, 0($t9)
    add $t8, $t8, $t3           # next row
    j draw_right_border
draw_right_border_end:

    jr $ra
