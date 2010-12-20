
#!/usr/bin/perl -w

=head1 DESCRIPTION
redirects old links out there on the web..
=cut
use strict;
use CGI;

my $cgi = CGI->new();
print  $cgi->redirect(-uri =>"qtl_search_help.pl", -status=>301);
