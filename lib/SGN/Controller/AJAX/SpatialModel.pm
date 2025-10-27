
use strict;

package SGN::Controller::AJAX::SpatialModel;

use Moose;
use Data::Dumper;
use File::Temp qw | tempfile |;
use File::Slurp;
use File::Spec qw | catfile|;
use File::Basename qw | basename |;
use File::Copy;
use List::Util qw | any |;
use JSON::Any;
use CXGN::Dataset;
use CXGN::Dataset::File;
use CXGN::Tools::Run;
use CXGN::Job;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/distinct evens/;
use CXGN::Blast::Parse;
use CXGN::Blast::SeqQuery;
use SGN::Model::Cvterm;
use Cwd qw(cwd);
use namespace::autoclean;
use Storable qw(retrieve);
use Storable qw(store);
use POSIX qw(strftime);

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub shared_phenotypes: Path('/ajax/spatial_model/shared_phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    my $dataset_id = $c->req->param('dataset_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $ds = CXGN::Dataset->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id);
    my $traits = $ds->retrieve_traits();

    $c->tempfiles_subdir("spatial_model_files");
    my ($fh, $tempfile) = $c->tempfile(TEMPLATE=>"spatial_model_files/trait_XXXXX");
    my $temppath = $c->config->{basepath}."/".$tempfile;
    my $ds2 = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema, sp_dataset_id => $dataset_id, file_name => $temppath, quotes => 0);
    my $phenotype_data_ref = $ds2->retrieve_phenotypes();

    print STDERR Dumper($traits);
    $c->stash->{rest} = {
        options => $traits,
        tempfile => $tempfile."_phenotype.txt",
#        tempfile => $file_response,
    };
}



sub extract_trait_data :Path('/ajax/spatial_model/getdata') Args(0) {
    my $self = shift;
    my $c = shift;

    my $file = $c->req->param("file");
    my $trait = $c->req->param("trait");

    $file = basename($file);
    my @data;

    my $temppath = File::Spec->catfile($c->config->{basepath}, "static/documents/tempfiles/spatial_model_files", $file);
    print STDERR Dumper($temppath);

    my $F;
    if (! open($F, "<", $temppath)) {
	$c->stash->{rest} = { error => "Can't find data." };
	return;
    }

    $c->stash->{rest} = { data => \@data, trait => $trait};
}


