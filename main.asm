	.globl main
	
	.include "syscalls.asm"
	.include "bmp_data.asm"
	.include "complex.asm"
	
	.data
	
input: 	.asciz  "/Users/domin/Desktop/studia/sem2_23L/ARKO/RISC V/Julia-set/lena.bmp"
output:	.asciz  "/Users/domin/Desktop/studia/sem2_23L/ARKO/RISC V/Julia-set/lenaAfter.bmp"

hello:	.asciz	"\nWelcome to Mandelbrot set generator!\n"
bye:	.asciz	"\nMandelbrot set was generated. Have a good day!"

error:	.asciz	"\nCould not open file\n"

	.text

main:
	la 	a0, hello
	li	a7, PSTR
	ecall	
	
	jal	open_bmp_file

##### count padding
padding:
	# padding: s4 = (4 - (width % 4)) % 4
	li	t4, 3		# bit mask = 4 - 1 = 3
	and	s4, s1, t4
	li	t3, 4
	sub	s4, t3, s4
	and	s4, s4, t4

##### mandelbrot set generator
start_table_iterator:
	mv	t0, s5		# t0 = start -> iterator
	add	t6, s5, s3	# t6 = start + size -> end

	mv	t3, s2		
	addi	t3, t3, -1	# t3 = height iterator
loop_height:
	li	t2, 0		# t2 = width iterator
	bltz	t3, end_loop
	
loop_width:
	bge	t2, s1, next_height
	
	# complex number real part
	# s6 = (x / WIDTH) * (RE_END - RE_START) + RE_START
	slli	t2, t2, 16		# t2 - 2^16
	div	s6, t2, s1		# s6 - 2^16
	srai	t2, t2, 16		# t2 - 2^0
	
	li	s8, RE_START
	li	s9, RE_END
	sub	s9, s9, s8		# s9 - 2^0
	
	mul	s6, s6, s9		# s6 - 2^16
	
	slli	s8, s8, 16		# s8 - 2^16
	add	s6, s6, s8		# s6 - 2^16
	
	# complex number imaginary part
	# s7 = (y / HEIGHT) * (IM_END - IM_START) + IM_START
	slli	t3, t3, 16		# t3 - 2^16
	div	s7, t3, s2		# s7 - 2^16
	srai	t3, t3, 16		# t3 - 2^0
	
	li	s8, IM_START
	li	s9, IM_END
	sub	s9, s9, s8		# s9 - 2^0
	
	mul	s7, s7, s9		# s7 - 2^16
	
	slli	s8, s8, 16		# s8 - 2^16
	add	s7, s7, s8		# s7 - 2^16
	
	jal	mandelbrot
		
	# grey scale color
	# color = 255 - int(m * 255 / MAX_ITER)
	li	t4, 255
	
	slli	s10, s10, 16		# s10 - 2^16
	mul	s8, s10, t4		# s8 - 2^16
	
	li	t5, MAX_ITER
	div	s8, s8, t5		# s8 - 2^16
	
	srai	s8, s8, 16		# s8 - 2^0
	
	sub	s8, t4, s8		# s8 - 2^0

store:
	# store blue
	bge	t0, t6, end_loop
	sb	s8, (t0)
	# store green
	addi	t0, t0, 1
	bge	t0, t6, end_loop
	sb	s8, (t0)
	# store red
	addi	t0, t0, 1
	bge	t0, t6, end_loop
	sb	s8, (t0)

	addi	t0, t0, 1
	
	addi	t2, t2, 1
	b	loop_width

next_height:
	addi	t3, t3, -1
	mv	t4, s4
		
skip_padding:
	beqz	t4, loop_height
	addi	t0, t0, 1
	addi	t4, t4, -1
	b	skip_padding

end_loop:
	jal 	open_dest_file

	li	a7, PSTR
	la 	a0, bye
	ecall
	
	li	a7, EXIT
	ecall


##### read bmp file function
open_bmp_file:
	la	a0, input
	mv	a1, zero	# read only mode
	li 	a7, OPEN
	ecall
	
	li	t0, -1
	beq	a0, t0, open_bmp_error

	mv	s0, a0		# save the file descriptor

