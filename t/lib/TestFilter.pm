package TestFilter;
use strict;
use warnings;
use base qw( Plack::Middleware );

sub call {
	
	my $self = shift;
	my $res = $self->app->(@_);
	$self->response_cb($res, sub {
		my $res = shift;
		my $h = Plack::Util::headers($res->[1]);
		if ($h->get('Content-Type') =~ 'text/html') {
			return sub {
				my $chunk = shift;
				
				$chunk .= '[filtered]';
				
				return $chunk;
			};
		}
		$res;
	});
}

1;

__END__
