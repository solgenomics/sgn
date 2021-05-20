
=head1 NAME

SGN::Controller::AJAX::ImageAnalysis - a REST controller class to provide image analysis including
functions for necrosis image analysis https://github.com/solomonnsumba/Necrosis-_Web_Server

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::ImageAnalysis;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use LWP::Simple;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use CXGN::UploadFile;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
use Text::CSV;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::FileResponse;
use CXGN::Onto;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;
use CXGN::Tag;
use CXGN::DroneImagery::ImageTypes;
use Time::Piece;
use POSIX;
use Math::Round;
use List::Util qw/sum/;
use Parallel::ForkManager;
use CXGN::Image::Search;
use CXGN::Trait::Search;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub image_analysis_submit : Path('/ajax/image_analysis/submit') : ActionClass('REST') { }
sub image_analysis_submit_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $image_ids = decode_json $c->req->param('selected_image_ids');
    my $service = $c->req->param('service');
    my $trait = $c->req->param('trait');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $main_production_site_url = $c->config->{main_production_site_url};

    unless (ref($image_ids) eq 'ARRAY') { $image_ids = [$image_ids]; }

    my ($trait_name, $db_accession) = split(/\|/, $trait);
    my ($db, $accession) = split(/:/, $db_accession);
    my ($trait_details, $record_number) = CXGN::Trait::Search->new({
        bcs_schema=>$schema,
        ontology_db_name_list => [$db],
        accession_list => [$accession]
    })->search();

    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        phenome_schema=>$phenome_schema,
        image_id_list=>$image_ids,
    });

    my ($result, $records_total) = $image_search->search();

    my @image_urls;
    my @image_files;
    foreach (@$result) {
        my $image = SGN::Image->new($schema->storage->dbh, $_->{image_id}, $c);
        my $original_img = $main_production_site_url.$image->get_image_url("original");
        my $image_file = $image->get_filename('original_converted', 'full');
        push @image_urls, $original_img;
        push @image_files, $image_file;
    }
    print STDERR Dumper \@image_urls;

    my %service_details = (
        'necrosis' => {
            server_endpoint => "http://unet.mcrops.org/api/",
            image_type_name => "image_analysis_necrosis_solomon_nsumba",
        },
        'whitefly_count' => {
            server_endpoint => "http://18.216.149.204/home/api2/",
            image_type_name => "image_analysis_white_fly_count_solomon_nsumba",
        },
        'count_contours' => {
            image_type_name => "image_analysis_contours",
            trait_name => "count_contours",
            script => 'GetContours.py',
            input_image => 'image_path',
            outfile_image => 'outfile_path',
            results_outfile => 'results_outfile_path',
        },
        'largest_contour_percent' => {
            image_type_name => 'image_analysis_largest_contour',
            trait_name => 'percent_largest_contour',
            script => 'GetLargestContour.py',
            input_image => 'image_path',
            outfile_image => 'outfile_path',
            results_outfile => 'results_outfile_path',
        },
        'count_sift' => {
            image_type_name => "image_analysis_sift",
            trait_name => "count_sift",
            script => 'ImageProcess/CalculatePhenotypeSift.py',
            input_image => 'image_paths',
            outfile_image => 'outfile_paths',
            results_outfile => 'results_outfile_path',
        }
    );

    my $image_type_name = $service_details{$service}->{'image_type_name'};

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $image_type_name, 'project_md_image')->cvterm_id();

    my $image_tag_id = CXGN::Tag::exists_tag_named($schema->storage->dbh, $image_type_name);
    if (!$image_tag_id) {
        my $image_tag = CXGN::Tag->new($schema->storage->dbh);
        $image_tag->set_name($image_type_name);
        $image_tag->set_description('Image analysis result image: '.$image_type_name);
        $image_tag->set_sp_person_id($user_id);
        $image_tag_id = $image_tag->store();
    }
    my $image_tag = CXGN::Tag->new($schema->storage->dbh, $image_tag_id);
    my $ua = LWP::UserAgent->new(
        ssl_opts => {
                        verify_hostname => 0,
                        timeout         => 60,
                    }
    );
    my $it = 0;

    foreach (@image_files) {
        my $dir = $c->tempfiles_subdir('/'.$image_type_name);
        my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $image_type_name.'/imageXXXX');
        $archive_temp_image .= '.png';
        my %res;

        if (defined $service_details{$service}->{'server_endpoint'}) { # submit image to external service for processing
            print STDERR "Using endpoint ".$service_details{$service}->{'server_endpoint'}." to analyze image\n";
            my $resp = $ua->post(
                $service_details{$service}->{'server_endpoint'},
                Content_Type => 'form-data',
                Content => [
                    image => [ $_, $_, Content_Type => 'image/png' ],
                ]
            );
            if ($resp->is_success) {
                my $message = $resp->decoded_content;
                my $message_hashref = decode_json $message;
                my $rc = getstore($message_hashref->{image_link}, $archive_temp_image);
                if (is_error($rc)) {
                    die "getstore of ".$message_hashref->{image_link}." failed with $rc";
                }
                print STDERR Dumper $message_hashref;
                $res{'value'} = $message_hashref->{trait_value};
                $res{'trait'} = $trait;
                $res{'trait_id'} = $trait_details->[0]->{trait_id};
            }
            else {
                print STDERR Dumper $resp->status_line;
                $res{'error'} = $resp->status_line;
            }
        }
        elsif (defined $service_details{$service}->{'script'}) { # supply image to local script for processing
            my $script = $service_details{$service}->{'script'};
            print STDERR "Using script $script to analyze image\n";
            my $input_image = $service_details{$service}->{'input_image'};
            my $outfile_image = $service_details{$service}->{'outfile_image'};
            my $results_outfile = $service_details{$service}->{'results_outfile'};
            my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $image_type_name.'/imageXXXX');

            my $cmd = $c->config->{python_executable} . ' ' . $c->config->{rootpath} .
                '/DroneImageScripts/' . $script . ' --' . $input_image . ' \'' . $_ .
                '\' --' . $outfile_image . ' \'' . $archive_temp_image . '\' --' .
                $results_outfile . ' \'' . $archive_temp_results . '\' ';
            # print STDERR Dumper $cmd;
            my $status = system($cmd);

            my $csv = Text::CSV->new({ sep_char => ',' });
            open(my $fh, '<', $archive_temp_results)
                or die "Could not open file '$archive_temp_results' $!";
            my $line = <$fh>;
            my @columns;
            if ($csv->parse($line)) {
                @columns = $csv->fields();
            }
            $res{'value'} = $columns[0];
            $res{'trait'} = $service_details{$service}->{'trait_name'};
        }

        $res{'original_image'} = $image_urls[$it];

        unless (defined $res{'error'}) {

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5 = $image->calculate_md5sum($archive_temp_image);
            my $stock_id = $result->[$it]->{stock_id};
            my $project_id = $result->[$it]->{project_id};

            my $project_where = ' ';
            my $project_join = ' ';
            if ($project_id) {
                $project_where = " AND project_md_image.type_id = $linking_table_type_id AND project_md_image.project_id = $project_id ";
                $project_join = " JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id) ";
            }

            my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                $project_join
                JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
                WHERE md_image.obsolete = 'f'
                $project_where
                AND stock_image.stock_id = $stock_id
                AND md_image.md5sum = '$md5';";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute();
            my ($saved_image_id) = $h->fetchrow_array();
            my $image_id;
            if ($saved_image_id) {
                print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
                $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
                $image_id = $image->get_image_id();
            }
            else {
                $image->set_sp_person_id($user_id);
                if ($project_id) {
                    my $ret = $image->process_image($archive_temp_image, 'project', $project_id, $linking_table_type_id);
                    if (!$ret ) {
                        return {error => "Image processing for $archive_temp_image did not work. Image not associated to stock_id $stock_id.<br/><br/>"};
                    }
                    my $stock_associate = $image->associate_stock($stock_id);
                }
                else {
                    my $ret = $image->process_image($archive_temp_image, 'stock', $stock_id);
                    if (!$ret ) {
                        return {error => "Image processing for $archive_temp_image did not work. Image not associated to stock_id $stock_id.<br/><br/>"};
                    }
                }
                print STDERR "Saved $archive_temp_image\n";
                $image_id = $image->get_image_id();
                my $added_image_tag_id = $image->add_tag($image_tag);
            }

            $res{'analyzed_image_id'} = $image_id;
            $res{'image_link'} = $image->get_image_url("original");
        }

        $result->[$it]->{result} = \%res;
        $it++;
    }

    # print STDERR "Before grouping result is: ".Dumper($result);

    $c->stash->{rest} = { success => 1, results => $result };
}

