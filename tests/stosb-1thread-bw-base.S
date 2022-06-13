#include "common-hdr.S"


#define VEC_SIZE			16
#include "common-vec.S"
#define vec_mov				vmova

#define VEC_SET_FWD			0
#define VEC_SET_BKWD			1
#define STOSB_SET			2

#define TODO				2
#define SET_LEN				(1UL << 24)

    
#ifndef TODO
# error "No 'TODO' Config"
#endif
#ifndef SET_LEN
# error "No Length Specified"
#endif




#define ITERS				(1UL << 33) / (SET_LEN)


	.global	_start
	.p2align 6
	.text
_start:
	MMAP_BUF_TO_RAX (SET_LEN)

	movq	%rax, %r8
	movq	$(SET_LEN), %rsi

	movl	$(ITERS), %esp

	movq	%r8, %rdi
	movq	%rsi, %rcx
	xorl	%eax, %eax
	/* Page in.  */
	rep	stosb
	prefetchw (%r8)
	prefetchw 4096(%r8)
	prefetchw 8192(%r8)
	prefetchw 16384(%r8)

	RDTSC_TO_RDX ()

	ZERO_VEC ()
	xorl	%eax, %eax
#if TODO == VEC_SET_BKWD
	leaq	(%r8, %rsi), %rdi
#else
	movq	%r8, %rdi
#endif

	movq	%rsi, %rcx



	.p2align 6
L(bench_loop):
#if TODO == VEC_SET_FWD
L(copy_loop):
	vec_mov	%VEC, (VEC_SIZE * 0)(%rdi)
	vec_mov	%VEC, (VEC_SIZE * 1)(%rdi)
	vec_mov	%VEC, (VEC_SIZE * 2)(%rdi)
	vec_mov	%VEC, (VEC_SIZE * 3)(%rdi)
	subq	$-(VEC_SIZE * 4), %rdi
	addq	$-(VEC_SIZE * 4), %rcx
	jnz	L(copy_loop)
	sfence
#elif TODO == VEC_SET_BKWD
L(copy_loop):
	vec_mov	%VEC, (VEC_SIZE * -1)(%rdi)
	vec_mov	%VEC, (VEC_SIZE * -2)(%rdi)
	vec_mov	%VEC, (VEC_SIZE * -3)(%rdi)
	vec_mov	%VEC, (VEC_SIZE * -4)(%rdi)
	addq	$-(VEC_SIZE * 4), %rdi
	addq	$-(VEC_SIZE * 4), %rcx
	jnz	L(copy_loop)
	sfence
#elif TODO == STOSB_SET
	rep	stosb
#else
# error "Invalid TODO"
#endif

#if TODO == VEC_SET_BKWD
	leaq	(%r8, %rsi), %rdi
#else
	movq	%r8, %rdi
#endif
	movq	%rsi, %rcx

	decl	%esp
	jnz	L(bench_loop)

	movq	%rdx, %rcx
	RDTSC_TO_RDX ()
	subq	%rcx, %rdx

	WRITE_REG_STDOUT (rdx)



	movl	$60, %eax
	xorl	%edi, %edi
	syscall

#if 0
	.section .rodata
	.balign	4096
buf_start:	.space 4096
buf_end:
#endif
