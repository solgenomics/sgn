
=head1 NAME

CXGN::Genotype::ParseUpload::Plugin::transposedVCF - plugin to load transposed VCF files

=head1 SYNOPSIS

 my $up = CXGN::Genotype::ParseUpload->new( {
    chado_schema => $schema,
    filename => $archived_filename_with_path,
    observation_unit_type_name => $obs_type,
    organism_id => $organism_id,
    create_missing_observation_units_as_accessions => $add_accessions,
    igd_numbers_included => $include_igd_numbers
  });

  $up->load_plugin("transposedVCF");
  if ($up->validate_with_plugin()) {
    $up->


=cut

package CXGN::Genotype::ParseUpload::Plugin::transposedVCF;

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
has '_is_first_line' => (is => 'rw', isa => 'Bool', default => 1);
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

    my @fields;

    open($F, "<", $filename) || die "Can't open file $filename\n";

    my @header_info;

    my $chroms;
    while (<$F>) {
	$_ =~ s/\r//g;
	chomp;
	if (m/\#\#/) {
	    print STDERR "Reading header line $_\n";
	    push @header_info, $_;
	}
	else {
	    $chroms = $_;
	    last();
	}
    }

    #print STDERR "CHROMS: $chroms\n";
    chomp($chroms);
    my @chroms = split /\t/, $chroms;
    foreach (@chroms) {
        if ($_ eq '' || !defined($_)) {
            push @error_messages, 'Chromosome (chrom) must be defined for all markers!';
        }
    }
    $self->chroms(\@chroms);

    my $pos = <$F>;
    chomp($pos);
    my @pos = split /\t/, $pos;
    foreach (@pos) {
        if ($_ eq '' || !defined($_)) {
            push @error_messages, 'Positions (pos) must be defined for all markers!';
        }
    }
    $self->pos(\@pos);
    #print STDERR "POS = ".Dumper(\@pos);

    my $ids = <$F>;
    chomp($ids);
    my @ids = split /\t/, $ids;
    foreach (@ids) {
        if ($_ eq '' || !defined($_)) {
            push @error_messages, 'Identifiers (id) must be defined for all markers (or .)!';
        }
    }
    $self->ids(\@ids);
    #print STDERR "IDS = ".Dumper(\@ids);

    my $refs = <$F>;
    chomp($refs);
    my @refs = split /\t/, $refs;
    $self->refs(\@refs);
    #print STDERR "REFS = ".Dumper(\@refs);

    my $alts = <$F>;
    chomp($alts);
    my @alts = split /\t/, $alts;
    $self->alts(\@alts);
    #print STDERR "ALTS = ".Dumper(\@alts);

    my $qual = <$F>;
    chomp($qual);
    my @qual = split /\t/,$qual;
    $self->qual(\@qual);
    #print STDERR "QUAL = ".Dumper(\@qual);

    my $filter = <$F>;
    chomp($filter);
    my @filter = split /\t/, $filter;
    $self->filter(\@filter);
    #print STDERR "FILTER = ".Dumper(\@filter);

    my $info = <$F>;
    chomp($info);
    my @info = split /\t/, $info;
    $self->info(\@info);
    #print STDERR "INFO = ".Dumper(\@info);

    my $format = <$F>;
    chomp($format);
    my @format = split /\t/, $format;
    $self->format(\@format);
    #print STDERR "FORMAT = ".Dumper(\@format);

    print STDERR "marker count = ".scalar(@ids)."\n";

    if ($chroms[0] ne '#CHROM'){
        push @error_messages, 'Line 1 must start with "#CHROM".';
    }
    if ($pos[0] ne 'POS'){
        push @error_messages, 'Line 2 must start with "POS".';
    }
    if ($ids[0] ne 'ID'){
        push @error_messages, 'Line 3 must start with "ID".';
    }
    if ($refs[0] ne 'REF'){
        push @error_messages, 'Line 4 must start with "REF".';
    }
    if ($alts[0] ne 'ALT'){
        push @error_messages, 'Line 5 must start with "ALT".';
    }
    if ($qual[0] ne 'QUAL'){
        push @error_messages, 'Line 6 must start with "QUAL".';
    }
    if ($filter[0] ne 'FILTER'){
        push @error_messages, 'Line 7 must start with "FILTER".';
    }
    if ($info[0] ne 'INFO'){
        push @error_messages, 'Line 8 must start with "INFO".';
    }
    if ($format[0] ne 'FORMAT'){
        push @error_messages, 'Line 9 must start with "FORMAT".';
    }

    my @observation_unit_names;

    #print STDERR "Scanning file for observation unit names... \n";
    my $lines = 0;
    while (<$F>) {
	chomp;

	my @fields = split /\t/;
	#print "Parsing line $fields[0]\n";
	push @observation_unit_names, $fields[0];
	$lines++;
	if ($lines % 100 == 0) { print STDERR "Reading line $lines...        \r"; }
    }

    #print STDERR "\n";
    close($F);

    my $number_observation_units = scalar(@observation_unit_names);
    #print STDERR "Number of observation units: $number_observation_units\n";

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


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $stock_type = $self->get_observation_unit_type_name;

    print STDERR "Reading VCF to parse\n";

    my $F;
    open($F, "<", $filename) || die "Can't open file $filename\n";
    while (<$F> =~ m/^\##/) {
        #Trash header lines
    }
    $self->_fh($F);
}

