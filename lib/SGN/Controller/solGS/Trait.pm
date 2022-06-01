package SGN::Controller::solGS::Trait;

use Moose;
use namespace::autoclean;

use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Array::Utils qw(:all);
use JSON;
use SGN::Controller::solGS::Utils;


BEGIN { extends 'Catalyst::Controller' }


sub solgs_details_trait :Path('/solgs/details/trait/') Args(1) {
    my ($self, $c, $trait_id) = @_;

    $trait_id = $c->req->param('trait_id') if !$trait_id;

    my $ret->{status} = undef;

    if ($trait_id)
    {
	$self->get_trait_details($c, $trait_id);
	$ret->{name}    = $c->stash->{trait_name};
	$ret->{def}     = $c->stash->{trait_def};
	$ret->{abbr}    = $c->stash->{trait_abbr};
	$ret->{id}      = $c->stash->{trait_id};
	$ret->{status}  = 1;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub get_trait_details {
    my ($self, $c, $trait) = @_;

    $trait = $c->stash->{trait_id} if !$trait;

    die "Can't get trait details with out trait id or name: $!\n" if !$trait;

    my ($trait_name, $trait_def, $trait_id, $trait_abbr);

    my $model = $c->controller('solGS::Search')->model($c);

    if ($trait =~ /^\d+$/)
    {
	$trait = $model->trait_name($trait);
    }

    if ($trait)
    {
	my $rs = $model->trait_details($trait);

	while (my $row = $rs->next)
	{
	    $trait_id   = $row->id;
	    $trait_name = $row->name;
	    $trait_def  = $row->definition;
	    $trait_abbr = $c->controller('solGS::Utils')->abbreviate_term($trait_name);
	}
    }

    my $abbr = $c->controller('solGS::Utils')->abbreviate_term($trait_name);

    $c->stash->{trait_id}   = $trait_id;
    $c->stash->{trait_name} = $trait_name;
    $c->stash->{trait_def}  = $trait_def;
    $c->stash->{trait_abbr} = $abbr;

}


sub get_trait_details_of_trait_abbr {
    my ($self, $c) = @_;

    my $trait_abbr = $c->stash->{trait_abbr};

    my $acronym_pairs = $self->get_acronym_pairs($c, $c->stash->{training_pop_id});

    if ($acronym_pairs)
    {
		foreach my $r (@$acronym_pairs)
		{
		    if ($r->[0] eq $trait_abbr)
		    {
				my $trait_name =  $r->[1];
				$trait_name    =~ s/^\s+|\s+$//g;

                # my $model = $c->controller('solGS::Search')->model($c);
				my $trait_id = $c->controller('solGS::Search')->model($c)->get_trait_id($trait_name);
				$self->get_trait_details($c, $trait_id);
		    }
		}
    }

}


sub traits_with_valid_models {
    my ($self, $c) = @_;

    my $pop_id = $c->stash->{pop_id} || $c->stash->{training_pop_id};

    $c->controller('solGS::Gebvs')->training_pop_analyzed_traits($c);

    my @analyzed_traits = @{$c->stash->{training_pop_analyzed_traits}};
    my @filtered_analyzed_traits;
    my @valid_traits_ids;

    foreach my $analyzed_trait (@analyzed_traits)
    {
        $c->controller('solGS::modelAccuracy')->get_model_accuracy_value($c, $pop_id, $analyzed_trait);
        my $av = $c->stash->{accuracy_value};
        if ($av && $av =~ m/\d+/ && $av > 0)
        {
            push @filtered_analyzed_traits, $analyzed_trait;


	    $c->stash->{trait_abbr} = $analyzed_trait;
	    $self->get_trait_details_of_trait_abbr($c);
	    push @valid_traits_ids, $c->stash->{trait_id};
        }
    }

    @filtered_analyzed_traits = uniq(@filtered_analyzed_traits);
    @valid_traits_ids = uniq(@valid_traits_ids);

    $c->stash->{traits_with_valid_models} = \@filtered_analyzed_traits;
    $c->stash->{traits_ids_with_valid_models} = \@valid_traits_ids;

}


sub phenotype_graph :Path('/solgs/phenotype/graph') Args(0) {
    my ($self, $c) = @_;

    my $pop_id        = $c->req->param('pop_id');
    my $trait_id      = $c->req->param('trait_id');
    my $combo_pops_id = $c->req->param('combo_pops_id');

    my $protocol_id = $c->req->param('genotyping_protocol_id');
    $c->controller('solGS::genotypingProtocol')->stash_protocol_id($c, $protocol_id);

    $self->get_trait_details($c, $trait_id);

    $c->stash->{training_pop_id}        = $pop_id;
    $c->stash->{combo_pops_id} = $combo_pops_id;

    $c->stash->{data_set_type} = 'combined populations' if $combo_pops_id;

    $c->controller("solGS::Files")->model_phenodata_file($c);

    my $model_pheno_file = $c->{stash}->{model_phenodata_file};
    my $model_data = $c->controller("solGS::Utils")->read_file_data($model_pheno_file);

    my $ret->{status} = 'failed';

    if (@$model_data)
    {
        $ret->{status} = 'success';
        $ret->{trait_data} = $model_data;
    }

    $ret = to_json($ret);

    $c->res->content_type('application/json');
    $c->res->body($ret);

}


sub save_single_trial_traits {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;

    $c->controller('solGS::Files')->traits_list_file($c, $pop_id);
    my $traits_file = $c->stash->{traits_list_file};

    if (!-s $traits_file)
    {
	my $trait_names = $c->controller('solGS::Utils')->get_clean_trial_trait_names($c, $pop_id);

	$trait_names = join("\t", @$trait_names);
	write_file($traits_file, {binmode => ':utf8'}, $trait_names);
    }

}


sub get_all_traits {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;

    $c->controller('solGS::Files')->traits_list_file($c, $pop_id);
    my $traits_file = $c->stash->{traits_list_file};

    if (!-s $traits_file)
    {
	my $page = $c->req->path;
	if ($page =~ /solgs\/population\/|anova\/|correlation\/|acronyms/ && $pop_id !~ /\D+/)
	{
	    $self->save_single_trial_traits($c, $pop_id);
	}
    }

    my $traits = read_file($traits_file, {binmode => ':utf8'});

    $c->controller('solGS::Files')->traits_acronym_file($c, $pop_id);
    my $acronym_file = $c->stash->{traits_acronym_file};

    unless (-s $acronym_file)
    {
	my @filtered_traits = split(/\t/, $traits);
	my $acronymized_traits = $c->controller('solGS::Utils')->acronymize_traits(\@filtered_traits);
	my $acronym_table = $acronymized_traits->{acronym_table};

	$self->traits_acronym_table($c, $acronym_table, $pop_id);
    }

    $self->create_trait_data($c, $pop_id);
}


sub create_trait_data {
    my ($self, $c, $pop_id) = @_;

    my $acronym_pairs = $self->get_acronym_pairs($c, $pop_id);

    my @pop_traits_details;
    if (@$acronym_pairs)
    {
	my $table = 'trait_id' . "\t" . 'trait_name' . "\t" . 'acronym' . "\n";
	foreach (@$acronym_pairs)
	{
	    my $trait_name = $_->[1];
	    $trait_name    =~ s/\n//g;

	    my $trait_id = $c->controller('solGS::Search')->model($c)->get_trait_id($trait_name);

	    if ($trait_id)
	    {
		$table .= $trait_id . "\t" . $trait_name . "\t" . $_->[0] . "\n";

        push @pop_traits_details, [$trait_id, $trait_name, $_->[0]];
	    }
	}

	$c->controller('solGS::Files')->all_traits_file($c, $pop_id);
	my $traits_file =  $c->stash->{all_traits_file};
	write_file($traits_file, {binmode => ':utf8'}, $table);

    $c->stash->{training_pop_traits_details} = \@pop_traits_details;
    }
}


sub get_acronym_pairs {
    my ($self, $c, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;
    #$pop_id = $c->stash->{combo_pops_id} if !$pop_id;

    my $dir    = $c->stash->{solgs_cache_dir};
    opendir my $dh, $dir
        or die "can't open $dir: $!\n";

    no warnings 'uninitialized';

    my ($file)   =  grep(/traits_acronym_pop_${pop_id}/, readdir($dh));
    $dh->close;

    my $acronyms_file = catfile($dir, $file);

    my @acronym_pairs;
    if (-f $acronyms_file)
    {
        @acronym_pairs =  map { [ split(/\t/) ] }  read_file($acronyms_file, {binmode => ':utf8'});
        shift(@acronym_pairs); # remove header;
    }

    @acronym_pairs = sort {uc $a->[0] cmp uc $b->[0] } @acronym_pairs;

    $c->stash->{acronym} = \@acronym_pairs;

    return \@acronym_pairs;

}


sub traits_acronym_table {
    my ($self, $c, $acronym_table, $pop_id) = @_;

    $pop_id = $c->stash->{training_pop_id} if !$pop_id;

    if (keys %$acronym_table)
    {
	my $table = 'Acronym' . "\t" . 'Trait name' . "\n";

	foreach (keys %$acronym_table)
	{
	    $table .= $_ . "\t" . $acronym_table->{$_} . "\n";
	}

	$c->controller('solGS::Files')->traits_acronym_file($c, $pop_id);
	my $acronym_file =  $c->stash->{traits_acronym_file};

	write_file($acronym_file, {binmode => ':utf8'}, $table);
    }

}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->get_solgs_dirs($c);

}


__PACKAGE__->meta->make_immutable;

1;
