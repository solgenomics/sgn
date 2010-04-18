
use strict;

use CXGN::DB::Connection;

my $dbh = CXGN::DB::Connection->new();

$c->forward_to_mason_view('/cview/index.mas', dbh=>$dbh);



# #!/usr/bin/perl
# ######################################################################
# #
# #  Program:  $Id: mapviewerHome.pl 1445 2005-06-08 14:29:30Z john $
# #  Author:   $Author: john $
# #  Date:     $Date: 2005-06-08 10:29:30 -0400 (Wed, 08 Jun 2005) $
# #  Version:  1.0
# #  CHECKOUT TAG: $Name:  $
# #  
# ######################################################################

# =head1 Name

# cview/index.pl

# =head1 Description

# Displays a html page with links to all SGN maps and related information. It takes no parameters.

# =head1 Author

# Initial version by Robert Ahrens, later maintainers were John Binns and/or Lukas Mueller.

# This version was written by Lukas Mueller <lam87@cornell.edu>

# =cut

