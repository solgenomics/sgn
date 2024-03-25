use CatalystX::GlobalContext qw( $c );
use strict;
use warnings;

my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
my $schema = $c->dbic_schema('Bio::Chado::Schema', undef, $sp_person_id);
$c->forward_to_mason_view('/genomes/Solanum_lycopersicum/publications.mas', schema => $schema);
