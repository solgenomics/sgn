use strict;
use warnings;

use CXGN::Page;

our $c;
my $p = CXGN::Page->new("Ontology Browser", "Lukas");


$p->header("Ontology Browser", "Browse Ontologies");

print $c->render_mason("/ontology/browser.mas");

$p->footer();
