
=head1 NAME

CXGN::Stock::SequencingInfo - a class to match keys to a standardized JSON structure

=head1 DESCRIPTION

The stockprop of type "sequencing_project_info" is stored as JSON. This class maps keys to the JSON structure and retrieves and saves the stockprop.

=head1 EXAMPLE

  my $si = CXGN::Stock::SequencingInfo->new( { schema => $schema, $stockprop_id });

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

=head2 ftp_link

=head2 ncbi_link

=head2 sp_person_id

=head2 timestamp


=cut

has 'schema' => (isa => 'Ref', is => 'rw', required => 1);

has 'stockprop_id' => (isa => 'Maybe[Int]', is => 'rw');

has 'stock_id' => (isa => 'Maybe[Int]', is => 'rw');

has 'type_id' => (isa => 'Int', is => 'rw');

has 'type' => (isa => 'Str', is => 'ro', default => "sequencing_project_info" );

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

has 'ftp_link'  => (isa => 'Maybe[Str]', is => 'rw');

has 'ncbi_link' => (isa => 'Maybe[Str]', is => 'rw');

has 'sp_person_id' => (isa => 'Maybe[Int]', is => 'rw');

has 'timestamp' => (isa => 'Maybe[Str]', is => 'rw');

has 'allowed_fields' => (isa => 'Ref', is => 'ro', default =>  sub {  [ qw | organization website genbank_accession funded_by funder_project_id contact_email sequencing_year publication jbrowse_link blast_db_id ftp_link ncbi_link stockprop_id stock_id sp_person_id timestamp | ] } );


sub BUILD {
    my $self = shift;
    my $args = shift;

    if ($args->{stockprop_id} eq "undefined") { $args->{stockprop_id} = undef; }

    print STDERR "STOCKPROPID: ".$self->stockprop_id.", TYPE: ".$self->type()."\n";
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), $self->type(), 'stock_property')->cvterm_id();

    $self->type_id($type_id);

    $self->_load_object();

    $self->stockprop_id($args->{stockprop_id});
}


=head2 Class methods


=head2 get_sequencing_project_infos($schema, $stock_id)

 Usage:        my @seq_projects = $se_info->get_sequencing_project_infos($schema, $stock_id);
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

    my @stockprops = $class->_retrieve_stockprops($schema, $stock_id, "sequencing_project_info");

    #print STDERR "Stockprops = ".Dumper(\@stockprops);

    my @infos = ();
    foreach my $sp (@stockprops) {
	my $hash;

	my $json = $sp->[1];

	eval {
	    $hash = JSON::Any->jsonToObj($json);
	};
	$hash->{stockprop_id} = $sp->[0];
	$hash->{uniquename} = $schema->resultset("Stock::Stock")->find( { stock_id => $stock_id })->uniquename();
	if ($@) {
	    print STDERR "Warning: $json is not valid json in stockprop ".$sp->[0].".!\n";
	}
	push @infos, $hash;
    }

    #print STDERR "Hashes = ".Dumper(\@infos);
    return \@infos;
}

