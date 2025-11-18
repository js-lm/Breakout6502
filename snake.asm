;  ___           _        __ ___  __ ___
; / __|_ _  __ _| |_____ / /| __|/  \_  )
; \__ \ ' \/ _` | / / -_) _ \__ \ () / /
; |___/_||_\__,_|_\_\___\___/___/\__/___|

; Snake game modified from the example by Nick Morgan.
; The grid size is now 2x2, and you can warp around the walls.

; Original code can be found here: http://skilldrick.github.io/easy6502/

; Change direction: W A S D

define appleL         $00 ; screen location of apple, low byte
define appleH         $01 ; screen location of apple, high byte
define snakeHeadL     $10 ; screen location of snake head, low byte
define snakeHeadH     $11 ; screen location of snake head, high byte
define snakeBodyStart $12 ; start of snake body byte pairs
define snakeDirection $02 ; direction (possible values are below)
define snakeLength    $03 ; snake length, in bytes

; Directions (each using a separate bit)
define movingUp      1
define movingRight   2
define movingDown    4
define movingLeft    8

; ASCII values of keys controlling the snake
define ASCII_w      $77
define ASCII_a      $61
define ASCII_s      $73
define ASCII_d      $64

; System variables
define sysRandom    $fe
define sysLastKey   $ff

define colorSnakeHead $01
define colorApple     $02
define colorEmpty     $00

define temp0          $04
define temp1          $05
define drawPtrL       $06
define drawPtrH       $07


  jsr init
  jsr loop

init:
  jsr initSnake
  jsr generateApplePosition
  rts


initSnake:
  lda #movingRight  ;start direction
  sta snakeDirection

  lda #4  ;start length (2 segments)
  sta snakeLength
  
  lda #$10
  sta snakeHeadL
  
  lda #$0e
  sta snakeBodyStart
  
  lda #$0c
  sta $14 ; body segment 1
  
  lda #$04
  sta snakeHeadH
  sta $13 ; body segment 1
  sta $15 ; body segment 2
  rts


generateApplePosition:
  lda #$00
  sta appleL
  lda #$02
  sta appleH

  ; pick random even column (0-30)
  lda sysRandom
  and #$0f
  asl
  sta temp0
  clc
  lda appleL
  adc temp0
  sta appleL

  ; pick random even row (0-30)
  lda sysRandom
  and #$0f
  sta temp1

  lda temp1
  and #$03
  sta temp0
  lda temp0
  asl
  asl
  asl
  asl
  asl
  asl
  clc
  adc appleL
  sta appleL

  lda temp1
  lsr
  lsr
  sta temp0
  lda appleH
  clc
  adc temp0
  sta appleH

  rts


loop:
  jsr readKeys
  jsr checkCollision
  jsr updateSnake
  jsr drawApple
  jsr drawSnake
  jsr spinWheels
  jmp loop


readKeys:
  lda sysLastKey
  cmp #ASCII_w
  beq upKey
  cmp #ASCII_d
  beq rightKey
  cmp #ASCII_s
  beq downKey
  cmp #ASCII_a
  beq leftKey
  rts
upKey:
  lda #movingDown
  bit snakeDirection
  bne illegalMove

  lda #movingUp
  sta snakeDirection
  rts
rightKey:
  lda #movingLeft
  bit snakeDirection
  bne illegalMove

  lda #movingRight
  sta snakeDirection
  rts
downKey:
  lda #movingUp
  bit snakeDirection
  bne illegalMove

  lda #movingDown
  sta snakeDirection
  rts
leftKey:
  lda #movingRight
  bit snakeDirection
  bne illegalMove

  lda #movingLeft
  sta snakeDirection
  rts
illegalMove:
  rts


checkCollision:
  jsr checkAppleCollision
  jsr checkSnakeCollision
  rts


checkAppleCollision:
  lda appleL
  cmp snakeHeadL
  bne doneCheckingAppleCollision
  lda appleH
  cmp snakeHeadH
  bne doneCheckingAppleCollision

  ;eat apple
  inc snakeLength
  inc snakeLength ;increase length
  jsr generateApplePosition
doneCheckingAppleCollision:
  rts


checkSnakeCollision:
  ldx #2 ;start with second segment
snakeCollisionLoop:
  lda snakeHeadL,x
  cmp snakeHeadL
  bne continueCollisionLoop

maybeCollided:
  lda snakeHeadH,x
  cmp snakeHeadH
  beq didCollide

continueCollisionLoop:
  inx
  inx
  cpx snakeLength          ;got to last section with no collision
  beq didntCollide
  jmp snakeCollisionLoop

didCollide:
  jmp gameOver
didntCollide:
  rts


updateSnake:
  ldx snakeLength
  dex
  txa
updateloop:
  lda snakeHeadL,x
  sta snakeBodyStart,x
  dex
  bpl updateloop

  lda snakeDirection
  lsr
  bcs up
  lsr
  bcs right
  lsr
  bcs down
  lsr
  bcs left
up:
  lda snakeHeadL
  sec
  sbc #$40
  sta snakeHeadL
  lda snakeHeadH
  sbc #$00
  sta snakeHeadH
  bcs updone
  lda snakeHeadH
  clc
  adc #$04
  sta snakeHeadH
updone:
  rts
right:
  lda snakeHeadL
  and #$e0
  sta temp1
  lda snakeHeadL
  and #$1f
  sta temp0
  lda temp0
  clc
  adc #$02
  cmp #$20
  bcc rightstore
  lda #$00
rightstore:
  sta temp0
  lda temp1
  ora temp0
  sta snakeHeadL
  rts
down:
  lda snakeHeadL
  clc
  adc #$40
  sta snakeHeadL
  lda snakeHeadH
  adc #$00
  sta snakeHeadH
  cmp #$06
  bcc downdone
  sec
  sbc #$04
  sta snakeHeadH
downdone:
  rts
left:
  lda snakeHeadL
  and #$e0
  sta temp1
  lda snakeHeadL
  and #$1f
  sta temp0
  lda temp0
  sec
  sbc #$02
  bcs leftstore
  lda #$1e
leftstore:
  sta temp0
  lda temp1
  ora temp0
  sta snakeHeadL
  rts


drawApple:
  lda appleL
  sta drawPtrL
  lda appleH
  sta drawPtrH
  lda #colorApple
  jsr fillBlockColor
  rts


drawSnake:
  ldx snakeLength
  lda snakeHeadL,x
  sta drawPtrL
  lda snakeHeadH,x
  sta drawPtrH
  lda #colorEmpty
  jsr fillBlockColor

  ldx #0
  lda snakeHeadL,x
  sta drawPtrL
  lda snakeHeadH,x
  sta drawPtrH
  lda #colorSnakeHead
  jsr fillBlockColor
  rts

fillBlockColor:
  ldy #0
  sta (drawPtrL),y
  iny
  sta (drawPtrL),y
  ldy #$20
  sta (drawPtrL),y
  iny
  sta (drawPtrL),y
  rts


spinWheels:
  ldx #0
spinloop:
  nop
  nop
  dex
  bne spinloop
  rts


gameOver:
