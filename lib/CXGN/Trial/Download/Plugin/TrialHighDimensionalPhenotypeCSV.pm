
package CXGN::Trial::Download::Plugin::TrialHighDimensionalPhenotypeCSV;

=head1 NAME

CXGN::Trial::Download::Plugin::TrialHighDimensionalPhenotypeCSV

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

=head1 DESCRIPTION

=head1 AUTHORS

Ben Maza

=cut

use Moose::Role;

use CXGN::Trial;
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;
use Data::Dumper;
use DateTime;

sub verify {
    1;
}

sub download {
    my $self = shift;
    my $schema                    = $self->bcs_schema();
    my $trial_id                  = $self->trial_id();
    my $accession_list            = $self->accession_list;
    my $trait_list                = $self->trait_list();
    my $trait_contains            = $self->trait_contains();
    my $data_level                = $self->data_level();
    my $include_timestamp         = $self->include_timestamp();
    my $trial_list                = $self->trial_list();

    if (!$trial_list) {
        push @$trial_list, $trial_id;
    }

    my $plot_list                 = $self->plot_list;
    my $plant_list                = $self->plant_list;
    my $protocol_list             = $self->protocol_list;
    my $nd_protocol_id            = $protocol_list->[0];
    my $location_list             = $self->location_list;
    my $year_list                 = $self->year_list;
    my $instance_list             = $self->instance_list;
    my $phenotype_min_value       = $self->phenotype_min_value();
    my $phenotype_max_value       = $self->phenotype_max_value();
    my $exclude_phenotype_outlier = $self->exclude_phenotype_outlier;
    my $search_type               = $self->search_type();
    my $include_intercrop_stocks  = $self->include_intercrop_stocks();
    my $include_entry_numbers     = $self->include_entry_numbers();
    my $phenotype_start_date      = $self->start_date();
    my $phenotype_end_date        = $self->end_date();
    my $repetitive_measurements   = $self->repetitive_measurements();
    #my $hdp_type                  = $self->hdp_type();

    my $hdp_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
        bcs_schema                      => $schema,
        nd_protocol_id                  => $nd_protocol_id,
        high_dimensional_phenotype_type => 'NIRS',
        accession_list                  => $self->accession_list,
        query_associated_stocks         => 0,
        plot_list                       => $self->plot_list,
        plant_list                      => $self->plant_list,
        instance_list                   => $self->instance_list,
    });

    my ($data_hash, $identifier_metadata, $identifier_names) = $hdp_search->search();

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema                => $schema,
        search_type               => $search_type,
        data_level                => $data_level,
        trial_list                => $trial_list,
        year_list                 => $year_list,
        location_list             => $location_list,
        accession_list            => $accession_list,
        plant_list                => $plant_list,
        include_timestamp         => $include_timestamp,
        exclude_phenotype_outlier => $exclude_phenotype_outlier,
        include_intercrop_stocks  => $include_intercrop_stocks,
        include_entry_numbers     => $include_entry_numbers,
        phenotype_start_date      => $phenotype_start_date,
        phenotype_end_date        => $phenotype_end_date,
        repetitive_measurements   => $repetitive_measurements,
    );

    my @phenotype_data = $phenotypes_search->get_phenotype_matrix();

    # Find observationUnitDbId column index
    my $pheno_stock_col;
    for my $i (0 .. $#{ $phenotype_data[0] }) {
        if ($phenotype_data[0]->[$i] eq 'observationUnitDbId') {
            $pheno_stock_col = $i;
            last;
        }
    }

    if (!defined $pheno_stock_col) {
        print STDERR "ERROR: Could not find observationUnitDbId column in phenotype matrix\n";
    }

    # Filter phenotype_data to only rows whose stock_id exists in data_hash
    my @filtered_phenotype_data = ($phenotype_data[0]);
    for my $row (@phenotype_data[1 .. $#phenotype_data]) {
        my $stock_id = $row->[$pheno_stock_col];
        if (exists $data_hash->{$stock_id}) {
            push @filtered_phenotype_data, $row;
        } else {
            print STDERR "Excluding stock_id $stock_id from output (not in data_hash)\n";
        }
    }

    my @data = @filtered_phenotype_data;

    my ($first_stock)   = values %$data_hash;
    my @all_identifiers = $first_stock ? sort { $a <=> $b } keys %{ $first_stock->{spectra} } : ();

    # Filter identifiers by min/max wavelength
    my @identifiers = grep {
        my $wavelength = $_;
        my $above_min  = (!defined $phenotype_min_value || $phenotype_min_value eq '')
                         ? 1 : ($wavelength >= $phenotype_min_value);
        my $below_max  = (!defined $phenotype_max_value || $phenotype_max_value eq '')
                         ? 1 : ($wavelength <= $phenotype_max_value);
        $above_min && $below_max;
    } @all_identifiers;

    #print STDERR "Identifiers after wavelength filtering: " . Dumper \@identifiers;

    push @{ $data[0] }, "protocol_id", "instance_id", @identifiers;

    my %col_index;
    for my $i (0 .. $#{ $data[0] }) {
        $col_index{ $data[0]->[$i] } = $i;
    }

    my $stock_col = $col_index{"observationUnitDbId"};

    for my $row (@data[1 .. $#data]) {

        my $stock_id    = $row->[$stock_col];
        my $instance_id = $data_hash->{$stock_id}->{instance_id} // '';
        my $spectra     = $data_hash->{$stock_id}->{spectra};

        push @$row, $nd_protocol_id;
        push @$row, $instance_id;

        foreach my $id (@identifiers) {
            push @$row, ($spectra && defined $spectra->{$id}) ? $spectra->{$id} : '';
        }
    }

    my $time      = DateTime->now();
    my $timestamp = $time->ymd() . "_" . $time->hms();

    my $identifier_count    = scalar(@identifiers);
    my $trait_list_text     = $trait_list      ? join(",", @$trait_list)      : '';
    my $trial_list_text     = $trial_list      ? join(",", @$trial_list)      : '';
    my $accession_list_text = $accession_list  ? join(",", @$accession_list)  : '';
    my $plot_list_text      = $plot_list       ? join(",", @$plot_list)       : '';
    my $plant_list_text     = $plant_list      ? join(",", @$plant_list)      : '';
    my $instance_list_text  = $instance_list   ? join(",", @$instance_list)   : '';
    my $trait_contains_text = $trait_contains  ? join(",", @$trait_contains)  : '';
    my $location_list_text  = $location_list   ? join(",", @$location_list)   : '';
    my $year_list_text      = $year_list       ? join(",", @$year_list)       : '';
    my $min_value_text      = defined $phenotype_min_value ? $phenotype_min_value : '';
    my $max_value_text      = defined $phenotype_max_value ? $phenotype_max_value : '';

    my $search_parameters =
        "Data Level:$data_level "                               .
        "Trait List:$trait_list_text "                          .
        "Trial List:$trial_list_text "                          .
        "Accession List:$accession_list_text "                  .
        "Plot List:$plot_list_text "                            .
        "Plant List:$plant_list_text "                          .
        "Location List:$location_list_text "                    .
        "Year List:$year_list_text "                            .
        "Include Timestamp:$include_timestamp "                 .
        "Trait Contains:$trait_contains_text "                  .
        "Minimum Wavelength:$min_value_text "                   .
        "Maximum Wavelength:$max_value_text "                   .
        "Exclude Phenotype Outliers:$exclude_phenotype_outlier " .
        "Data Type: NIRS "                                      .
        "Protocol ID:$nd_protocol_id "                         .
        "Instance ID:$instance_list_text "                     .
        "Wavelengths Included:$identifier_count";

   
    no warnings 'uninitialized';
    open(my $F, ">", $self->filename()) || die "Can't open file " . $self->filename();

    if ($self->has_header) {
        print $F "\"Date of Download: $timestamp\"\n";
        print $F "\"Search Parameters: $search_parameters\"\n";
        print $F "\n";
    }

    for (my $line = 0; $line < @data; $line++) {
        my $columns = $data[$line];
        print $F join ',', map {
            my $field = $_;
            $field =~ s/"/""/g;
            qq!"$field"!;
        } @$columns;
        print $F "\n";
    }

    close($F);
}

1;