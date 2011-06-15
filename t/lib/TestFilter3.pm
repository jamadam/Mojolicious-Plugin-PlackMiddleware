package TestFilter3;
use strict;
use warnings;
use base qw( Plack::Middleware );

sub call {
	
	my $self = shift;
	my $res = $self->app->(@_);
	$self->response_cb($res, sub {
		return sub {
			my $chunk = shift;
			return $chunk. "[$self->{tag}]";
		};
		$res;
	});
}

1;

__END__
