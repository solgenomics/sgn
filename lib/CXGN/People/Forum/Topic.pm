
=head1 PACKAGE CXGN::People::Forum::Topic


=cut

package CXGN::People::Forum::Topic;

use base qw | CXGN::People::Forum |;
use strict;

=head2 function new()

  Synopsis:	constructor: 
  Example:      my $t = CXGN::People::Forum::Topic->new($dbh, $id)
  Arguments:	a database handle and a topic id
  Returns:	an object filled in with the db row of id provided,
                or an empty object if $id is omitted.
  Side effects:	
  Description:	

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $id = shift; 

    my $self = $class->SUPER::new($dbh);

    $self->set_sql();

    if ($id and $id=~/^\d+$/) { 
	$self->set_forum_topic_id($id);
	$self->fetch_topic();

    }



    return $self;
}

=head2 function new_page_comment()
 
  Synopsis:	my $t = CXGN::People::Forum::Topic
                  ->new_page_comment($dbh, "BAC", $id)
  Arguments:	
  Returns:	
  Side effects:	
  Description:  alternate constructor that takes a page type
                and id as parameters. Page types describe different
                detail pages such as BAC, EST, unigene, marker, 
                map, etc. The id is the id of the object in the 
                database that the topic is assigned to.

=cut

sub new_page_comment { 
    my $class = shift;
    my $dbh = shift;
    my $page_type = shift;
    my $page_id = shift;
    my $self = $class->new($dbh);
    my $sth = $self->get_sql('page_comment');
    $sth->execute($page_type, $page_id);
    if ($sth->rows()>0) { 
	my ($topic_id) = $sth->fetchrow_array();
	$self->set_forum_topic_id($topic_id);
	$self->fetch_topic($topic_id);
    }
    else { 
	#print STDERR "Couldn't find topic...\n";
    }

    return $self;
}


=head2 function all_topics()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	returns a list of all topics, as 
                CXGN::People::Forum::Topic objects

=cut

sub all_topics {
	#
	# static function that return all topics as a list of topic objects.
	# only get topics that are not page topics (page_type IS NULL)
	#
    my $dbh = shift;
    my $forum = CXGN::People::Forum::Topic->new($dbh);
    my $forum_handle = $forum->get_sql('all_topics');
    $forum_handle -> execute();
    my @topics=();
    while (my ($id) = $forum_handle->fetchrow_array()) { 
	push @topics, CXGN::People::Forum::Topic->new($dbh, $id);
    }
    
    return @topics;
}



sub all_topics_by_class { 
    # static function
    my $class = shift;

}

sub all_topic_classes {
    my $self = shift;
    my $forum = CXGN::People::Forum->new($self->get_dbh());
    my $forum_handle = $forum->get_sql('all_topic_classes');
    $forum_handle->execute();
    my @classes;
    while (my ($class) = $forum_handle->fetchrow_array()) { 
	push @classes, $class;
    }
    return @classes;
}

sub fetch_topic { 
    my $self = shift;
    my $sth = $self->get_sql('fetch');
    $sth->execute($self->get_forum_topic_id());
	my ($forum_topic_id, $person_id, $topic_name, $topic_description, 
		$parent_topic, $topic_class, $page_type, $page_object_id, 
		$sort_order) = $sth->fetchrow_array();

    $self->set_person_id($person_id);
    $self->set_topic_name($topic_name);
    $self->set_topic_description($topic_description);
    $self->set_parent_topic($parent_topic);
    $self->set_topic_class($topic_class);
    $self->set_page_type($page_type);
    $self->set_page_object_id($page_object_id);
    $self->set_topic_sort_order($sort_order);
}

sub store {
	my $self = shift;
	#print STDERR "Storing Topic...".$self->get_topic_name()."\n";
	if ($self->get_forum_topic_id()) { 
		#
		# update db
		# 
		my $uh = $self->get_sql('update');
		
		$uh->execute(
			$self->get_person_id(), $self->get_topic_name(), 
			$self->get_topic_description(), $self->get_topic_class(), 
			$self->get_page_type(), $self->get_page_object_id(), 
			$self->get_topic_sort_order(), 
			($self->get_forum_topic_id() + 0)
		);
	}
	else { 
		#
		# insert into db
		#
		my $ih = $self->get_sql('insert');
		$ih->execute(
			$self->get_person_id, $self->get_topic_name(), 
			$self->get_topic_description(), $self->get_parent_topic(), 
			$self->get_topic_class(), $self->get_page_type(), 
			$self->get_page_object_id(), $self->get_topic_sort_order()
		);
		my $lh = $self->get_sql('currval');
		$lh->execute();
		my ($last_id) = $lh->fetchrow_array();
		$self->set_forum_topic_id($last_id);
	}
	my $subject="[Forum.pm] Topic stored: ".$self->get_topic_name();
	my $body="Submitted by person ID: ".$self->get_person_id()."\n\n";
	$body.="Topic description: ".$self->get_topic_description()."\n\n";
	eval { CXGN::Contact::send_email($subject,$body,'cxgn-devel\@sgn.cornell.edu'); };
	return $self->get_forum_topic_id();
}

