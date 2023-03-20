dnl define(diversion_number, divnum)dnl
dnl divert(-1)


dnl Locate the perl(1) utility.
dnl
AC_DEFUN([NP_PROG_PERL], [dnl
    case "$PERL" in
	'')
	    AC_PROGRAMS_CHECK(PERL, perl)dnl
	    case "$PERL" in
		'') UC_NEED_VALUE(PERL, [perl utility], /usr/local/bin/perl)
		    ;;
		*)  AC_SUBST(PERL)
		    ;;
	    esac
	    ;;
	*)
	    AC_MSG_CHECKING(for perl utility)
	    AC_SUBST(PERL)
	    AC_MSG_RESULT($PERL)
	    ;;
    esac
])

dnl Decide the value of the perl POLLUTE variable.
dnl
AC_DEFUN([NP_POLLUTE_PERL], [dnl
    AC_REQUIRE([NP_PROG_PERL])
    AC_MSG_CHECKING(for value of perl POLLUTE variable)
    case "$POLLUTE" in
	'') case "`$PERL -v`" in
		*5.005*|*5.6.0*) POLLUTE=1 ;;
		*)              POLLUTE=0 ;;
	    esac
	    ;;
    esac
    AC_SUBST(POLLUTE)
    AC_MSG_RESULT($POLLUTE)
])


dnl Locate the perl(1) manual page directory.
dnl
AC_DEFUN([NP_MANDIR_PERL], [dnl
    AC_REQUIRE([NP_PROG_PERL])
    AC_MSG_CHECKING(for perl manual page directory)
    pre=`echo $PERL | sed 's:/[[^/]]*$::'`
    UC_TEST_DIR(PERL_MANDIR, $pre/../man /usr/man /usr/local/man, man1/perl.1,
		[perl manual directory], /usr/local/man)dnl
    AC_SUBST(PERL_MANDIR)
    AC_MSG_RESULT($PERL_MANDIR)
])


dnl Locate the perl(1) source distribution.
dnl
AC_DEFUN([NP_SRCDIR_PERL], [dnl
    AC_MSG_CHECKING(for perl source directory)
    case "$PERL_SRCDIR" in
	'')
	    dirs=`ls -d /usr/local/src/perl* | sort -r`
	    case "$dirs" in
		'')
		    UC_NEED_VALUE(PERL_SRCDIR, [perl source directory],
				  /usr/local/src/perl5)
		    ;;
		*)  
		    for dir in $dirs; do
			if test -r $dir/perl.c; then
			    PERL_SRCDIR=$dir
			    break;
			fi
		    done
		    case "$dir" in
			'')
			    UC_NEED_VALUE(PERL_SRCDIR, [perl source directory],
					  /usr/local/src/perl5)
			    ;;
			*)
			    PERL_SRCDIR=$dir
			    AC_SUBST(PERL_SRCDIR)
			    AC_MSG_RESULT($PERL_SRCDIR) 
			    ;;
		    esac
	    esac
	    ;;
	*)
	    AC_SUBST(PERL_SRCDIR)
	    AC_MSG_RESULT($PERL_SRCDIR) 
	    ;;
    esac
])


dnl divert(diversion_number)dnl
