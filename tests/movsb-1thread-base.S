#include "common-hdr.S"


#define VEC_SIZE			32
#include "common-vec.S"


#define VEC_SET_FWD			0
#define VEC_SET_BKWD			1
#define MOVSB_SET			2
#define DRY_RUN				3

#define NT_STORE			0
#define CACHE_STORE			1

#if 0
# define FILL_VAL			0
# define TODO				2
# define MOV_TODO			0
# define SET_LEN				512
# define BINOUT				0

# define ALIGN_DST			0
# define ALIGN_SRC			0

# define ALIGN_PTR			1
# define ALIGN_LEN			1
# define ALIGN_END			0

# define ALIGN_PTR_DST			1
# define ALIGN_PTR_SRC			0


# define RAND_SIZE			0
# define ALIGN_TO			2
# define PURE_COPY			0
#endif

#ifndef FILL_VAL
# error "No FILL_VAL"
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
#ifndef ALIGN_PTR_DST
# error "No ALIGN_PTR_DST"
#endif
#ifndef ALIGN_PTR_SRC
# error "No ALIGN_PTR_DST"
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
#ifndef ALIGN_DST
# error "No DST Alignment specified"
#endif
#ifndef ALIGN_SRC
# error "No SRC Alignment specified"
#endif
#ifndef BINOUT
# error "No BINOUT specified"
#endif
#if SET_LEN < 256
# error "Length too short"
#endif

#if MOV_TODO == NT_STORE
# define VEC_MOV				vmovnt
# define SFENCE				sfence

# if ALIGN_DST != 0 && ALIGN_TO == 0
#  error "Invalid config"
# endif
#elif MOV_TODO == CACHE_STORE
# define VEC_MOV				vmovu
# define SFENCE
#else
# error "Invalid MOV_TODO"
#endif

#if VEC_SIZE == 8
# error "Invalid config"
#endif

#define PAGE_ALIGN_DST			(4095 & (ALIGN_DST))
#define PAGE_ALIGN_SRC			(4095 & (ALIGN_SRC))
#define ITERS				((1UL << 35) / SET_LEN)
#if ALIGN_PTR_SRC && ALIGN_PTR_DST
# error "Bad Config"
#endif

#if PURE_COPY
# define END_OFFSET			0
#else
# define END_OFFSET			(VEC_SIZE * 4)
#endif

	.global	_start
	.p2align 6
	.text
_start:
	MMAP_BUF_TO_RAX (SET_LEN * 2 + 16384)

	leaq	(PAGE_ALIGN_DST + 4096)(%rax), %r8
	leaq	(PAGE_ALIGN_SRC + SET_LEN + 8192)(%rax), %r9
	movq	$(SET_LEN), %r10

	movl	$(ITERS), %esp

	movq	%r9, %rdi
	movl	$FILL_VAL, %eax
	movq	%r10, %rcx
	rep	stosb

	movq	%r8, %rdi
	movq	%r9, %rsi
	movq	%r10, %rcx
	/* Page in.  */
	rep	movsb
	prefetchw (%r8)
	prefetcht0 (%r9)
#if SET_LEN >= 4096
	prefetchw 4096(%r8)
	prefetcht0 4096(%r9)
#endif


#if TODO == VEC_SET_FWD
	leaq	(-1 * END_OFFSET)(%r9, %r10), %r11
	leaq	(-1 * END_OFFSET)(%r8, %r10), %r10
#elif TODO == VEC_SET_BKWD
	leaq	(END_OFFSET)(%r9), %r11
	leaq	(END_OFFSET)(%r8), %rcx

	addq	%r10, %r8
	addq	%r10, %r9

	movq	%rcx, %r10
#elif ALIGN_PTR_SRC || ALIGN_PTR_DST || ALIGN_LEN
	leaq	(%r8, %r10), %rbp
	leaq	(%r9, %r10), %r11
	movq	%rbp, %r12
# if ALIGN_PTR_SRC
	addq	%r9, %r10
