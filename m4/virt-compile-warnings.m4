dnl
dnl Enable all known GCC compiler warnings, except for those
dnl we can't yet cope with
dnl
AC_DEFUN([LIBVIRT_COMPILE_WARNINGS],[
    dnl ******************************
    dnl More compiler warnings
    dnl ******************************

    LIBVIRT_ARG_ENABLE([WERROR], [Use -Werror (if supported)], [check])
    if test "$enable_werror" = "check"; then
        if test -d $srcdir/.git; then
            is_git_version=true
            enable_werror=yes
        else
            enable_werror=no
        fi
    fi

    # List of warnings that are not relevant / wanted

    # Don't care about C++ compiler compat
    dontwarn="$dontwarn -Wc++-compat"
    dontwarn="$dontwarn -Wabi"
    dontwarn="$dontwarn -Wdeprecated"
    # Don't care about ancient C standard compat
    dontwarn="$dontwarn -Wtraditional"
    # Don't care about ancient C standard compat
    dontwarn="$dontwarn -Wtraditional-conversion"
    # Ignore warnings in /usr/include
    dontwarn="$dontwarn -Wsystem-headers"
    # Happy for compiler to add struct padding
    dontwarn="$dontwarn -Wpadded"
    # GCC very confused with -O2
    dontwarn="$dontwarn -Wunreachable-code"
    # Too many to deal with
    dontwarn="$dontwarn -Wconversion"
    # Too many to deal with
    dontwarn="$dontwarn -Wsign-conversion"
    # GNULIB gettext.h violates
    dontwarn="$dontwarn -Wvla"
    # Many GNULIB header violations
    dontwarn="$dontwarn -Wundef"
    # Need to allow bad cast for execve()
    dontwarn="$dontwarn -Wcast-qual"
    # We need to use long long in many places
    dontwarn="$dontwarn -Wlong-long"
    # We allow manual list of all enum cases without default:
    dontwarn="$dontwarn -Wswitch-default"
    # Not a problem since we don't use -fstrict-overflow
    dontwarn="$dontwarn -Wstrict-overflow"
    # Not a problem since we don't use -funsafe-loop-optimizations
    dontwarn="$dontwarn -Wunsafe-loop-optimizations"
    # Things like virAsprintf mean we can't use this
    dontwarn="$dontwarn -Wformat-nonliteral"
    # Gnulib's stat-time.h violates this
    dontwarn="$dontwarn -Waggregate-return"
    # gcc 4.4.6 complains this is C++ only; gcc 4.7.0 implies this from -Wall
    dontwarn="$dontwarn -Wenum-compare"
    # gcc 5.1 -Wformat-signedness mishandles enums, not ready for prime time
    dontwarn="$dontwarn -Wformat-signedness"
    # Several conditionals expand the same on both branches
    # depending on the particular platform/architecture
    dontwarn="$dontwarn -Wduplicated-branches"
    # > This warning does not generally indicate that there is anything wrong
    # > with your code; it merely indicates that GCC's optimizers are unable
    # > to handle the code effectively.
    # Source: https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
    dontwarn="$dontwarn -Wdisabled-optimization"
    # Various valid glib APIs/macros trigger this warning
    dontwarn="$dontwarn -Wbad-function-cast"

    # Broken in 6.0 and later
    #     https://gcc.gnu.org/bugzilla/show_bug.cgi?id=69602
    AC_CACHE_CHECK([whether gcc gives bogus warnings for -Wlogical-op],
      [lv_cv_gcc_wlogical_op_equal_expr_broken], [
        save_CFLAGS="$CFLAGS"
        CFLAGS="-O2 -Wlogical-op -Werror"
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
          #define TEST1 1
          #define TEST2 TEST1
        ]], [[
          int test = 0;
          return test == TEST1 || test == TEST2;]])],
        [lv_cv_gcc_wlogical_op_equal_expr_broken=no],
        [lv_cv_gcc_wlogical_op_equal_expr_broken=yes])
        CFLAGS="$save_CFLAGS"])

    AC_CACHE_CHECK([whether clang gives bogus warnings for -Wdouble-promotion],
      [lv_cv_clang_double_promotion_broken], [
        save_CFLAGS="$CFLAGS"
        CFLAGS="-O2 -Wdouble-promotion -Werror"
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
          #include <math.h>
        ]], [[
          float f = 0.0;
	  return isnan(f);]])],
        [lv_cv_clang_double_promotion_broken=no],
        [lv_cv_clang_double_promotion_broken=yes])
        CFLAGS="$save_CFLAGS"])

    if test "$lv_cv_clang_double_promotion_broken" = "yes";
    then
      dontwarn="$dontwarn -Wdouble-promotion"
    fi

    # Clang complains about unused static inline functions
    # which are common with G_DEFINE_AUTOPTR_CLEANUP_FUNC
    AC_CACHE_CHECK([whether clang gives bogus warnings for -Wunused-function],
      [lv_cv_clang_unused_function_broken], [
        save_CFLAGS="$CFLAGS"
        CFLAGS="-Wunused-function -Werror"
        AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
           static inline void foo(void) {}
        ]], [[
          return 0]])],
        [lv_cv_clang_unused_function_broken=no],
        [lv_cv_clang_unused_function_broken=yes])
        CFLAGS="$save_CFLAGS"])

    # We might fundamentally need some of these disabled forever, but
    # ideally we'd turn many of them on
    dontwarn="$dontwarn -Wfloat-equal"
    dontwarn="$dontwarn -Wdeclaration-after-statement"
    dontwarn="$dontwarn -Wpacked"
    dontwarn="$dontwarn -Wunused-macros"
    dontwarn="$dontwarn -Woverlength-strings"
    dontwarn="$dontwarn -Wstack-protector"
    dontwarn="$dontwarn -Wsuggest-attribute=malloc"

    # Get all possible GCC warnings
    gl_MANYWARN_ALL_GCC([maybewarn])

    # Remove the ones we don't want, blacklisted earlier
    gl_MANYWARN_COMPLEMENT([wantwarn], [$maybewarn], [$dontwarn])

    # -Wunused-functin is implied by -Wall we must turn it
    # off explicitly.
    if test "$lv_cv_clang_unused_function_broken" = "yes";
    then
      wantwarn="$wantwarn -Wno-unused-function"
    fi

    # GNULIB uses '-W' (aka -Wextra) which includes a bunch of stuff.
    # Unfortunately, this means you can't simply use '-Wsign-compare'
    # with gl_MANYWARN_COMPLEMENT
    # So we have -W enabled, and then have to explicitly turn off...
    wantwarn="$wantwarn -Wno-sign-compare"
    # We do "bad" function casts all the time for event callbacks
    wantwarn="$wantwarn -Wno-cast-function-type"

    # CLang incorrectly complains about dup typedefs win gnu99 mode
    # so use this CLang-specific arg to keep it quiet
    wantwarn="$wantwarn -Wno-typedef-redefinition"

    # GNULIB expects this to be part of -Wc++-compat, but we turn
    # that one off, so we need to manually enable this again
    wantwarn="$wantwarn -Wjump-misses-init"

    # GNULIB explicitly filters it out, preferring -Wswitch
    # but that doesn't report missing enums if a default:
    # is present.
    wantwarn="$wantwarn -Wswitch-enum"

    # GNULIB turns on -Wformat=2 which implies -Wformat-nonliteral,
    # so we need to manually re-exclude it.
    wantwarn="$wantwarn -Wno-format-nonliteral"

    # -Wformat enables this by default, and we should keep it,
    # but need to rewrite various areas of code first
    wantwarn="$wantwarn -Wno-format-truncation"

    # This should be < 256 really. Currently we're down to 4096,
    # but using 1024 bytes sized buffers (mostly for virStrerror)
    # stops us from going down further
    gl_WARN_ADD([-Wframe-larger-than=4096], [STRICT_FRAME_LIMIT_CFLAGS])
    gl_WARN_ADD([-Wframe-larger-than=32768], [RELAXED_FRAME_LIMIT_CFLAGS])

    # Extra special flags
    dnl -fstack-protector stuff passes gl_WARN_ADD with gcc
    dnl on Mingw32, but fails when actually used
    case $host in
       aarch64-*-*)
       dnl "error: -fstack-protector not supported for this target [-Werror]"
       ;;
       *-*-linux*)
       dnl Prefer -fstack-protector-strong if it's available.
       dnl There doesn't seem to be great overhead in adding
       dnl -fstack-protector-all instead of -fstack-protector.
       dnl
       dnl We also don't need ssp-buffer-size with -all or -strong,
       dnl since functions are protected regardless of buffer size.
       dnl wantwarn="$wantwarn --param=ssp-buffer-size=4"
       wantwarn="$wantwarn -fstack-protector-strong"
       ;;
       *-*-freebsd*)
       dnl FreeBSD ships old gcc 4.2.1 which doesn't handle
       dnl -fstack-protector-all well
       wantwarn="$wantwarn -fstack-protector"

       wantwarn="$wantwarn -Wno-unused-command-line-argument"
       ;;
    esac
    wantwarn="$wantwarn -fexceptions"
    wantwarn="$wantwarn -fasynchronous-unwind-tables"

    # Need -fipa-pure-const in order to make -Wsuggest-attribute=pure
    # fire even without -O.
    wantwarn="$wantwarn -fipa-pure-const"
    # We should eventually enable this, but right now there are at
    # least 75 functions triggering warnings.
    wantwarn="$wantwarn -Wno-suggest-attribute=pure"
    wantwarn="$wantwarn -Wno-suggest-attribute=const"

    if test "$enable_werror" = "yes"
    then
      wantwarn="$wantwarn -Werror"
    fi

    # Request the gnu99 standard which is the best choice with
    # gcc 4.8.0. Not a warning flag, but the probing mechanism
    # is convenient
    wantwarn="$wantwarn -std=gnu99"

    # Check for $CC support of each warning
    for w in $wantwarn; do
      gl_WARN_ADD([$w])
    done

    case $host in
        *-*-linux*)
        dnl Fall back to -fstack-protector-all if -strong is not available
        case $WARN_CFLAGS in
        *-fstack-protector-strong*)
        ;;
        *)
            gl_WARN_ADD([-fstack-protector-all])
        ;;
        esac
        ;;
    esac

    case $WARN_CFLAGS in
        *-Wsuggest-attribute=format*)
           AC_DEFINE([HAVE_SUGGEST_ATTRIBUTE_FORMAT], [1], [Whether -Wsuggest-attribute=format works])
        ;;
    esac

    # Silence certain warnings in gnulib, and use improved glibc headers
    AC_DEFINE([lint], [1],
      [Define to 1 if the compiler is checking for lint.])
    AH_VERBATIM([FORTIFY_SOURCE],
    [/* Enable compile-time and run-time bounds-checking, and some warnings,
        without upsetting newer glibc. */
     #if !defined _FORTIFY_SOURCE && defined __OPTIMIZE__ && __OPTIMIZE__
     # define _FORTIFY_SOURCE 2
     #endif
    ])

    if test "$gl_cv_warn_c__Wlogical_op" = yes &&
       test "$lv_cv_gcc_wlogical_op_equal_expr_broken" = yes; then
      AC_DEFINE_UNQUOTED([BROKEN_GCC_WLOGICALOP_EQUAL_EXPR], 1,
        [Define to 1 if gcc -Wlogical-op reports false positive 'or' equal expr])
    fi
])
