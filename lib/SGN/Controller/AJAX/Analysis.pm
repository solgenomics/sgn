
package SGN::Controller::AJAX::Analysis;

use Moose;

use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


sub store_analysis_json : Path('/ajax/analysis/store/json') ActionClass("REST") Args(0) {}

sub store_analysis_json_POST {
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();
    my $data = $c->req->param("data");
    my $dataset_id = $c->req->param("dataset_id");
    my $analysis_name = $c->req->param("analysis_name");
    my $analysis_type = $c->req->param("analysis_type");

    if (my $error = $self->check_user($c)) {
	$c->stash->{error} = $error;
	return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    
    my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), $params->{analysis_type}, 'analysis_type');
    if (! $analysis_type_row) { 
	die "Provided analysis type does not exist in the database. Exiting." 
    }
    
    my @plots;
    my @stocks;
    my @traits;
    my %values;
    
    my $analysis_type_id = $analysis_type_row->cvterm_id();    
    push @traits, $analysis_type_id;
    
    my %values = JSON::Any->decode($params, $data); 
    
    $self->store_data($c, $params, \%values, $user_id);
}

sub store_analysis_file : Path('/ajax/analysis/store/file') ActionClass("REST") Args(0) {}

sub store_analysis_file_POST {
    my $self = shift;
    my $c = shift;
    my $file = $c->req->param("file");
    my $dir = $c->req->param("dir"); # the dir under tempfiles/

    my $params = $c->req->params();
    my $analysis_name = $c->req->param("analysis_name");
    my $analysis_type = $c->req->param("analysis_type");
    my $dataset_id = $c->req->param("dataset_id");
    my $description = $c->req->param("description");
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    print STDERR "Storing analysis file: $dir / $file...\n";

    if (my $error = $self->check_user($c)) {
	$c->stash->{error} = "Need to be logged in ($error)";
	return;
    }
    
    my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), $params->{analysis_type}, 'analysis_type');
    if (! $analysis_type_row) { 
	$c->stash->{error} = "Provided analysis type does not exist in the database. Exiting.";
	return;
    }
    
    my @plots;
    my @stocks;
    my @traits;
    my %values;
    
    my $analysis_type_id = $analysis_type_row->cvterm_id();    
    push @traits, $analysis_type_id;

    my $fullpath = $c->tempfiles_base()."/".$dir."/".$file;

    print STDERR "Reading analysis file path $fullpath...\n";
    
    my @lines = slurp($file);

    foreach my $line (@lines) {
	my ($acc, $value) = split /\t/, $line;
	print STDERR "Reading data for $acc with value $value...\n";
	my $plot_name = $analysis_name."_".$acc;
	push @plots, $plot_name;
	push @stocks, $acc;
        $values{$plot_name}->{$traits[0]} = $value;
    }

    print STDERR "Storing data...\n";
    return $self->store_data($c, $params, \%values, $user_id);
}


sub store_data {
    my $self = shift;
    my $c = shift;
    my $params = shift;
    my $values = shift;
    my $user_id = shift;

    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $a = CXGN::Analysis->new( 
	{
	    bcs_schema => $bcs_schema,
	    people_schema => $people_schema,
	});
    
    my $d = CXGN::Dataset->new( 
	{
	    bcs_schema => $bcs_schema,
	    people_schema => $people_schema,
	});

    $a->name($params->{name});
    $a->description($params->{description});
    $a->user_id($user_id);
    $a->dataset_id($params->{dataset_id});
    $a->dataset_info($d->data());
		     
    my ($verified_warning, $verified_error) = $a->create_and_store_analysis_design();
       
    if ($verified_warning || $verified_error) {
	$c->stash->{rest} = { warnings => $verified_warning, error => $verified_error };
	return;
    }
    else {
	$c->stash->{rest} = { success => 1 };
    }
}

sub list_analyses_by_user_table :Path('/ajax/analyses/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user_id;
    if ($c->user()) {
	$user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }
    my @a = CXGN::Analysis->retrieve_analyses_by_user($schema, $user_id);

    print STDERR Dumper(\@a);
	

}

sub check_user {
    my $self = shift;
    my $c = shift;
    
    my $error;
    
    if (! $c->user()) {
	$error = "You need to be logged in to store data";
    }
    
    if (! $c->user()->check_roles("submitter") || ! $c->user()->check_roles("curator")) {
	$error = "You have insufficient privileges to store the data in the database";
    }
    
    return $error;
}
