package SGN::Controller::solGS::Utils;

use Moose;
use namespace::autoclean;

use File::Slurp qw /write_file read_file/;


sub convert_arrayref_to_hashref {
    my ($self, $array_ref) = @_;

    my %hash_var = ();

    foreach my $dt (@$array_ref)
    {
        $hash_var{$dt->[0]} = $dt->[1];
    }
    return \%hash_var;
}


sub count_cores {
    my $self= shift;

    my $data = qx/lscpu | grep -e '^CPU(s)'/;
    my ($name, $cores) = split(':', $data);
    $cores =~ s/\s+//g;

    return $cores;

}


sub read_file_data {
    my ($self, $file) = @_;

    my @lines = read_file($file, {binmode => ':utf8'});
    shift(@lines);
	chomp(@lines);

    my @data;
    push @data, map{ [split(/\t/)]} @lines;

    return \@data;

}


sub structure_downloadable_data {
    my ($self, $file, $row_name) = @_;

    my @data;
    if (-s $file)
    {
	my $count = 1;
	foreach my $row (read_file($file, {binmode => ':utf8'}) )
	{
	    $row_name = "\t" if !$row_name;
	    $row = $row_name . $row  if $count == 1;
	    $row = join("\t", split(/\s/, $row));
	    $row .= "\n";

	    push @data, [ $row ];
	    $count++;
	}
    }

    return \@data;
}


sub top_10 {
    my ($self, $file) = @_;

    my $lines = $self->read_file_data($file);
    my @top_10;


    if (scalar(@$lines) > 10)
    {
    	@top_10 = @$lines[0..9];
    }
    else
    {
    	@top_10 = @$lines;
    }

    return \@top_10;

}


sub abbreviate_term {
    my ($self, $term) = @_;

    $term =~ s/\// /g;
    $term =~ s/-/_/g;
    $term =~ s/\%/percent/g;
    $term =~ s/\((\w+\s*\w*)\)/_$2 $1/g;

    my @words = split(/\s/, $term);

    my $acronym;

    if (scalar(@words) == 1)
    {
	$acronym = shift(@words);
    }
    else
    {
	foreach my $word (@words)
        {
	    if ($word =~ /^[A-Za-z]/)
            {
		my $l = substr($word,0,1,q{});

		$acronym .= $l;
	    }
	    elsif ($word =~/^[0-9]/)
	    {
		my $str_wrd = $word;
		my @str = $str_wrd =~ /[\d+-\d+]/g;
		my $str = join("", @str);
		my @wrd = $word =~ /[A-Za-z]/g;
		my $wrd = join("", @wrd);

		my $l = substr($wrd,0,1,q{});
		$acronym .= $str . uc($l);
	    }
            else
            {
                $acronym .= $word;
            }

	    $acronym = uc($acronym);
	}
    }

    return $acronym;

}


sub acronymize_traits {
    my ($self, $traits) = @_;

    my $acronym_table = {};
    my $cnt = 0;
    my $acronymized_traits;

    no warnings 'uninitialized';

    foreach my $trait_name (@$traits)
    {
	$cnt++;

        my $abbr = $self->abbreviate_term($trait_name);

	$abbr = $abbr . '.2' if $cnt > 1 && $acronym_table->{$abbr};

        $acronymized_traits .= $abbr;
	$acronymized_traits .= "\t" unless $cnt == scalar(@$traits);

        $acronym_table->{$abbr} = $trait_name if $abbr;
	my $tr_h = $acronym_table->{$abbr};
    }

    my $acronym_data = {
	'acronymized_traits' => $acronymized_traits,
	'acronym_table'      => $acronym_table
    };

    return $acronym_data;
}


sub trial_traits {
    my ($self, $c, $trial_id) = @_;

    my $trial = CXGN::Trial->new({bcs_schema => $self->schema($c),
				  trial_id => $trial_id});

    return $trial->get_traits_assayed();

}


sub clean_traits {
    my ($self, $terms) = @_;

    $terms =~ s/(\|\w+:\d+)//g;
    $terms =~ s/\|/ /g;
    $terms =~ s/^\s+|\s+$//g;

    return $terms;
}


sub remove_ontology {
    my ($self, $traits) = @_;

    my @clean_traits;

    foreach my $tr (@$traits) {
	my $name = $tr->[1];
	$name= $self->clean_traits($name);

	my $id_nm = {'trait_id' => $tr->[0], 'trait_name' => $name};
 	push @clean_traits, $id_nm;
    }

    return \@clean_traits;

}


sub get_clean_trial_trait_names {
    my ($self, $c, $trial_id) = @_;

    my $traits = $c->model('solGS::solGS')->trial_traits($trial_id);
    my $clean_traits = $c->controller('solGS::Utils')->remove_ontology($traits);
    my @trait_names;

    foreach my $tr (@$clean_traits)
    {
	push @trait_names, $tr->{trait_name};
    }

    return \@trait_names;
}


sub save_metadata {
    my ($self, $c) = @_;

    $c->controller('solGS::Files')->phenotype_metadata_file($c);
    my $metadata_file = $c->stash->{phenotype_metadata_file};

    if (!-s $metadata_file)
    {
	my $metadata   = $c->model('solGS::solGS')->trial_metadata();
	write_file($metadata_file, {binmode => ':utf8'}, join("\t", @$metadata));
    }

}


sub generic_message {
    my ($self, $c, $msg) = @_;

    $c->stash->{message} = $msg;

    $c->stash->{template} = "/generic_message.mas";
}

####
1;
####
