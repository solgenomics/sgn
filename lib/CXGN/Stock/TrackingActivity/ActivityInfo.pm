package CXGN::Stock::TrackingActivity::ActivityInfo;


=head1 NAME

CXGN::Stock::TrackingActivity::ActivityInfo - a modul to handle tracking activity info

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

has 'activity_type' => (
    isa =>'Str', is => 'rw',
    required => 1,
);

has 'value' => (
    isa =>'HashRef',
    is => 'rw',
    required => 1,
);


sub add_info {
    my $self = shift;
    my $schema = $self->get_schema();
    my $tracking_identifier = $self->get_tracking_identifier();
    my $activity_type = $self->get_activity_type();
    my $activity_info = $self->get_value();

    my $error;

    my $coderef = sub {

        my $tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
        my $tracking_info_json_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_metadata_json', 'stock_property');

        my $info_json_string;
        my $info_json_hash = {};
        my $identifier;

        my $tracking_identifier_rs = $schema->resultset("Stock::Stock")->search({ 'uniquename' => $tracking_identifier, 'type_id' => $tracking_identifier_cvterm_id});
        my $id;
        if ($tracking_identifier_rs->count == 1) {
            $identifier = $tracking_identifier_rs->first;
        } else {
            return;
        }

        my $previous_info_rs = $identifier->stockprops({type_id=>$tracking_info_json_cvterm->cvterm_id()});
        if ($previous_info_rs->count == 1){
            $info_json_string = $previous_info_rs->first->value();
            $info_json_hash = decode_json $info_json_string;
            $info_json_string = _generate_info_hash($activity_type, $activity_info, $info_json_hash);
            $previous_info_rs->first->update({value=>$info_json_string});
        } elsif ($previous_info_rs->count > 1) {
            print STDERR "More than one found!\n";
            return;
        } else {
            $info_json_string = _generate_info_hash($activity_type, $activity_info, $info_json_hash);
            $identifier->create_stockprops({$tracking_info_json_cvterm->name() => $info_json_string});
        }
        print STDERR "INFO JSON STRING =".Dumper($info_json_string)."\n";
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $error =  $_;
    };

    if ($error) {
        print STDERR "Error storing tracking information: $error\n";
        return;
    }

    return 1;
}

sub _generate_info_hash {
    my $activity_type = shift;
    my $activity_info = shift;
    my $info_json_hash = shift;

    $info_json_hash->{$activity_type} = $activity_info;
    #print STDERR Dumper $info_json_hash;
    my $info_json_string = encode_json $info_json_hash;

    return $info_json_string;

}



#######
1;
#######
