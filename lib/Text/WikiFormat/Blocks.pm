package Text::WikiFormat::Blocks;

use strict;
use warnings;

sub import
{
	my $caller = caller();
	no strict 'refs';
	*{ $caller . '::new_block' } = sub
	{
		my $type  = shift;
		my $class = "Text::WikiFormat::Block::$type";
		my $ctor;
		
		unless ($ctor = $class->can( 'new' ))
		{
			*{ $class . '::ISA' } = [ 'Text::WikiFormat::Block' ];
			$ctor = $class->can( 'new' );
		}

		return $class->new( type => $type, @_ );
	};
}

package Text::WikiFormat::Block;

use Scalar::Util qw( blessed reftype );

sub new
{
	my ($class, %args) = @_;

	$args{text}        =   $class->arg_to_ref( delete $args{text} || '' );
	$args{args}        = [ $class->arg_to_ref( delete $args{args} || [] ) ];

	bless \%args, $class;
}

sub arg_to_ref
{
	my ($class, $value) = @_;
	return   $value if ( reftype( $value ) || '' ) eq 'ARRAY';
	return [ $value ];
}

sub shift_args
{
	my $self = shift;
	my $args = shift @{ $self->{args} };
	return unless $args and ref $args eq 'ARRAY';
	return wantarray ? @$args : $args;
}

sub all_args
{ 
	my $args = $_[0]{args};
	return wantarray ? @$args : $args;
}

sub text
{
	my $text = $_[0]{text};
	return wantarray ? @$text : $text;
}

sub add_text
{
	my $self = shift;
	push @{ $self->{text} }, @_;
}

sub raw_text
{
	my $text = $_[0]{text};
	return wantarray ? @$text : $text;
}

sub formatted_text
{
	my $self = shift;
	return map
	{
		blessed( $_ ) ? $_ : $self->formatter( $_ )
	} $self->raw_text();
}

sub formatter
{
	my ($self, $line) = @_;
	Text::WikiFormat::format_line( $line, $self->tags(), $self->opts() );
}

sub add_args
{
	my $self = shift;
	push @{ $self->{args} }, @_;
}

{
	no strict 'refs';
	for my $attribute (qw( level opts tags type ))
	{
		*{ $attribute } = sub { $_[0]{$attribute} };
	}
}

sub merge
{
	my ($self, $next_block) = @_;

	return $next_block unless $self->type()  eq $next_block->type();
	return $next_block unless $self->level() == $next_block->level();

	$self->add_text( $next_block->raw_text() );
	$self->add_args( $next_block->all_args() );
	return;
}

sub nests
{
	my $self = shift;
	return exists $self->{tags}{nests}{ $self->type() };
}

sub nest
{
	my ($self, $next_block) = @_;

	return $next_block unless $self->nests() and $next_block->nests();
	return $next_block unless $self->level()  <  $next_block->level();

	# if there's a nested block at the end, maybe it can nest too
	my $last_item = ( $self->raw_text() )[-1];
	return $last_item->nest( $next_block ) if blessed( $last_item );

	$self->add_text( $next_block );
	return;
}

package Text::WikiFormat::Block::code;

use base 'Text::WikiFormat::Block';

sub formatter { $_[1] }

1;
