use strict;
use warnings;

my $schema = $c->dbic_schema('Bio::Chado::Schema');
$c->forward_to_mason_view('/genomes/Solanum_lycopersicum/publications.mas', schema => $schema);
