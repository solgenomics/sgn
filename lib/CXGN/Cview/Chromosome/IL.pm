

=head1 NAME

CXGN::Cview::Chromosome::IL - a class for drawing Isogenic Line (IL) diagrams

=head1 DESCRIPTION

Inherits from L<CXGN::Cview::Chromosome>. 

=head1 SEE ALSO

See also the documentation in L<CXGN::Cview>.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=head1 FUNCTIONS


=cut

1;

use strict;
use CXGN::Cview::Chromosome;

package CXGN::Cview::Chromosome::IL;

use base qw( CXGN::Cview::Chromosome );

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    # set some standard attributes of IL chromosomes
    #
    $self->set_width(10);
    $self->set_color(200,200,200);
    return $self;
}

# sub add_section {
#     # sections are the non-overlapping sections of the ILs that have labels of the form 1-A
#     my $self=shift;
#     my $section_name = shift;
#     my $marker1 = shift;
#     my $offset1 = shift;
#     my $marker2 = shift;
#     my $offset2 = shift;
    
#     my %section = ();
#     $section{marker1}=$marker1;
#     $section{offset1}=$offset1;
#     $section{marker2}=$marker2;
#     $section{offset2}=$offset2;
#     $section{name}=$section_name;
#     $section{label_position} = 0;
#     push @{$self->{sections}}, \%section;

# }


# sub add_fragment {
#     # fragments are the overlapping sections defining the different IL lines and have lables of the form IL1-1.
#     my $self=shift;
#     my $fragment_name=shift;
#     my $marker1=shift;
#     my $offset1 = shift;
#     my $marker2 = shift;
#     my $offset2 = shift;

#     my %fragment = ();
#     $fragment{marker1}=$marker1;
#     $fragment{offset1}=$offset1;
#     $fragment{marker2}=$marker2;
#     $fragment{offset2}=$offset2;
#     $fragment{name}=$fragment_name;
#     $fragment{label_position} = 0;
#     push @{$self->{fragments}}, \%fragment;

# }

# sub render {
#     my $self=shift;
#     my $image = shift;

#     $self->_calculate_scaling_factor();
#     $self->_calculate_chromosome_length();
#     $self-> set_color(100,100,100);
#     #print STDERR "Rendering ILs...\n";
#     $self->{font}= GD::Font->Small();
#     my $section_x = $self->get_horizontal_offset() - $self->get_width()/2;

#     my $color = $image -> colorResolve($self->{color}[0], $self->{color}[1], $self->{color}[2]);
#     my $light_color = $image -> colorResolve(200, 200, 200);
#     #
#     # render sections
#     #
#     my $previous_label_position = 0;
#     my $line =  1;
#     my $spacing = 7;


#     foreach my $s (@{$self->{sections}}) {
# 	my $y_start = $self->get_vertical_offset()+$self->mapunits2pixels($$s{offset1});
# 	my $y_end   = $self->get_vertical_offset()+$self->mapunits2pixels($$s{offset2 });
	
	
# 	$image -> line($section_x - 10, $y_start, $section_x + @{$self->{fragments}}*$spacing, $y_start, $light_color);
# 	$image -> line($section_x - 10, $y_end,   $section_x + @{$self->{fragments}}*$spacing, $y_end,  $light_color);
# 	$image -> line($section_x,      $y_start, $section_x, $y_end,   $color);
# 	$image -> string($self->{font}, $section_x - $self->{font}->width()* length($$s{name})-2, ($y_end + $y_start)/2-$self->{font}->height()/2, $$s{name}, $color); 
	
#     }

#     # render fragments
#     #
#     if (!defined($self->{fragments})) { print STDERR "IL: no fragments to render.\n"; return; }
#     my $max_fragments = @{$self->{fragments}};

#     foreach my $f (@{$self->{fragments}}) {
# 	my $y_start = $self->get_vertical_offset()+$self->mapunits2pixels($$f{offset1});
# 	my $y_end   = $self->get_vertical_offset()+$self->mapunits2pixels($$f{offset2 });
	
# 	my $label_position = ($y_end+$y_start)/2;
# 	if ($label_position < ($previous_label_position+$self->{font}->height())) { $label_position = $previous_label_position + $self->{font}->height(); }

# 	$image -> line($section_x+$line*$spacing, $y_start, $section_x+$line*$spacing, $y_end,$color);
# 	$image -> line($section_x+$line*$spacing+1, $y_start, $section_x+$line*$spacing+1, $y_end,   $color);
# 	$image -> string($self->{font}, $section_x +$max_fragments*$spacing+3, $label_position-$self->{font}->height()/2, $$f{name}, $color); 
# 	$image -> line($section_x+$line*$spacing, ($y_end+$y_start)/2, $section_x+$max_fragments*$spacing+3, $label_position, $color);
# 	$line++;
#  $previous_label_position = $label_position;
#     }
	
# }
    
     