# elif ALIGN_PTR_DST
	addq	%r8, %r10
# endif
#endif

#if ALIGN_LEN && (ALIGN_PTR_SRC || ALIGN_PTR_DIR)
# if !ALIGN_PTR
#  error "Bad config"
# endif
#endif

	movq	%r8, %rdi
	movq	%r9, %rsi
	movq	%r10, %rcx

#if BINOUT
	RDTSC_TO_RDX ()
#endif

	movq	%r11, %rax

	.p2align 6
L(bench_loop):

#if TODO == VEC_SET_FWD
# if ALIGN_TO

#  if PURE_COPY
#   error "Bad Config"
#  endif

	vmovu	(VEC_SIZE * 0)(%rsi), %VEC0
#  if ALIGN_TO > 1
	vmovu	(VEC_SIZE * 1)(%rsi), %VEC1
#   if ALIGN_TO > 2
	vmovu	(VEC_SIZE * 2)(%rsi), %VEC2
	vmovu	(VEC_SIZE * 3)(%rsi), %VEC3
#   endif
#  endif


	vmovu	%VEC0, (VEC_SIZE * 0)(%rdi)
#  if ALIGN_TO > 1
	vmovu	%VEC1, (VEC_SIZE * 1)(%rdi)
#   if ALIGN_TO > 2
	vmovu	%VEC2, (VEC_SIZE * 2)(%rdi)
	vmovu	%VEC3, (VEC_SIZE * 3)(%rdi)
#   endif
#  endif

	subq	%rdi, %rsi
	orq	$(VEC_SIZE * ALIGN_TO - 1), %rdi
	incq	%rdi
	addq	%rdi, %rsi
# endif

# if ALIGN_PTR || ALIGN_PTR_SRC || ALIGN_PTR_DST || ALIGN_LEN || ALIGN_END
#  error "BAD ALIGN Config"
# endif

# if RAND_SIZE
	ASSERT_BE (movq %rax, %r15;subq %rsi, %r15;cmpq $(SET_LEN + 256 - END_OFFSET), %r15)
# else
	ASSERT_BE (movq %rax, %r15;subq %rsi, %r15;cmpq $(SET_LEN - END_OFFSET), %r15)
# endif

# if ALIGN_TO
#  if RAND_SIZE
	ASSERT_B (movq %rax, %r15;subq %rsi, %r15;cmpq $(SET_LEN + 256 - END_OFFSET), %r15)
#  else
	ASSERT_B (movq %rax, %r15;subq %rsi, %r15;cmpq $(SET_LEN - END_OFFSET), %r15)
#  endif


	ASSERT_Z (testq $(ALIGN_TO * VEC_SIZE - 1), %rdi)
# endif
	ASSERT_Z (movq %rdi, %r14;movq %rsi, %r15;subq %r8, %r14;subq %r9, %r15;cmpq %r14, %r15)
	ASSERT_Z (movq %rax, %r15;subq %rsi, %r15;movq %rcx, %r14;subq %rdi, %r14;cmpq %r14, %r15)




	.p2align 5
L(copy_loop):
	vmovu	(VEC_SIZE * 0)(%rsi), %VEC0
	vmovu	(VEC_SIZE * 1)(%rsi), %VEC1
	vmovu	(VEC_SIZE * 2)(%rsi), %VEC2
	vmovu	(VEC_SIZE * 3)(%rsi), %VEC3

	VEC_MOV	%VEC0, (VEC_SIZE * 0)(%rdi)
	VEC_MOV	%VEC1, (VEC_SIZE * 1)(%rdi)
	VEC_MOV	%VEC2, (VEC_SIZE * 2)(%rdi)
	VEC_MOV	%VEC3, (VEC_SIZE * 3)(%rdi)
	subq	$-(VEC_SIZE * 4), %rsi
	subq	$-(VEC_SIZE * 4), %rdi
	.p2align 5,, 4
	cmpq	%rsi, %rax
	ja	L(copy_loop)
	SFENCE