read_headers:
	mv	a0, s0
	la	a1, BitMapFileHeader
	li	a2, FileHeaderSIZE
	li	a7, READ
	ecall
	
	mv	a0, s0
	la	a1, BitMapInfoHeader
	li	a2, InfoHeaderSIZE
	li	a7, READ
	ecall

get_dims:
	la	t0, BitMapInfoHeader
	lw 	s1, biWidthStart(t0)		# s1 = width
	lw	s2, biHeightStart(t0)		# s2 = height
	lw	s3, biTableSizeStart(t0)	# s3 = full size in bytes

create_table:
	mv	a0, s3
	li	a7, HEAP
	ecall
	
	mv	s5, a0				# s5 = table pointer

copy_table:
	# read all bitMap table into buffer at once
	mv	a0, s0				# s0 = file descriptor
	mv	a1, s5				# s5 = table pointer
	mv	a2, s3				# s3 = full size in bytes
	li	a7, READ
	ecall
	
close_source_file:
	mv	a0, s0
	li	a7, CLOSE
	ecall

	ret

open_bmp_error:
	li	a7, PSTR
	la 	a0, error
	ecall
	
	li	a7, ERROR
	ecall
	
	ret


##### mandlebrot
mandelbrot:
	li	s8, 0		# s8 = z real part
	li	s9, 0		# s9 = z imaginary part
	li	s10, 0		# s10 = n
	
	slli	s8, s8, 8		# s8 - 2^8
	slli	s9, s9, 8		# s9 - 2^8
	
mloop:
	# s11 = abs(z)^2		where z = s8 + s9 * i
	# s11 = s8^2 + s9^2
	mv	t4, s8			# t4 - 2^8
	mv	t5, s9			# t5 - 2^8
	
	mul	t4, t4, t4		# t4 - 2^16
	mul	t5, t5, t5		# t5 - 2^16
	add	s11, t4, t5		# s11 - s^16
	
	# do mloop while abs(z) <= 2 and n < MAX_ITER
	li	t4, 4	
	slli	t4, t4, 16		# t4 - 2^16
	bgt	s11, t4, end_mloop
	
	li	t4, MAX_ITER
	bge	s10, t4, end_mloop
	
	# z = z*z + c
	# s8 = s8^2 - s9^2 + s6
	mv	t4, s8		# save old s8 for counting new s9
	
	mul	s8, s8, s8		# s8 - 2^16
	mul	t5, s9, s9		# t5 - 2^16
	
	sub	s8, s8, t5		# s8 - 2^16
	add	s8, s8, s6		# s8 - 2^16

	# s9 = 2 * s8 * s9 + s7
	li	t5, 2
	slli	t5, t5, 8		# t5 - 2^8
	
	mul	s9, s9, t5		# s9 - 2^16
	mul	s9, s9, t4		# s9 - 2^24
	
	srai	s9, s9, 8		# s9 - 2^16
	add	s9, s9, s7		# s9 - 2^16
	
	srai	s9, s9, 8		# s9 - 2^8
	srai	s8, s8, 8		# s8 - 2^8
	
	# n += 1
	addi	s10, s10, 1
	b mloop	

end_mloop:
	ret


##### write to bmp file function
open_dest_file:
	la	a0, output
	li	a1, 1		# write-only
	li	a7, OPEN
	ecall
	
	mv	s0, a0

write_headers:
	mv	a0, s0
	la	a1, BitMapFileHeader
	li	a2, FileHeaderSIZE
	li	a7, WRITE
	ecall

	mv	a0, s0
	la	a1, BitMapInfoHeader
	li	a2, InfoHeaderSIZE
	li	a7, WRITE
	ecall

write_table:
	mv	a0, s0
	mv	a1, s5
	mv	a2, s3
	li	a7, WRITE
	ecall

close_dest_file:
	mv	a0, s0
	li	a7, CLOSE
	ecall
	
	ret
