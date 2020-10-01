package CXGN::QRcode;

use Moose;
use GD;

use Imager::QRCode;

has 'text' => (
    isa => 'Str',
	is => 'rw',
    required => 1,
);

has 'size' => (
	isa => 'Maybe[Int]',
	is => 'rw',
    default => 3,
);

has 'margin' => (
	isa => 'Maybe[Int]',
	is => 'rw',
    default => 5,
);

has 'version' => (
	isa => 'Maybe[Int]',
	is => 'rw',
    default => 1,
);

has 'level' => (
	isa => 'Maybe[Str]',
	is => 'rw',
    default => 'M',
);

sub get_barcode_file {
    my $self = shift;
    my $file = shift;

    my $qrcode = Imager::QRCode->new(
        size          => $self->size,
        margin        => $self->margin,
        version       => $self->version,
        level         => $self->level,
        casesensitive => 1,
        lightcolor    => Imager::Color->new(255, 255, 255),
        darkcolor     => Imager::Color->new(0, 0, 0),
    );
    my $barcode = $qrcode->plot( $self->text );
    $barcode->write(file => $file);

    return $file;

}

1;
