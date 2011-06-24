package GrowLargeFilter;
use strict;
use warnings;
use base qw( Plack::Middleware );

sub call {
	
	my $self = shift;
	my $res = $self->app->(@_);
	$self->response_cb($res, sub {
		return sub {
			if (my $chunk = shift) {
				return $chunk. ("1234567890" x 10000);
			}
		};
		$res;
	});
}

1;

__END__