sub generate_results: Path('/ajax/spatial_model/generate_results') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;
    my $basenamesp = $c -> req -> param("basenamesp");

    print STDERR "TRIAL_ID: $trial_id\n";

    $c->tempfiles_subdir("spatial_model_files"); # set the tempfiles subdir to spatial model files
    my $spatial_model_tmp_output = $c->config->{cluster_shared_tempdir}."/spatial_model_files"; # get the spatial model temp output directory
    print STDERR "spatial_model_tmp_output: $spatial_model_tmp_output\n";
    mkdir $spatial_model_tmp_output if ! -d $spatial_model_tmp_output; # create the spatial model temp output directory if it doesn't exist
    my ($tmp_fh, $tempfile) = tempfile(
      "spatial_model_download_XXXXX",
      DIR=> $spatial_model_tmp_output,
    );
    print STDERR "tempfile: $tempfile\n";

    #my $temppath = $c->config->{basepath}."/".$tempfile;
    #print STDERR "temppath: $temppath\n";

    my $pheno_filepath = $tempfile . "_phenotype.txt"; # create the phenotype file path
    

    print STDERR "pheno_filepath: $pheno_filepath\n";

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);
    my $temppath =  $tempfile;
    my $ds = CXGN::Dataset::File->new(people_schema => $people_schema, schema => $schema,  file_name => $temppath, quotes=>0);
    $ds -> trials([$trial_id]);
    $ds -> retrieve_phenotypes($pheno_filepath);
    open(my $PF, "<", $pheno_filepath) || die "Can't open pheno file $pheno_filepath";
    open(my $CLEAN, ">", $pheno_filepath.".clean") || die "Can't open pheno_filepath clean for writing";

    my $header = <$PF>;
    chomp($header);

    my @fields = split /\t/, $header;

    my @file_traits = @fields[ 39 .. @fields-1 ];
    my @file_traits_original = @fields[ 39 .. @fields-1 ];
    my @other_headers = @fields[ 0 .. 38 ];



    print STDERR "FIELDS: ".Dumper(\@file_traits);

    foreach my $t (@file_traits) { 
	    $t = make_R_trait_name($t);
    }
    #later i will replace the R trait name with the original trait name so save both so that it can remember the original trait name
    my %trait_hash;
    for (my $i=0; $i<@file_traits; $i++) {
            $trait_hash{$file_traits[$i]} = $file_traits_original[$i];
    }

    # print STDERR "TRAIT HASH: ".Dumper(\%trait_hash);
    #save the trait hash to a perl storable file to be retrieved later
    my $trait_hash_file = $pheno_filepath.".clean.trait_hash";
    store \%trait_hash, $trait_hash_file; #syntax error here because store is not defined, need to use Storable qw(retrieve);
    

    my $si_traits = join(",", @file_traits);

    print STDERR "FILE TRAITS: ".Dumper(\@file_traits);

    my @new_header = (@other_headers, @file_traits);
    print $CLEAN join("\t", @new_header)."\n";

    my $last_index = scalar(@new_header)-1;

    while(<$PF>) {
        chomp;
        my @f = split /\t/;
        print $CLEAN join("\t",@f[0..$last_index]), "\n";
    }
    
    my $cxgn_tools_run_config = {
        backend => $c->config->{backend},
        submit_host=>$c->config->{cluster_host},
        temp_base => $c->config->{cluster_shared_tempdir} . "/spatial_model_files",
        queue => $c->config->{'web_cluster_queue'},
        do_cleanup => 0,
        # don't block and wait if the cluster looks full
        max_cluster_jobs => 1_000_000_000,
    };
    my $cmd_str = join(" ", (
        "Rscript ",
        $c->config->{basepath} . "/R/spatial_correlation_check.R",
        $pheno_filepath.".clean",
        "'".$si_traits."'"
    ));
    my $job = CXGN::Job->new({
        schema => $schema,
        people_schema => $people_schema,
        sp_person_id => $sp_person_id,
        job_type => 'spatial_analysis',
        cmd => $cmd_str,
        name => "Trial $trial_id spatial analysis",
        results_page => "/breeders/trial/$trial_id",
        cxgn_tools_run_config => $cxgn_tools_run_config,
        finish_logfile => $c->config->{job_finish_log}
    });

    # my $cmd = CXGN::Tools::Run->new($cxgn_tools_run_config);

    # $job_record->update_status("submitted");
    #     $cmd->run_cluster(
    #     "Rscript ",
    #     $c->config->{basepath} . "/R/spatial_modeling.R",
    #     $pheno_filepath.".clean",
    #     "'".$si_traits."'",
    #     $job_record->generate_finish_timestamp_cmd()
	# );

    # while ($cmd->alive) {
	# sleep(1);
    # }

    $job->submit();
    while($job->alive()){
        sleep(1);
    }
    #getting the spatial correlation results
    my @data;

    open(my $F, "<", $pheno_filepath.".clean.spatial_correlation_summary") || die "Can't open result file $pheno_filepath".".spatial_correlation_summary";
    my $header = <$F>;
    my @h = split(/\t/, $header);
    #my @h = split(',', $header);
    my @spl;
    foreach my $item (@h) {
    push  @spl, {title => $item};
  }
    print STDERR "Header: ".Dumper(\@spl);
    while (<$F>) {
	chomp;
	my @fields = split /\t/; #split /,/;
	foreach my $f (@fields) { $f =~ s/\"//g; }
	push @data, \@fields;
    }
    #change the trait name back to the original trait name, i dont need to open the trait hash file again because i already have the hash
    my @data_original;
    foreach my $r (@data) {
        my @data_original_row;
        foreach my $r2 (@$r) {
            if (exists($trait_hash{$r2})) {
                push @data_original_row, $trait_hash{$r2};
            } else {
                push @data_original_row, $r2;
            }
        }
        push @data_original, \@data_original_row;
    }
    @data = @data_original;
    

    print STDERR "FORMATTED DATA: ".Dumper(\@data);

    my $basename = basename($pheno_filepath.".clean.spatial_correlation_summary");

    copy($pheno_filepath.".clean.blues", $c->config->{basepath}."/static/documents/tempfiles/spatial_model_files/".$basename);

    my $download_url = '/documents/tempfiles/spatial_model_files/'.$basename;
    my $download_link = "<a href=\"$download_url\">Download Results</a>";

####################################################################

    # convert row data into nested structure that can be saved as analysis


    $c->stash->{rest} = {
	data => \@data,
    headers => \@spl,
	download_link => $download_link,
    pheno_filepath => $pheno_filepath,
    phenotype_file => "$pheno_filepath.clean"
    };
}
sub correct_spatial: Path('/ajax/spatial_model/correct_spatial') Args(1) {
    my ($self, $c) = @_;
    my $dataTableData = $c->req->param("dataTableData");
    my $include_rc_random = $c->req->param("include_rc_random");
    my $genotype_as_random = $c->req->param("genotype_as_random");
    my $nseg_degree = $c->req->param("nseg_degree");
    print STDERR "DATA TABLE DATA: $dataTableData\n";
    # Convert the DataTable data back into an array
    my @dataTableArray = map { [split(/\t/, $_)] } split(/\n/, $dataTableData);

    # Get the data and other required variables from the stash
    # my $data = $c->stash->{rest}->{data};
    my $pheno_filepath = $c->req->param("pheno_filepath");
    my $headers = $c->req->param("headers");   
    my $phenotype_file = $c->req->param("phenotype_file");
    print STDERR "PHENOTYPE FILE: $phenotype_file\n";
    # Convert the data and headers to a format suitable for passing to the second R script
    my $data_string = join("\n", map { join("\t", @$_) } @$dataTableData);
    my $headers_string = join(",", map { $_->{title} } @$headers);
    # Create a temporary file to store the data
    my ($temp_fh, $temp_file) = tempfile();
    print $temp_fh $data_string;
    close($temp_fh);
    print STDERR "TEMP FILE: $temp_file\n";


    # Define the command to run the second R script
    my $cmd = CXGN::Tools::Run->new({
        backend => $c->config->{backend},
        submit_host=>$c->config->{cluster_host},
        temp_base => $c->config->{cluster_shared_tempdir} . "/spatial_model_files",
        queue => $c->config->{'web_cluster_queue'},
        do_cleanup => 0,
        # don't block and wait if the cluster looks full
        max_cluster_jobs => 1_000_000_000,
    });
    
    $cmd->run_cluster(
	    "Rscript ",
        $c->config->{basepath} . "/R/Spatial_Correction.R",
        $phenotype_file,
        $phenotype_file.".spatial_correlation_summary", 
        $include_rc_random,
        $genotype_as_random,
        $nseg_degree,
        "'".$headers_string."'",
	);

    while ($cmd->alive) {
	    sleep(1);
    }

   #getting the spatial correlation results
    my @result;

    open(my $F, "<", "$phenotype_file.spatially_corrected") || die "Can't open result file $phenotype_file.spatially_corrected";

    open(my $moranF, "<", "$phenotype_file.moran") || die "Can't get new moran p values file!";

    open(my $modelF, "<", "$phenotype_file.model_string") || die "Can't get model call file!";

    my @moran_p_values;
    while (<$moranF>) {
        chomp;
        my ($trait, $p_value) = split("\t", $_);
        push @moran_p_values, [$trait, $p_value];
    }

    my $model_string = <$modelF>;
    chomp($model_string);

    my $accessions = {}; # keeps list of unique accessions
    my $nested_data = {}; # formats the result data for saving the analysis
    my $projectprop_data = {}; # Stores adjustments only, for saving as projectprop
        # needs to have 
    my $analysis_design = {}; # retains the trial layout data for analysis submission
    my @data; # formats for the datatable

    my $header = <$F>;
    # header will have plot, accession, row, column, replicate, blockNumber, plotNumber [...traits...]
    my (undef, undef, undef, undef, undef, undef, undef, @trait_columns) = split(/\s+/, $header);

    print STDERR Dumper \@trait_columns;

    # my sub fix_trait_name {
    #     my $trait = shift;

    #     $trait =~ s/_([A-Z]+(_\d+)*)_(\d+)/\|$1:$3/;

    #     my ($name, $onto) = split(/\|/, $trait);

    #     $name = join(" ", split("_", $name));

    #     $trait = join('|', ($name, $onto));

    #     return $trait;
    # }

    my $trait_hash_file = $pheno_filepath.".clean.trait_hash";
    my $trait_hashref = retrieve $trait_hash_file;

    @trait_columns = map {$trait_hashref->{$_}} @trait_columns; #need to fix trait names!

    my @traits = grep {$_ !~ /_spatially_corrected|_spatial_adjustment/} @trait_columns;

    # need to make a trait->cvterm_id hash here
    my $traits_to_id = {};

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    print STDERR Dumper \@traits;

    foreach my $trait (@traits) {
        my ($short_name, $onto) = split(/\|/,$trait);
        my $cvterm_id = $schema->resultset('Cv::Cvterm')->find({
            name => $short_name,
        })->cvterm_id;
        $traits_to_id->{$trait} = $cvterm_id;
    }

    my $datarow_num = 1;
    while (<$F>) {
        chomp;
        my ($plot, $accession, $row, $column, $replicate, $block_number, $plot_number, @trait_values) = split(/\s+/, $_);

        for (my $i = 0; $i < @trait_values; $i += 3) {
            my $original = $trait_values[$i];
            my $corrected;
            my $adjustment = 0;
            if ($trait_values[$i + 2] ne "NA") {
                $adjustment = $trait_values[$i + 2];
            }
            if ($original eq "NA") {
                $corrected = "NA";
            } else {
                $corrected = $trait_values[$i + 1];
            }
            push @data, [$plot, $accession, $traits[$i / 3], $original, $corrected, $adjustment ];
            $nested_data->{$plot}->{$traits[$i / 3]} = [
                $corrected, 
                strftime("%Y-%m-%dT%H:%M:%S", localtime), 
                $c->user->get_object()->get_first_name().' '.$c->user->get_object()->get_last_name(), 
                '', 
                ''
            ];
            $projectprop_data->{$plot}->{$traits_to_id->{$traits[$i / 3]}} = $adjustment;
            # $projectprop_data->{$plot}->{$traits[$i / 3]} = $adjustment;
        }

        $analysis_design->{$datarow_num} = {
            'stock_name' => $accession,
            'plot_name' => $plot,
            'plot_number' => $plot_number,
            'block_number' => $block_number,
            'rep_number' => $replicate,
            'row_number' => $row,
            'col_number' => $column
        };

        $accessions->{$accession} = 1;
        $datarow_num++;
    }

    my @accessions = sort(keys(%{$accessions}));

    # print STDERR "FORMATTED DATA: ".Dumper($projectprop_data);

    # print STDERR Dumper $nested_data;
    
    my $basename = basename("$phenotype_file.spatially_corrected");

    copy("$phenotype_file.spatially_corrected", $c->config->{basepath}."/static/documents/tempfiles/spatial_model_files/$basename");

    my $download_url = "/documents/tempfiles/spatial_model_files/$basename";
    my $download_link = "<a href=\"$download_url\">Download Results</a>";

    $c->stash->{rest} = {
        result => \@data,
        download_link => $download_link,
        accession_names => \@accessions,
        phenotype_file => $phenotype_file,
        traits => \@traits,
        nested_data => JSON::Any->encode($nested_data),
        analysis_design => JSON::Any->encode($analysis_design),
        projectprop_data => JSON::Any->encode($projectprop_data),
        moran_p_values => \@moran_p_values,
        model_string => $model_string
    };

};

