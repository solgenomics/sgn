
package SGN::Controller::AJAX::Analysis;

use Moose;

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
    my $data = $c->req->param("data");
    my $analysis_name = $c->req->param("analysis_name");
    my $analysis_type = $c->req->param("analysis_type");
    
    if (my $error = $self->check_user($c)) {
	$c->stash->{error} = $error;
	return;
    }
    
    my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), $analysis_type, 'analysis_type');
    if (! $analysis_type_row) { die "Provided analysis type does not exist in the database. Exiting." }
    
    my @plots;
    my @stocks;
    my @traits;
    my %values;
    
    my $analysis_type_id = $analysis_type_row->cvterm_id();    
    push @traits, $analysis_type_id;
    
    my %values = JSON::Any->decode($data); 
    
    $self->store_data($c, \%values);
}

sub store_analysis_file : Path('/ajax/analysis/store/file') ActionClass("REST") Args(0) {}

sub store_analysis_file_POST {
    my $self = shift;
    my $c = shift;
    my $file = $c->req->param("file");
    my $analysis_name = $c->req->param("analysis_name");
    my $analysis_type = $c->req->param("analysis_type");
    
    my $user_id = $c->user()->get_object()->sp_person_id();
    
    if (my $error = $self->check_user($c)) {
	$c->stash->{error} = $error;
	return;
    }
    
    my $analysis_type_row = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), $analysis_type, 'analysis_type');
    if (! $analysis_type_row) { die "Provided analysis type does not exist in the database. Exiting." }
    
    my @plots;
    my @stocks;
    my @traits;
    my %values;
    
    my $analysis_type_id = $analysis_type_row->cvterm_id();    
    push @traits, $analysis_type_id;
    
    my @lines = slurp($file);

    foreach my $line (@lines) {
	my ($acc, $value) = split /\t/, $line;
	my $plot_name = $analysis_name."_".$acc;
	push @plots, $plot_name;
	push @stocks, $acc;
        $values{$plot_name}->{$traits[0]} = $value;
    }

    $self->store_data($c, \%values, $user_id);

}


sub store_data {
    my $self = shift;
    my $c = shift;

    my $a = CXGN::Analysis->new( {bcs_schema=> $c->dbic("Bio::Chado::Schema") });


    
    my ($verified_warning, $verified_error) = $a->store_analysis();
    
    
    if ($verified_warning || $verified_error) {
	$c->stash->{rest} = { warnings => $verified_warning, error => $verified_error };
	return;
    }

    else {
	$c->stash->{rest} = { success => 1 };
    }
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
