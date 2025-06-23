
package SGN::Controller::AJAX::QualityControl;

use Moose;

use Data::Dumper;
use File::Slurp;
use File::Spec qw | catfile |;
use File::Path qw(rmtree);
use JSON::Any;
use File::Basename qw | basename |;
use DateTime;
use Bio::Chado::Schema;
use CXGN::Dataset::File;
use CXGN::Phenotypes::File;
use CXGN::MixedModels;
use SGN::Controller::AJAX::Dataset;
use JSON;


BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON' },
   );


sub prepare: Path('/ajax/qualitycontrol/prepare') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');

    if (! $c->user()) {
        $c->stash->{rest} = {error=>'You must be logged in first!'};
        $c->detach;
    }

    $c->tempfiles_subdir("qualitycontrol");

    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"qualitycontrol/qc_XXXXX");

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");
    my $temppath = $c->config->{basepath}."/".$tempfile;

    my $ds_json = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    $ds_json->retrieve_traits();
    my $ds_traits = $ds_json->traits();

    
    # Print extracted traits
    if ($ds_traits && @$ds_traits) {
       
        my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, exclude_dataset_outliers => 1, file_name => $temppath, quotes => 0);
        $ds->retrieve_phenotypes();
        my $pf = CXGN::Phenotypes::File->new( { file => $temppath."_phenotype.txt" });

        # my @traits_select = ();
        my $traits = $pf->traits();

        my $trait_options = "trait_options";
        my $trait_html ="";

        foreach my $trait (@$traits) {
           if ($trait =~ m/.+\d{7}/){
            $trait_html .= '<input type="checkbox" class= "trait_box" name="'.$trait_options.'" value="'.$trait.'">'.$trait.'</input> </br>';
           }
        }


        $c->stash->{rest} = {
            selected_variable => $trait_html,
            tempfile => $tempfile."_phenotype.txt",
        };

    } else {
        $c->stash->{rest} = {
            error => "No traits found in the dataset. Please select a dataset with trial(s) and trait(s).",
        };
    }
}

sub extract_trait_data :Path('/ajax/qualitycontrol/grabdata') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/qualitycontrol/".$file);
    my $F;
    if (! open($F, "<", $temppath)) {
    $c->stash->{rest} = { error => "Can't find data." };
    return;
    }

    my $header = <$F>;
    chomp($header);

    my @keys = split("\t", $header);

    my @data = ();

    while (<$F>) {
        chomp;
        my @fields = split "\t";
        my %line = ();
        
        for (my $n = 0; $n < @keys; $n++) {
            if (exists($fields[$n]) && defined($fields[$n])) {
                $line{$keys[$n]} = $fields[$n];
            }
        }
        if (defined $line{$trait} && $line{$trait} ne '') {
            push @data, \%line;
        }
    }
    
    my %unique_names;
    foreach my $entry (@data) {
        if (defined $entry->{'studyName'} && $entry->{'studyName'} ne '') {
            $unique_names{$entry->{'studyName'}} = 1;
        }
    }

    # Format the unique project names for the SQL query
    
    $trait =~ s/\|.*//;
    my $trait_like = $trait . '%';
    
    my $project_names = join(", ", map { "'$_'" } keys %unique_names);

    my $trait_sql = qq{
        select project."name" from projectprop
        join project on project.project_id = projectprop.project_id 
        where projectprop.type_id = (select cvterm_id from cvterm where cvterm."name" = 'validated_phenotype')
        and project.name in ($project_names)
        and projectprop.value like '$trait_like'
        group by project."name";
    };

    my @validated_projects;
    eval {
        # Prepare and execute the query
        my $sth_trait = $dbh->prepare($trait_sql);
        $sth_trait->execute();

        # Collect project names from the query result
        while (my ($project_name) = $sth_trait->fetchrow_array) {
            push @validated_projects, $project_name;

        }

        #print STDERR Dumper \@validated_projects;
        my $list_projects = join(", ", @validated_projects);

        if (scalar(@validated_projects) > 0) {
            my $project_names_str = join(", ", @validated_projects);
            my $message = "Trait $trait is already validated data for trials: $list_projects";
            $c->stash->{rest} = { message => $message };
        } else {
            $c->stash->{rest} = { data => \@data, trait => $trait};
        }
    };

    if ($@) {
        $c->response->body("Failed to search data: $@");
            return;
    }
}

