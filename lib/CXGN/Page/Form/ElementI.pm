
=head1 NAME

CXGN::Page::Form::ElementI -- a parent class for all form elements (such as edit boxes and drop down menus)

=cut

use strict;

package CXGN::Page::Form::ElementI;

=head1 CONSTANTS

The following error return codes are defined in this class and are
available as globals:

$INPUT_REQUIRED_ERROR

$INTEGER_REQUIRED_ERROR

$NUMBER_REQUIRED_ERROR

$TOKEN_REQUIRED_ERROR

$DATE_REQUIRED_ERROR

$ALLELE_NAME_REQUIRED_ERROR

$LENGTH_EXCEEDED_ERROR  # not yet implemented


=cut

our $INPUT_REQUIRED_ERROR = 1;
our $INTEGER_REQUIRED_ERROR = 2;
our $NUMBER_REQUIRED_ERROR = 3;
our $TOKEN_REQUIRED_ERROR= 4;
our $DATE_REQUIRED_ERROR=6;
our $LENGTH_EXCEEDED_ERROR = 5;
our $UNIQUE_REQUIRED_ERROR=7;
our $ALLELE_SYMBOL_REQUIRED_ERROR=8;


=head1 FUNCTIONS

=head2 new

 Usage:
 Desc:
 Ret:
 Args:       a hash with the following keys:
               display_name  (name of the field for display purposes)
	       field_name (name of the form element)
	       id (the id of the html node)
	       contents (varies by field type; usually the node value)
	       selected (varies by field type; not used by all fields)
	       object (the object this field maps to)
	       getter (the getter function for this field in the object)
	       setter (the setter function for this field in the object)
               validate (a string describing how to validate the user input; see set_validate() below)
					
               All keys correspond to object properties with getter/setters
               which are described in more detail below.

 Side Effects:
 Example:

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    my %args = @_;
#    print STDERR  "\nCLASS: $class.\n";
#    foreach my $k (keys %args) { print  STDERR "Args to add_select $k, $args{$k}\n"; }
    if (!$args{field_name}) { 
	my $args_list = "";
	foreach my $k (keys %args) { 
	    $args_list .= "$k ($args{$k}) | ";
	}

	die qq { Usage: CXGN::Page::Form::ElementI->new( display_name=>"Foo:", field_name=>"foo", contents=>"bar", selected=>0, length => 20, object => \$foo_obj , setter=>"set_foo", getter=>"get_foo", validate=>1)<br /> Your argument list is: $args_list. field_name is required, others are optional };
    }

    $self->set_display_name($args{display_name});
    $self->set_field_name($args{field_name});
    $self->set_id($args{id});
    $self->set_contents($args{contents});
    $self->set_selected($args{selected});
    $self->set_length($args{length});
    $self->set_object($args{object});
    $self->set_object_getter($args{getter});
    $self->set_object_setter($args{setter});
    $self->set_store_enabled(1); #default is to store
    $args{validate} = "" if !defined($args{validate}); #avoid error messages about uninitialized values in comparison
    $self->set_validate($args{validate});
    my $formatting = $args{formatting} || "";
    $self->set_formatting($formatting);
    
    return $self;
}

=head2 get_display_name

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_display_name {
  my $self=shift;
  return $self->{display_name};

}

=head2 set_display_name

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_display_name {
  my $self=shift;
  $self->{display_name}=shift;
}

=head2 get_field_name

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_field_name {
  my $self=shift;
  if (!exists($self->{field_name})) { $self->{field_name} = ""; }
  return $self->{field_name};

}

=head2 set_field_name

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_field_name {
  my $self=shift;
  $self->{field_name}=shift;
}

=head2 get_id

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_id {
  my $self=shift;
  if (!exists($self->{id})) { $self->{id} = ""; }
  return $self->{id};

}

=head2 set_id

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_id {
  my $self=shift;
  $self->{id}=shift;
}

=head2 get_contents

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_contents {
  my $self=shift;
  if (!exists($self->{contents})) { $self->{contents}=""; }
  return $self->{contents};

}

=head2 set_contents

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_contents {
  my $self=shift;
  $self->{contents}=shift;
}

=head2 set_from_external

Set the appropriate fields ('contents', 'selected', etc) from a value not in the form of an ElementI,
such as one taken from a database or a request string.
Meant to be overridden by some provided subclasses (eg Checkbox, which uses its contents field unusually)
and some user-defined ones.

 Args: a string with all provided values for this field separated by \0

=cut

sub set_from_external
{
	my ($self, $value) = @_;
	$self->set_contents($value);
}


=head2 get_length

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_length {
  my $self=shift;
  if (!exists($self->{length})) { $self->{length}=20; }
  return $self->{length};

}

=head2 set_length

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_length {
  my $self=shift;
  $self->{length}=shift;
}



=head2 get_selected

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_selected {
  my $self=shift;
  if (!exists($self->{selected})) { $self->{selected}=""; }
  return $self->{selected};

}

=head2 set_selected

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_selected {
  my $self=shift;
  $self->{selected}=shift;
}



=head2 get_object

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_object {
  my $self=shift;
  if (!exists($self->{object})) { $self->{object}=""; }
  return $self->{object};

}

