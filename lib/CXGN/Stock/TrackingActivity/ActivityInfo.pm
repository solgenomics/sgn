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

has 'selected_type' => (
    isa =>'Str', is => 'rw',
    required => 1,
);

has 'input' => (
    isa => 'Maybe[Int]',
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


sub add_info {
    my $self = shift;
    my $schema = $self->get_schema();
    my $tracking_identifier = $self->get_tracking_identifier();
    my $selected_type = $self->get_selected_type();
    my $input = $self->get_input();
    my $operator_id = $self->get_operator_id();
    my $timestamp = $self->get_timestamp();
    my $error;

    print STDERR "IDENTIFIER =".Dumper($tracking_identifier)."\n";
    print STDERR "SELECTED TYPE =".Dumper($selected_type)."\n";
    print STDERR "INPUT =".Dumper($input)."\n";
    print STDERR "TIMESTAMP =".Dumper($timestamp)."\n";
    print STDERR "OPERATOR ID =".Dumper($operator_id)."\n";


    my $coderef = sub {

        my $tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
        my $tracking_info_json_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_metadata_json', 'stock_property');

        my $info_json_string;
        my $info_ref = {};
        my $identifier;

        my $tracking_identifier_rs = $schema->resultset("Stock::Stock")->search({ 'uniquename' => $tracking_identifier, 'type_id' => $tracking_identifier_cvterm_id});
        my $id;
        if ($tracking_identifier_rs->count == 1) {
            $identifier = $tracking_identifier_rs->first;
        } else {
            return;
        }

        my $previous_info_rs = $identifier->stockprops({type_id=>$tracking_info_json_cvterm->cvterm_id()});
        print STDERR "COUNT =".Dumper($previous_info_rs->count)."\n";
        if ($previous_info_rs->count == 1){
            $info_json_string = $previous_info_rs->first->value();
            my $previous_info = decode_json $info_json_string;
            my %info_hash = %{$previous_info};
            $info_hash{$selected_type}{$timestamp}{'operator_id'} = $operator_id;
            $info_hash{$selected_type}{$timestamp}{'input'} = $input;
            my $new_value = encode_json \%info_hash;
            print STDERR "NEW VALUE 1 =".Dumper($new_value)."\n";
            $previous_info_rs->first->update({value=>$new_value});
        } elsif ($previous_info_rs->count > 1) {
            print STDERR "More than one found!\n";
            return;
        } else {
            my %new_info;
            $new_info{$selected_type}{$timestamp}{'operator_id'} = $operator_id;
            $new_info{$selected_type}{$timestamp}{'input'} = $input;
            my $new_value = encode_json \%new_info;
            print STDERR "NEW VALUE 2 =".Dumper($new_value)."\n";            
            $identifier->create_stockprops({$tracking_info_json_cvterm->name() => $new_value});
        }
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



#######
1;
#######
