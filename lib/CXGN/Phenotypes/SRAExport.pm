package CXGN::Phenotypes::SRAExport;

=head1 NAME

CXGN::Phenotypes::SRAExport - NCBI BioSample and SRA metadata sheets for tissue samples

=head1 SYNOPSIS

  my $export = CXGN::Phenotypes::SRAExport->new({
      bcs_schema      => $schema,
      people_schema   => $people_schema,
      metadata_schema => $metadata_schema,
      phenome_schema  => $phenome_schema,
      tissue_sample_ids => [ ... ],   # or
      trial_ids         => [ ... ],   # or
      nd_protocol_id    => $id,       # transcriptomics protocol
  });
  # zip with biosample_attributes.xlsx, sra_metadata.tsv and README.txt
  my $result = $export->write_submission_package($zip_path);

  # or the sheets on their own
  my $sample_count = $export->write_xlsx($filepath);
  my $warnings     = $export->write_sra_metadata_tsv($filepath);

=head1 DESCRIPTION

Writes the two sheets NCBI needs to deposit reads in SRA for a set of
tissue samples: the BioSample attributes sheet (write_xlsx) and the SRA
metadata table (write_sra_metadata_tsv, documented below).

The BioSample sheet is the "Plant; version 1.0" batch template. The output matches NCBI's Plant.1.0.xlsx: sheet name,
comment rows, header colours and definitions, column widths and the 'sex'
dropdown.

Samples come from, in order of precedence: tissue_sample_ids; all tissue
samples in trial_ids; or all tissue samples with data in nd_protocol_id.

Values are read from the database:
  *organism         organism of the tissue sample
  cultivar          accession of the sample (directly, or via its plant/plot)
  isolate           plant/plot the sample was taken from
  *collection_date  'acquisition date' stockprop (ISO 8601)
  *geo_loc_name     "Country: Location" of the sample's trial
  *tissue           'tissue_type' stockprop
  replicate, block, plot_number   custom attributes, when present

NCBI rejects a sheet in which two rows are identical once sample_name,
sample_title and description are ignored. If that still happens after the
fields above, a breedbase_sample_name custom attribute is added.

Mandatory fields with no value are written as 'missing', including one field
of each blue group (isolate/cultivar/ecotype and age/dev_stage).

=cut

use Moose;
use Excel::Writer::XLSX;
use CXGN::Trial;
use Archive::Zip qw(:ERROR_CODES);
use Encode qw(encode);
use File::Temp qw(tempdir);
use JSON qw(decode_json);

# NCBI SRA controlled vocabularies, copied from the 'Library and Platform Terms'
# sheet of NCBI's SRA metadata template (SRA_metadata.xlsx).
my @SRA_SELECTIONS = (
    'RANDOM', 'PCR', 'RANDOM PCR', 'RT-PCR', 'HMPR', 'MF', 'CF-S', 'CF-M', 'CF-H', 'CF-T', 'MDA',
    'MSLL', 'cDNA', 'ChIP', 'MNase', 'DNAse', 'Hybrid Selection', 'Reduced Representation',
    'Restriction Digest', '5-methylcytidine antibody', 'MBD2 protein methyl-CpG binding domain',
    'CAGE', 'RACE', 'size fractionation', 'Padlock probes capture method', 'other', 'unspecified',
    'cDNA_oligo_dT', 'cDNA_randomPriming', 'Inverse rRNA', 'Oligo-dT', 'PolyA',
    'repeat fractionation',
);
my %SRA_INSTRUMENTS = (
    _LS454 => [ '454 GS', '454 GS 20', '454 GS FLX', '454 GS FLX+', '454 GS FLX Titanium', '454 GS Junior' ],
    ILLUMINA => [ 'HiSeq X Five', 'HiSeq X Ten', 'Illumina Genome Analyzer', 'Illumina Genome Analyzer II', 'Illumina Genome Analyzer IIx', 'Illumina HiScanSQ', 'Illumina HiSeq 1000', 'Illumina HiSeq 1500', 'Illumina HiSeq 2000', 'Illumina HiSeq 2500', 'Illumina HiSeq 3000', 'Illumina HiSeq 4000', 'Illumina HiSeq X', 'Illumina MiSeq', 'Illumina MiSeq i100', 'Illumina MiniSeq', 'Illumina NovaSeq 6000', 'Illumina NovaSeq X', 'Illumina NovaSeq X Plus', 'Illumina iSeq 100', 'NextSeq 1000', 'NextSeq 2000', 'NextSeq 500', 'NextSeq 550' ],
    HELICOS => [ 'Helicos HeliScope' ],
    ABI_SOLID => [ 'AB 5500 Genetic Analyzer', 'AB 5500xl Genetic Analyzer', 'AB 5500x-Wl Genetic Analyzer', 'AB SOLiD 3 Plus System', 'AB SOLiD 4 System', 'AB SOLiD 4hq System', 'AB SOLiD PI System', 'AB SOLiD System', 'AB SOLiD System 2.0', 'AB SOLiD System 3.0' ],
    COMPLETE_GENOMICS => [ 'Complete Genomics' ],
    PACBIO_SMRT => [ 'PacBio RS', 'PacBio RS II', 'Revio', 'Sequel', 'Sequel II', 'Sequel IIe', 'Onso' ],
    ION_TORRENT => [ 'Ion Torrent PGM', 'Ion Torrent Proton', 'Ion Torrent S5 XL', 'Ion Torrent S5', 'Ion Torrent Genexus', 'Ion GeneStudio S5', 'Ion GeneStudio S5 Plus', 'Ion GeneStudio S5 Prime' ],
    CAPILLARY => [ 'AB 310 Genetic Analyzer', 'AB 3130 Genetic Analyzer', 'AB 3130xL Genetic Analyzer', 'AB 3500 Genetic Analyzer', 'AB 3500xL Genetic Analyzer', 'AB 3730 Genetic Analyzer', 'AB 3730xL Genetic Analyzer' ],
    OXFORD_NANOPORE => [ 'GridION', 'MinION', 'PromethION' ],
    BGISEQ => [ 'BGISEQ-50', 'BGISEQ-500', 'MGISEQ-2000RS' ],
    DNBSEQ => [ 'DNBSEQ-G400', 'DNBSEQ-G50', 'DNBSEQ-T7', 'DNBSEQ-G400 FAST' ],
    ELEMENT => [ 'Element AVITI' ],
    GENAPSYS => [ 'GS111' ],
    GENEMIND => [ 'FASTASeq 300', 'GenoCare 1600', 'GenoLab M' ],
    TAPESTRI => [ 'Tapestri' ],
    ULTIMA => [ 'UG 100' ],
    VELA_DIAGNOSTICS => [ 'Sentosa SQ301' ],
);

