package CXGN::TrackingActivity::ActivityInfo;


=head1 NAME

CXGN::TrackingActivity::ActivityInfo - a modul to handle tracking activity info

=head1 USAGE


=head1 DESCRIPTION


=head1 AUTHORS

Titima Tantikanjana (tt15@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;


has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    required => 1,
);

has 'tracking_identifier' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'selected_type' => (
    isa =>'Str', is => 'rw',
    required => 1,
);

has 'input' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    required => 1,
);

has 'operator_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'timestamp' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    required => 1
);

has 'notes' => (
    isa =>'Str|Undef',
    is => 'rw',
);

has 'activity_type' => (
    isa =>'Maybe[Str]',
    is => 'rw',
);

sub add_info {
    my $self = shift;
    my $schema = $self->get_schema();
    my $tracking_identifier = $self->get_tracking_identifier();
    my $selected_type = $self->get_selected_type();
    my $input = $self->get_input();
    my $operator_id = $self->get_operator_id();
    my $timestamp = $self->get_timestamp();
    my $notes = $self->get_notes();
    my $activity_type = $self->get_activity_type;
    my $error;

    my $coderef = sub {

        my $tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
        my $tracking_info_json_cvterm;
        if ($activity_type eq 'tissue_culture') {
            $tracking_info_json_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_tissue_culture_json', 'stock_property');
        } elsif ($activity_type eq 'transformation') {
            $tracking_info_json_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_transformation_json', 'stock_property');
        }

        my $tracking_identifier_stock = $self->_get_tracking_identifier($tracking_identifier);
        if (!$tracking_identifier_stock) {
            return { error => "$tracking_identifier could not be found." };
        }

        my $info_json_string;
        my $info_ref = {};
        my $id;

        my $previous_info_rs = $tracking_identifier_stock->stockprops({type_id=>$tracking_info_json_cvterm->cvterm_id()});
#        print STDERR "COUNT =".Dumper($previous_info_rs->count)."\n";
        if ($previous_info_rs->count == 1){
            $info_json_string = $previous_info_rs->first->value();
            my $previous_info = decode_json $info_json_string;
            my %info_hash = %{$previous_info};
            $info_hash{$selected_type}{$timestamp}{'operator_id'} = $operator_id;
            $info_hash{$selected_type}{$timestamp}{'input'} = $input;
            $info_hash{$selected_type}{$timestamp}{'notes'} = $notes;

            my $new_value = encode_json \%info_hash;
#            print STDERR "NEW VALUE 1 =".Dumper($new_value)."\n";
            $previous_info_rs->first->update({value=>$new_value});
        } elsif ($previous_info_rs->count > 1) {
            print STDERR "More than one found!\n";
            return;
        } else {
            my %new_info;
            $new_info{$selected_type}{$timestamp}{'operator_id'} = $operator_id;
            $new_info{$selected_type}{$timestamp}{'input'} = $input;
            $new_info{$selected_type}{$timestamp}{'notes'} = $notes;
            my $new_value = encode_json \%new_info;
#            print STDERR "NEW VALUE 2 =".Dumper($new_value)."\n";
            $tracking_identifier_stock->create_stockprops({$tracking_info_json_cvterm->name() => $new_value});
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $error =  $_;
    };

    if ($error) {
        return { error => "Error storing tracking information: $error\n" };
    } else {
        return { success => 1};
    }

}


sub _get_tracking_identifier {
    my $self = shift;
    my $identifier_name = shift;
    my $schema = $self->get_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    my $stock;
    my $tracking_identifier_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type');

    $stock_lookup->set_stock_name($identifier_name);
    $stock = $stock_lookup->get_tracking_identifier_exact();

    if (!$stock) {
        print STDERR "Tracking identifier does not exist\n";
        return;
    }
    return $stock;
}


#######
1;
#######