=head2 function get_post_count()

  Synopsis:	
  Arguments:	
  Returns:	the number of posts associated with the
                topic_id associated with this object.
  Side effects:	
  Description:	 

=cut

sub get_post_count { 
    my $self = shift;
    my $h = $self->get_sql('post_count');
    $h->execute($self->get_forum_topic_id());
    my ($count) = $h->fetchrow_array();
    return $count;
} 

=head2 function get_most_recent_post_date()

  Synopsis:	
  Arguments:	none
  Returns:	a formatted string representing the date 
                and time of the most recent posting to this 
                topic.
  Side effects:	
  Description:	

=cut

sub get_most_recent_post_date { 
    my $self = shift;
    my $h = $self->get_sql('latest_post');
    $h->execute($self->get_forum_topic_id());
    my $post = CXGN::People::Forum::Post->new($self->get_dbh(), ($h->fetchrow_array())[0]);
    return $post->get_formatted_post_time();
}

=head2 accessors get_person_id() and set_person_id()

  Synopsis:	accessors for the person property
  Arguments:	set: the person id
  Returns:	get: the id of the person who created the topic
  Side effects:	
  Description:	the person_id refers to the sgn_people.sp_person.person_id

=cut

sub get_person_id { 
    my $self = shift;
    return $self->{person_id};
}

sub set_person_id {
    my $self = shift;
    $self->{person_id} = shift;
}

=head2 accessors get_forum_topic_id() and set_forum_topic_id()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_forum_topic_id { 
    my $self = shift;
    if (!$self->{forum_topic}) { return 0; }
    return $self->{forum_topic};
}

sub set_forum_topic_id {
    my $self = shift;
    $self->{forum_topic}=shift;
}

=head2 accessors get_topic_name() and set_topic_name()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_topic_name {
    my $self = shift;
    return ($self->{topic_name});

}

sub set_topic_name {
    my $self = shift;
    $self->{topic_name}=shift;
}

=head2 function get_topic_description

Synopsis:	
Arguments:	
Returns:	
Side effects:	
Description:	

=cut

sub get_topic_description { 
    my $self=shift;
    #my $formatted = $self->format_post_text($self->{topic_description});
    return $self->{topic_description};
}

=head2 function set_topic_description

Synopsis:	
Arguments:	
Returns:	
Side effects:	
Description:	

=cut

sub set_topic_description { 
    my $self=shift;
    $self->{topic_description}=shift;
}

sub get_parent_topic {
    my $self = shift;
    if (!$self->{topic_parent}) { 
	return 0; 
    }
    return $self->{topic_parent};
}

sub set_parent_topic {
    my $self = shift;
    $self->{topic_parent} = shift;
}

sub get_topic_class {
    my $self = shift;
    return $self->{topic_class};
}

sub set_topic_class {
    my $self = shift;
    $self->{topic_class} = shift;
}

=head2 accessors get_page_type() and set_page_type()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	the page type property is used for page
                comments.

=cut

sub get_page_type { 
    my $self = shift;
    return $self->{page_type};
}

sub set_page_type { 
    my $self = shift;
    $self->{page_type} =shift;
}

=head2 accessors get_page_object_id() and set_page_object_id()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_page_object_id { 
    my $self = shift;
    if (!$self->{page_object_id}) { return 0; }
    return $self->{page_object_id};
}

sub set_page_object_id { 
    my $self = shift;
    $self->{page_object_id} = shift;
}

=head2 function get_all_posts()

  Synopsis:	
  Arguments:	
  Returns:	all posts belonging to this topic, 
                as CXGN::People::Forum::Post objects. 
                The objects are ordered in the order they
                were entered (oldest first).
  Side effects:	
  Description:	

=cut

sub get_all_posts { 
    my $self = shift;
    my $topic_id = $self->get_forum_topic_id();
    
    $self->{post_level} =0;
    @{$self->{posts}} = ();

    $self->_get_children_posts(0, $topic_id);

    return @{$self->{posts}};
}

sub _get_children_posts { 
    my $self = shift;
    my $parent_post_id = shift;
    my $topic_id = shift;
    
    my $sort_order = $self->get_topic_sort_order();
    #warn "SORT ORDER IS $sort_order\n";
#    $sort_order = "ASC" unless $sort_order =~ /desc/i;
    my $sth;
    if ($sort_order =~ /asc/) {  $sth = $self->get_sql('children_posts_asc'); }
    else { $sth = $self->get_sql('children_posts_desc'); }
    $sth->execute($topic_id);
    return if $sth->rows()==0;
    
    while (my ($post_id)= $sth->fetchrow_array()) {
	my $post = CXGN::People::Forum::Post->new($self->get_dbh(), $post_id);
	push @{$self->{posts}}, $post;
    }
}
    

