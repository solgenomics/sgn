
=head1 NAME

CXGN::JSONProp - an abstract class for implementing different prop objects that store data in json format

=head1 DESCRIPTION

A subclass needs to implement accessors for each property that is stored as a json key. A BUILD function needs to be implemented that defines some metadata about tables and namespaces that the object has to access.

Example implementation of a subclass:


  package TestProp;

  use Moose;>

  use Data::Dumper;

  BEGIN { extends 'CXGN::JSONProp'; }

  has 'info_field1' => (isa => 'Str', is => 'rw');

  has 'info_field2' => (isa => 'Str', is => 'rw');

  sub BUILD {
      my $self = shift;
      my $args = shift;
    
      $self->prop_table('projectprop');
      $self->prop_namespace('Project::Projectprop');
      $self->prop_primary_key('projectprop_id');
      $self->prop_type('analysis_metadata_json');
      $self->cv_name('project_property');
      $self->allowed_fields( [ qw | info_field1 info_field2 | ] );
      $self->parent_table('project');
      $self->parent_primary_key('project_id');

      $self->load();
   }

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

1;



package CXGN::JSONProp;

use Moose;

use Data::Dumper;
use Bio::Chado::Schema;
use JSON::Any;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema', is => 'rw');

has 'prop_table' => (isa => 'Str', is => 'rw', default => 'Set_in_subclass!'); # for example, 'stockprop'

has 'prop_namespace' => (isa => 'Str', is => 'rw', default => 'Set_in_subclass!'); # for example 'Stock::Stockprop'

has '_prop_type_id' => (isa => 'Int', is => 'rw');

has 'prop_primary_key' => (isa => 'Str', is => 'rw'); # set in subclass

has 'prop_type' => (isa => 'Str', is => 'rw'); # the type given by the type_id, set in subclass

has 'cv_name' => (isa => 'Str', is => 'rw');  # set in subclass

has 'allowed_fields' => (isa => 'Ref', is => 'rw', default =>  sub {  [ qw | | ] } );  # override in subclass

has 'prop_id' => (isa => 'Maybe[Int]', is => 'rw');

has 'parent_table' => (isa => 'Str', is => 'rw');  # set in subclass

has 'parent_primary_key' => (isa => 'Str', is => 'rw'); # set in subclass

has 'parent_id' => (isa => 'Maybe[Int]', is => 'rw');


sub load {  # must be called from BUILD in subclass
    my $self = shift;
    #print STDERR "prop_type ".$self->prop_type()." cv_name ".$self->cv_name()."\n";
    $self->_prop_type_id(SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), $self->prop_type(), $self->cv_name())->cvterm_id());

    #print STDERR "LOAD PROP ID = ".$self->prop_id()."\n";
    
    if ($self->prop_id()) {
	my $rs = $self->bcs_schema()->resultset($self->prop_namespace())->search( { $self->prop_primary_key() => $self->prop_id() });
	while (my $row = $rs->next()) {
	    if ($row->type_id() == $self->_prop_type_id()) { 
		#print STDERR "ROW VALUE = ".$row->value().", TYPEID=".$row->type_id()." TYPE = ".$self->prop_type()."\n";
		 my $parent_primary_key = $self->parent_primary_key();
		my $parent_id = $row->$parent_primary_key;
		$self->parent_id($parent_id);
		$self->from_json($row->value());
	    }
	    else {
		print STDERR "Skipping property unrelated to metadata...\n";
	    }
	   
	}
	

    }
}

sub from_json {
    my $self = shift;
    my $json = shift;

    my $data;
    eval { 
	$data = JSON::Any->decode($json);
    };
    if ($@) {
	print STDERR "JSON not valid ($json) - ignoring.\n";
    }

    $self->from_hash($data);

}

sub from_hash {
    my $self = shift;
    my $hash = shift;

    my $allowed_fields = $self->allowed_fields();

    #print STDERR Dumper($hash);
    
    foreach my $f (@$allowed_fields) {
	if (exists($hash->{$f})) {
	    #print STDERR "Processing $f ($hash->{$f})...\n";
	    $self->$f($hash->{$f});
	}
    }
}

