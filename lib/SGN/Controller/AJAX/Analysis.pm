
package SGN::Controller::AJAX::Analysis;

use Moose;

use File::Slurp;
use Data::Dumper;
use CXGN::Phenotypes::StorePhenotypes;
use URI::FromHash 'uri';

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
    my $trait => $c->req->param("trait");
    
    if (my $error = $self->check_user($c)) {
	$c->stash->{rest} = { error =>  $error };
	return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    
    my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), $params->{analysis_type}, 'analysis_type');
    if (! $analysis_type_row) { 
	$c->stash->{rest} = { error => "The provided analysis type does not exist in the database. Please try this with different settings." };
	return;
    }
    
    my @plots;
    my @stocks;
    my @traits;
    my %values;
    
    my $analysis_type_id = $analysis_type_row->cvterm_id();
    
    push @traits, $trait;
    
    my %values = JSON::Any->decode($params, $data); 
    
    $self->store_data($c, $params, \%values, \@stocks, \@plots, \@traits, $user_id);
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
    print STDERR <<;
    Analysis name: $analysis_name
    Analysis type: $analysis_type
    Description:   $description

    
    if (my $error = $self->check_user($c)) {
	print STDERR "Sorry you are not logged in... not storing.\n";
	$c->stash->{rest} = { error => $error };
	return;
    }

    print STDERR "Retrieving cvterms...\n";
    my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), $params->{analysis_type}, 'experiment_type');
    if (! $analysis_type_row) {
	my $error = "Provided analysis type ($params->{analysis_type}) does not exist in the database. Exiting.";
	print STDERR $error."\n";
	$c->stash->{rest} = { error =>  $error };
	return;
    }
    
    my @plots;
    my @stocks;
    my @traits;
    my %values;
    
    my $analysis_type_id = $analysis_type_row->cvterm_id();    

    my $fullpath = $c->tempfiles_base()."/".$dir."/".$file;

    print STDERR "Reading analysis file path $fullpath...\n";
    
    my @lines = read_file($fullpath);

    my $header = shift(@lines);

    my ($accession, $trait) = split /\t/, $header;
    
    foreach my $line (@lines) {
	my ($acc, $value) = split /\t/, $line;
	$acc =~ s/\"//g;
	print STDERR "Reading data for $acc with value $value...\n";
	my $plot_name = $analysis_name."_".$acc;
	push @plots, $plot_name;
	push @stocks, $acc;
        $values{$plot_name}->{$trait} = $value;
    }

    print STDERR "Storing data...\n";
    return $self->store_data($c, $params, \%values, \@stocks, \@plots, \@traits, $user_id);
}


sub store_data {
    my $self = shift;
    my $c = shift;
    my $params = shift;
    my $values = shift;
    my $stocks = shift;
    my $plots = shift;
    my $traits = shift;
    my $user_id = shift;


    my $user = $c->user()->get_object();
    
    my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");

    my $a = CXGN::Analysis->new( 
	{
	    bcs_schema => $bcs_schema,
	    people_schema => $people_schema,
	});

    if ($params->{dataset_id} !~ /^\d+$/) {
	$params->{dataset_id} = undef;
    }


    if ($params->{dataset_id}) { 
	$a->metadata()->dataset_id($params->{dataset_id});
    }
    $a->name($params->{analysis_name});
    $a->description($params->{description});
    $a->user_id($user_id);
    $a->metadata()->accessions($stocks);
    $a->metadata()->traits($traits);
    $a->metadata()->analysis_protocol($params->{analysis_protocol});
    
    my ($verified_warning, $verified_error);

    print STDERR "Storing the analysis...\n";
    eval { 
	($verified_warning, $verified_error) = $a->create_and_store_analysis_design();
    };

        
    my @errors;
    my @warnings;
    
    if ($@) {
	push @errors, $@;
    }
    elsif ($verified_warning || $verified_error) {
	push @warnings, $verified_warning;
	push @errors, $verified_error;
    }

    if (@errors) { 
	$c->stash->{rest} = { error => join "; ", @errors };
	return;
    }
    
    my $operator = $user->get_first_name()." ".$user->get_last_name();
    print STDERR "Store analysis values...\n";

    eval { 
	$a->store_analysis_values(
	    $c->dbic_schema("CXGN::Metadata::Schema"),
	    $c->dbic_schema("CXGN::Phenome::Schema"),
	    $values, # value_hash
	    $plots, 
	    $traits,
	    $operator,
	    $c->config->{basepath},
	    $c->config->{dbhost},
	    $c->config->{dbname},
	    $c->config->{dbuser},
	    $c->config->{dbpass},
	    "/tmp/temppath-$$",
	    
	    );

    };

    if ($@) {
	$c->stash->{rest} = { error => "An error occurred storing the values.\n"};
	return;
    }
    
    $c->stash->{rest} = { success => 1 };

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
    my @analyses = CXGN::Analysis->retrieve_analyses_by_user($schema, $user_id);

    my @table;
    foreach my $a (@analyses) {
	push @table, [ '<a href="/analyses/'.$a->project_id().'">'.$a->name()."</a>", $a->description() ];
    }

    print STDERR Dumper(\@table);
    
    $c->stash->{rest} = { data => \@table };

}

sub check_user {
    my $self = shift;
    my $c = shift;
    
    my $error;
    
    if (! $c->user()) {
	$error = "You need to be logged in to store data";
    }
    
    if (! $c->user()->check_roles("submitter") && ! $c->user()->check_roles("curator")) {
	$error = "You have insufficient privileges to store the data in the database";
    }
    
    return $error;
}
