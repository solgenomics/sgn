package CXGN::Fieldbook::DownloadTrial;

use Moose;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use File::Copy;
use File::Spec::Functions;
use Digest::MD5;
use CXGN::List::Validate;
use Data::Dumper;
use CXGN::Trial::TrialLayout;
use Spreadsheet::WriteExcel;
use CXGN::Trait;
use CXGN::List::Transform;
use CXGN::People::Person;
use DateTime;
use CXGN::Stock::Accession;
use CXGN::Stock;

has 'bcs_schema' => (
    isa => "Bio::Chado::Schema",
    is => 'ro',
    required => 1,
);

has 'metadata_schema' => (
    isa => "CXGN::Metadata::Schema",
    is => 'ro',
    required => 1,
);

has 'phenome_schema' => (
    isa => "CXGN::Phenome::Schema",
    is => 'ro',
    required => 1,
);

has 'trial_id'   => (
    isa => "Int",
    is => 'ro',
    required => 1,
);

has 'tempfile' => (isa => 'Str', is => 'ro',
    predicate => 'has_tempfile',
    required => 1,
);

has 'archive_path' => (isa => 'Str', is => 'ro',
    predicate => 'has_archive_path',
    required => 1,
);

has 'user_id' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has 'user_name' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'data_level' => (
    is => 'ro',
    isa => 'Str',
    default => 'plots',
);
  
has 'file_metadata' => (isa => 'Str', is => 'rw', predicate => 'has_file_metadata');

has 'treatment_project_id' => (
    isa => 'Maybe[Int]',
    is => 'rw'
);

has 'selected_columns' => (
    is => 'ro',
    isa => 'HashRef',
);