has 'bcs_schema'        => ( isa => 'Bio::Chado::Schema',     is => 'ro', required => 1 );
has 'people_schema'     => ( isa => 'CXGN::People::Schema',   is => 'ro', required => 1 );
has 'metadata_schema'   => ( isa => 'CXGN::Metadata::Schema', is => 'ro', required => 1 );
has 'phenome_schema'    => ( isa => 'CXGN::Phenome::Schema',  is => 'ro', required => 1 );
has 'tissue_sample_ids' => ( isa => 'ArrayRef[Int]', is => 'ro', default => sub { [] } );
has 'trial_ids'         => ( isa => 'ArrayRef[Int]', is => 'ro', default => sub { [] } );
has 'nd_protocol_id'    => ( isa => 'Maybe[Int]',    is => 'ro' );

=head2 get_tissue_sample_ids()

Returns an arrayref of the tissue sample stock_ids that will be exported.

=cut

sub get_tissue_sample_ids {
    my $self = shift;
    return [ @{ $self->tissue_sample_ids } ] if @{ $self->tissue_sample_ids };

    my $dbh = $self->bcs_schema->storage->dbh;
    my ($q, @bind);
    if (@{ $self->trial_ids }) {
        my $trial_placeholders = join(',', ('?') x scalar(@{ $self->trial_ids }));
        $q = "SELECT DISTINCT s.stock_id
            FROM stock s
            JOIN cvterm stype               ON s.type_id = stype.cvterm_id
            JOIN nd_experiment_stock ndes   ON s.stock_id = ndes.stock_id
            JOIN nd_experiment_project ndep ON ndes.nd_experiment_id = ndep.nd_experiment_id
            WHERE stype.name = 'tissue_sample'
            AND ndep.project_id IN ($trial_placeholders);";
        @bind = @{ $self->trial_ids };
    }
    elsif ($self->nd_protocol_id) {
        $q = "SELECT DISTINCT s.stock_id
            FROM stock s
            JOIN cvterm stype                ON s.type_id = stype.cvterm_id
            JOIN nd_experiment_stock ndes    ON s.stock_id = ndes.stock_id
            JOIN nd_experiment_protocol ndep ON ndes.nd_experiment_id = ndep.nd_experiment_id
            WHERE stype.name = 'tissue_sample'
            AND ndep.nd_protocol_id = ?;";
        @bind = ($self->nd_protocol_id);
    }
    else {
        return [];
    }

    my $h = $dbh->prepare($q);
    $h->execute(@bind);
    my @ids;
    while (my ($stock_id) = $h->fetchrow_array()) {
        push @ids, $stock_id;
    }
    return \@ids;
}

=head2 write_xlsx($filepath)

Writes the BioSample sheet to $filepath and returns the number of samples.
Dies if there are no tissue samples to export.

=cut

