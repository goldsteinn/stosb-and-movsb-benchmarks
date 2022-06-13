#include "common-hdr.S"


#define VEC_SIZE			32
#include "common-vec.S"


#define VEC_SET_FWD			0
#define VEC_SET_BKWD			1
#define STOSB_SET			2
#define DRY_RUN				3

#define NT_STORE			0
#define CACHE_STORE			1

#if 0
# define FILL_VAL			0
# define TODO				2
# define MOV_TODO			0
# define SET_LEN				(1UL << 26)
# define BINOUT				0

# define ALIGN				0
# define ALIGN_PTR			1
# define ALIGN_LEN			1
# define ALIGN_END			0
# define PURE_COPY			0
# define RAND_SIZE			0
# define ALIGN_TO			1
#endif


#ifndef PURE_COPY
# error "No PURE_COPY"
#endif
#ifndef ALIGN_END
# error "No ALIGN_END"
#endif
#ifndef ALIGN_TO
# error "No ALIGN_TO"
#endif
#ifndef RAND_SIZE
# error "No RAND_SIZE"
#endif
#ifndef ALIGN_PTR
# error "No ALIGN_PTR"
#endif
#ifndef ALIGN_LEN
# error "No ALIGN_LEN"
#endif
#ifndef MOV_TODO
# error "No 'MOV_TODO' type specified"
#endif
#ifndef TODO
# error "No 'TODO' Config"
#endif
#ifndef SET_LEN
# error "No Length Specified"
#endif
#ifndef ALIGN
# error "No Alignment specified"
#endif
#ifndef BINOUT
# error "No BINOUT specified"
#endif
#ifndef FILL_VAL
# error "No fill value specified"
#endif
#if SET_LEN < 256
# error "Length too short"
#endif

#if MOV_TODO == NT_STORE
# if ALIGN != 0 && ALIGN_TO == 0
#  error "Invalid config"
# endif

# define VEC_MOV				vmovnt
# define SFENCE				sfence
#elif MOV_TODO == CACHE_STORE
# define VEC_MOV				vmovu
# define SFENCE
#else
# error "Invalid MOV_TODO"
#endif

#define PAGE_ALIGN			(4095 & (ALIGN))
#define ITERS				((1UL << 35) / SET_LEN)

#if PURE_COPY
# define END_OFFSET			0
#else
# define END_OFFSET			(VEC_SIZE * 4)
#endif

#if (ALIGN_PTR || ALIGN_END || ALIGN_LEN) && PURE_COPY
# error "Bad config"
#endif

#if TODO == STOSB_SET && VEC_SIZE == 8
# error "Invalid config"
#endif

	.global	_start
	.p2align 6
	.text
_start:
	MMAP_BUF_TO_RAX (SET_LEN + PAGE_ALIGN + 8192)

	leaq	(PAGE_ALIGN + 4096)(%rax), %r8
	movq	$(SET_LEN), %r9

	movl	$(ITERS), %esp

	xorl	%ebx, %ebx

	movq	%r8, %rdi
	leaq	256(%r9), %rcx
	xorl	%eax, %eax
	/* Page in.  */
	rep	stosb
	prefetchw (%r8)
#if SET_LEN >= 4096
	prefetchw 4096(%r8)
#endif


	SET_VEC	(FILL_VAL)

#if TODO == VEC_SET_FWD
	leaq	(-1 * END_OFFSET)(%r8, %r9), %r9
#elif TODO == VEC_SET_BKWD
	leaq	(1 * END_OFFSET)(%r8), %rcx
	addq	%r9, %r8
	movq	%rcx, %r9
#elif ALIGN_PTR || ALIGN_END || ALIGN_LEN

# if ALIGN_LEN || ALIGN_END
	leaq	(%r8, %r9), %rsi
# endif

# if ALIGN_PTR || ALIGN_END
	addq	%r8, %r9
# endif



#endif
	movq	%r8, %rdi
	movq	%r9, %rcx

#if BINOUT
	RDTSC_TO_RDX ()
# if VEC_SIZE == 8
#  error "Bad Config"
# endif

#endif


	movq	$FILL_VAL, %rax

	.p2align 6
L(bench_loop):
#if TODO == VEC_SET_FWD


# if ALIGN_TO
#  if PURE_COPY
#   error "Bad Config"
#  endif

	vmovu	%VEC, (VEC_SIZE * 0)(%rdi)
#  if ALIGN_TO > 1
	vmovu	%VEC, (VEC_SIZE * 1)(%rdi)
