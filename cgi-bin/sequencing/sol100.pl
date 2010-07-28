use strict;
use warnings;
use CXGN::Page;
use CXGN::Login;


my $page = CXGN::Page->new("SOL100 sequencing project","Naama");
my $dbh = $page->get_dbh;
my ($person_id, $user_type)=CXGN::Login->new($dbh)->has_session();
my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
my $cvterm = $schema->resultset("Cv::Cvterm")->search( { name => 'sol100' } );
my $o_props;
my $organism_res;

$o_props= $cvterm->search_related('organismprops') if $cvterm;

my $sol=();

while(my $o_prop=$o_props->next){
    print STDERR "$o_prop\n\n\n";
    my ($organism)=$o_prop->search_related('organism');
    
    my $organism_id = $organism->organism_id;
    print STDERR "$organism_id\n\n\n";
    $sol->{$organism->species}= $organism_id;
}

$c->forward_to_mason_view("/sequencing/sol100.mas" , user_type=>$user_type, schema=>$schema, sol=>$sol );









