
package CXGN::Trial::Download::Plugin::TrialPhenotypeCSV;

use Moose::Role;
use CXGN::BreederSearch;
use CXGN::Trial;
use CXGN::Phenotypes::Search;

sub verify {
    1;
}

sub download {
    my $self = shift;

    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my $trait_list = $self->trait_list();
    my $trait_contains = $self->trait_contains();
    my $data_level = $self->data_level();
    my $include_timestamp = $self->include_timestamp();
    my $trial_list = $self->trial_list();
    if (!$trial_list) {
        push @$trial_list, $trial_id;
    }
    my $accession_list = $self->accession_list;
    my $plot_list = $self->plot_list;
    my $plant_list = $self->plant_list;
    my $location_list = $self->location_list;
    my $year_list = $self->year_list;
    my $phenotype_min_value = $self->phenotype_min_value();
    my $phenotype_max_value = $self->phenotype_max_value();

    $self->trial_download_log($trial_id, "trial phenotypes");

    my $phenotypes_search = CXGN::Phenotypes::Search->new({
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trial_list=>$trial_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        include_timestamp=>$include_timestamp,
        trait_contains=>$trait_contains,
        phenotype_min_value=>$phenotype_min_value,
        phenotype_max_value=>$phenotype_max_value,
        location_list=>$location_list,
        year_list=>$year_list
    });
    my @data = $phenotypes_search->get_extended_phenotype_info_matrix();
    #print STDERR Dumper \@data;

    #my $rs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id })->search_related('nd_experiment_projects')->search_related('nd_experiment')->search_related('nd_geolocation');

    #my $location = $rs->first()->get_column('description');

    #my $bprs = $schema->resultset("Project::Project")->search( { 'me.project_id' => $trial_id})->search_related_rs('project_relationship_subject_projects');

    #print STDERR "COUNT: ".$bprs->count()."  ". $bprs->get_column('project_relationship.object_project_id')."\n";

    #my $pbr = $schema->resultset("Project::Project")->search( { 'me.project_id'=> $bprs->get_column('project_relationship_subject_projects.object_project_id')->first() } );

    #my $program_name = $pbr->first()->name();
    #my $year = $trial->get_year();

    #print STDERR "YEAR: $year\n";

    #print STDERR "PHENOTYPE DATA MATRIX: ".Dumper(\@data);

    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();
    my @header = split /\t/, $data[0];
    my $num_col = scalar(@header);
    for (my $line =0; $line< @data; $line++) {
        my @columns = split /\t/, $data[$line];
        my $step = 1;
        for(my $i=0; $i<$num_col; $i++) {
            if ($columns[$i]) {
                print $F "\"$columns[$i]\"";
            } else {
                print $F "\"\"";
            }
            if ($step < $num_col) {
                print $F ",";
            }
            $step++;
        }
        print $F "\n";
    }
    close($F);
}

1;