sub result_file_to_hash {
    my $self = shift;
    my $c = shift;
    my $file = shift;

    print STDERR "result_file_to_hash(): Processing file $file...\n";
    my @lines = read_file($file);
    chomp(@lines);

    my $header_line = shift(@lines);
    my ($accession_header, @value_cols) = split /\t/, $header_line;

    my $now = DateTime->now();
    my $timestamp = $now->ymd()."T".$now->hms();

    my $operator = $c->user()->get_object()->get_first_name()." ".$c->user()->get_object()->get_last_name();

    my @fields;
    my @accession_names;
    my %analysis_data;

    my $html = qq | <style> th, td {padding: 10px;} </style> \n <table cellpadding="20" cellspacing="20"> |;

    $html .= "<br><tr>";
    for (my $m=0; $m<@value_cols; $m++) {
      $html .= "<th scope=\"col\">".($value_cols[$m])."</th>";
    }
    $html .= "</tr><tr>";
    foreach my $line (@lines) {
	      my ($accession_name, @values) = split /\t/, $line;
	      push @accession_names, $accession_name;

        #$html .= "<tr><td>".join("</td><td>", $accession_name)."</td>";

        for (my $k=0; $k<@value_cols; $k++) { 
          #print STDERR "adding  $values[$k] to column $value_cols[$k]\n";
          $html .= "<td>".($values[$k])."</td>";
        }

	      for(my $n=0; $n<@values; $n++) {
	         #print STDERR "Building hash for trait $accession_name and value $value_cols[$n]\n";
	          $analysis_data{$accession_name}->{$value_cols[$n]} = [ $values[$n], $timestamp, $operator, "", "" ];



	      }
        $html .= "</tr>"

    }
    $html .= "</table>";

    #print STDERR "Analysis data formatted: ".Dumper(\%analysis_data);

    return (\%analysis_data);
}
sub make_R_trait_name {
    my $trait = shift;

    if ($trait =~ /^\d/) {
	$trait = "X".$trait;
    }
    $trait =~ s/\&/\_/g;
    $trait =~ s/\%//g;
    $trait =~ s/\s/\_/g;
    $trait =~ s/\//\_/g;
    $trait =~ tr/ /./;
    $trait =~ tr/\//./;
    $trait =~ s/\:/\_/g;
    $trait =~ s/\|/\_/g;
    $trait =~ s/\-/\_/g;

    return $trait;
}