# if !PURE_COPY
	vmovu	(VEC_SIZE * 0)(%rax), %VEC0
	vmovu	(VEC_SIZE * 1)(%rax), %VEC1
	vmovu	(VEC_SIZE * 2)(%rax), %VEC2
	vmovu	(VEC_SIZE * 3)(%rax), %VEC3

	vmovu	%VEC0, (VEC_SIZE * 0)(%rcx)
	vmovu	%VEC1, (VEC_SIZE * 1)(%rcx)
	vmovu	%VEC2, (VEC_SIZE * 2)(%rcx)
	vmovu	%VEC3, (VEC_SIZE * 3)(%rcx)
# endif

#elif TODO == VEC_SET_BKWD

# if ALIGN_TO

#  if PURE_COPY
#   error "Bad Config"
#  endif

	vmovu	(VEC_SIZE * -1)(%rsi), %VEC0
#  if ALIGN_TO > 1
	vmovu	(VEC_SIZE * -2)(%rsi), %VEC1
#   if ALIGN_TO > 2
	vmovu	(VEC_SIZE * -3)(%rsi), %VEC2
	vmovu	(VEC_SIZE * -4)(%rsi), %VEC3
#   endif
#  endif


	vmovu	%VEC0, (VEC_SIZE * -1)(%rdi)
#  if ALIGN_TO > 1
	vmovu	%VEC1, (VEC_SIZE * -2)(%rdi)
#   if ALIGN_TO > 2
	vmovu	%VEC2, (VEC_SIZE * -3)(%rdi)
	vmovu	%VEC3, (VEC_SIZE * -4)(%rdi)
#   endif
#  endif

	subq	%rdi, %rsi
	decq	%rdi
	andq	$(VEC_SIZE * -1 * ALIGN_TO), %rdi
	addq	%rdi, %rsi

# endif

# if ALIGN_PTR || ALIGN_PTR_SRC || ALIGN_PTR_DST || ALIGN_LEN || ALIGN_END
#  error "BAD ALIGN Config"
# endif

# if RAND_SIZE
	ASSERT_BE (movq %rsi, %r15;subq %rax, %r15;cmpq $(SET_LEN + 256 - END_OFFSET), %r15)
# else
	ASSERT_BE (movq %rsi, %r15;subq %rax, %r15;cmpq $(SET_LEN - END_OFFSET), %r15)
# endif


# if ALIGN_TO
#  if RAND_SIZE
	ASSERT_B (movq %rsi, %r15;subq %rax, %r15;cmpq $(SET_LEN + 256 - END_OFFSET), %r15)
#  else
	ASSERT_B (movq %rsi, %r15;subq %rax, %r15;cmpq $(SET_LEN - END_OFFSET), %r15)
#  endif



	ASSERT_Z (testq $(ALIGN_TO * VEC_SIZE - 1), %rdi)
# endif
	ASSERT_Z (movq %rdi, %r14;movq %rsi, %r15;subq %r8, %r14;subq %r9, %r15;cmpq %r14, %r15)
	ASSERT_Z (movq %rax, %r15;subq %rsi, %r15;movq %rcx, %r14;subq %rdi, %r14;cmpq %r14, %r15)


	.p2align 5
L(copy_loop):
	vmovu	(VEC_SIZE * -1)(%rsi), %VEC0
	vmovu	(VEC_SIZE * -2)(%rsi), %VEC1
	vmovu	(VEC_SIZE * -3)(%rsi), %VEC2
	vmovu	(VEC_SIZE * -4)(%rsi), %VEC3

	VEC_MOV	%VEC0, (VEC_SIZE * -1)(%rdi)
	VEC_MOV	%VEC1, (VEC_SIZE * -2)(%rdi)
	VEC_MOV	%VEC2, (VEC_SIZE * -3)(%rdi)
	VEC_MOV	%VEC3, (VEC_SIZE * -4)(%rdi)
	addq	$-(VEC_SIZE * 4), %rsi
	addq	$-(VEC_SIZE * 4), %rdi
	.p2align 5,, 4
	cmpq	%rsi, %rax
	jb	L(copy_loop)
	SFENCE

