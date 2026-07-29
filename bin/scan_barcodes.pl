
=head1 NAME

scan_barcodes.pl - a script to scan barcodes in images, such as field images

=head1 DESCRIPTION

perl scan_barcodes.pl dirname

images must be in dirname directly. No subdirs are parsed.

Output:

The filename and the read value from the barcode, and the level at which the barcode could be read. 1=raw image, 2=first sharpen, 3=second sharpen, 4=not detected/parsed.

=head2 DEPENDENCIES

The script is a thin wrapper around the zbarimg utility and the convert script.

zbarimg can be installed with:

apt install libzbar-dev

convert is part of imagemagick:

apt install imagemagick

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;
use Barcode::ZBar;
use Image::Magick;

my $dir = shift;

my @files = glob "$dir/*";

my $step;

my $scanner = Barcode::ZBar::ImageScanner ->new();
my $image = Barcode::ZBar::Image->new();
foreach my $f (@files) {
    chomp($f);

    print STDERR "PROCESSING IMAGE $f...\n";

    # 2. Read the image file using Image::Magick
    my $magick = Image::Magick->new();
    my $status = $magick->Read($f);
    die "Error reading image: $status\n" if $status;

    # 3. Extract the image metadata (width and height)
    my $width  = $magick->Get('columns');
    my $height = $magick->Get('rows');

    # 4. Convert the JPG data to a raw 8-bit greyscale blob (Y800 format)
    my $raw_blob = $magick->ImageToBlob(magick => 'GRAY', depth => 8);

    # 5. Pack the raw bits into the Barcode::ZBar::Image wrapper
    my $image = Barcode::ZBar::Image->new();

    $image->set_size($width, $height);



    $scanner->parse_config('disable');
    $scanner->parse_config('qrcode.enable');

    $image->set_data($raw_blob);
    $image->set_format("Y800");

    print STDERR "SCANNING IMAGE...\n";
    my $symbol_count = $scanner->scan_image($image);

    print STDERR "SYMBOLD COUNT : $symbol_count\n";
    print STDERR "GETTING RESULT...\n";

    foreach my $symbol ($image->get_symbols()) {

	print STDERR join(", ", $symbol->get_data())."\n";
    }

    print STDERR "DONE\n";

#    $scanner->recycle_image($scanner, $image);
    next();

    print STDERR "PROCESSING IMAGE $f\n";
    $step = 1;
    my $output = `zbarimg --raw $f`;
    chomp($output);

    if (!$output) {
	$step = 2;
	print STDERR "NO OUTPUT DETECTED... REDUCING BRIGHTNESS AND INCREASING CONTRAST... \n";
	my $outfile = $f."_high_contrast";
	my $output_convert = `convert -brightness-contrast -50x20 $f $outfile 2> /dev/null`;

	$output = `zbarimg --raw $outfile`;

	if (! $output) {
	    $step = 3;
	    my $outfile = $f."_high_contrast2";
	    my $output_convert = `convert -brightness-contrast -80x30 $f $outfile 2> /dev/null`;

	    $output = `zbarimg --raw $outfile`;
	    chomp($output);
	}

	chomp($output);

	if (!$output) { $step=4; }
    }

    print join("\t", $f, $output, $step)."\n";
}