sub store_spatial_adjustments: Path('/ajax/spatial_model/store_spatial_adjustments') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $spatial_adjustments = $c->req->param("spatial_adjustments"); # should be a JSON of plot->trait->adjustment

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    my $trial = $schema->resultset('Project::Project')->find({
        project_id => $trial_id, 
    });

    if (!$trial) {
        $c->stash->{rest} = {error => "Error: no trial with ID $trial_id found.\n"};
        return;
    }

    my $spatial_adjustments_cvtermid = SGN::Model::Cvterm->get_cvterm_row($schema, 'spatially_corrected_trait_adjustments_json', 'project_property')->cvterm_id();

    my $row_to_overwrite = $schema->resultset('Project::Projectprop')->find({
        project_id => $trial_id, 
        type_id => $spatial_adjustments_cvtermid
    });

    eval {
        if ($row_to_overwrite) {
            $row_to_overwrite->delete();
        }
        my $row = $schema->resultset("Project::Projectprop")->create({
            project_id => $trial_id,
            type_id=>$spatial_adjustments_cvtermid,
            value=>$spatial_adjustments
        });
    };
    
    if ($@) {
        $c->stash->{rest} = {error => "An error occurred saving spatial corrections to this trial. It may still be saved as a standalone analysis. \n $@ \n"};
        return;
    }



    $c->stash->{rest} = {success => 1};
    
}