# if !PURE_COPY
	vmovu	(VEC_SIZE * -1)(%rax), %VEC0
	vmovu	(VEC_SIZE * -2)(%rax), %VEC1
	vmovu	(VEC_SIZE * -3)(%rax), %VEC2
	vmovu	(VEC_SIZE * -4)(%rax), %VEC3

	vmovu	%VEC0, (VEC_SIZE * -1)(%rcx)
	vmovu	%VEC1, (VEC_SIZE * -2)(%rcx)
	vmovu	%VEC2, (VEC_SIZE * -3)(%rcx)
	vmovu	%VEC3, (VEC_SIZE * -4)(%rcx)
# endif


#elif TODO == MOVSB_SET

# if ALIGN_TO

#  if PURE_COPY
#   error "Bad Config"
#  endif

#  if ALIGN_PTR

#   if ALIGN_END
#    error "Bad Config"
#   endif

	vmovu	(VEC_SIZE * 0)(%rsi), %VEC0
#   if ALIGN_TO > 1
	vmovu	(VEC_SIZE * 1)(%rsi), %VEC1
#    if ALIGN_TO > 2
	vmovu	(VEC_SIZE * 2)(%rsi), %VEC2
	vmovu	(VEC_SIZE * 3)(%rsi), %VEC3
#    endif
#   endif


	vmovu	%VEC0, (VEC_SIZE * 0)(%rdi)
#   if ALIGN_TO > 1
	vmovu	%VEC1, (VEC_SIZE * 1)(%rdi)
#    if ALIGN_TO > 2
	vmovu	%VEC2, (VEC_SIZE * 2)(%rdi)
	vmovu	%VEC3, (VEC_SIZE * 3)(%rdi)
#    endif
#   endif
#  endif

#  if ALIGN_LEN || ALIGN_END
	ASSERT_Z (movq %rax, %r15;subq %rsi, %r15;movq %rbp, %r14;subq %rdi, %r14;cmpq %r14, %r15)

	vmovu	(VEC_SIZE * -1)(%rax), %VEC0
#   if ALIGN_TO > 1
	vmovu	(VEC_SIZE * -2)(%rax), %VEC1
#    if ALIGN_TO > 2
	vmovu	(VEC_SIZE * -3)(%rax), %VEC2
	vmovu	(VEC_SIZE * -4)(%rax), %VEC3
#    endif
#   endif

	vmovu	%VEC0, (VEC_SIZE * -1)(%rbp)
#   if ALIGN_TO > 1
	vmovu	%VEC1, (VEC_SIZE * -2)(%rbp)
#    if ALIGN_TO > 2
	vmovu	%VEC2, (VEC_SIZE * -3)(%rbp)
	vmovu	%VEC3, (VEC_SIZE * -4)(%rbp)
#    endif
#   endif
#  endif

#  if !ALIGN_PTR_DST && !ALIGN_PTR_SRC && !ALIGN_LEN
#   error "Bad Align Config"
#  endif

#  if ALIGN_PTR_DST && ALIGN_PTR_SRC
#   error "Bad Align Config"
#  endif

#  if ALIGN_PTR
#   if ALIGN_PTR_DST
	subq	%rdi, %rsi
	orq	$(VEC_SIZE * ALIGN_TO - 1), %rdi
	incq	%rdi
	addq	%rdi, %rsi
	subq	%rdi, %rcx
#   elif ALIGN_PTR_SRC
	subq	%rsi, %rdi
	orq	$(VEC_SIZE * ALIGN_TO - 1), %rsi
	incq	%rsi
	addq	%rsi, %rdi
	subq	%rsi, %rcx
#   else
#    error "Bad Config"
#   endif
#  endif

