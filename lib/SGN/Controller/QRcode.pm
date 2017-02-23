package SGN::Controller::QRcode;

use Moose;
use GD;

use Imager::QRCode;

sub barcode_qrcordes {
    my $self = shift;
    my $stock_id = shift;
    my $stock_name = shift;
    my $field_info = shift;
    my $file = shift;
    my $text = "stock name: ".$stock_name. "\n stock id: ". $stock_id. "\n".$field_info;

    my $qrcode = Imager::QRCode->new(
        size          => 5,
        margin        => 5,
        version       => 1,
        level         => 'M',
        casesensitive => 1,
        lightcolor    => Imager::Color->new(255, 255, 255),
        darkcolor     => Imager::Color->new(0, 0, 0),
    );
    my $barcode = $qrcode->plot($text);
    $barcode->write(file => $file);

    return $file;
}

1;
