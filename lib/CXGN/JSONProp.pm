
=head1 NAME

CXGN::JSONProp - an abstract class for implementing different prop objects that store data in json format

=head1 DESCRIPTION

A subclass needs to implement accessors for each property that is stored as a json key. A BUILD function needs to be implemented that defines some metadata about tables and namespaces that the object has to access.

Example implementation of a subclass:


  package TestProp;

  use Moose;

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
use POSIX;

use Data::Dumper;
use Bio::Chado::Schema;
use CXGN::People::Schema;
use JSON::Any;
use Try::Tiny;
use SGN::Model::Cvterm;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema', is => 'rw');

has 'people_schema' => ( isa => 'CXGN::People::Schema', is => 'rw');

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

    select(STDERR);
    $|=1;
    print STDERR "prop_type ".$self->prop_type()." cv_name ".$self->cv_name()."\n";

    my $cvterm_row = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), $self->prop_type(), $self->cv_name());

    if (!$cvterm_row) { die "Can't find term ".$self->prop_type()." in cv ".$self->cv_name()."!!!!"; }

    $self->_prop_type_id($cvterm_row->cvterm_id());

    print STDERR "LOAD PROP ID = ".$self->prop_id()."\n";

    if ($self->prop_id()) {
        my $rs;
        if ($self->prop_table eq 'sp_orderprop') {
            $rs = $self->people_schema()->resultset($self->prop_namespace())->search( { $self->prop_primary_key() => $self->prop_id() });
        } else {
            $rs = $self->bcs_schema()->resultset($self->prop_namespace())->search( { $self->prop_primary_key() => $self->prop_id() });
        }
	    if (my $row = $rs->next()) {
	        if ($row->type_id() == $self->_prop_type_id()) {
		    #print STDERR "ROW VALUE = ".$row->value().", TYPEID=".$row->type_id()." TYPE = ".$self->prop_type()."\n";
                my $parent_primary_key = $self->parent_primary_key();
                my $parent_id = $row->$parent_primary_key;
                $self->parent_id($parent_id);
                $self->from_json($row->value());
            } else {
                print STDERR "Skipping property unrelated to metadata...\n";
            }
        } else {
            die "The object with id ".$self->prop_id()." does not exist. Sorry!";
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

sub to_hashref {
    my $self = shift;
    my $allowed_fields = $self->allowed_fields();
    my $data;

    foreach my $f (@$allowed_fields) {
	if (defined($self->$f())) {
	    $data->{$f} = $self->$f();
	}
    }
    return $data;
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


=head2 get_props($schema, $prop_id)

 Usage:        my @seq_projects = $stock->get_props($schema, $stock_id);
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_props {
    my $class = shift;
    my $schema = shift;
    my $parent_id = shift;

    print STDERR "get_props(): creating object; using parent_id $parent_id\n";
    my $obj = $class->new( { bcs_schema => $schema });

    my @props = $obj->_retrieve_props($schema, $parent_id);
    print STDERR "Props = ".Dumper(\@props);
    my @hashes = ();
    foreach my $sp (@props) {
	my $json = $sp->[2];
	my $hash;

	eval {
	    $hash = JSON::Any->jsonToObj($json);
	    $hash->{prop_id} = $sp->[0];
	    $hash->{parent_id} = $sp->[1]
	};

	if ($@) {
	    print STDERR "Warning: $json is not valid json in prop ".$sp->[0].".!\n";
	}
	push @hashes, $hash;
    }

    return \@hashes;
}


=head2 filter_props()
 
 Usage:     my $filtered_props = $JSONPropClass->filter_props({ schema=> $schema, conditions => \%conditions });
 Desc:      This class method can be used to get props that match the provided search criteria
 Ret:       a hash with the results metadata and the matching props:
                page: current page number
                maxPage: the number of the last page
                pageSize: (max) number of results per page
                total: total number of results
                results: an arrayref of hashes containing the parent_id, prop_id, all of the prop values, and any specified parent fields
 Args:      schema = Bio::Chado::Schema
            conditions = (optional, default=unfiltered/all props) a hashref of DBIx where conditions to filter the props by.  
                If you're filtering by a prop value, you should use the form: "value::json->>'prop_name' => 'prop value'"
            parent_fields = (optional, default=none) an arrayref of the names of fields from the parent table to include in the results
                NOTE: if a parent field is used in the search conditions, it should also be included here
            order_by = (optional) the field to sort the results by:
                order_by => "stockprop_id"                               // sort by ascending stockprop_id
                order_by => { "-desc" => "value::json->'timestamp'" }    // sort by descending timestamp in the json value
            page = (optional, default=1) the page number of results to return
            pageSize = (optional, default=1000) the number of results to return per page
 Example:   my $conditions = {
                '-and' => [ 
                    { 'stock.uniquename' => [ 'TEST_SEEDLOT_1', 'TEST_SEEDLOT_2' ] },
                    { 'value::json->>\'timestamp\'' => { '>=' => '2021-06-01 00:00:00' } },
                    { 'value::json->>\'timestamp\'' => { '<=' => '2021-06-30 24:00:00' } }, 
                    { 'value::json->>\'operator\'' => [ 'dwaring87' ] }
                ], 
                '-or' => [
                    { 
                        '-and' => [
                            { 'value::json->>\'cvterm_id\'' => '78094' }, 
                            { 'value::json->>\'value\'' => [ 'Successful' ] }
                        ] 
                    },
                    {
                        '-and' => [
                            { 'value::json->>\'cvterm_id\'' => '78085' },
                            { 'value::json->>\'value\'' => [ 'High', 'Medium' ] }
                        ]
                    },
                    { 'value::json->>\'cvterm_id\'' => '78090' }
                ]
            };
            my $filtered_props = $JSONPropClass->filter_props({
                schema => $schema, 
                conditions => $conditions, 
                parent_fields => ["uniquename"],
                order_by => { "-desc" => "value::json->>'timestamp'" }
            });

=cut

sub filter_props {
    my $class = shift;
    my $args = shift;
    my $schema = $args->{schema};
    my $conditions = $args->{conditions};
    my $parent_fields = $args->{parent_fields};
    my $order_by = $args->{order_by};
    my $page = $args->{page} || 1;
    my $pageSize = $args->{pageSize} || 1000;
    my $type_id = $class->_prop_type_id();

    # Build the search conditions
    my @all_conditions = ();
    push(@all_conditions, { 'me.type_id' => $class->_prop_type_id() });
    if ( $conditions ) {
        push(@all_conditions, $conditions);
    }

    # Build the filter query using a ResultSet
    my @s = ();
    my @a = ();
    foreach my $f (@{$class->allowed_fields()}) {
        push(@s, "value::json->>'$f'");
        push(@a, $f);
    }
    my $props = $schema->resultset($class->prop_namespace())->search(
        { '-and' => \@all_conditions },
        {
            'prefetch' => defined $parent_fields ? $class->parent_table() : undef,
            '+select' => \@s,
            '+as' => \@a,
            'order_by' => $order_by,
            'page' => $page,
            'rows' => $pageSize
        }
    );
    my $pager = $props->pager();
    my $total = $pager->total_entries();

    # Parse the results
    my @filtered_props = ();
    while (my $r = $props->next) {
        my %p = (
            $class->prop_primary_key() => $r->get_column($class->prop_primary_key()),
            $class->parent_primary_key() => $r->get_column($class->parent_primary_key())
        );
        foreach my $f (@a) {
            $p{$f} = $r->get_column($f);
        }
        if ( defined $parent_fields ) {
            my $pt = $class->parent_table();
            foreach my $pf (@$parent_fields) {
                $p{$pf} = $r->$pt->$pf;
            }
        }
        push(@filtered_props, \%p);
    }

    # Return the results and page info
    my %results = (
        page => $page,
        maxPage => int(ceil($total/$pageSize)),
        total => $total,
        pageSize => $pageSize,
        results => \@filtered_props
    );
    return \%results;
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
	$self->store_by_rank();
    }

}


=head2 method store_by_rank()

Usage:         $prop->store_by_rank();
Desc:          store multiple props with the same type_id
Ret:
Args:


Side Effects:
Example:

=cut


sub store_by_rank {
    my $self = shift;

    my $rs = $self->bcs_schema()->resultset($self->prop_namespace())->search( { $self->parent_primary_key() => $self->parent_id(), type_id => $self->_prop_type_id() });

    my $rank;
    if ($rs->count() > 0) {
        $rank = $rs->get_column("rank")->max();
    }
    $rank++;

	my $row = $self->bcs_schema()->resultset($self->prop_namespace())->create( { $self->parent_primary_key()=> $self->parent_id(), value => $self->to_json(), type_id => $self->_prop_type_id(), rank => $rank });
	my $prop_primary_key = $self->prop_primary_key();
	$self->prop_id($row->$prop_primary_key);

}


=head2 method store_sp_orderprop()

Usage:         $prop->store_sp_orderprop();
Desc:
Ret:
Args:


Side Effects:
Example:

=cut

sub store_sp_orderprop {
    my $self = shift;
    print STDERR "PROP ID =".Dumper($self->prop_id())."\n";
    if ($self->prop_id()) {
        print STDERR "UPDATING JSONPROP ".$self->to_json()."\n";
        my $row = $self->people_schema()->resultset($self->prop_namespace())->find( { $self->prop_primary_key() => $self->prop_id() } );
        if ($row) {
            $row->value($self->to_json());
            $row->update();
        }
    } else {
        my $row = $self->people_schema()->resultset($self->prop_namespace())->create( { $self->parent_primary_key()=> $self->parent_id(), value => $self->to_json(), type_id => $self->_prop_type_id(), rank => 1});
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

    print STDERR "Prop type id = ".$self->_prop_type_id()."\n";
    print STDERR "Parent primary key: ".$self->parent_primary_key()."\n";
    print STDERR "Parent id: ".$self->parent_id()."\n";
    print STDERR "Prop primary key: ".$self->prop_primary_key()."\n";
    print STDERR "Prop ID : ".$self->prop_id()."\n";

    my $prop = $self->bcs_schema()->resultset($self->prop_namespace())->find({ type_id=>$self->_prop_type_id(), $self->parent_primary_key() => $self->parent_id(), $self->prop_primary_key() => $self->prop_id() });

    if (!$prop) {
	print STDERR "Prop not found!\n";
	return 0;
    }
    else {
	$prop->delete();
	return 1;
    }
}

=head2 _retrieve_props

  Usage:
  Desc:         Retrieves prop as a list of [prop_id, value]
  Ret:
  Args:         schema, parent_id, prop_type
  Side Effects:
  Example:

=cut

sub _retrieve_props {
    my $self = shift;
    my $schema = shift;
    my $parent_id = shift;

    print STDERR "Getting props for parent_id $parent_id, ".join(",", $self->parent_primary_key(), $self->_prop_type_id(), $self->prop_primary_key())."\n";
    my @results;

    my $prop_primary_key = $self->prop_primary_key();
    my $parent_primary_key = $self->parent_primary_key();

    if ($parent_id) {
	eval {
	    my $rs = $schema->resultset($self->prop_namespace())->search({ $self->parent_primary_key() => $parent_id, type_id => $self->_prop_type_id() }, { order_by => {-asc => $self->prop_primary_key() } });

	    while (my $r = $rs->next()){
		push @results, [ $r->$prop_primary_key, $r->$parent_primary_key, $r->value() ];
	    }
	};
    }
    else {
	eval {

	    print STDERR "Searching all ".$self->_prop_type_id()." in namespace ".$self->prop_namespace()." (primary key is ".$prop_primary_key."...\n";

	    my $rs = $schema->resultset($self->prop_namespace())->search({ type_id => $self->_prop_type_id() }, { order_by => {-asc => $prop_primary_key } });

	    while (my $r = $rs->next()){
		push @results, [ $r->$prop_primary_key(), $r->$parent_primary_key(), $r->value() ];
	    }
	};
    }

    if ($@) {
	print STDERR "ERROR $@\n";
    }

    return @results;
}

"CXGN::JSONProp";
