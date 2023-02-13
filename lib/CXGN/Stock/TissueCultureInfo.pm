package CXGN::Stock::TissueCultureInfo;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;
use Bio::Chado::Schema;
use Data::Dumper;
use JSON;
use CXGN::Stock::StockLookup;

has 'chado_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
	predicate => 'has_chado_schema',
	required => 1,
);

has 'stock_name' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_stock_name',
);

has 'tissue_culture_info' => (
    isa => 'HashRef',
    is => 'rw'
);


sub store {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $stock_name = $self->get_stock_name();
    my $new_tissue_culture_info = $self->get_tissue_culture_info();
    my %new_tissue_culture_info_hash = %{$new_tissue_culture_info};
    my $transaction_error;
    my $coderef = sub {
        my $stock_rs = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name });
        if (!$stock_rs) {
            print STDERR "Stock name: $stock_name does not exist or does not exist as uniquename in the database\n";
            return;
        }

        my $tissue_culture_info_json;
        my $tissue_culture_data_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_culture_data_json', 'stock_property');
        my $stock_prop_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $stock_rs->stock_id(), type_id => $tissue_culture_data_cvterm->cvterm_id()});
        if ($stock_prop_rs){
            my %updated_info;
            my $previous_value = $stock_prop_rs->value();
            my $previous_tissue_culture_info = decode_json $previous_value;
            my %previous_hash = %{$previous_tissue_culture_info};
            foreach my $previous_tissue_culture_id (keys %previous_hash) {
                $updated_info{$previous_tissue_culture_id} = $previous_hash{$previous_tissue_culture_id};
            }
            foreach my $new_tissue_culture_id (keys %new_tissue_culture_info_hash) {
                $updated_info{$new_tissue_culture_id} = $new_tissue_culture_info_hash{$new_tissue_culture_id};
            }
            $tissue_culture_info_json = encode_json \%updated_info;
            $stock_prop_rs->first->update({value=>$tissue_culture_info_json});

        } else {
            $tissue_culture_info_json = encode_json \%new_tissue_culture_info_hash;
            $stock_rs->create_stockprops({$tissue_culture_data_cvterm->name() => $tissue_culture_info_json});
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error storing tissue culture info: $transaction_error\n";
        return;
    }

    return 1;

}


sub tissue_culture_info {
    my $self = shift;
    my $schema = $self->get_chado_schema();

    my $tissue_culture_data_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_culture_data_json', 'stock_property');

    my $data_rs = $schema->resultset("Stock::Stockprop")->search({type_id => $tissue_culture_data_cvterm->cvterm_id()}, { order_by => {-asc => 'stock_id'} });
    my @all_info;
    while (my $each_info = $data_rs->next()){
        my %info_hash = ();
        my $stock_id = $each_info->stock_id();
        my $stock_rs = $schema->resultset("Stock::Stock")->find({stock_id => $stock_id});
        my $stock_name = $stock_rs->uniquename();
        my $data_value = $each_info->value();
        my $info = decode_json $data_value;
        %info_hash = %{$info};
        foreach my $tissue_culture_id (keys %info_hash) {
            my %each_info = ();
            %each_info = %{$info_hash{$tissue_culture_id}};
            my $program_id = $each_info{'breeding_program_id'};
            my $subculture_date = $each_info{'Subculture Date'};
            my $number_of_copies = $each_info{'Number of Copies'};
            my $rooting_date = $each_info{'Rooting Date'};
            my $number_of_rooted_plantlets = $each_info{'Number of Rooted Plantlets'};
            my $hardening_date = $each_info{'Hardening Date'};
            my $number_of_hardened_plantlets = $each_info{'Number of Hardened Plantlets'};

            my $program_rs = $schema->resultset('Project::Project')->find({project_id => $program_id});
            my $program_name = $program_rs->name();
            push @all_info, [$stock_id, $stock_name, $tissue_culture_id, $program_id, $program_name, $subculture_date, $number_of_copies, $rooting_date, $number_of_rooted_plantlets, $hardening_date, $number_of_hardened_plantlets ];
        }
    }

    print STDERR "ALL INFO =".Dumper(\@all_info)."\n";
    return \@all_info;

}



1;
