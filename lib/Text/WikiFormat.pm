package Text::WikiFormat;

use strict;

use URI::Escape;

use vars qw( $VERSION %tags $indent );
$VERSION = 0.60;

$indent = qr/^(?:\t+|\s{4,})/;
%tags = (
	newline		=> '<br />',
	line		=> '<hr />',
	link		=> \&make_html_link,
	strong		=> sub { "<strong>$_[0]</strong>" },
	emphasized	=> sub { "<em>$_[0]</em>" },

	code		=> [ '<code>', "</code>\n", '', "\n" ],
	paragraph	=> [ '<p>', "</p>\n", '', "\n" ],
	unordered	=> [ '<ul>', "</ul>\n", '<li>', "</li>\n" ],
	ordered		=> [ '<ol>', "</ol>\n", 
		sub { qq|<li value="$_[1]">$_[0]</li>\n| } ],

	lists		=> {
		ordered		=> qr/$indent([\dA-Za-z]+)\.\s*/,
		unordered	=> qr/$indent\*\s*/,
		code		=> qr/$indent/,
	},

	listorder                => [qw( ordered unordered code )],
	extended_link_delimiters => [qw( [ ] )],
);

sub process_args
{
	my $self = shift;
	my $name = @_ == 1 ? shift : 'wikiformat';
	return ( as => $name, @_ );
}

sub default_opts
{
	my ($class, $args) = @_;

	my %defopts = ( implicit_links => 1, map { $_ => delete $args->{ $_ } }
		qw( prefix extended implicit_links) );

	return %defopts;
}

sub merge_hash
{
	my ($from, $to) = @_;
	while (my ($key, $value) = each %$from)
	{
		if (UNIVERSAL::isa( $value, 'HASH' ))
		{
			$to->{$key} = {} unless defined $to->{$key};
			merge_hash( $value, $to->{$key} );
		}
		else
		{
			$to->{$key} = $value;
		}
	}
}

sub import
{
	my $class = shift;
	return unless @_;

	my %args    = $class->process_args( @_ );
	my %defopts = $class->default_opts( \%args );

	my $caller = caller();
	my $name   = delete $args{as};

	no strict 'refs';
	*{ $caller . "::$name" } = sub {
		my ($text, $tags, $opts) = @_;

		$tags ||= {};
		$opts ||= {};

		my %tags = %args;
		merge_hash( $tags, \%tags );
		my %opts = %defopts;
		merge_hash( $opts, \%opts );

		Text::WikiFormat::format( $text, \%tags, \%opts);
	}
}

sub _available_lists
{
	my $tags = shift;
	my $order = $tags->{listorder} || [];
	my $lists = $tags->{lists};
	my %difference;
	@difference{ keys %{ $tags->{ lists } } } = ();
	delete @difference{ @$order };
	unshift @$order, keys %difference;
	return $order;
}

sub format
{
	my ($text, $newtags, $opts) = @_;
	$opts ||= { prefix => '', extended => 0, implicit_links => 1 };

	my %tags = %tags;
	if (defined $newtags and UNIVERSAL::isa($newtags, 'HASH')) {
		merge_hash( $newtags, \%tags );
	}

	my $list_types = _available_lists( \%tags );
	my %lists = map { $_ => [] } @$list_types;
	my ($parsed, $active_list) = ('', '');

	LINE:
	for my $line (split(/\n/, $text)) {

		for my $list (@$list_types) {

			my $regex = $tags{lists}->{$list};
			if (my @captures = ($line =~ $regex)) {
				$line =~ s/$regex//;

				$line = format_line($line, \%tags, $opts) 
					unless $list eq 'code';

				my $action = $tags{$list} or next;
				my $formatted;

				if (@$action == 3) {
					my $subref = $action->[2];
					if (defined $subref and defined &$subref) {
						$formatted = $subref->($line, @captures);
					} else {
						warn "Bad actions for list type '$list'\n";
					}
				} else {
					$formatted = $action->[2] . $line . $action->[3];
				}

				# save this list element
				push @{ $lists{$list} }, $formatted;

				# must end previous list type
				if ($active_list and $active_list ne $list) {
					$parsed .= end_list(\%lists, $active_list, 
						$tags{$active_list});
				}

				$active_list = $list;
				next LINE;
			}
		}

		if ($active_list and $active_list ne 'paragraph' or !$line) {
			pop @{ $lists{paragraph} } unless $line;
			$parsed .= end_list(\%lists, $active_list, 
				$tags{$active_list}) if $active_list;
		}
			
		next LINE unless $line;

		$active_list = 'paragraph';
		push @{ $lists{paragraph} }, 
			format_line($line, \%tags, $opts), $tags{newline};

	}

	pop @{ $lists{paragraph} } if $active_list eq 'paragraph';
	$parsed .= end_list(\%lists, $active_list, $tags{$active_list})
		if $active_list;
	return $parsed;
}

