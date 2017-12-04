package CXGN::Trial::TrialLayoutDownload;

=head1 NAME

CXGN::Trial::TrialLayoutDownload

=head1 SYNOPSIS

Module to format layout info for trial based on which columns user wants to see. Selected columns can be 'plant_name','subplot_name','plot_name','block_number','subplot_number','plant_number','plot_number','rep_number','row_number','col_number','accession_name','is_a_control','pedigree','location_name','trial_name','year','synonyms', or 'tier'.
This module can also optionally include treatments into the output.
This module can also optionally include accession trait performace summaries into the output.

This module is used from CXGN::Trial::Download::Plugin::TrialLayoutExcel, CXGN::Trial::Download::Plugin::TrialLayoutCSV, CXGN::Fieldbook::DownloadTrial

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => 'plots',
    treatment_project_ids => [1,2],
    selected_columns => {"plot_name"=>1,"plot_number"=>1,"block_number"=>1},
    selected_trait_ids => [1,2,3],
    selected_trait_names => ['trait1|CO:00001', 'trait2|CO:000002']
});
my $output = $trial_layout_download->get_layout_output();

Output is an ArrayRef or ArrayRefs where the first entry is the Header and subsequent entries are the layout entries.


If you don't need treatments or phenotype summaries included you can ignore those keys like:

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $schema,
    trial_id => $trial_id,
    data_level => 'plots',
    selected_columns => {"plot_name"=>1,"plot_number"=>1,"block_number"=>1},
});
my $output = $trial_layout_download->get_layout_output();

=head1 AUTHORS


=cut


use Moose;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Stock::Accession;
use JSON;
use CXGN::Phenotypes::Summary;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);

has 'trial_id'   => (
    isa => "Int",
    is => 'ro',
    required => 1,
);

has 'data_level' => (
    is => 'ro',
    isa => 'Str',
    default => 'plots',
);
  
has 'treatment_project_ids' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'selected_columns' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {"plot_name"=>1, "plot_number"=>1} }
);

has 'selected_trait_ids'=> (
    is => 'ro',
    isa => 'ArrayRef[Int]|Undef',
);

has 'selected_trait_names'=> (
    is => 'ro',
    isa => 'ArrayRef[Str]|Undef',
);

