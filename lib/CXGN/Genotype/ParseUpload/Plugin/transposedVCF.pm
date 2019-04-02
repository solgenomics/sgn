
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

    print STDERR "CHROMS: $chroms\n";
    chomp($chroms);
    my @chroms = split /\t/, $chroms;
    $self->chroms(\@chroms);
    
    my $pos = <$F>;
    chomp($pos);
    my @pos = split /\t/, $pos;
    $self->pos(\@pos);
    
    my $ids = <$F>;
    chomp($ids);
    my @ids = split /\t/, $ids;
    $self->ids(\@ids);
    
    print STDERR "IDS = ".Dumper(\@ids);
    
    my $refs = <$F>;
    chomp($refs);
    my @refs = split /\t/, $refs;
    $self->refs(\@refs);
    
    my $alts = <$F>;
    chomp($alts);
    my @alts = split /\t/, $alts;
    $self->alts(\@alts);
    
    my $qual = <$F>;
    chomp($qual);
    my @qual = split /\t/,$qual;
    $self->qual(\@qual);
    
    my $filter = <$F>;
    chomp($filter);
    my @filter = split /\t/, $filter;
    $self->filter(\@filter);
    
    my $info = <$F>;
    chomp($info);
    my @info = split /\t/, $info;
    $self->info(\@info);
    
    my $format = <$F>;
    chomp($format);
    my @format = split /\t/, $format;
    $self->format(\@format);
    
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
   
    while (<$F>) {
	chomp;

	my @fields = split /\t/;
	print "Parsing line $fields[0]\n";
	push @observation_unit_names, $fields[0];
    }

    close($F);
    
    my $number_observation_units = scalar(@observation_unit_names);
    print STDERR "Number of observation units: $number_observation_units\n";
    
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

    foreach (1..9) { my $trash = <$F>; } # remove first 9 lines
    $self->_fh($F);
    
    
}

sub extract_protocol_data {
    my $self = shift;

    my $marker_name;
    my %protocolprop_info;
    my $marker_info_p8;
    
#    open(my $F, '<', $self->get_filename()) || die "Can't open file ".$self->get_filename()."\n";

    for (my $i=0; $i<@{$self->ids()}; $i++) { 
	my $marker_info_p2 = $self->ids()->[$i];
	my $marker_info_p8 = $self->format()->[$i];
	if ($marker_info_p2 eq '.') {
	    $marker_name = $self->chroms()->[$i]."_".$self->pos()->[$i];
	} else {
	    $marker_name = $self->ids()->[$i];
	}
	
	my %marker = 
	    (
	     name => $self->ids()->[$i],
	     chrom => $self->chroms()->[$i],
	     pos => $self->pos()->[$i],
	     ref => $self->refs()->[$i],
	     alt => $self->alts()->[$i],
	     qual => $self->qual()->[$i],
	     filter => $self->filter()->[$i],
	     info => $self->info()->[$i],
	     format => $marker_info_p8,
            );

            #print STDERR "Marker: ".Dumper(\%marker);
            $protocolprop_info{'markers'}->{$marker_name} = \%marker;
            push @{$protocolprop_info{'marker_names'}}, $marker_name;
            push @{$protocolprop_info{'markers_array'}}, \%marker;
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

    my $genotypeprop; # hashref
    my $line;

    my $F = $self->_fh();
    

    if (! ($line = <$F>)) { 
	print STDERR "No next genotype... Done!\n"; 
	close($F); 
	return 0; 
    }
    else {
	chomp($line);

	LABEL: if ($line =~ m/^\#/) { print STDERR "Skipping header line: $line\n"; $line = <$F>; chomp;  goto LABEL; }

	my @fields = split /\t/, $line;

	my $observation_unit_name = $fields[0];
	my @scores = @fields[1..$#fields];

	my $marker_name = "";
	
	for(my $i=1; $i<@scores; $i++) { 

            my @separated_alts = split ',', $self->alts()->[$i];

            my @format =  split /:/,  $self->format()->[$i];

            #As it goes down the rows, it contructs a separate json object for each observation unit column. They are all stored in the %genotypeprop_observation_units. Later this hash is iterated over and actually stores the json object in the database.
	    
	    my @fvalues = split /:/, $scores[$i];
	    my %value;
	    #for (my $fv = 0; $fv < scalar(@format); $fv++ ) {
	    #    $value{@format[$fv]} = @fvalues[$fv];
	    #}
	    @value{@format} = @fvalues;
	    my $gt_dosage = 0;
	    if (exists($value{'GT'})) {
		my @nucleotide_genotype;
		my $gt = $value{'GT'};
		my $separator = '/';
		my @alleles = split (/\//, $gt);
		if (scalar(@alleles) <= 1){
		    @alleles = split (/\|/, $gt);
		    if (scalar(@alleles) > 1) {
			$separator = '|';
		    }
		}
		foreach (@alleles) {
		    if (looks_like_number($_)) {
			$gt_dosage = $gt_dosage + $_;
			my $index = $_ + 0;
			if ($index == 0) {
			    push @nucleotide_genotype, $self->refs()->[$i]; #Using Reference Allele
			} else {
			    push @nucleotide_genotype, $separated_alts[$index-1]; #Using Alternate Allele
			}
		    } else {
			push @nucleotide_genotype, $_;
		    }
		}
		$value{'NT'} = join $separator, @nucleotide_genotype;
	    }
	    if (exists($value{'GT'}) && !looks_like_number($value{'DS'})) {
		$value{'DS'} = $gt_dosage;
	    }
	    if (looks_like_number($value{'DS'})) {
		$value{'DS'} = round($value{'DS'});
	    }
	    $genotypeprop->{$marker_name} = \%value;
	}
    }
    
    
    #        print STDERR Dumper($genotypeprop);
    #   close($F);
    
    #    $protocolprop_info{'header_information_lines'} = \@header_info;
    #    $protocolprop_info{'sample_observation_unit_type_name'} = $stock_type;
    
    #print STDERR Dumper \%protocolprop_info;
    #print STDERR Dumper \%genotypeprop_observation_units;
    
    #  my %parsed_data = (
    #      protocol_info => \%protocolprop_info,
    #      genotypes_info => \%genotypeprop_observation_units,
    #      observation_unit_uniquenames => \@observation_unit_names
    #  );
    
    # $self->_set_parsed_data(\%parsed_data);

    return $genotypeprop;
}

1;
