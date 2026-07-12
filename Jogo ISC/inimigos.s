.data
.include "vilao.data"

.eqv OGRE_INTERVALO  5     # frames entre cada passo (velocidade lenta)
.eqv OGRE_DIST_MIN   80    # distancia minima (manhattan) ao nascer
.eqv OGRE_TENTATIVAS 10

.text

# Sorteia uma posição longe do mago e ativa o primeiro slot de inimigo
spawn_inimigos:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)

    la s1, inimigos
    li s2, OGRE_TENTATIVAS

spawn_tenta:
    li a7, 42
    li a1, 264
    ecall
    addi t0, a0, 16          # x sorteado em [16, 280)

    li a7, 42
    li a1, 184
    ecall
    addi t1, a0, 16          # y sorteado em [16, 200)

    la t2, posicao_x_mago
    lw t2, 0(t2)
    la t3, posicao_y_mago
    lw t3, 0(t3)

    sub t4, t0, t2
    bgez t4, spawn_dx_ok
    neg t4, t4
spawn_dx_ok:
    sub t5, t1, t3
    bgez t5, spawn_dy_ok
    neg t5, t5
spawn_dy_ok:
    add t4, t4, t5            # distancia até o mago

    li t6, OGRE_DIST_MIN
    bge t4, t6, spawn_aceita

    addi s2, s2, -1
    bnez s2, spawn_tenta
    # acabaram as tentativas: usa a última posição sorteada mesmo

spawn_aceita:
    sw t0, 0(s1)
    sw t1, 4(s1)
    li t0, 1
    sw t0, 8(s1)               # ativo
    sw zero, 12(s1)            # direcao (0 = esquerda)
    li t0, OGRE_INTERVALO
    sw t0, 16(s1)              # timer de passo

    lw ra, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 12
    ret

# Anda os inimigos ativos 1px por vez em direção ao mago (chase simples)
atualiza_inimigos:
    addi sp, sp, -8
    sw ra, 4(sp)
    sw s1, 0(sp)

    la s1, inimigos
    li t6, MAX_INIMIGOS

atualiza_loop:
    beqz t6, atualiza_fim

    lw t0, 8(s1)
    beqz t0, atualiza_next      # inimigo inativo, pula

    lw t0, 16(s1)
    addi t0, t0, -1
    bgtz t0, atualiza_guarda    # ainda não é hora de andar

    li t0, OGRE_INTERVALO       # reseta o temporizador

    lw t1, 0(s1)
    lw t2, 4(s1)
    la t3, posicao_x_mago
    lw t3, 0(t3)
    la t4, posicao_y_mago
    lw t4, 0(t4)

    blt t1, t3, ogre_direita
    bgt t1, t3, ogre_esquerda
    j ogre_x_ok
ogre_direita:
    addi t1, t1, 2
    li t5, 1
    sw t5, 12(s1)                # direcao = direita
    j ogre_x_ok
ogre_esquerda:
    addi t1, t1, -2
    sw zero, 12(s1)              # direcao = esquerda
ogre_x_ok:
    blt t2, t4, ogre_desce
    bgt t2, t4, ogre_sobe
    j ogre_y_ok
ogre_desce:
    addi t2, t2, 2
    j ogre_y_ok
ogre_sobe:
    addi t2, t2, -2
ogre_y_ok:
    sw t1, 0(s1)
    sw t2, 4(s1)

atualiza_guarda:
    sw t0, 16(s1)

atualiza_next:
    addi s1, s1, TAM_INIMIGO
    addi t6, t6, -1
    j atualiza_loop

atualiza_fim:
    lw ra, 4(sp)
    lw s1, 0(sp)
    addi sp, sp, 8
    ret

# Desenha todos os inimigos ativos
draw_inimigos:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)

    la s1, inimigos
    li s2, MAX_INIMIGOS

draw_inimigos_loop:
    beqz s2, draw_inimigos_fim

    lw t0, 8(s1)
    beqz t0, draw_inimigos_next

    lw a1, 0(s1)
    lw a2, 4(s1)
    lw a3, 12(s1)
    jal draw_vilao

draw_inimigos_next:
    addi s1, s1, TAM_INIMIGO
    addi s2, s2, -1
    j draw_inimigos_loop

draw_inimigos_fim:
    lw ra, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 12
    ret

# Desenha o ogro (32x32). a1=x, a2=y, a3=direcao (0=esq,1=dir). 0x00 = transparente
draw_vilao:
    la t0, base_frame_A
    lw s0, 0(t0)

    la a0, vilao
    addi a0, a0, 8            # pula cabeçalho (2 words)
    li t1, 1024                # bytes por frame (32*32)
    mul t1, a3, t1
    add a0, a0, t1             # escolhe o frame pela direção

    li t1, 320
    mul t2, a2, t1
    add t2, t2, a1
    add t0, s0, t2

    li t3, 0
vilao_row:
    li t4, 32
    beq t3, t4, vilao_row_done
    mv t5, t0
    li t6, 0
vilao_col:
    li t4, 32
    beq t6, t4, vilao_col_done
    lb t4, 0(a0)
    beqz t4, vilao_skip
    sb t4, 0(t5)
vilao_skip:
    addi a0, a0, 1
    addi t5, t5, 1
    addi t6, t6, 1
    j vilao_col
vilao_col_done:
    addi t0, t0, 320
    addi t3, t3, 1
    j vilao_row
vilao_row_done:
    ret

# Mata um inimigo (a0 = ponteiro pro registro dele em "inimigos")
# Chamar aqui quando o poder do mago acertar um ogro
mata_inimigo:
    sw zero, 8(a0)
    ret