#   if ALIGN_TO > 2
	vmovu	%VEC, (VEC_SIZE * 2)(%rdi)
	vmovu	%VEC, (VEC_SIZE * 3)(%rdi)
#   endif
#  endif
	orq	$(VEC_SIZE * ALIGN_TO - 1), %rdi
	incq	%rdi
# endif
# if ALIGN_PTR || ALIGN_LEN || ALIGN_END
#  error "Bad ALIGN Config"
# endif

# if RAND_SIZE
	ASSERT_BE (movq %rcx, %r14;subq %rdi, %r14;cmp $(SET_LEN + 256 - END_OFFSET), %r14);
# else
	ASSERT_BE (movq %rcx, %r14;subq %rdi, %r14;cmp $(SET_LEN - END_OFFSET), %r14);
# endif
# if ALIGN_TO
#  if RAND_SIZE
	ASSERT_B (movq %rcx, %r14;subq %rdi, %r14;cmp $(SET_LEN + 256 - END_OFFSET), %r14);
#  else
	ASSERT_B (movq %rcx, %r14;subq %rdi, %r14;cmp $(SET_LEN - END_OFFSET), %r14);
#  endif

	ASSERT_Z (test $(VEC_SIZE * ALIGN_TO - 1), %rdi)
# endif


	.p2align 5
L(copy_loop):
	VEC_MOV	%VEC, (VEC_SIZE * 0)(%rdi)
	VEC_MOV	%VEC, (VEC_SIZE * 1)(%rdi)
	VEC_MOV	%VEC, (VEC_SIZE * 2)(%rdi)
	VEC_MOV	%VEC, (VEC_SIZE * 3)(%rdi)
	subq	$-(VEC_SIZE * 4), %rdi
	.p2align 5,, 4
	cmpq	%rdi, %rcx
	ja	L(copy_loop)
	SFENCE
# if !PURE_COPY
	vmovu	%VEC, (VEC_SIZE * 0)(%rcx)
	vmovu	%VEC, (VEC_SIZE * 1)(%rcx)
	vmovu	%VEC, (VEC_SIZE * 2)(%rcx)
	vmovu	%VEC, (VEC_SIZE * 3)(%rcx)
# endif

#elif TODO == VEC_SET_BKWD

# if ALIGN_TO
#  if PURE_COPY
#   error "Bad Config"
#  endif

	vmovu	%VEC, (VEC_SIZE * -1)(%rdi)
#  if ALIGN_TO > 1
	vmovu	%VEC, (VEC_SIZE * -2)(%rdi)
#   if ALIGN_TO > 2
	vmovu	%VEC, (VEC_SIZE * -3)(%rdi)
	vmovu	%VEC, (VEC_SIZE * -4)(%rdi)
#   endif
#  endif
	decq	%rdi
	andq	$(VEC_SIZE * -1 * ALIGN_TO), %rdi

# endif
# if ALIGN_PTR || ALIGN_LEN || ALIGN_END
#  error "Bad ALIGN Config"
# endif

# if RAND_SIZE
	ASSERT_BE (movq %rdi, %r14;subq %rcx, %r14;cmp $(SET_LEN + 256 - END_OFFSET), %r14);
# else
	ASSERT_BE (movq %rdi, %r14;subq %rcx, %r14;cmp $SET_LEN - END_OFFSET, %r14);
# endif

# if ALIGN_TO
#  if RAND_SIZE
	ASSERT_B (movq %rdi, %r14;subq %rcx, %r14;cmp $(SET_LEN + 256 - END_OFFSET), %r14);
#  else
	ASSERT_B (movq %rdi, %r14;subq %rcx, %r14;cmp $SET_LEN - END_OFFSET, %r14);
#  endif

	ASSERT_Z (test $(VEC_SIZE * ALIGN_TO - 1), %rdi)
# endif

	.p2align 4
L(copy_loop):
	VEC_MOV	%VEC, (VEC_SIZE * -1)(%rdi)
	VEC_MOV	%VEC, (VEC_SIZE * -2)(%rdi)
	VEC_MOV	%VEC, (VEC_SIZE * -3)(%rdi)
	VEC_MOV	%VEC, (VEC_SIZE * -4)(%rdi)
	addq	$-(VEC_SIZE * 4), %rdi
	.p2align 5,, 4
	cmpq	%rdi, %rcx
	jb	L(copy_loop)
	SFENCE
