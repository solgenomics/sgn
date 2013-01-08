
package PDF::LabelPage;

use Moose;
use Data::Dumper;

has 'pdf'            => ( isa => 'PDF::Create',
			  is  => 'rw',
    );

has 'labels'         => ( isa => 'ArrayRef',
			  is  => 'rw',
			  default => sub { [] },
    );

has 'rows'           => ( isa => 'Int',
			  is => 'rw',
    );

has 'cols'           => ( isa => 'Int',
			  is => 'rw',
    );

has 'top_margin'     => (isa=>'Int',
			 is => 'rw',
    );

has 'bottom_margin'  => (isa=>'Int',
			 is  => 'rw',
    );

has 'left_margin'    => (isa => 'Int',
			 is => 'rw',
    );

has 'right_margin'   => (isa => 'Int',
			 is => 'rw',
    );

has 'page_format'    => (isa => 'Str',
			 is => 'rw',
			 default => 'Letter',
    );

sub add_label { 
    my $self = shift;
    my $label = shift;
    
    my $labels = $self->labels();
    push @$labels, $label;
    $self->labels($labels);

    print STDERR "Now we have ".(scalar(@{$self->labels()}))." labels in the page object.\n";
}

sub render { 
    my $self = shift;

    my $page = $self->pdf()->new_page(Mediabox=>$self->pdf->get_page_size($self->page_format));
    
    my ($page_width, $page_height) = @{$self->pdf->get_page_size($self->page_format)}[2,3];
    
    my $label_height = int( ($page_height - $self->top_margin - $self->bottom_margin) / $self->rows());
    
    my $label_width  = int( ($page_width - $self->left_margin - $self->right_margin) / $self->cols());
     my $final_barcode_width = ($page_width - $self->right_margin - $self->left_margin) / $self->cols;

    my @images =@{ $self->labels() };
      
    print STDERR "Rendering page with @images labels on it\n";
    foreach my $row (1..$self->rows()) { 
	foreach my $col (1..$self->cols()) { 
	    my $label_boundary = $page_height - (($row-1) * $label_height) - $self->top_margin;	
	    $page->line($page_width -100, $label_boundary, $page_width, $label_boundary);
	    my $index = ($row -1) * $self->cols() + $col -1;
	    my $image = $images[$index];	   
	    #print STDERR "RENDER: IMAGE: ".Data::Dumper::Dumper($image)."\n\n";

	    
	    if (!defined($image)) { next; }

	    my $scalex = $final_barcode_width / $image->{width};
	    my $scaley = $label_height / $image->{height};
	    
	    my $ypos = $label_boundary - int( ($label_height - $image->{height} * $scaley) /2);
	    my $xpos = $label_width * ($col -1);

	    print STDERR "Printing label: row $row; col $col = index $index X: $xpos. Y: $ypos\n";

	    if ($scalex < $scaley) { $scaley = $scalex; }
	    else { $scalex = $scaley; }
	    
	    #foreach my $label_count (1..$self->cols) { 
		$page->image(image=>$image, xpos=>$xpos, ypos=>$ypos, xalign=>0, yalign=>2, xscale=>$scalex, yscale=>$scaley);
		
	    #}
	}
    }

}

sub need_more_labels { 
    my $self = shift;
    
    if (scalar(@{$self->labels()}) < ($self->rows * $self->cols)) { 
	return 1;
    }
    else { 
	return 0;
    }
}



1;
