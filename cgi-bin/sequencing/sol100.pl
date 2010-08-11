use strict;
use warnings;
use CXGN::Login;
use CXGN::Chado::Organism;



our $c;

my $dbh = $c->dbc->dbh;
my ($person_id, $user_type)=CXGN::Login->new($dbh)->has_session();
my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
my $cvterm = $schema->resultset("Cv::Cvterm")->search( { name => 'sol100' } );
my $o_props;
my $organism_res;

$o_props= $cvterm->search_related('organismprops') if $cvterm;

my $sol=();

while(my $o_prop=$o_props->next){
    my ($organism)=$o_prop->search_related('organism');
    
    my $organism_id = $organism->organism_id;
    $sol->{$organism->species}= $organism_id;
}

$c->forward_to_mason_view("/sequencing/sol100.mas" , user_type=>$user_type, schema=>$schema, sol=>$sol );
