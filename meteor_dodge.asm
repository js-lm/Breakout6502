; ▗▖  ▗▖▗▄▄▄▖▗▄▄▄▖▗▄▄▄▖ ▗▄▖ ▗▄▄▖     ▗▄▄▄  ▗▄▖ ▗▄▄▄  ▗▄▄▖▗▄▄▄▖
; ▐▛▚▞▜▌▐▌     █  ▐▌   ▐▌ ▐▌▐▌ ▐▌    ▐▌  █▐▌ ▐▌▐▌  █▐▌   ▐▌   
; ▐▌  ▐▌▐▛▀▀▘  █  ▐▛▀▀▘▐▌ ▐▌▐▛▀▚▖    ▐▌  █▐▌ ▐▌▐▌  █▐▌▝▜▌▐▛▀▀▘
; ▐▌  ▐▌▐▙▄▄▖  █  ▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▐▙▄▄▀▝▚▄▞▘▐▙▄▄▀▝▚▄▞▘▐▙▄▄▖
;                                        Created by Joshua Lam
;                 https://github.com/js-lm/6502-assembly-games
;
; Controls: WASD

; Zero page layout

define playerTopL       $00
define playerTopH       $01
define playerBottomL    $02
define playerBottomH    $03
define playerCol        $04
define playerRow        $05

define obstacleLowBase  $10   ; low bytes for obstacle pointers
define obstacleHighBase $11   ; high bytes for obstacle pointers
define obstacleDelayBase $20  ; frame delay before meteor activates
define obstacleStepBase $30   ; per-meteor pointer delta (down vs diagonals)

define obstacleCount    $0c   ; 12 meteors tracked in the tables
define obstacleBytes    $18   ; obstacleCount * 2

; Constants

define playerColor      $0f
define obstacleColor    $05

define sysRandom        $fe
define sysLastKey       $ff

define ASCII_a          $61
define ASCII_d          $64
define ASCII_w          $77
define ASCII_s          $73

  jsr init
mainloop:
  jsr erasePlayer
  jsr eraseObstacles
  jsr readKeys
  jsr moveObstacles
  jsr checkCollisions
  jsr drawPlayer
  jsr drawObstacles
  jsr delay
  jmp mainloop

init:
  jsr clearScreen
  jsr initPlayer
  jsr initObstacles
  rts

initPlayer:
  lda #$6f        ; top pixel near center bottom
  sta playerTopL
  lda #$05
  sta playerTopH
  lda #$0f        ; column index
  sta playerCol
  lda #$1b        ; row index for top pixel
  sta playerRow
  jsr updatePlayerBottom
  rts

updatePlayerBottom:
  lda playerTopL
  clc
  adc #$20
  sta playerBottomL
  lda playerTopH
  adc #$00
  sta playerBottomH
  rts

initObstacles:
  ldx #$00
initObstacleLoop:
  jsr spawnObstacle
  inx
  inx
  cpx #obstacleBytes
  bne initObstacleLoop
  rts

spawnObstacle:
  lda #$02                ; always start at the top row ($0200)
  sta obstacleHighBase,x
  lda sysRandom
  and #$03
  tay
  lda #$20                ; default straight down
  cpy #$01
  beq setDownRight
  cpy #$02
  beq setDownLeft
  cpy #$03
  beq setDownRight        ; reuse extra value for more diagonals
storeStep:
  sta obstacleStepBase,x
  jmp chooseColumn
setDownRight:
  lda #$21
  bne storeStep
setDownLeft:
  lda #$1f
  bne storeStep
chooseColumn:
  cpy #$01                ; diagonal right?
  bne maybeLeftStart
  lda sysRandom
  and #$1e                ; limit to cols 0-30 to avoid wrapping past edge
  sta obstacleLowBase,x
  jmp storeDelay
maybeLeftStart:
  cpy #$02
  bne straightStart
  lda sysRandom
  and #$1e
  ora #$01                ; ensure column >= 1 for left movers
  sta obstacleLowBase,x
  jmp storeDelay
straightStart:
  lda sysRandom
  and #$1f
  sta obstacleLowBase,x
storeDelay:
  lda sysRandom
  and #$0f                ; random entry delay (0-15 frames)
  sta obstacleDelayBase,x
  rts

erasePlayer:
  lda #$00
  ldy #$00
  sta (playerTopL),y
  sta (playerBottomL),y
  rts

drawPlayer:
  lda #playerColor
  ldy #$00
  sta (playerTopL),y
  sta (playerBottomL),y
  rts

