

package SGN::Controller::Analyze::Phenotypes;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use strict;
use warnings;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::Download;
use POSIX qw(strftime);

sub load_analyze_phenotypes : Path('/analyze/phenotypes') Args(0) { 
    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    
    $c->stash->{template} = '/analyze/phenotypes.mas';
}

sub analyze_phenotypes_action : Path('/analyze/phenotypes/action') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $accession_list_id = $c->req->param("accession_list_list_select");
    my $trial_list_id     = $c->req->param("trial_list_list_select");
    my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $format            = $c->req->param("format");
    my $cookie_value      = $c->req->param("analyze_token_value"); 

    my $accession_data;
    if ($accession_list_id) { 
	$accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    }

    my $trial_data;
    if ($trial_list_id) { 
	$trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
    }

    my $trait_data;
    if ($trait_list_id) { 
	$trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);
    }

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
    my @trait_list = map { $_->[1] } @$trait_data;

    my $tf = CXGN::List::Transform->new();
    
    my $unique_transform = $tf->can_transform("accession_synonyms", "accession_names");
    
    my $unique_list = $tf->transform($c->dbic_schema("Bio::Chado::Schema"), $unique_transform, \@accession_list);
    
    # get array ref out of hash ref so Transform/Plugins can use it
    my %unique_hash = %$unique_list;
    my $unique_accessions = $unique_hash{transform};

    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, $unique_accessions);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    my $trait_t = $t->can_transform("traits", "trait_ids");
    my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    my $trait_sql = join ",", map { "\'$_\'" } @{$trait_id_data->{transform}};

    my $output = "";
    my $result = $bs->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
    my @data = @$result;

	    # if xls or csv, create tempfile name and place to save it
	    my $what = "analyze_phenotype";
	    my $time_stamp = strftime "%Y-%m-%dT%H%M%S", localtime();
	    my $dir = $c->tempfiles_subdir('analyze');
	    my $temp_file_name = $time_stamp . "$what" . "XXXX";
	    my $rel_file = $c->tempfile( TEMPLATE => "analyze/$temp_file_name");
	    my $tempfile = $c->config->{basepath}."/".$rel_file;
	    my @col_names = qw/year project_name stock_name location trait value plot_name cv_name cvterm_accession rep block_number/;
	    
	    if ($format eq ".csv") {
		
		#build csv with column names
		open(CSV, ">", $tempfile) || die "Can't open file $tempfile\n";
		print CSV join(",", @col_names);
		print CSV "\n"; 
		for (my $line =0; $line< @data; $line++) { 
		    my @columns = @{$data[$line]};
		    print CSV join(",", @columns);
		    print CSV "\n";
		}
		close CSV;
		
	    } else {
		
		#build excel file; include column names
		my $ss = Spreadsheet::WriteExcel->new($tempfile);
		my $ws = $ss->add_worksheet();
		
		for (my $column =0; $column< @col_names; $column++) {
		    $ws->write(0, $column, $col_names[$column]);
		}
		for (my $line =0; $line < @data; $line++) {
		    my @columns = @{$data[$line]};
		    for(my $col = 0; $col<@columns; $col++) { 
			$ws->write(($line+1), $col, $columns[$col]);
		    }
		}
		$ss ->close();
		$format = ".xls";
	    }
	    
	    #Using tempfile and new filename,send file to client
	    my $file_name = $time_stamp . "$what" . "$format";
	    $c->res->content_type('Application/'.$format);
	    $c->res->cookies->{fileDownloadToken} = { value => $cookie_value};
	    $c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
	    $output = read_file($tempfile);
	    $c->res->body($output);   
}


1;
