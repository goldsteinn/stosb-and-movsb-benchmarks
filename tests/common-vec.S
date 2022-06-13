#ifndef STOSB_MOVSB_PERF__TESTS__COMMON_VEC_S_
# define STOSB_MOVSB_PERF__TESTS__COMMON_VEC_S_

# if VEC_SIZE == 8
#  define VEC				rax
#  define vmovu				movq
#  define vmova				movq
#  define vmovnt				movnti
#  define SET_VEC(v)			movq $v, %rax
# elif VEC_SIZE == 16
#  define VEC				xmm0

#  define VEC0				xmm0
#  define VEC1				xmm1
#  define VEC2				xmm2
#  define VEC3				xmm3

#  define vmovu				vmovdqu
#  define vmova				vmovdqa
#  define vmovnt				movntdq
# elif VEC_SIZE == 32
#  define VEC				ymm0

#  define VEC0				ymm0
#  define VEC1				ymm1
#  define VEC2				ymm2
#  define VEC3				ymm3


#  define vmovu				vmovdqu
#  define vmova				vmovdqa
#  define vmovnt				vmovntdq
# else
#  define VEC				zmm0

#  define VEC0				zmm0
#  define VEC1				zmm1
#  define VEC2				zmm2
#  define VEC3				zmm3


#  define vmovu				vmovdqu64
#  define vmova				vmovdqa64
#  define vmovnt				vmovntdq
# endif

# ifndef SET_VEC
#  define SET_VEC(v)	\
	movq	$v, %rbp;	\
	vpbroadcastq %rbp, %VEC;
# endif

#endif
