
package SGN::Controller::BreedersToolbox::Download;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use URI::FromHash 'uri';
use CXGN::List::Transform;

sub breeder_download : Path('/breeders/download/') Args(0) { 
    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 	
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    
    $c->stash->{template} = '/breeders_toolbox/download.mas';
}

sub download_action : Path('/breeders/download_action') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $accession_list_id = $c->req->param("accession_list_list_select");
    my $trial_list_id     = $c->req->param("trial_list_list_select");
    my $trait_list_id     = $c->req->param("trait_list_list_select");
    my $data_type         = $c->req->param("data_type") || "phenotype";
    my $format            = $c->req->param("format");


    print STDERR "IDS: $accession_list_id, $trial_list_id, $trait_list_id\n";

    my $accession_data = SGN::Controller::AJAX::List->retrieve_list($c, $accession_list_id);
    my $trial_data = SGN::Controller::AJAX::List->retrieve_list($c, $trial_list_id);
    my $trait_data = SGN::Controller::AJAX::List->retrieve_list($c, $trait_list_id);

    

    my @accession_list = map { $_->[1] } @$accession_data;
    my @trial_list = map { $_->[1] } @$trial_data;
    my @trait_list = map { $_->[1] } @$trait_data;

        my $tf = CXGN::List::Transform->new();
    my $unique_transform = $tf->can_transform("accession_synonyms", "accession_names");
    
    my $unique_list = $tf->transform($c->dbic_schema("Bio::Chado::Schema"), $unique_transform, \@accession_list);
    
    my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh() });

    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $t = CXGN::List::Transform->new();
    
#    print STDERR Data::Dumper::Dumper(\@accession_list);
#    print STDERR Data::Dumper::Dumper(\@trial_list);
#    print STDERR Data::Dumper::Dumper(\@trait_list);

    my $acc_t = $t->can_transform("accessions", "accession_ids");
    my $accession_id_data = $t->transform($schema, $acc_t, $unique_list);

    my $trial_t = $t->can_transform("trials", "trial_ids");
    my $trial_id_data = $t->transform($schema, $trial_t, \@trial_list);
    
    my $trait_t = $t->can_transform("traits", "trait_ids");
    my $trait_id_data = $t->transform($schema, $trait_t, \@trait_list);

    my $accession_sql = join ",", map { "\'$_\'" } @{$accession_id_data->{transform}};
    my $trial_sql = join ",", map { "\'$_\'" } @{$trial_id_data->{transform}};
    my $trait_sql = join ",", map { "\'$_\'" } @{$trait_id_data->{transform}};

    print STDERR "SQL-READY: $accession_sql | $trial_sql | $trait_sql \n";

    my $data; 
    my $output = "";

    if ($data_type eq "phenotype") { 
	$data = $bs->get_phenotype_info($accession_sql, $trial_sql, $trait_sql);
	
	$output = "";
	foreach my $d (@$data) { 
	    $output .= join "\t", @$d;
	    $output .= "\n";
	}
    }

    if ($data_type eq "genotype") { 
	


    }
    $c->res->content_type("text/plain");
   $c->res->body($output);

}

1;
