package SuperPage::Plugin;

use MT::Util qw( dirify );
use strict;

sub instance {
    return MT->component("SuperPage");
}

sub pre_save {
    my ($cb, $app, $obj, $orig) = @_;

    my $cfg = instance()->get_config_hash('blog:'.$app->blog->id);
    return 1 if !$cfg->{enable_superpage};

    my $super = $app->param('is_super_page');
    $obj->is_super_page($super);
    1;
}


sub pre_remove {
    my ($cb, $obj) = @_;
    if ($obj->is_super_page) {
	MT::Page->remove({ parent_super_page => $obj->id });
    }
}

sub post_save {
    my ($cb, $app, $obj, $orig) = @_;

    my $cfg = instance()->get_config_hash('blog:'.$app->blog->id);
    return 1 if !$cfg->{enable_superpage};

    if ($app->param('is_super_page')) {
	my @pages = _partition($obj);
	my $toc = _toc($obj, @pages);
	$toc->save;
	_set_folder($toc->id, $toc->blog_id, $obj->category->id);
    }
    1;
}

sub _set_folder {
    my ($id,$blog_id,$cat_id) = @_;
    require MT::Placement;
    my $place;
    unless ($place = MT::Placement->load( { entry_id => $id, blog_id => $blog_id })) {
	$place = MT::Placement->new;
	$place->entry_id($id);
	$place->blog_id($blog_id);
	$place->is_primary(1);
    }
    $place->category_id( $cat_id );
    $place->save;
}

sub _partition {
    my ($parent) = @_;
    my ($obj,$page,$title);
    my @pages = ();
    my @lines = split("\n",$parent->text);

    # Map the current list of pages associated with the parent into a simple lookup table
    # This table will be used to fetch pages
    my @tmp = MT::Page->load({ parent_super_page => $parent->id });
    my %origpages = map { $_->title => $_ } @tmp;
        
    foreach my $line (@lines) {
	if ($line =~ s/^(#+)\s*//) {
	    my $size = $#pages + 1;
	    if ($page) {
#		$page->{'obj'}->save();
		push @pages, $page;
	    }
	    chomp($line);

	    $page = {};
	    # Look for a page that has the same title. 
	    $obj = delete($origpages{$line});
	    if ($obj) {
#		MT->log({ level => MT::Log::INFO(), message => "found a page: " . $obj->title });
	    } else {
		$obj = MT::Page->new;
		$obj->parent_super_page($parent->id);
		$obj->title($line);
		$obj->blog_id($parent->blog_id);
		$obj->status($parent->status);
		$obj->author_id($parent->author_id);
		$obj->allow_comments($parent->allow_comments);
		$obj->convert_breaks($parent->convert_breaks);
#		$obj->basename(dirify($line));
	    }
	    $page->{'obj'} = $obj;
	    $page->{'depth'} = length($1);
	    $page->{'title'} = $line;
	} else {
	    $page->{'content'} .= "$line\n" if ($page->{'title'});
	    $obj->text($page->{'content'});
	}
    }
    # HACK!!! - save the last page
#    $page->{'obj'}->save();
#    _set_folder($page->{'obj'}->id, $page->{'obj'}->blog_id, $parent->category->id);
    push @pages, $page;

    # Now the origpages struct only has left over pages - they can be safely deleted
    my @keys = keys %origpages;
#    MT->log({ level => MT::Log::INFO(), message => "Remove " . $#keys . " remnants" });
    foreach (@keys) {
#	MT->log({ level => MT::Log::INFO(), message => "Removing $_" });
	$origpages{$_}->remove();
    }

    for (my $i = 0; $i <= $#pages; $i++) {
	my $page = $pages[$i];
	my $next = ($i < $#pages ? $pages[$i + 1] : undef);
	my $prev = ($i > 0 ? $pages[$i - 1] : undef);
	$next->{'obj'}->save if $next && !$next->{obj}->id;
	$page->{'obj'}->next_page($next->{'obj'}->id) if $next;
	$page->{'obj'}->prev_page($prev->{'obj'}->id) if $prev;
	$page->{'obj'}->save;
	_set_folder($page->{'obj'}->id, $page->{'obj'}->blog_id, $parent->category->id);
    }
    return @pages;
}

sub _toc {
    my ($parent, @pages) = @_;
    require MT::Page;
    my $toc = MT::Page->new;
    $toc->title($parent->title . ": " . $app->translate("Table of Contents"));
    $toc->basename("index");
    $toc->allow_comments(0);
    $toc->status(MT::Entry::RELEASE());
    $toc->convert_breaks('markdown');
    $toc->parent_super_page($parent->id);
    $toc->blog_id($parent->blog_id);
    $toc->author_id($parent->author_id);
    my $content = '';
    foreach my $p (@pages) {
	$p->{'title'} =~ s/_/\\_/g;
	$content .= "   " x ($p->{'depth'} - 1);
	$content .= "* [" . $p->{'title'} . "](". $p->{'obj'}->permalink() . ")\n";
    }
    $toc->text($content);
    return $toc;
}

sub xfrm_edit {
    my ($cb, $app, $tmpl) = @_;

    my $cfg = instance()->get_config_hash('blog:'.$app->blog->id);
    return if !$cfg->{enable_superpage};

    my $slug1 = <<END_TMPL;
      <mt:if name="parent_super_page">
      <mtapp:statusmsg
          id="super-page"
          class="alert">
          <__trans phrase="You are editing the artifact of a 'super page.' Changes you make might get lost.">
      </mtapp:statusmsg>
      </mt:if>
END_TMPL
    my $slug2 = <<END_TMPL;
        <mtapp:setting
            id="super_page"
            label="<__trans phrase="Super Page?">">
                <input type="checkbox" name="is_super_page" value="1" id="is_super_page" <mt:if name="is_super_page">checked</mt:if> />
        </mtapp:setting>
END_TMPL
    $$tmpl =~ s{(<div id="msg-block">)}{$1$slug1}msg;
    $$tmpl =~ s{(<\$mt:var name="category_setting"\$>)}{$slug2$1}msg;
}

sub tag_prev_page_id {
    my ($ctx, $args) = @_;
    my $p = $ctx->stash('entry')
        or return $ctx->_no_entry_error($ctx->stash('tag'));
    return $p->prev_page;
} 

sub tag_next_page_id {
    my ($ctx, $args) = @_;
    my $p = $ctx->stash('entry')
        or return $ctx->_no_entry_error($ctx->stash('tag'));
    return $p->next_page;
} 

sub tag_parent_page_id {
    my ($ctx, $args) = @_;
    my $p = $ctx->stash('entry')
        or return $ctx->_no_entry_error($ctx->stash('tag'));
    return $p->parent_super_page;
} 

sub tag_is_super {
    my ($ctx, $args) = @_;
    my $p = $ctx->stash('entry')
        or return $ctx->_no_entry_error($ctx->stash('tag'));
    return $p->is_super_page;
} 

sub tag_is_super_child {
    my ($ctx, $args) = @_;
    my $p = $ctx->stash('entry')
        or return $ctx->_no_entry_error($ctx->stash('tag'));
    return $p->parent_super_page > 0;
} 


1;

__END__
