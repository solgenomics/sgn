#!/usr/bin/perl -w

=head1 DESCRIPTION
a redirect for a wrong url (/population.pl?population_id=12) 
in qtl paper http://www.biomedcentral.com/1471-2105/11/525/abstract/

--pending a better solution...

=head1 AUTHOR

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;
use CGI;

my $cgi = CGI->new();
my $pop_id = $cgi->param('population_id');

print  $cgi->redirect(-uri =>"phenome/population.pl?population_id=$pop_id", -status=>301);

