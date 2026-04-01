
=head1 NAME

SGN::Controller::AJAX::Search::GenotypingDataProject - a REST controller class to provide genotyping data project

=head1 DESCRIPTION


=head1 AUTHOR

=cut

package SGN::Controller::AJAX::Search::GenotypingDataProject;

use Moose;
use Data::Dumper;
use JSON;
use File::Slurp qw | read_file |;
use File::Basename;
use CXGN::People::Login;
use CXGN::Trial::Search;
use CXGN::Genotype::GenotypingProject;
use CXGN::Genotype::Protocol;
use CXGN::Trial;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

sub genotyping_data_project_search : Path('/ajax/genotyping_data_project/search') : ActionClass('REST') { }

sub genotyping_data_project_search_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $trial_search = CXGN::Trial::Search->new({
        bcs_schema=>$bcs_schema,
        trial_design_list=>['genotype_data_project', 'pcr_genotype_data_project']
    });
    my ($data, $total_count) = $trial_search->search();
    my @result;
    foreach (@$data){
        my $genotyping_project_id = $_->{trial_id};

        my $plate_info = CXGN::Genotype::GenotypingProject->new({
            bcs_schema => $bcs_schema,
            project_id => $genotyping_project_id
        });
        my ($plate_data, $number_of_plates) = $plate_info->get_plate_info();
        my $total_accession_count = 0;
        if ($plate_data) {
            foreach (@$plate_data) {
                my $trial_id = $_->{plate_id};
                my $trial = CXGN::Trial->new( { bcs_schema => $bcs_schema, trial_id => $trial_id });
                my $accession_count = $trial->get_trial_stock_count();
                $total_accession_count += $accession_count;
            }
        }

        my $folder_string = '';
        if ($_->{folder_name}){
            $folder_string = "<a href=\"/folder/$_->{folder_id}\">$_->{folder_name}</a>";
        }
        my $design = $_->{design};
        my $data_type;
        if ($design eq 'pcr_genotype_data_project') {
            $data_type = 'SSR';
        } else {
            $data_type = 'SNP';
        }
#        print STDERR "DESIGN =".Dumper($design)."\n";
        push @result,
          [
            "<a href=\"/breeders_toolbox/trial/$_->{trial_id}\">$_->{trial_name}</a>",
            $data_type,
            $_->{description},
            "<a href=\"/breeders/program/$_->{breeding_program_id}\">$_->{breeding_program_name}</a>",
            $folder_string,
            $_->{year},
            $_->{location_name},
            $_->{genotyping_facility},
            $number_of_plates,
            $total_accession_count
          ];
    }
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}


sub genotyping_project_plates : Path('/ajax/genotyping_project/genotyping_plates') : ActionClass('REST') { }

sub genotyping_project_plates_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $genotyping_project_id = $c->req->param('genotyping_project_id');

    my $plate_info = CXGN::Genotype::GenotypingProject->new({
        bcs_schema => $bcs_schema,
        project_id => $genotyping_project_id
    });
    my ($data, $total_count) = $plate_info->get_plate_info();
    my @result;
    foreach my $plate(@$data){
        push @result,
        [
            "<a href=\"/breeders_toolbox/trial/$plate->{plate_id}\">$plate->{plate_name}</a>",
            $plate->{plate_description},
            $plate->{plate_format},
            $plate->{sample_type},
            $plate->{number_of_samples},
            "<a class='btn btn-sm btn-default' href='/breeders/trial/$plate->{plate_id}/download/layout?format=csv&dataLevel=plate'>Download Layout</a>"
        ];
    }

    $c->stash->{rest} = { data => \@result };

}


sub genotyping_project_plate_names : Path('/ajax/genotyping_project/plate_names') : ActionClass('REST') { }

sub genotyping_project_plate_names_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $genotyping_project_id = $c->req->param('genotyping_project_id');

    my $plate_info = CXGN::Genotype::GenotypingProject->new({
        bcs_schema => $bcs_schema,
        project_id => $genotyping_project_id
    });
    my ($data, $total_count) = $plate_info->get_plate_info();

    $c->stash->{rest} = { data => $data };

}


sub genotyping_project_protocols : Path('/ajax/genotyping_project/protocols') : ActionClass('REST') { }

sub genotyping_project_protocols_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $genotyping_project_id = $c->req->param('genotyping_project_id');

    my $protocol_info = CXGN::Genotype::GenotypingProject->new({
        bcs_schema => $bcs_schema,
        project_id => $genotyping_project_id
    });
    my $associated_protocol  = $protocol_info->get_associated_protocol();
