use strict;
use warnings;

use CXGN::Page;

use CatalystX::GlobalContext qw( $c );
my $p = CXGN::Page->new("Ontology Browser", "Lukas");


$p->header("Ontology Browser", "Browse Ontologies");

print $c->render_mason("/ontology/browser.mas");

$p->footer();