sub get_all_posts_by_person {
    my $self = shift;
    my $person_id = shift;
}

=head2 accessors set_topic_sort_order, get_topic_sort_order

  Property:	
  Setter Args:	
  Getter Args:	
  Getter Ret:	
  Side Effects:	
  Description:	

=cut

sub get_topic_sort_order { 
    my $self=shift;
    if (!exists($self->{topic_sort_order})) { $self->{topic_sort_order}="asc"; }
    return $self->{topic_sort_order};
}

sub set_topic_sort_order { 
    my $self=shift;
    my $sort_order = shift;
    if ($sort_order=~/asc|desc/i) { 
	$self->{topic_sort_order}=$sort_order;
    }
    else { 
	print STDERR "[Topic.pm] set_topic_sort_order $sort_order is not a legal sort order. Set to default (asc)\n"; 
	$self->{topic_sort_order}="asc";
    }
}



=head2 function delete()

  Synopsis:	
  Arguments:	none
  Returns:	the number of rows deleted, usually >0 if 
                successful (the number is the number of
		associated posts deleted).
  Side effects:	the topic with the corresponding id is 
                permanently removed from the database,
                including all associated posts.
  Description:	

=cut

sub delete { 
    my $self = shift;
    my $h = $self->get_sql('delete_posts');
    $h->execute($self->get_forum_topic_id());
    $h = $self->get_sql('delete_topic');
    $h->execute($self->get_forum_topic_id());
    return $h->rows();
}


sub set_sql { 
    my $self = shift;
    
    $self->{queries} = {
	
		fetch =>

			"
				SELECT 
					forum_topic_id, person_id, topic_name, topic_description, 
					parent_topic, topic_class, page_type, page_object_id, 
					sort_order 
				FROM 
					sgn_people.forum_topic 
				WHERE 
					forum_topic_id=?
			",
		
		page_comment =>
			
			"
				SELECT forum_topic_id
				FROM sgn_people.forum_topic
				WHERE page_type=?
				AND page_object_id=?
			",

		post_count =>

			"
				SELECT COUNT(*)
				FROM sgn_people.forum_post
				WHERE forum_topic_id=?
			",

		latest_post=>

			"
				SELECT MAX(forum_post_id)
				FROM sgn_people.forum_post
				WHERE forum_topic_id=?
			",

		all_topics =>

			"
				SELECT 
					forum_topic.forum_topic_id, 
					MAX(forum_post.post_time) 
				FROM sgn_people.forum_topic 
				LEFT JOIN sgn_people.forum_post 
					ON (forum_topic.forum_topic_id=forum_post.forum_topic_id) 
				WHERE page_type IS NULL 
					OR page_type=''  
				GROUP BY forum_topic.forum_topic_id 
				ORDER BY MAX(forum_post.post_time) DESC
			",

		all_topic_classes =>

			"
				SELECT DISTINCT(topic_class)
				FROM sgn_people.forum_topic
			",

		update =>

			"
				UPDATE 
					sgn_people.forum_topic 
				SET 
					person_id=?, topic_name=?, topic_description=?, topic_class=?, 
					page_type=?, page_object_id=?, sort_order=? 
				WHERE 
					forum_topic_id =?
			",

		insert =>

			"
				INSERT INTO sgn_people.forum_topic 
					(person_id, topic_name, topic_description,  parent_topic, 
					topic_class, page_type, page_object_id, sort_order) 
				VALUES 
					(?, ?, ?, ?, 
					 ?, ?, ?, ?)
			",

		currval =>
			
			" SELECT currval('sgn_people.forum_topic_forum_topic_id_seq') ",

		children_posts_asc =>

		"
				SELECT forum_post_id, post_time 
				FROM sgn_people.forum_post
				WHERE forum_topic_id=? 
				ORDER BY post_time"
			,

		children_posts_desc => "
                	        SELECT forum_post_id, post_time 
				FROM sgn_people.forum_post
				WHERE forum_topic_id=? 
				ORDER BY post_time desc"
				,
		
		

		delete_posts =>

			" DELETE FROM sgn_people.forum_post WHERE forum_topic_id=? ",

		delete_topic =>

			" DELETE FROM sgn_people.forum_topic WHERE forum_topic_id=? ",


	};
	
	while(my($k,$v) = each %{$self->{queries}}){
	    $self->{query_handles}->{$k}= $self->get_dbh()->prepare($v);
	}
}

sub get_sql { 
    my $self = shift;
    my $name = shift;
    return $self->{query_handles}->{$name};
}

1;