sub end_list
{
	my ($lists, $active, $tags) = @_;

	return '' unless @{ $lists->{$active} };
	my $result = join('', $tags->[0], @{ $lists->{$active} }, $tags->[1]);
	$lists->{$active} = [];
	return $result;
}

sub format_line
{
	my ($text, $tags, $opts) = @_;
	$opts ||= {};

	$text =~ s!'''(.+?)'''!$tags->{strong}->($1, $opts)!eg;
	$text =~ s!''(.+?)''!$tags->{emphasized}->($1, $opts)!eg;
	$text =~ s!^-{4,}!$tags->{line}!gm;

	$text = find_extended_links( $text, $tags, $opts ) if $opts->{extended};

	$text =~ s|(?<!["/>=])\b([A-Za-z]+(?:[A-Z]\w+)+)|$tags->{link}->($1, 
	$opts)|eg if !defined $opts->{implicit_links} or $opts->{implicit_links};

	return $text;
}

sub find_extended_links
{
	my ($text, $tags, $opts) = @_;

	my ($start, $end) = @{ $tags->{extended_link_delimiters} };

	my $position = 0;
	while (1)
	{
		my $open = index $text, $start, $position;
		last if $open == -1;
		my $close   = index $text, $end, $open;
		last if $close == -1;

		my $text_start = $open + length $start;
		my $extended = substr $text, $text_start, $close - $text_start;
		$extended = $tags->{link}->( $extended, $opts );
		substr $text, $open, $close - $open + length $end, $extended;
		$position += length $extended;
	};

	return $text;
}

sub make_html_link
{
	my ($link, $opts) = @_;
	$opts ||= {};

	my $title;
	($link, $title) = split(/\|/, $link, 2) if $opts->{extended};
	$title ||= $link;
	$link = uri_escape( $link );

	my $prefix = $opts->{prefix} || '';
	return qq|<a href="$prefix$link">$title</a>|;
}

'shamelessly adapted from the Jellybean project';

__END__

=head1 NAME

Text::WikiFormat - module for translating Wiki formatted text into other formats

=head1 SYNOPSIS

	use Text::WikiFormat;
	my $html = Text::WikiFormat::format($raw);

=head1 DESCRIPTION

The original Wiki web site was intended to have a very simple interface to
edit and to add pages.  Its formatting rules are simple and easy to use.  They
are also easily translated into other, more complicated markup languages with
this module.  It creates HTML by default, but can be extended to produce valid
POD, DocBook, XML, or any other format imaginable.

The most important function is C<format()>.  It is not exported by default.

=head2 format()

C<format()> takes one required argument, the text to convert, and returns the
converted text.  It allows two optional arguments.  The first is a reference to
a hash of tags.  Anything passed in here will override the default tag
behavior.  These tags are described later.  The second argument is a hash
reference of options.  There are currently limited to:

=over 4

=item * prefix

The prefix of any links.  In HTML mode, this is the path to the Wiki.  The
actual linked item itself will be appended to the prefix.  This is used to
create full URIs:

	{ prefix => 'http://example.com/wiki.pl?page=' }

=item * extended

A boolean flag, false by default, to use extended linking semantics.  This is
stolen from the Everything Engine (L<http://everydevel.com/>), where links are
marked by square brackets.  An optional title may occur after the link target,
preceded by an open pipe.  That is to say, these are valid extended
links:

	[a valid link]
	[link|title]

Where the linking semantics of the destination format allow it, the
title will be displayed instead of the URI.  In HTML terms, the title
is the content of an A element (not the content of its HREF attribute).

You can use delimiters other than single square brackets for marking
extended links, by passing a value for C<extended_link_delimiters>
in the C<%tags> hash when calling C<format> (see below for details).

=item * implicit_links

A boolean flag, true by default, to cause links to be created wherever a
StudlyCapsString is seen.  Note that if you disable this flag, you'll most
likely be wanting to enable the C<extended> one also, or there will be no way
of creating links in your documents.  To disable it, use the pair:

	{ implicit_links => 0 }

=head2 Wiki Format

Wiki formatting is very simple.  An item wrapped in three single quotes is
marked as B<strong>.  An item wrapped in two single quotes is marked as
I<emphasized>.  Any word with multiple CapitalLetters (e. g., StudlyCaps) will
be turned into a link.  Four or more hyphen characters at the start of a line
create a horizontal line.  Newlines are translated into the appropriate tag.

All lists are indented by one tab or four spaces.  Lists can be unordered,
where each item has its own bullet point.  These are marked by a leading
asterisk and space.  They can also be ordered, where any combination of one or
more alphanumeric characters can be followed by a period and an optional space.
Any indented text without either marking is considered to be code, and is
handled literally.

The following is valid Wiki formatting, with an extended link as marked.

	ANormalLink
	[let the Sun shine|AnExtendedLink]

	    * unordered one
	    * unordered two

	    1. ordered one
	    2. ordered two

	    code one
	    code two

	The first line of a normal paragraph.
	The second line of a normal paragraph.  Whee.

=head1 EXPORT

If you'd like to make your life more convenient, you can optionally import a
subroutine that already has default tags and options set up.  This is
especially handy if you will be using a prefix:

	use Text::WikiFormat prefix => 'http://www.example.com/';
	wikiformat( 'some text' );

All tags are interpreted as, well, tags, except for four special keys:

=over 4

=item * C<prefix>, interpreted as a link prefix

=item * C<extended>, interpreted as the extended link flag

=item * C<implicit_links>, interpreted as the flag to control implicit links

=item * C<as>, interpreted as an alias for the imported function

=back

Use the C<as> flag to control the name by which the imported function is
called.  For example,

	use Text::WikiFormat as => 'formatTextInWikiStyle';
	formatTextInWikiStyle( 'some text' );

You might choose a better name, though.

The calling semantics are effectively the same as those of the format()
function.  Any additional tags or options to the imported function will
override the defaults.  In this example:

	use Text::WikiFormat as => 'wf', extended => 0;
	wf( 'some text', {}, { extended => 1 });

extended links will be enabled, though the default is to disable them.

This feature was suggested by Tony Bowden E<lt>tony@kasei.comE<gt>, but all
implementation blame rests solely with me.  Kate L Pugh
(E<lt>kake@earth.liE<gt>) pointed out that it didn't work, with tests, so it's
fixed now.

=head1 GORY DETAILS

=head2 Tags

There are two types of Wiki markup: line items and lists.  Lists are made up of
lines, and can also contain other lists.

=head3 Line items

There are two classes of line items: simple tags, and tags that contain data.
The simple tags are C<newline> and C<line>.  A newline is inserted whenever a
newline character (C<\n>) is encountered.  A line is inserted whenever four or
more dash characters (C<---->) occur at the start of a line.  No whitespace is
allowed.  These default to the BR and HR HTML tags, respectively.  To override
either, simply pass tags such as:

	my $html = format($text, { newline => "\n" });

The three line items are more complex, and require subroutine references. This
category includes the C<strong> and C<emphasized> tags as well as C<link>s.
The first argument passed to the subref will be the data found in between the
marks.  The second argument is the $opts hash reference.  The default action
for a strong tag can be reimplemented with this syntax:

	my $html = format($text, { strong => sub { "<b>$_[0]</b>" } });

Finally, there are C<extended_link_delimiters>, which allow you to use
delimiters other than single square brackets for marking extended links.  Pass
the tags as:

	my $html = format( $text, { extended_link_delimiters => [ '[[', ']]' ] });

This will allow you to use double square brackets as UseMod supports:

	[[an extended link]]
	[[a titled extended link|title]]

=head3 Lists

There are three types of lists:  C<code>, C<unordered>, and C<ordered>.  Each
of these is I<usually> marked by indentation, either one or more tabs or four
or more whitespace characters.  (This does not include newlines, however.)  Any
line that does not fall in any of these three categories is automatically put
in a C<paragraph> list.

Lists are not required to have indentation, as of version 0.50.  Be careful
with this, however.

List entries in the tag hashes must contain array references.  The first two
items are the tags used at the start of the list and at the end of the list.
As you'd expect, the last items contain the tags used at the start and end of
each line.  Where there needs to be more processing of individual lines, use a
subref as the third item.  This is how ordered lines are numbered in HTML
lists:

	my $html = format($text, { ordered => [ '<ol>', "</ol>\n",
		sub { qq|<li value="$_[1]">$_[0]</li>\n| } ] });

The first argument to these subrefs is the text of the line itself, after it
has been processed.  (The indentation and tokens used to mark this as a list
item are removed, and the rest of the line is checked for other line
formattings.)  The subsequent arguments are captured variables in the regular
expression used to find this list type.  The regexp for ordered lists is:

	qr/^(?:\t+|\s{4,})([\dA-Za-z]+)\.\s*/;

This means that a line must start with one or more tabs B<or> four or more 
spaces.  It must then contain one or more alphanumeric character followed by a
single period and optional whitespace.  The contents of this last group is
saved, and will be passed to the subref as the second argument.

Lists are automatically started and ended as necessary.

=head3 Finding lists

Text::WikiFormat uses regular expressions to find lists.  These are kept in the
%tags hash, under the C<lists> key.  To change the regular expression to find
code list items, use:

	my $html = format($wikitext, { lists => { 
		code => qr/^(?:\t+|\s{4,}):\s+/ }
	);

This will require indentation and a colon to mark code lines.  A potential
shortcut is to use C<$Text::WikiFormat::indent> to match or to change the
indentation marker.  (If you do change it, the existing list regular
expressions may not reflect your modifications.  This may be corrected in a
future version, but this really B<ought> to be kept a read-only variable as
much as possible.)

=head3 Finding Lists in the Correct Order

As intrepid bug reporter Tom Hukins pointed out in CPAN RT bug #671, the order
in which Text::WikiFormat searches for lists varies by platform and version of
Perl.  Because some list-finding regular expressions are more specific than
others, what's intended to be one type of list may be caught by a different
list type.

If you're adding new list types, be aware of this.  The C<listorder> entry in
C<%tags> exists to force Text::WikiFormat to apply its regexes from most
specific to least specific.  It contains an array reference.  By default, it
looks for ordered lists first, unordered lists second, and code references at
the end:

Any additional list types will be processed before the built-in types, but
their order of execution is not guaranteed B<unless> you set the order
explicitly.  I can't read all of your minds.  :)

=back

=head1 AUTHOR

chromatic, C<chromatic@wgz.org>, with much input from the Jellybean team
(including Jonathan Paulett).  Tony Bowden and Tom Hukins both suggested some
useful features.  Kate L Pugh has also provided several patches.  Blame me for
the implementation.

=head1 BUGS

The link checker in C<format_line()> may fail to detect existing links that do
not follow HTML, XML, or SGML style.  They may die with some SGML styles too.
I<Sic transit gloria mundi>.

=head1 TODO

=over 4

=item * Find a nicer way to mark list as having unformatted lines

=item * Optimize C<format_line()> to work on a list of lines

=item * Handle nested C<strong> and C<emphasized> markings better

=back

=head1 COPYRIGHT

Copyright (c) 2002, chromatic.  All rights reserved.  This module is
distributed under the same terms as Perl itself.