=head2 set_object

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_object {
  my $self=shift;
  $self->{object}=shift;
}

=head2 get_object_getter

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_object_getter {
  my $self=shift;
  if (!exists($self->{object_getter})) { $self->{object_getter}=""; }
  return $self->{object_getter};

}

=head2 set_object_getter

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_object_getter {
  my $self=shift;
  $self->{object_getter}=shift;
}

=head2 get_object_setter

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_object_setter {
  my $self=shift;
  if (!exists($self->{object_setter})) { $self->{object_setter}=""; }
  return $self->{object_setter};

}

=head2 set_object_setter

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_object_setter {
  my $self=shift;
  $self->{object_setter}=shift;
}

=head2 is_store_enabled

 Usage:
 Desc:
 Ret: whether this field will store its value on the next form submission
 Args:
 Side Effects:
 Example:

=cut

sub is_store_enabled {
  my $self=shift;
  return $self->{store_enabled};

}

=head2 set_store_enabled

 Usage: default is ON for all fields
 Desc:
 Ret:
 Args: a value that will be interpreted in Boolean context
 Side Effects:
 Example:

=cut

sub set_store_enabled {
  my ($self, $enable) = @_;
  $self->{store_enabled} = $enable;
}


=head2 accessors get_formatting, set_formatting

 Usage: handle html tag formatting
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_formatting {
  my $self = shift;
  return $self->{formatting}; 
}

sub set_formatting {
  my $self = shift;
  $self->{formatting} = shift;
}


=head2 get_validate

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_validate {
  my $self=shift;
  if (!exists($self->{validate})) { $self->{validate}=""; }
  return $self->{validate};

}

=head2 set_validate

 Usage:
 Desc:
 Ret:
 Args:         one of: 
               o a true value (1). This means that the 
                 field is required, any data type may be given.
               o "string": same as 1
               o "integer": this field requires an integer
               o "number": this field requires a number (maybe in 
                 exp format etc).
               o "token": a string consisting of letter and numbers
                 only, no spaces allowed.
               o "date": a string of the format \d+[-/]\d+[-/]\d+
               o "unique": 1 if it must be a unique field.
                 (the database accessor class needs to implement
                 the exists_in_database function, as described in
		 L<CXGN::DB::ModifiableI>. Uniqueness
                 should also be enforced on the database level.
 Side Effects:
 Example:

=cut

sub set_validate {
  my $self=shift;
  my $validation = shift;
  if ($validation && ($validation!~/1|string|integer|number|token|date|allele_symbol/i)) { 
      die "unknown validation type";
  }
  $self->{validate}=$validation;
}

=head2 validate

 Usage:
 Desc:
 Ret:          an error code if the field does not validate,
               0 if the field validates.               
               Error codes:
                 $INPUT_REQUIRED_ERROR
                 $INTEGER_REQUIRED_ERROR
                 $NUMBER_REQUIRED_ERROR
                 $DATE_REQUIRED_ERROR
                 $TOKEN_REQUIRED_ERROR
                 $LENGTH_EXCEEDED_ERROR
                 $UNIQUE_REQUIRED_ERROR
                 $ALLELE_SYMBOL_REQUIRED_ERROR
 Args:         none
 Side Effects:
 Example:

=cut

sub validate {
    my $self = shift;
    if (($self->get_validate()=~/1|string/i) && !$self->get_contents()) { 
	return $INPUT_REQUIRED_ERROR;
    }
    if (($self->get_validate()=~/integer/i) && ($self->get_contents()!~/^\s*\-?\d+\s*$/) ) { 
	return $INTEGER_REQUIRED_ERROR;
    }
    if (($self->get_validate()=~/number/i) && ($self->get_contents() !~ /\s*\-?\d+(\.)?[Ee]?\-?\d*/) ) { 
	return $NUMBER_REQUIRED_ERROR;
    }
    if (($self->get_validate()=~/token/i) && ($self->get_contents() !~ m/^[A-Za-z0-9\-\_]+$/)) { 
	return $TOKEN_REQUIRED_ERROR;
    }
    if (($self->get_validate()=~/date/i) && ($self->get_contents() !~ /^\d+[-\/]\d+[-\/]+\d+$/)) { 
	return $DATE_REQUIRED_ERROR;
    }
    if (($self->get_validate()=~/allele_symbol/i) && ($self->get_contents() !~ /^[A-Za-z0-9]+(\-\d+)?$/)) { 
	return $ALLELE_SYMBOL_REQUIRED_ERROR;
    }
#    if ( length($self->get_contents())>$self->get_length()) { 
#	return $LENGTH_EXCEEDED_ERROR;
#    }

    if ($self->get_validate()=~/unique/i) {
	if ($self->get_object()->can("exists_in_database")) { 
	    if ($self->get_object()->exists_in_database()) { 
		return $UNIQUE_REQUIRED_ERROR;
	    }
	}
    }

    
#    print STDERR "VALIDATION OF FIELD ".$self->get_field_name()." CONTENTS: ".$self->get_contents()." - NO ERROR DETECTED\n";
    # the field has validated
    return 0;

}

=head2 render

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub render {
    print STDERR "ElementI does not render anything...please subclass.\n";
    exit();
}

return 1;
