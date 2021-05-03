
package CXGN::List::Validate::Plugin::Accessions;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
#use Hash::Case::Preserve;

sub name { 
    return "accessions";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

#    tie my(%all_names), 'Hash::Case::Preserve';
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();


    my @missing;
    my @wrong_case;
    my @multiple_wrong_case;
    
    foreach my $item (@$list) {
	my $rs = $schema->resultset("Stock::Stock")->search(
	    { uniquename => { '~*' => $item },
	      'me.type_id' => $accession_type_id,
	      is_obsolete => 'F' },
	    { join => 'stockprops',
	      '+select' => [ 'stockprops.value', 'stockprops.type_id' ] ,
	      '+as' => [ 'stockprop_value', 'stockprop_type_id' ]
	    });

	if ($rs->count() == 0) {
	    push @missing, $item;
	}

	elsif ($rs->count() == 1) {
	    my $row = $rs->next();
	    if ($row->uniquename() ne $item) {
		push @wrong_case, [ $item, $row->uniquename() ];
	    }
	}

	elsif ($rs->count() > 1) {
	    while(my $row = $rs->next()) { 
		push @multiple_wrong_case, [ $item, $row->uniquename() ];
	    }
	}
	    
    }


    return {
	missing => \@missing,
	wrong_case => \@wrong_case,
	multiple_wrong_case => \@multiple_wrong_case,
    };
}

1;
