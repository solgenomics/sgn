
package CXGN::Trait;

use Moose;

## to do: add concept of trait short name; provide alternate constructors for term, shortname, and synonyms etc.

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

has 'display_name' => (isa => 'Str',
		       is => 'ro',
		       lazy => 1,
		       default => sub { 
			   my $self = shift;
			   my $db = $self->db();
			   my $name = $self->name();
			   my $accession = $self->accession();
			   #print STDERR $db." ".$name." ".$accession."\n";
			   if ($db && $name && $accession ) { 
			       return $name ."|".$db.":".$accession;
			   }
			   return "";
		       }
    );

has 'accession' => (isa => 'Str',
		    is => 'ro',
		    lazy => 1,
		    default => sub { 
			my $self = shift;
			my $rs = $self->bcs_schema()->resultset("Cv::Cvterm")
			    -> search( { cvterm_id => $self->cvterm_id() }) 
			    -> search_related("dbxref");
			if ($rs->count() ==1) { 
			    my $accession = $rs->first()->get_column("accession");
			    return $accession;
			}
			return "";
		    }

    );

has 'term' => (isa => 'Str',
	       is => 'ro',
	       lazy => 1,
	       default => sub { 
		   my $self = shift;
		   my $accession = $self->accession();
		   my $db = $self->db();
		   if ($accession && $db) { 
		       return "$db:$accession";
		   }
		   return "";
	       }
    );

has 'db'   => ( isa => 'Str',
		is => 'ro',
		lazy => 1,
		default => sub { 
		    my $self = shift;
		    my $rs = $self->bcs_schema()->resultset("Cv::Cvterm")->search( { cvterm_id => $self->cvterm_id()})->search_related("dbxref")->search_related("db");
		    if ($rs->count() == 1) { 
			my $db_name =  $rs->first()->get_column("name");
			#print STDERR "DBNAME = $db_name\n";
			return $db_name;
		    }
		    return "";
			
		}
    );

has 'db_id'   => (
	isa => 'Int',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $rs = $self->cvterm->search_related("dbxref");
		if ($rs->count() == 1) {
			my $db_id =  $rs->first()->get_column("db_id");
			#print STDERR "DBID = $db_id\n";
			return $db_id;
		}
		return "";
	}
);

has 'definition' => (isa => 'Maybe[Str]',
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

has 'default_value' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_default_value' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return "";
	}
);

has 'minimum' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_minimum' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return "";
	}
);

has 'maximum' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_maximum' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return "";
	}
);

has 'categories' => (
	isa => 'Str',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_categories' },
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

has 'uri' => (isa => 'Str',
	is            => 'ro',
	lazy          => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{cvterm_id => $self->cvterm_id(), 'type.name' => 'uri'},
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return "";
	}
);

sub BUILD { 
    #print STDERR "BUILDING...\n";
    my $self = shift;
    my $cvterm = $self->bcs_schema()->resultset("Cv::Cvterm")->find( { cvterm_id => $self->cvterm_id() });
    if ($cvterm) { 
	#print STDERR "Cvterm with ID ".$self->cvterm_id()." was found!\n";
    }
    $self->cvterm($cvterm);
}


1;
