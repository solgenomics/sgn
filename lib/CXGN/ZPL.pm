
package CXGN::ZPL;

use Moose;


has 'font'        => ( is      => 'rw',
		       isa     => 'Str',
		       default => 'xyz',
    );

has 'orientation' => ( is      => 'rw',
		       isa     => 'Str',
		       default => '',
    );


has 'print_quality' => ( is      => 'rw',
			 isa    => 'Str',
			 default=> '',
    );

has 'print_orientation' => ( is      => 'rw',
			     isa   => 'Str',
			     default => 'N',
    );

has 'units_of_measurement' => ( is      => 'rw',
				isa => 'Str',
				default => 'D',
    );

has 'print_width'          => ( is      => 'rw',
				isa => 'Int',
    );

has 'label_length'         => ( is      => 'rw',
				isa => 'Int',
    );

has 'dots_per_millimeter'   => ( is      => 'rw',
				 isa => 'Int',
    );

has 'command_list'          => ( is     => 'rw',
				 isa    => 'ArrayRef',
    );

has 'field_typeset'         => ( is     => 'rw',
				 isa    => 'ArrayRef',
    );

has 'field_default_height' => ( is      => 'rw',
				isa     => 'Int',
				default => 10,
    );

has 'field_default_width'  => ( is      => 'rw',
				isa     => 'Int',
				default => 2,
    );

has 'field_default_ratio'  => ( is      => 'rw',
				isa     => 'Num', 
				default => 3.0,
    );

sub graphic_symbol { 
    my $self = shift;
    my ($o, $h, $w) = @_;

    $self->add("^GS$o,$h,$w");

}

sub bar_code_field_default { 
    my $self =shift;
    my ($w, $r, $h) = @_;
    $self->field_default_width($w);
    $self->field_default_ration($r);
    $self->field_default_height($h);
} 

sub graphic_box { 

}

sub comment { 

}

sub graphic_ellipse { 

}

sub graphic_diagonal_line { 


}

sub graphic_circle { 

}

sub field_orientation { 
}

sub field_origin { 

}

sub field_data { 

}

sub mirror_image { 
    my $self = shift;
    my $mirror = shift;
    die if ($mirror !~ /y|n/i);
    $self->add("^PM$mirror");
}

sub barcode_code128 { 
    my $self = shift;
    my ($o, $h, $f, $g, $e, $m) = @_;

    if (!defined($o)) { $o = $self->print_orientation(); }
    if (!defined($h)) { $h = $self->field_default_height(); }
    if (!defined($f)) { $f = ''; }
    if (!defined($g)) { $g = ''; }
    if (!defined($e)) { $e = ''; }
    if (!defined($m)) { $m = ''; }

    $self->add("^BC$o,$h,$f,$g,$e,$m");

}

sub start_format { 
    my $self = shift;

    $self->add("^XA");

}


sub end_format { 
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