#    print STDERR "ASSOCIATED PROTOCOL =".Dumper($associated_protocol)."\n";
    my @info;
    if ( defined $associated_protocol && scalar(@$associated_protocol)>1) {
        $c->stash->{rest} = { error => "Each genotyping project should be associated with only one protocol" };
        return;
    } elsif (defined $associated_protocol && scalar(@$associated_protocol) == 1) {
        push @info, {
            protocol_id => $associated_protocol->[0]->[0],
            protocol_name => $associated_protocol->[0]->[1]
        }
    }

    $c->stash->{rest} = { data => \@info };

}


sub genotyping_project_has_archived_vcf : Path('/ajax/genotyping_project/has_archived_vcf') : ActionClass('REST') { }

sub genotyping_project_has_archived_vcf_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my @project_ids = split(',', $c->req->param('genotyping_project_id'));
    my @protocol_ids = split(',', $c->req->param('genotyping_protocol_id'));
    my $limit = defined $c->req->param('limit');
    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    # Get projects that match the provided protocol(s)
    if ( scalar(@protocol_ids) > 0 ) {
        my $ph = join ( ',', ('?') x @protocol_ids );
        my $q = "SELECT genotyping_project_id FROM genotyping_projectsxgenotyping_protocols WHERE genotyping_project_id IS NOT NULL AND genotyping_protocol_id IN ($ph);";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute(@protocol_ids);
        while (my ($project_id) = $h->fetchrow_array()) {
            push(@project_ids, $project_id);
        }
    }

    # Initiate the return hash (key = project id, value = array of vcf file data)
    my %rtn;
    foreach my $project_id (@project_ids) {
        $rtn{$project_id} = [];
    }

    # Make sure there is at least 1 matching project
    if ( scalar(@project_ids) < 1 ) {
        $c->stash->{rest} = { error => "No genotyping projects selected!" };
        return;
    }

    # Get metadata about the archived vcf files for all of the requested projects 
    my $ph = join ( ',', ('?') x @project_ids );
    my $q = "SELECT genotyping_protocol_id, genotyping_protocol_name, genotyping_project_id, genotyping_project_name,
                dirname, basename, create_date, uploader_id, uploader_name, uploader_username
            FROM (
                SELECT genotyping_protocols.genotyping_protocol_id, genotyping_protocols.genotyping_protocol_name, 
                    genotyping_projects.genotyping_project_id, genotyping_projects.genotyping_project_name,
                    md_files.dirname, md_files.basename, md_metadata.create_date,
                    sp_person.sp_person_id AS uploader_id,
                    CONCAT(sp_person.first_name, ' ', sp_person.last_name) AS uploader_name,
                    sp_person.username AS uploader_username
                FROM public.nd_experiment_project
                LEFT JOIN phenome.nd_experiment_md_files ON (nd_experiment_project.nd_experiment_id = nd_experiment_md_files.nd_experiment_id)
                LEFT JOIN metadata.md_files ON (nd_experiment_md_files.file_id = md_files.file_id)
                LEFT JOIN metadata.md_metadata ON (md_files.metadata_id = md_metadata.metadata_id)
                LEFT JOIN sgn_people.sp_person ON (md_metadata.create_person_id = sp_person.sp_person_id)
                LEFT JOIN public.genotyping_projects ON (nd_experiment_project.project_id = genotyping_projects.genotyping_project_id)
                LEFT JOIN public.genotyping_projectsxgenotyping_protocols ON (genotyping_projects.genotyping_project_id = genotyping_projectsxgenotyping_protocols.genotyping_project_id)
                LEFT JOIN public.genotyping_protocols ON (genotyping_projectsxgenotyping_protocols.genotyping_protocol_id = genotyping_protocols.genotyping_protocol_id)
                WHERE nd_experiment_project.project_id IN ($ph)
                GROUP BY genotyping_projects.genotyping_project_id, genotyping_project_name, 
                    genotyping_protocols.genotyping_protocol_id, genotyping_protocol_name, 
                    dirname, basename, create_date, sp_person_id, first_name, last_name, username
            ) AS t
            WHERE t.create_date IS NOT NULL
            ORDER BY t.genotyping_protocol_name, t.genotyping_project_name, t.create_date DESC";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute(@project_ids);

    # Parse the results for all of the archived files
    my %seen_projects;
    while (my ($geno_proto_id, $geno_proto_name, $geno_proj_id, $geno_proj_name, $dirname, $basename, $create_date, $uploader_id, $uploader_name, $uploader_username) = $h->fetchrow_array()) {
        
        # When limit is defined (to only return the most recent file for each project),
        # skip processing the file if one was already found (newer files are processed first since the query is sorted by date DESC)
        # This should really be implemented in the query, but not sure of the best way to do that - maybe a lateral join?
        if ( $limit && exists($seen_projects{$geno_proj_id}) ) {
            next;
        }
        $seen_projects{$geno_proj_id} = 1;

        # Check if the file actually exists
        my $exists = "false";
        if ( defined $dirname && defined $basename && -s "$dirname/$basename" ) {
            $exists = "true";
        }

        # Set return properties
        my %props = (
            genotyping_protocol_id => $geno_proto_id,
            genotyping_protocol_name => $geno_proto_name,
            genotyping_project_id => $geno_proj_id,
            genotyping_project_name => $geno_proj_name,
            dirname => $dirname,
            basename => $basename,
            create_date => $create_date,
            uploader_id => $uploader_id,
            uploader_name => $uploader_name,
            uploader_username => $uploader_username,
            exists => $exists
        );

        # Add to existing project props
        push(@{$rtn{$geno_proj_id}}, \%props);

    }

    $c->stash->{rest} = \%rtn;
}