eraseObstacles:
  ldx #$00
eraseObstacleLoop:
  lda obstacleDelayBase,x
  bne skipErase           ; not active yet
  lda obstacleHighBase,x
  cmp #$06
  bcs skipErase           ; already off-screen / respawning
  lda #$00
  sta (obstacleLowBase,x)
skipErase:
  inx
  inx
  cpx #obstacleBytes
  bne eraseObstacleLoop
  rts

drawObstacles:
  ldx #$00
drawObstacleLoop:
  lda obstacleDelayBase,x
  bne skipDraw
  lda obstacleHighBase,x
  cmp #$06
  bcs skipDraw
  lda #obstacleColor
  sta (obstacleLowBase,x)
skipDraw:
  inx
  inx
  cpx #obstacleBytes
  bne drawObstacleLoop
  rts

readKeys:
  lda sysLastKey
  cmp #ASCII_w
  beq moveUp
  cmp #ASCII_s
  beq moveDown
  cmp #ASCII_a
  beq moveLeft
  cmp #ASCII_d
  beq moveRight
  rts

moveLeft:
  lda playerCol
  beq doneMove
  dec playerCol
  lda playerTopL
  bne leftNoBorrow
  dec playerTopH
leftNoBorrow:
  dec playerTopL
  jsr updatePlayerBottom
  rts

moveRight:
  lda playerCol
  cmp #$1f      ; stay within 32-column screen
  beq doneMove
  inc playerCol
  inc playerTopL
  bne rightNoCarry
  inc playerTopH
rightNoCarry:
  jsr updatePlayerBottom
  rts

moveUp:
  lda playerRow
  beq doneMove
  dec playerRow
  lda playerTopL
  sec
  sbc #$20
  sta playerTopL
  lda playerTopH
  sbc #$00
  sta playerTopH
  jsr updatePlayerBottom
  rts

moveDown:
  lda playerRow
  cmp #$1e      ; row + 1 must stay within screen
  beq doneMove
  inc playerRow
  lda playerTopL
  clc
  adc #$20
  sta playerTopL
  lda playerTopH
  adc #$00
  sta playerTopH
  jsr updatePlayerBottom
  rts

doneMove:
  rts

moveObstacles:
  ldx #$00
moveObLoop:
  lda obstacleDelayBase,x
  beq meteorActive
  dec obstacleDelayBase,x
  jmp afterAdvance

meteorActive:
  lda obstacleHighBase,x
  cmp #$06
  bcs respawnObstacle
  lda obstacleLowBase,x
  and #$1f
  tay                     ; current column in Y
  lda obstacleStepBase,x
  cmp #$21                ; moving down-right?
  bne checkLeftEdge
  cpy #$1f
  beq respawnObstacle     ; would wrap past right edge
  jmp applyStep
checkLeftEdge:
  cmp #$1f                ; moving down-left?
  bne applyStep
  cpy #$00
  beq respawnObstacle     ; would wrap past left edge
applyStep:
  lda obstacleLowBase,x
  clc
  adc obstacleStepBase,x
  sta obstacleLowBase,x
  bcc checkBounds
  inc obstacleHighBase,x
checkBounds:
  lda obstacleHighBase,x
  cmp #$06
  bcc obstacleAdvanced
respawnObstacle:
  jsr spawnObstacle
  jmp afterAdvance
obstacleAdvanced:
  ; keep current value
afterAdvance:
  inx
  inx
  cpx #obstacleBytes
  bne moveObLoop
  rts

checkCollisions:
  ldx #$00
collisionLoop:
  lda obstacleLowBase,x
  cmp playerTopL
  bne checkRightPixel
  lda obstacleHighBase,x
  cmp playerTopH
  beq collision
checkRightPixel:
  lda obstacleLowBase,x
  cmp playerBottomL
  bne nextObstacle
  lda obstacleHighBase,x
  cmp playerBottomH
  beq collision
nextObstacle:
  inx
  inx
  cpx #obstacleBytes
  bne collisionLoop
  rts

collision:
  jsr resetGame
  rts

resetGame:
  jsr clearScreen
  jsr initPlayer
  jsr initObstacles
  rts

clearScreen:
  lda #$00
  ldx #$00
clearLoop:
  sta $0200,x
  sta $0300,x
  sta $0400,x
  sta $0500,x
  inx
  bne clearLoop
  rts

delay:
  ldx #$0400  ; I think t
outerDelay:
  ldy #$ff
innerDelay:
  dey
  bne innerDelay
  dex
  bne outerDelay
  rts
