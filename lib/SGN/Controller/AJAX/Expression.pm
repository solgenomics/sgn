
package SGN::Controller::AJAX::Expression;

use Moose;

use strict;
use warnings;

use CXGN::DB::DBICFactory;
use CXGN::GEM::Schema;
use CXGN::GEM::Template;
use CXGN::GEM::Expression;
# use Data::Dumper;

use CXGN::DB::Connection;
use CXGN::GEM::Schema::GeTemplate;
use CXGN::Chado::Dbxref::DbxrefI;

use CXGN::Page::FormattingHelpers qw| page_title_html info_table_html hierarchical_selectboxes_html |;
use CXGN::Page::UserPrefs;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );

our %urlencode;


sub get_data :Path('/tools/expression/result') :Args(0) { 
    my ($self, $c) = @_;
    
	# declare variables
	my @all_data;
	my %exp_design;
    my $template_id;
    my $query_gene = $c->req->param("gene");
    $query_gene =~ s/\s+//g;

    # to store errors as they happen
    my @errors; 
	
	
	# get all data from the query gene
    my @schema_list = ('gem', 'biosource', 'metadata', 'public');
    my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::GEM::Schema', search_path => \@schema_list, );
    my @template_array = CXGN::GEM::Template->new_by_name($schema, $query_gene);



    ## Add expression object
    foreach my $template (@template_array) {
		if (!defined $template || !defined $template->get_template_id()) {
			push (@errors, "The query gene is not available in our database. Please try again\n");
		} else {
			$template_id = $template->get_template_id();
			print "id: $template_id\n";
			
			# get the experiment data from each experiment
			my ($exp_data, $design_name, $design_desc, $exp_dbxref,$exp_pub) = get_expression_data($template_id,$schema);
			
			$exp_design{"name"} = $design_name;
			$exp_design{"description"} = $design_desc;
			$exp_design{"dbxref"} = $exp_dbxref;
			$exp_design{"pub"} = $exp_pub;
			$exp_design{"data"} = $exp_data;
			
			# save the final structure of data; An array containing one hash for each experiment
			push(@all_data, \%exp_design);
		}
    }

	# print STDERR "my data: ".Dumper(@all_data)."\n";
	# print STDERR "my data: ".Dumper($all_data[0]{"data"})."\n";


#   print STDERR "final design:".Dumper(@all_design_data)."\n";
	
	# return errors if needed
    if (scalar (@errors) > 0){
		my $user_errors = join("<br />", @errors);
		$c->stash->{rest} = {error => $user_errors};
		return;
    }
	
	# return dat to mason view
    $c->stash->{rest} = {
		gene_id => $template_id,
		gene_name => $query_gene,
		all_exp_design =>\@all_data,
    };

}



