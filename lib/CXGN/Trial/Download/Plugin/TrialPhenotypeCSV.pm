
package CXGN::Trial::Download::Plugin::TrialPhenotypeCSV;

use Moose::Role;
use CXGN::BreederSearch;
use CXGN::Trial;

sub verify { 
    1;
}

sub download { 
    my $self = shift;

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $trial_id });

    $self->trial_download_log($trial_id, "trial phenotypes");

    my $trial_sql = "\'$trial_id\'";
    my $bs = CXGN::BreederSearch->new( { dbh => $schema->storage->dbh() });
    my @data = $bs->get_extended_phenotype_info_matrix(undef,$trial_sql, undef);
    my $rs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id })->search_related('nd_experiment_projects')->search_related('nd_experiment')->search_related('nd_geolocation');

    my $location = $rs->first()->get_column('description');
    
    my $bprs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id})->search_related_rs('project_relationship_subject_projects');

    #print STDERR "COUNT: ".$bprs->count()."  ". $bprs->get_column('project_relationship.object_project_id')."\n";

    my $pbr = $schema->resultset("Project::Project")->search( { 'me.project_id'=> $bprs->get_column('project_relationship_subject_projects.object_project_id')->first() } );
    
    my $program_name = $pbr->first()->name();
    my $year = $trial->get_year();

    #print STDERR "YEAR: $year\n";

    #print STDERR "PHENOTYPE DATA MATRIX: ".Dumper(\@data);
    
    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();
    for (my $line =0; $line< @data; $line++) { 
	my @columns = split /\t/, $data[$line];
	
	print $F join(",", @columns);
	print $F "\n";
    }
    close($F);
}

1;
