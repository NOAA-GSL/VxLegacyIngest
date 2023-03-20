##############################################################################
#
# FSL/FRD wide wide "$HOME/.login" file
# Updated 12/06/97 -- DSB
#
##############################################################################
#                                                                            #
# PLEASE NOTE:								     #
#                                                                            #
#       This new "~/.login" file is re-designed to initialize every user's   #
#	  environment in a basic and similar manner.  Any user changes or    #
#	  additions are made in the "~/.login" file.  The user's "~/.login"  #
#	  file sources the master Login file.				     #
#                                                                            #
#	The file, "/usr/local/share/lib/login/Login", is sourced in by this  #
#	  "~/.login" file to allow your Systems Administrator to add/edit    #
#	  FRD-wide components in your environment without you having to	     #
#	  add/edit them yourself.					     #
#                                                                            #
##############################################################################
##############################################################################
#                                                                            #
# WARNING:                                                                   #
# --------                                                                   #
# DO NOT CHANGE ANY OF THESE NEXT FEW ITEMS UNLESS YOU ARE WILLING TO        #
# TAKE CARE OF THESE SETTINGS IN YOUR OWN LOGIN ENVIRONMENT!                 #
#                                                                            #
##############################################################################
 
if ( -f /usr/local/share/lib/login/Login ) then
        source /usr/local/share/lib/login/Login
endif
 
#____________________________________________________________________________#
# ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^#
# DO _NOT_ CHANGE ANYTHING ABOVE THIS LINE                                   #
#----------------------------------------------------------------------------#
# YOU _MAY_ CHANGE OR ADD ANYTHING BELOW THIS LINE EXCEPT WHERE NOTED        #
# v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v v#
#____________________________________________________________________________#

#newgrp rtvs
setenv XAPPLRESDIR ~/app-defaults
#emacs&
#setenv EDITOR emacsclient
setenv TZ 'GMT'
umask 0002

#echo "LOGIN called!"
#date
#echo ""

# END
