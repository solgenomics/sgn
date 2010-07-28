use strict;
use warnings;

use CXGN::Page;
use CXGN::Login;


my $page = CXGN::Page->new("SOL100 sequencing project","Naama");
my $dbh = $page->get_dbh;

#my $login = CXGN::Login->new($dbh);
#my ($person_id) = $login->verify_session('submitter');
my ($person_id, $user_type)=CXGN::Login->new($dbh)->has_session();
my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

#my @species= ('Solanum lycopersicum', 'Solanum pennellii', 'Solanum pimpinellifolium', 'Solanum galapagense');

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


# if ($organism_res) {
#     my @organisms = $organism_res->all();
#     foreach my $o (@organisms){
# 	if (defined $o){
# 	    my $organism_id = $o->organism_id();
# 	    $sol->{$species}= $organism_id ;
# 	}
#     }

$c->forward_to_mason_view("/sequencing/sol100.mas" , user_type=>$user_type, schema=>$schema, sol=>$sol );



##########









# use strict;
# use CXGN::Page;
# use CXGN::Chado::Organism;
# use CXGN::DB::DBICFactory;

# my $page   =  CXGN::Page->new("SOL100 sequencing project","Dean");

# my $schema =  CXGN::DB::DBICFactory->open_schema( 'Bio::Chado::Schema' );

# my @species= ('Solanum lycopersicum', 'Solanum pennellii', 'Solanum pimpinellifolium',); #'Solanum galapagense');

# my $sol=();

# foreach my $s (@species) {
#     my $organism= CXGN::Chado::Organism->new_with_species($schema, $s);
#     my $organism_id = $organism->get_organism_id();
#     $sol->{$s}= $organism_id ;
# }

# $c->forward_to_mason_view("/sequencing/sol100.mas" , schema=>$schema, sol=>$sol );