sub retrieve_spatial_adjustments: Path('/ajax/spatial_model/retrieve_spatial_adjustments') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    my $trial = $schema->resultset('Project::Project')->find({
        project_id => $trial_id, 
    });

    if (!$trial) {
        $c->stash->{rest} = {error => "Error: no trial with ID $trial_id found.\n"};
        return;
    }

    my $spatial_adjustments_cvtermid = SGN::Model::Cvterm->get_cvterm_row($schema, 'spatially_corrected_trait_adjustments_json', 'project_property')->cvterm_id();

    my $q = 'SELECT value FROM projectprop
    WHERE project_id=? AND type_id=?';

    my $spatial_adjustments_data_row = $schema->storage->dbh()->prepare($q);

    $spatial_adjustments_data_row->execute($trial_id, $spatial_adjustments_cvtermid);

    my $spatial_adjustments_json = $spatial_adjustments_data_row->fetchrow_array();

    if (!$spatial_adjustments_json) {
        $c->stash->{rest} = {data => "", message => "No spatial corrections associated with this trial.\n"};
        return;
    } 

    $c->stash->{rest} = {data => $spatial_adjustments_json};
    return;
}

sub get_spatial_adjusted_traits: Path('/ajax/spatial_model/get_spatial_adjusted_traits/') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado", $sp_person_id);

    my $trial = $schema->resultset('Project::Project')->find({
        project_id => $trial_id, 
    });

    if (!$trial) {
        $c->stash->{rest} = {error => "Error: no trial with ID $trial_id found.\n"};
        return;
    }

    my $spatial_adjustments_cvtermid = SGN::Model::Cvterm->get_cvterm_row($schema, 'spatially_corrected_trait_adjustments_json', 'project_property')->cvterm_id();

    my $q = 'SELECT value FROM projectprop
    WHERE project_id=? AND type_id=?';

    my $spatial_adjustments_data_row = $schema->storage->dbh()->prepare($q);

    $spatial_adjustments_data_row->execute($trial_id, $spatial_adjustments_cvtermid);

    my $spatial_adjustments_exists = $spatial_adjustments_data_row->fetchrow_array();

    if (!$spatial_adjustments_exists) {
        $c->stash->{rest} = {error => "No spatial corrections associated with this trial.\n"};
        return;
    } 

    my $traits = {};

    my $spatial_adjustments = JSON::Any->decode($spatial_adjustments_exists);

    foreach my $plot (keys(%{$spatial_adjustments})) {
        foreach my $trait (keys(%{$plot})) {
            $traits->{$trait} = 1;
        }
    }

    $c->stash->{rest} = {
        data => JSON::Any->encode($traits)
    };
    return;
}

1;