sub write_xlsx {
    my $self     = shift;
    my $tempfile = shift;

    my ($sample_data, $sample_order) = $self->_sample_data();
    die "No tissue samples found to export.\n" unless @$sample_order;
    my %sample_data  = %$sample_data;
    my @sample_order = @$sample_order;

    # --- NCBI BioSample "Plant.1.0" template ----------------------------
    # Reproduces https://www.ncbi.nlm.nih.gov/biosample/docs/templates/ (Plant.1.0.xlsx):
    # sheet name, 12 '#' comment rows, header row 13 with group colours,
    # hover-comment definitions, column widths and the 'sex' dropdown.
    my %fill = (
        green  => '#92D050',   # mandatory
        blue   => '#00A0F0',   # "at least one of" (comment row only)
        org    => '#52A5FF',   # Organism group: isolate/cultivar/ecotype
        age    => '#66CDFF',   # Age/stage group: age/dev_stage
        yellow => '#FFFF00',   # optional
    );

    # [ header, fill, width (undef = Excel default), hover comment ]
    my @all_columns = (
        [ '*sample_name', 'green', 14, 'Sample Name is a name that you choose for the sample. It can have any format, but we suggest that you make it concise, unique and consistent within your lab, and as informative as possible. Every Sample Name from a single Submitter must be unique.' ],
        [ 'sample_title', 'yellow', undef, 'Title of the sample.' ],
        [ 'bioproject_accession', 'yellow', 22, 'The accession number of the BioProject(s) to which the BioSample belongs. If the BioSample belongs to more than one BioProject, enter multiple bioproject_accession columns. A valid BioProject accession has prefix PRJN, PRJE or PRJD, e.g., PRJNA12345.' ],
        [ '*organism', 'green', 11, q{The most descriptive organism name for this sample (to the species, if possible). It is OK to submit an organism name that is not in our database. In the case of a new species, provide the desired organism name, and our taxonomists may assign a provisional taxID. In the case of unidentified species, choose the appropriate Genus and include 'sp.', e.g., "Escherichia sp.". When sequencing a genome from a non-metagenomic source, include a strain or isolate name too, e.g., "Pseudomonas sp. UK4". For more information about providing a valid organism, including new species, metagenomes (microbiomes) and metagenome-assembled genomes, see https://www.ncbi.nlm.nih.gov/biosample/docs/organism/.} ],
        [ 'isolate', 'org', 9, "Organism group\n\nidentification or description of the specific individual from which this sample was obtained" ],
        [ 'cultivar', 'org', 10, "Organism group\n\ncultivar name - cultivated variety of plant" ],
        [ 'ecotype', 'org', 9, "Organism group\n\na population within a given species displaying genetically based, phenotypic traits that reflect adaptation to a local habitat, e.g., Columbia" ],
        [ 'age', 'age', 5, "Age/stage group\n\nage at the time of sampling; relevant scale depends on species and study, e.g. could be seconds for amoebae or centuries for trees" ],
        [ 'dev_stage', 'age', 11, "Age/stage group\n\nDevelopmental stage at the time of sampling." ],
        [ '*collection_date', 'green', 18, q{the date on which the sample was collected; date/time ranges are supported by providing two dates from among the supported value formats, delimited by a forward-slash character; collection times are supported by adding "T", then the hour and minute after the date, and must be in Coordinated Universal Time (UTC), otherwise known as "Zulu Time" (Z); supported formats include "DD-Mmm-YYYY", "Mmm-YYYY", "YYYY" or ISO 8601 standard "YYYY-mm-dd", "YYYY-mm", "YYYY-mm-ddThh:mm:ss"; e.g., 30-Oct-1990, Oct-1990, 1990, 1990-10-30, 1990-10,  21-Oct-1952/15-Feb-1953, 2015-10-11T17:53:03Z; valid non-ISO dates will be automatically transformed to ISO format} ],
        [ '*geo_loc_name', 'green', 15, q{Geographical origin of the sample; use the appropriate name from this list https://www.insdc.org/submitting-standards/geo_loc_name-qualifier-vocabulary/. Use a colon to separate the country or ocean from more detailed information about the location, eg "Canada: Vancouver" or "Germany: halfway down Zugspitze, Alps"} ],
        [ '*tissue', 'green', 9, 'Type of tissue the sample was taken from.' ],
        [ 'biomaterial_provider', 'yellow', 22, 'name and address of the lab or PI, or a culture collection identifier' ],
        [ 'cell_line', 'yellow', 11, 'Name of the cell line.' ],
        [ 'cell_type', 'yellow', undef, 'Type of cell of the sample or from which the sample was obtained.' ],
        [ 'collected_by', 'yellow', 14, 'Name of persons or institute who collected the sample' ],
        [ 'culture_collection', 'yellow', 20, 'Name of source institute and unique culture identifier. See the description for the proper format and list of allowed institutes, http://www.insdc.org/controlled-vocabulary-culturecollection-qualifier' ],
        [ 'disease', 'yellow', 9, 'list of diseases diagnosed; can include multiple diagnoses. the value of the field depends on host; for humans the terms should be chosen from DO (Disease Ontology), free text for non-human. For DO terms, please see http://gemina.svn.sourceforge.net/viewvc/gemina/trunk/Gemina/ontologies/gemina_symptom.obo?view=log' ],
        [ 'disease_stage', 'yellow', 15, 'stage of disease at the time of sampling.' ],
        [ 'genotype', 'yellow', 10, 'observed genotype' ],
        [ 'growth_protocol', 'yellow', 17, undef ],
        [ 'height_or_length', 'yellow', 18, 'measurement of height or length' ],
        [ 'isolation_source', 'yellow', undef, 'Describes the physical, environmental and/or local geographical source of the biological sample from which the sample was derived.' ],
        [ 'lat_lon', 'yellow', 9, q{The geographical coordinates of the location where the sample was collected. Specify as degrees latitude and longitude in format "d[d.dddd] N|S d[dd.dddd] W|E", eg, 38.98 N 77.11 W} ],
        [ 'phenotype', 'yellow', 11, 'Phenotype of sampled organism. For Phenotypic quality Ontology (PATO) (v1.269) terms, please see http://bioportal.bioontology.org/visualize/44601' ],
        [ 'population', 'yellow', 12, 'for human: ; for plants: filial generation, number of progeny, genetic structure' ],
        [ 'sample_type', 'yellow', 13, 'Sample type, such as cell culture, mixed culture, tissue sample, whole organism, single cell, metagenomic assembly' ],
        [ 'sex', 'yellow', 5, 'physical sex of sampled organism' ],
        [ 'specimen_voucher', 'yellow', 18, q{Identifier for the physical specimen. Use format: "[<institution-code>:[<collection-code>:]]<specimen_id>", eg, "UAM:Mamm:52179". Intended as a reference to the physical specimen that remains after it was analyzed. If the specimen was destroyed in the process of analysis, electronic images (e-vouchers) are an adequate substitute for a physical voucher specimen. Ideally the specimens will be deposited in a curated museum, herbarium, or frozen tissue collection, but often they will remain in a personal or laboratory collection for some time before they are deposited in a curated collection. There are three forms of specimen_voucher qualifiers. If the text of the qualifier includes one or more colons it is a 'structured voucher'. Structured vouchers include institution-codes (and optional collection-codes) taken from a controlled vocabulary maintained by the INSDC that denotes the museum or herbarium collection where the specimen resides, please visit: http://www.insdc.org/controlled-vocabulary-specimenvoucher-qualifier.} ],
        [ 'temp', 'yellow', 6, 'temperature of the sample at time of sampling' ],
        [ 'treatment', 'yellow', 11, undef ],
        [ 'description', 'yellow', 13, 'Description of the sample.' ],
    );

    # --- Custom attributes ----------------------------------------------
    # NCBI rejects a sheet where two rows are identical once sample_name,
    # sample_title and description are ignored. Add the sample's layout
    # (only columns that have data), then check whether rows are unique.
    my @custom_columns = (
        [ 'replicate',   'custom', 10, 'Breedbase: replicate of the sampled plot/plant' ],
        [ 'block',       'custom', 8,  'Breedbase: block of the sampled plot/plant' ],
        [ 'plot_number', 'custom', 12, 'Breedbase: plot number (or well/position) of the tissue sample' ],
    );
    foreach my $custom (@custom_columns) {
        my $key = $custom->[0];
        push @all_columns, $custom if grep { defined $sample_data{$_}{$key} } @sample_order;
    }

    # Last resort: if rows are still not unique, add the Breedbase sample
    # name as a custom attribute (as NCBI's error message suggests).
    my %ignored_for_uniqueness = map { $_ => 1 } qw(*sample_name sample_title description);
    my %seen_rows;
    my $has_duplicates = 0;
    foreach my $stock_id (@sample_order) {
        my $row_key = join("\t", map {
            (my $k = $_->[0]) =~ s/^\*//;
            $ignored_for_uniqueness{ $_->[0] } ? () : ($sample_data{$stock_id}{$k} // '')
        } @all_columns);
        if ($seen_rows{$row_key}++) { $has_duplicates = 1; last; }
    }
    if ($has_duplicates) {
        $sample_data{$_}{breedbase_sample_name} = $sample_data{$_}{sample_name} for @sample_order;
        push @all_columns, [ 'breedbase_sample_name', 'custom', 30, 'Breedbase: tissue sample name, added so every row has a unique attribute' ];
    }

    my $workbook = Excel::Writer::XLSX->new($tempfile);
    my %font = (font => 'Arial Unicode MS', size => 10);

    my $text_fmt = $workbook->add_format(%font, num_format => '@');
    my %comment_row_fmt = (
        plain  => $workbook->add_format(%font),
        bold   => $workbook->add_format(%font, bold => 1),
        map { $_ => $workbook->add_format(%font, pattern => 1, bg_color => $fill{$_}) } qw(green blue yellow),
    );
    my %header_fmt = map {
        $_ => $workbook->add_format(
            %font,
            bold     => 1,
            color    => 'black',
            pattern  => 1,
            bg_color => $fill{$_},
            border   => 3,                    # dashed, as in the template
            align    => 'center_across',
        )
    } qw(green org age yellow);
    # Custom (non-template) attributes: same header style, no fill
    $header_fmt{custom} = $workbook->add_format(
        %font, bold => 1, color => 'black', border => 3, align => 'center_across',
    );

    my $ws = $workbook->add_worksheet('Plant.1.0');

    my @comments = (
        [ "# This is a submission template for batch deposit of 'Plant; version 1.0' samples to the NCBI BioSample database (https://www.ncbi.nlm.nih.gov/biosample/).", 'plain' ],
        [ "# GREEN fields are mandatory. Your submission will fail if any mandatory fields are not completed. If information is unavailable for any mandatory field, please enter 'not collected',  'not applicable' or 'missing' as appropriate.", 'green' ],
        [ "# BLUE  fields indicate that at least one of those fields is mandatory. If information is unavailable, please enter 'not collected',  'not applicable' or 'missing' as appropriate.", 'blue' ],
        [ "# YELLOW fields are optional. Leave optional fields empty (or delete them) if no information is available.", 'yellow' ],
        [ "# You can add any number of custom fields to fully describe your BioSamples, simply include them in the table.", 'plain' ],
        [ "# Hover over field name to view definition, or see https://www.ncbi.nlm.nih.gov/biosample/docs/attributes/.", 'plain' ],
        [ "# CAUTION: Be aware that Excel may automatically apply formatting to your data. In particular, take care with dates, incrementing autofills and special characters like / or -. Doublecheck that your text file is accurate before uploading to BioSample.", 'plain' ],
        [ "# TO MAKE A SUBMISSION: ", 'bold' ],
        [ "# 1. Complete this template table.", 'plain' ],
        [ "# 2. Upload the file on the 'Attributes' tab of the BioSample Submission Portal at https://submit.ncbi.nlm.nih.gov/subs/biosample/. ", 'plain' ],
        [ "# If you have any questions, please contact us at biosamplehelp\@ncbi.nlm.nih.gov.", 'plain' ],
        [ "# ", 'plain' ],
    );

    my $row_cursor = 0;
    foreach my $comment (@comments) {
        $ws->write_string($row_cursor++, 0, $comment->[0], $comment_row_fmt{ $comment->[1] });
    }

    # Header row (row 13) with hover definitions
    my $header_row = $row_cursor;
    for my $col_idx (0 .. $#all_columns) {
        my ($name, $fill_key, $width, $note) = @{ $all_columns[$col_idx] };
        $ws->write_string($header_row, $col_idx, $name, $header_fmt{$fill_key});
        $ws->write_comment($header_row, $col_idx, $note, author => 'NCBI', x_scale => 2, y_scale => 2) if defined $note;
        $ws->set_column($col_idx, $col_idx, $width) if defined $width;
    }
    $row_cursor++;

    # 'sex' dropdown, as in the template
    my ($sex_col) = grep { $all_columns[$_][0] eq 'sex' } 0 .. $#all_columns;
    $ws->data_validation($row_cursor, $sex_col, 1_048_575, $sex_col, {
        validate      => 'list',
        source        => [ 'male', 'female', 'pooled male and female', 'neuter', 'hermaphrodite', 'intersex', 'not determined', 'missing', 'not applicable', 'not collected', 'not provided', 'restricted access' ],
        error_message => 'Wrong value, try again.',
    });

    # Data rows: written as text so Excel does not reformat dates/IDs
    foreach my $stock_id (@sample_order) {
        my $s = $sample_data{$stock_id};
        for my $col_idx (0 .. $#all_columns) {
            (my $key = $all_columns[$col_idx][0]) =~ s/^\*//;
            my $value = $s->{$key};
            $ws->write_string($row_cursor, $col_idx, $value, $text_fmt) if defined $value && $value ne '';
        }
        $row_cursor++;
    }

    $workbook->close();

    return scalar(@sample_order);
}

=head2 write_sra_metadata_tsv($filepath)

Writes the NCBI SRA metadata table as tab-separated text (UTF-8), the format
the SRA Submission Portal's 'SRA Metadata' step accepts: a header row with
NCBI's column names, then one row per tissue sample (one EXPERIMENT per sample).

Library fields come from the transcriptomics protocol the sample has data in
(nd_protocolprop 'high_dimensional_phenotype_protocol_properties'). Values that
are not NCBI terms are left empty and reported as warnings. Breedbase does not
store raw read files, so filetype and filename columns are left for the user.

Returns an arrayref of warnings. Dies if there are no tissue samples.

=cut

# Column order of NCBI's SRA metadata template (SRA_data sheet)
my @SRA_COLUMNS = qw(sample_name library_ID title library_strategy library_source library_selection
    library_layout platform instrument_model design_description filetype filename filename2 filename3
    filename4 assembly fasta_file);

sub write_sra_metadata_tsv {
    my $self     = shift;
    my $filepath = shift;

    my ($sample_data, $sample_order) = $self->_sample_data();
    die "No tissue samples found to export.\n" unless @$sample_order;
    my ($rows, $warnings) = $self->_sra_metadata_rows();

    open(my $fh, '>:encoding(UTF-8)', $filepath) or die "Cannot write $filepath: $!\n";
    print $fh join("\t", @SRA_COLUMNS), "\n";
    foreach my $row (@$rows) {
        # Tabs or line breaks inside a value would break the table
        print $fh join("\t", map { my $v = $row->{$_} // ''; $v =~ s/[\t\r\n]+/ /g; $v } @SRA_COLUMNS), "\n";
    }
    close($fh) or die "Cannot write $filepath: $!\n";

    return $warnings;
}

=head2 write_submission_package($zip_path)

Writes a zip with everything for an SRA submission:
  biosample_attributes.xlsx   BioSample Plant.1.0 sheet (write_xlsx)
  sra_metadata.tsv            SRA metadata table (write_sra_metadata_tsv)
  README.txt                  what to upload where, and what still needs filling in

Returns { sample_count => N, warnings => [ ... ] }.

=cut

sub write_submission_package {
    my $self     = shift;
    my $zip_path = shift;

    my $dir = tempdir(CLEANUP => 1);
    my $sample_count = $self->write_xlsx("$dir/biosample_attributes.xlsx");
    my $warnings     = $self->write_sra_metadata_tsv("$dir/sra_metadata.tsv");

    my $readme = join("\n",
        "NCBI SRA submission files exported from Breedbase ($sample_count tissue samples)",
        "",
        "1. biosample_attributes.xlsx",
        "   Upload on the 'Attributes' tab of the BioSample submission",
        "   (https://submit.ncbi.nlm.nih.gov/subs/biosample/), or as the sample attributes",
        "   step of the SRA submission wizard.",
        "",
        "2. sra_metadata.tsv",
        "   Upload on the 'SRA Metadata' step of the SRA submission",
        "   (https://submit.ncbi.nlm.nih.gov/subs/sra/). Each row is one experiment;",
        "   sample_name matches biosample_attributes.xlsx.",
        "",
        "Still to fill in before uploading:",
        map({ "  - $_" } @$warnings),
        "",
    );

    my $zip = Archive::Zip->new();
    $zip->addFile("$dir/biosample_attributes.xlsx", 'biosample_attributes.xlsx');
    $zip->addFile("$dir/sra_metadata.tsv", 'sra_metadata.tsv');
    $zip->addString(encode('UTF-8', $readme), 'README.txt');
    $zip->writeToFileNamed($zip_path) == AZ_OK or die "Cannot write $zip_path\n";

    return { sample_count => $sample_count, warnings => $warnings };
}

# One SRA metadata row per sample. Returns (\@rows, \@warnings).
sub _sra_metadata_rows {
    my $self = shift;
    my ($sample_data, $sample_order) = $self->_sample_data();
    my $protocols = $self->_transcriptomics_protocols($sample_order);

    my (@rows, @warnings, %library_cache, $samples_without_protocol);
    foreach my $stock_id (@$sample_order) {
        my $s        = $sample_data->{$stock_id};
        my $protocol = $protocols->{$stock_id};

        my $library = {};
        if ($protocol) {
            $library_cache{ $protocol->{nd_protocol_id} } //= do {
                my ($fields, $protocol_warnings) = _sra_library_fields($protocol);
                push @warnings, @$protocol_warnings;
                $fields;
            };
            $library = $library_cache{ $protocol->{nd_protocol_id} };
        } else {
            $samples_without_protocol++;
        }

        # e.g. "RNA-Seq of Zea mays: seed, P14"
        my @described = grep { defined && $_ ne '' && $_ ne 'missing' } ($s->{tissue}, $s->{cultivar});
        my $title = join(': ', grep { defined } ($s->{organism} ne 'missing' ? $s->{organism} : undef),
            (@described ? join(', ', @described) : undef));
        $title = "$library->{library_strategy} of $title" if $library->{library_strategy} && $title;

        push @rows, {
            %$library,
            sample_name => $s->{sample_name},     # must match the BioSample sheet
            library_ID  => $s->{sample_name},     # one library per sample, so unique
            title       => $title,
        };
    }

    push @warnings, "$samples_without_protocol sample(s) have no transcriptomics protocol, so their library and platform columns are empty."
        if $samples_without_protocol;
    push @warnings, "filetype and filename columns: Breedbase does not store raw read files. Enter the file type (e.g. fastq) and exact file names for each library; paired files go on the same row.";

    return (\@rows, \@warnings);
}

# Transcriptomics protocol for each sample: { stock_id => { nd_protocol_id, name, description, props } }.
# When a sample is in several, nd_protocol_id (if set) wins, otherwise the lowest protocol id.
sub _transcriptomics_protocols {
    my $self      = shift;
    my $stock_ids = shift;
    return {} unless @$stock_ids;

    my $dbh = $self->bcs_schema->storage->dbh;

    # Which transcriptomics protocol(s) each sample has data in
    my $placeholders = join(',', ('?') x scalar(@$stock_ids));
    # (Protocol type filtered in a subquery: joining nd_protocol/cvterm directly
    # lets the planner rescan nd_experiment_stock per protocol link, ~40s for 433 samples.)
    my $h = $dbh->prepare("
        SELECT DISTINCT nes.stock_id, nep.nd_protocol_id
        FROM nd_experiment_stock nes
        JOIN nd_experiment_protocol nep ON nep.nd_experiment_id = nes.nd_experiment_id
        WHERE nes.stock_id IN ($placeholders)
        AND nep.nd_protocol_id IN (
            SELECT np.nd_protocol_id
            FROM nd_protocol np
            JOIN cvterm pt ON pt.cvterm_id = np.type_id
            WHERE pt.name = 'high_dimensional_phenotype_transcriptomics_protocol')
        ORDER BY nep.nd_protocol_id;");
    $h->execute(@$stock_ids);

    my $preferred = $self->nd_protocol_id;
    my %stock_protocol;
    while (my ($stock_id, $protocol_id) = $h->fetchrow_array()) {
        next if $stock_protocol{$stock_id} && !($preferred && $protocol_id == $preferred);
        $stock_protocol{$stock_id} = $protocol_id;
    }

    # Each protocol's properties, once, without the (large) gene/header lists
    my $props_h = $dbh->prepare("
        SELECT np.name, np.description,
               (npp.value::jsonb - 'header_column_names' - 'header_column_details')::text
        FROM nd_protocol np
        LEFT JOIN (
            nd_protocolprop npp
            JOIN cvterm ppt ON ppt.cvterm_id = npp.type_id
                           AND ppt.name = 'high_dimensional_phenotype_protocol_properties'
        ) ON npp.nd_protocol_id = np.nd_protocol_id
        WHERE np.nd_protocol_id = ?;");
    my %protocol_info;
    foreach my $protocol_id (keys %{{ map { $_ => 1 } values %stock_protocol }}) {
        $props_h->execute($protocol_id);
        my ($name, $description, $props_json) = $props_h->fetchrow_array();
        $protocol_info{$protocol_id} = {
            nd_protocol_id => $protocol_id,
            name           => $name,
            description    => $description,
            props          => (eval { decode_json($props_json // '{}') } || {}),
        };
    }

    return { map { $_ => $protocol_info{ $stock_protocol{$_} } } keys %stock_protocol };
}

# Maps a transcriptomics protocol onto SRA library columns. Returns (\%fields, \@warnings).
sub _sra_library_fields {
    my $protocol = shift;
    my $p        = $protocol->{props};
    my $name     = $protocol->{name};
    my @warnings;

    my %fields = (
        library_strategy => 'RNA-Seq',
        library_source   => 'TRANSCRIPTOMIC',
    );

    # Instrument model and platform, matched to NCBI terms ("NextSeq 500" -> ILLUMINA / "NextSeq 500")
    my $model = _clean($p->{instrument_model});
    my ($platform, $instrument) = _match_instrument($model);
    if ($instrument) {
        $fields{platform}         = $platform;
        $fields{instrument_model} = $instrument;
    } else {
        push @warnings, $model
            ? "Protocol '$name': instrument model '$model' is not an NCBI instrument_model term. Choose one in sra_metadata.tsv."
            : "Protocol '$name' has no instrument model. Choose platform and instrument_model in sra_metadata.tsv.";
        my $platform_text = _clean($p->{sequencing_platform});
        if ($platform_text) {
            (my $key = uc $platform_text) =~ s/[\s-]+/_/g;
            $key = { PACBIO => 'PACBIO_SMRT', '454' => '_LS454', LS454 => '_LS454', NANOPORE => 'OXFORD_NANOPORE' }->{$key} // $key;
            $fields{platform} = $key if $SRA_INSTRUMENTS{$key};
        }
    }

    # Layout: 'layout' property, or a "/single" or "/paired" suffix in read_length (e.g. "86/single")
    foreach my $text (_clean($p->{layout}), _clean($p->{read_length})) {
        next unless $text;
        if    ($text =~ /paired/i) { $fields{library_layout} = 'paired'; last }
        elsif ($text =~ /single/i) { $fields{library_layout} = 'single'; last }
    }
    push @warnings, "Protocol '$name' has no library layout (single or paired). Choose one in sra_metadata.tsv."
        unless $fields{library_layout};

    # Library selection: library_method if it is an NCBI term ("poly(A)" -> PolyA)
    my $method = _clean($p->{library_method});
    my ($selection) = $method ? grep { _vocab_key($_) eq _vocab_key($method) } @SRA_SELECTIONS : ();
    if ($selection) {
        $fields{library_selection} = $selection;
    } else {
        push @warnings, $method
            ? "Protocol '$name': library method '$method' is not an NCBI library_selection term (e.g. PolyA, cDNA, Inverse rRNA). Choose one in sra_metadata.tsv."
            : "Protocol '$name' has no library method. Choose library_selection (e.g. PolyA, cDNA) in sra_metadata.tsv.";
    }

    # Free-text methods description from whatever the protocol records
    my @design = grep { defined } (
        _clean($protocol->{description}),
        map { my ($label, $key) = @$_; my $v = _clean($p->{$key}); defined $v ? "$label: $v" : undef } (
            [ 'Library method',          'library_method' ],
            [ 'Nucleic acid extraction', 'nucleic_acid_extraction_method' ],
            [ 'Read length',             'read_length' ],
            [ 'Library comments',        'library_comments' ],
            [ 'Sequencing center',       'sequencing_center' ],
            [ 'Reference genome',        'genome_version' ],
            [ 'Annotation',              'annotation_version' ],
        ),
    );
    $fields{design_description} = join('; ', @design) if @design;

    return (\%fields, \@warnings);
}

sub _match_instrument {
    my $model = shift;
    return () unless $model;
    my $key = _vocab_key($model);
    foreach my $platform (sort keys %SRA_INSTRUMENTS) {
        foreach my $instrument (@{ $SRA_INSTRUMENTS{$platform} }) {
            return ($platform, $instrument) if _vocab_key($instrument) eq $key;
        }
    }
    return ();
}

# Comparison key for vocabulary terms: case, punctuation and an "Illumina" prefix ignored
sub _vocab_key {
    my $v = lc shift;
    $v =~ s/^illumina\s+//;
    $v =~ s/[^a-z0-9+]//g;
    return $v;
}

# Trimmed value, or undef for empty/placeholder values ('', 'blank', 'NA', 'none', 'null')
sub _clean {
    my $v = shift;
    return undef unless defined $v;
    $v =~ s/^\s+|\s+$//g;
    return undef if $v eq '' || $v =~ m{^(?:blank|n/?a|none|null)$}i;
    return $v;
}

# Sample data is gathered once per object and shared by both sheets
has '_sample_data_cache' => ( is => 'ro', lazy => 1, init_arg => undef,
    default => sub { [ $_[0]->_collect_sample_data() ] } );
sub _sample_data { @{ $_[0]->_sample_data_cache } }

# Gathers the attribute values for each tissue sample.
# Returns (\%sample_data keyed by stock_id, \@sample_order sorted by name).
sub _collect_sample_data {
    my $self = shift;

    my @tissue_sample_ids = @{ $self->get_tissue_sample_ids() };
    return ({}, []) unless @tissue_sample_ids;

    my @trial_ids       = @{ $self->trial_ids };
    my $schema          = $self->bcs_schema;
    my $dbh             = $schema->storage->dbh;
    my $people_schema   = $self->people_schema;
    my $metadata_schema = $self->metadata_schema;
    my $phenome_schema  = $self->phenome_schema;

    my $placeholders = join(',', ('?') x scalar(@tissue_sample_ids));

    # --- 1. Retrieve sample_name and organism (species) -----------------
    my $organism_query = "
        SELECT s.stock_id, s.uniquename, o.species
        FROM stock s
        JOIN organism o USING (organism_id)
        JOIN cvterm stype ON s.type_id = stype.cvterm_id
        WHERE stype.name = 'tissue_sample'
        AND s.stock_id IN ($placeholders)
        ORDER BY s.uniquename ASC;";
    my $org_sth = $dbh->prepare($organism_query);
    $org_sth->execute(@tissue_sample_ids);

    my %sample_data;
    my @sample_order; # preserve sort order for output
    while (my ($stock_id, $uniquename, $species) = $org_sth->fetchrow_array()) {
        $sample_data{$stock_id} = {
            sample_name => $uniquename,
            organism    => $species // 'missing',
        };
        push @sample_order, $stock_id;
    }

    # --- 2. Retrieve geo_loc_name via trial location --------------------
    # Format: "Country: Location Name" per NCBI convention
    # Uses CXGN::Trial->get_location() and get_location_country_name()
    # matching the pattern: $location_data->[1] and $trial->get_location_country_name()
    #
    # First, map tissue samples -> trials via nd_experiment_stock + project
    my $trial_stock_query = "
        SELECT DISTINCT s.stock_id, proj.project_id
        FROM stock s
        JOIN nd_experiment_stock ndes ON s.stock_id = ndes.stock_id
        JOIN nd_experiment nd         ON ndes.nd_experiment_id = nd.nd_experiment_id
        JOIN nd_experiment_project ndep ON nd.nd_experiment_id = ndep.nd_experiment_id
        JOIN project proj             ON ndep.project_id = proj.project_id
        JOIN cvterm stype             ON s.type_id = stype.cvterm_id
        WHERE stype.name = 'tissue_sample'
        AND s.stock_id IN ($placeholders);";
    my $trial_stock_sth = $dbh->prepare($trial_stock_query);
    $trial_stock_sth->execute(@tissue_sample_ids);

    # For each tissue sample, get the trial and pull location via CXGN::Trial
    # Prefer a trial the user selected; otherwise take the first one found
    my %selected_trial = map { $_ => 1 } @trial_ids;
    my %stock_to_trial;
    while (my ($stock_id, $project_id) = $trial_stock_sth->fetchrow_array()) {
        if ($selected_trial{$project_id}) {
            $stock_to_trial{$stock_id} = $project_id;
        } else {
            $stock_to_trial{$stock_id} //= $project_id;
        }
    }

    # Cache trial location lookups so we don't re-query the same trial repeatedly
    my %trial_geo_cache;
    foreach my $stock_id (@sample_order) {
        my $project_id = $stock_to_trial{$stock_id};
        next unless $project_id;

        unless (exists $trial_geo_cache{$project_id}) {
            my $trial = CXGN::Trial->new({
                bcs_schema      => $schema,
                people_schema   => $people_schema,
                metadata_schema => $metadata_schema,
                phenome_schema  => $phenome_schema,
                trial_id        => $project_id,
            });

            my $location_data = $trial->get_location();
            my $location_name = $location_data->[1] // '';
            my $country_name  = $trial->get_location_country_name() // '';

            # Format as "Country: Location Name" per NCBI geo_loc_name convention
            my $geo_loc_name;
            if ($country_name && $location_name) {
                $geo_loc_name = "$country_name: $location_name";
            } elsif ($country_name) {
                $geo_loc_name = $country_name;
            } elsif ($location_name) {
                $geo_loc_name = $location_name;
            } else {
                $geo_loc_name = 'missing';
            }

            $trial_geo_cache{$project_id} = $geo_loc_name;
        }

        $sample_data{$stock_id}{geo_loc_name} = $trial_geo_cache{$project_id};
    }

    # --- 3. Retrieve tissue (tissue_type stockprop) ----------------------------
    my $tissue_query = "
        SELECT s.stock_id, sp.value AS tissue
        FROM stock s
        JOIN stockprop sp ON s.stock_id = sp.stock_id
        JOIN cvterm spt   ON sp.type_id = spt.cvterm_id
        JOIN cvterm stype ON s.type_id  = stype.cvterm_id
        WHERE stype.name = 'tissue_sample'
        AND spt.name     = 'tissue_type'
        AND s.stock_id IN ($placeholders);";
    my $tissue_sth = $dbh->prepare($tissue_query);
    $tissue_sth->execute(@tissue_sample_ids);

    while (my ($stock_id, $tissue) = $tissue_sth->fetchrow_array()) {
        if (exists $sample_data{$stock_id}) {
            $sample_data{$stock_id}{tissue} = $tissue // 'missing';
        }
    }

    # --- 4. Source material: accession (cultivar) and plant/plot (isolate) ---
    # tissue_sample --tissue_sample_of--> accession | plant | plot | subplot
    # plant/plot/subplot --plant_of/plot_of/subplot_of--> accession
    my $source_query = "
        SELECT ts.stock_id, src.uniquename, srct.name, acc.uniquename
        FROM stock ts
        JOIN stock_relationship sr ON sr.subject_id = ts.stock_id
        JOIN cvterm srt            ON sr.type_id = srt.cvterm_id AND srt.name = 'tissue_sample_of'
        JOIN stock src             ON sr.object_id = src.stock_id
        JOIN cvterm srct           ON src.type_id = srct.cvterm_id
        LEFT JOIN (
            stock_relationship sr2
            JOIN cvterm r2   ON sr2.type_id = r2.cvterm_id AND r2.name IN ('plant_of', 'plot_of', 'subplot_of')
            JOIN stock acc   ON sr2.object_id = acc.stock_id
            JOIN cvterm acct ON acc.type_id = acct.cvterm_id AND acct.name IN ('accession', 'cross')
        ) ON sr2.subject_id = src.stock_id
        WHERE srct.name IN ('accession', 'cross', 'plant', 'plot', 'subplot')
        AND ts.stock_id IN ($placeholders);";
    my $source_sth = $dbh->prepare($source_query);
    $source_sth->execute(@tissue_sample_ids);

    while (my ($stock_id, $source_name, $source_type, $accession_name) = $source_sth->fetchrow_array()) {
        next unless exists $sample_data{$stock_id};
        if ($source_type eq 'accession' || $source_type eq 'cross') {
            $sample_data{$stock_id}{cultivar} //= $source_name;
        } else {
            $sample_data{$stock_id}{isolate}  //= $source_name;   # the individual plant/plot sampled
            $sample_data{$stock_id}{cultivar} //= $accession_name if defined $accession_name;
        }
    }

    # --- 5. Layout and acquisition date (stockprops on the tissue sample) ---
    my %prop_to_key = (
        'replicate'        => 'replicate',
        'block'            => 'block',
        'plot number'      => 'plot_number',
        'acquisition date' => 'acquisition_date',
    );
    my $prop_placeholders = join(',', ('?') x scalar(keys %prop_to_key));
    my $props_query = "
        SELECT sp.stock_id, spt.name, sp.value
        FROM stockprop sp
        JOIN cvterm spt ON sp.type_id = spt.cvterm_id
        WHERE spt.name IN ($prop_placeholders)
        AND sp.stock_id IN ($placeholders);";
    my $props_sth = $dbh->prepare($props_query);
    $props_sth->execute(keys %prop_to_key, @tissue_sample_ids);

    while (my ($stock_id, $prop_name, $value) = $props_sth->fetchrow_array()) {
        next unless exists $sample_data{$stock_id} && defined $value && $value ne '';
        $sample_data{$stock_id}{ $prop_to_key{$prop_name} } //= $value;
    }

    # The sample's acquisition date is the collection date. (The nd_experiment
    # date on tissue samples is the upload date, so it is not used here.)
    foreach my $stock_id (keys %sample_data) {
        my $date = delete $sample_data{$stock_id}{acquisition_date};
        next unless defined $date;
        if ($date =~ /^(\d{4}-\d{2}-\d{2})/) {                      # 2019-09-09[...]
            $date = $1;
        } elsif ($date =~ m{^(\d{1,2})/(\d{1,2})/(\d{4})$}) {       # 9/9/2019 (US month/day)
            $date = sprintf('%04d-%02d-%02d', $3, $1, $2);
        }
        $sample_data{$stock_id}{collection_date} = $date;
    }

    # --- Fill in any missing required fields with 'missing' -------------
    foreach my $stock_id (keys %sample_data) {
        for my $col (qw(organism collection_date geo_loc_name tissue)) {
            $sample_data{$stock_id}{$col} //= 'missing';
        }
        # BLUE groups: at least one attribute of each group is required
        my $s = $sample_data{$stock_id};
        $s->{isolate}   = 'missing' unless grep { defined $s->{$_} } qw(isolate cultivar ecotype);   # Organism group
        $s->{dev_stage} = 'missing' unless grep { defined $s->{$_} } qw(age dev_stage);              # Age/stage group
    }

    return (\%sample_data, \@sample_order);
}

1;
