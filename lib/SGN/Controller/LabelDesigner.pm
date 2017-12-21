package SGN::Controller::LabelDesigner;

use Moose;
use File::Slurp;
use Barcode::Code128;
use CXGN::QRcode;
use URI::Encode qw(uri_encode uri_decode);
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub interactive_barcoder_main :Path('/tools/label_designer') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {  # redirect to login page
    	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
    	return;
    }

    $c->stash->{template} = '/tools/label_designer.mas';
}

sub barcode_preview :Path('/tools/label_designer/preview') {
    my $self = shift;
    my $c = shift;
    my $uri     = URI::Encode->new( { encode_reserved => 0 } );
    my $content =  $uri->decode($c->req->param("content"));
    my $type = $uri->decode($c->req->param("type"));
    my $size = $uri->decode($c->req->param("size"));

    #print STDERR "Content is $content and type is $type and size is $size\n";

    if ($type eq 'Code128') {

        print STDERR "Creating barcode 128\n";

        my $barcode_object = Barcode::Code128->new();
        $barcode_object->option("scale", $size);
        $barcode_object->option("font_align", "center");
        $barcode_object->option("padding", 5);
        $barcode_object->option("show_text", 0);
        $barcode_object->barcode($content);
        my $barcode = $barcode_object->gd_image();

        $c->res->headers->content_type('image/png');
        $c->res->body($barcode->png());

    } elsif ($type eq 'QRCode') {

        print STDERR "Creating QR Code\n";

        $c->tempfiles_subdir('barcode');
        my ($file_location, $uri) = $c->tempfile( TEMPLATE => [ 'barcode', 'bc-XXXXX'], SUFFIX=>'.jpg');

        my $barcode_generator = CXGN::QRcode->new(
            text => $content,
            size => $size,
            margin => 0,
            version => 0,
            level => 'M'
        );
        my $barcode_file = $barcode_generator->get_barcode_file($file_location);

         my $qrcode_path = $c->path_to($uri);

         $c->res->headers->content_type('image/jpg');
         my $output = read_file($qrcode_path);
         $c->res->body($output);

    }

}

return 1;