sub extract_protocol_data {
    my $self = shift;

    my $marker_name;
    my %protocolprop_info;
    my $marker_info_p8;

#    open(my $F, '<', $self->get_filename()) || die "Can't open file ".$self->get_filename()."\n";

    for (my $i=1; $i<@{$self->ids()}; $i++) {
        my $marker_info_p2 = $self->ids()->[$i];
        my $marker_info_p8 = $self->format()->[$i];
        if ($marker_info_p2 eq '.') {
            $marker_name = $self->chroms()->[$i]."_".$self->pos()->[$i];
        } else {
            $marker_name = $self->ids()->[$i];
        }
        my $chrom_name = $self->chroms()->[$i];
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

        #print STDERR "Marker: ".Dumper(\%marker);
        push @{$protocolprop_info{'marker_names'}}, $marker_name;

        $protocolprop_info{'markers'}->{$chrom_name}->{$marker_name} = \%marker;
        push @{$protocolprop_info{'markers_array'}->{$chrom_name}}, \%marker;
    }
    my $stock_type = $self->get_observation_unit_type_name;
    $protocolprop_info{header_information_lines} = $self->header_info();
    $protocolprop_info{sample_observation_unit_type_name} = $stock_type;

    return \%protocolprop_info;
}

sub next_genotype {
    my $self = shift;

    #print STDERR "Processing next genotype...\n";
    my @fields;

    my $genotypeprop = {}; # hashref
    my $observation_unit_name;

    my $line;

    my $F = $self->_fh();

    if (! ($line = <$F>)) {
        print STDERR "No next genotype... Done!\n";
        close($F);
        return ( [$observation_unit_name], $genotypeprop );
    } else {
	$line =~ s/\r//g;
        chomp($line);

        if ($self->_is_first_line()) {
            print STDERR "Skipping 7 more lines... ";
            for (0..6) {
                $line = <$F>;
		#print STDERR Dumper $line;
            }
        }
	$line =~ s/\r//g;
        chomp($line);

        my @fields = split /\t/, $line;
        #print STDERR Dumper \@fields;

        $observation_unit_name = $fields[0];
        my @scores = @fields[1..$#fields];
        #print STDERR Dumper \@scores;

        my $marker_name = "";

        for(my $i=1; $i<=@scores; $i++) {
            my $marker_name = $self->ids()->[$i];
             if ($marker_name eq '.') {
                $marker_name = $self->chroms()->[$i]."_".$self->pos()->[$i];
            } 
            my $chrom = $self->chroms()->[$i];
            my @separated_alts = split ',', $self->alts()->[$i];
            my @format =  split /:/,  $self->format()->[$i];

            my @fvalues = split /:/, $scores[$i-1];
            my %value;
            @value{@format} = @fvalues;
            my $gt_dosage_alt_val = 'NA';
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
                        if ($_ ne '0') {
                            $gt_dosage_alt++;
                        }
                        my $index = $_ + 0;
                        if ($index == 0) {
                            push @nucleotide_genotype, $self->refs()->[$i]; #Using Reference Allele
                            push @ref_calls, $self->refs()->[$i];
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
                    $gt_dosage_alt_val = $gt_dosage_alt;
                }
                if ($separator eq '/') {
                    $separator = ',';
                    @nucleotide_genotype = (@ref_calls, @alt_calls);
                }
                $value{'NT'} = join $separator, @nucleotide_genotype;
                $value{'GT'} = $gt;
            }
            # If DS is provided in uploaded file and is a number, then this will be skipped
            if (exists($value{'GT'}) && !looks_like_number($value{'DS'})) {
                $value{'DS'} = $gt_dosage_alt_val;
            }
            # if (looks_like_number($value{'DS'})) {
            #     my $rounded_ds = round($value{'DS'});
            #     $value{'DS'} = "$rounded_ds";
            # }
            $genotypeprop->{$chrom}->{$marker_name} = \%value;
        }
        $self->_is_first_line(0);
    }

    return ( [$observation_unit_name], { $observation_unit_name => $genotypeprop } );
}

1;
