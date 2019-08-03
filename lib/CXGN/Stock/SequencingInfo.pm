
=head1 NAME

CXGN::Stock::SequencingInfo - a class to match keys to a standardized JSON structure

=head1 DESCRIPTION

The stockprop of type "sequencing_project_info" is stored as JSON. This class maps keys to the JSON structure and retrieves and saves the stockprop.

=head1 EXAMPLE

  my $si = CXGN::Stock::SequencingInfo->new( { schema => $schema, $stock_id => $stock_id });

=head1 AUTHOR

 Lukas Mueller <lam87@cornell.edu>

=cut

package CXGN::Stock::SequencingInfo;

use Moose;
use JSON::Any;
use Data::Dumper;
use SGN::Model::Cvterm;


=head1 ACCESSORS

=head2 schema

=head2 stock_id

=head2 stockprop_id

=head2 organization

=head2 website

=head2 genbank_accession

=head2 funded_by

=head2 funder_project_id

=head2 contact_email

=head2 sequencing_year

=head2 publication

=head2 jbrowse_link

=head2 blast_db_id

=cut
    
has 'schema' => (isa => 'Ref', is => 'rw', required => 1);

has 'stock_id' => (isa => 'Int', is => 'rw');

has 'stockprop_id' => (isa => 'Maybe[Int]', is => 'rw');

has 'organization' => (isa => 'Maybe[Str]', is => 'rw');

has 'website' => (isa => 'Maybe[Str]', is => 'rw');

has 'genbank_accession' => (isa => 'Maybe[Str]', is => 'rw');

has 'funded_by' => (isa => 'Maybe[Str]', is => 'rw');

has 'funder_project_id' => (isa => 'Maybe[Str]', is => 'rw');

has 'contact_email' => (isa => 'Maybe[Str]', is => 'rw');

has 'sequencing_year' => (isa => 'Maybe[Str]', is => 'rw');

has 'publication' => (isa => 'Maybe[Str]', is => 'rw');

has 'jbrowse_link' => (isa => 'Maybe[Str]', is => 'rw');

has 'blast_db_id' => (isa => 'Maybe[Int]', is => 'rw');

has 'allowed_fields' => (isa => 'Ref', is => 'ro', default =>  sub {  [ qw | organization website genbank_accession funded_by funder_project_id contact_email sequencing_year publication jbrowse_link blast_db_id | ] } );


sub from_json {
    my $self = shift;
    my $json = shift;

    my $data = JSON::Any->decode($json);

    $self->from_hash($data);

}

sub from_hash {
    my $self = shift;
    my $hash = shift;

    my $allowed_fields = $self->allowed_fields();

    print STDERR Dumper($hash);
    
    foreach my $f (@$allowed_fields) {
	print STDERR "Processing $f ($hash->{$f})...\n";
	$self->$f($hash->{$f});
    }
}

sub to_json {
    my $self = shift;
 
    my $allowed_fields = $self->allowed_fields();

    print STDERR Dumper($allowed_fields);
    my $data;
    
    foreach my $f (@$allowed_fields) {
	if (defined($self->$f())) { 
	    $data->{$f} = $self->$f();
	}
    }

    my $json = JSON::Any->encode($data);
    return $json;
}

sub validate {
    my $self = shift;
    
    my @errors = ();
    my @warnings = ();
    
    # check keys in the info hash...
    if (!defined($self->sequencing_year())) {
	push @errors, "Need year for sequencing project";
    }
    if (!defined($self->organization())) {
	push @errors, "Need organization for sequencing project";
    }
    if (!defined($self->website())) {
	push @errors, "Need website for sequencing project";
    }
    if (!defined($self->publication())) {
	push @warnings, "Need publication for sequencing project";
    }
    if (!defined($self->website())) {
	push @warnings, "Need project url for sequencing project";
    }
    if (!defined($self->jbrowse_link())) {
	push @warnings, "Need jbrowse link for sequencing project";
    }

    if (@errors) {
	die join("\n", @errors);
    }
}

=head2 Class methods
   

=head2 get_sequencing_project_infos($schema, $stock_id)

 Usage:        my @seq_projects = $stock->get_sequencing_project_infos($schema, $stock_id);
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_sequencing_project_infos { 
    my $class = shift;
    my $schema = shift;
    my $stock_id = shift;
    
    my @stockprops = _retrieve_stockprops($schema, $stock_id, "sequencing_project_info");
    print STDERR "Stockprops = ".Dumper(\@stockprops);
    my @hashes = ();
    foreach my $sp (@stockprops) { 
	my $json = $sp->[1];
	my $hash;
	eval { 
	    $hash = JSON::Any->jsonToObj($json);
	};
	if ($@) { 
	    print STDERR "Warning: $json is not valid json in stockprop ".$sp->[0].".!\n"; 
	}
	push @hashes, [ $sp->[0], $hash ];
    }

    return @hashes;
}


=head2 OBJECT METHODS

=head2 method store()

 Usage:         $s->set_sequencing_project_info($si, $stockprop_id)
 Desc:          creates a sequencing project info in the stockprop
 Ret:           
 Args:          a CXGN::Stock::SequencingInfo object, and an optional
                stockprop_id (which will trigger an update instead
                of insert)
 Side Effects:
 Example:

=cut

sub store {
    my $self = shift;

    if ($self->stockprop_id()) {
	# update
	my $row = $self->schema()->resultset("Stock::Stockprop")->find( { stockprop_id => $self->stockprop_id() } );
	if ($row) {
	    $row->value($self->to_json());
	    $row->update();
	}
    }
    else { 
	# insert
	my $row = $self->schema()->resultset("Stock::Stockprop")->create( { stock_id => $self->stock_id(), "stock.type" => "sequencing_project_info", value => $self->to_json() });
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
    my $stockprop_id = shift;

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'sequencing_project_info', 'stock_property')->cvterm_id();
    my $stockprop = $self->schema()->resultset("Stock::Stockprop")->find({ type_id=>$type_id, stock_id => $self->stock_id(), stockprop_id=>$stockprop_id });

    if (!$stockprop) {
	return 0;
    }
    else {
	$stockprop->delete();
	return 1;
    }
}

=head2 _retrieve_stockprops

 Usage:
 Desc:         Retrieves stockprop as a list of [stockprop_id, value]
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub _retrieve_stockprops {
    my $schema = shift;
    my $stock_id = shift;
    my $type = shift;
    
    my @results;

    try {
        my $stockprop_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $type, 'stock_property')->cvterm_id();
        my $rs = $schema->resultset("Stock::Stockprop")->search({ stock_id => $stock_id, type_id => $stockprop_type_id }, { order_by => {-asc => 'stockprop_id'} });

        while (my $r = $rs->next()){
            push @results, [ $r->stockprop_id(), $r->value() ];
        }
    } catch {
        #print STDERR "Cvterm $type does not exist in this database\n";
    };

    return @results;
}

1;

	