sub to_json {
    my $self = shift;
 
    my $allowed_fields = $self->allowed_fields();

    #print STDERR Dumper($allowed_fields);
    my $data;
    
    foreach my $f (@$allowed_fields) {
	if (defined($self->$f())) { 
	    $data->{$f} = $self->$f();
	}
    }

    my $json;
    eval { $json = JSON::Any->encode($data); };
    if ($@) { print STDERR "Warning! Data is not valid json ($json)\n"; }
    return $json;
}

sub validate {   # override in subclass
    my $self = shift;
    
    my @errors = ();
    my @warnings = ();
    
    # check keys in the info hash...

    if (@errors) {
	die join("\n", @errors);
    }
}

=head2 Class methods
   

=head2 get_props($schema, $parent_object_id, $prop_type)

 Usage:        my @seq_projects = $stock->get_sequencing_project_infos($schema, $stock_id);
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_props { 
    my $class = shift;
    my $schema = shift;
    my $parent_object_id = shift; # the id of the parent object, eg stock_id for a stockprop
    my $prop_type = shift;
    
    my @props = _retrieve_stockprops($schema, $parent_object_id, $prop_type);
    #print STDERR "Props = ".Dumper(\@props);
    my @hashes = ();
    foreach my $sp (@props) { 
	my $json = $sp->[1];
	my $hash;
	eval { 
	    $hash = JSON::Any->jsonToObj($json);
	};
	if ($@) { 
	    print STDERR "Warning: $json is not valid json in prop ".$sp->[0].".!\n"; 
	}
	push @hashes, [ $sp->[0], $hash ];
    }

    return @hashes;
}


=head2 OBJECT METHODS

=head2 method store()

 Usage:         $s->store();
 Desc:          creates a sequencing project info in the stockprop
 Ret:           
 Args:          
                
                
 Side Effects:
 Example:

=cut

sub store {
    my $self = shift;

    ## TO DO: need to check for rank

    
    if ($self->prop_id()) {
	# update
	print STDERR "UPDATING JSONPROP ".$self->to_json()."\n";
	my $row = $self->bcs_schema()->resultset($self->prop_namespace())->find( { $self->prop_primary_key() => $self->prop_id() } );
	if ($row) {
	    $row->value($self->to_json());
	    $row->update();
	}
    }
    else { 
	# insert
	print STDERR "INSERTING JSONPROP ".$self->to_json().", parent_id = ".$self->parent_id(),"\n";
	my $row = $self->bcs_schema()->resultset($self->prop_namespace())->create( { $self->parent_primary_key()=> $self->parent_id(), value => $self->to_json(), type_id => $self->_prop_type_id() });
	my $prop_primary_key = $self->prop_primary_key();
	$self->prop_id($row->$prop_primary_key);
    }
    
}
    
=head2 method delete()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete {
    my $self = shift;

    my $prop = $self->bcs_schema()->resultset($self->prop_namespace())->find({ type_id=>$self->_prop_type_id(), $self->parent_table() => $self->parent_id(),  $self->prop_primary_key() => $self->prop_id });

    if (!$prop) {
	return 0;
    }
    else {
	$prop->delete();
	return 1;
    }
}

# =head2 _retrieve_stockprops

#  Usage:
#  Desc:         Retrieves prop as a list of [prop_id, value]
#  Ret:
#  Args:         schema, parent_id, prop_type
#  Side Effects:
#  Example:

# =cut

# sub _retrieve_props {
#     my $schema = shift;
#     my $parent_object_id = shift;
#     my $prop_type_id = shift;
    
#     my @results;

#     try {
# 	my $rs = $schema->resultset($self->prop_namespace())->search({ $self->parent_table()."_id" => $parent_object_id, type_id => $self->_prop_type_id() }, { order_by => {-asc => $self->prop_primary_key() } });

#         while (my $r = $rs->next()){
# 	    my $primary_key = $self->prop_primary_key();
#             push @results, [ $r->($self->$primary_key, $r->value() ];
#         }
#     } catch {
#         #print STDERR "Cvterm $type does not exist in this database\n";
#     };

#     return @results;
# }

"CXGN::JSONProp";
