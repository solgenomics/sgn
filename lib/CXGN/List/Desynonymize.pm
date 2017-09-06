package CXGN::List::Desynonymize;

use Moose;
use CXGN::Stock::StockLookup;

use Module::Pluggable require => 1;

my %stock_list_type_hash = (
    'seedlots'=>'seedlot',
    'plots'=>'plot',
    'accessions'=>'accession',
    'vector_constructs'=>'vector_construct',
    'crosses'=>'cross',
    'populations'=>'population',
    'plants'=>'plant'
);

sub desynonymize {
    my $self = shift;
    my $schema = shift; # dbschema
    my $type = shift; # a stock type
    my $list = shift; # an array ref to an array of stock names
    
    #check if list is a stock list
    my $match = 0;
    my @stock_types = ('seedlots', 'plots', 'accessions', 'vector_constructs', 
    'crosses', 'populations', 'plants');
    foreach my $stock_type (@stock_types) {
        if( $stock_type eq $type ){
            $match = 1;
            last;
        }
    }
    if ($match==0){
        return {
            success => "0",
            error => "not a stock list"
        };
    }
    else{
        my $stocklookup = CXGN::Stock::StockLookup->new({ schema => $schema});
        my $unique = $stocklookup->get_stock_synonyms('any_name',$stock_list_type_hash{$type},$list);
        # my @already_unique = ();
        # my @changed = ();
        # my @missing = ();
        # foreach my $old_name (@{$list}){
        #     if (defined $unique->{$old_name}){
        #         push @already_unique, $old_name;
        #     } else {
        #         UNFOUND: {
        #             while (my ($uniq_name, $synonyms) = each %{$unique}){
        #                 foreach my $synonym (@{$synonyms}){
        #                     if ($old_name eq $synonym){
        #                         push @changed, [$old_name,$uniq_name];
        #                         last UNFOUND;
        #                     }
        #                 }
        #             }
        #             push @missing, $old_name;
        #         }
        #     }
        # }
        my @unique_list = keys %{$unique};
        return {
            success => "1",
            list => \@unique_list,
            synonyms => $unique
            # unchanged => \@already_unique, 
            # changed => \@changed, 
            # absent => \@missing
        };
    }
}

1;