# if !PURE_COPY
	vmovu	%VEC, (VEC_SIZE * -1)(%rcx)
	vmovu	%VEC, (VEC_SIZE * -2)(%rcx)
	vmovu	%VEC, (VEC_SIZE * -3)(%rcx)
	vmovu	%VEC, (VEC_SIZE * -4)(%rcx)
# endif

#elif TODO == STOSB_SET
# if ALIGN_TO
#  if PURE_COPY
#   error "Bad Config"
#  endif

#  if ALIGN_PTR
	vmovu	%VEC, (VEC_SIZE * 0)(%rdi)
#   if ALIGN_TO > 1
	vmovu	%VEC, (VEC_SIZE * 1)(%rdi)
#    if ALIGN_TO > 2
	vmovu	%VEC, (VEC_SIZE * 2)(%rdi)
	vmovu	%VEC, (VEC_SIZE * 3)(%rdi)
#    endif
#   endif
#  endif
#  if ALIGN_LEN || ALIGN_END

#   if ALIGN_LEN && !ALIGN_PTR
	ASSERT_Z (movq %rdi, %r14;addq %rcx, %r14;cmp %rsi, %r14)
#   else
	RASSERT_EQ_R (rsi, rcx)
#   endif

	vmovu	%VEC, (VEC_SIZE * -1)(%rsi)
#   if ALIGN_TO > 1
	vmovu	%VEC, (VEC_SIZE * -2)(%rsi)
#    if ALIGN_TO > 2
	vmovu	%VEC, (VEC_SIZE * -3)(%rsi)
	vmovu	%VEC, (VEC_SIZE * -4)(%rsi)
#    endif
#   endif
#  endif

#  if !ALIGN_PTR && !ALIGN_LEN && !ALIGN_END
#   error "Bad Config"
#  endif

#  if ALIGN_END && (ALIGN_PTR || ALIGN_LEN)
#   error "Bad Config"
#  endif

#  if ALIGN_PTR
	orq	$(VEC_SIZE * ALIGN_TO - 1), %rdi
	incq	%rdi
	subq	%rdi, %rcx
#  endif

#  if ALIGN_LEN || ALIGN_END
	decq	%rcx
	andq	$(VEC_SIZE * -1 * ALIGN_TO), %rcx
#  endif

#  if ALIGN_END
	subq	%rdi, %rcx
#  endif

# endif

# if !RAND_SIZE
	RASSERT_BE (rcx, SET_LEN);
# else
	RASSERT_BE (rcx, SET_LEN + 256);
# endif

	RASSERT_EQ_V (rax, FILL_VAL)
# if ALIGN_TO
#  if !RAND_SIZE
	RASSERT_B (rcx, SET_LEN);
#  else
	RASSERT_B (rcx, SET_LEN + 256);
#  endif


#  if ALIGN_PTR
	ASSERT_Z (test $(VEC_SIZE * ALIGN_TO - 1), %rdi);
#  endif
#  if ALIGN_END
	ASSERT_Z (movq %rdi, %r14;addq %rcx, %r14;test $(VEC_SIZE * ALIGN_TO - 1), %r14);
#  endif
#  if ALIGN_LEN
	ASSERT_Z (test $(VEC_SIZE * ALIGN_TO - 1), %rcx);
#  endif

# endif

	rep	stosb
#elif TODO == DRY_RUN
	/* Do nothing.  */
#else
# error "Invalid TODO"
#endif

	movq	%r9, %rcx
#if RAND_SIZE
# if PURE_COPY
#  error "Bad Config"
# endif

	rorxl	$26, %ebx, %edi
	leal	9(%rbx, %rdi), %ebx
	movzbl	%bl, %edi

# if TODO == VEC_SET_FWD
	addq	%rdi, %rcx
# elif TODO == VEC_SET_BKWD
	subq	%rdi, %rcx
# else
	addq	%rdi, %rcx

#  if ALIGN_END || (ALIGN_PTR && ALIGN_LEN)
	movq	%rcx, %rsi
#  elif ALIGN_LEN
	leaq	(%r8, %rcx), %rsi
#  endif


# endif
#endif

	movq	%r8, %rdi

	.p2align 5,, 6
	decl	%esp
	jnz	L(bench_loop)
#if BINOUT
	movq	%rdx, %rcx
	RDTSC_TO_RDX ()
	subq	%rcx, %rdx
	WRITE_REG_STDOUT (rdx)
#endif

	movl	$60, %eax
	xorl	%edi, %edi
	syscall

#if 0
	.section .rodata
	.balign	4096
buf_start:	.space 4096
buf_end:
#endif
