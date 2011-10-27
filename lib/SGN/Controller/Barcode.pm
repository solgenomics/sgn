

package SGN::Controller::Barcode;

use Moose;
use GD;
use Barcode::Code128;
use GD::Barcode::QRcode;

BEGIN { extends 'Catalyst::Controller'; }

sub code128_png :Path('/barcode/code128png') :Args(2) { 
    my $self = shift;
    my $c = shift;
    my $identifier = shift;
    my $text = shift;
    
    $text =~ s/\+/ /g;
    $identifier =~ s/\+/ /g;

    my $barcode_object = Barcode::Code128->new();
    $barcode_object->barcode($identifier);
    $barcode_object->font('large');
    $barcode_object->border(2);
    $barcode_object->top_margin(30);
    $barcode_object->font_align("center");
    my  $barcode = $barcode_object ->gd_image();
    my $text_width = gdLargeFont->width()*length($text);
    $barcode->string(gdLargeFont,int(($barcode->width()-$text_width)/2),10,$text, $barcode->colorAllocate(0, 0, 0));
    
    $c->res->headers->content_type('image/png');
    
    $c->res->body($barcode->png());    
}


sub qrcode_png :Path('/barcode/qrcodepng') :Args(2) { 
    my $self = shift;
    my $c = shift;
    my $link = shift;
    my $text = shift;

    $text =~ s/\+/ /g;
    $link =~ s/\+/ /g;

    my $bc = GD::Barcode::QRcode->new($link, { Ecc => 'L', Version=>2, ModuleSize => 2 });
    my $image = $bc->plot();

    $c->res->headers->content_type('image/png');    
    $c->res->body($image->png());			      
}


1;
