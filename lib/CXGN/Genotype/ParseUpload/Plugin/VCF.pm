package CXGN::Genotype::ParseUpload::Plugin::VCF;

use Moose::Role;
use SGN::Model::Cvterm;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Math::Round qw(round);

has 'markers' => (is => 'rw', isa => 'Ref');
has 'chroms' => (is => 'rw', isa => 'Ref');
has 'pos' => (is => 'rw', isa => 'Ref');
has 'ids' => (is => 'rw', isa => 'Ref');
has 'refs' => (is => 'rw', isa => 'Ref');
has 'alts' => (is => 'rw', isa => 'Ref');
has 'qual' => (is => 'rw', isa => 'Ref');
has 'filter' => (is => 'rw', isa => 'Ref');
has 'info' => (is => 'rw', isa => 'Ref');
has 'format' => (is => 'rw', isa => 'Ref');
has 'protocol_data' => (is => 'rw', isa=> 'Ref');
has 'header_info' => (is => 'rw', isa => 'Ref');
has 'observation_unit_names' => (is => 'rw', isa => 'Ref');
has '_fh' => (is => 'rw', isa => 'Ref');

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my %errors;
    my @error_messages;
    my %missing_accessions;

    print STDERR "Reading VCF to validate during parse...\n";

    my $F;
    my @header;
    my @header_info;
    my @fields;
    my @observation_unit_names;
    open($F, "<", $filename) || die "Can't open file $filename\n";
        while (<$F>) {
            chomp;
            #print STDERR Dumper $_;

            if ($_ =~ m/^##/){
                push @header_info, $_;
                next;
            }
            if ($_ =~ m/^#/){
                my $header = $_;
                @fields = split /\t/, $header;
                @header = @fields[0 .. 8];
                @observation_unit_names = @fields[9..$#fields];
                next;
            }
            last;
        }
    close($F);

    open($F, "<", $filename) || die "Can't open file $filename\n";

        my @chroms;
        my @positions;
        my @markers;
        my @refs;
        my @alts;
        my @quals;
        my @filters;
        my @infos;
        my @formats;
        my $line_count = 1;
        while (<$F>) {
            chomp;

            if ($_ =~ m/^##/){
                next;
            }
            if ($_ =~ m/^#/){
                next;
            }

            @fields = split /\t/;

            my @marker_info = @fields[ 0..8 ];
            push @chroms, $marker_info[0];
            push @positions, $marker_info[1];
            push @refs, $marker_info[3];
            push @alts, $marker_info[4];
            push @quals, $marker_info[5];
            push @filters, $marker_info[6];
            push @infos, $marker_info[7];
            push @formats, $marker_info[8];

            my $marker_name;
            my $marker_info_p2 = $marker_info[2];
            if ($marker_info_p2 eq '.') {
                $marker_name = $marker_info[0]."_".$marker_info[1];
            } else {
                $marker_name = $marker_info_p2;
            }
            push @markers, $marker_name;

            if ($marker_info[2] eq '' || !defined($marker_info[2])) {
                push @error_messages, "No marker name given on line $line_count. Marker name can be . if not assigned";
            }
            if ($marker_info[0] eq '' || !defined($marker_info[0])) {
                push @error_messages, "No chromosome 'chrom' given for marker $marker_name";
            }
            if ($marker_info[1] eq '' || !defined($marker_info[1])) {
                push @error_messages, "No position 'pos' given for marker $marker_name";
            }
            if (!$marker_info[3]) {
                push @error_messages, "No reference 'ref' allele given for marker $marker_name";
            }
            if (!$marker_info[4]) {
                push @error_messages, "No alternate 'alt' allele given for marker $marker_name";
            }
            if (!$marker_info[8]) {
                push @error_messages, "No format 'format' given for marker $marker_name";
            }
            $line_count++;
        }

    close($F);

    if (scalar(@markers) < 1) {
        push @error_messages, "Less than one marker is in your file!";
    }

    if ($header[0] ne '#CHROM'){
        push @error_messages, 'Column 1 header must be "#CHROM".';
    }
    if ($header[1] ne 'POS'){
        push @error_messages, 'Column 2 header must be "POS".';
    }
    if ($header[2] ne 'ID'){
        push @error_messages, 'Column 3 header must be "ID".';
    }
    if ($header[3] ne 'REF'){
        push @error_messages, 'Column 4 header must be "REF".';
    }
    if ($header[4] ne 'ALT'){
        push @error_messages, 'Column 5 header must be "ALT".';
    }
    if ($header[5] ne 'QUAL'){
        push @error_messages, 'Column 6 header must be "QUAL".';
    }
    if ($header[6] ne 'FILTER'){
        push @error_messages, 'Column 7 header must be "FILTER".';
    }
    if ($header[7] ne 'INFO'){
        push @error_messages, 'Column 8 header must be "INFO".';
    }
    if ($header[8] ne 'FORMAT'){
        push @error_messages, 'Column 9 header must be "FORMAT".';
    }

    $self->chroms(\@chroms);
    $self->pos(\@positions);
    $self->ids(\@markers);
    $self->refs(\@refs);
    $self->alts(\@alts);
    $self->qual(\@quals);
    $self->filter(\@filters);
    $self->info(\@infos);
    $self->format(\@formats);

    my $number_observation_units = scalar(@observation_unit_names);
    print STDERR "Number observation units: $number_observation_units...\n";

    my @observation_units_names_trim;
    if ($self->get_igd_numbers_included){
        foreach (@observation_unit_names) {
            my ($observation_unit_name_with_accession_name, $igd_number) = split(/:/, $_);
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
            push @observation_units_names_trim, $observation_unit_name;
        }
    } else {
        foreach (@observation_unit_names) {
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $_);
            push @observation_units_names_trim, $observation_unit_name;
        }
    }
    my $observation_unit_names = \@observation_units_names_trim;

    my $organism_id = $self->get_organism_id;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $stock_type = $self->get_observation_unit_type_name;
    my @missing_stocks;
    my $validator = CXGN::List::Validate->new();
    if ($stock_type eq 'tissue_sample'){
        @missing_stocks = @{$validator->validate($schema,'tissue_samples',$observation_unit_names)->{'missing'}};
    } elsif ($stock_type eq 'accession'){
        @missing_stocks = @{$validator->validate($schema,'accessions',$observation_unit_names)->{'missing'}};
    } elsif ($stock_type eq 'stocks'){
        @missing_stocks = @{$validator->validate($schema,'stocks',$observation_unit_names)->{'missing'}};
    } else {
        push @error_messages, "You can only upload genotype data for a tissue_sample OR accession (including synonyms) OR stocks!"
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
            print STDERR "Adding new accession $_!\n";
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

    $self->observation_unit_names(\@observation_unit_names);
    $self->header_info(\@header_info);

    my $protocol_data = $self->extract_protocol_data();
    $self->protocol_data($protocol_data);

    return 1; #returns true if validation is passed
}

