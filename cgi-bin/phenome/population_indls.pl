#!/usr/bin/perl -w

=head1 DESCRIPTION
redirects to qtl_analysis.pl

=cut

use strict;
use warnings;


use CGI;

my $cgi = CGI->new();
my $pop_id  = $cgi->param('population_id');
my $term_id = $cgi->param('cvterm_id');

print $cgi->redirect("qtl_analysis.pl?population_id=$pop_id&cvterm_id=$term_id", 301);
