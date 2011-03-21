#!/usr/bin/perl -w

=head1 DESCRIPTION
a redirect for phenome/population_indls.pl to phenome/qtl_analysis.pl: for links from the qtl ms and may be more...

=cut

use strict;
use CGI;

use CatalystX::GlobalContext qw( $c );

my $cgi = CGI->new();
my $pop_id = $cgi->param('population_id');
my $term_id = $cgi->param('cvterm_id');


print $cgi->redirect("qtl_analysis.pl?population_id=$pop_id&cvterm_id=$term_id", 301);


#$c->forward_to_mason_view('/qtl/qtl_analysis.mas',
#                          url           => '/phenome/qtl_analysis.pl',
#                          population_id => $pop_id,
#                          cvterm_id     => $term_id
#    );