=head2 all_sequenced_stocks()

 Usage:        @sequenced_stocks = CXGN::Stock->sequenced_stocks();
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub all_sequenced_stocks {
    my $class = shift;
    my $schema = shift;

    print STDERR "all_sequenced_stocks with ".ref($schema)." as parameter...\n";
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'sequencing_project_info', 'stock_property')->cvterm_id();
    print STDERR "type_id = $type_id\n";

    my $sp_rs = $schema->resultset("Stock::Stockprop")->search({ type_id => $type_id });

    my @sequenced_stocks = ();
    while (my $row = $sp_rs->next()) {
	print STDERR "found stock with stock_id ".$row->stock_id()."\n";
	push @sequenced_stocks, $row->stock_id();
    }

    return @sequenced_stocks;
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

    if (!$self->stock_id()) {
	die "Need a stock_id to save SequencingInfo object.";
    }

    if ($self->stockprop_id()) {
	# update
	print STDERR "updating stockprop...\n";
	my $row = $self->schema()->resultset("Stock::Stockprop")->find( { stockprop_id => $self->stockprop_id() } );
	if ($row) {
	    $row->value($self->to_json());
	    $row->update();
	}
    }
    else {
	# insert

	#get highest rank from previous inserts...
	my $rs = $self->schema()->resultset("Stock::Stockprop")->search( { stock_id => $self->stock_id(), type_id => $self->type_id() }); #SELECT max(rank) from stockprop where type_id=? and stock_id=?";
	my $rank = $rs->get_column("rank")->max();

	$rank++;

	print STDERR "inserting stockprop...\n";
	my $row = $self->schema()->resultset("Stock::Stockprop")->create(
	    {
		stock_id => $self->stock_id(),
		type_id => $self->type_id(),
		value => $self->to_json(),
		rank => $rank,

	    });

	$self->stockprop_id($row->stockprop_id());
	$self->stock_id($row->stock_id());
	return $row->stockprop_id();
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

    print STDERR "CXGN::Stock::SequencingInfo: Deleting sequencing info object ".$self->stockprop_id()."\n";
    my $stockprop;

    print STDERR "stock_id = ".$self->stock_id().", stockprop_id = ".$self->stockprop_id()."\n";

    eval {
	$stockprop = $self->schema()->resultset("Stock::Stockprop")->find({ type_id=>$self->type_id(), stock_id => $self->stock_id(), stockprop_id=>$self->stockprop_id() });

    };
    if ($@) {
	die "Delete failed!\n";
    }

    if (!$stockprop) {
	print STDERR "No such stockprop associated with such type or stock. Not deleting.\n";
	return 0;
    }
    else {
	print STDERR "Deleting stcokprop now.\n";
	$stockprop->delete();
	print STDERR "SequencingInfo successfully deleted.\n";
	return 1;
    }
}

=head2 _load_object

 Desc:
 Ret:
 Args:
 Side Effects:   requires stockprop_id and schema to be set
 Example:

=cut

sub _load_object {
    my $self= shift;

    print STDERR "_load_object...\n";

    print STDERR "Stockprop_id is now ".$self->stockprop_id()."\n";
    if ($self->stockprop_id()) {
	print STDERR "configuring object...\n";
	my $stockprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $self->type(), 'stock_property')->cvterm_id();
	my $rs = $self->schema->resultset("Stock::Stockprop")->search({ stockprop_id => $self->stockprop_id(), type_id => $stockprop_type_id } );

	if ($rs->count() == 0) { die "No stockprops could be retrieved." }

	my $row = $rs->next(); # should only be one

	$self->type_id($stockprop_type_id);
	$self->stock_id($row->stock_id());
	$self->from_json($row->value());
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
    my $class = shift;
    my $schema = shift;
    my $stock_id = shift;
    my $type = shift;

    my @results;

    print STDERR "_retrieve_stockprops...\n";

    eval {
        my $stockprop_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $type, 'stock_property')->cvterm_id();
        my $rs = $schema->resultset("Stock::Stockprop")->search({ stock_id => $stock_id, type_id => $stockprop_type_id }, { order_by => {-asc => 'stockprop_id'} });

        while (my $r = $rs->next()){
            push @results, [ $r->stockprop_id(), $r->value() ];
        }
    };

    if ($@)  {
        print STDERR "Cvterm $type does not exist in this database\n";
    };

    return @results;
}

=head2 from_json

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub from_json {
    my $self = shift;
    my $json = shift;

    my $data = JSON::Any->decode($json);

    $self->from_hash($data);
}

=head2 from_hash

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub from_hash {
    my $self = shift;
    my $hash = shift;

    my $allowed_fields = $self->allowed_fields();

    #print STDERR Dumper($hash);

    foreach my $f (@$allowed_fields) {
	print STDERR "Processing $f ($hash->{$f})...\n";
	if ( ($hash->{$f} eq "undefined") || ($hash->{$f} eq "") ) { $hash->{$f} = undef; }
	$self->$f($hash->{$f});
    }
}

=head2 to_json

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

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

    my $json = JSON::Any->encode($data);
    return $json;
}

=head2 to_hash

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub to_hashref {
    my $self = shift;

    my $hashref;
    foreach my $f (@{$self->allowed_fields()}) {
	$hashref->{$f} = $self->$f;
    }
    return $hashref;
}

=head2 validate

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

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
    if (!defined($self->ftp_link())) {
	push @warnings, "Need ftp link for sequencing project";
    }
    if (!defined($self->ncbi_link())) {
    push @warnings, "Need ncbi link for sequencing project";
    }

    if (@errors) {
	die join("\n", @errors);
    }
}



1;