sub image_analysis_group : Path('/ajax/image_analysis/group') : ActionClass('REST') { }
sub image_analysis_group_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $result = decode_json $c->req->param('result');
    # print STDERR Dumper($result);
    my %grouped_results = ();
    my @table_data = ();

    my ($uniquename, $next_uniquename, $trait, $value, $results_ref, $next_results_ref);
    # sort result hash array by $stock_id
    my @sorted_result = sort {$$a{"stock_id"} <=> $$b{"stock_id"} } @{$result};
    # my $old_uniquename = $sorted_result[0]->{'stock_uniquename'};
    $grouped_results{$sorted_result[0]->{'stock_uniquename'}}{$sorted_result[0]->{'result'}->{'trait'}} = [];

    for (my $i = 0; $i <= $#sorted_result; $i++) {
        $results_ref = $sorted_result[$i];
        # print STDERR "\n\nResults ref is ".Dumper($results_ref)."\n\n";
        $uniquename = $results_ref->{'stock_uniquename'};
        $trait = $results_ref->{'result'}->{'trait'};
        $value = $results_ref->{'result'}->{'value'};

        if ($trait && $value) {
            print STDERR "Working on $trait for $uniquename. Saving the details \n";
            push @{$grouped_results{$uniquename}{$trait}}, {
                        stock_id => $results_ref->{'stock_id'},
                        collector => $results_ref->{'image_username'},
                        original_link => $results_ref->{'result'}->{'original_image'},
                        analyzed_link => $results_ref->{'result'}->{'image_link'},
                        image_name => $results_ref->{'image_original_filename'}.$results_ref->{'image_file_ext'},
                        trait_id => $results_ref->{'result'}->{'trait_id'},
                        value => $value + 0
                };
        }
        else { # if no result returned for an image, include it with error details.
            print STDERR "No usable analysis data in this results_ref \n";
            push @{$grouped_results{$uniquename}{$trait}}, {
                        stock_id => $results_ref->{'stock_id'},
                        collector => $results_ref->{'image_username'},
                        original_link => $results_ref->{'result'}->{'original_image'},
                        analyzed_link => 'Error: ' . $results_ref->{'result'}->{'error'},
                        image_name => $results_ref->{'image_original_filename'}.$results_ref->{'image_file_ext'},
                        trait_id => $results_ref->{'result'}->{'trait_id'},
                        value => 'NA'
                };
        }

        $next_results_ref = $sorted_result[$i+1];
        $next_uniquename = $next_results_ref->{'stock_uniquename'};

        if ($next_uniquename ne $uniquename) {

            print STDERR "Calculating mean value for $uniquename\n";

            my $uniquename_data = $grouped_results{$uniquename};

            foreach my $trait (keys %{$uniquename_data}) {
                my $details = $uniquename_data->{$trait};
                my @values = map { $_->{'value'}} @{$uniquename_data->{$trait}};
                @values= grep { $_ != 'NA' } @values; # remove NAs before calculating mean
                # print STDERR "\n\n\nVALUES ARE @values and length is ". scalar @values . "\n\n\n";
                my $mean_value = @values ? sprintf("%.2f", sum(@values)/@values) : undef;
                print STDERR "Mean value is $mean_value\n";
                push @table_data, {
                    observationUnitDbId => $uniquename_data->{$trait}[0]->{'stock_id'},
                    observationUnitName => $uniquename,
                    collector => $uniquename_data->{$trait}[0]->{'collector'},
                    observationTimeStamp => localtime()->datetime,
                    observationVariableDbId => $uniquename_data->{$trait}[0]->{'trait_id'},
                    observationVariableName => $trait,
                    value => $mean_value,
                    details => $details,
                    numberAnalyzed => scalar @values
                    # Add previously observed trait value
                };
            }
        }
    }
    # print STDERR "table data is ".Dumper(@table_data);
    $c->stash->{rest} = { success => 1, results => \@table_data };
}

sub _check_user_login {
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    return ($user_id, $user_name, $user_role);
}

1;
