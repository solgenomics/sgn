
=head1 NAME

SGN::Controller::AJAX::NecrosisImageAnalysis - a REST controller class to provide the
functions for necrosis image analysis https://github.com/solomonnsumba/Necrosis-_Web_Server

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::NecrosisImageAnalysis;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
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

sub necrosis_image_analysis_submit : Path('/ajax/necrosis_image_analysis/submit') : ActionClass('REST') { }
sub necrosis_image_analysis_submit_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $image_ids = decode_json $c->req->param('selected_image_ids');
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
    my $server_endpoint = "http://18.219.45.102/necrosis/api2/";
    print STDERR $server_endpoint."\n";
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
        }
        $it++;
    }

    $c->stash->{rest} = { success => 1, results => $result };
}

1;