sub get_layout_output {
    my $self = shift;
    my $trial_id = $self->trial_id();
    my $schema = $self->schema();
    my %errors;
    my @error_messages;
    my @output;

    print STDERR "TrialLayoutDownload for Trial id: ($trial_id) ".localtime()."\n";

    my $trial_layout;
    try {
        $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    };
    if (!$trial_layout) {
        push @error_messages, "Trial does not have valid field design.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    my $selected_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $trial_id});
    my $location_name = $selected_trial->get_location ? $selected_trial->get_location->[1] : '';
    my $trial_year = $selected_trial->get_year ? $selected_trial->get_year : '';
    my $accessions = $selected_trial->get_accessions();
    my @accession_ids;
    foreach (@$accessions){
        push @accession_ids, $_->{stock_id};
    }

    my $treatments = $self->treatment_project_ids();
    my @treatment_trials;
    my @treatment_names;
    my @treatment_units_array;
    if ($treatments){
        foreach (@$treatments){
            my $treatment_trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => $_});
            my $treatment_name = $treatment_trial->get_name();
            push @treatment_trials, $treatment_trial;
            push @treatment_names, $treatment_name;
        }
    }

    my $trial_name =  $trial_layout->get_trial_name();
    my $tl = $trial_layout->get_design();
    if (!$tl){
        push @error_messages, "Trial does not have valid field design. Please contact us.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    print STDERR Dumper $tl;

    my %selected_cols = %{$self->selected_columns};
    my @selected_traits = $self->selected_trait_ids() ? @{$self->selected_trait_ids} : ();
    my @selected_trait_names = $self->selected_trait_names() ? @{$self->selected_trait_names} : ();
    my $summary_values = [];
    if (scalar(@selected_traits)>0){
        my $summary = CXGN::Phenotypes::Summary->new({
            bcs_schema=>$schema,
            trait_list=>\@selected_traits,
            accession_list=>\@accession_ids
        });
        $summary_values = $summary->search();
    }
    my %fieldbook_trait_hash;
    foreach (@$summary_values){
        $fieldbook_trait_hash{$_->[0]}->{$_->[8]} = $_;
    }
    #print STDERR Dumper \%fieldbook_trait_hash;

    my @possible_cols = ();
    if ($self->data_level eq 'plots') {
        @possible_cols = ('plot_name','accession_name','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        if ($treatments){
            foreach (@treatment_trials){
                my $treatment_units = $_ ? $_->get_plots() : [];
                push @treatment_units_array, $treatment_units;
            }
        }
    } elsif ($self->data_level eq 'plants') {
        @possible_cols = ('plant_name','plot_name','accession_name','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','plant_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        if ($treatments){
            foreach (@treatment_trials){
                my $treatment_units = $_ ? $_->get_plants() : [];
                push @treatment_units_array, $treatment_units;
            }
        }
    } elsif ($self->data_level eq 'subplots') {
        @possible_cols = ('subplot_name','plot_name','accession_name','plot_number','block_number','is_a_control','rep_number','range_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        if ($treatments){
            foreach (@treatment_trials){
                my $treatment_units = $_ ? $_->get_subplots() : [];
                push @treatment_units_array, $treatment_units;
            }
        }
    } elsif ($self->data_level eq 'plants_subplots') {
        @possible_cols = ('plant_name','subplot_name','plot_name','accession_name','plot_number','block_number','is_a_control','range_number','rep_number','row_number','col_number','seedlot_name','seed_transaction_operator','num_seed_per_plot','subplot_number','plant_number','pedigree','location_name','trial_name','year','synonyms','tier','plot_geo_json');
        if ($treatments){
            foreach (@treatment_trials){
                my $treatment_units = $_ ? $_->get_plants() : [];
                push @treatment_units_array, $treatment_units;
            }
        }
    } elsif ($self->data_level eq 'plate') {
        @possible_cols = ('plot_number','plot_name','accession_name','pedigree','genus','species','trial_name','genotyping_project_name','genotyping_user_id','location_name');
    }

    my @header;
    foreach (@possible_cols){
        if ($selected_cols{$_}){
            push @header, $_;
        }
    }
    my @treatment_stock_hashes;
    if($treatments){
        foreach (@treatment_names){
            push @header, "ManagementFactor:".$_;
        }
        foreach my $u (@treatment_units_array){
            my %treatment_stock_hash;
            foreach (@$u){
                $treatment_stock_hash{$_->[1]}++;
            }
            push @treatment_stock_hashes, \%treatment_stock_hash;
        }
    }

    foreach (@selected_trait_names){
        push @header, $_;
    }

    push @output, \@header;

    my %design = %$tl;
    foreach my $key (sort { $a <=> $b} keys %design) {
        my %design_info = %{$design{$key}};

        if ($self->data_level eq 'plots') {
            my @line;
            foreach (@possible_cols){
                if ($selected_cols{$_}){
                    if ($_ eq 'location_name'){
                        push @line, $location_name;
                    } elsif ($_ eq 'plot_geo_json'){
                        push @line, $design_info{"plot_geo_json"} ? encode_json $design_info{"plot_geo_json"} : '';
                    } elsif ($_ eq 'trial_name'){
                        push @line, $trial_name;
                    } elsif ($_ eq 'year'){
                        push @line, $trial_year;
                    } elsif ($_ eq 'tier'){
                        my $row = $design_info{"row_number"} ? $design_info{"row_number"} : '';
                        my $col = $design_info{"col_number"} ? $design_info{"col_number"} : '';
                        push @line, $row."/".$col;
                    } elsif ($_ eq 'synonyms'){
                        my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                        push @line, join ',', @{$accession->synonyms}
                    } elsif ($_ eq 'pedigree'){
                        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                        push @line, $accession->get_pedigree_string('Parents');
                    } else {
                        push @line, $design_info{$_};
                    }
                }
            }
            if ($treatments){
                foreach (@treatment_stock_hashes){
                    if(exists($_->{$design_info{'plot_name'}})){
                        push @line, 1;
                    } else {
                        push @line, '';
                    }
                }
            }
            foreach my $t (@selected_trait_names){
                my $perf = $fieldbook_trait_hash{$t}->{$design_info{"accession_id"}};
                if($perf){
                    push @line, "Avg: ".$perf->[3]." Min: ".$perf->[5]." Max: ".$perf->[4]." Count: ".$perf->[2]." StdDev: ".$perf->[6];
                } else {
                    push @line, '';
                }
            }

            push @output, \@line;
        } elsif ($self->data_level eq 'plants'){
            my $plant_names = $design_info{'plant_names'};
            my $plant_num = 1;
            my $acc_synonyms = '';
            if (exists($selected_cols{'synonyms'})){
                my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                $acc_synonyms = join ',', @{$accession->synonyms};
            }
            my $acc_pedigree = '';
            if (exists($selected_cols{'pedigree'})){
                my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                $acc_pedigree = $accession->get_pedigree_string('Parents');
            }
            foreach (sort @$plant_names) {
                my @line;
                foreach my $c (@possible_cols){
                    if ($selected_cols{$c}){
                        if ($c eq 'plant_name'){
                            push @line, $_;
                        } elsif ($c eq 'plant_number'){
                            push @line, $plant_num;
                        } elsif ($c eq 'location_name'){
                            push @line, $location_name;
                        } elsif ($c eq 'plot_geo_json'){
                            push @line, $design_info{"plot_geo_json"} ? encode_json $design_info{"plot_geo_json"} : '';
                        } elsif ($c eq 'trial_name'){
                            push @line, $trial_name;
                        } elsif ($c eq 'year'){
                            push @line, $trial_year;
                        } elsif ($c eq 'tier'){
                            my $row = $design_info{"row_number"} ? $design_info{"row_number"} : '';
                            my $col = $design_info{"col_number"} ? $design_info{"col_number"} : '';
                            push @line, $row."/".$col;
                        } elsif ($c eq 'synonyms'){
                            push @line, $acc_synonyms;
                        } elsif ($c eq 'pedigree'){
                            push @line, $acc_pedigree;
                        } else {
                            push @line, $design_info{$c};
                        }
                    }
                }
                if ($treatments){
                    foreach my $u (@treatment_stock_hashes){
                        if(exists($u->{$_})){
                            push @line, 1;
                        } else {
                            push @line, '';
                        }
                    }
                }
                foreach my $t (@selected_trait_names){
                    my $perf = $fieldbook_trait_hash{$t}->{$design_info{"accession_id"}};
                    if ($perf){
                        push @line, "Avg: ".$perf->[3]." Min: ".$perf->[5]." Max: ".$perf->[4]." Count: ".$perf->[2]." StdDev: ".$perf->[6];
                    } else {
                        push @line, '';
                    }
                }

                $plant_num++;
                push @output, \@line;
            }
        } elsif ($self->data_level eq 'subplots'){
            my $subplot_names = $design_info{'subplot_names'};
            my $subplot_num = 1;
            my $acc_synonyms = '';
            if (exists($selected_cols{'synonyms'})){
                my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                $acc_synonyms = join ',', @{$accession->synonyms};
            }
            my $acc_pedigree = '';
            if (exists($selected_cols{'pedigree'})){
                my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                $acc_pedigree = $accession->get_pedigree_string('Parents');
            }
            foreach (sort @$subplot_names) {
                my @line;
                foreach my $c (@possible_cols){
                    if ($selected_cols{$c}){
                        if ($c eq 'subplot_name'){
                            push @line, $_;
                        } elsif ($c eq 'subplot_number'){
                            push @line, $subplot_num;
                        } elsif ($c eq 'location_name'){
                            push @line, $location_name;
                        } elsif ($c eq 'plot_geo_json'){
                            push @line, $design_info{"plot_geo_json"} ? encode_json $design_info{"plot_geo_json"} : '';
                        } elsif ($c eq 'trial_name'){
                            push @line, $trial_name;
                        } elsif ($c eq 'year'){
                            push @line, $trial_year;
                        } elsif ($c eq 'tier'){
                            my $row = $design_info{"row_number"} ? $design_info{"row_number"} : '';
                            my $col = $design_info{"col_number"} ? $design_info{"col_number"} : '';
                            push @line, $row."/".$col;
                        } elsif ($c eq 'synonyms'){
                            push @line, $acc_synonyms;
                        } elsif ($c eq 'pedigree'){
                            push @line, $acc_pedigree;
                        } else {
                            push @line, $design_info{$c};
                        }
                    }
                }
                if ($treatments){
                    foreach my $u (@treatment_stock_hashes){
                        if(exists($u->{$_})){
                            push @line, 1;
                        } else {
                            push @line, '';
                        }
                    }
                }
                foreach my $t (@selected_trait_names){
                    my $perf = $fieldbook_trait_hash{$t}->{$design_info{"accession_id"}};
                    if ($perf){
                        push @line, "Avg: ".$perf->[3]." Min: ".$perf->[5]." Max: ".$perf->[4]." Count: ".$perf->[2]." StdDev: ".$perf->[6];
                    } else {
                        push @line, '';
                    }
                }

                $subplot_num++;
                push @output, \@line;
            }
        } elsif ($self->data_level eq 'plants_subplots'){
            my $subplot_plant_names = $design_info{'subplots_plant_names'};
            my $subplot_num = 1;
            my $acc_synonyms = '';
            if (exists($selected_cols{'synonyms'})){
                my $accession = CXGN::Stock::Accession->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                $acc_synonyms = join ',', @{$accession->synonyms};
            }
            my $acc_pedigree = '';
            if (exists($selected_cols{'pedigree'})){
                my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                $acc_pedigree = $accession->get_pedigree_string('Parents');
            }
            foreach my $s (sort keys %$subplot_plant_names) {
                my $plants = $subplot_plant_names->{$s};
                my $plant_num = 1;
                foreach my $p (sort @$plants){
                    my @line;
                    foreach my $c (@possible_cols){
                        if ($selected_cols{$c}){
                            if ($c eq 'plant_name'){
                                push @line, $p;
                            } elsif ($c eq 'subplot_name'){
                                push @line, $s;
                            } elsif ($c eq 'subplot_number'){
                                push @line, $subplot_num;
                            } elsif ($c eq 'plant_number'){
                                push @line, $plant_num;
                            } elsif ($c eq 'location_name'){
                                push @line, $location_name;
                            } elsif ($c eq 'plot_geo_json'){
                                push @line, $design_info{"plot_geo_json"} ? encode_json $design_info{"plot_geo_json"} : '';
                            } elsif ($c eq 'trial_name'){
                                push @line, $trial_name;
                            } elsif ($c eq 'year'){
                                push @line, $trial_year;
                            } elsif ($c eq 'tier'){
                                my $row = $design_info{"row_number"} ? $design_info{"row_number"} : '';
                                my $col = $design_info{"col_number"} ? $design_info{"col_number"} : '';
                                push @line, $row."/".$col;
                            } elsif ($c eq 'synonyms'){
                                push @line, $acc_synonyms;
                            } elsif ($c eq 'pedigree'){
                                push @line, $acc_pedigree;
                            } else {
                                push @line, $design_info{$c};
                            }
                        }
                    }
                    if ($treatments){
                        foreach my $u (@treatment_stock_hashes){
                            if(exists($u->{$p})){
                                push @line, 1;
                            } else {
                                push @line, '';
                            }
                        }
                    }
                    foreach my $t (@selected_trait_names){
                        my $perf = $fieldbook_trait_hash{$t}->{$design_info{"accession_id"}};
                        if ($perf){
                            push @line, "Avg: ".$perf->[3]." Min: ".$perf->[5]." Max: ".$perf->[4]." Count: ".$perf->[2]." StdDev: ".$perf->[6];
                        } else {
                            push @line, '';
                        }
                    }
                    $plant_num++;
                    push @output, \@line;
                }
                $subplot_num++;
            }
        } elsif ($self->data_level eq 'plate') {
            my @line;
            foreach (@possible_cols){
                if ($selected_cols{$_}){
                    if ($_ eq 'location_name'){
                        push @line, $location_name;
                    } elsif ($_ eq 'trial_name'){
                        push @line, $trial_name;
                    } elsif ($_ eq 'pedigree'){
                        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                        push @line, $accession->get_pedigree_string('Parents');
                    } elsif ($_ eq 'genus'){
                        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                        push @line, $accession->genus;
                    } elsif ($_ eq 'species'){
                        my $accession = CXGN::Stock->new({schema=>$schema, stock_id=>$design_info{"accession_id"}});
                        push @line, $accession->species;
                    } else {
                        push @line, $design_info{$_};
                    }
                }
            }

            push @output, \@line;
        }
    }
    print STDERR "TrialLayoutDownload End for Trial id: ($trial_id) ".localtime()."\n";
    return {output => \@output};
}

1;