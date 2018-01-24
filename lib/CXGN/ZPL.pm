
package CXGN::ZPL;

use Moose;

has 'font'        => ( is      => 'rw',
		       isa     => 'Str',
		       default => 'AA',
    );

has 'print_width'          => ( is      => 'rw',
				isa => 'Num',
    );

has 'label_length'         => ( is      => 'rw',
				isa => 'Num',
    );

has 'command_list'          => ( is     => 'rw',
				 isa    => 'ArrayRef',
    );

sub start_sequence {
    my $self = shift;
    $self->add("^XA");
}

sub label_format {
    my $self = shift;
    my $label_length = $self->label_length();
    my $print_width = $self->print_width();
    $self->add("^LL$label_length^PW$print_width");
}

sub new_element {
    my $self = shift;
    my ($type, $x, $y, $size, $value) = @_;

    my %dispatcher = (
        ZebraText => \&text,
        Code128 => \&code128,
        QRCode => \&qrcode,
    );

    if (exists $dispatcher{$type}) {
        $dispatcher{$type}( $self, $x, $y, $size, $value);
    }
}

sub code128 {
    my $self = shift;
    my ($x, $y, $size, $value) = @_;
    my $height = $size * 25;
    $self->add("^FO$x,$y^BCN,$height,N,N,N^FD   $value^FS");
}

sub qrcode {
    my $self = shift;
    my ($x, $y, $size, $value) = @_;
    $y = $y - 10; #adjust for 10 dot offset
    $self->add("^FO$x,$y^BQ,,$size^FDMA,$value^FS");
}

sub text {
    my $self = shift;
    my ($x, $y, $size, $value) = @_;
    my $font = $self->font();
    $self->add("^FO$x,$y^$font,$size^FD$value^FS");
}

sub end_sequence {
    my $self = shift;
    $self->add("^XZ");
}

sub add {
    my $self = shift;
    my $command = shift;
    my $command_list = $self->command_list();
    push @$command_list, $command;
    $self->command_list($command_list);
}

sub render {
    my $self = shift;
    my $zpl = "";
    foreach my $c (@{$self->command_list()}) {
	 $zpl .= "$c\n";
    }
    return $zpl;
}


1;
