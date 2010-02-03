
use strict;

package CXGN::Page::Form::Label;

use base qw / CXGN::Page::Form::ElementI /;

sub new { 
    my $class = shift;
    my %args = @_;
    my $self = $class -> SUPER::new(@_);
    return $self;
}

sub render  { 
    my $self = shift;
    return $self->get_contents();
}
    
return 1;
