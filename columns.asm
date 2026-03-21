################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
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

##############################################################################
# Mutable Data
##############################################################################
# Grid to store gem colors (6 * 15 = 90 cells * 4 bytes = 360 bytes)
GRID:       .space 360

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    li $a0, 1       # Start X = 2 units from left
    li $a1, 2       # Start Y = 3 units from top
    jal draw_grid

    # Exit program
    li $v0, 10
    syscall

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop



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
