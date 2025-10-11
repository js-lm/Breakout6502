;  ____                 _               _     __ _____  ___ ___  
; |  _ \               | |             | |   / /| ____|/ _ \__ \ 
; | |_) |_ __ ___  __ _| | _____  _   _| |_ / /_| |__ | | | | ) |
; |  _ <| '__/ _ \/ _` | |/ / _ \| | | | __| '_ \___ \| | | |/ / 
; | |_) | | |  __/ (_| |   < (_) | |_| | |_| (_) |__) | |_| / /_ 
; |____/|_|  \___|\__,_|_|\_\___/ \__,_|\__|\___/____/ \___/____|
;                                           Created by Joshua Lam
;                           https://github.com/js-lm/Breakout6502
;
; Controls: A (left) D (right)

define paddleX        $20
define paddleY        $21
define ballX          $22
define ballY          $23
define ballDX         $24 ; ball direction X (1 or $ff)
define ballDY         $25 ; ball direction Y (1 or $ff)

define ASCII_a        $61
define ASCII_d        $64
define systemLastKey  $ff

  jsr init
  jsr loop

init:
  ; initialize paddle at bottom center
  lda #$0d
  sta paddleX
  lda #$1c
  sta paddleY
  
  ; initialize ball just above paddle
  lda #$0f
  sta ballX
  lda #$1b
  sta ballY
  
  ; ball starts moving up right
  lda #$01
  sta ballDX
  lda #$ff
  sta ballDY
  
  ; draw initial bricks (3 rows)
  jsr drawBricks
  
  rts

drawBricks:
  ; row 1 at Y=2 (address $0240)
  ldx #$00
row1Loop:
  lda #$02
  sta $0240,x
  inx
  inx
  cpx #$20
  bne row1Loop
  
  ; row 2 at Y=4 (address $0280)
  ldx #$00
row2Loop:
  lda #$04
  sta $0280,x
  inx
  inx
  cpx #$20
  bne row2Loop
  
  ; row 3 at Y=6 (address $02c0)
  ldx #$00
row3Loop:
  lda #$06
  sta $02c0,x
  inx
  inx
  cpx #$20
  bne row3Loop
  
  rts

loop:
  jsr readKeys
  jsr eraseBall
  jsr erasePaddle
  jsr moveBall
  jsr checkCollisions
  jsr drawPaddle
  jsr drawBall
  jsr delay
  jmp loop

readKeys:
  lda systemLastKey
  cmp #ASCII_a
  beq moveLeft
  cmp #ASCII_d
  beq moveRight
  rts

moveLeft:
  lda paddleX
  cmp #$01
  beq doneMove
  dec paddleX
  rts

moveRight:
  lda paddleX
  cmp #$1a
  beq doneMove
  inc paddleX
  rts

doneMove:
  rts

erasePaddle:
  ; erase entire bottom row
  ldx #$00
  lda #$00
erasePaddleLoop:
  sta $0580,x
  inx
  cpx #$20
  bne erasePaddleLoop
  rts

eraseBall:
  ; calculate which page ball is in and erase
  lda ballY
  cmp #$08
  bcc erasePage2
  cmp #$10
  bcc erasePage3
  cmp #$18
  bcc erasePage4
  jmp erasePage5

erasePage2:
  lda ballY
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$00
  sta $0200,x
  rts

erasePage3:
  lda ballY
  sec
  sbc #$08
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$00
  sta $0300,x
  rts

erasePage4:
  lda ballY
  sec
  sbc #$10
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$00
  sta $0400,x
  rts

erasePage5:
  lda ballY
  sec
  sbc #$18
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$00
  sta $0500,x
  rts

checkCollisions:
  ; check paddle collision (paddle at Y=$1c)
  lda ballY
  cmp #$1c
  bne checkBricks
  
  ; check if ball X is on paddle
  lda ballX
  sec
  sbc paddleX
  bmi checkBricks
  cmp #$05
  bcs checkBricks
  
  ; check if moving down (ballDY = $01)
  lda ballDY
  cmp #$01
  bne checkBricks
  
  ; hit paddle - bounce up
  lda #$ff
  sta ballDY

checkBricks:
  ; check if ball Y is exactly at brick rows
  lda ballY
  cmp #$02
  beq checkRow1
  cmp #$04
  beq checkRow2
  cmp #$06
  beq checkRow3
  rts

checkRow1:
  ldx ballX
  lda $0240,x
  beq doneCheckBricks
  
  ; brick exists, erase it
  lda #$00
  sta $0240,x
  
  ; reverse ball direction
  lda ballDY
  eor #$ff
  clc
  adc #$01
  sta ballDY
  rts

checkRow2:
  ldx ballX
  lda $0280,x
  beq doneCheckBricks
  
  ; brick exists, erase it
  lda #$00
  sta $0280,x
  
  ; reverse ball direction
  lda ballDY
  eor #$ff
  clc
  adc #$01
  sta ballDY
  rts

checkRow3:
  ldx ballX
  lda $02c0,x
  beq doneCheckBricks
  
  ; brick exists, erase it
  lda #$00
  sta $02c0,x
  
  ; reverse ball direction
  lda ballDY
  eor #$ff
  clc
  adc #$01
  sta ballDY

doneCheckBricks:
  rts

moveBall:
  ; move ball X
  lda ballDX
  bmi moveBallLeft
moveBallRight:
  inc ballX
  lda ballX
  cmp #$1f
  bne moveBallYAxis
  lda #$ff
  sta ballDX
  jmp moveBallYAxis

moveBallLeft:
  dec ballX
  lda ballX
  bne moveBallYAxis
  lda #$01
  sta ballDX

moveBallYAxis:
  ; move ball Y
  lda ballDY
  bmi moveBallUp
moveBallDown:
  inc ballY
  lda ballY
  cmp #$1e
  bne doneBallMove
  ; game over
  jmp init

moveBallUp:
  dec ballY
  lda ballY
  bne doneBallMove
  lda #$01
  sta ballDY

doneBallMove:
  rts

drawPaddle:
  ; draw paddle at Y=$1c (address $0580)
  ldx paddleX
  lda #$0f
  sta $0580,x
  inx
  sta $0580,x
  inx
  sta $0580,x
  inx
  sta $0580,x
  inx
  sta $0580,x
  rts

drawBall:
  ; calculate ball address and draw
  lda ballY
  cmp #$08
  bcc drawPage2
  cmp #$10
  bcc drawPage3
  cmp #$18
  bcc drawPage4
  jmp drawPage5

drawPage2:
  lda ballY
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$01
  sta $0200,x
  rts

drawPage3:
  lda ballY
  sec
  sbc #$08
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$01
  sta $0300,x
  rts

drawPage4:
  lda ballY
  sec
  sbc #$10
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$01
  sta $0400,x
  rts

drawPage5:
  lda ballY
  sec
  sbc #$18
  asl
  asl
  asl
  asl
  asl
  clc
  adc ballX
  tax
  lda #$01
  sta $0500,x
  rts

delay:
  ldx #$03
delayOuter:
  ldy #$00
delayInner:
  nop
  nop
  dey
  bne delayInner
  dex
  bne delayOuter
  rts