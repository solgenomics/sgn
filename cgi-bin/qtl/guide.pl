use CatalystX::GlobalContext qw( $c );
#!/usr/bin/perl -w

=head1 DESCRIPTION
easy to remember url redirect to the googledoc QTL guidelines page;

=head1 AUTHOR

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;
use CGI;

print  CGI->new()->redirect(-uri =>'http://docs.google.com/View?id=dgvczrcd_1c479cgfb', -status=>301);


#$c->forward_to_mason_view('/qtl/guide.mas', redir=>$redir);
