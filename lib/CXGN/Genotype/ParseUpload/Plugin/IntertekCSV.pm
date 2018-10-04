package CXGN::Genotype::ParseUpload::Plugin::IntertekCSV;

use Moose::Role;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::GenotypeIO;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $marker_info_filename = $self->get_filename_intertek_marker_info();
    my $schema = $self->get_chado_schema();
    my %errors;
    my @error_messages;
    my %missing_accessions;

    print STDERR "Reading IntertekCSV to validate during parse...\n";
    my $gtio = CXGN::GenotypeIO->new({
        file => $filename,
        format => "intertek_grid"
    });

    my $header = $gtio->header;
    if ($header->[0] ne 'SampleName.LabID'){
        push @error_messages, 'Column 1 header must be "SampleName.LabID".';
    }

    my $observation_unit_names = $gtio->observation_unit_names();
    my $number_observation_units = scalar(@$observation_unit_names);
    print STDERR "Number observation units: $number_observation_units...\n";

    my @observation_units_names_trim;
    foreach (@$observation_unit_names) {
        my ($observation_unit_name_with_accession_name, $lab_id) = split(/./, $_);
        my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
        push @observation_units_names_trim, $observation_unit_name;
    }
    $observation_unit_names = \@observation_units_names_trim;

    my $organism_id = $self->get_organism_id;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $stock_type = $self->get_observation_unit_type_name;
    my @missing_stocks;
    my $validator = CXGN::List::Validate->new();
    if ($stock_type eq 'tissue_sample'){
        @missing_stocks = @{$validator->validate($schema,'tissue_samples',$observation_unit_names)->{'missing'}};
    } elsif ($stock_type eq 'accession'){
        @missing_stocks = @{$validator->validate($schema,'accessions',$observation_unit_names)->{'missing'}};
    } else {
        push @error_messages, "You can only upload genotype data for a tissue_sample OR accession (including synonyms)!"
    }

    my %unique_stocks;
    foreach (@missing_stocks){
        $unique_stocks{$_}++;
    }

    @missing_stocks = sort keys %unique_stocks;
    my @missing_stocks_return;
    foreach (@missing_stocks){
        if (!$self->get_create_missing_observation_units_as_accessions){
            push @missing_stocks_return, $_;
            print STDERR "WARNING! Observation unit name $_ not found for stock type $stock_type. You can pass an option to automatically create accessions.\n";
        } else {
            my $stock = $schema->resultset("Stock::Stock")->create({
                organism_id => $organism_id,
                name       => $_,
                uniquename => $_,
                type_id     => $accession_cvterm_id,
            });
        }
    }

    if (scalar(@missing_stocks_return)>0){
        $errors{'missing_stocks'} = \@missing_stocks_return;
        push @error_messages, "The following stocks are not in the database: ".join(',',@missing_stocks_return);
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed
}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $stock_type = $self->get_observation_unit_type_name;

    print STDERR "Reading VCF to parse\n";
    my $gtio = CXGN::GenotypeIO->new({ file => $filename, format => "vcf_new" });

    my %protocolprop_info;
    my %genotypeprop_observation_units;

    my $observation_unit_names = $gtio->observation_unit_names();
    my $number_observation_units = scalar(@$observation_unit_names);
    print STDERR "Number observation units: $number_observation_units...\n";

    my $header_info_lines = $gtio->header_information_lines();
    $protocolprop_info{'header_information_lines'} = $header_info_lines;
    $protocolprop_info{'sample_observation_unit_type_name'} = $stock_type;

    while (my ($marker_info, $values) = $gtio->next_vcf_row() ) {

        if ($marker_info){
            my $marker_name;
            my $marker_info_p2 = $marker_info->[2];
            my $marker_info_p8 = $marker_info->[8];
            if ($marker_info_p2 eq '.') {
                $marker_name = $marker_info->[0]."_".$marker_info->[1];
            } else {
                $marker_name = $marker_info_p2;
            }

            #As it goes down the rows, it appends the info from cols 0-8 into the protocolprop json object.
            my %marker = (
                name => $marker_name,
                chrom => $marker_info->[0],
                pos => $marker_info->[1],
                ref => $marker_info->[3],
                alt => $marker_info->[4],
                qual => $marker_info->[5],
                filter => $marker_info->[6],
                info => $marker_info->[7],
                format => $marker_info_p8,
            );
            $protocolprop_info{'markers'}->{$marker_name} = \%marker;
            push @{$protocolprop_info{'marker_names'}}, $marker_name;
            push @{$protocolprop_info{'markers_array'}}, \%marker;

            my @format =  split /:/,  $marker_info_p8;
            #As it goes down the rows, it contructs a separate json object for each observation unit column. They are all stored in the %genotypeprop_observation_units. Later this hash is iterated over and actually stores the json object in the database.
            for (my $i = 0; $i < $number_observation_units; $i++ ) {
                my @fvalues = split /:/, $values->[$i];
                my %value;
                #for (my $fv = 0; $fv < scalar(@format); $fv++ ) {
                #    $value{@format[$fv]} = @fvalues[$fv];
                #}
                @value{@format} = @fvalues;
                $genotypeprop_observation_units{$observation_unit_names->[$i]}->{$marker_name} = \%value;
            }
        }
    }
    #print STDERR Dumper \%protocolprop_info;
    #print STDERR Dumper \%genotypeprop_observation_units;

    my %parsed_data = (
        protocol_info => \%protocolprop_info,
        genotypes_info => \%genotypeprop_observation_units,
        observation_unit_uniquenames => $observation_unit_names
    );

    $self->_set_parsed_data(\%parsed_data);

    return 1;
}

1;