sub extract_protocol_data {
    my $self = shift;
    my %protocolprop_info;

    for (my $i=0; $i<@{$self->ids()}; $i++) {
        my $marker_info_p2 = $self->ids()->[$i];
        my $marker_name;
        my $marker_info_p8 = $self->format()->[$i];
        if ($marker_info_p2 eq '.') {
            $marker_name = $self->chroms()->[$i]."_".$self->pos()->[$i];
        } else {
            $marker_name = $self->ids()->[$i];
        }
        my $chrom_name = $self->chroms()->[$i]
        my %marker = (
            name => $self->ids()->[$i],
            chrom => $chrom_name,
            pos => $self->pos()->[$i],
            ref => $self->refs()->[$i],
            alt => $self->alts()->[$i],
            qual => $self->qual()->[$i],
            filter => $self->filter()->[$i],
            info => $self->info()->[$i],
            format => $marker_info_p8,
        );

        push @{$protocolprop_info{'marker_names'}}, $marker_name;

        $protocolprop_info{'markers'}->{$chrom_name}->{$marker_name} = \%marker;
        push @{$protocolprop_info{'markers_array'}->{$chrom_name}}, \%marker;
    }
    $protocolprop_info{header_information_lines} = $self->header_info();
    $protocolprop_info{sample_observation_unit_type_name} = $self->get_observation_unit_type_name;

    return \%protocolprop_info;
}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $stock_type = $self->get_observation_unit_type_name;

    print STDERR "Reading VCF to parse\n";

    my $F;
    open($F, "<", $filename) || die "Can't open file $filename\n";
    while (<$F> =~ m/^##/) {
        #Trash header lines
    }
    $self->_fh($F);
}

