
package CXGN::Trait;

use Moose;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
		  is => 'rw',
		  required => 1,
    );

has 'cvterm_id' => (isa => 'Int',
		    is => 'rw',
		    required => 1,
    );

has 'cvterm' => ( isa => 'Bio::Chado::Schema::Result::Cv::Cvterm', 
		  is => 'rw');


has 'name' => ( isa => 'Str',
		is => 'ro',
		lazy => 1,
		default => sub { 
		    my $self = shift; 
		    return $self->cvterm->name(); 
		},

    );

has 'definition' => (isa => 'Str',
		     is => 'ro',
		     lazy => 1,
		     default => sub { 
			 my $self = shift;
			 return $self->cvterm->definition(); 
		     },

    );

has 'format' => (isa => 'Str',
		 is => 'ro',
		 lazy => 1,
		 default => sub { 
		     my $self = shift;

		     my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find( 
			 { 
			     cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_format' 
			 }, 
			 { join => 'type'} 
			 );
		     
		     if ($row) { 
			 return $row->value();
		     }
		     return "";
		 }
    );

has 'associated_plots' => ( isa => 'Str',
			    is => 'ro',
			    lazy => 1,
			    default => sub { "not yet implemented" }
    );

has 'associated_accessions' =>  ( isa => 'Str',
				  is => 'ro',
				  lazy => 1,
				  default => sub { "not yet implemented" }
    );


sub BUILD { 
    print STDERR "BUILDING...\n";
    my $self = shift;
    my $cvterm = $self->bcs_schema()->resultset("Cv::Cvterm")->find( { cvterm_id => $self->cvterm_id() });
    if ($cvterm) { 
	print STDERR "Cvterm with ID ".$self->cvterm_id()." was found!\n";
    }
    $self->cvterm($cvterm);
}

sub _build_definition { 
}

sub _build_cvterm_id { 
    my $self = shift;
    $self->cvterm->cvterm_id(); 
}

sub _build_name { 
}

1;