sub genotyping_project_download_archived_vcf : Path('/ajax/genotyping_project/download_archived_vcf') : ActionClass('REST') { }

sub genotyping_project_download_archived_vcf_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $project_id = $c->req->param('genotyping_project_id');
    my $requested_basename = $c->req->param('basename');
    my $schema = $c->dbic_schema('Bio::Chado::Schema');

    # Get the file information
    my $q = "SELECT md_files.dirname, md_files.basename
            FROM public.nd_experiment_project
            LEFT JOIN phenome.nd_experiment_md_files ON (nd_experiment_project.nd_experiment_id = nd_experiment_md_files.nd_experiment_id)
            LEFT JOIN metadata.md_files ON (nd_experiment_md_files.file_id = md_files.file_id)
            WHERE nd_experiment_project.project_id = ? AND md_files.basename = ?
            GROUP BY dirname, basename;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($project_id, $requested_basename);
    my ($dirname, $basename) = $h->fetchrow_array();

    # Return the file, if it exists
    if ( defined $dirname && defined $basename && -s "$dirname/$basename" ) {
        my $filepath = "$dirname/$basename";

        # Check if the file is a vcf (.vcf extension of ##filformat=VCF header on first line)
        open my $FH, '<', $filepath;
        my $firstline = <$FH>;
        close $FH;
        my $is_a_vcf = rindex($firstline, "##fileformat=VCF", 0) == 0 || $filepath =~ m/\.vcf$/;

        # Transpose the VCF file (to a temp file)
        if ($is_a_vcf) {
            my $dir = $c->tempfiles_subdir('download');
            my ($Fout, $temp_file_transposed) = $c->tempfile(TEMPLATE=>"download/download_vcf_XXXXX", SUFFIX=>".vcf", UNLINK=>0);
            open (my $F, "< :encoding(UTF-8)", $filepath) or die "Can't open file $filepath \n";
            my @outline;
            my $lastcol;
            while (<$F>) {
                $_ =~ s/\r//g;
                if ($_ =~ m/^\##/) {
                    print $Fout $_;
                } else {
                    chomp;
                    my @line = split /\t/;
                    my $oldlastcol = $lastcol;
                    $lastcol = $#line if $#line > $lastcol;
                    for (my $i=$oldlastcol; $i < $lastcol; $i++) {
                        if ($oldlastcol) {
                            $outline[$i] = "\t" x $oldlastcol;
                        }
                    }
                    for (my $i=0; $i <=$lastcol; $i++) {
                        $outline[$i] .= "$line[$i]\t"
                    }
                }
            }
            for (my $i=0; $i <= $lastcol; $i++) {
                $outline[$i] =~ s/\s*$//g;
                print $Fout $outline[$i]."\n";
            }

            close($F);
            close($Fout);
            $filepath = $c->config->{basepath} . '/' . $temp_file_transposed;
            my ($name,$path,$suffix) = fileparse($basename,qr"\..[^.]*$");
            if ( $suffix ne '.vcf' ) {
                $basename = "$basename.vcf";
            }
        }

        my $contents = read_file($filepath);
        $c->res->content_type('text/plain');
        $c->res->header('Content-Disposition', qq[attachment; filename="$basename"]);
        $c->res->body($contents);
    }
}

sub genotyping_project_accession_search : Path('/ajax/genotyping_project/search/accession_list') : ActionClass('REST') { }

