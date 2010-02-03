use strict;

use CXGN::Chado::Phenotype;
use CXGN::DB::Connection;




#sub new {
#    my $self=shift;
    my $dbh = CXGN::DB::Connection->new();   
    my $phenotype = CXGN::Chado::Phenotype->new($self->get_phenotype_id, $dbh)
    
    my $phenotype_id = $phenotype->get_phenotype_id();
    my $value = $phenotype->value();

print STDERR "phenotype id: $phenotype_id value: $value \n";