sub next_genotype {
    my $self = shift;
    my %genotypeprop_observation_units;
    my $observation_unit_names = $self->observation_unit_names;

    my $line;
    my $F = $self->_fh();

    for my $iter (1..10) {
        if (! ($line = <$F>)) {
            print STDERR "No next genotype... Done!\n";
            if ($F) {
                close($F);
            }
            return ($observation_unit_names, \%genotypeprop_observation_units);
        }
        else {
            chomp($line);
            LABEL: if ($line =~ m/^\#/) {
                #print STDERR "Skipping header line: $line\n";
                $line = <$F>;
                goto LABEL;
            }

            my @fields = split /\t/, $line;
            my @marker_info = @fields[ 0..8 ];
            my @values = @fields[ 9..$#fields ];

            my $marker_name;
            my $marker_info_p2 = $marker_info[2];
            my $marker_info_p8 = $marker_info[8];
            if ($marker_info_p2 eq '.') {
                $marker_name = $marker_info[0]."_".$marker_info[1];
            } else {
                $marker_name = $marker_info_p2;
            }

            my @separated_alts = split ',', $marker_info[4];
            my $chrom = $marker_info[0];

            my @format =  split /:/,  $marker_info_p8;
            #As it goes down the rows, it contructs a separate json object for each observation unit column. They are all stored in the %genotypeprop_observation_units. Later this hash is iterated over and actually stores the json object in the database.
            for (my $i = 0; $i < scalar(@$observation_unit_names); $i++ ) {
                my @fvalues = split /:/, $values[$i];
                my %value;
                @value{@format} = @fvalues;
                my $gt_dosage_ref_val = 'NA';
                my $gt_dosage_alt_val = 'NA';
                my $gt_dosage_ref = 0;
                my $gt_dosage_alt = 0;
                if (exists($value{'GT'})) {
                    my $gt = $value{'GT'};
                    chomp($gt);

                    my $separator = '/';
                    my @alleles = split (/\//, $gt);
                    if (scalar(@alleles) <= 1){
                        @alleles = split (/\|/, $gt);
                        if (scalar(@alleles) > 1) {
                            $separator = '|';
                        }
                    }

                    my @nucleotide_genotype;
                    my @ref_calls;
                    my @alt_calls;
                    my $has_calls = 0;
                    foreach (@alleles) {
                        if (looks_like_number($_)) {
                            if ($_ eq '0') {
                                $gt_dosage_ref++;
                            }
                            else {
                                $gt_dosage_alt++;
                            }
                            my $index = $_ + 0;
                            if ($index == 0) {
                                push @nucleotide_genotype, $marker_info[3]; #Using Reference Allele
                                push @ref_calls, $marker_info[3];
                            } else {
                                push @nucleotide_genotype, $separated_alts[$index-1]; #Using Alternate Allele
                                push @alt_calls, $separated_alts[$index-1];
                            }
                            $has_calls = 1;
                        } else {
                            push @nucleotide_genotype, $_;
                        }
                    }
                    if ($has_calls) {
                        $gt_dosage_ref_val = $gt_dosage_ref;
                        $gt_dosage_alt_val = $gt_dosage_alt;
                    }
                    if ($separator eq '/') {
                        $separator = ',';
                        @nucleotide_genotype = (@ref_calls, @alt_calls);
                    }
                    $value{'NT'} = join $separator, @nucleotide_genotype;
                    $value{'DR'} = $gt_dosage_ref_val;
                }
                # If DS is provided in uploaded file and is a number, then this will be skipped
                if (exists($value{'GT'}) && !looks_like_number($value{'DS'})) {
                    $value{'DS'} = $gt_dosage_alt_val;
                }
                # if (looks_like_number($value{'DS'})) {
                    # my $rounded_ds = round($value{'DS'});
                    # $value{'DS'} = "$rounded_ds";
                # }
                $genotypeprop_observation_units{$observation_unit_names->[$i]}->{$chrom}->{$marker_name} = \%value;
            }
        }
    }

    return ($observation_unit_names, \%genotypeprop_observation_units);
}

1;