sub genotyping_project_accession_search_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $schema->storage->dbh();
    my $accession_list_id = $c->req->param('accession_list_id');
    my @accession_ids = split(/, ?/, $c->req->param('accession_ids') || '');

    # Results to return
    my $error;
    my $acc_counts_total;   # total number of accessions in the list
    my %gen_by_acc;         # genotyping projects found for each accession (key = accession id, value = array of genotyping project ids)
    my %acc_by_gen;         # accessions used in each genotyping project (key = genotyping project id, value = array of accession ids)
    my %gen_counts_by_acc;  # counts of genoyping projects found for each accession (key = accession id, value = count of matching genotyping projects)
    my %acc_counts_by_gen;  # counts of accessions in each genotyping project (key = genotyping project id, value = count of matching accessions)
    my @ranked_gen;         # sorted genotyping project ids, the first item is the geno proto id of the proto that has the most accessions
    my %lookup_acc;         # lookup hash of accession name by id (key = accession id, value = accession uniquename)
    my %lookup_gen;         # lookup hash of genotyping project name by id (key = geno proto id, value = geno proto name)

    # Make sure we have a list id or accessions ids
    if ( (!defined $accession_list_id || $accession_list_id eq "") && scalar @accession_ids == 0 ) {
        $error = "You must define the accession_list_id or accession_ids!";
    }

    # Get Accession IDs from specified List
    if ( defined $accession_list_id && $accession_list_id ne "" ) {

        # Get accession names in list
        my $list = CXGN::List->new({ dbh => $dbh, list_id => $accession_list_id });
        my $names = $list->elements();

        # Make sure there are list items
        if ( scalar(@$names) > 0 ) {

            # Transform accession names to accession ids
            my $t = CXGN::List::Transform->new();
            my $accession_t = $t->can_transform("accessions", "accession_ids");
            my $accession_id_hash = $t->transform($schema, $accession_t, $names);
            @accession_ids = @{$accession_id_hash->{transform}};

        }
        else {
            $error = "List does not contain any list items!";
        }

    }

    # Check if we have any accessions
    $acc_counts_total = scalar @accession_ids;
    if ( $acc_counts_total > 0 ) {

        # Find Genotyping Projects for the selected Accessions
        my $ph = join(',', ('?') x @accession_ids);
        my $q = "SELECT accession_id, ARRAY_AGG(genotyping_project_id)
                FROM accessionsxgenotyping_projects
                WHERE accession_id IN ($ph)
                GROUP BY accession_id;";
        my $h = $dbh->prepare($q);
        $h->execute(@accession_ids);

        # Summarize query results
        while (my ($acc_id, $gen_ids) = $h->fetchrow_array()) {
            $gen_by_acc{$acc_id} = $gen_ids;
            foreach my $gen_id ( @$gen_ids ) {
                push @{$acc_by_gen{$gen_id}}, $acc_id;
            }
        }
        foreach my $acc_id (keys %gen_by_acc) {
            $gen_counts_by_acc{$acc_id} = scalar @{$gen_by_acc{$acc_id}};
        }
        foreach my $gen_id (keys %acc_by_gen) {
            $acc_counts_by_gen{$gen_id} = scalar @{$acc_by_gen{$gen_id}};
        }
        @ranked_gen = sort { $acc_counts_by_gen{$b} <=> $acc_counts_by_gen{$a} } keys(%acc_counts_by_gen);

        # Generate lookup of accession ids -> accession names
        $ph = join(',', ('?') x @accession_ids);
        $q = "SELECT stock_id, uniquename FROM stock WHERE stock_id IN ($ph)";
        $h = $dbh->prepare($q);
        $h->execute(@accession_ids);
        while (my ($acc_id, $acc_name) = $h->fetchrow_array()) {
            $lookup_acc{$acc_id} = $acc_name;
        }

        # Generate lookup of genotyping project ids -> genotyping project names
        my @gen_ids = keys %acc_by_gen;
        if ( scalar @gen_ids > 0 ) {
            $ph = join(',', ('?') x @gen_ids);
            $q = "SELECT project_id, name FROM project WHERE project_id IN ($ph)";
            $h = $dbh->prepare($q);
            $h->execute(@gen_ids);
            while (my ($gen_id, $gen_name) = $h->fetchrow_array()) {
                $lookup_gen{$gen_id} = $gen_name;
            }
        }
    }

    $c->stash->{rest} = {
        error => $error,
        results => {
            matches => {
                genotyping_projects_by_accession => \%gen_by_acc,
                accessions_by_genotyping_project => \%acc_by_gen
            },
            counts => {
                accessions_total => $acc_counts_total,
                genotyping_projects_by_accession => \%gen_counts_by_acc,
                accessions_by_genotyping_project => \%acc_counts_by_gen,
                ranked_genotyping_projects => \@ranked_gen
            },
            lookups => {
                accessions => \%lookup_acc,
                genotyping_projects => \%lookup_gen
            }
        }
    }
}

1;
