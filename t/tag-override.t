use strict;
use Test::More tests => 10;
use Text::WikiFormat;

my $wikitext =<<WIKI;

    * This should be a list.

    1. This should be an ordered list.

    ! This is like the default unordered list
    ! But marked differently

WIKI

my $indent = $Text::WikiFormat::indent;

my $htmltext = Text::WikiFormat::format($wikitext);
like( $htmltext, qr!<li>This should be a list.</li>!m,
	'unordered lists should be rendered correctly' );
like( $htmltext, qr!<li value="1">This should be an ordered list.</li>!m,
	'...and ordered lists too' );

# Redefine all the list regexps to what they were to start with.
my %tags = (
	lists => {
		ordered   => qr/$indent([\dA-Za-z]+)\.\s*/,
		unordered => qr/$indent\*\s*/,
		code      => qr/$indent/,
	},
);

$htmltext = Text::WikiFormat::format($wikitext, \%tags, {} );
like( $htmltext, qr!<li>This should be a list.</li>!m,
	'unordered should remain okay when we redefine all list regexps' );
like( $htmltext, qr!<li value="1">This should be an ordered list.</li>!m,
	'... and so should ordered' );

# Redefine again, set one of them to something different.
%tags = (
	lists => {
		ordered   => qr/$indent([\dA-Za-z]+)\.\s*/,
		unordered => qr/^$indent\s*!\s*/,
		code      => qr/$indent/,
	},
);

$htmltext = Text::WikiFormat::format($wikitext, \%tags, {} );
like( $htmltext, qr!<li>But marked differently</li>!m,
	'unordered should still work when redefined' );
like( $htmltext, qr!<li value="1">This should be an ordered list.</li>!m,
	'...and ordered should be unaffected' );

# Now try redefining just one list type.
%tags = (
	lists => { unordered => qr/$indent\s*!\s*/ },
);

$htmltext = Text::WikiFormat::format($wikitext, \%tags, {} );
like( $htmltext, qr!<li>This is like the default unordered list</li>!m,
	'redefining just one list type should work for that type' );
like( $htmltext, qr!<li value="1">This should be an ordered list.</li>!m,
	'...and should not affect other types too' );

# Test redefining just one list type after using import with a list definition.
package Bar;
Text::WikiFormat->import(
	as => 'wf',
	lists => {
		unordered => qr/^\s*!\s*/
	},
);

$htmltext = wf("        !1. Ordered list\n        ! Unordered list",
               { lists => { ordered => qr/^\s*![\d]+\.\s*/ } }, {} );
::like( $htmltext, qr!<li value="1">Ordered list</li>!m,
	'redefining a single list type after import should work for that type' );
::like( $htmltext, qr!<li>Unordered list</li>!m,
	'...and also for a different type defined on import' );
