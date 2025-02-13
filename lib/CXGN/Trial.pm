
=head1 NAME

CXGN::Trial - factory object for project entries (phenotyping trials, genotyping trials, crossing trials, and analyses

=head1 DESCRIPTION

my $trial = CXGN::Trial->new( { bcs_schema => $schema, ... , trial_id => $trial_id });

If $trial_id is a phenotyping trial, the type of object returned will be CXGN::PhenotypingTrial.

If $trial_id is a genotyping trial, the type of object returned will be CXGN::GenotypingTrial.

If $trial_id is a crossing trial, the type of object returned will be CXGN::CrossingTrial.

If $trial_id is an analysis, the type of object returned will be CXGN::Analysis.

=over 6

=item Note:

if there is a chance that a CXGN::Analysis object will be created, you also need to
supply a people_schema, phenome_schema, and metadata_schema object to the constructor

=back


Inheritance structure of Trial objects:

      CXGN::Project
      |
      |--CXGN::PhenotypingTrial
      |  |
      |  |--CXGN::GenotypingTrial
      |  |
      |  ---CXGN::CrossingTrial
      |
      ---CXGN::Analysis


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu> and many others

=head1 METHODS

=cut


package CXGN::Trial;

use Moose;
use Data::Dumper;
use Try::Tiny;
use CXGN::Trial::Folder;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::TrialLayoutDownload;
use SGN::Model::Cvterm;
use Time::Piece;
use Time::Seconds;
use CXGN::Calendar;
use JSON;
use File::Basename qw | basename dirname|;
use CXGN::BrAPI::v2::ExternalReferences;
use CXGN::PhenotypingTrial;
use CXGN::GenotypingTrial;
use CXGN::CrossingTrial;
use CXGN::Analysis;
use CXGN::SamplingTrial;
use CXGN::ManagementFactor;
use CXGN::GenotypeDataProject;
use CXGN::AerialImagingEventBandProject;
use CXGN::AerialImagingEventProject;


sub new {
    my $class = shift;
    my $args = shift;

    my $schema = $args->{bcs_schema};
    my $trial_id = $args->{trial_id};

    my $trial_rs = $schema->resultset("Project::Projectprop")->search( { project_id => $trial_id },{ join => 'type' });

    if ($trial_id && $trial_rs->count() == 0) {
        return CXGN::PhenotypingTrial->new($args);
    }

    my $object;
    while (my $trial_row = $trial_rs->next()) {
        my $name = $trial_row->type()->name();
        my $val = $trial_row->value();

        if ($val eq "genotyping_plate") {
            return CXGN::GenotypingTrial->new($args);
        }
        elsif ($name eq "crossing_trial") {
            return CXGN::CrossingTrial->new($args);
        }
        elsif ($name eq "analysis_experiment") {
            return CXGN::Analysis->new($args);
        }
        elsif ($val eq "treatment") {
            return CXGN::ManagementFactor->new($args);
        }
        elsif ($val eq "sampling_trial") {
            return CXGN::SamplingTrial->new($args);
        }
        elsif (($val eq "genotype_data_project") || ($val eq "pcr_genotype_data_project")) {
            return CXGN::GenotypeDataProject->new($args);
        }
        elsif ($val eq "drone_run") {
            return CXGN::AerialImagingEventProject->new($args);
        }
        elsif ($val eq "drone_run_band") {
            return CXGN::AerialImagingEventBandProject->new($args);
        }
        else {
            $object = CXGN::PhenotypingTrial->new($args);
        }
    }
    return $object;
}

=head2 class method get_all_locations()

 Usage:        my $locations = CXGN::Trial::get_all_locations($schema)
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_all_locations {
    my $schema = shift;
	my $location_id = shift;
    my @locations;

	my %search_params;
	if ($location_id){
		$search_params{'nd_geolocation_id'} = $location_id;
	}

    my $loc = $schema->resultset('NaturalDiversity::NdGeolocation')->search( \%search_params, {order_by => { -asc => 'nd_geolocation_id' }} );
    while (my $s = $loc->next()) {
        my $loc_props = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search( { nd_geolocation_id => $s->nd_geolocation_id() }, {join=>'type', '+select'=>['me.value', 'type.name'], '+as'=>['value', 'cvterm_name'] } );

		my %attr;
        $attr{'geodetic datum'} = $s->geodetic_datum();

        my $country = '';
        my $country_code = '';
        my $location_type = '';
        my $abbreviation = '';
        my $address = '';

        while (my $sp = $loc_props->next()) {
            if ($sp->get_column('cvterm_name') eq 'country_name') {
                $country = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'country_code') {
                $country_code = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'location_type') {
                $location_type = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'abbreviation') {
                $abbreviation = $sp->get_column('value');
            } elsif ($sp->get_column('cvterm_name') eq 'geolocation address') {
                $address = $sp->get_column('value');
            } else {
                $attr{$sp->get_column('cvterm_name')} = $sp->get_column('value') ;
            }
        }

        my @reference_locations = ($s->nd_geolocation_id());
        my $references = CXGN::BrAPI::v2::ExternalReferences->new({
            bcs_schema => $schema,
            table_name => 'nd_geolocation',
            table_id_key => 'nd_geolocation_id',
            id => \@reference_locations
        });
        my $external_references_search = $references->search();
        my $external_references = $external_references_search->{$s->nd_geolocation_id()} || [];


        push @locations, [$s->nd_geolocation_id(), $s->description(), $s->latitude(), $s->longitude(), $s->altitude(), $country, $country_code, \%attr, $location_type, $abbreviation, $address, $external_references],
    }

    return \@locations;
}

# CLASS METHOD!

=head2 class method get_all_project_types()

 Usage:        my @cvterm_ids = CXGN::Trial::get_all_project_types($schema)
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_all_project_types {
    ##my $class = shift;
    my $schema = shift;
    my $project_type_cv_id = $schema->resultset('Cv::Cv')->find( { name => 'project_type' } )->cv_id();
    my $rs = $schema->resultset('Cv::Cvterm')->search( { cv_id=> $project_type_cv_id }, {order_by=>'me.cvterm_id'} );
    my @cvterm_ids;
    if ($rs->count() > 0) {
	@cvterm_ids = map { [ $_->cvterm_id(), $_->name(), $_->definition ] } ($rs->all());
    }
    return @cvterm_ids;
}


=head2 function get_all_phenotype_metadata($schema, $n)

 Note:         Class method!
 Usage:        CXGN::Trial->get_phenotype_metadata($schema, 100);
 Desc:         retrieves maximally $n metadata.md_file entries for the any trial . These entries are created during StorePhenotypes.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_all_phenotype_metadata {
    my $class = shift;
    my $schema = shift;
    my $n = shift || 200;
    my @file_array;
    my %file_info;
    my $q = "SELECT file_id, m.create_date, p.sp_person_id, p.username, basename, dirname, filetype FROM nd_experiment_project JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenome.nd_experiment_md_files ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_md_files.nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata as m using(metadata_id) LEFT JOIN sgn_people.sp_person as p ON (p.sp_person_id=m.create_person_id) WHERE m.obsolete = 0 and NOT (metadata.md_files.filetype='generated from plot from plant phenotypes') and NOT (metadata.md_files.filetype='direct phenotyping') ORDER BY file_id ASC LIMIT $n";
    my $h = $schema->storage()->dbh()->prepare($q);
    $h->execute();

    while (my ($file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype) = $h->fetchrow_array()) {
	$file_info{$file_id} = [$file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype];
    }
    foreach (keys %file_info){
	push @file_array, $file_info{$_};
    }
    return \@file_array;

}



=head2 function get_sorted_plots()

 Usage: CXGN::Trial->get_sorted_plots($schema, $trials, $order, $start, $gaps)
 Desc:  Get an array of plot metadata (plot_id, plot_name, row_number, col_number, etc)
        for plots in the trial.  Sort the plots by the provided traversal parameters.
 Requirements: The Trial(s) MUST have row/col positions for every plot AND there must not
        be any overlapping plots (more than one plot with the same row/col position).
 Ret:   An array of sorted plot metadata
 Args:  trials = an arrayref of trial ids to include
        order = the order to traverse the plots ('by_col_serpentine', 'by_col_zigzag', 'by_row_serpentine', 'by_row_zigzag')
        start = the corner of the trial layout to start the traversal ('bottom_left', 'top_left', 'top_right', 'bottom_right')
        borders = a hashref with keys top, right, bottom, left.  If the value is 1, then include that side as a border
        gaps = when set to 1, include missing plots / gaps as items in the order
 Side Effects:
 Example:

=cut

sub get_sorted_plots {
    my $class = shift;
    my $schema = shift;
    my $trials = shift;
    my $order = shift || 'by_row_serpentine';
    my $start = shift || 'bottom_left';
    my $borders = shift || { top => 0, right => 0, bottom => 0, left => 0 };
    my $gaps = shift || 0;

    # Parse each trial
    my @plot_details;
    my ($min_row, $max_row, $min_col, $max_col, %seen_row_cols);
    foreach my $trial_id (@$trials) {

        # Get plot details from the stored layout information
        my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
            schema => $schema,
            trial_id => $trial_id,
            data_level => 'plots',
            selected_columns => {
                "location_name"=>1,"trial_name"=>1,"plot_name"=>1,"plot_id"=>1,"plot_number"=>1,
                "row_number"=>1,"col_number"=>1,"accession_name"=>1,"seedlot_name"=>1,
                "rep_number"=>1,"block_number"=>1,"is_a_control"=>1,"accession_id"=>1
            },
        });
        my $output = $trial_layout_download->get_layout_output()->{output};

        # Convert plot layout array into hash and add each plot to the plot_details array (of hashes)
        # Check for plot row/col requirements
        # Set the overall min/max row/col positions
        my @outer_array = @{$output};
        my ($inner_array, @keys);
        for my $i (0 .. $#outer_array) {
            $inner_array = $outer_array[$i];
            if (scalar @keys > 0) {
                my %detail_hash;
                @detail_hash{@keys} = @{$outer_array[$i]};
                my $row = $detail_hash{'row_number'};
                my $col = $detail_hash{'col_number'};
                my $key = "$row|$col";

                # Check for undefined row and column positions
                if ( !defined($row) || !defined($col) ) {
                    return { error => "One or more plots do not have a row and/or column defined!" };
                }

                # Check for duplicate positions (plots with the same row / col positions)
                if ( exists $seen_row_cols{$key} ) {
                    return { error => "One or more plots share the same row and column position!" };
                }

                # Set the min/max row/col
                $row = int($row);
                $col = int($col);
                if ( !defined($min_row) || $row < $min_row ) {
                    $min_row = $row;
                }
                if ( !defined($max_row) || $row > $max_row ) {
                    $max_row = $row;
                }
                if ( !defined($min_col) || $col < $min_col ) {
                    $min_col = $col;
                }
                if ( !defined($max_col) || $col > $max_col ) {
                    $max_col = $col;
                }

                push(@plot_details, \%detail_hash);
            }
            else {
                @keys = @{$inner_array};
            }
        }
    }

    # Set starting position:
    #   right = col from max to min
    #   left = col from min to max
    #   top = row from max to min
    #   bottom = row from min to max
    # Add a row/col on either side for the borders
    my ($start_row, $end_row, $delta_row);
    my ($start_col, $end_col, $delta_col);
    if ( $start =~ /right/ ) {
        $start_col = $max_col + 1;
        $end_col = $min_col - 1;
        $delta_col = -1;
    }
    else {
        $start_col = $min_col - 1;
        $end_col = $max_col + 1;
        $delta_col = 1;
    }
    if ( $start =~ /top/ ) {
        $start_row = $max_row + 1;
        $end_row = $min_row - 1;
        $delta_row = -1;
    }
    else {
        $start_row = $min_row - 1;
        $end_row = $max_row + 1;
        $delta_row = 1;
    }

    # Set traversal order:
    #   by_col = first by column (outer loop) then by row (inner loop)
    #   by_row = first by row (outer loop) then by col (inner loop)
    my ($outerloop_key, $outerloop_start, $outerloop_end, $outerloop_delta);
    my ($innerloop_key, $innerloop_start, $innerloop_end, $innerloop_delta);
    if ( $order =~ /by_col/ ) {
        $outerloop_key = 'col_number';
        $outerloop_start = $start_col;
        $outerloop_end = $end_col;
        $outerloop_delta = $delta_col;
        $innerloop_key = 'row_number';
        $innerloop_start = $start_row;
        $innerloop_end = $end_row;
        $innerloop_delta = $delta_row;
    }
    else {
        $outerloop_key = 'row_number';
        $outerloop_start = $start_row;
        $outerloop_end = $end_row;
        $outerloop_delta = $delta_row;
        $innerloop_key = 'col_number';
        $innerloop_start = $start_col;
        $innerloop_end = $end_col;
        $innerloop_delta = $delta_col;
    }

    # Start the traversal
    my @ordered_plots;
    my $o_count = 0;
    my $p_order = 1;

    # Start the outerloop...
    for ( my $o = $outerloop_start; $outerloop_delta > 0 ? $o <= $outerloop_end : $o >= $outerloop_end; $o=$o+$outerloop_delta ) {
        my $starting_p_order = $p_order;

        # Invert the order of every other innerloop when serpentine
        my $i_start = $innerloop_start;
        my $i_end = $innerloop_end;
        my $i_delta = $innerloop_delta;
        if ( $order =~ /serpentine/ ) {
            if ( $o_count % 2 ) {
                $i_start = $innerloop_end;
                $i_end = $innerloop_start;
                $i_delta = $innerloop_delta*-1;
            }
        }

        # Start the innerloop...
        for ( my $i = $i_start; $i_delta > 0 ? $i <= $i_end : $i >= $i_end; $i=$i+$i_delta ) {

            #
            # ADD BORDERS
            #

            # Determine border type based on current position
            my $obt_start = $outerloop_key eq 'row_number' ? ($outerloop_delta > 0 ? 'bottom' : 'top') : ($outerloop_delta > 0 ? 'left' : 'right');
            my $obt_end = $outerloop_key eq 'row_number' ? ($outerloop_delta > 0 ? 'top' : 'bottom') : ($outerloop_delta > 0 ? 'right' : 'left');
            my $ibt_start = $innerloop_key eq 'col_number' ? ($innerloop_delta > 0 ? 'left' : 'right') : ($innerloop_delta > 0 ? 'bottom' : 'top');
            my $ibt_end = $innerloop_key eq 'col_number' ? ($innerloop_delta > 0 ? 'right' : 'left') : ($innerloop_delta > 0 ? 'top' : 'bottom');

            # Add corner 1
            if ( $o == $outerloop_start && $i == $innerloop_start ) {
                if ( $borders->{$obt_start} && $borders->{$ibt_start} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $obt_start . "_" . $ibt_start,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }

            # Add corner 2
            elsif ( $o == $outerloop_end && $i == $innerloop_start ) {
                if ( $borders->{$obt_end} && $borders->{$ibt_start} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $obt_end . "_" . $ibt_start,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }

            # Add corner 3
            elsif ( $o == $outerloop_end && $i == $innerloop_end ) {
                if ( $borders->{$obt_end} && $borders->{$ibt_end} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $obt_end . "_" . $ibt_end,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }

            # Add corner 4
            elsif ( $o == $outerloop_start && $i == $innerloop_end ) {
                if ( $borders->{$obt_start} && $borders->{$ibt_end} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $obt_start . "_" . $ibt_end,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }

            # Add outer start border
            elsif ( $o == $outerloop_start ) {
                if ( $borders->{$obt_start} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $obt_start,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }

            # Add outer end border
            elsif ( $o == $outerloop_end ) {
                if ( $borders->{$obt_end} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $obt_end,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }

            # Add inner start border
            elsif ( $i == $innerloop_start ) {
                if ( $borders->{$ibt_start} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $ibt_start,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }

            # Add inner end border
            elsif ( $i == $innerloop_end ) {
                if ( $borders->{$ibt_end} ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'border',
                        border => $ibt_end,
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }
            }


            #
            # ADD PLOTS
            #
            else {

                # Find the plot with the matching row / col position
                my ($p) = grep { $_->{$outerloop_key} == $o && $_->{$innerloop_key} == $i } @plot_details;

                # Add the plot, if it's found
                if ( defined($p) ) {
                    $p->{order} = $p_order;
                    $p->{type} = 'plot';
                    push(@ordered_plots, $p);
                    $p_order++;
                }

                # Add a gap item when there is no plot, if requested
                elsif ( $gaps ) {
                    push(@ordered_plots, {
                        order => $p_order,
                        type => 'gap',
                        $outerloop_key => $o,
                        $innerloop_key => $i
                    });
                    $p_order++;
                }

            }

        }

        if ( $p_order > $starting_p_order ) {
            $o_count++;
        }
    }

    return { plots => \@ordered_plots };
}


1;
