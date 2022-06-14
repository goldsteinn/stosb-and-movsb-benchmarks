#ifndef STOSB_MOVSB_PERF__TESTS__COMMON_HDR_S_
# define STOSB_MOVSB_PERF__TESTS__COMMON_HDR_S_



# define PROT_READ			0x1
# define PROT_WRITE			0x2
# define MAP_PRIVATE			0x2
# define MAP_ANONYMOUS			0x20

# define SYS_mmap			0x9
# define SYS_write			0x1

# define STDOUT_FILENO			0x1
# define STDERR_FILENO			0x2

# define ASSERT_ERROR_INFO		0x0a747265737361, 7
# define SYS_WRITE_ERROR_INFO		0x0a293128727265, 7
# define SYS_MMAP_ERROR_INFO		0x0a293928727265, 7


# ifdef I_NO_HIDDEN_LABELS
#  define I_L(x)				L##x
# else
#  define I_L(x)				.L##x
# endif
# define L(x)				I_L(x)


# define I_WRITE_BASE(fileno, data, sz)	\
	leaq	I_reg_buf(%rip), %rsi;	\
	movq	data, (%rsi);	\
	movl	$fileno, %edi;	\
	movl	$sz, %edx;	\
	movl	$SYS_write, %eax;	\
	syscall;

# define I_WRITE_CHECK_ERR(sz)	\
	cmpl	$sz, %eax;	\
	jne	L(I_write_error);

# define I_WRITE(fileno, data)	\
	I_WRITE_BASE (fileno, data, 8);	\
	I_WRITE_CHECK_ERR (8);

# define WRITE_REG_STDOUT(reg)		I_WRITE(STDOUT_FILENO, %reg)
# define WRITE_REG_STDERR(reg)		I_WRITE(STDERR_FILENO, %reg)

# define WRITE_IMM32_STDOUT(val)		I_WRITE(STDOUT_FILENO, $val)
# define WRITE_IMM32_STDERR(val)		I_WRITE(STDERR_FILENO, $val)

# define WRITE_IMM64_STDOUT(val)	\
	movabs	$val, %rdi;	\
	WRITE_REG_STDOUT (rdi);

# define WRITE_IMM64_STDERR(val)	\
	movabs	$val, %rdi;	\
	WRITE_REG_STDERR (rdi);

# define I_WRITE_ERR(val, sz)	\
	movabs	$val, %rdi;	\
	I_WRITE_BASE (STDERR_FILENO, %rdi, sz);


# define WRITE_ERR(...)			I_WRITE_ERR(__VA_ARGS__)


# define MMAP_BUF_TO_RAX(sz)	\
	xorl	%edi, %edi;	\
	movq	$sz, %rsi;	\
	movl	$(PROT_READ | PROT_WRITE), %edx;	\
	movl	$(MAP_PRIVATE | MAP_ANONYMOUS), %r10d;	\
	movl	$-1, %r8d;	\
	xorl	%r9d, %r9d;	\
	movl	$SYS_mmap, %eax;	\
	syscall;	\
	testq	%rax, %rax;	\
	js	L(I_mmap_error);	\

# define I_RDTSC_TO(other, dst)	\
	rdtsc;	\
	salq	$32, %rdx;	\
	orq	%other, %dst

# define RDTSC_TO_RDX()			I_RDTSC_TO(rax, rdx)
# define RDTSC_TO_RAX()			I_RDTSC_TO(rdx, rax)

# define DEBUG
# ifdef DEBUG
#  define I_ASSERT_JCC(jcc, ...)	\
	__VA_ARGS__;	\
	jcc	L(I_assert_err);
# else
#  define I_ASSERT_JCC(...)
# endif

# define ASSERT_Z(...)			I_ASSERT_JCC(jnz, __VA_ARGS__)
# define ASSERT_NZ(...)			I_ASSERT_JCC(jz, __VA_ARGS__)
# define ASSERT_A(...)			I_ASSERT_JCC(jbe, __VA_ARGS__)
# define ASSERT_B(...)			I_ASSERT_JCC(jae, __VA_ARGS__)
# define ASSERT_AE(...)			I_ASSERT_JCC(jb, __VA_ARGS__)
# define ASSERT_BE(...)			I_ASSERT_JCC(ja, __VA_ARGS__)
# define ASSERT_G(...)			I_ASSERT_JCC(jle, __VA_ARGS__)
# define ASSERT_L(...)			I_ASSERT_JCC(jge, __VA_ARGS__)
# define ASSERT_GE(...)			I_ASSERT_JCC(jl, __VA_ARGS__)
# define ASSERT_LE(...)			I_ASSERT_JCC(jg, __VA_ARGS__)

# define RASSERT_Z(reg)			I_ASSERT_JCC(jnz, test %reg, %reg)
# define RASSERT_NZ(reg)			I_ASSERT_JCC(jz, test %reg, %reg)

# define RASSERT_EQ_V(reg, v)		I_ASSERT_JCC(jnz, cmp $v, %reg)
# define RASSERT_EQ_R(reg0, reg1)		I_ASSERT_JCC(jnz, cmp %reg0, %reg1)

# define RASSERT_A(reg, v)		I_ASSERT_JCC(jbe, cmp $v, %reg)
# define RASSERT_B(reg, v)		I_ASSERT_JCC(jae, cmp $v, %reg)
# define RASSERT_AE(reg, v)		I_ASSERT_JCC(jb, cmp $v, %reg)
# define RASSERT_BE(reg, v)		I_ASSERT_JCC(ja, cmp $v, %reg)
# define RASSERT_G(reg, v)		I_ASSERT_JCC(jle, cmp $v, %reg)
# define RASSERT_L(reg, v)		I_ASSERT_JCC(jge, cmp $v, %reg)
# define RASSERT_GE(reg, v)		I_ASSERT_JCC(jl, cmp $v, %reg)
# define RASSERT_LE(reg, v)		I_ASSERT_JCC(jg, cmp $v, %reg)


	.section .data.reg_buf, "aM", @progbits, 8
	.p2align 3
I_reg_buf:	.space 8


	.section .text.error_tbl, "ax", @progbits
L(I_assert_err):
	WRITE_ERR (ASSERT_ERROR_INFO)
	jmp	L(I_err_return)
L(I_mmap_error):
	WRITE_ERR (SYS_MMAP_ERROR_INFO)
	jmp	L(I_err_return)
L(I_write_error):
	WRITE_ERR (SYS_WRITE_ERROR_INFO)
L(I_err_return):
	movl	$60, %eax
	movl	$-2, %edi
	syscall



#endif