sub data_restore :Path('/ajax/qualitycontrol/datarestore') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/qualitycontrol/".$file);

    my $F;
    if (! open($F, "<", $temppath)) {
    $c->stash->{rest} = { error => "Can't find data." };
    return;
    }

    my $header = <$F>;
    chomp($header);

    my @keys = split("\t", $header);

    my @data = ();

    while (<$F>) {
        chomp;
        my @fields = split "\t";
        my %line = ();
        
        for (my $n = 0; $n < @keys; $n++) {
            if (exists($fields[$n]) && defined($fields[$n])) {
                $line{$keys[$n]} = $fields[$n];
            }
        }
        if (defined $line{$trait} && $line{$trait} ne '') {
            push @data, \%line;
        }
    }

    my %unique_names;
    foreach my $entry (@data) {
        if (defined $entry->{'studyName'} && $entry->{'studyName'} ne '') {
            $unique_names{$entry->{'studyName'}} = 1;
        }
    }

    # Format the unique project names for the SQL query
    my $project_names = join(", ", map { "'$_'" } keys %unique_names);
    
    $c->stash->{rest} = { data => $project_names, trait => $trait};
}

sub store_outliers : Path('/ajax/qualitycontrol/storeoutliers') Args(0) {
    my ($self, $c) = @_;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $operator = $c->user()->get_object()->get_first_name()." ".$c->user()->get_object()->get_last_name();

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my @user_roles = $c->user()->roles;
    my $curator = (grep { $_ eq 'curator' || $_ eq 'breeder' } @user_roles) ? 1 : 0;

    my $response_data = {
    is_curator => $curator ? 1 : 0,  # 1 if curator, 0 otherwise
    };


    # Retrieve and decode the outliers from the request
    my $outliers_string = $c->req->param('outliers');
    
    # Now proceed to decode JSON
    my $outliers_data = decode_json($outliers_string);
    my $main_trait = $c->req->param('trait');

    my %trait_ids;
    my %study_names;
    my $trait;

    my $othertraits_json = $c->req->param('othertraits');  
    my $othertraits = decode_json($othertraits_json);

    # Remove duplicates using a hash
    my %unique_traits = map { $_ => 1 } @$othertraits;
    my @unique_othertraits = keys %unique_traits;

    foreach my $entry (@$outliers_data) { 
        $trait = $entry->{trait};  # Directly use the trait from the entry
        my $study_name = $entry->{studyName};
        $study_names{$study_name} = 1 if defined $study_name;
    }

    my @alltraits = ($main_trait, @unique_othertraits);
    foreach my $sel_trait (@alltraits) {
        $trait_ids{$sel_trait} = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $sel_trait)->cvterm_id;
    }

        
    $main_trait =~ s/\|.*//;
    my $trait_operator = $main_trait."|".$operator;

    # Convert unique study names to a comma-separated list in SQL format
    my @unique_study_names = keys %study_names;
    return $c->response->body('No unique study names found.') unless @unique_study_names;

    my $study_names_sql = join(", ", map { $schema->storage->dbh->quote($_) } @unique_study_names);  # Quote each name

    # Add validated traits to projectprop
    my $trial_sql = qq{
        INSERT INTO projectprop (project_id, type_id, value, rank)
        SELECT 
            p.project_id,
            (SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype'),
            '$trait_operator',
            COALESCE(MAX(pp.rank), 0) + 1  -- Increment rank
        FROM project p
        LEFT JOIN projectprop pp
            ON p.project_id = pp.project_id
            AND pp.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype')
        WHERE p.name in ($study_names_sql)
        GROUP BY p.project_id;
    };

    my $experiment_type = SGN::Model::Cvterm->get_cvterm_row($schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();

    # Execute the first query unconditionally
    eval {
        my $sth_trial = $schema->storage->dbh->prepare($trial_sql);
        $sth_trial->execute();
    };

    my @plot_names  = map { $_->{plotName} } @$outliers_data;
    my @plot_values = map { $_->{value} } @$outliers_data;

    my %seen;
    @plot_names = grep { !$seen{$_}++ } @plot_names;

    print("here are plots:\n");
    print Dumper \@plot_names;
    
    # Proceed only if there are outliers
    if (@plot_names) {
        # Extract plot names from the outliers data
        

        my @unique_trait_ids = grep { !$seen{$_}++ } values %trait_ids;
        my $trait_ids_sql    = join(", ", @unique_trait_ids);

        # Proceed with query only if @plot_names and %trait_ids are valid
        if (@plot_names && %trait_ids) {
            my $plot_names_sql = join(", ", map { $schema->storage->dbh()->quote($_) } @plot_names);

            # SQL Query to insert outliers
            my $outlier_data_sql = "
                INSERT INTO phenotypeprop (phenotype_id, type_id, value)
                SELECT phenotype.phenotype_id, 
                       cvterm_outlier.cvterm_id, 
                       phenotype.value
                FROM phenotype
                JOIN nd_experiment_phenotype 
                    ON nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id 
                JOIN nd_experiment_stock 
                    ON nd_experiment_stock.nd_experiment_id = nd_experiment_phenotype.nd_experiment_id 
                JOIN stock 
                    ON stock.stock_id = nd_experiment_stock.stock_id 
                LEFT JOIN phenotypeprop existing_prop
                    ON existing_prop.phenotype_id = phenotype.phenotype_id
                    AND existing_prop.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'phenotype_outlier')
                CROSS JOIN (SELECT cvterm_id FROM cvterm WHERE name = 'phenotype_outlier') AS cvterm_outlier
                WHERE stock.uniquename IN ($plot_names_sql)
                AND nd_experiment_stock.type_id = $experiment_type
                AND phenotype.observable_id IN ($trait_ids_sql)
                AND existing_prop.phenotype_id IS NULL;";  


            # If curator flag is set, execute the second query
            if ($curator == 1) {
                eval {
                    my $sth_outliers = $schema->storage->dbh->prepare($outlier_data_sql);
                    $sth_outliers->execute();
                };
            }
        }
    }

    $c->stash->{rest} = $response_data;


    
    ## celaning tempfiles
    rmtree(File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/qualitycontrol"));
}

sub restore_outliers : Path('/ajax/qualitycontrol/restoreoutliers') Args(0) {

    my ($self, $c) = @_;
    my $dbh = $c->dbc->dbh();
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my @user_roles = $c->user()->roles;
    
    my $curator = (grep { $_ eq 'curator' } @user_roles) ? 'curator' : undef;
    

    # Retrieve and decode the outliers from the request
    my $outliers_string = $c->req->param('outliers');
    my $outlier_trials;
    $outlier_trials = decode_json($outliers_string);
    
    # getting trait name
    my $trait = $c->req->param('trait');
    $trait =~ s/\|.*//;

    my $trait_like = $trait . '%';

    my $response_data = {
    is_curator => $curator ? 1 : 0,  # 1 if curator, 0 otherwise
    };

    my $trial_clean_sql = qq{
        DELETE FROM projectprop
        WHERE projectprop.project_id IN (
            SELECT projectprop.project_id
            FROM projectprop
            JOIN project ON project.project_id = projectprop.project_id
            WHERE project.name IN ($outlier_trials)
        )
        AND projectprop.value LIKE '$trait_like'
        AND projectprop.type_id = (
            SELECT cvterm_id FROM cvterm WHERE name = 'validated_phenotype'
        );
    };

    my $outliers_clean_sql = qq{
        DELETE FROM phenotypeprop
        WHERE phenotypeprop.phenotype_id IN (
            SELECT phenotypeprop.phenotype_id
            FROM phenotypeprop
            JOIN phenotype ph ON phenotypeprop.phenotype_id = ph.phenotype_id
            JOIN nd_experiment_phenotype nep ON nep.phenotype_id = phenotypeprop.phenotype_id
            JOIN nd_experiment_project nes ON nes.nd_experiment_id = nep.nd_experiment_id
            JOIN project pr ON pr.project_id = nes.project_id
            WHERE ph.observable_id = (
                SELECT cvterm_id FROM cvterm WHERE cvterm.name like '$trait_like'
            )
            AND pr.name IN ($outlier_trials)
        );
    };
    
    

    # Execute the SQL query
    if ($curator eq 'curator'){
        eval {
            my $sth_trial = $dbh->prepare($trial_clean_sql);
            $sth_trial->execute();

            my $sth_clean = $dbh->prepare($outliers_clean_sql);
            $sth_clean->execute();
        };

        if ($@) {
            $c->response->body("Failed to store data: $@");
            return;
        } else {
            $c->stash->{rest} = $response_data;
        }
    } else {
        $c->stash->{rest} = $response_data;
    }

    ## celaning tempfiles
    rmtree(File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/qualitycontrol"));

}


1;
