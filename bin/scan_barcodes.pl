
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

my $dir = shift;

my @files = glob "$dir/*";

my $step;

foreach my $f (@files) {
    chomp($f);
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