sub get_expression_data {
    my $template_id = shift;
    my $schema = shift;
    my @one_design;
    my @one_experiment;
    my $experiment;
	
	my $title;
	my $journal;
	my $pyear;
	
	#----------------------------------
	my %one_exp;
	my @all_exp;
	my @all_data;
	#----------------------------------

    my @exp_exp_values_rows = $schema->resultset('GeExpressionByExperiment')
                                     ->search( { template_id => $template_id } );
	
#   print STDERR "rows: ".Dumper(@exp_exp_values_rows)."\n";

	foreach my $expexp_value_row (@exp_exp_values_rows) {
		my %exp_values = $expexp_value_row->get_columns();

		my $exp_id = $exp_values{'experiment_id'};
		$one_experiment[0] = $exp_id;

		$experiment = CXGN::GEM::Experiment->new($schema, $exp_id);

		if (defined $experiment && defined $experiment->get_experiment_id() ) {
    
			my $exp_name = $experiment->get_experiment_name();
#			print STDERR "\nEXP_NAME: $exp_name\n";

			my $exp_rep = $exp_values{'replicates_used'} || 'NA';

			my $fpkm = Math::BigFloat->new( $exp_values{'mean'})
                                         ->ffround(-2)
					 ->bstr();
 
			# my $median = Math::BigFloat->new( $exp_values{'median'} )
			#                                            ->ffround(-2)
			# 		   ->bstr();

			my $fpkm_lo = Math::BigFloat->new($exp_values{'standard_desviation'})
                                       ->ffround(-2)
				       ->bstr();

			my $fpkm_hi = Math::BigFloat->new($exp_values{'coefficient_of_variance'})
                                       ->ffround(-2)
				       ->bstr();

			$one_exp{"name"} = $exp_name;
			$one_exp{"id"} = $exp_id;
			$one_exp{"replicates"} = $exp_rep;
			$one_exp{"fpkm"} = $fpkm;
			$one_exp{"fpkm_lo"} = $fpkm_lo;
			$one_exp{"fpkm_hi"} = $fpkm_hi;
			$one_exp{"exp_description"} = $experiment->get_description();



		    ## Get the external links for experiment conditions
		     my @exp_dbxref_ids = $experiment->get_dbxref_list();
			 my $exp_dbxref_html = "";
			 
		     foreach my $dbxref_id (@exp_dbxref_ids) {
				 $exp_dbxref_html = "$exp_dbxref_html ".get_dbxref_html($dbxref_id, $schema);
		     }
			 
			 print STDERR "SRA dbxref: $exp_dbxref_html\n";
 			$one_exp{"exp_links"} = $exp_dbxref_html;
			 

#	    my @target_list = $experiment->get_target_list();
#           my $tissue = set_tissue($target_list[0]);

		}
	#	print STDERR "one exp:".Dumper(@one_experiment)."\n";
		my %tmp_hash = %one_exp;
		push (@all_exp, \%tmp_hash);
		# %one_exp;
		
		
		# push (@all_exp, %one_exp);
		# %one_exp;
    }
	
    my $expdesign = $experiment->get_experimental_design();
    my $expdesign_name = $expdesign->get_experimental_design_name();
    my $expdesign_desc = $expdesign->get_description();
	my $pub_html = '';
	my $expdesign_dbxref_html = '';
	
    #print STDERR "$expdesign_name: experiment replicates: $exp_rep\n\n";
	
	# get exp_design publications
	my @pub_id_list = $expdesign->get_publication_list();
	# my @pub_title_list = $expdesign->get_publication_list('title');
	# my @pub_journal_list = $expdesign->get_publication_list('series_name');
	# my @pub_year_list = $expdesign->get_publication_list('pyear');



	my @dbxref_id_list = $expdesign->get_dbxref_list();
	
	for (my $i = 0; $i < scalar(@pub_id_list); $i++) {
		if ($pub_id_list[$i]) {
			
			$expdesign_dbxref_html = "$expdesign_dbxref_html ".get_dbxref_html($dbxref_id_list[$i], $schema);
			

			my ($pub_obj) = $schema->resultset('Pub::Pub')
			                               ->search({ pub_id => $pub_id_list[$i]});
										   

			$title = $pub_obj->get_column('title');
			$journal = $pub_obj->get_column('series_name');
			$pyear = $pub_obj->get_column('pyear');
			
			
		}
		if ($title && $journal && $pyear) {
			$pub_html = "$pub_html $title $journal $pyear.<br/>\n";
		} 
		elsif ($title) {
			$pub_html = "$pub_html $title<br/>\n";
		}

	}
	# print STDERR "$expdesign_dbxref_html\n";
	
	# my $exp_design_description = "<b>$expdesign_name:</b> $expdesign_desc.";
	
	# if ($expdesign_dbxref_html ne '') {
	# 	$exp_design_description = "$exp_design_description\n<br/><b>External links:</b> $expdesign_dbxref_html\n";
	# 	# $exp_design_description = "$exp_design_description\n<b>External link:</b> $pub_dbxref_html\n";
	# }
	# if ($pub_dbxref_html ne '') {
	# 	$exp_design_description = "$exp_design_description\n<br/><b>Publications:</b> $pub_dbxref_html\n";
	# 	# $exp_design_description = "$exp_design_description\n<b>External link:</b> $pub_dbxref_html\n";
	# }
	
	# push (@all_data, %exp_design);
	
    return (\@all_exp,$expdesign_name,$expdesign_desc,$expdesign_dbxref_html,$pub_html);
    # return (\@one_design,$expdesign_name);
}

sub get_dbxref_html {
	my $dbxref_id = shift;
	my $schema = shift;
	my $dbxref_html;
	
	my ($dbxref_obj) = $schema->resultset('General::Dbxref')
	                              ->search({ dbxref_id => $dbxref_id });

	if (defined $dbxref_obj) {
	    my ($db_obj) = $schema->resultset('General::Db')
	                              ->search({ db_id => $dbxref_obj->get_column('db_id') });
            
	    my $dbxref_url = $db_obj->get_column('urlprefix').$db_obj->get_column('url').$dbxref_obj->get_column('accession');
	    $dbxref_html = "<a href='".$dbxref_url."'  target='_blank'>".$db_obj->get_column('name').":".$dbxref_obj->get_column('accession')."</a>";
	}
	
	return $dbxref_html;
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
