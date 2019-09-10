
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
use Parallel::ForkManager;
use CXGN::Image::Search;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
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
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $main_production_site_url = $c->config->{main_production_site_url};

    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        phenome_schema=>$phenome_schema,
        image_id_list=>$image_ids,
    });
    my ($result, $records_total) = $image_search->search();
    #print STDERR Dumper $result;

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

    my $ua = LWP::UserAgent->new(
        ssl_opts => { verify_hostname => 0 }
    );
    if ($service eq 'necrosis' || $service eq 'whitefly_count') {
        my $server_endpoint;
        my $image_type_name;
        if ($service eq 'necrosis') {
            $server_endpoint = "http://18.219.45.102/necrosis/api2/";
            $image_type_name = "image_analysis_necrosis_solomon_nsumba";
        }
        if ($service eq 'whitefly_count') {
            $server_endpoint = "http://18.216.149.204/home/api2/";
            $image_type_name = "image_analysis_white_fly_count_solomon_nsumba";
        }
        print STDERR $server_endpoint."\n";

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

        my $it = 0;
        foreach (@image_files) {
            my $resp = $ua->post(
                $server_endpoint,
                Content_Type => 'form-data',
                Content => [
                    image => [ $_, $_, Content_Type => 'image/png' ],
                ]
            );
            if ($resp->is_success) {
                my $message = $resp->decoded_content;
                my $message_hash = decode_json $message;
                print STDERR Dumper $message_hash;
                $message_hash->{original_image} = $image_urls[$it];
                $result->[$it]->{result} = $message_hash;

                my $project_id = $result->[$it]->{project_id};
                my $stock_id = $result->[$it]->{stock_id};

                my $project_where = ' ';
                my $project_join = ' ';
                if ($project_id) {
                    $project_where = " AND project_md_image.type_id = $linking_table_type_id AND project_md_image.project_id = $project_id ";
                    $project_join = " JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id) ";
                }

                my $dir = $c->tempfiles_subdir('/'.$image_type_name);
                my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $image_type_name.'/imageXXXX');
                $archive_temp_image .= '.png';

                my $rc = getstore($message_hash->{image_link}, $archive_temp_image);
                if (is_error($rc)) {
                    die "getstore of ".$message_hash->{image_link}." failed with $rc";
                }

                my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
                my $md5 = $image->calculate_md5sum($archive_temp_image);
                my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                    $project_join
                    JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
                    WHERE md_image.obsolete = 'f' $project_where AND stock_image.stock_id = $stock_id AND md_image.md5sum = '$md5';";
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
            }
            $it++;
        }
    }
    elsif ($service eq 'count_contours' || $service eq 'count_sift' || $service eq 'largest_contour_percent') {

        my $image_type_name;
        my $trait_name;
        my $script;
        my $input_image;
        my $outfile_image;
        my $results_outfile;
        if ($service eq 'count_contours') {
            $image_type_name = "image_analysis_contours";
            $trait_name = "count_contours";
            $script = 'GetContours.py';
            $input_image = 'image_path';
            $outfile_image = 'outfile_path';
            $results_outfile = 'results_outfile_path';
        }
        if ($service eq 'largest_contour_percent') {
            $image_type_name = 'image_analysis_largest_contour';
            $trait_name = 'percent_largest_contour';
            $script = 'GetLargestContour.py';
            $input_image = 'image_path';
            $outfile_image = 'outfile_path';
            $results_outfile = 'results_outfile_path';
        }
        if ($service eq 'count_sift') {
            $image_type_name = "image_analysis_sift";
            $trait_name = "count_sift";
            $script = 'ImageProcess/CalculatePhenotypeSift.py';
            $input_image = 'image_paths';
            $outfile_image = 'outfile_paths';
            $results_outfile = 'results_outfile_path';
        }

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

        my $it = 0;
        foreach (@image_files) {
            my $dir = $c->tempfiles_subdir('/'.$image_type_name);
            my $archive_contours_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $image_type_name.'/imageXXXX');
            $archive_contours_temp_image .= '.png';

            my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $image_type_name.'/imageXXXX');

            my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/'.$script.' --'.$input_image.' \''.$_.'\' --'.$outfile_image.' \''.$archive_contours_temp_image.'\' --'.$results_outfile.' \''.$archive_temp_results.'\' ';
            print STDERR Dumper $cmd;
            my $status = system($cmd);

            my $csv = Text::CSV->new({ sep_char => ',' });
            open(my $fh, '<', $archive_temp_results)
                or die "Could not open file '$archive_temp_results' $!";

            my $project_id = $result->[$it]->{project_id};
            my $stock_id = $result->[$it]->{stock_id};

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5 = $image->calculate_md5sum($archive_contours_temp_image);
            my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
                JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
                JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
                WHERE md_image.obsolete = 'f' AND project_md_image.type_id = $linking_table_type_id AND project_md_image.project_id = $project_id AND stock_image.stock_id = $stock_id AND md_image.md5sum = '$md5';";
            my $h = $schema->storage->dbh->prepare($q);
            $h->execute();
            my ($saved_image_id) = $h->fetchrow_array();
            my $image_id;
            if ($saved_image_id) {
                print STDERR Dumper "Image $archive_contours_temp_image has already been added to the database and will not be added again.";
                $image = SGN::Image->new( $schema->storage->dbh, $saved_image_id, $c );
                $image_id = $image->get_image_id();
            }
            else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($archive_contours_temp_image, 'project', $project_id, $linking_table_type_id);
                if (!$ret ) {
                    return {error => "Image processing for $archive_contours_temp_image did not work. Image not associated to stock_id $stock_id.<br/><br/>"};
                }
                print STDERR "Saved $archive_contours_temp_image\n";
                my $stock_associate = $image->associate_stock($stock_id);
                $image_id = $image->get_image_id();
                my $added_image_tag_id = $image->add_tag($image_tag);
            }

            my $line = <$fh>;
            my @columns;
            if ($csv->parse($line)) {
                @columns = $csv->fields();
            }
            my $res = {
                trait_name => $trait_name,
                trait_value => $columns[0],
                image_link => $main_production_site_url.$image->get_image_url("original"),
                original_image => $image_urls[$it]
            };
            $result->[$it]->{result} = $res;
            $it++;
        }
    }

    $c->stash->{rest} = { success => 1, results => $result };
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
