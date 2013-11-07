
package SGN::Controller::AJAX::Expression;

use Moose;

use strict;
use warnings;

use CXGN::DB::DBICFactory;
use CXGN::GEM::Schema;
use CXGN::GEM::Template;
use CXGN::GEM::Expression;
use Data::Dumper;

use CXGN::DB::Connection;
use CXGN::GEM::Schema::GeTemplate;

use CXGN::Page::FormattingHelpers qw| page_title_html info_table_html hierarchical_selectboxes_html |;
use CXGN::Page::UserPrefs;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

our %urlencode;


sub get_data :Path('/tools/expression/result') :Args(0) { 
    my ($self, $c) = @_;
    
    my $query_gene = $c->req->param("gene");
    my $expdesign_name;
    my $template_id;
#    print "gene: $query_gene\n\n";

    # to store erros as they happen
    my @errors; 

    # to store all data for each experimental design
    my @all_design_data;
    my @one_design;
    my @one_experiment;

    ## Create the schema object
    my $psqlv = `psql --version`;
    chomp($psqlv);

    my @schema_list = ('gem', 'biosource', 'metadata', 'public');

    my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::GEM::Schema', search_path => \@schema_list, );

    ## Get template object (by default it will create an empty template object)
    my $template = CXGN::GEM::Template->new($schema);
    $template = CXGN::GEM::Template->new_by_name($schema, $query_gene);


#    foreach my $t_el (@template_array) {
#	my $t_id = $t_el->get_template_id();
#	print STDERR "t_id: $t_id\n";

#    }

    #my $template_type = $template->get_template_type();

    ## Add expression object
    #my $expression = CXGN::GEM::Expression->new($schema);

    if (!defined $template || !defined $template->get_template_id()) {
	push (@errors, "The query gene is not available in our database. Please try again\n");
    } else {
	## Get schema
#	my $schema = $template->get_schema();

	## Get the template_id and all the expression_experiment_values associated to them with the experimental design
	#my (%exp_info, %expdes_info);

	$template_id = $template->get_template_id();
	print "id: $template_id\n";

	my @exp_exp_values_rows = $schema->resultset('GeExpressionByExperiment')
                                     ->search( { template_id => $template_id } );
	

#	print STDERR "rows: ".Dumper(@exp_exp_values_rows)."\n";

	foreach my $expexp_value_row (@exp_exp_values_rows) {
	    my %exp_values = $expexp_value_row->get_columns();

	    my $exp_id = $exp_values{'experiment_id'};
	    $one_experiment[0] = $exp_id;

	    my $experiment = CXGN::GEM::Experiment->new($schema, $exp_id);

	    if (defined $experiment && defined $experiment->get_experiment_id() ) {
    
      		my $exp_name = $experiment->get_experiment_name();
		print STDERR "\nEXP_NAME: $exp_name\n";

		my $exp_rep = $exp_values{'replicates_used'} || 'NA';

		my $mean = Math::BigFloat->new( $exp_values{'mean'})
                                         ->ffround(-2)
					 ->bstr();
 
		my $median = Math::BigFloat->new( $exp_values{'median'} )
                                           ->ffround(-2)
					   ->bstr();

		my $sd = Math::BigFloat->new($exp_values{'standard_desviation'})
                                       ->ffround(-2)
				       ->bstr();

		my $cv = Math::BigFloat->new($exp_values{'coefficient_of_variance'})
                                       ->ffround(-2)
				       ->bstr();


#		my $exp_rep = $experiment->get_replicates_nr();
          	push (@one_experiment, $exp_name);
          	push (@one_experiment, $exp_rep);
          	push (@one_experiment, $mean);
          	push (@one_experiment, $median);
          	push (@one_experiment, $sd);
          	push (@one_experiment, $cv);

		my $expdesign = $experiment->get_experimental_design();

		$expdesign_name = $expdesign->get_experimental_design_name();

		#print STDERR "$expdesign_name: experiment replicates: $exp_rep\n\n";

		my @target_list = $experiment->get_target_list();

                my $tissue = set_tissue($target_list[0]);

	    }
#	    print STDERR "one exp:".Dumper(@one_experiment)."\n";
	    my @tmp_array = @one_experiment;
	    push (@one_design, \@tmp_array);
	    @one_experiment = [];

        }
    }
#	    print STDERR "final design:".Dumper(@one_design)."\n";

    if (scalar (@errors) > 0){
	my $user_errors = join("<br />", @errors);
	$c->stash->{rest} = {error => $user_errors};
	return;
    }

    print STDERR "gene: $query_gene\n";
    #print STDERR "mydata: ".Dumper(@one_design)."\n";

    $c->stash->{rest} = {
			 gene_id => $template_id,
			 gene_name => $query_gene,
	                 all_exp_design =>[ @one_design ]
    };

}


sub set_tissue {
    my $first_target = shift;
    my $dbh = CXGN::DB::Connection->new();
    my $tissue;
    my @sample_list = $first_target->get_sample_list();

    foreach my $sample (@sample_list) {
        my %po = $sample_list[0]->get_dbxref_related('PO');
                    
	foreach my $sample_dbxref_id (keys %po) {
	    my %dbxref_po = %{ $po{$sample_dbxref_id} };
	    my $po_name = $dbxref_po{'cvterm.name'};

	    my $cvterm = CXGN::Chado::Cvterm->new( $dbh, $dbxref_po{'cvterm.cvterm_id'} );
	    my $accession   = $cvterm->get_accession;
			
#	    print STDERR "$accession: $po_name\n";
	}
    }
    return $tissue;
}



1;
