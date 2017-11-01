package CXGN::QRcode;

use Moose;
use GD;

use Imager::QRCode;

sub get_barcode_file {
  my $self = shift;
  my $file = shift;
  my $text = shift;
  my $size = shift || 3;

  my $qrcode = Imager::QRCode->new(
        size          => $size,
        margin        => 0,
        version       => 0,
        level         => 'L',
        casesensitive => 1,
        lightcolor    => Imager::Color->new(255, 255, 255),
        darkcolor     => Imager::Color->new(0, 0, 0),
    );
  my $barcode = $qrcode->plot($text);
  $barcode->write(file => $file);

  return $file;

}

1;