#  if ALIGN_LEN || ALIGN_END
	decq	%rcx
	andq	$(VEC_SIZE * -1 * ALIGN_TO), %rcx
#  endif

#  if ALIGN_LEN
#   if ALIGN_END
#    error "Bad Config"
#   endif
#  elif ALIGN_END
#   if ALIGN_PTR_SRC
	subq	%rsi, %rcx
#   elif ALIGN_PTR_DST

	subq	%rdi, %rcx
#   else
#    error "Bad Alignment Config"
#   endif
#  endif
# elif ALIGN_LEN || ALIGN_END || ALIGN_PTR || ALIGN_PTR_DST || ALIGN_PTR_SRC
#  error "Bad Alignment Config"
# endif

# if RAND_SIZE
	RASSERT_BE (rcx, SET_LEN + 256);
# else
	RASSERT_BE (rcx, SET_LEN);
# endif

# if ALIGN_TO
#  if RAND_SIZE
	RASSERT_B (rcx, SET_LEN + 256);
#  else
	RASSERT_B (rcx, SET_LEN);
#  endif


#  if ALIGN_PTR && ALIGN_PTR_DST
	ASSERT_Z (test $(VEC_SIZE * ALIGN_TO - 1), %rdi);
#  endif
#  if ALIGN_PTR && ALIGN_PTR_SRC
	ASSERT_Z (test $(VEC_SIZE * ALIGN_TO - 1), %rsi);
#  endif
#  if ALIGN_LEN
	ASSERT_Z (test $(VEC_SIZE * ALIGN_TO - 1), %rcx);
#  endif
#  if ALIGN_END && ALIGN_PTR_DST
	ASSERT_Z (movq %rcx, %r14;addq %rdi, %r14;test $(VEC_SIZE * ALIGN_TO - 1), %r14);
#  endif
#  if ALIGN_END && ALIGN_PTR_SRC
	ASSERT_Z (movq %rcx, %r14;addq %rsi, %r14;test $(VEC_SIZE * ALIGN_TO - 1), %r14);
#  endif


#  if ALIGN_PTR && ALIGN_PTR_DST
#  elif ALIGN_PTR && ALIGN_PTR_SRC
#  elif ALIGN_LEN
#  elif ALIGN_END && ALIGN_PTR_DST
#  elif ALIGN_END && ALIGN_PTR_SRC
#  else
#   error "Unknown config"
#  endif



# endif
	ASSERT_Z (movq %rdi, %r14;movq %rsi, %r15;subq %r8, %r14;subq %r9, %r15;cmpq %r14, %r15)

	rep	movsb
#elif TODO == DRY_RUN
	/* Do nothing.  */
#else
# error "Invalid TODO"
#endif

	movq	%r10, %rcx

#if RAND_SIZE
	movq	%r11, %rax

# if PURE_COPY
#  error "Bad Config"
# endif
	rorxl	$26, %ebx, %edi
	leal	9(%rbx, %rdi), %ebx
	movzbl	%bl, %edi

# if TODO == VEC_SET_FWD
	addq	%rdi, %rcx
	addq	%rdi, %rax
# elif TODO == VEC_SET_BKWD
	subq	%rdi, %rcx
	subq	%rdi, %rax
# else
	movq	%r12, %rbp
	addq	%rdi, %rcx
	addq	%rdi, %rax
	addq	%rdi, %rbp
# endif
#endif

	movq	%r8, %rdi
	movq	%r9, %rsi


	.p2align 5,, 7
	decl	%esp
	jnz	L(bench_loop)
#if BINOUT
	movq	%rdx, %rcx
	RDTSC_TO_RDX ()
	subq	%rcx, %rdx
	WRITE_REG_STDOUT (rdx)
#endif
	vzeroupper
	movl	$60, %eax
	xorl	%edi, %edi
	syscall

#if 0
	.section .rodata
	.balign	4096
buf_start:	.space 4096
buf_end:
#endif