sub download { 
    my $self = shift;
    my %errors;
    my @error_messages;
    
    my $schema = $self->bcs_schema();
    my $trial_id = $self->trial_id();
    my $tempfile = $self->tempfile();
    my $wb = Spreadsheet::WriteExcel->new($tempfile);
    if (!$wb) {
        push @error_messages, "Could not create file.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }
    
    my $ws = $wb->add_worksheet();
    my $trial_layout;
    print STDERR "\n\nTrial id: ($trial_id)\n\n";
    try {
        $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    };
    if (!$trial_layout) {
        push @error_messages, "Trial does not have valid field design.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    my $selected_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id});
    my $location_name = $selected_trial->get_location ? $selected_trial->get_location->[1] : '';
    my $trial_year = $selected_trial->get_year ? $selected_trial->get_year : '';

    my $treatment = $self->treatment_project_id();
    my $treatment_trial;
    my $treatment_name = "";
    my $treatment_units;
    if ($treatment){
        $treatment_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $treatment});
        $treatment_name = $treatment_trial->get_name();
    }

    my $trial_name =  $trial_layout->get_trial_name();

    my %selected_cols = %{$self->selected_columns};

    my %treatment_stock_hash;
    my $current_col_num = 0;
    my @possible_cols = ();
    if ($self->data_level eq 'plots') {
        @possible_cols = ('plot_name','block_number','plot_number','rep_number','row_number','col_number','accession_name','is_a_control','pedigree','location_name','trial_name','year','synonyms','tier');
        $treatment_units = $treatment ? $treatment_trial->get_plots() : [];
    } elsif ($self->data_level eq 'plants') {
        @possible_cols = ('plant_name','plot_name','block_number','plant_number','plot_number','rep_number','row_number','col_number','accession_name','is_a_control','pedigree','location_name','trial_name','year','ssynonyms','tier');
        $treatment_units = $treatment ? $treatment_trial->get_plants() : [];
    } elsif ($self->data_level eq 'subplots') {
        @possible_cols = ('subplot_name','plot_name','block_number','subplot_number','plot_number','rep_number','row_number','col_number','accession_name','is_a_control','pedigree','location_name','trial_name','year','ssynonyms','tier');
        $treatment_units = $treatment ? $treatment_trial->get_subplots() : [];
    } elsif ($self->data_level eq 'plants_subplots') {
        @possible_cols = ('plant_name','subplot_name','plot_name','block_number','subplot_number','plant_number','plot_number','rep_number','row_number','col_number','accession_name','is_a_control','pedigree','location_name','trial_name','year','ssynonyms','tier');
        $treatment_units = $treatment ? $treatment_trial->get_plants() : [];
    }

    foreach (@possible_cols){
        if ($selected_cols{$_}){
            $ws->write(0, $current_col_num, $_);
            $current_col_num++;
        }
    }
    if($treatment_trial){
        $ws->write(0, $current_col_num, "Treatment:".$treatment_name);
        foreach (@$treatment_units){
            $treatment_stock_hash{$_->[1]}++;
        }
    }

    my $tl = $trial_layout->get_design();
    if (!$tl){
        push @error_messages, "Trial does not have valid field design. Please contact us.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }
    my %design = %$tl;
    my $row_num = 1;
    foreach my $key (sort { $a <=> $b} keys %design) {
        my %design_info = %{$design{$key}};

        if ($self->data_level eq 'plots') {
            my $current_col_num = 0;
            foreach (@possible_cols){
                if ($selected_cols{$_}){
                    if ($_ eq 'location_name'){
                        $ws->write($row_num, $current_col_num, $location_name );
                    } elsif ($_ eq 'trial_name'){
                        $ws->write($row_num, $current_col_num, $trial_name );
                    } elsif ($_ eq 'year'){
                        $ws->write($row_num, $current_col_num, $trial_year );
                    } elsif ($_ eq 'tier'){
                        $ws->write($row_num, $current_col_num, $design_info{"row_number"}."/".$design_info{"col_number"} );
                    } elsif ($_ eq 'synonyms'){
                        my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                        $ws->write($row_num, $current_col_num, join ',', @{$accession->synonyms} );
                    } elsif ($_ eq 'pedigree'){
                        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                        $ws->write($row_num, $current_col_num, $accession->get_pedigree_string('Parents') );
                    } else {
                        $ws->write($row_num, $current_col_num, $design_info{$_} );
                    }
                    $current_col_num++;
                }
            }
            if(exists($treatment_stock_hash{$design_info{'plot_name'}})){
                $ws->write($row_num, $current_col_num, 1);
            }

            $row_num++;
        } elsif ($self->data_level eq 'plants'){
            my $plant_names = $design_info{'plant_names'};
            my $plant_num = 1;
            foreach (sort @$plant_names) {
                my $current_col_num = 0;
                foreach my $c (@possible_cols){
                    if ($selected_cols{$c}){
                        if ($c eq 'plant_name'){
                            $ws->write($row_num, $current_col_num, $_ );
                        } elsif ($c eq 'plant_number'){
                            $ws->write($row_num, $current_col_num, $plant_num );
                        } elsif ($c eq 'location_name'){
                            $ws->write($row_num, $current_col_num, $location_name );
                        } elsif ($c eq 'trial_name'){
                            $ws->write($row_num, $current_col_num, $trial_name );
                        } elsif ($c eq 'year'){
                            $ws->write($row_num, $current_col_num, $trial_year );
                        } elsif ($c eq 'tier'){
                            $ws->write($row_num, $current_col_num, $design_info{"row_number"}."/".$design_info{"col_number"} );
                        } elsif ($c eq 'synonyms'){
                            my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                            $ws->write($row_num, $current_col_num, join ',', @{$accession->synonyms} );
                        } elsif ($c eq 'pedigree'){
                            my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                            $ws->write($row_num, $current_col_num, $accession->get_pedigree_string('Parents') );
                        } else {
                            $ws->write($row_num, $current_col_num, $design_info{$c} );
                        }
                        $current_col_num++;
                    }
                }
                if(exists($treatment_stock_hash{$_})){
                    $ws->write($row_num,$current_col_num,1);
                }

                $plant_num++;
                $row_num++;
            }
        } elsif ($self->data_level eq 'subplots'){
            my $subplot_names = $design_info{'subplot_names'};
            my $subplot_num = 1;
            foreach (sort @$subplot_names) {
                my $current_col_num = 0;
                foreach my $c (@possible_cols){
                    if ($selected_cols{$c}){
                        if ($c eq 'subplot_name'){
                            $ws->write($row_num, $current_col_num, $_ );
                        } elsif ($c eq 'subplot_number'){
                            $ws->write($row_num, $current_col_num, $subplot_num );
                        } elsif ($c eq 'location_name'){
                            $ws->write($row_num, $current_col_num, $location_name );
                        } elsif ($c eq 'trial_name'){
                            $ws->write($row_num, $current_col_num, $trial_name );
                        } elsif ($c eq 'year'){
                            $ws->write($row_num, $current_col_num, $trial_year );
                        } elsif ($c eq 'tier'){
                            $ws->write($row_num, $current_col_num, $design_info{"row_number"}."/".$design_info{"col_number"} );
                        } elsif ($c eq 'synonyms'){
                            my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                            $ws->write($row_num, $current_col_num, join ',', @{$accession->synonyms} );
                        } elsif ($c eq 'pedigree'){
                            my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                            $ws->write($row_num, $current_col_num, $accession->get_pedigree_string('Parents') );
                        } else {
                            $ws->write($row_num, $current_col_num, $design_info{$c} );
                        }
                        $current_col_num++;
                    }
                }
                if(exists($treatment_stock_hash{$_})){
                    $ws->write($row_num,$current_col_num,1);
                }

                $subplot_num++;
                $row_num++;
            }
        } elsif ($self->data_level eq 'plants_subplots'){
            my $subplot_plant_names = $design_info{'subplots_plant_names'};
            my $subplot_num = 1;
            foreach my $s (sort keys %$subplot_plant_names) {
                my $plants = $subplot_plant_names->{$s};
                my $plant_num = 1;
                foreach my $p (sort @$plants){
                    my $current_col_num = 0;
                    foreach my $c (@possible_cols){
                        if ($selected_cols{$c}){
                            if ($c eq 'plant_name'){
                                $ws->write($row_num, $current_col_num, $p );
                            } elsif ($c eq 'subplot_name'){
                                $ws->write($row_num, $current_col_num, $s );
                            } elsif ($c eq 'subplot_number'){
                                $ws->write($row_num, $current_col_num, $subplot_num );
                            } elsif ($c eq 'plant_number'){
                                $ws->write($row_num, $current_col_num, $plant_num );
                            } elsif ($c eq 'location_name'){
                                $ws->write($row_num, $current_col_num, $location_name );
                            } elsif ($c eq 'trial_name'){
                                $ws->write($row_num, $current_col_num, $trial_name );
                            } elsif ($c eq 'year'){
                                $ws->write($row_num, $current_col_num, $trial_year );
                            } elsif ($c eq 'tier'){
                                $ws->write($row_num, $current_col_num, $design_info{"row_number"}."/".$design_info{"col_number"} );
                            } elsif ($c eq 'synonyms'){
                                my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                                $ws->write($row_num, $current_col_num, join ',', @{$accession->synonyms} );
                            } elsif ($c eq 'pedigree'){
                                my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                                $ws->write($row_num, $current_col_num, $accession->get_pedigree_string('Parents') );
                            } else {
                                $ws->write($row_num, $current_col_num, $design_info{$c} );
                            }
                            $current_col_num++;
                        }
                    }
                    if(exists($treatment_stock_hash{$p})){
                        $ws->write($row_num,$current_col_num,1);
                    }
                    $plant_num++;
                    $row_num++;
                }
                $subplot_num++;
            }
        }
    }
    $wb->close();

    my $user_id = $self->user_id();
    open(my $F, "<", $tempfile) || die "Can't open file ".$self->tempfile();
        binmode $F;
        my $md5 = Digest::MD5->new();
        $md5->addfile($F);
    close($F);

    my $project = $trial_layout->get_project;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $user_name = $self->user_name();
    my $subdirectory_name = "tablet_field_layout";
    my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".$project->name.".xls");
    my $archive_path = $self->archive_path();
    my $file_destination =  catfile($archive_path, $archived_file_name);

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory_name)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory_name));
    }

    my $metadata_schema = $self->metadata_schema();
    my $md_row = $metadata_schema->resultset("MdMetadata")->create({
        create_person_id => $user_id,
    });
    $md_row->insert();

    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($file_destination),
        dirname => dirname($file_destination),
        filetype => 'tablet field layout xls',
        md5checksum => $md5->hexdigest(),
        metadata_id => $md_row->metadata_id(),
    });
    $file_row->insert();

    my $field_layout_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type' );

    my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->find(
        {
            'nd_experiment_projects.project_id' => $project->project_id,
            type_id => $field_layout_cvterm->cvterm_id(),
        },
        {
            join => 'nd_experiment_projects',
        }
    );

    my $phenome_schema = $self->phenome_schema();
    my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")->create({
        nd_experiment_id => $experiment->nd_experiment_id(),
        file_id => $file_row->file_id(),
    });
    $experiment_files->insert();

    move($tempfile,$file_destination);
    unlink $tempfile;
    
    my $result = $file_row->file_id;
    return {result => $result, file => $file_destination, file_id=>$file_row->file_id() };
}

1;
